import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'community_cards_display_widget.dart';

class CommunityCardsWidget extends StatelessWidget {
  final int pot;
  final List<String> communityCards;
  final int playerCount;

  const CommunityCardsWidget({
    super.key,
    required this.pot,
    this.communityCards = const [],
    this.playerCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final availableWidth = MediaQuery.of(context).size.width - 32;

    // --- DYNAMICZNE POZYCJONOWANIE ---
    double cardsTopFactor;
    double maxCardHeight;
    double potOffset;

    if (playerCount <= 3) {
      cardsTopFactor = 0.42;
      maxCardHeight = 90.0;
      potOffset = 0.12;
    } else if (playerCount <= 4) {
      cardsTopFactor = 0.48;
      maxCardHeight = 80.0;
      potOffset = 0.13;
    } else if (playerCount <= 6) {
      cardsTopFactor = 0.37;
      maxCardHeight = 70.0;
      potOffset = 0.12;
    } else {
      cardsTopFactor = 0.44;
      maxCardHeight = 70.0;
      potOffset = 0.11;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // A. KARTY WSPÓLNE
        Positioned(
          top: screenHeight * cardsTopFactor,
          left: 0,
          right: 0,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CommunityCardsDisplayWidget(
                communityCards: communityCards,
                maxWidth: availableWidth,
                maxCardHeight: maxCardHeight,
              ),
            ),
          ),
        ),

        // B. POT (Pula)
        Positioned(
          top: screenHeight * (cardsTopFactor + potOffset),
          left: 0,
          right: 0,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. IKONA Z TRANSFORMCJĄ SKALI
                // Używamy Transform.scale, aby powiększyć wizualnie ikonę (nawet x1.8),
                // ale logicznie zajmuje ona wciąż tyle samo miejsca w Row.
                // Dzięki temu tekst się nie przesuwa gwałtownie.
                Transform.scale(
                  scale: 5.0, // <-- TUTAJ STERUJESZ ROZMIAREM WIZUALNYM (np. 1.5 do 2.0)
                  child: SvgPicture.asset(
                    'assets/a_lot_chips.svg',
                    // Bazowy rozmiar (layout) trzymamy mniejszy, żeby nie rozpychał Row
                    width: 30.0,
                    height: 30.0,
                  ),
                ),

                const SizedBox(width: 12), // Odstęp między "środkiem" ikony a tekstem

                // 2. KWOTA W TLE
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$pot',
                    style: TextStyle(
                      fontFamily: 'MontserratBoldItalic',
                      fontSize: playerCount <= 5 ? 24.0 : 20.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: const [
                        Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black54)
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}