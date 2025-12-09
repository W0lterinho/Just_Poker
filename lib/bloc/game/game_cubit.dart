import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../repository/poker_repository.dart';
import '../../models/player_dto.dart';
import '../../models/action_dto.dart';
import '../../models/state_dto.dart';
import '../../models/winner_dto.dart'; // NOWE
import 'game_state.dart';
import 'package:flutter/widgets.dart';
import '../../models/sync_dto.dart';

class GameCubit extends Cubit<GameState> {
  final PokerRepository _repo;
  final FlutterSecureStorage _storage;
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _tableSub;
  StreamSubscription? _userSub;
  int? _tableCode;
  List<String> _pendingCards = []; // Karty które czekają na wyświetlenie
  bool _newRoundInProgress = false; // NOWE - flaga czy nowa runda się rozpoczęła

  // NOWE - Timery do usuwania akcji po 4 sekundach
  final Map<String, Timer> _actionTimers = {};
  // NOWE - Opóźnianie pokazywania kart wspólnych (3s przerwa)
  List<String> _pendingCommunityCards = [];
  Timer? _communityCardsTimer;
  bool _delayingCommunityCards = false;
  // NOWE - Buforowanie StateDTO podczas opóźnienia kart
  StateDTO? _pendingStateDTO;

  // NOWE - SHOWDOWN Timery
  Timer? _showdownSequenceTimer;
  Timer? _revealedCardsTimer;
  Timer? _winnersTimer;
  Timer? _allInWinnerTimer; // NOWE - timer dla sekwencji ALL IN

  // NOWE - SHOWDOWN pending dane
  Map<String, List<String>> _pendingRevealedCards = {}; // Karty czekające na pokazanie
  List<WinnerDTO> _pendingWinners = []; // ZMIENIONE - teraz WinnerDTO zamiast String
  bool _isAllInWinners = false; // NOWE - czy to winner_allin
  int _currentAllInWinnerIndex = 0; // NOWE - aktualny index dla sekwencji ALL IN
  List<String> _pendingShowdownCards = []; // Brakujące karty wspólne
  // NOWE - ELIMINATION pending dane
  List<String> _pendingEliminatedEmails = []; // Wyeliminowani gracze czekający na aktualizację
  Timer? _actionTimer;
  bool _shouldStartActionTimer = false;
  bool _shouldStopActionTimer = false;

  // RECONNECT
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  GameCubit(this._repo, this._storage) : super(const GameState());

  @override
  Future<void> close() {
    _reconnectTimer?.cancel();
    _tableSub?.cancel();
    _userSub?.cancel();
    _audioPlayer.dispose();

    // NOWE - Wyczyść wszystkie timery akcji
    for (final timer in _actionTimers.values) {
      timer.cancel();
    }
    _actionTimers.clear();

    // NOWE - Wyczyść SHOWDOWN timery
    _showdownSequenceTimer?.cancel();
    _revealedCardsTimer?.cancel();
    _winnersTimer?.cancel();
    _allInWinnerTimer?.cancel(); // NOWE
    _communityCardsTimer?.cancel();
    // NOWE - Wyczyść pending StateDTO
    _pendingStateDTO = null;

    // NOWE - Wyczyść pending dane
    _pendingRevealedCards.clear();
    _pendingWinners.clear();
    _pendingShowdownCards.clear();
    _pendingEliminatedEmails.clear();
    _newRoundInProgress = false;
    _isAllInWinners = false; // NOWE
    _currentAllInWinnerIndex = 0; // NOWE
    _actionTimer?.cancel();

    return super.close();
  }

  void updateState({
    bool? gameStarted,
    List<PlayerDto>? players,
    List<String>? myCards,
    int? myChips,
    int? pot,
    String? nextPlayerMail,
    String? dealerMail,
    Map<String, String>? lastAction,
    Map<String, int>? roundBets,
    String? localEmail,
    List<PlayerDto>? allPlayers,
    bool? cardsVisible,
    bool? isMyTurn,
    bool? showingRaiseSlider,
    int? raiseAmount,
    int? nextPlayerToCall,
    List<String>? communityCards,
    // NOWE - SHOWDOWN parametry
    Map<String, List<String>>? revealedCards,
    bool? showingRevealedCards,
    List<String>? winners,
    Map<String, int>? winnerWinSizes, // NOWE
    bool? showingWinners,
    // NOWE - ELIMINATION parametry
    List<String>? eliminatedEmails,
    bool? gameFinished,
    String? ultimateWinner,
    // NOWE - ACTION TIMER parametry
    int? actionTimerSeconds,
    bool? actionTimerUrgent,
    bool? actionTimerGracePeriod,
    int? updateNumber,
    bool? isReconnecting,
    bool recalculateMyTurn = true,
  }) {
    print('updateState wywołane z: cardsVisible=$cardsVisible, myCards=$myCards, communityCards=$communityCards, recalculateMyTurn=$recalculateMyTurn, showingRevealedCards=$showingRevealedCards, winners=$winners, showingWinners=$showingWinners, eliminatedEmails=$eliminatedEmails, gameFinished=$gameFinished, isReconnecting=$isReconnecting');

    // STEP 3: Weryfikacja updateNumber (detekcja utraty wiadomości)
    if (updateNumber != null) {
      final lastUpdate = state.updateNumber;
      // Jeśli lastUpdate był null (początek gry/po syncu) lub numer == 1 (nowa runda), akceptujemy bez sprawdzania luki
      if (lastUpdate != null && updateNumber > 1) {
        if (updateNumber > lastUpdate + 1) {
          print('!!! DETEKCJA LUKI W UPDATE NUMBER !!! Oczekiwano: ${lastUpdate + 1}, Otrzymano: $updateNumber');
          print('Uruchamiam sendSync() aby nadrobić zaległości...');
          // Trigger sync - asynchronicznie
          WidgetsBinding.instance.addPostFrameCallback((_) {
             _repo.sendSync().then((syncDto) {
               final currentLocalEmail = localEmail ?? state.localEmail ?? '';
               _applySync(syncDto, currentLocalEmail);
             }).catchError((e) {
               print('Błąd podczas sendSync po detekcji luki: $e');
             });
          });
        }
      }
    }

    // Obliczamy czy to kolej lokalnego gracza TYLKO gdy recalculateMyTurn = true
    final currentLocalEmail = localEmail ?? state.localEmail;
    final currentNextPlayerMail = nextPlayerMail ?? state.nextPlayerMail;

    bool calculatedIsMyTurn;
    if (isMyTurn != null) {
      // Jeśli isMyTurn jest explicite przekazane, używamy tej wartości
      calculatedIsMyTurn = isMyTurn;
    } else if (recalculateMyTurn && (nextPlayerMail != null || localEmail != null)) {
      // Przeliczymy isMyTurn tylko gdy faktycznie zmienia się nextPlayerMail lub localEmail
      // NOWE - Jeśli nextPlayerMail == "SHOWDOWN", to NIE jest kolej żadnego gracza
      // NOWE - Jeśli opóźniamy karty wspólne, to też NIE jest kolej żadnego gracza
      calculatedIsMyTurn = !_delayingCommunityCards &&
          currentNextPlayerMail != null &&
          currentNextPlayerMail != "SHOWDOWN" &&
          currentLocalEmail != null &&
          currentNextPlayerMail == currentLocalEmail;
    } else {
      // Zachowujemy poprzednią wartość (ale blokujemy gdy opóźniamy karty)
      calculatedIsMyTurn = !_delayingCommunityCards && state.isMyTurn;
    }

    // NOWA LOGIKA - Reset suwaka gdy zaczyna się nowa kolej gracza
    bool calculatedShowingRaiseSlider = showingRaiseSlider ?? state.showingRaiseSlider;
    if (!state.isMyTurn && calculatedIsMyTurn) {
      // Kolej gracza się zaczyna (false -> true) - resetuj suwak
      calculatedShowingRaiseSlider = false;
      print('NOWA KOLEJ GRACZA - resetuję suwak Rise na false');
      // NOWE - Zaplanuj start timera (PO emit, jeśli cardsVisible)
      _shouldStartActionTimer = true;
    } else if (state.isMyTurn && !calculatedIsMyTurn) {
      // Kolej gracza się kończy (true -> false) - zaplanuj stop timera
      _shouldStopActionTimer = true;
    }

    emit(state.copyWith(
      gameStarted: gameStarted,
      players: players,
      myCards: myCards,
      myChips: myChips,
      pot: pot,
      nextPlayerMail: nextPlayerMail,
      dealerMail: dealerMail ?? state.dealerMail,
      lastAction: lastAction ?? state.lastAction,
      roundBets: roundBets ?? state.roundBets,
      localEmail: localEmail ?? state.localEmail,
      allPlayers: allPlayers ?? state.allPlayers,
      cardsVisible: cardsVisible ?? state.cardsVisible,
      isMyTurn: calculatedIsMyTurn,
      showingRaiseSlider: calculatedShowingRaiseSlider,
      raiseAmount: raiseAmount ?? state.raiseAmount,
      nextPlayerToCall: nextPlayerToCall ?? state.nextPlayerToCall,
      communityCards: communityCards ?? state.communityCards,
      // NOWE - SHOWDOWN
      revealedCards: revealedCards ?? state.revealedCards,
      showingRevealedCards: showingRevealedCards ?? state.showingRevealedCards,
      winners: winners ?? state.winners,
      winnerWinSizes: winnerWinSizes ?? state.winnerWinSizes, // NOWE
      showingWinners: showingWinners ?? state.showingWinners,
      // NOWE - ELIMINATION
      eliminatedEmails: eliminatedEmails ?? state.eliminatedEmails,
      gameFinished: gameFinished ?? state.gameFinished,
      ultimateWinner: ultimateWinner ?? state.ultimateWinner,
      // NOWE - ACTION TIMER
      actionTimerSeconds: actionTimerSeconds ?? state.actionTimerSeconds,
      actionTimerUrgent: actionTimerUrgent ?? state.actionTimerUrgent,
      actionTimerGracePeriod: actionTimerGracePeriod ?? state.actionTimerGracePeriod,
      updateNumber: updateNumber ?? state.updateNumber,
      isReconnecting: isReconnecting ?? state.isReconnecting,
    ));

    // NOWE - Detectuj SHOWDOWN trigger
    if (nextPlayerMail == "SHOWDOWN" && !state.showingRevealedCards && !state.showingWinners) {
      print('WYKRYTO SHOWDOWN - rozpoczynam sekwencję');
      _startShowdownSequence();
    }

    print('Stan po emit: cardsVisible=${state.cardsVisible}, myCards length=${state.myCards.length}, isMyTurn=${state.isMyTurn}, showingRaiseSlider=${state.showingRaiseSlider}, communityCards length=${state.communityCards.length}, winners=${state.winners}, showingWinners=${state.showingWinners}, eliminatedEmails=${state.eliminatedEmails}, gameFinished=${state.gameFinished}');

    // NOWE - Wykrywanie zmiany cardsVisible na true (kluczowy moment startu timera!)
    final previousCardsVisible = cardsVisible == null ? state.cardsVisible : !cardsVisible;
    final currentCardsVisible = state.cardsVisible;
    if (!previousCardsVisible && currentCardsVisible && state.isMyTurn) {
      // cardsVisible zmieniło się false → true I jest kolej gracza
      print('WYKRYTO: cardsVisible = true I isMyTurn = true → STARTUJĘ TIMER');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startActionTimerDirectly();
      });
    }

    // NOWE - Wykonaj akcje timera PO emit (asynchronicznie, żeby nie kolidować)
    if (_shouldStartActionTimer) {
      _shouldStartActionTimer = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startActionTimerDirectly();
      });
    }
    if (_shouldStopActionTimer) {
      _shouldStopActionTimer = false;
      _stopActionTimer();
    }
  }
  /// Inicjalizacja gry z SyncDTO (po reconnect)
  Future<void> initFromSync(SyncDTO syncDto) async {
    final me = await _storage.read(key: 'userEmail') ?? '';
    final tableCodeStr = await _storage.read(key: 'tableCode');
    final tableCode = int.tryParse(tableCodeStr ?? '');

    if (tableCode == null) {
      print('Brak tableCode w SecureStorage - nie można zainicjalizować z sync');
      return;
    }

    if (me.isEmpty) {
      print('Brak userEmail w SecureStorage - nie można zainicjalizować z sync');
      return;
    }

    print('=== INICJALIZACJA Z SYNC ===');
    print('tableCode: $tableCode, email: $me');
    print('SyncDTO: gameStarted=${syncDto.gameStarted}, pot=${syncDto.pot}, players=${syncDto.players.length}');

    _tableCode = tableCode;

    // 1. Subskrybuj tematy
    _subscribeTopics(tableCode, me);

    // 2. Aplikuj SyncDTO na stan
    _applySync(syncDto, me);

    print('Inicjalizacja z sync zakończona pomyślnie');
  }

  /// Subskrybuje tematy WebSocket dla danego stołu i użytkownika
  void _subscribeTopics(int tableCode, String userEmail) {
    print('Subskrybuję tematy: /topic/table/$tableCode i /topic/user/$userEmail');

    // Subskrypcja na topic stołu - IDENTYCZNA jak w metodzie init
    _tableSub = _repo.subscribeTopic<dynamic>(
      '/topic/table/$tableCode',
          (json) => json,
    ).listen((payload) async {
      print('WS [table/$tableCode] payload: $payload');

      if (payload is Map<String, dynamic>) {
        // Nowa obsługa gameStarted: TRUE
        if (payload['gameStarted'] == true) {
          final wasGameStarted = state.gameStarted;
          updateState(gameStarted: true, recalculateMyTurn: false);
          print("Ustawiono gameStarted na true na podstawie WS /topic/table/$tableCode");

          // Jeśli gra nie była wcześniej rozpoczęta (np. Joiner), uruchom sekwencję tasowania
          if (!wasGameStarted) {
            print("Wykryto start gry (Joiner) - uruchamiam sekwencję tasowania");
            _playCardShuffleSequence();
          }
          return;
        }

        // Obsługa DEKODERA DEALERA
        if (payload['type'] == 'dealer') {
          updateState(dealerMail: payload['object'] as String?, recalculateMyTurn: false);
          return;
        }

        // NOWA OBSŁUGA - karty wspólne z akumulacją podczas opóźnienia
        if (payload['type'] == 'community_cards') {
          final object = payload['object'];

          // Parsowanie - pojedyncza karta lub lista
          List<String> cardsToAdd = [];

          if (object is String) {
            cardsToAdd = [object];
            print('Otrzymano pojedynczą kartę wspólną: $object');
          } else if (object is List) {
            cardsToAdd = List<String>.from(object);
            print('Otrzymano listę kart wspólnych: $cardsToAdd');
          } else {
            print('Nieznany format community_cards: $object');
            return;
          }

          // KLUCZOWA LOGIKA - sprawdź czy już opóźniamy karty
          if (_delayingCommunityCards) {
            print('Akumuluję karty do pending (opóźnienie w toku): $cardsToAdd');
            _pendingCommunityCards.addAll(cardsToAdd);
            print('Pending cards teraz: $_pendingCommunityCards');
          } else {
            print('NOWA FAZA - rozpoczynam opóźnienie 3s dla kart: $cardsToAdd');

            _pendingCommunityCards = List<String>.from(cardsToAdd);
            _delayingCommunityCards = true;

            updateState(recalculateMyTurn: true);

            _communityCardsTimer?.cancel();
            _communityCardsTimer = Timer(const Duration(seconds: 3), () {
              _showPendingCommunityCards();
            });

            print('Timer 3s uruchomiony, pending cards: $_pendingCommunityCards');
          }
          return;
        }

        // NOWE - Obsługa kart do pokazania w SHOWDOWN
        if (payload['type'] == 'cards_to_show') {
          final cardsMap = payload['object'] as Map<String, dynamic>? ?? {};
          final convertedMap = <String, List<String>>{};
          cardsMap.forEach((email, cards) {
            if (cards is List) {
              convertedMap[email] = List<String>.from(cards);
            }
          });
          print('Otrzymano karty do pokazania: $convertedMap');
          _handleCardsToShow(convertedMap);
          return;
        }

        // ZMIENIONE - Obsługa zwycięzców (type="winner")
        if (payload['type'] == 'winner') {
          final winnersObject = payload['object'];
          if (winnersObject is List) {
            final winnersDto = winnersObject.map((w) {
              if (w is Map<String, dynamic>) {
                return WinnerDTO.fromJson(w);
              }
              return null;
            }).whereType<WinnerDTO>().toList();

            print('Otrzymano zwycięzców (winner): ${winnersDto.map((w) => w.toString()).toList()}');
            _handleWinners(winnersDto, isAllIn: false);
          } else {
            print('Nieznany format winner: $winnersObject');
          }
          return;
        }

        // NOWE - Obsługa zwycięzców ALL IN (type="winner_allin")
        if (payload['type'] == 'winner_allin') {
          final winnersObject = payload['object'];
          if (winnersObject is List) {
            final winnersDto = winnersObject.map((w) {
              if (w is Map<String, dynamic>) {
                return WinnerDTO.fromJson(w);
              }
              return null;
            }).whereType<WinnerDTO>().toList();

            print('Otrzymano zwycięzców (winner_allin): ${winnersDto.map((w) => w.toString()).toList()}');
            _handleWinners(winnersDto, isAllIn: true);
          } else {
            print('Nieznany format winner_allin: $winnersObject');
          }
          return;
        }

        // NOWE - Obsługa showdown_cards
        if (payload['type'] == 'showdown_cards') {
          final cardsObject = payload['object'];
          List<String> showdownCards;
          if (cardsObject is List) {
            showdownCards = List<String>.from(cardsObject);
          } else {
            print('Nieznany format showdown_cards: $cardsObject');
            return;
          }
          print('Otrzymano showdown_cards: $showdownCards');
          _handleShowdownCards(showdownCards);
          return;
        }

        // NOWE - Obsługa wyeliminowanych graczy
        if (payload['type'] == 'eliminated_players') {
          final eliminatedObject = payload['object'];
          List<String> eliminatedEmails;
          if (eliminatedObject is List) {
            eliminatedEmails = List<String>.from(eliminatedObject);
          } else {
            print('Nieznany format eliminated_players: $eliminatedObject');
            return;
          }
          print('Otrzymano eliminated_players: $eliminatedEmails');
          _handleEliminatedPlayers(eliminatedEmails);
          return;
        }

        // NOWE - Obsługa zakończenia gry
        if (payload['type'] == 'game_finished') {
          final gameFinishedObject = payload['object'] as Map<String, dynamic>? ?? {};
          final ultimateWinner = gameFinishedObject['ultimate_winner'] as String?;
          print('Otrzymano game_finished z ultimate_winner: $ultimateWinner');
          _handleGameFinished(ultimateWinner);
          return;
        }

        // Obsługa StateDTO
        if (payload.containsKey('pot') || payload.containsKey('nextPlayerMail') || payload.containsKey('nextPlayerToCall')) {
          try {
            final s = StateDTO.fromJson(payload);

            if (_delayingCommunityCards) {
              print('BUFORUJĘ StateDTO podczas opóźnienia kart (table topic)');
              print('  pot: ${s.pot}');
              print('  nextPlayerMail: ${s.nextPlayerMail}');
              print('  nextPlayerToCall: ${s.nextPlayerToCall}');

              _pendingStateDTO = s;

              updateState(
                pot: s.pot,
                recalculateMyTurn: false,
              );

              if (s.actionPlayerMail != null) {
                _updatePlayerBetsAndChips(
                  email: s.actionPlayerMail!,
                  chipsLeft: s.chipsLeft,
                  chipsInRound: s.chipsInRound,
                  action: s.action,
                );
              }
            } else {
              print('Otrzymano StateDTO z table: pot=${s.pot}, nextPlayerMail=${s.nextPlayerMail}, nextPlayerToCall=${s.nextPlayerToCall}');
              updateState(
                pot: s.pot,
                nextPlayerMail: s.nextPlayerMail,
                nextPlayerToCall: s.nextPlayerToCall,
                recalculateMyTurn: true,
              );

              if (s.actionPlayerMail != null) {
                _updatePlayerBetsAndChips(
                  email: s.actionPlayerMail!,
                  chipsLeft: s.chipsLeft,
                  chipsInRound: s.chipsInRound,
                  action: s.action,
                );
              }
            }
          } catch (e) {
            print("Nieudane parsowanie StateDTO z table: $e");
          }
          return;
        }
      }
    });

    // Subskrypcja na topic użytkownika - IDENTYCZNA jak w metodzie init
    if (userEmail.isNotEmpty) {
      _userSub = _repo.subscribeTopic<dynamic>(
        '/topic/user/$userEmail',
            (json) => json,
      ).listen((payload) {
        print('WS [user/$userEmail] payload: $payload | type: ${payload.runtimeType}');
        if (payload is Map<String, dynamic>) {
          // Obsługa kart gracza
          if (payload['type'] == 'cards') {
            final cards = List<String>.from(payload['object'] ?? []);
            print('Otrzymano karty gracza lokalnego: $cards');
            _pendingCards = cards;

            if (_newRoundInProgress) {
              print('Nowa runda w toku - uruchamiam sekwencję dźwięku');
              _playNewRoundSequence();
            }
            // OBSŁUGA OPÓŹNIONYCH KART PRZY STARCIE:
            // Jeśli gra wystartowała, animacja tasowania już się zakończyła (cardsVisible=true),
            // ale nie mieliśmy wtedy kart (myCards=[]), to aktualizujemy je teraz.
            else if (state.gameStarted && state.cardsVisible && state.myCards.isEmpty) {
              print('Karty dotarły po animacji startowej (lub pusty stan) - aktualizuję natychmiast');
              updateState(
                myCards: _pendingCards,
                recalculateMyTurn: false,
              );
              _pendingCards = [];
            }
            return;
          }

          // Obsługa community_cards z user topic
          if (payload['type'] == 'community_cards') {
            final object = payload['object'];
            List<String> cardsToAdd = [];

            if (object is String) {
              cardsToAdd = [object];
              print('Otrzymano pojedynczą kartę wspólną: $object');
            } else if (object is List) {
              cardsToAdd = List<String>.from(object);
              print('Otrzymano listę kart wspólnych: $cardsToAdd');
            } else {
              print('Nieznany format community_cards: $object');
              return;
            }

            if (_delayingCommunityCards) {
              print('Akumuluję karty do pending (opóźnienie w toku): $cardsToAdd');
              _pendingCommunityCards.addAll(cardsToAdd);
              print('Pending cards teraz: $_pendingCommunityCards');
            } else {
              print('NOWA FAZA - rozpoczynam opóźnienie 3s dla kart: $cardsToAdd');

              _pendingCommunityCards = List<String>.from(cardsToAdd);
              _delayingCommunityCards = true;

              updateState(recalculateMyTurn: true);

              _communityCardsTimer?.cancel();
              _communityCardsTimer = Timer(const Duration(seconds: 3), () {
                _showPendingCommunityCards();
              });

              print('Timer 3s uruchomiony, pending cards: $_pendingCommunityCards');
            }
            return;
          }

          // Obsługa cards_to_show
          if (payload['type'] == 'cards_to_show') {
            final cardsMap = payload['object'] as Map<String, dynamic>? ?? {};
            final convertedMap = <String, List<String>>{};
            cardsMap.forEach((email, cards) {
              if (cards is List) {
                convertedMap[email] = List<String>.from(cards);
              }
            });
            print('Otrzymano karty do pokazania (user topic): $convertedMap');
            _handleCardsToShow(convertedMap);
            return;
          }

          // Obsługa winner
          if (payload['type'] == 'winner') {
            final winnersObject = payload['object'];
            if (winnersObject is List) {
              final winnersDto = winnersObject.map((w) {
                if (w is Map<String, dynamic>) {
                  return WinnerDTO.fromJson(w);
                }
                return null;
              }).whereType<WinnerDTO>().toList();

              print('Otrzymano zwycięzców (winner, user topic): ${winnersDto.map((w) => w.toString()).toList()}');
              _handleWinners(winnersDto, isAllIn: false);
            } else {
              print('Nieznany format winner (user topic): $winnersObject');
            }
            return;
          }

          // Obsługa winner_allin
          if (payload['type'] == 'winner_allin') {
            final winnersObject = payload['object'];
            if (winnersObject is List) {
              final winnersDto = winnersObject.map((w) {
                if (w is Map<String, dynamic>) {
                  return WinnerDTO.fromJson(w);
                }
                return null;
              }).whereType<WinnerDTO>().toList();

              print('Otrzymano zwycięzców (winner_allin, user topic): ${winnersDto.map((w) => w.toString()).toList()}');
              _handleWinners(winnersDto, isAllIn: true);
            } else {
              print('Nieznany format winner_allin (user topic): $winnersObject');
            }
            return;
          }

          // Obsługa showdown_cards
          if (payload['type'] == 'showdown_cards') {
            final cardsObject = payload['object'];
            List<String> showdownCards;
            if (cardsObject is List) {
              showdownCards = List<String>.from(cardsObject);
            } else {
              print('Nieznany format showdown_cards (user topic): $cardsObject');
              return;
            }
            print('Otrzymano showdown_cards (user topic): $showdownCards');
            _handleShowdownCards(showdownCards);
            return;
          }

          // Obsługa eliminated_players
          if (payload['type'] == 'eliminated_players') {
            final eliminatedObject = payload['object'];
            List<String> eliminatedEmails;
            if (eliminatedObject is List) {
              eliminatedEmails = List<String>.from(eliminatedObject);
            } else {
              print('Nieznany format eliminated_players (user topic): $eliminatedObject');
              return;
            }
            print('Otrzymano eliminated_players (user topic): $eliminatedEmails');
            _handleEliminatedPlayers(eliminatedEmails);
            return;
          }

          // Obsługa game_finished
          if (payload['type'] == 'game_finished') {
            final gameFinishedObject = payload['object'] as Map<String, dynamic>? ?? {};
            final ultimateWinner = gameFinishedObject['ultimate_winner'] as String?;
            print('Otrzymano game_finished (user topic) z ultimate_winner: $ultimateWinner');
            _handleGameFinished(ultimateWinner);
            return;
          }

          // Obsługa StateDTO z user topic
          if (payload.containsKey('pot') && payload.containsKey('nextPlayerMail')) {
            try {
              final s = StateDTO.fromJson(payload);
              print('Otrzymano StateDTO z /user: pot=${s.pot}, nextPlayerMail=${s.nextPlayerMail}, nextPlayerToCall=${s.nextPlayerToCall}, actionPlayerMail=${s.actionPlayerMail}, action=${s.action}, chipsLeft=${s.chipsLeft}, chipsInRound=${s.chipsInRound}');

              if (_delayingCommunityCards) {
                print('BUFORUJĘ StateDTO podczas opóźnienia kart (user topic)');
                print('  Zastosuje po pokazaniu kart');

                _pendingStateDTO = s;

                updateState(
                  pot: s.pot,
                  recalculateMyTurn: false,
                );

                if (s.actionPlayerMail != null) {
                  _updatePlayerBetsAndChips(
                    email: s.actionPlayerMail!,
                    chipsLeft: s.chipsLeft,
                    chipsInRound: s.chipsInRound,
                    action: s.action,
                  );
                }
              } else {
                print('Stosuję StateDTO natychmiast (user topic) - brak opóźnienia');
                updateState(
                  pot: s.pot,
                  nextPlayerMail: s.nextPlayerMail,
                  nextPlayerToCall: s.nextPlayerToCall,
                  recalculateMyTurn: true,
                );

                if (s.actionPlayerMail != null) {
                  _updatePlayerBetsAndChips(
                    email: s.actionPlayerMail!,
                    chipsLeft: s.chipsLeft,
                    chipsInRound: s.chipsInRound,
                    action: s.action,
                  );
                }
              }

              print('AKTUALNY STAN: ${state.toString()}');
            } catch (e) {
              print("Nieudane parsowanie StateDTO z /user: $e");
            }
            return;
          }

          // Obsługa pełnej mapy graczy
          if (payload.values.isNotEmpty && payload.values.first is Map<String, dynamic> && (payload.values.first as Map<String, dynamic>).containsKey('seatIndex')) {
            print('PRZED _handlePlayersMap, payload: $payload');
            _handlePlayersMap(payload, userEmail);
            print('PO _handlePlayersMap');
            return;
          }
        }
      });
    }

    print('Subskrypcje utworzone pomyślnie');
  }

  /// Aplikuje SyncDTO na stan gry (wspólna metoda dla init i update)
  void _applySync(SyncDTO syncDto, String localEmail) {
    print('=== APLIKOWANIE SYNC NA STAN ===');
    print('Liczba graczy w SyncDTO: ${syncDto.players.length}');

    // Buduj listy graczy
    final allPlayers = <PlayerDto>[];
    final opponents = <PlayerDto>[];
    int? myChips;
    final roundBets = <String, int>{};

    syncDto.players.forEach((email, player) {
      allPlayers.add(player);
      roundBets[email] = player.chipsInRound;

      if (email == localEmail) {
        myChips = player.chips;
        print('Znaleziono lokalnego gracza: $email, chips: ${player.chips}');
      } else {
        opponents.add(player);
      }
    });

    // Sortuj graczy po seatIndex (IDENTYCZNIE jak w _handlePlayersMap)
    allPlayers.sort((a, b) => a.seatIndex.compareTo(b.seatIndex));

    print('allPlayers posortowani: ${allPlayers.map((p) => '${p.email}(seat:${p.seatIndex})').toList()}');
    print('opponents: ${opponents.length}');
    print('myChips: $myChips');
    print('roundBets: $roundBets');
    print('communityCards: ${syncDto.communityCards}');
    print('myCards: ${syncDto.myCards}');
    print('eliminatedEmails: ${syncDto.eliminatedEmails}');

    // Aplikuj wszystko na stan
    updateState(
      gameStarted: syncDto.gameStarted,
      players: opponents,
      allPlayers: allPlayers,
      myCards: syncDto.myCards,
      myChips: myChips ?? 0,
      pot: syncDto.pot,
      nextPlayerMail: syncDto.nextPlayerMail,
      dealerMail: syncDto.dealerMail,
      communityCards: syncDto.communityCards,
      eliminatedEmails: syncDto.eliminatedEmails,
      roundBets: roundBets,
      nextPlayerToCall: syncDto.nextPlayerToCall,
      localEmail: localEmail,
      cardsVisible: syncDto.gameStarted, // Jeśli gra started, pokaż karty
      updateNumber: syncDto.updateNumber,
      recalculateMyTurn: true,
    );

    print('Stan zaktualizowany z SyncDTO');
    print('AKTUALNY STAN: gameStarted=${state.gameStarted}, cardsVisible=${state.cardsVisible}, isMyTurn=${state.isMyTurn}');
  }

  Future<void> init(int tableCode) async {
    _tableCode = tableCode;
    final me = await _storage.read(key: 'userEmail') ?? '';

    // Ustawienie callbacków dla STOMP Client (reconnect logic)
    _repo.createStompClient(
        onConnect: (frame) {
          print('WS: onConnect - Połączono z serwerem');
          // Jeśli byliśmy w trakcie reconnectu, to teraz sukces
          if (state.isReconnecting) {
            print('WS: Reconnect udany po $_reconnectAttempts próbach!');
            _handleReconnected(tableCode, me);
          }
        },
        onError: (err) {
          print('WS Error: $err');
          // Error może oznaczać rozłączenie
          if (!state.isReconnecting) {
             _handleDisconnect();
          }
        },
        onDisconnect: () {
          print('WS: onDisconnect - Utracono połączenie');
          _handleDisconnect();
        }
    );

    // 1) SUB na /topic/table/...
    _subscribeTopics(tableCode, me);
  }

  void _handleDisconnect() {
    if (state.isReconnecting) return; // Już obsługujemy
    print('=== UTRATA POŁĄCZENIA - ROZPOCZYNAM PROCEDURĘ RECONNECT ===');

    updateState(isReconnecting: true, recalculateMyTurn: false);
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();

    _attemptReconnectLoop();
  }

  void _attemptReconnectLoop() {
    // 25 prób * 5s = 2 minuty i 5 sekund
    if (_reconnectAttempts >= 25) {
      print('=== RECONNECT FAILED: Osiągnięto limit 25 prób ===');
      _reconnectTimer?.cancel();
      // Tutaj można dodać logikę wyjścia do menu albo pokazania błędu krytycznego
      return;
    }

    _reconnectAttempts++;
    print('Reconnect attempt: $_reconnectAttempts / 25');

    // Spróbuj nawiązać połączenie (repo.createStompClient zabija stare i tworzy nowe)
    // UWAGA: createStompClient wywołujemy z tymi samymi callbackami co w init.
    // Ale w init już przekazaliśmy callbacki, które są "stateful" w kontekście createStompClient?
    // W obecnej implementacji PokerRepository createStompClient zwraca clienta i go aktywuje.
    // Więc wystarczy wywołać to ponownie.

    // Musimy jednak mieć dostęp do `tableCode` i `me` w callbackach, a te są w polach klasy `_tableCode`.
    final currentTableCode = _tableCode;
    final me = state.localEmail ?? ''; // lub z secureStorage, ale tu powinno być w stanie

    if (currentTableCode == null) {
      print('Brak tableCode - nie można wykonać reconnectu');
      return;
    }

    // Wywołanie repo.createStompClient spowoduje próbę połączenia.
    // Jeśli się uda -> odpali się onConnect -> _handleReconnected
    // Jeśli się nie uda -> odpali się onError/onDisconnect -> ale musimy unikać pętli nieskończonej wywołań.
    // W PokerRepo ustawiliśmy reconnectDelay: 0, więc biblioteka nie będzie sama próbować.
    // My musimy próbować co 5 sekund.

    _repo.createStompClient(
        onConnect: (frame) {
           print('WS (Reconnect): Connected!');
           _reconnectTimer?.cancel(); // Zatrzymaj pętlę
           _handleReconnected(currentTableCode, me);
        },
        onError: (err) {
           print('WS (Reconnect): Error... ($err)');
           // Nie robimy nic, timer za 5s spróbuje znowu
        },
        onDisconnect: () {
           print('WS (Reconnect): Disconnected...');
           // Nie robimy nic, timer za 5s spróbuje znowu
        }
    );

    // Zaplanuj kolejną próbę za 5s
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _attemptReconnectLoop();
    });
  }

  Future<void> _handleReconnected(int tableCode, String userEmail) async {
    print('=== POŁĄCZENIE ODZYSKANE ===');

    // 1. Zasubskrybuj tematy na nowo (bo nowe połączenie)
    _subscribeTopics(tableCode, userEmail);

    // 2. Wyślij prośbę o synchronizację
    try {
      final syncDto = await _repo.sendSync();
      print('Otrzymano SyncDTO po reconnect');

      // 3. Zaktualizuj stan
      _applySync(syncDto, userEmail);

      // 4. Zdejmij flagę reconnecting
      updateState(isReconnecting: false, recalculateMyTurn: true);

      print('=== RECONNECT ZAKOŃCZONY SUKCESEM ===');
    } catch (e) {
      print('Błąd podczas synchronizacji po reconnect: $e');
      // Jeśli sync się nie udał... może spróbuj jeszcze raz albo uznaj że failed?
      // Na razie uznajemy że reconnect się powiódł tylko połowicznie (socket jest, dane nie).
      // Może warto ponowić sync?
    }
  }

  // Metoda wywoływana przez GameScreen gdy aplikacja wraca z tła (STEP 3)
  Future<void> onAppResumed() async {
    print('=== APLIKACJA WZNOWIONA (RESUMED) ===');
    // Prewencyjna synchronizacja
    if (state.gameStarted && !state.isReconnecting) {
      try {
        final email = state.localEmail;
        if (email != null && email.isNotEmpty) {
           print('Wysyłam prewencyjny Sync...');
           final syncDto = await _repo.sendSync();
           _applySync(syncDto, email);
           print('Prewencyjny Sync zakończony.');
        }
      } catch (e) {
        print('Błąd prewencyjnego Sync: $e');
      }
    }
  }

  // NOWE - ELIMINATION HANDLING METHODS (This line is not really here, just forcing the diff to span the gap)
  /* DEAD CODE REMOVED */
      print('WS [table/$tableCode] payload: $payload');

      if (payload is Map<String, dynamic>) {
        // Nowa obsługa gameStarted: TRUE
        if (payload['gameStarted'] == true) {
          final wasGameStarted = state.gameStarted;
          updateState(gameStarted: true, recalculateMyTurn: false);
          print("Ustawiono gameStarted na true na podstawie WS /topic/table/$tableCode");

          // Jeśli gra nie była wcześniej rozpoczęta (np. Joiner), uruchom sekwencję tasowania
          if (!wasGameStarted) {
            print("Wykryto start gry (Joiner) - uruchamiam sekwencję tasowania");
            _playCardShuffleSequence();
          }
          return;
        }

        // Obsługa DEKODERA DEALERA
        if (payload['type'] == 'dealer') {
          updateState(dealerMail: payload['object'] as String?, recalculateMyTurn: false);
          return;
        }

        // NOWA OBSŁUGA - karty wspólne z akumulacją podczas opóźnienia
        if (payload['type'] == 'community_cards') {
          final object = payload['object'];

          // Parsowanie - pojedyncza karta lub lista
          List<String> cardsToAdd = [];

          if (object is String) {
            // Backend wysyła pojedynczą kartę
            cardsToAdd = [object];
            print('Otrzymano pojedynczą kartę wspólną: $object');
          } else if (object is List) {
            // Backend wysyła listę kart
            cardsToAdd = List<String>.from(object);
            print('Otrzymano listę kart wspólnych: $cardsToAdd');
          } else {
            print('Nieznany format community_cards: $object');
            return;
          }

          // KLUCZOWA LOGIKA - sprawdź czy już opóźniamy karty
          if (_delayingCommunityCards) {
            // Jesteśmy w trakcie opóźnienia - AKUMULUJ karty
            print('Akumuluję karty do pending (opóźnienie w toku): $cardsToAdd');
            _pendingCommunityCards.addAll(cardsToAdd);
            print('Pending cards teraz: $_pendingCommunityCards');
          } else {
            // Pierwsza karta w nowej fazie - ROZPOCZNIJ opóźnienie
            print('NOWA FAZA - rozpoczynam opóźnienie 3s dla kart: $cardsToAdd');

            // Zapisz karty jako pending
            _pendingCommunityCards = List<String>.from(cardsToAdd);
            _delayingCommunityCards = true;

            // WAŻNE - Zablokuj isMyTurn natychmiast
            updateState(recalculateMyTurn: true);

            // Uruchom timer 3s (anuluj poprzedni na wszelki wypadek)
            _communityCardsTimer?.cancel();
            _communityCardsTimer = Timer(const Duration(seconds: 3), () {
              _showPendingCommunityCards();
            });

            print('Timer 3s uruchomiony, pending cards: $_pendingCommunityCards');
          }
          return;
        }

        // NOWE - Obsługa kart do pokazania w SHOWDOWN
        if (payload['type'] == 'cards_to_show') {
          final cardsMap = payload['object'] as Map<String, dynamic>? ?? {};
          final convertedMap = <String, List<String>>{};
          cardsMap.forEach((email, cards) {
            if (cards is List) {
              convertedMap[email] = List<String>.from(cards);
            }
          });
          print('Otrzymano karty do pokazania: $convertedMap');
          _handleCardsToShow(convertedMap);
          return;
        }

        // ZMIENIONE - Obsługa zwycięzców (type="winner")
        if (payload['type'] == 'winner') {
          final winnersObject = payload['object'];
          if (winnersObject is List) {
            final winnersDto = winnersObject.map((w) {
              if (w is Map<String, dynamic>) {
                return WinnerDTO.fromJson(w);
              }
              return null;
            }).whereType<WinnerDTO>().toList();

            print('Otrzymano zwycięzców (winner): ${winnersDto.map((w) => w.toString()).toList()}');
            _handleWinners(winnersDto, isAllIn: false);
          } else {
            print('Nieznany format winner: $winnersObject');
          }
          return;
        }

        // NOWE - Obsługa zwycięzców ALL IN (type="winner_allin")
        if (payload['type'] == 'winner_allin') {
          final winnersObject = payload['object'];
          if (winnersObject is List) {
            final winnersDto = winnersObject.map((w) {
              if (w is Map<String, dynamic>) {
                return WinnerDTO.fromJson(w);
              }
              return null;
            }).whereType<WinnerDTO>().toList();

            print('Otrzymano zwycięzców (winner_allin): ${winnersDto.map((w) => w.toString()).toList()}');
            _handleWinners(winnersDto, isAllIn: true);
          } else {
            print('Nieznany format winner_allin: $winnersObject');
          }
          return;
        }

        // NOWE - Obsługa showdown_cards (dodatkowe karty wspólne przy wcześniejszym showdown)
        if (payload['type'] == 'showdown_cards') {
          final cardsObject = payload['object'];
          List<String> showdownCards;
          if (cardsObject is List) {
            showdownCards = List<String>.from(cardsObject);
          } else {
            print('Nieznany format showdown_cards: $cardsObject');
            return;
          }
          print('Otrzymano showdown_cards: $showdownCards');
          _handleShowdownCards(showdownCards);
          return;
        }

        // NOWE - Obsługa wyeliminowanych graczy
        if (payload['type'] == 'eliminated_players') {
          final eliminatedObject = payload['object'];
          List<String> eliminatedEmails;
          if (eliminatedObject is List) {
            eliminatedEmails = List<String>.from(eliminatedObject);
          } else {
            print('Nieznany format eliminated_players: $eliminatedObject');
            return;
          }
          print('Otrzymano eliminated_players: $eliminatedEmails');
          _handleEliminatedPlayers(eliminatedEmails);
          return;
        }

        // NOWE - Obsługa zakończenia gry
        if (payload['type'] == 'game_finished') {
          final gameFinishedObject = payload['object'] as Map<String, dynamic>? ?? {};
          final ultimateWinner = gameFinishedObject['ultimate_winner'] as String?;
          print('Otrzymano game_finished z ultimate_winner: $ultimateWinner');
          _handleGameFinished(ultimateWinner);
          return;
        }

        // Obsługa StateDTO – update tylko określonych pól!
        if (payload.containsKey('pot') || payload.containsKey('nextPlayerMail') || payload.containsKey('nextPlayerToCall')) {
          try {
            final s = StateDTO.fromJson(payload);

            // NOWA LOGIKA - buforuj StateDTO podczas opóźnienia kart
            if (_delayingCommunityCards) {
              print('BUFORUJĘ StateDTO podczas opóźnienia kart (table topic)');
              print('  pot: ${s.pot}');
              print('  nextPlayerMail: ${s.nextPlayerMail}');
              print('  nextPlayerToCall: ${s.nextPlayerToCall}');

              // Zapisz StateDTO jako pending - zastosujemy po pokazaniu kart
              _pendingStateDTO = s;

              // ALE aktualizuj pot i akcję gracza natychmiast (widoczne od razu)
              if (s.pot != null) {
                updateState(
                  pot: s.pot,
                  recalculateMyTurn: false, // NIE aktualizujemy isMyTurn podczas blokady
                );
              }

              if (s.actionPlayerMail != null) {
                _updatePlayerBetsAndChips(
                  email: s.actionPlayerMail!,
                  chipsLeft: s.chipsLeft,
                  chipsInRound: s.chipsInRound,
                  action: s.action,
                );
              }
            } else {
              // Normalne flow - brak opóźnienia, zastosuj wszystko od razu
              print('Stosuję StateDTO natychmiast (table topic) - brak opóźnienia');
              updateState(
                pot: s.pot ?? state.pot,
                nextPlayerMail: s.nextPlayerMail ?? state.nextPlayerMail,
                nextPlayerToCall: s.nextPlayerToCall ?? state.nextPlayerToCall,
                recalculateMyTurn: true, // WAŻNE - przeliczymy isMyTurn bo nextPlayerMail się zmieniło
              );

              if (s.actionPlayerMail != null) {
                _updatePlayerBetsAndChips(
                  email: s.actionPlayerMail!,
                  chipsLeft: s.chipsLeft,
                  chipsInRound: s.chipsInRound,
                  action: s.action,
                );
              }
            }
          } catch (e) {
            print("Nieudane parsowanie StateDTO z /table: $e");
          }
          return;
        }
        print('Przechodzi przez handlePlayersMap z TABLE topic');
        _handlePlayersMap(payload, me);
      }

      // OBSŁUGA STARSZEGO FORMATU - surowa lista kart wspólnych (dla kompatybilności)
      else if (payload is List) {
        final cards = List<String>.from(payload);
        print('Otrzymano karty wspólne (stary format): $cards');
        updateState(
          communityCards: cards,
          recalculateMyTurn: false,
        );
      }
    });

    // 2) subskrybuj temat użytkownika: karty + StateDTO + mapa graczy
    if (me.isNotEmpty) {
      _userSub = _repo.subscribeTopic<dynamic>(
        '/topic/user/$me',
            (json) => json,
      ).listen((payload) {
        print('WS [user/$me] payload: $payload | type: ${payload.runtimeType}');
        if (payload is Map<String, dynamic>) {
          // 1. Obsługa kart gracza - automatyczne uruchomienie sekwencji nowej rundy
          if (payload['type'] == 'cards') {
            final cards = List<String>.from(payload['object'] ?? []);
            print('Otrzymano karty gracza lokalnego: $cards');
            _pendingCards = cards;

            // NOWE - Jeśli nowa runda jest w toku, uruchom sekwencję dźwięku
            if (_newRoundInProgress) {
              print('Nowa runda w toku - uruchamiam sekwencję dźwięku');
              _playNewRoundSequence();
            }
            // OBSŁUGA OPÓŹNIONYCH KART PRZY STARCIE:
            // Jeśli gra wystartowała, animacja tasowania już się zakończyła (cardsVisible=true),
            // ale nie mieliśmy wtedy kart (myCards=[]), to aktualizujemy je teraz.
            else if (state.gameStarted && state.cardsVisible && state.myCards.isEmpty) {
              print('Karty dotarły po animacji startowej (lub pusty stan) - aktualizuję natychmiast');
              updateState(
                myCards: _pendingCards,
                recalculateMyTurn: false,
              );
              _pendingCards = [];
            }
            // Jeśli nie nowa runda, NIE wywołujemy updateState z kartami - czekamy na sekwencję
            return;
          }

          // NOWA OBSŁUGA - karty wspólne z akumulacją podczas opóźnienia
          if (payload['type'] == 'community_cards') {
            final object = payload['object'];

            // Parsowanie - pojedyncza karta lub lista
            List<String> cardsToAdd = [];

            if (object is String) {
              // Backend wysyła pojedynczą kartę
              cardsToAdd = [object];
              print('Otrzymano pojedynczą kartę wspólną: $object');
            } else if (object is List) {
              // Backend wysyła listę kart
              cardsToAdd = List<String>.from(object);
              print('Otrzymano listę kart wspólnych: $cardsToAdd');
            } else {
              print('Nieznany format community_cards: $object');
              return;
            }

            // KLUCZOWA LOGIKA - sprawdź czy już opóźniamy karty
            if (_delayingCommunityCards) {
              // Jesteśmy w trakcie opóźnienia - AKUMULUJ karty
              print('Akumuluję karty do pending (opóźnienie w toku): $cardsToAdd');
              _pendingCommunityCards.addAll(cardsToAdd);
              print('Pending cards teraz: $_pendingCommunityCards');
            } else {
              // Pierwsza karta w nowej fazie - ROZPOCZNIJ opóźnienie
              print('NOWA FAZA - rozpoczynam opóźnienie 3s dla kart: $cardsToAdd');

              // Zapisz karty jako pending
              _pendingCommunityCards = List<String>.from(cardsToAdd);
              _delayingCommunityCards = true;

              // WAŻNE - Zablokuj isMyTurn natychmiast
              updateState(recalculateMyTurn: true);

              // Uruchom timer 3s (anuluj poprzedni na wszelki wypadek)
              _communityCardsTimer?.cancel();
              _communityCardsTimer = Timer(const Duration(seconds: 3), () {
                _showPendingCommunityCards();
              });

              print('Timer 3s uruchomiony, pending cards: $_pendingCommunityCards');
            }
            return;
          }

          // NOWE - Obsługa kart do pokazania w SHOWDOWN (może przyjść też przez user topic)
          if (payload['type'] == 'cards_to_show') {
            final cardsMap = payload['object'] as Map<String, dynamic>? ?? {};
            final convertedMap = <String, List<String>>{};
            cardsMap.forEach((email, cards) {
              if (cards is List) {
                convertedMap[email] = List<String>.from(cards);
              }
            });
            print('Otrzymano karty do pokazania (user topic): $convertedMap');
            _handleCardsToShow(convertedMap);
            return;
          }

          // ZMIENIONE - Obsługa zwycięzców (może przyjść też przez user topic)
          if (payload['type'] == 'winner') {
            final winnersObject = payload['object'];
            if (winnersObject is List) {
              final winnersDto = winnersObject.map((w) {
                if (w is Map<String, dynamic>) {
                  return WinnerDTO.fromJson(w);
                }
                return null;
              }).whereType<WinnerDTO>().toList();

              print('Otrzymano zwycięzców (winner, user topic): ${winnersDto.map((w) => w.toString()).toList()}');
              _handleWinners(winnersDto, isAllIn: false);
            } else {
              print('Nieznany format winner (user topic): $winnersObject');
            }
            return;
          }

          // NOWE - Obsługa zwycięzców ALL IN (może przyjść też przez user topic)
          if (payload['type'] == 'winner_allin') {
            final winnersObject = payload['object'];
            if (winnersObject is List) {
              final winnersDto = winnersObject.map((w) {
                if (w is Map<String, dynamic>) {
                  return WinnerDTO.fromJson(w);
                }
                return null;
              }).whereType<WinnerDTO>().toList();

              print('Otrzymano zwycięzców (winner_allin, user topic): ${winnersDto.map((w) => w.toString()).toList()}');
              _handleWinners(winnersDto, isAllIn: true);
            } else {
              print('Nieznany format winner_allin (user topic): $winnersObject');
            }
            return;
          }

          // NOWE - Obsługa showdown_cards (może przyjść też przez user topic)
          if (payload['type'] == 'showdown_cards') {
            final cardsObject = payload['object'];
            List<String> showdownCards;
            if (cardsObject is List) {
              showdownCards = List<String>.from(cardsObject);
            } else {
              print('Nieznany format showdown_cards (user topic): $cardsObject');
              return;
            }
            print('Otrzymano showdown_cards (user topic): $showdownCards');
            _handleShowdownCards(showdownCards);
            return;
          }

          // NOWE - Obsługa wyeliminowanych graczy (może przyjść też przez user topic)
          if (payload['type'] == 'eliminated_players') {
            final eliminatedObject = payload['object'];
            List<String> eliminatedEmails;
            if (eliminatedObject is List) {
              eliminatedEmails = List<String>.from(eliminatedObject);
            } else {
              print('Nieznany format eliminated_players (user topic): $eliminatedObject');
              return;
            }
            print('Otrzymano eliminated_players (user topic): $eliminatedEmails');
            _handleEliminatedPlayers(eliminatedEmails);
            return;
          }

          // NOWE - Obsługa zakończenia gry (może przyjść też przez user topic)
          if (payload['type'] == 'game_finished') {
            final gameFinishedObject = payload['object'] as Map<String, dynamic>? ?? {};
            final ultimateWinner = gameFinishedObject['ultimate_winner'] as String?;
            print('Otrzymano game_finished z ultimate_winner (user topic): $ultimateWinner');
            _handleGameFinished(ultimateWinner);
            return;
          }

          // 3. Obsługa StateDTO (pul/nextPlayerMail/nextPlayerToCall)
          if (payload.containsKey('pot') && payload.containsKey('nextPlayerMail')) {
            try {
              final s = StateDTO.fromJson(payload);
              print('Otrzymano StateDTO z /user: pot=${s.pot}, nextPlayerMail=${s.nextPlayerMail}, nextPlayerToCall=${s.nextPlayerToCall}, actionPlayerMail=${s.actionPlayerMail}, action=${s.action}, chipsLeft=${s.chipsLeft}, chipsInRound=${s.chipsInRound}');

              // NOWA LOGIKA - buforuj StateDTO podczas opóźnienia kart
              if (_delayingCommunityCards) {
                print('BUFORUJĘ StateDTO podczas opóźnienia kart (user topic)');
                print('  Zastosuje po pokazaniu kart');

                // Zapisz StateDTO jako pending - zastosujemy po pokazaniu kart
                _pendingStateDTO = s;

                // ALE aktualizuj pot i akcję gracza natychmiast (widoczne od razu)
                updateState(
                  pot: s.pot,
                  recalculateMyTurn: false, // NIE aktualizujemy isMyTurn podczas blokady
                );

                if (s.actionPlayerMail != null) {
                  _updatePlayerBetsAndChips(
                    email: s.actionPlayerMail!,
                    chipsLeft: s.chipsLeft,
                    chipsInRound: s.chipsInRound,
                    action: s.action,
                  );
                }
              } else {
                // Normalne flow - brak opóźnienia, zastosuj wszystko od razu
                print('Stosuję StateDTO natychmiast (user topic) - brak opóźnienia');
                updateState(
                  pot: s.pot,
                  nextPlayerMail: s.nextPlayerMail,
                  nextPlayerToCall: s.nextPlayerToCall,
                  recalculateMyTurn: true, // WAŻNE - przeliczymy isMyTurn bo nextPlayerMail się zmieniło
                );

                // BLIND LOGIC - aktualizuj gracza jeśli są dane
                if (s.actionPlayerMail != null) {
                  _updatePlayerBetsAndChips(
                    email: s.actionPlayerMail!,
                    chipsLeft: s.chipsLeft,
                    chipsInRound: s.chipsInRound,
                    action: s.action,
                  );
                }
              }

              print('AKTUALNY STAN: ${state.toString()}');
            } catch (e) {
              print("Nieudane parsowanie StateDTO z /user: $e");
            }
            return;
          }

          // 4. Obsługa pełnej mapy graczy!
          if (payload.values.isNotEmpty && payload.values.first is Map<String, dynamic> && (payload.values.first as Map<String, dynamic>).containsKey('seatIndex')) {
            print('PRZED _handlePlayersMap, payload: $payload');
            _handlePlayersMap(payload, me);
            print('PO _handlePlayersMap');
            return;
          }
        }
      });
    }
  }
  // NOWE - ELIMINATION HANDLING METHODS

  void _handleEliminatedPlayers(List<String> eliminatedEmails) {
    print('=== OBSŁUGA ELIMINATED PLAYERS ===');
    print('Wyeliminowani gracze: $eliminatedEmails');

    // Zapisz jako pending - zostaną zaktualizowani w _startNewRound()
    _pendingEliminatedEmails = List<String>.from(eliminatedEmails);
    print('Zapisano eliminated_players jako pending: $_pendingEliminatedEmails');
    print('Gracze poczekają na aktualizację w nowej rundzie');
  }

  void _handleGameFinished(String? ultimateWinner) {
    print('=== OBSŁUGA GAME FINISHED ===');
    print('Ultimate winner: $ultimateWinner');

    // NATYCHMIAST aktualizuj stan - gra zakończona
    updateState(
      gameFinished: true,
      ultimateWinner: ultimateWinner,
      recalculateMyTurn: false,
    );

    print('Gra zakończona - ultimate winner będzie pokazany w overlay');
  }

  // NOWE - SHOWDOWN SEQUENCE METHODS

  void _startShowdownSequence() {
    print('=== ROZPOCZĘTO SEKWENCJĘ SHOWDOWN ===');

    // Anuluj poprzednie timery jeśli istnieją
    _showdownSequenceTimer?.cancel();

    // 3 sekundy oczekiwania na "cards_to_show", "winner", "winner_allin", "showdown_cards", "eliminated_players", "game_finished"
    _showdownSequenceTimer = Timer(const Duration(seconds: 3), () {
      print('Upłynęły 3 sekundy od SHOWDOWN - sprawdzam karty do pokazania');

      if (_pendingRevealedCards.isNotEmpty) {
        // Mamy karty do pokazania - usuń karty lokalnego gracza jeśli są
        final filteredCards = <String, List<String>>{};
        _pendingRevealedCards.forEach((email, cards) {
          if (email != state.localEmail) {
            filteredCards[email] = cards;
          } else {
            print('Pomijam karty lokalnego gracza: $email');
          }
        });

        if (filteredCards.isNotEmpty) {
          print('Pokazuję karty graczy: $filteredCards');
          _showRevealedCards(filteredCards);
        } else {
          print('Brak kart do pokazania (wszystkie odfiltrowane jako lokalne)');
          // NOWE - Sprawdź zwycięzców nawet gdy karty zostały odfiltrowane
          _checkPendingWinners();
        }
      } else {
        print('Brak kart do pokazania - pusta mapa _pendingRevealedCards');
        // NOWE - Sprawdź zwycięzców gdy brak kart do pokazania
        _checkPendingWinners();
      }

      _pendingRevealedCards.clear();
    });
  }

  void _handleCardsToShow(Map<String, List<String>> cardsMap) {
    print('_handleCardsToShow: $cardsMap');
    _pendingRevealedCards = cardsMap;
  }

  void _handleShowdownCards(List<String> showdownCards) {
    print('=== OBSŁUGA SHOWDOWN_CARDS ===');
    print('Otrzymane dodatkowe karty wspólne: $showdownCards');

    // NAPRAWIONE - Zapisujemy karty jako pending zamiast od razu je dodawać
    _pendingShowdownCards = List<String>.from(showdownCards); // Kopia listy
    print('Zapisano showdown_cards jako pending: $_pendingShowdownCards');
  }
  // NOWA METODA - Pokazanie opóźnionych kart wspólnych po 3 sekundach
  void _showPendingCommunityCards() {
    if (_pendingCommunityCards.isEmpty) {
      print('Brak pending community cards do pokazania');
      _delayingCommunityCards = false;
      _pendingStateDTO = null; // Wyczyść też pending StateDTO
      return;
    }

    print('=== POKAZUJĘ OPÓŹNIONE KARTY WSPÓLNE ===');
    print('Liczba kart: ${_pendingCommunityCards.length}');
    print('Karty: $_pendingCommunityCards');
    print('Obecne karty na stole: ${state.communityCards}');
    print('Obecny nextPlayerMail w state: ${state.nextPlayerMail}');
    print('Obecny nextPlayerToCall w state: ${state.nextPlayerToCall}');

    // WAŻNE - Dodaj pending karty do istniejących kart na stole
    final newCommunityCards = List<String>.from([
      ...state.communityCards,
      ..._pendingCommunityCards,
    ]);

    print('Nowe karty na stole: $newCommunityCards');

    // Najpierw odblokuj flagę (WAŻNE - przed updateState!)
    _delayingCommunityCards = false;

    // NOWA LOGIKA - sprawdź czy jest pending StateDTO
    if (_pendingStateDTO != null) {
      print('=== STOSUJĘ BUFOROWANY StateDTO ===');
      print('  nextPlayerMail: ${_pendingStateDTO!.nextPlayerMail}');
      print('  nextPlayerToCall: ${_pendingStateDTO!.nextPlayerToCall}');
      print('  pot: ${_pendingStateDTO!.pot}');

      // Pokaż karty + zastosuj pending StateDTO + reset zakładów
      updateState(
        communityCards: newCommunityCards,
        roundBets: {}, // Reset zakładów w nowej fazie
        pot: _pendingStateDTO!.pot ?? state.pot,
        nextPlayerMail: _pendingStateDTO!.nextPlayerMail,
        nextPlayerToCall: _pendingStateDTO!.nextPlayerToCall,
        recalculateMyTurn: true, // WAŻNE - przelicz isMyTurn z nowymi wartościami
      );

      // Wyczyść pending StateDTO
      _pendingStateDTO = null;
    } else {
      print('=== BRAK PENDING StateDTO - UŻYWAM ISTNIEJĄCYCH WARTOŚCI Z STATE ===');
      print('  Przekazuję nextPlayerMail: ${state.nextPlayerMail}');
      print('  Przekazuję nextPlayerToCall: ${state.nextPlayerToCall}');

      // KLUCZOWA ZMIANA - Przekaż istniejące wartości z state żeby wymuszić przeliczenie!
      updateState(
        communityCards: newCommunityCards,
        roundBets: {}, // Reset zakładów w nowej fazie
        nextPlayerMail: state.nextPlayerMail, // NOWE - przekaż istniejącą wartość!
        nextPlayerToCall: state.nextPlayerToCall, // NOWE - przekaż istniejącą wartość!
        recalculateMyTurn: true, // WAŻNE - przelicz isMyTurn (teraz zadziała!)
      );
    }

    // Wyczyść pending karty (flagę już odblokowaliśmy wcześniej)
    _pendingCommunityCards = [];

    print('Karty pokazane, isMyTurn odblokowane i przeliczone');
  }

  void _showRevealedCards(Map<String, List<String>> cardsMap) {
    print('=== POKAZYWANIE KART GRACZY ===');
    print('Ustawiam revealedCards: $cardsMap');

    // WAŻNE - Czyścimy lastAction I roundBets podczas pokazywania kart
    updateState(
      revealedCards: cardsMap,
      showingRevealedCards: true,
      lastAction: {}, // Czyść akcje podczas pokazywania kart
      roundBets: {}, // NOWE - Czyść zakłady podczas pokazywania kart
      recalculateMyTurn: false,
    );

    print('State po ustawieniu revealedCards: ${state.revealedCards}');

    // Anuluj poprzedni timer jeśli istnieje
    _revealedCardsTimer?.cancel();

    // 4 sekundy na pokazywanie kart
    _revealedCardsTimer = Timer(const Duration(seconds: 4), () {
      print('Koniec pokazywania kart graczy');
      updateState(
        showingRevealedCards: false,
        recalculateMyTurn: false,
      );

      // NOWA LOGIKA - Sprawdź czy są pending showdown cards
      if (_pendingShowdownCards.isNotEmpty) {
        print('Są pending showdown cards: $_pendingShowdownCards - rozpoczynam dodawanie');
        _addShowdownCardsSequentiallyAndThenShowWinners();
      } else {
        // Sprawdź czy są oczekujący zwycięzcy
        if (_pendingWinners.isNotEmpty) {
          print('Są oczekujący zwycięzcy: ${_pendingWinners.length} - pokazuję ich teraz');
          _showWinners();
        } else {
          print('Brak oczekujących zwycięzców');
        }
      }
    });
  }

  // POPRAWIONA METODA - Obsługa specjalnej logiki dla 5 kart (PREFLOP ALL_IN)
  Future<void> _addShowdownCardsSequentiallyAndThenShowWinners() async {
    final cardsToAdd = List<String>.from(_pendingShowdownCards);
    _pendingShowdownCards.clear();

    print('Rozpoczynam dodawanie ${cardsToAdd.length} kart showdown');

    if (cardsToAdd.length == 5) {
      // SPECJALNA LOGIKA: 5 kart = PREFLOP ALL_IN → FLOP (3 karty razem) + TURN + RIVER
      print('Wykryto 5 kart (PREFLOP ALL_IN) - pokazuję FLOP (3 karty razem)');

      // FLOP: Dodaj pierwsze 3 karty jednocześnie (animacje będą działać automatycznie)
      final flop = cardsToAdd.sublist(0, 3);
      final newCommunityCardsFlop = List<String>.from([...state.communityCards, ...flop]);
      updateState(
        communityCards: newCommunityCardsFlop,
        recalculateMyTurn: false,
      );
      print('Dodano FLOP: $flop');

      // Czekaj 5 sekund po FLOP
      await Future.delayed(const Duration(seconds: 5));

      // TURN: Dodaj 4. kartę
      if (!isClosed) {
        final turn = cardsToAdd[3];
        final newCommunityCardsTurn = List<String>.from([...state.communityCards, turn]);
        print('Dodaję TURN: $turn');
        updateState(
          communityCards: newCommunityCardsTurn,
          recalculateMyTurn: false,
        );
      }

      // Czekaj 3 sekundy po TURN
      await Future.delayed(const Duration(seconds: 3));

      // RIVER: Dodaj 5. kartę
      if (!isClosed) {
        final river = cardsToAdd[4];
        final newCommunityCardsRiver = List<String>.from([...state.communityCards, river]);
        print('Dodaję RIVER: $river');
        updateState(
          communityCards: newCommunityCardsRiver,
          recalculateMyTurn: false,
        );
      }
    } else {
      // STANDARDOWA LOGIKA: Dodaj karty po jednej co 3 sekundy (TURN/RIVER)
      for (int i = 0; i < cardsToAdd.length; i++) {
        if (i > 0) {
          // Czekaj 3 sekundy przed następną kartą (oprócz pierwszej)
          await Future.delayed(const Duration(seconds: 3));
        }

        if (!isClosed) {
          final cardToAdd = cardsToAdd[i];
          final newCommunityCards = List<String>.from([...state.communityCards, cardToAdd]);
          print('Dodaję kartę showdown ${i + 1}/${cardsToAdd.length}: $cardToAdd');

          updateState(
            communityCards: newCommunityCards,
            recalculateMyTurn: false,
          );
        }
      }
    }

    print('Zakończono dodawanie wszystkich kart showdown');

    // Czekaj 3 sekundy po ostatniej karcie
    await Future.delayed(const Duration(seconds: 3));

    // Pokaż zwycięzców
    if (_pendingWinners.isNotEmpty) {
      print('Pokazuję zwycięzców po showdown_cards: ${_pendingWinners.length}');
      _showWinners();
    } else {
      print('Brak oczekujących zwycięzców po showdown_cards');
    }
  }

  // ZMIENIONE - Nowa sygnatura z WinnerDTO i flagą isAllIn
  void _handleWinners(List<WinnerDTO> winnersDto, {required bool isAllIn}) {
    print('=== OBSŁUGA ZWYCIĘZCÓW ===');
    print('Zwycięzcy: ${winnersDto.map((w) => w.toString()).toList()}');
    print('Czy ALL IN: $isAllIn');

    // Zapisz jako oczekujących
    _pendingWinners = List<WinnerDTO>.from(winnersDto);
    _isAllInWinners = isAllIn;
    _currentAllInWinnerIndex = 0;

    print('Zapisano zwycięzców jako oczekujących: ${_pendingWinners.length} graczy');
    print('Zwycięzcy poczekają na koniec sekwencji SHOWDOWN (karty lub timeout)');
  }

  // NOWA METODA - Sprawdź i pokaż oczekujących zwycięzców
  void _checkPendingWinners() {
    if (_pendingWinners.isNotEmpty) {
      print('Sprawdzam oczekujących zwycięzców: ${_pendingWinners.length} - pokazuję ich teraz');
      _showWinners();
    } else {
      print('Brak oczekujących zwycięzców do pokazania');
    }
  }

  // CAŁKOWICIE PRZEPISANA METODA - Obsługa standard vs ALL IN
  void _showWinners() {
    print('=== ROZPOCZYNAM POKAZYWANIE ZWYCIĘZCÓW ===');
    print('Liczba zwycięzców: ${_pendingWinners.length}');
    print('Czy ALL IN: $_isAllInWinners');

    if (_isAllInWinners && _pendingWinners.length > 1) {
      // Sekwencja ALL IN - pokazuj po kolei po 4 sekundy każdy
      print('Sekwencja ALL IN z ${_pendingWinners.length} zwycięzcami');
      _showAllInWinnersSequentially();
    } else {
      // Standard - wszyscy naraz przez 6 sekund (lub 1 ALL IN przez 6s)
      print('Standard/pojedynczy ALL IN - wszyscy naraz przez 6 sekund');
      _showStandardWinners();
    }
  }

  // NOWA METODA - Standard winners (wszyscy naraz, 6s)
  void _showStandardWinners() {
    print('=== POKAZUJĘ STANDARD WINNERS ===');

    // Przygotuj dane
    final winnerEmails = _pendingWinners.map((w) => w.winnerEmail).toList();
    final winnerWinSizes = <String, int>{};

    for (final winner in _pendingWinners) {
      winnerWinSizes[winner.winnerEmail] = winner.winSize;
    }

    print('Winner emails: $winnerEmails');
    print('Winner winSizes: $winnerWinSizes');

    // Aktualizuj chips WSZYSTKICH zwycięzców NATYCHMIAST
    final updatedAllPlayers = state.allPlayers.map((p) {
      final winner = _pendingWinners.firstWhere(
            (w) => w.winnerEmail == p.email,
        orElse: () => WinnerDTO(winnerEmail: '', winnerChips: 0, winSize: 0),
      );

      if (winner.winnerEmail.isNotEmpty) {
        print('Aktualizuję żetony dla ${p.email}: ${p.chips} → ${winner.winnerChips}');
        return p.copyWith(chips: winner.winnerChips);
      }
      return p;
    }).toList();

    // Sprawdź czy lokalny gracz wygrywa
    int? newMyChips = state.myChips;
    final localWinner = _pendingWinners.firstWhere(
          (w) => w.winnerEmail == state.localEmail,
      orElse: () => WinnerDTO(winnerEmail: '', winnerChips: 0, winSize: 0),
    );
    if (localWinner.winnerEmail.isNotEmpty) {
      newMyChips = localWinner.winnerChips;
      print('Aktualizuję żetony lokalnego gracza: ${state.myChips} → $newMyChips');
    }

    // Aktualizuj stan z nowymi żetonami + pokazywaniem zwycięzców
    updateState(
      allPlayers: updatedAllPlayers,
      myChips: newMyChips,
      winners: winnerEmails,
      winnerWinSizes: winnerWinSizes, // NOWE
      showingWinners: true,
      recalculateMyTurn: false,
    );

    // Anuluj poprzedni timer jeśli istnieje
    _winnersTimer?.cancel();

    // 6 sekund pokazywania
    _winnersTimer = Timer(const Duration(seconds: 6), () {
      print('Koniec pokazywania zwycięzców (standard)');
      _finishShowingWinners();
    });
  }

  // NOWA METODA - ALL IN winners sekwencyjnie (po 4s każdy lub 6s dla jednego)
  void _showAllInWinnersSequentially() {
    print('=== ROZPOCZYNAM SEKWENCJĘ ALL IN WINNERS ===');
    _currentAllInWinnerIndex = 0;
    _showNextAllInWinner();
  }

  // NOWA METODA - Pokaż kolejnego zwycięzcę ALL IN
  void _showNextAllInWinner() {
    if (_currentAllInWinnerIndex >= _pendingWinners.length) {
      print('Zakończono sekwencję ALL IN - wszyscy zwycięzcy pokazani');
      _finishShowingWinners();
      return;
    }

    final currentWinner = _pendingWinners[_currentAllInWinnerIndex];
    print('=== POKAZUJĘ ALL IN WINNER ${_currentAllInWinnerIndex + 1}/${_pendingWinners.length} ===');
    print('Winner: ${currentWinner.toString()}');

    // Aktualizuj chips TEGO zwycięzcy
    final updatedAllPlayers = state.allPlayers.map((p) {
      if (p.email == currentWinner.winnerEmail) {
        print('Aktualizuję żetony dla ${p.email}: ${p.chips} → ${currentWinner.winnerChips}');
        return p.copyWith(chips: currentWinner.winnerChips);
      }
      return p;
    }).toList();

    // Sprawdź czy to lokalny gracz
    int? newMyChips = state.myChips;
    if (currentWinner.winnerEmail == state.localEmail) {
      newMyChips = currentWinner.winnerChips;
      print('Aktualizuję żetony lokalnego gracza: ${state.myChips} → $newMyChips');
    }

    // Aktualizuj stan - TYLKO JEDEN zwycięzca pokazywany
    updateState(
      allPlayers: updatedAllPlayers,
      myChips: newMyChips,
      winners: [currentWinner.winnerEmail], // TYLKO jeden!
      winnerWinSizes: {currentWinner.winnerEmail: currentWinner.winSize}, // NOWE
      showingWinners: true,
      recalculateMyTurn: false,
    );

    // Anuluj poprzedni timer jeśli istnieje
    _allInWinnerTimer?.cancel();

    // 4 sekundy na tego zwycięzcę
    _allInWinnerTimer = Timer(const Duration(seconds: 4), () {
      print('Koniec pokazywania zwycięzcy ${_currentAllInWinnerIndex + 1}/${_pendingWinners.length}');
      _currentAllInWinnerIndex++;
      _showNextAllInWinner(); // Rekurencyjnie pokaż następnego
    });
  }

  // NOWA METODA - Wspólne zakończenie pokazywania zwycięzców
  void _finishShowingWinners() {
    print('=== ZAKOŃCZENIE POKAZYWANIA ZWYCIĘZCÓW ===');

    // Reset showingWinners
    updateState(
      showingWinners: false,
      recalculateMyTurn: false,
    );

    // Wyczyść pending winners
    _pendingWinners.clear();
    _isAllInWinners = false;
    _currentAllInWinnerIndex = 0;

    // Sprawdź czy gra zakończona
    if (state.gameFinished && state.ultimateWinner != null) {
      print('Gra zakończona - NIE rozpoczynam nowej rundy, pokazuję ultimate winner overlay');
      // NIE wywołuj _startNewRound(), overlay będzie obsłużony w GameScreen
    } else {
      print('Gra trwa - rozpoczynam nową rundę');
      _startNewRound();
    }
  }

  void _startNewRound() {
    print('=== ROZPOCZYNAM NOWĄ RUNDĘ ===');
    _stopActionTimer();

    // NAPRAWIONE - Reset wszystkich stanów przed wysłaniem requestu
    _pendingRevealedCards.clear();
    _pendingWinners.clear();
    _pendingShowdownCards.clear();
    _newRoundInProgress = true; // NOWE - ustaw flagę nowej rundy
    _isAllInWinners = false; // NOWE
    _currentAllInWinnerIndex = 0; // NOWE
    _communityCardsTimer?.cancel();
    _pendingCommunityCards.clear();
    _delayingCommunityCards = false;
    _pendingStateDTO = null;

    // POPRAWKA: Reset isFolded dla wszystkich graczy w nowej rundzie
    final resetPlayers = state.players.map((p) => p.copyWith(isFolded: false)).toList();
    final resetAllPlayers = state.allPlayers.map((p) => p.copyWith(isFolded: false)).toList();

    // NOWE - Aktualizuj eliminatedEmails z pending data
    final newEliminatedEmails = List<String>.from(_pendingEliminatedEmails);
    _pendingEliminatedEmails.clear();

    updateState(
      winners: [],
      winnerWinSizes: {}, // NOWE - reset winSizes
      revealedCards: {},
      showingRevealedCards: false,
      communityCards: [], // Reset kart wspólnych
      cardsVisible: false, // Ukryj karty
      myCards: [], // Wyczyść lokalne karty
      // NOWE - Reset stanów rundy
      players: resetPlayers, // POPRAWKA: Reset isFolded
      allPlayers: resetAllPlayers, // POPRAWKA: Reset isFolded
      eliminatedEmails: newEliminatedEmails, // NOWE: Aktualizuj eliminated players
      roundBets: {}, // Reset żetonów graczy w rundzie
      lastAction: {}, // Reset ostatnich akcji graczy
      dealerMail: null, // Reset dealera (przyjdzie nowy z serwera)
      pot: 0, // Reset puli (przyjdzie nowa z serwera)
      nextPlayerMail: null, // Reset następnego gracza (przyjdzie z serwera)
      nextPlayerToCall: 0, // Reset kwoty do call (przyjdzie z serwera)
      recalculateMyTurn: false,
    );

    // NAPRAWIONE - Wyślij request NATYCHMIAST bez await (nie może się zawiesić)
    _sendStartNewRoundRequest();

    print('Request wysłany, czekam na dane z serwera...');
    // Sekwencja dźwięku będzie uruchomiona gdy przyjdą karty z serwera
  }

  // NAPRAWIONE - Metoda wysyłania requestu o start nowej rundy (bez async)
  void _sendStartNewRoundRequest() {
    try {
      final tableCode = _tableCode;
      if (tableCode == null) {
        print('Brak tableCode - nie mogę wysłać requestu o nową rundę');
        return;
      }

      final storage = _storage;
      storage.read(key: 'userEmail').then((mail) {
        if (mail == null || mail.isEmpty) {
          print('Brak userEmail - nie mogę wysłać requestu o nową rundę');
          return;
        }

        print('Wysyłam request o nową rundę - email: $mail, tableCode: $tableCode');

        final dto = ActionDTO(
          action: "CHECK",
          playerEmail: mail,
          chips: 0,
          tableName: null,
          tableCode: tableCode,
        );

        // NAPRAWIONE - Używam sendFireAndForget żeby nie czekać na odpowiedź i nie zawiesić się
        _repo.sendFireAndForget<ActionDTO>(
          '/app/startRound',
          dto,
              (d) => d.toJson(),
        );

        print('Request o nową rundę wysłany pomyślnie (fire and forget)');
      }).catchError((e) {
        print('Błąd podczas pobierania userEmail: $e');
      });
    } catch (e) {
      print('Błąd podczas wysyłania requestu o nową rundę: $e');
    }
  }

  Future<void> _playNewRoundSequence() async {
    try {
      print('Rozpoczynam sekwencję nowej rundy z kartami: $_pendingCards');

      // Czekamy 1 sekundę (identycznie jak w _playCardShuffleSequence)
      await Future.delayed(const Duration(seconds: 1));

      // Odtwarzamy dźwięk tasowania kart
      print('Odtwarzam dźwięk tasowania kart dla nowej rundy');
      await _audioPlayer.play(AssetSource('sounds/schuffle_cards.mp3'));

      // Czekamy na zakończenie odtwarzania (~3 sekundy) + 0.5 sekundy
      await Future.delayed(const Duration(milliseconds: 3500));

      print('Dźwięk tasowania zakończony, pokazuję karty dla nowej rundy');

      // Pokazujemy karty - używamy _pendingCards które już są ustawione
      updateState(
        myCards: _pendingCards,
        cardsVisible: true,
        recalculateMyTurn: false,
      );

      print('Stan po rozpoczęciu nowej rundy: cardsVisible=${state.cardsVisible}, myCards=${state.myCards}');

      // Czyścimy pending cards i resetujemy flagę
      _pendingCards = [];
      _newRoundInProgress = false;

    } catch (e) {
      print('Błąd podczas sekwencji nowej rundy: $e');

      // W przypadku błędu z dźwiękiem, i tak pokazuj karty
      updateState(
        myCards: _pendingCards,
        cardsVisible: true,
        recalculateMyTurn: false,
      );
      _pendingCards = [];
      _newRoundInProgress = false; // Reset flagi nawet przy błędzie
    }
  }

  void _updatePlayerBetsAndChips({
    required String email,
    int? chipsLeft,
    int? chipsInRound,
    String? action,
  }) {
    final updatedPlayers = state.players.map((p) {
      if (p.email == email) {
        return p.copyWith(
          chips: chipsLeft ?? p.chips,
          chipsInRound: chipsInRound ?? p.chipsInRound,
          isFolded: action == 'FOLD' ? true : p.isFolded,
        );
      }
      return p;
    }).toList();

    final updatedAllPlayers = state.allPlayers.map((p) {
      if (p.email == email) {
        return p.copyWith(
          chips: chipsLeft ?? p.chips,
          chipsInRound: chipsInRound ?? p.chipsInRound,
          isFolded: action == 'FOLD' ? true : p.isFolded,
        );
      }
      return p;
    }).toList();

    int? myChips = state.myChips;
    if (email == state.localEmail) {
      myChips = chipsLeft ?? myChips;
    }

    final lastAction = {...state.lastAction};
    if (action != null && action.isNotEmpty) {
      lastAction[email] = action;
      print('Zaktualizowano lastAction dla $email: $action');

      // Odtwórz dźwięk dla akcji innych graczy (nie naszych)
      if (email != state.localEmail) {
        _playActionSound(action);
      }

      // NOWE - Uruchom timer do usunięcia akcji po 4 sekundach (tylko dla innych graczy)
      if (email != state.localEmail) {
        _startActionRemovalTimer(email);
      }
    }

    final roundBets = {...state.roundBets};
    if (chipsInRound != null) roundBets[email] = chipsInRound;

    updateState(
      players: updatedPlayers,
      allPlayers: updatedAllPlayers,
      myChips: myChips,
      lastAction: lastAction,
      roundBets: roundBets,
      recalculateMyTurn: false,
    );
  }

  void _startActionRemovalTimer(String playerEmail) {
    // Anuluj poprzedni timer dla tego gracza jeśli istnieje
    _actionTimers[playerEmail]?.cancel();

    // Uruchom nowy timer na 4 sekundy
    _actionTimers[playerEmail] = Timer(const Duration(seconds: 3), () {
      print('Usuwam akcję dla gracza $playerEmail po 3 sekundach');

      // Usuń akcję z mapy
      final lastAction = {...state.lastAction};
      lastAction.remove(playerEmail);

      // Zaktualizuj stan
      updateState(
        lastAction: lastAction,
        recalculateMyTurn: false,
      );

      // Usuń timer z mapy
      _actionTimers.remove(playerEmail);
    });

    print('Uruchomiono timer usuwania akcji dla gracza $playerEmail (3 sekundy)');
  }


  Future<void> startRound() async {
    final tableCode = _tableCode;
    if (tableCode == null) return;
    final mail = await _storage.read(key: 'userEmail') ?? '';
    final dto = ActionDTO(
      action: "CHECK",
      playerEmail: mail,
      chips: 0,
      tableName: null,
      tableCode: tableCode,
    );

    // Wysyłamy żądanie startu gry
    await _repo.sendRequest<ActionDTO, dynamic>(
      '/app/startRound',
      dto,
          (d) => d.toJson(),
          (r) => r,
    );

    // Jeśli gra jeszcze nie wystartowała (według WS), uruchom lokalnie.
    // Jeśli WS dotarł szybciej, to gameStarted jest już true, a sekwencja już ruszyła (w listenerze).
    if (!state.gameStarted) {
      updateState(gameStarted: true, recalculateMyTurn: false);
      print('AKTUALNY STAN (startRound): ${state.toString()}');

      // Uruchamiamy sekwencję dźwięku i kart
      _playCardShuffleSequence();
    } else {
      print('Gra już wystartowała (przez WS) - pomijam lokalny startRound, aby uniknąć podwójnego tasowania');
    }
  }

  Future<void> _playCardShuffleSequence() async {
    try {
      print('Rozpoczynam sekwencję tasowania kart...');

      // Czekamy 1 sekundę po kliknięciu startu
      await Future.delayed(const Duration(seconds: 1));

      // Odtwarzamy dźwięk tasowania kart
      print('Odtwarzam dźwięk tasowania kart');
      await _audioPlayer.play(AssetSource('sounds/schuffle_cards.mp3'));

      // Czekamy na zakończenie odtwarzania (zakładam ~3 sekundy) + 0.5 sekundy
      await Future.delayed(const Duration(milliseconds: 3500));

      print('Dźwięk tasowania zakończony, pokazuję karty dla wszystkich graczy');

      // Teraz pokazujemy karty - zarówno lokalne jak i przeciwników
      updateState(
        myCards: _pendingCards,
        cardsVisible: true,
        recalculateMyTurn: false,
      );

      print('Stan po pokazaniu kart: cardsVisible=${state.cardsVisible}, myCards=${state.myCards}');

      // Czyścimy pending cards
      _pendingCards = [];

    } catch (e) {
      print('Błąd podczas odtwarzania dźwięku tasowania: $e');
      // Jeśli jest błąd z dźwiękiem, i tak pokazujemy karty
      updateState(
        myCards: _pendingCards,
        cardsVisible: true,
        recalculateMyTurn: false,
      );
      print('Stan po błędzie (pokazanie kart): cardsVisible=${state.cardsVisible}, myCards=${state.myCards}');
      _pendingCards = [];
    }
  }

  Future<void> sendPlayersRequest() async {
    final email = await _storage.read(key: 'userEmail') ?? '';
    final tableCodeStr = await _storage.read(key: 'tableCode');
    int? tableCode = _tableCode;
    if (tableCodeStr != null) {
      tableCode = int.tryParse(tableCodeStr) ?? tableCode;
    }
    if (email.isEmpty || tableCode == null) {
      print("Nie można pobrać email lub tableCode!");
      return;
    }
    final dto = ActionDTO(
      action: 'CHECK',
      playerEmail: email,
      chips: 0,
      tableName: null,
      tableCode: tableCode,
    );
    await _repo.sendRequest<ActionDTO, dynamic>(
      '/app/data/players',
      dto,
          (d) => d.toJson(),
          (r) => r,
    );
    print("Wysłano żądanie mapy graczy przez JOINERA!");
  }

  Future<void> leaveTable() async {
    try {
      // Pobieramy dane z secure storage
      final mail = await _storage.read(key: 'userEmail') ?? '';
      final tableCodeStr = await _storage.read(key: 'tableCode');

      if (mail.isEmpty || tableCodeStr == null) {
        print("Nie można pobrać email lub tableCode z storage!");
        return;
      }

      final tableCode = int.tryParse(tableCodeStr);
      if (tableCode == null) {
        print("Nieprawidłowy format tableCode: $tableCodeStr");
        return;
      }

      print("Opuszczam stół - email: $mail, tableCode: $tableCode");

      // Usuwamy TYLKO tableCode z storage (WebSocket pozostaje połączony!)
      await _storage.delete(key: 'tableCode');

      // Tworzymy ActionDTO zgodnie z wymaganiami
      final dto = ActionDTO(
        action: "CHECK",
        playerEmail: mail,
        chips: 0,
        tableName: null,
        tableCode: tableCode,
      );

      // Wysyłamy wiadomość na serwer
      _repo.sendFireAndForget<ActionDTO>(
        '/app/leaveTable',
        dto,
            (d) => d.toJson(),
      );

      // Resetujemy stan gry (ale WebSocket zostaje!)
      emit(const GameState());

      print('Gracz opuścił stół, usunięto tableCode z storage, WebSocket pozostaje połączony');

    } catch (e) {
      print('Błąd podczas opuszczania stołu: $e');
      // W przypadku błędu i tak resetujemy stan lokalnie
      emit(const GameState());
    }
  }
  void showRaiseSlider() {
    // NOWA LOGIKA - minRaise = nextPlayerToCall + 10
    final minRaise = state.nextPlayerToCall + 10;
    final maxRaise = state.myChips;

    // Walidacja - jeśli minRaise > maxRaise, użyj maxRaise (ALL IN)
    final initialAmount = minRaise > maxRaise ? maxRaise : minRaise;

    print('Pokazuję suwak RAISE:');
    print('  nextPlayerToCall: ${state.nextPlayerToCall}');
    print('  minRaise: $minRaise (nextPlayerToCall + 10)');
    print('  maxRaise: $maxRaise (moje żetony)');
    print('  initialAmount: $initialAmount');

    updateState(
      showingRaiseSlider: true,
      raiseAmount: initialAmount,
      recalculateMyTurn: false,
    );
  }

  void hideRaiseSlider() {
    updateState(showingRaiseSlider: false, recalculateMyTurn: false);
  }

  void updateRaiseAmount(int amount) {
    updateState(raiseAmount: amount, recalculateMyTurn: false);
  }

  // POMOCNICZE METODY DLA DŹWIĘKÓW
  Future<void> _playActionSound(String action) async {
    try {
      String soundFile;
      switch (action.toUpperCase()) {
        case 'FOLD':
          soundFile = 'sounds/FOLD.mp3';
          break;
        case 'CHECK':
          soundFile = 'sounds/CHECK.mp3';
          break;
        case 'CALL':
          soundFile = 'sounds/CALL.mp3';
          break;
        case 'RISE':
        case 'RAISE':
          soundFile = 'sounds/RISE.mp3';
          break;
        case 'ALL_IN':
          soundFile = 'sounds/ALL_IN.mp3';
          break;
        default:
          print('Nieznana akcja dla dźwięku: $action');
          return;
      }

      print('Odtwarzam dźwięk dla akcji $action: $soundFile');
      await _audioPlayer.play(AssetSource(soundFile));
    } catch (e) {
      print('Błąd odtwarzania dźwięku dla akcji $action: $e');
    }
  }

  // AKCJE GRACZA - wysyłanie na serwer

  Future<void> performFoldAction() async {
    try {
      // Odtwórz dźwięk FOLD
      await _playActionSound('FOLD');

      final mail = await _storage.read(key: 'userEmail') ?? '';
      final tableCodeStr = await _storage.read(key: 'tableCode');
      final tableCode = int.tryParse(tableCodeStr ?? '');

      if (mail.isEmpty || tableCode == null) {
        print("Nie można pobrać email lub tableCode dla akcji FOLD!");
        return;
      }

      print('Wysyłam akcję FOLD - email: $mail, tableCode: $tableCode');

      final dto = ActionDTO(
        action: "FOLD",
        playerEmail: mail,
        chips: 0,
        tableName: null,
        tableCode: tableCode,
      );

      await _repo.sendRequest<ActionDTO, dynamic>(
        '/app/action',
        dto,
            (d) => d.toJson(),
            (r) => r,
      );
      // NOWE - Stop action timer
      _stopActionTimer();
      // Ukrywamy przyciski akcji
      updateState(isMyTurn: false, showingRaiseSlider: false, recalculateMyTurn: false);

      print('Akcja FOLD wysłana pomyślnie');
    } catch (e) {
      print('Błąd podczas wysyłania akcji FOLD: $e');
      // W przypadku błędu i tak ukrywamy przyciski
      updateState(isMyTurn: false, showingRaiseSlider: false, recalculateMyTurn: false);
    }
  }

  Future<void> performCheckCallAction() async {
    try {
      final mail = await _storage.read(key: 'userEmail') ?? '';
      final tableCodeStr = await _storage.read(key: 'tableCode');
      final tableCode = int.tryParse(tableCodeStr ?? '');

      if (mail.isEmpty || tableCode == null) {
        print("Nie można pobrać email lub tableCode dla akcji CHECK/CALL!");
        return;
      }

      // Określamy ile żetonów trzeba wysłać
      final chipsToSend = state.nextPlayerToCall; // 0 dla CHECK, >0 dla CALL
      final isCall = chipsToSend > 0;
      final actionName = isCall ? 'CALL' : 'CHECK';

      // Odtwórz odpowiedni dźwięk
      await _playActionSound(actionName);

      print('Wysyłam akcję $actionName - email: $mail, tableCode: $tableCode, chips: $chipsToSend');

      final dto = ActionDTO(
        action: "CHECK",
        playerEmail: mail,
        chips: chipsToSend,
        tableName: null,
        tableCode: tableCode,
      );

      await _repo.sendRequest<ActionDTO, dynamic>(
        '/app/action',
        dto,
            (d) => d.toJson(),
            (r) => r,
      );
      // NOWE - Stop action timer
      _stopActionTimer();
      // Ukrywamy przyciski akcji
      updateState(isMyTurn: false, showingRaiseSlider: false, recalculateMyTurn: false);

      print('Akcja $actionName wysłana pomyślnie');
    } catch (e) {
      print('Błąd podczas wysyłania akcji CHECK/CALL: $e');
      // W przypadku błędu i tak ukrywamy przyciski
      updateState(isMyTurn: false, showingRaiseSlider: false, recalculateMyTurn: false);
    }
  }

  Future<void> performRaiseAction() async {
    try {
      final mail = await _storage.read(key: 'userEmail') ?? '';
      final tableCodeStr = await _storage.read(key: 'tableCode');
      final tableCode = int.tryParse(tableCodeStr ?? '');

      if (mail.isEmpty || tableCode == null) {
        print("Nie można pobrać email lub tableCode dla akcji RAISE!");
        return;
      }

      final raiseAmount = state.raiseAmount;
      final isAllIn = raiseAmount >= state.myChips;
      final action = isAllIn ? "ALL_IN" : "RISE";

      // Odtwórz odpowiedni dźwięk
      await _playActionSound(action);

      print('Wysyłam akcję $action - email: $mail, tableCode: $tableCode, chips: $raiseAmount');

      final dto = ActionDTO(
        action: action,
        playerEmail: mail,
        chips: raiseAmount,
        tableName: null,
        tableCode: tableCode,
      );

      await _repo.sendRequest<ActionDTO, dynamic>(
        '/app/action',
        dto,
            (d) => d.toJson(),
            (r) => r,
      );
      // NOWE - Stop action timer
      _stopActionTimer();
      // Ukrywamy przyciski akcji
      updateState(isMyTurn: false, showingRaiseSlider: false, recalculateMyTurn: false);

      print('Akcja $action wysłana pomyślnie');
    } catch (e) {
      print('Błąd podczas wysyłania akcji RAISE: $e');
      // W przypadku błędu i tak ukrywamy przyciski
      updateState(isMyTurn: false, showingRaiseSlider: false, recalculateMyTurn: false);
    }
  }
  void _startActionTimerDirectly() {
    // Sprawdź czy dalej jest kolej gracza
    if (!state.isMyTurn) {
      print('=== NIE STARTUJĘ TIMERA - brak kolei gracza ===');
      return;
    }

    // Sprawdź czy karty są widoczne
    if (!state.cardsVisible) {
      print('=== NIE STARTUJĘ TIMERA - karty nie widoczne ===');
      return;
    }

    // Sprawdź czy timer już nie działa (podwójna ochrona)
    if (_actionTimer != null && _actionTimer!.isActive) {
      print('=== TIMER JUŻ DZIAŁA - pomijam start ===');
      return;
    }

    print('=== STARTUJĘ ACTION TIMER (synchronicznie z cardsVisible!) ===');

    // Anuluj poprzedni timer jeśli istnieje
    _actionTimer?.cancel();

    // Start z 30 sekund
    int remainingSeconds = 30;

    // Aktualizuj stan początkowy
    updateState(
      actionTimerSeconds: remainingSeconds,
      actionTimerUrgent: false,
      actionTimerGracePeriod: false,
      recalculateMyTurn: false,
    );

    // Timer co 1 sekundę
    _actionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remainingSeconds--;
      print('Action timer tick: $remainingSeconds sekund');

      // Sprawdź czy dalej jest kolej gracza (może się zmienić)
      if (!state.isMyTurn) {
        print('Timer anulowany - koniec kolei gracza');
        timer.cancel();
        _stopActionTimer();
        return;
      }

      if (remainingSeconds >= 1) {
        // Normalny countdown 30→1
        final isUrgent = remainingSeconds <= 10;
        updateState(
          actionTimerSeconds: remainingSeconds,
          actionTimerUrgent: isUrgent,
          actionTimerGracePeriod: false,
          recalculateMyTurn: false,
        );
      } else if (remainingSeconds >= -4) {
        // Grace period: 0, -1, -2, -3, -4 (5 sekund)
        print('Grace period: ${remainingSeconds} (pozostało ${-remainingSeconds + 5} sekund do auto-FOLD)');
        updateState(
          actionTimerSeconds: null, // Ukryj timer
          actionTimerUrgent: false,
          actionTimerGracePeriod: true,
          recalculateMyTurn: false,
        );
      } else {
        // -5: Czas upłynął - AUTO FOLD
        print('CZAS UPŁYNĄŁ! Wykonuję auto-FOLD');
        timer.cancel();
        _performAutoFold();
      }
    });
  }
  void _stopActionTimer() {
    print('=== STOPUJĘ ACTION TIMER ===');

    if (_actionTimer != null) {
      _actionTimer?.cancel();
      _actionTimer = null;
      print('Timer anulowany i wyzerowany');
    } else {
      print('Timer już był null');
    }

    // Wyczyść stan timera
    if (state.actionTimerSeconds != null || state.actionTimerUrgent || state.actionTimerGracePeriod) {
      print('Czyszczę stan timera w state');
      updateState(
        actionTimerSeconds: null,
        actionTimerUrgent: false,
        actionTimerGracePeriod: false,
        recalculateMyTurn: false,
      );
    }
  }

  Future<void> _performAutoFold() async {
    print('=== WYKONUJÊ AUTO-FOLD (TIMEOUT) ===');

    // Wyczyść timer
    _stopActionTimer();

    // Wykonaj standardowy FOLD (z dźwiękiem i wysyłką)
    await performFoldAction();

    print('Auto-FOLD wykonany pomyślnie');
  }
}