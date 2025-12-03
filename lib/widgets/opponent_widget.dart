import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/poker_card_widget.dart';

class OpponentWidget extends StatefulWidget {
  final String email; // DODANE - potrzebne dla revealed cards i winner detection
  final String nick;
  final int chips;
  final Alignment alignment;
  final double scale;
  final bool isActive;
  final bool isDealer;
  final int chipsInRound;
  final bool showCards; // czy pokazywać karty (normalne tryłem)
  final bool isFolded; // czy gracz spasował
  final String? lastAction; // ostatnia akcja gracza

  // NOWE - SHOWDOWN funkcjonalności
  final Map<String, List<String>>? revealedCards; // {email: [karta1, karta2]} - karty do pokazania
  final bool showingRevealedCards; // czy faza pokazywania kart jest aktywna
  final List<String> winners; // lista zwycięzców
  final Map<String, int> winnerWinSizes; // NOWE - {email: winSize} - wygrane kwoty
  final bool showingWinners; // czy faza pokazywania zwycięzców jest aktywna

  // NOWE - ELIMINATION funkcjonalności
  final List<String> eliminatedEmails; // lista wyeliminowanych graczy

  const OpponentWidget({
    Key? key,
    required this.email, // DODANE
    required this.nick,
    required this.chips,
    required this.alignment,
    this.scale = 1.0,
    this.isActive = false,
    this.isDealer = false,
    this.chipsInRound = 0,
    this.showCards = false,
    this.isFolded = false,
    this.lastAction,
    // NOWE - SHOWDOWN parametry
    this.revealedCards,
    this.showingRevealedCards = false,
    this.winners = const [],
    this.winnerWinSizes = const {}, // NOWE
    this.showingWinners = false,
    // NOWE - ELIMINATION parametry
    this.eliminatedEmails = const [],
  }) : super(key: key);

  @override
  State<OpponentWidget> createState() => _OpponentWidgetState();
}

class _OpponentWidgetState extends State<OpponentWidget>
    with TickerProviderStateMixin {

  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupPulseAnimation();
  }

  void _setupPulseAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000), // 1 sekunda cykl pulsowania
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController!,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(OpponentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Sprawdź czy gracz stał się zwycięzcą
    final isWinner = widget.winners.contains(widget.email);
    final wasWinner = oldWidget.winners.contains(widget.email);

    if (isWinner && widget.showingWinners && !wasWinner) {
      // Rozpocznij pulsowanie
      print('Rozpoczynam pulsowanie dla zwycięzcy: ${widget.nick}');
      _pulseController?.repeat(reverse: true);
    } else if (!isWinner || !widget.showingWinners) {
      // Zatrzymaj pulsowanie
      _pulseController?.stop();
      _pulseController?.reset();
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWinner = widget.winners.contains(widget.email) && widget.showingWinners;
    final isEliminated = widget.eliminatedEmails.contains(widget.email); // NOWE
    final winSize = widget.winnerWinSizes[widget.email]; // NOWE - pobierz winSize

    print('OpponentWidget dla ${widget.nick}: showCards=${widget.showCards}, isFolded=${widget.isFolded}, lastAction=${widget.lastAction}, isWinner=$isWinner, isEliminated=$isEliminated, showingRevealedCards=${widget.showingRevealedCards}, revealedCards=${widget.revealedCards}, winSize=$winSize');

    // NOWY SZCZEGÓŁOWY LOG
    if (widget.revealedCards != null) {
      print('OpponentWidget ${widget.nick}: revealedCards zawiera klucze: ${widget.revealedCards!.keys.toList()}');
      if (widget.revealedCards!.containsKey(widget.email)) {
        print('OpponentWidget ${widget.nick}: moje karty to: ${widget.revealedCards![widget.email]}');
      } else {
        print('OpponentWidget ${widget.nick}: nie ma moich kart w revealedCards');
      }
    } else {
      print('OpponentWidget ${widget.nick}: revealedCards jest null');
    }

    final double iconSize = 50.0 * widget.scale;
    final double cardHeight = 18.0 * widget.scale;
    final double cardWidth = cardHeight * 0.7;
    final double cardSpacing = cardWidth * 0.3;

    // NOWE - Rozmiary kart avers (+33% większe)
    final double aversCardHeight = cardHeight * 1.33;
    final double aversCardWidth = aversCardHeight * 0.7;
    final double aversCardSpacing = aversCardWidth * 0.15; // Mniejszy spacing dla kart avers

    // NOWE - Oblicz opacity na podstawie stanu eliminated i folded
    double calculateOpacity() {
      if (isEliminated) return 0.5; // Wyeliminowany gracz
      if (widget.isFolded) return 0.4; // Gracz po FOLD
      return 1.0; // Normalny gracz
    }

    return Align(
      alignment: widget.alignment,
      child: OverflowBox(
        maxWidth: double.infinity,
        child: AnimatedBuilder(
          animation: _pulseAnimation ?? const AlwaysStoppedAnimation(1.0),
          builder: (context, child) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Główna ikona gracza z potencjalną przezroczystością i pulsującym podświetleniem
                Container(
                  decoration: isWinner ? BoxDecoration(
                    borderRadius: BorderRadius.circular(iconSize * 0.15),
                    border: Border.all(
                      color: Colors.yellow.withOpacity(_pulseAnimation?.value ?? 1.0),
                      width: 3 * widget.scale,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.yellow.withOpacity((_pulseAnimation?.value ?? 1.0) * 0.6),
                        blurRadius: 15 * widget.scale,
                        spreadRadius: 3 * widget.scale,
                      ),
                    ],
                  ) : null,
                  child: Opacity(
                    opacity: calculateOpacity(), // ZMIENIONE - używa nowej funkcji
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            SvgPicture.asset(
                              'assets/player.svg',
                              width: iconSize,
                              height: iconSize,
                              fit: BoxFit.contain,
                            ),

                            // NOWA LOGIKA KART - conditional rendering
                            _buildCardsDisplay(iconSize, cardHeight, cardWidth, cardSpacing,
                                aversCardHeight, aversCardWidth, aversCardSpacing, isEliminated),

                            // Dealer badge - też skalowany
                            if (widget.isDealer)
                              Positioned(
                                left: -8 * widget.scale,
                                top: -6 * widget.scale,
                                child: SvgPicture.asset(
                                  'assets/dealer.svg',
                                  width: 20 * widget.scale,
                                  height: 20 * widget.scale,
                                ),
                              ),

                            // NOWE - ELIMINATED badge
                            if (isEliminated)
                              Positioned(
                                right: -8 * widget.scale,
                                top: -6 * widget.scale,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 4 * widget.scale,
                                    vertical: 2 * widget.scale,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(4 * widget.scale),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1 * widget.scale,
                                    ),
                                  ),
                                  child: Text(
                                    'OUT',
                                    style: TextStyle(
                                      fontSize: 6 * widget.scale,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 2 * widget.scale),
                        Text(
                          widget.nick,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5 * widget.scale,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Roboto',
                            color: widget.isActive ? Colors.yellow : Colors.white,
                            shadows: const [
                              Shadow(offset: Offset(0, 1),
                                  blurRadius: 2,
                                  color: Colors.black54),
                            ],
                          ),
                        ),
                        // NOWE - Nie pokazuj żetonów dla wyeliminowanych graczy
                        if (!isEliminated) ...[
                          Text(
                            '${widget.chips}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9 * widget.scale,
                              fontWeight: FontWeight.w900,
                              color: Colors.white70,
                              shadows: const [
                                Shadow(offset: Offset(0, 1),
                                    blurRadius: 2,
                                    color: Colors.black54),
                              ],
                            ),
                          ),
                          // ZMIENIONE - Pokazuj winSize podczas showingWinners zamiast chipsInRound
                          if (widget.showingWinners && isWinner && winSize != null && winSize > 0)
                            Padding(
                              padding: EdgeInsets.only(top: 1.0 * widget.scale),
                              child: Text(
                                '+$winSize',
                                style: TextStyle(
                                  color: Colors.yellow,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10 * widget.scale,
                                  shadows: [
                                    const Shadow(blurRadius: 2, color: Colors.black54),
                                    Shadow(blurRadius: 8 * widget.scale, color: Colors.yellow),
                                  ],
                                ),
                              ),
                            )
                          // Pokaż chipsInRound TYLKO gdy NIE showingWinners
                          else if (!widget.showingWinners && widget.chipsInRound > 0)
                            Padding(
                              padding: EdgeInsets.only(top: 1.0 * widget.scale),
                              child: Text(
                                '+${widget.chipsInRound}',
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10 * widget.scale,
                                  shadows: const [
                                    Shadow(blurRadius: 2, color: Colors.black54)
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Wyświetlenie ostatniej akcji gracza - nad ikoną (TYLKO dla nie-wyeliminowanych)
                // NOWY STYL - minimalistyczny, bez ramki
                if (widget.lastAction != null && widget.lastAction!.isNotEmpty && !isEliminated)
                  Positioned(
                    top: -20 * widget.scale,
                    left: -10 * widget.scale,
                    right: -10 * widget.scale,
                    child: Center(
                      child: Text(
                        widget.lastAction!.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9 * widget.scale,
                          fontWeight: FontWeight.w900,
                          color: _getActionColor(widget.lastAction!),
                          shadows: [
                            // Mocny czarny cień dla kontrastu
                            Shadow(
                              blurRadius: 3 * widget.scale,
                              color: Colors.black.withOpacity(0.9),
                              offset: Offset(0, 1 * widget.scale),
                            ),
                            Shadow(
                              blurRadius: 6 * widget.scale,
                              color: Colors.black.withOpacity(0.6),
                              offset: Offset(0, 2 * widget.scale),
                            ),
                            // Dodatkowy outline efekt
                            Shadow(
                              blurRadius: 1 * widget.scale,
                              color: Colors.black,
                              offset: Offset(-0.5 * widget.scale, -0.5 * widget.scale),
                            ),
                            Shadow(
                              blurRadius: 1 * widget.scale,
                              color: Colors.black,
                              offset: Offset(0.5 * widget.scale, -0.5 * widget.scale),
                            ),
                            Shadow(
                              blurRadius: 1 * widget.scale,
                              color: Colors.black,
                              offset: Offset(-0.5 * widget.scale, 0.5 * widget.scale),
                            ),
                            Shadow(
                              blurRadius: 1 * widget.scale,
                              color: Colors.black,
                              offset: Offset(0.5 * widget.scale, 0.5 * widget.scale),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
  // ZAKTUALIZOWANA METODA - Budowanie wyświetlania kart z obsługą eliminated
  Widget _buildCardsDisplay(double iconSize, double cardHeight, double cardWidth, double cardSpacing,
      double aversCardHeight, double aversCardWidth, double aversCardSpacing, bool isEliminated) {

    // NOWE - Wyeliminowani gracze NIE mają kart
    if (isEliminated) {
      print('Gracz ${widget.email} jest wyeliminowany - brak kart');
      return const SizedBox.shrink();
    }

    // Sprawdź czy gracz ma karty do pokazania w revealed cards
    final hasRevealedCards = widget.revealedCards?.containsKey(widget.email) == true;
    final playerRevealedCards = hasRevealedCards ? widget.revealedCards![widget.email]! : <String>[];

    print('_buildCardsDisplay dla ${widget.email}: hasRevealedCards=$hasRevealedCards, showingRevealedCards=${widget.showingRevealedCards}, showingWinners=${widget.showingWinners}, playerRevealedCards=$playerRevealedCards, showCards=${widget.showCards}, isFolded=${widget.isFolded}');

    // POPRAWKA: Karty avers widoczne podczas CAŁEGO SHOWDOWN (revealed cards + winners phase)
    if (hasRevealedCards && (widget.showingRevealedCards || widget.showingWinners) && playerRevealedCards.length == 2) {
      // POKAZUJ KARTY AVERS z flip animation
      print('Pokazuję karty avers dla ${widget.email}: $playerRevealedCards');
      return _buildRevealedCards(iconSize, aversCardHeight, aversCardWidth, aversCardSpacing, playerRevealedCards);
    } else if (widget.showCards && !widget.isFolded) {
      // POKAZUJ NORMALE KARTY TYŁEM (jak wcześniej)
      print('Pokazuję normale karty tyłem dla ${widget.email}');
      return _buildNormalCards(iconSize, cardHeight, cardWidth, cardSpacing);
    } else {
      // BRAK KART
      print('Brak kart dla ${widget.email}');
      return const SizedBox.shrink();
    }
  }

  // NOWA METODA - Budowanie kart avers (revealed) - UPROSZCZONA bez FlipCard
  Widget _buildRevealedCards(double iconSize, double aversCardHeight, double aversCardWidth,
      double aversCardSpacing, List<String> cards) {
    final totalWidth = aversCardWidth * 2 + aversCardSpacing;

    print('_buildRevealedCards: iconSize=$iconSize, totalWidth=$totalWidth, aversCardHeight=$aversCardHeight, cards=$cards');

    return Positioned(
      bottom: iconSize * 0.1,
      left: (iconSize - totalWidth) / 2, // Centruj względem ikony
      child: Container(
        width: totalWidth,
        height: aversCardHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Pierwsza karta avers - PROSTA implementacja bez FlipCard
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: PokerCardWidget(
                key: ValueKey('revealed-${widget.email}-${cards[0]}-front'),
                code: cards[0],
                height: aversCardHeight,
                showFront: true,
              ),
            ),

            // Druga karta avers - PROSTA implementacja bez FlipCard
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: PokerCardWidget(
                key: ValueKey('revealed-${widget.email}-${cards[1]}-front'),
                code: cards[1],
                height: aversCardHeight,
                showFront: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NOWA METODA - Budowanie normalnych kart tyłem (istniejąca logika)
  Widget _buildNormalCards(double iconSize, double cardHeight, double cardWidth, double cardSpacing) {
    return Positioned(
      bottom: iconSize * 0.1,
      left: (iconSize - (cardWidth + cardSpacing)) / 2,
      child: Container(
        width: cardWidth + cardSpacing,
        height: cardHeight,
        child: Stack(
          children: [
            // Pierwsza karta
            Positioned(
              left: 0,
              child: Container(
                width: cardWidth,
                height: cardHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(cardHeight * 0.08),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 0.3 * widget.scale,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 1.5 * widget.scale,
                      offset: Offset(0, 0.8 * widget.scale),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(cardHeight * 0.08),
                  child: SvgPicture.asset(
                    'assets/card_revers.svg',
                    width: cardWidth,
                    height: cardHeight,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            // Druga karta
            Positioned(
              left: cardSpacing,
              child: Container(
                width: cardWidth,
                height: cardHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(cardHeight * 0.08),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 0.3 * widget.scale,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 1.5 * widget.scale,
                      offset: Offset(0, 0.8 * widget.scale),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(cardHeight * 0.08),
                  child: SvgPicture.asset(
                    'assets/card_revers.svg',
                    width: cardWidth,
                    height: cardHeight,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pomocnicza metoda do określenia koloru akcji
  Color _getActionColor(String action) {
    switch (action.toUpperCase()) {
      case 'FOLD':
        return const Color(0xFFD32F2F); // Czerwony
      case 'CHECK':
        return const Color(0xFF1976D2); // Niebieski
      case 'CALL':
        return const Color(0xFF1976D2); // Niebieski
      case 'RAISE':
      case 'RISE':
        return const Color(0xFF388E3C); // Zielony
      case 'ALL_IN':
        return const Color(0xFFFF9800); // Pomarańczowy
      default:
        return const Color(0xFF616161); // Szary
    }
  }
}