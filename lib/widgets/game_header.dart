import 'package:flutter/material.dart';

class GameHeader extends StatelessWidget {
  final int        tableCode;
  final VoidCallback onBack;
  final bool       showCode;

  const GameHeader({
    super.key,
    required this.tableCode,
    required this.onBack,
    this.showCode = true,          // nowość
  });

@override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return Stack(children: [
      // ◀️ Wstecz
      Positioned(
        top:   padding.top + 8,
        right: 8,
        child: TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          label: const Text('Back', style: TextStyle(color: Colors.white)),
        ),
      ),

      // “Table code:” tylko gdy showCode == true
      if (showCode)
        Center(
          child: Text(
            'Table code: $tableCode',
            style: const TextStyle(
              fontFamily: 'MontserratBoldItalic',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
    ]);
  }
}

