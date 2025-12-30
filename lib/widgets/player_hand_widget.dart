import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'poker_card_widget.dart';

class PlayerHandWidget extends StatefulWidget {
  final List<String> cards;
  final double height;
  final bool isWinner;
  final bool showingWinners;
  final int? winSize;
  final bool isEliminated;

  const PlayerHandWidget({
    super.key,
    required this.cards,
    required this.height,
    this.isWinner = false,
    this.showingWinners = false,
    this.winSize,
    this.isEliminated = false,
  });

  @override
  State<PlayerHandWidget> createState() => _PlayerHandWidgetState();
}

class _PlayerHandWidgetState extends State<PlayerHandWidget> {
  bool _showFront = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onPanDown(DragDownDetails _) async {
    if (widget.isEliminated) return;
    setState(() => _showFront = true);
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
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Text(
              'You are eliminated',
              style: TextStyle(
                fontSize: widget.height * 0.2,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (widget.cards.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanDown: _onPanDown,
      onPanEnd: _onPanEnd,
      onPanCancel: _onPanCancel,
      child: Container(
        // USUNIĘTO: decoration z ramką zwycięzcy
        padding: EdgeInsets.zero,
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
      ),
    );
  }
}