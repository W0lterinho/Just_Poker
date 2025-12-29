import 'package:flutter/material.dart';

class ActionButtonsWidget extends StatelessWidget {
  final bool canCheck; // true gdy gracz może CHECK, false gdy musi CALL
  final int callAmount; // kwota do CALL
  final bool isAllIn; // NOWE: Czy sprawdzenie oznacza wejście za wszystko?
  final VoidCallback onFold;
  final VoidCallback onCheckCall;
  final VoidCallback onRaise;

  const ActionButtonsWidget({
    super.key,
    required this.canCheck,
    required this.callAmount,
    this.isAllIn = false, // Domyślnie false
    required this.onFold,
    required this.onCheckCall,
    required this.onRaise,
  });

  @override
  Widget build(BuildContext context) {
    // Określamy tekst i kolor środkowego przycisku
    String middleButtonText;
    Color middleButtonColor;

    if (canCheck) {
      middleButtonText = 'CHECK';
      middleButtonColor = const Color(0xFF1976D2); // Niebieski
    } else if (isAllIn) {
      middleButtonText = 'ALL IN';
      middleButtonColor = const Color(0xFFFF9800); // Pomarańczowy dla All-In
    } else {
      middleButtonText = 'CALL $callAmount';
      middleButtonColor = const Color(0xFF1976D2); // Niebieski
    }

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // FOLD Button
          Expanded(
            child: Container(
              height: 50,
              margin: const EdgeInsets.only(right: 8),
              child: ElevatedButton(
                onPressed: onFold,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 3,
                ),
                child: const Text(
                  'FOLD',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),

          // CHECK / CALL / ALL IN Button
          Expanded(
            child: Container(
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton(
                onPressed: onCheckCall,
                style: ElevatedButton.styleFrom(
                  backgroundColor: middleButtonColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 3,
                ),
                child: Text(
                  middleButtonText,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),

          // RAISE Button
          // Jeśli jest ALL-IN (wymuszony przez brak żetonów na Call), to zazwyczaj nie można już robić Raise,
          // ale zostawiamy aktywny (można zablokować opcjonalnie)
          Expanded(
            child: Container(
              height: 50,
              margin: const EdgeInsets.only(left: 8),
              child: ElevatedButton(
                onPressed: onRaise,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF388E3C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 3,
                ),
                child: const Text(
                  'RAISE',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}