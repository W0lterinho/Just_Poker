import 'package:equatable/equatable.dart';

import '../../models/player_dto.dart';

class GameState extends Equatable {
  final bool gameStarted;
  final List<PlayerDto> players; // tylko przeciwnicy!
  final List<String> myCards;
  final int myChips;
  final int pot;
  final String? nextPlayerMail;
  final String? dealerMail;
  final Map<String, String> lastAction;  // <email, action>
  final Map<String, int> roundBets;      // <email, chipsInRound>
  final String? localEmail;
  final List<PlayerDto> allPlayers;
  final bool cardsVisible; // czy karty mają być widoczne dla wszystkich

  // NOWE - stany dla akcji gracza
  final bool isMyTurn; // czy to kolej lokalnego gracza
  final bool showingRaiseSlider; // czy pokazujemy suwak raise
  final int raiseAmount; // aktualna kwota na suwasku
  final int nextPlayerToCall; // kwota którą trzeba wpłacić żeby grać dalej

  // NOWE - karty wspólne na stole
  final List<String> communityCards; // FLOP(3) + TURN(1) + RIVER(1)

  // NOWE - SHOWDOWN funkcjonalności
  final Map<String, List<String>> revealedCards; // {email: [karta1, karta2]} - karty do pokazania
  final bool showingRevealedCards; // czy pokazujemy karty graczy (faza 4s)
  final List<String> winners; // lista emaili zwycięzców
  final Map<String, int> winnerWinSizes; // NOWE - {email: winSize} - wygrane kwoty
  final bool showingWinners; // czy pokazujemy zwycięzców z pulsowaniem (faza 6s lub sekwencja)

  // NOWE - ELIMINATION I GAME FINISHED funkcjonalności
  final List<String> eliminatedEmails; // lista emaili wyeliminowanych graczy
  final bool gameFinished; // czy gra została zakończona
  final String? ultimateWinner; // email ostatecznego zwycięzcy gry
  // NOWE - ACTION TIMER
  final int? actionTimerSeconds; // Pozostałe sekundy (30→0), null = timer nieaktywny
  final bool actionTimerUrgent; // true gdy ≤10 sekund (czerwony, większy)
  final bool actionTimerGracePeriod; // true w ostatnich 5 sekundach (bez wyświetlania)
  final int? updateNumber; // Numer ostatniej wiadomości z backendu (dla przyszłych iteracji)
  // NOWE - RECONNECT I GAP DETECTION
  final bool isReconnecting; // Czy trwa próba ponownego łączenia
  final int lastUpdateNumber; // Ostatni poprawny numer wiadomości (dla detekcji luki)

  const GameState({
    this.gameStarted = false,
    this.players = const [],
    this.myCards = const [],
    this.myChips = 0,
    this.pot = 0,
    this.nextPlayerMail,
    this.dealerMail,
    this.lastAction = const {},
    this.roundBets = const {},
    this.localEmail,
    this.allPlayers = const [],
    this.cardsVisible = false,
    this.isMyTurn = false,
    this.showingRaiseSlider = false,
    this.raiseAmount = 10,
    this.nextPlayerToCall = 0,
    this.communityCards = const [],
    // NOWE - SHOWDOWN domyślne wartości
    this.revealedCards = const {},
    this.showingRevealedCards = false,
    this.winners = const [],
    this.winnerWinSizes = const {}, // NOWE
    this.showingWinners = false,
    // NOWE - ELIMINATION domyślne wartości
    this.eliminatedEmails = const [],
    this.gameFinished = false,
    this.ultimateWinner,
    // NOWE - ACTION TIMER domyślne wartości
    this.actionTimerSeconds,
    this.actionTimerUrgent = false,
    this.actionTimerGracePeriod = false,
    this.updateNumber,
    this.isReconnecting = false,
    this.lastUpdateNumber = 0,
  });

  GameState copyWith({
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
    int? lastUpdateNumber,
  }) {
    return GameState(
      gameStarted: gameStarted ?? this.gameStarted,
      players: players ?? this.players,
      myCards: myCards ?? this.myCards,
      myChips: myChips ?? this.myChips,
      pot: pot ?? this.pot,
      nextPlayerMail: nextPlayerMail ?? this.nextPlayerMail,
      dealerMail: dealerMail ?? this.dealerMail,
      lastAction: lastAction ?? this.lastAction,
      roundBets: roundBets ?? this.roundBets,
      localEmail: localEmail ?? this.localEmail,
      allPlayers: allPlayers ?? this.allPlayers,
      cardsVisible: cardsVisible ?? this.cardsVisible,
      isMyTurn: isMyTurn ?? this.isMyTurn,
      showingRaiseSlider: showingRaiseSlider ?? this.showingRaiseSlider,
      raiseAmount: raiseAmount ?? this.raiseAmount,
      nextPlayerToCall: nextPlayerToCall ?? this.nextPlayerToCall,
      communityCards: communityCards ?? this.communityCards,
      // NOWE - SHOWDOWN
      revealedCards: revealedCards ?? this.revealedCards,
      showingRevealedCards: showingRevealedCards ?? this.showingRevealedCards,
      winners: winners ?? this.winners,
      winnerWinSizes: winnerWinSizes ?? this.winnerWinSizes, // NOWE
      showingWinners: showingWinners ?? this.showingWinners,
      // NOWE - ELIMINATION
      eliminatedEmails: eliminatedEmails ?? this.eliminatedEmails,
      gameFinished: gameFinished ?? this.gameFinished,
      ultimateWinner: ultimateWinner ?? this.ultimateWinner,
      // NOWE - ACTION TIMER
      actionTimerSeconds: actionTimerSeconds ?? this.actionTimerSeconds,
      actionTimerUrgent: actionTimerUrgent ?? this.actionTimerUrgent,
      actionTimerGracePeriod: actionTimerGracePeriod ?? this.actionTimerGracePeriod,
      updateNumber: updateNumber ?? this.updateNumber,
      isReconnecting: isReconnecting ?? this.isReconnecting,
      lastUpdateNumber: lastUpdateNumber ?? this.lastUpdateNumber,
    );
  }

  @override
  List<Object?> get props => [
    gameStarted, players, myCards, myChips, pot, nextPlayerMail, dealerMail,
    lastAction, roundBets, localEmail, allPlayers, cardsVisible, isMyTurn,
    showingRaiseSlider, raiseAmount, nextPlayerToCall, communityCards,
    revealedCards, showingRevealedCards, winners, winnerWinSizes, showingWinners,
    eliminatedEmails, gameFinished, ultimateWinner, actionTimerSeconds,
    actionTimerUrgent, actionTimerGracePeriod, updateNumber,
    isReconnecting, lastUpdateNumber
  ];
}