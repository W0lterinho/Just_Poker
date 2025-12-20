import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/poker_card_widget.dart';

class OpponentWidget extends StatefulWidget {
  final String email;
  final String nick;
  final int chips;
  final Alignment alignment;
  final double scale;
  final bool isActive;
  final bool isDealer;
  final int chipsInRound;
  final bool showCards;
  final bool isFolded;
  final String? lastAction;

  // SHOWDOWN parametry
  final Map<String, List<String>>? revealedCards;
  final bool showingRevealedCards;
  final List<String> winners;
  final Map<String, int> winnerWinSizes;
  final bool showingWinners;

  // ELIMINATION parametry
  final List<String> eliminatedEmails;

  const OpponentWidget({
    super.key,
    required this.email,
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
    this.revealedCards,
    this.showingRevealedCards = false,
    this.winners = const [],
    this.winnerWinSizes = const {},
    this.showingWinners = false,
    this.eliminatedEmails = const [],
  });

  @override
  State<OpponentWidget> createState() => _OpponentWidgetState();
}

class _OpponentWidgetState extends State<OpponentWidget> with TickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupPulseAnimation();
  }

  void _setupPulseAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(
      parent: _pulseController!,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(OpponentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isWinner = widget.winners.contains(widget.email);
    final wasWinner = oldWidget.winners.contains(widget.email);

    if (isWinner && widget.showingWinners && !wasWinner) {
      _pulseController?.repeat(reverse: true);
    } else if (!isWinner || !widget.showingWinners) {
      _pulseController?.stop();
      _pulseController?.reset();
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  Color _getActionColor(String action) {
    switch (action.toUpperCase()) {
      case 'FOLD': return const Color(0xFFD32F2F);
      case 'CHECK': return const Color(0xFF1976D2);
      case 'CALL': return const Color(0xFF1976D2);
      case 'RAISE':
      case 'RISE': return const Color(0xFF388E3C);
      case 'ALL_IN': return const Color(0xFFFF9800);
      default: return const Color(0xFF616161);
    }
  }

  // --- METODY BUDUJĄCE KARTY ---

  Widget _buildCardsDisplay(double iconSize, double cardHeight, double cardWidth, double cardSpacing,
      double aversCardHeight, double aversCardWidth, double aversCardSpacing, bool isEliminated) {

    if (isEliminated) return const SizedBox.shrink();

    final hasRevealedCards = widget.revealedCards?.containsKey(widget.email) == true;
    final playerRevealedCards = hasRevealedCards ? widget.revealedCards![widget.email]! : <String>[];

    if (hasRevealedCards && (widget.showingRevealedCards || widget.showingWinners) && playerRevealedCards.length == 2) {
      return _buildRevealedCards(iconSize, aversCardHeight, aversCardWidth, aversCardSpacing, playerRevealedCards);
    } else if (widget.showCards && !widget.isFolded) {
      return _buildNormalCards(iconSize, cardHeight, cardWidth, cardSpacing);
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildRevealedCards(double iconSize, double aversCardHeight, double aversCardWidth,
      double aversCardSpacing, List<String> cards) {
    final totalWidth = aversCardWidth * 2 + aversCardSpacing;
    return Positioned(
      bottom: iconSize * 0.1,
      left: (iconSize - totalWidth) / 2,
      child: SizedBox(
        width: totalWidth,
        height: aversCardHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: PokerCardWidget(
                  key: ValueKey('revealed-${widget.email}-${cards[0]}-front'),
                  code: cards[0], height: aversCardHeight, showFront: true
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: PokerCardWidget(
                  key: ValueKey('revealed-${widget.email}-${cards[1]}-front'),
                  code: cards[1], height: aversCardHeight, showFront: true
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNormalCards(double iconSize, double cardHeight, double cardWidth, double cardSpacing) {
    return Positioned(
      bottom: iconSize * 0.1,
      left: (iconSize - (cardWidth + cardSpacing)) / 2,
      child: SizedBox(
        width: cardWidth + cardSpacing,
        height: cardHeight,
        child: Stack(
          children: [
            Positioned(left: 0, child: _buildBackCard(cardWidth, cardHeight)),
            Positioned(left: cardSpacing, child: _buildBackCard(cardWidth, cardHeight)),
          ],
        ),
      ),
    );
  }

  Widget _buildBackCard(double w, double h) {
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(h * 0.08),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 0.3 * widget.scale),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 1.5 * widget.scale, offset: Offset(0, 0.8 * widget.scale))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(h * 0.08),
        child: SvgPicture.asset('assets/card_revers.svg', width: w, height: h, fit: BoxFit.cover),
      ),
    );
  }

  // --- BRAKUJĄCA METODA POMOCNICZA DLA ODZNAKI "OUT" ---
  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 4 * widget.scale,
        vertical: 2 * widget.scale,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4 * widget.scale),
        border: Border.all(color: Colors.white, width: 1 * widget.scale),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 6 * widget.scale,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  // --- GŁÓWNA METODA BUILD ---

  @override
  Widget build(BuildContext context) {
    final isWinner = widget.winners.contains(widget.email) && widget.showingWinners;
    final isEliminated = widget.eliminatedEmails.contains(widget.email);
    final winSize = widget.winnerWinSizes[widget.email];

    // Skalowanie wymiarów
    final double iconSize = 50.0 * widget.scale;
    final double cardHeight = 18.0 * widget.scale;
    final double cardWidth = cardHeight * 0.7;
    final double cardSpacing = cardWidth * 0.3;
    final double aversCardHeight = cardHeight * 1.33;
    final double aversCardWidth = aversCardHeight * 0.7;
    final double aversCardSpacing = aversCardWidth * 0.15;

    // Limit szerokości nicku dla uniknięcia ucięcia (max szerokość = 2.5x ikona)
    final double maxTextWidth = iconSize * 2.5;

    double calculateOpacity() {
      if (isEliminated) return 0.5;
      if (widget.isFolded) return 0.4;
      return 1.0;
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
                // Container z poświatą dla zwycięzcy
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
                    opacity: calculateOpacity(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Stack: Ikona, Karty, Badges
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            // 1. IKONA
                            SvgPicture.asset(
                              'assets/player.svg',
                              width: iconSize,
                              height: iconSize,
                              fit: BoxFit.contain,
                            ),

                            // 2. KARTY
                            _buildCardsDisplay(iconSize, cardHeight, cardWidth, cardSpacing,
                                aversCardHeight, aversCardWidth, aversCardSpacing, isEliminated),

                            // 3. DEALER
                            if (widget.isDealer)
                              Positioned(
                                left: -8 * widget.scale,
                                top: -6 * widget.scale,
                                child: SvgPicture.asset('assets/dealer.svg', width: 20 * widget.scale, height: 20 * widget.scale),
                              ),

                            // 4. ELIMINATED
                            if (isEliminated)
                              Positioned(
                                right: -8 * widget.scale,
                                top: -6 * widget.scale,
                                child: _buildBadge('OUT', Colors.red),
                              ),

                            // 5. ACTION STATUS BADGE (Subtelna pigułka z animacją)
                            Positioned(
                              bottom: -4 * widget.scale,
                              child: AnimatedOpacity(
                                opacity: (widget.lastAction != null && widget.lastAction!.isNotEmpty && !isEliminated) ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 5 * widget.scale, vertical: 1.5 * widget.scale),
                                  decoration: BoxDecoration(
                                    // Półprzezroczyste tło
                                    color: _getActionColor(widget.lastAction ?? '').withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(6 * widget.scale),
                                    // Subtelna ramka
                                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 0.5 * widget.scale),
                                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2 * widget.scale, offset: const Offset(0, 1))],
                                  ),
                                  child: Text(
                                    (widget.lastAction ?? '').toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 7.5 * widget.scale,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white.withOpacity(0.95),
                                        letterSpacing: 0.3,
                                        shadows: [Shadow(blurRadius: 1, color: Colors.black38, offset: const Offset(0, 0.5))]
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 4 * widget.scale), // Odstęp

                        // 6. NICK (Zabezpieczony przed ucięciem - ellipsis)
                        SizedBox(
                          width: maxTextWidth, // Wymuszenie max szerokości
                          child: Text(
                            widget.nick,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis, // Kropki na końcu
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9.5 * widget.scale,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Roboto',
                              color: widget.isActive ? Colors.yellow : Colors.white,
                              shadows: const [Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black54)],
                            ),
                          ),
                        ),

                        // 7. CHIPS & WIN AMOUNT
                        if (!isEliminated) ...[
                          Text(
                            '${widget.chips}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9 * widget.scale,
                              fontWeight: FontWeight.w900,
                              color: Colors.white70,
                              shadows: const [Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black54)],
                            ),
                          ),
                          if (widget.showingWinners && isWinner && winSize != null && winSize > 0)
                            Padding(
                              padding: EdgeInsets.only(top: 1.0 * widget.scale),
                              child: Text('+$winSize', style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 10 * widget.scale, shadows: [const Shadow(blurRadius: 2, color: Colors.black54), Shadow(blurRadius: 8 * widget.scale, color: Colors.yellow)])),
                            )
                          else if (!widget.showingWinners && widget.chipsInRound > 0)
                            Padding(
                              padding: EdgeInsets.only(top: 1.0 * widget.scale),
                              child: Text('+${widget.chipsInRound}', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 10 * widget.scale, shadows: const [Shadow(blurRadius: 2, color: Colors.black54)])),
                            ),
                        ],
                      ],
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
}