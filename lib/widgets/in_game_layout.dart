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
    super.key,
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
  });

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
    print('InGameLayout: Clean UI Build');

    final pad = MediaQuery.of(context).padding;
    final usableH = MediaQuery.of(context).size.height - pad.vertical;
    final rotatedPlayers = getRotatedPlayers(allPlayers);
    final localPlayer = rotatedPlayers.isNotEmpty ? rotatedPlayers.last : null;
    final isDealer = localPlayer != null && dealerMail == localPlayer.email;
    final myChipsInRound = roundBets[localEmail] ?? 0;

    // Statusy lokalnego gracza
    final isLocalWinner = winners.contains(localEmail);
    final isLocalEliminated = eliminatedEmails.contains(localEmail);
    final localWinSize = winnerWinSizes[localEmail];

    // --- NOWA LOGIKA ROZMIARÓW I POZYCJI ---

    // 1. Karta ma stałą, rozsądną wysokość zależną od ekranu, ale nie za wielką.
    // Dajemy jej mniej miejsca niż wcześniej, bo jest niżej.
    final cardHeight = usableH * 0.20; // Ok. 20% wysokości ekranu

    // 2. Dolny margines dla kart (aby nie dotykały samej krawędzi)
    final cardsBottomPos = pad.bottom + 10;

    // 3. Pozycja Przycisków Akcji / Suwaka - TUŻ NAD KARTAMI
    // offset = margines dolny + wysokość kart + mały odstęp
    final actionsBottomPos = cardsBottomPos + cardHeight + 12;

    // 4. Pozycja napisu wygranej (jeszcze wyżej)
    final winSizeBottomPos = actionsBottomPos + 60;

    // Lista przeciwników
    final visibleOpponents = rotatedPlayers.where((p) => p.email != localEmail).toList();

    return Stack(
      fit: StackFit.expand,
      children: [
        // WARSTWA 1: PRZECIWNICY (z nowymi pozycjami z opponent_layer.dart)
        if (visibleOpponents.isNotEmpty && localPlayer != null)
          OpponentLayer(
            opponents: allPlayers,
            activeEmail: nextPlayerMail,
            dealerMail: dealerMail,
            lastAction: lastAction,
            roundBets: roundBets,
            localSeatIndex: localPlayer.seatIndex,
            showCards: cardsVisible,
            revealedCards: revealedCards,
            showingRevealedCards: showingRevealedCards,
            winners: winners,
            winnerWinSizes: winnerWinSizes,
            showingWinners: showingWinners,
            eliminatedEmails: eliminatedEmails,
          ),

        // WARSTWA 2: KARTY WSPÓLNE I POT
        // Dzięki zmianom w OpponentLayer, środek stołu jest teraz pusty i bezpieczny
        CommunityCardsWidget(
          pot: pot,
          communityCards: communityCards,
          playerCount: allPlayers.length,
        ),

        // WARSTWA 3: Wyświetlanie wygranej / żetonów w rundzie (NA SAMYM ŚRODKU NAD AKCJAMI)
        Positioned(
          bottom: winSizeBottomPos,
          left: 0,
          right: 0,
          child: Center(
            child: Builder(
              builder: (context) {
                if (showingWinners && isLocalWinner && localWinSize != null && localWinSize > 0) {
                  return Text(
                    '+$localWinSize',
                    style: const TextStyle(
                      color: Colors.yellow,
                      fontWeight: FontWeight.bold,
                      fontSize: 36,
                      shadows: [
                        Shadow(blurRadius: 2, color: Colors.black54),
                        Shadow(blurRadius: 10, color: Colors.yellow),
                      ],
                    ),
                  );
                } else if (!showingWinners && myChipsInRound > 0) {
                  return Text(
                    '+$myChipsInRound',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                      shadows: [Shadow(blurRadius: 2, color: Colors.black54)],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),

        // WARSTWA 4: PRZYCISKI AKCJI (Tuż nad kartami)
        // Pokazywane tylko gdy moja tura, brak suwaka, karty widoczne, nie wyeliminowany
        if (isMyTurn && !showingRaiseSlider && cardsVisible && !isLocalEliminated)
          Positioned(
            bottom: actionsBottomPos,
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

        // WARSTWA 5: SUWAK RAISE (W tym samym miejscu co przyciski)
        if (isMyTurn && showingRaiseSlider && cardsVisible && !isLocalEliminated)
          Positioned(
            bottom: actionsBottomPos,
            left: 0,
            right: 0,
            child: RaiseSliderWidget(
              minRaise: nextPlayerToCall + 10,
              maxRaise: myChips,
              currentAmount: raiseAmount,
              onAmountChanged: onRaiseAmountChanged ?? (int value) {},
              onConfirm: onRaise ?? () {},
              onCancel: onHideRaiseSlider ?? () {},
            ),
          ),

        // WARSTWA 6: KARTY GRACZA LOKALNEGO (Na samym dole, wyśrodkowane)
        Positioned(
          bottom: cardsBottomPos,
          left: 0,
          right: 0,
          child: Center(
            child: PlayerHandWidget(
              cards: cards,
              height: cardHeight,
              isWinner: isLocalWinner,
              showingWinners: showingWinners,
              winSize: localWinSize,
              isEliminated: isLocalEliminated,
            ),
          ),
        ),

        // --- ROGI DOLNE EKRANU (Oddzielone od kart dla przejrzystości) ---

        // LEWY DOLNY RÓG: Timer + Dealer Button
        if (!isLocalEliminated)
          Positioned(
            bottom: pad.bottom + 10,
            left: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dealer Button (nad timerem lub samodzielnie)
                if (isDealer)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: SvgPicture.asset('assets/dealer.svg', width: 26, height: 26),
                  ),

                // Timer (tylko w mojej turze)
                if (isMyTurn && cardsVisible && actionTimerSeconds != null && !actionTimerGracePeriod)
                  ActionTimerWidget(
                    seconds: actionTimerSeconds!,
                    isUrgent: actionTimerUrgent,
                  ),
              ],
            ),
          ),

        // PRAWY DOLNY RÓG: Ilość Żetonów Gracza
        if (!isLocalEliminated)
          Positioned(
            bottom: pad.bottom + 15, // Trochę wyżej dla równowagi optycznej
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SvgPicture.asset('assets/chips.svg', width: 24, height: 24),
                ),
                Text(
                  '${localPlayer?.chips ?? myChips}',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black45)],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}