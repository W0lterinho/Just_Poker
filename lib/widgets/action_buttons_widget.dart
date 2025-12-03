import 'package:flutter/material.dart';

class ActionButtonsWidget extends StatelessWidget {
  final bool canCheck; // true gdy gracz może CHECK, false gdy musi CALL
  final int callAmount; // kwota do CALL (0 gdy można CHECK)
  final VoidCallback onFold;
  final VoidCallback onCheckCall;
  final VoidCallback onRaise;

  const ActionButtonsWidget({
    Key? key,
    required this.canCheck,
    required this.callAmount,
    required this.onFold,
    required this.onCheckCall,
    required this.onRaise,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // CHECK/CALL Button
          Expanded(
            child: Container(
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton(
                onPressed: onCheckCall,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 3,
                ),
                child: Text(
                  canCheck ? 'CHECK' : 'CALL $callAmount',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // RAISE Button
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}