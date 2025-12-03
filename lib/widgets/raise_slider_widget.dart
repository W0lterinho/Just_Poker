import 'package:flutter/material.dart';
import 'dart:math';

class RaiseSliderWidget extends StatefulWidget {
  final int minRaise; // minimalna kwota raise (nextPlayerToCall + 10)
  final int maxRaise; // maksymalna kwota (wszystkie żetony gracza)
  final int currentAmount; // aktualna kwota na suwasku
  final Function(int) onAmountChanged;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const RaiseSliderWidget({
    Key? key,
    required this.minRaise,
    required this.maxRaise,
    required this.currentAmount,
    required this.onAmountChanged,
    required this.onConfirm,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<RaiseSliderWidget> createState() => _RaiseSliderWidgetState();
}

class _RaiseSliderWidgetState extends State<RaiseSliderWidget> {
  @override
  Widget build(BuildContext context) {
    // NOWA WALIDACJA - sprawdź czy minRaise nie przekracza maxRaise
    final effectiveMinRaise = min(widget.minRaise, widget.maxRaise);
    final isAllIn = widget.currentAmount >= widget.maxRaise;

    // NOWE - sprawdź czy gracz ma wystarczająco żetonów na minRaise
    final canRaise = widget.maxRaise >= effectiveMinRaise;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Wyświetlenie aktualnej kwoty
          Container(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              isAllIn ? 'ALL IN: ${widget.currentAmount}' : 'RAISE: ${widget.currentAmount}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isAllIn ? const Color(0xFFFF9800) : Colors.white,
                shadows: const [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 2,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),

          // NOWE - komunikat gdy gracz nie ma wystarczająco żetonów
          if (!canRaise)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Insufficient chips for RAISE (min: $effectiveMinRaise)',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Suwak
          Container(
            height: 32,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                activeTrackColor: isAllIn ? const Color(0xFFFF9800) : const Color(0xFF388E3C),
                inactiveTrackColor: Colors.white.withOpacity(0.3),
                thumbColor: isAllIn ? const Color(0xFFFF9800) : const Color(0xFF388E3C),
                overlayColor: (isAllIn ? const Color(0xFFFF9800) : const Color(0xFF388E3C)).withOpacity(0.2),
              ),
              child: Slider(
                value: widget.currentAmount.toDouble(),
                min: effectiveMinRaise.toDouble(),
                max: widget.maxRaise.toDouble(),
                divisions: max(1, ((widget.maxRaise - effectiveMinRaise) / 10).round()),
                onChanged: (value) {
                  // Zaokrąglamy do wielokrotności 10
                  int roundedValue = (value / 10).round() * 10;
                  if (roundedValue > widget.maxRaise) {
                    roundedValue = widget.maxRaise;
                  }
                  if (roundedValue < effectiveMinRaise) {
                    roundedValue = effectiveMinRaise;
                  }
                  widget.onAmountChanged(roundedValue);
                },
              ),
            ),
          ),

          // Etykiety min/max
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$effectiveMinRaise',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'ALL IN',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Przyciski CONFIRM/CANCEL
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // CANCEL - węższy
              Container(
                width: 100,
                height: 36,
                margin: const EdgeInsets.only(right: 12),
                child: ElevatedButton(
                  onPressed: widget.onCancel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF616161),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // CONFIRM/ALL IN - węższy
              Container(
                width: 100,
                height: 36,
                child: ElevatedButton(
                  onPressed: widget.onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAllIn ? const Color(0xFFFF9800) : const Color(0xFF388E3C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    isAllIn ? 'ALL IN' : 'CONFIRM',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}