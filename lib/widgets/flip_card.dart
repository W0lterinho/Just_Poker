import 'package:flutter/material.dart';
import 'dart:math';

class FlipCard extends StatelessWidget {
  final Widget front;
  final Widget back;
  final bool showFront;

  const FlipCard({
    Key? key,
    required this.front,
    required this.back,
    this.showFront = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) {
        final rotate = Tween(begin: pi, end: 0.0).animate(anim);
        return AnimatedBuilder(
          animation: rotate,
          child: child,
          builder: (context, child) {
            final isUnder = (ValueKey(showFront) != child?.key);
            var tilt = ((anim.value - 0.5).abs() - 0.5) * 0.003;
            tilt *= isUnder ? -1.0 : 1.0;
            final value = isUnder ? min(anim.value, 0.5) : max(anim.value, 0.5);
            return Transform(
              transform: Matrix4.rotationY(pi * value)..setEntry(3, 0, tilt),
              alignment: Alignment.center,
              child: child,
            );
          },
        );
      },
      child: showFront
          ? front
          : back,
    );
  }
}

