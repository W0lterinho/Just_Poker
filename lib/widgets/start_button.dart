import 'package:flutter/material.dart';

class StartButton extends StatelessWidget {
  final bool sending;
  final VoidCallback onStart;

  const StartButton({
    super.key,
    required this.sending,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return Positioned(
      bottom: padding.bottom + 32,
      left:   0,
      right:  0,
      child: Center(
        child: ElevatedButton(
          onPressed: sending ? null : onStart,
          style: ElevatedButton.styleFrom(
            padding:    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            textStyle: const TextStyle(
              fontFamily: 'MontserratBoldItalic',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          child: sending
              ? const SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          )
              : const Text("Let's play Poker"),
        ),
      ),
    );
  }
}
