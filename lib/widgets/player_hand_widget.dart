import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'poker_card_widget.dart';

class PlayerHandWidget extends StatefulWidget {
  final List<String> cards;
  final double height;

  // NOWE - parametry dla podświetlenia zwycięzcy
  final bool isWinner; // czy gracz lokalny jest zwycięzcą
  final bool showingWinners; // czy faza pokazywania zwycięzców jest aktywna
  final int? winSize; // NOWE - wygrana kwota

  // NOWE - parametry dla wyeliminowanego gracza
  final bool isEliminated; // czy gracz lokalny jest wyeliminowany

  const PlayerHandWidget({
    super.key,
    required this.cards,
    required this.height,
    // NOWE - SHOWDOWN parametry
    this.isWinner = false,
    this.showingWinners = false,
    this.winSize, // NOWE
    // NOWE - ELIMINATION parametry
    this.isEliminated = false,
  });

  @override
  State<PlayerHandWidget> createState() => _PlayerHandWidgetState();
}

class _PlayerHandWidgetState extends State<PlayerHandWidget>
    with TickerProviderStateMixin {

  bool _showFront = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // NOWE - Animacja pulsowania dla zwycięzcy
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
  void didUpdateWidget(PlayerHandWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Sprawdź czy gracz stał się zwycięzcą
    if (widget.isWinner && widget.showingWinners && (!oldWidget.isWinner || !oldWidget.showingWinners)) {
      // Rozpocznij pulsowanie
      print('Rozpoczynam pulsowanie dla lokalnego zwycięzcy');
      _pulseController?.repeat(reverse: true);
    } else if (!widget.isWinner || !widget.showingWinners) {
      // Zatrzymaj pulsowanie
      _pulseController?.stop();
      _pulseController?.reset();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _pulseController?.dispose();
    super.dispose();
  }

  void _onPanDown(DragDownDetails _) async {
    // NOWE - Wyeliminowani gracze nie mogą odkrywać kart
    if (widget.isEliminated) return;

    setState(() => _showFront = true);
    // Odtwórz dźwięk tylko gdy odkrywamy karty
    try {
      await _audioPlayer.play(AssetSource('sounds/flip_card.mp3'));
    } catch (e) {
      print('Błąd odtwarzania dźwięku: $e');
    }
  }

  void _onPanEnd(DragEndDetails _) {
    if (widget.isEliminated) return;
    setState(() => _showFront = false);
  }

  void _onPanCancel() {
    if (widget.isEliminated) return;
    setState(() => _showFront = false);
  }

  @override
  Widget build(BuildContext context) {
    final cardW = widget.height * (50 / 70);
    final totalWidth = widget.cards.length > 1
        ? cardW + (widget.cards.length - 1) * (cardW * 0.65)
        : cardW;

    // NOWE - Wyeliminowany gracz pokazuje komunikat zamiast kart
    if (widget.isEliminated) {
      return SizedBox(
        width: totalWidth,
        height: widget.height,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.8),
              borderRadius: BorderRadius.circular(widget.height * 0.1),
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              'You are eliminated',
              style: TextStyle(
                fontSize: widget.height * 0.2,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: const [
                  Shadow(
                    offset: Offset(0, 2),
                    blurRadius: 4,
                    color: Colors.black54,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (widget.cards.isEmpty) return const SizedBox.shrink();

    // NOWE - Sprawdź czy pokazać pulsujący border zwycięzcy
    final shouldShowWinnerBorder = widget.isWinner && widget.showingWinners;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanDown: _onPanDown,
      onPanEnd: _onPanEnd,
      onPanCancel: _onPanCancel,
      child: AnimatedBuilder(
        animation: _pulseAnimation ?? const AlwaysStoppedAnimation(1.0),
        builder: (context, child) {
          return Container(
            // NOWE - Pulsujące podświetlenie zwycięzcy
            decoration: shouldShowWinnerBorder ? BoxDecoration(
              borderRadius: BorderRadius.circular(widget.height * 0.1),
              border: Border.all(
                color: Colors.yellow.withOpacity(_pulseAnimation?.value ?? 1.0),
                width: 4, // Wyraźny border
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.yellow.withOpacity((_pulseAnimation?.value ?? 1.0) * 0.6),
                  blurRadius: 20, // Mocny glow effect
                  spreadRadius: 4,
                ),
              ],
            ) : null,
            padding: shouldShowWinnerBorder ? const EdgeInsets.all(8) : EdgeInsets.zero,
            child: SizedBox(
              width: totalWidth,
              height: widget.height,
              child: Stack(
                children: widget.cards.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final code = entry.value;
                  return AnimatedPositioned(
                    duration: const Duration(milliseconds: 180),
                    left: idx * (cardW * 0.65),
                    top: 0,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: _showFront
                          ? PokerCardWidget(
                        key: ValueKey('front-$code'),
                        code: code,
                        height: widget.height,
                        showFront: true,
                      )
                          : PokerCardWidget(
                        key: ValueKey('back-$code'),
                        code: 'BACK',
                        height: widget.height,
                        showFront: false,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}