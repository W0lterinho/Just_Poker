import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/opponent_layer.dart';
import '../widgets/player_hand_widget.dart';
import '../widgets/community_cards_widget.dart';
import '../widgets/action_buttons_widget.dart';
import '../widgets/raise_slider_widget.dart';
import '../widgets/action_timer_widget.dart';
import '../models/player_dto.dart';

class InGameLayout extends StatelessWidget {
  final List<String> cards;
  final int myChips;
  final int pot;
  final String? nextPlayerMail;
  final List<PlayerDto> allPlayers; // ALL players including local
  final String? dealerMail;
  final Map<String, String> lastAction;
  final Map<String, int> roundBets;
  final String localEmail;
  final bool cardsVisible; // czy karty mają być widoczne
  final List<String> communityCards; // karty wspólne

  // parametry dla akcji gracza
  final bool isMyTurn;
  final bool showingRaiseSlider;
  final int raiseAmount;
  final int nextPlayerToCall;

  // NOWE - SHOWDOWN parametry
  final Map<String, List<String>>? revealedCards; // {email: [karta1, karta2]} - karty do pokazania
  final bool showingRevealedCards; // czy faza pokazywania kart jest aktywna
  final List<String> winners; // lista zwycięzców
  final Map<String, int> winnerWinSizes; // NOWE - {email: winSize} - wygrane kwoty
  final bool showingWinners; // czy faza pokazywania zwycięzców jest aktywna

  // NOWE - ELIMINATION parametry
  final List<String> eliminatedEmails; // lista wyeliminowanych graczy

  // callback functions
  final VoidCallback? onFold;
  final VoidCallback? onCheckCall;
  final VoidCallback? onRaise;
  final VoidCallback? onShowRaiseSlider;
  final VoidCallback? onHideRaiseSlider;
  final Function(int)? onRaiseAmountChanged;
  // NOWE - ACTION TIMER parametry
  final int? actionTimerSeconds;
  final bool actionTimerUrgent;
  final bool actionTimerGracePeriod;

  const InGameLayout({
    Key? key,
    required this.cards,
    required this.myChips,
    required this.pot,
    required this.nextPlayerMail,
    required this.allPlayers,
    required this.dealerMail,
    required this.lastAction,
    required this.roundBets,
    required this.localEmail,
    this.cardsVisible = false,
    this.communityCards = const [],
    this.isMyTurn = false,
    this.showingRaiseSlider = false,
    this.raiseAmount = 10,
    this.nextPlayerToCall = 0,
    // NOWE - SHOWDOWN parametry z domyślnymi wartościami
    this.revealedCards,
    this.showingRevealedCards = false,
    this.winners = const [],
    this.winnerWinSizes = const {}, // NOWE
    this.showingWinners = false,
    // NOWE - ELIMINATION parametry z domyślnymi wartościami
    this.eliminatedEmails = const [],
    this.onFold,
    this.onCheckCall,
    this.onRaise,
    this.onShowRaiseSlider,
    this.onHideRaiseSlider,
    this.onRaiseAmountChanged,
    // NOWE - ACTION TIMER parametry
    this.actionTimerSeconds,
    this.actionTimerUrgent = false,
    this.actionTimerGracePeriod = false,
  }) : super(key: key);

  // Obraca listę tak, by lokalny był ostatni (na dole)
  List<PlayerDto> getRotatedPlayers(List<PlayerDto> allPlayers) {
    if (allPlayers.isEmpty) return [];
    final sorted = List<PlayerDto>.from(allPlayers)
      ..sort((a, b) => a.seatIndex.compareTo(b.seatIndex));
    final localIdx = sorted.indexWhere((p) => p.email == localEmail);
    if (localIdx == -1) return sorted;
    // [localIdx+1, ...end, 0..localIdx] -> localPlayer będzie ostatni
    final rotated = [
      ...sorted.sublist(localIdx + 1),
      ...sorted.sublist(0, localIdx + 1),
    ];
    return rotated;
  }

  @override
  Widget build(BuildContext context) {
    print('InGameLayout: cardsVisible=$cardsVisible, isMyTurn=$isMyTurn, showingRaiseSlider=$showingRaiseSlider, showingRevealedCards=$showingRevealedCards, showingWinners=$showingWinners, eliminatedEmails=$eliminatedEmails');

    final usableH = MediaQuery.of(context).size.height - MediaQuery.of(context).padding.vertical;
    final rotatedPlayers = getRotatedPlayers(allPlayers);
    final localPlayer = rotatedPlayers.isNotEmpty ? rotatedPlayers.last : null;
    final isDealer = localPlayer != null && dealerMail == localPlayer.email;

    // Używamy roundBets tak jak pokazuje log
    final myChipsInRound = roundBets[localEmail] ?? 0;

    // NOWE - Sprawdź czy gracz lokalny jest zwycięzcą i wyeliminowanym
    final isLocalWinner = winners.contains(localEmail);
    final isLocalEliminated = eliminatedEmails.contains(localEmail);
    final localWinSize = winnerWinSizes[localEmail]; // NOWE - pobierz winSize lokalnego gracza

    // Debug
    print('DEBUG: localEmail=$localEmail, roundBets=$roundBets, myChipsInRound=$myChipsInRound, isLocalWinner=$isLocalWinner, isLocalEliminated=$isLocalEliminated, localWinSize=$localWinSize');

    // Odpowiada za to, by tylko przeciwnicy szli do OpponentLayer:
    final visibleOpponents = rotatedPlayers.where((p) => p.email != localEmail).toList();

    // LOGIKA WYSOKOŚCI z uwzględnieniem liczby przeciwników
    double cardHeight;
    double actionsOffset;
    double winSizeOffset; // ZMIENIONE - offset dla winSize (zamiast chipsInRoundOffset)

    // Sprawdzenie liczby przeciwników (wszystkich graczy minus lokalny)
    final opponentCount = allPlayers.length - 1;

    if (isMyTurn && showingRaiseSlider) {
      // Stan: suwak raise
      if (opponentCount >= 6) {
        cardHeight = usableH * 0.15; // 15% - bardzo małe karty przy 6+ przeciwnikach z suwakiem
      } else {
        cardHeight = usableH * 0.18; // 18% - standardowy rozmiar z suwakiem
      }
      actionsOffset = MediaQuery.of(context).padding.bottom + 60 + cardHeight + 10;
      winSizeOffset = actionsOffset + 75;
    } else if (isMyTurn) {
      // Stan: przyciski akcji
      if (opponentCount >= 6) {
        cardHeight = usableH * 0.18; // 18% - zmniejszone karty przy 6+ przeciwnikach z przyciskami
      } else {
        cardHeight = usableH * 0.22; // 22% - standardowy rozmiar z przyciskami
      }
      actionsOffset = MediaQuery.of(context).padding.bottom + 60 + cardHeight + 10;
      winSizeOffset = actionsOffset + 60;
    } else {
      // Stan: normalny
      if (opponentCount >= 6) {
        cardHeight = usableH * 0.22; // 22% - zmniejszone karty przy 6+ przeciwnikach (jak poprzednio z przyciskami)
      } else {
        cardHeight = usableH * 0.28; // 28% - pełne karty przy mniejszej liczbie przeciwników
      }
      actionsOffset = 0; // Nie używane
      winSizeOffset = MediaQuery.of(context).padding.bottom + 60 + cardHeight + 10;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Przeciwnicy na stole (wszyscy, ale z info gdzie lokalny)
        if (visibleOpponents.isNotEmpty && localPlayer != null)
          OpponentLayer(
            opponents: allPlayers,
            activeEmail: nextPlayerMail,
            dealerMail: dealerMail,
            lastAction: lastAction,
            roundBets: roundBets,
            localSeatIndex: localPlayer.seatIndex,
            showCards: cardsVisible,
            // NOWE - SHOWDOWN parametry
            revealedCards: revealedCards,
            showingRevealedCards: showingRevealedCards,
            winners: winners,
            winnerWinSizes: winnerWinSizes, // NOWE - przekazujemy winSizes
            showingWinners: showingWinners,
            // NOWE - ELIMINATION parametry
            eliminatedEmails: eliminatedEmails,
          ),

        // Pot i karty wspólne
        CommunityCardsWidget(
          pot: pot,
          communityCards: communityCards,
          playerCount: allPlayers.length,
        ),

        // ZMIENIONE - Wyświetlanie winSize lub chipsInRound lokalnego gracza
        Positioned(
          bottom: winSizeOffset,
          left: 0,
          right: 0,
          child: Center(
            child: Builder(
              builder: (context) {
                // NOWA LOGIKA - pokazuj winSize gdy showingWinners i gracz wygrał
                if (showingWinners && isLocalWinner && localWinSize != null && localWinSize > 0) {
                  return Text(
                    '+$localWinSize',
                    style: TextStyle(
                      color: Colors.yellow,
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                      shadows: const [
                        Shadow(blurRadius: 2, color: Colors.black54),
                        Shadow(blurRadius: 8, color: Colors.yellow),
                      ],
                    ),
                  );
                }
                // W przeciwnym razie pokazuj chipsInRound (jeśli NIE showingWinners)
                else if (!showingWinners && myChipsInRound > 0) {
                  return Text(
                    '+$myChipsInRound',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                      shadows: [Shadow(blurRadius: 2, color: Colors.black54)],
                    ),
                  );
                }
                // W pozostałych przypadkach nic nie pokazuj
                return const SizedBox.shrink();
              },
            ),
          ),
        ),

        // PRZYCISKI AKCJI - pokazywane tylko gdy karty widoczne I to kolej gracza I NIE jest wyeliminowany
        if (isMyTurn && !showingRaiseSlider && cardsVisible && !isLocalEliminated)
          Positioned(
            bottom: actionsOffset,
            left: 0,
            right: 0,
            child: ActionButtonsWidget(
              canCheck: nextPlayerToCall == 0,
              callAmount: nextPlayerToCall,
              onFold: onFold ?? () {},
              onCheckCall: onCheckCall ?? () {},
              onRaise: onShowRaiseSlider ?? () {},
            ),
          ),

        // SUWAK RAISE - pokazywany gdy wybrano raise I karty widoczne I NIE jest wyeliminowany
        if (isMyTurn && showingRaiseSlider && cardsVisible && !isLocalEliminated)
          Positioned(
            bottom: actionsOffset,
            left: 0,
            right: 0,
            child: RaiseSliderWidget(
              minRaise: nextPlayerToCall + 10, // NOWA LOGIKA - minRaise = nextPlayerToCall + 10
              maxRaise: myChips,
              currentAmount: raiseAmount,
              onAmountChanged: onRaiseAmountChanged ?? (int value) {},
              onConfirm: onRaise ?? () {},
              onCancel: onHideRaiseSlider ?? () {},
            ),
          ),

        // Karty lokalnego gracza - DOSTOSOWANA WYSOKOŚĆ (zmienia się dynamicznie)
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 60,
          left: 0,
          right: 0,
          child: Center(
            child: PlayerHandWidget(
              cards: cards,
              height: cardHeight, // Dynamiczna wysokość
              // NOWE - SHOWDOWN parametry dla lokalnego zwycięzcy
              isWinner: isLocalWinner,
              showingWinners: showingWinners,
              winSize: localWinSize, // NOWE - przekazujemy winSize
              // NOWE - ELIMINATION parametry dla lokalnego gracza
              isEliminated: isLocalEliminated,
            ),
          ),
        ),

        // Żetony lokalnego gracza i DEALER jeśli jest - UKRYTE dla wyeliminowanych
        if (!isLocalEliminated)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isDealer)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SvgPicture.asset(
                      'assets/dealer.svg',
                      width: 28,
                      height: 28,
                    ),
                  ),
                // Ikona żetonu zamiast kwadratu
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SvgPicture.asset(
                    'assets/chips.svg',
                    width: 28,
                    height: 28,
                  ),
                ),
                Text(
                  '${localPlayer?.chips ?? myChips}',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black45)],
                  ),
                ),
              ],
            ),
          ),
        // NOWE - ACTION TIMER - lewy dolny róg
        if (isMyTurn && cardsVisible && actionTimerSeconds != null && !actionTimerGracePeriod)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 10,
            left: 16,
            child: ActionTimerWidget(
              seconds: actionTimerSeconds!,
              isUrgent: actionTimerUrgent,
            ),
          ),
      ],
    );
  }
}