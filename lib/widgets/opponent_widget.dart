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
    // Animacja pulsuje od 0.0 do 1.0
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
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
    // Uwaga: isWinner używamy teraz do sterowania animacją wewnątrz Stacka,
    // a nie do ramki na zewnątrz.
    final isWinner = widget.winners.contains(widget.email) && widget.showingWinners;
    final isEliminated = widget.eliminatedEmails.contains(widget.email);
    // winSize jest dostępne, ale na prośbę użytkownika na razie nie wyświetlamy go tekstowo w nowym miejscu
    // final winSize = widget.winnerWinSizes[widget.email];

    final double iconSize = 50.0 * widget.scale;
    final double cardHeight = 18.0 * widget.scale;
    final double cardWidth = cardHeight * 0.7;
    final double cardSpacing = cardWidth * 0.3;
    final double aversCardHeight = cardHeight * 1.33;
    final double aversCardWidth = aversCardHeight * 0.7;
    final double aversCardSpacing = aversCardWidth * 0.15;
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
          animation: _pulseAnimation ?? const AlwaysStoppedAnimation(0.0),
          builder: (context, child) {
            final pulseValue = _pulseAnimation?.value ?? 0.0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Stack: Glow, Ikona, Karty, Badges
                Opacity(
                  opacity: calculateOpacity(),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // 0. NOWOŚĆ - AUREOLA ZWYCIĘZCY (GLOW)
                      // Renderujemy ją TYLKO gdy jest zwycięzcą
                      if (isWinner)
                        Positioned(
                          // Centrujemy względem ikony
                          child: Container(
                            width: iconSize * 0.9,
                            height: iconSize * 0.9,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orangeAccent.withOpacity(0.6 * pulseValue + 0.2),
                                  blurRadius: 20 * widget.scale + (10 * pulseValue),
                                  spreadRadius: 5 * widget.scale + (10 * pulseValue),
                                ),
                                BoxShadow(
                                  color: Colors.yellow.withOpacity(0.4 * pulseValue),
                                  blurRadius: 10 * widget.scale,
                                  spreadRadius: 2 * widget.scale,
                                ),
                              ],
                            ),
                          ),
                        ),

                      // 1. IKONA GRACZA
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

                      // 5. ACTION STATUS BADGE
                      Positioned(
                        bottom: -4 * widget.scale,
                        child: AnimatedOpacity(
                          opacity: (widget.lastAction != null && widget.lastAction!.isNotEmpty && !isEliminated) ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 5 * widget.scale, vertical: 1.5 * widget.scale),
                            decoration: BoxDecoration(
                              color: _getActionColor(widget.lastAction ?? '').withOpacity(0.6),
                              borderRadius: BorderRadius.circular(6 * widget.scale),
                              border: Border.all(color: Colors.white.withOpacity(0.5), width: 0.5 * widget.scale),
                            ),
                            child: Text(
                              (widget.lastAction ?? '').toUpperCase(),
                              style: TextStyle(
                                fontSize: 7.5 * widget.scale,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withOpacity(0.95),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 4 * widget.scale),

                // 6. NICK
                SizedBox(
                  width: maxTextWidth,
                  child: Text(
                    widget.nick,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

                // 7. CHIPS & WIN AMOUNT (Stara logika +X)
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
                  // Tutaj nadal zostawiam mały tekst +X pod chipsami (jeśli chcesz go usunąć całkowicie, daj znać)
                  // Ale prosiłeś o brak tekstu "o wygranej" w kontekście wielkiego komunikatu,
                  // standardowe przyrosty żetonów są zazwyczaj pożądane.
                  if (!widget.showingWinners && widget.chipsInRound > 0)
                    Padding(
                      padding: EdgeInsets.only(top: 1.0 * widget.scale),
                      child: Text('+${widget.chipsInRound}', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 10 * widget.scale, shadows: const [Shadow(blurRadius: 2, color: Colors.black54)])),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}