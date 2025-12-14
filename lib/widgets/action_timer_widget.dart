import 'package:flutter/material.dart';

class ActionTimerWidget extends StatefulWidget {
  final int seconds;
  final bool isUrgent;

  const ActionTimerWidget({
    super.key,
    required this.seconds,
    required this.isUrgent,
  });

  @override
  State<ActionTimerWidget> createState() => _ActionTimerWidgetState();
}

class _ActionTimerWidgetState extends State<ActionTimerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.isUrgent ? 75.0 : 55.0;
    final bgColor = widget.isUrgent
        ? const Color(0xFFD32F2F).withOpacity(0.9)
        : const Color(0xFF424242).withOpacity(0.85);
    final textColor = widget.isUrgent ? Colors.white : Colors.white;
    final fontSize = widget.isUrgent ? 28.0 : 22.0;

    Widget timerCircle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: widget.isUrgent
                ? Colors.red.withOpacity(0.5)
                : Colors.black.withOpacity(0.3),
            blurRadius: widget.isUrgent ? 12 : 8,
            spreadRadius: widget.isUrgent ? 2 : 1,
          ),
        ],
        border: Border.all(
          color: widget.isUrgent
              ? Colors.red.withOpacity(0.8)
              : Colors.white.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          '${widget.seconds}',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: textColor,
            shadows: const [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 3,
                color: Colors.black45,
              ),
            ],
          ),
        ),
      ),
    );

    // Dodaj pulsowanie tylko w trybie urgent
    if (widget.isUrgent) {
      return ScaleTransition(
        scale: _pulseAnimation,
        child: timerCircle,
      );
    }

    return timerCircle;
  }
}