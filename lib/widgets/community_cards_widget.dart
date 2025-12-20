import 'package:flutter/material.dart';
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

    // --- DYNAMICZNE POZYCJONOWANIE I SKALOWANIE ---
    // Musimy dostosować pozycję kart w zależności od tłoku na stole.

    double cardsTopFactor; // Pozycja Y od góry ekranu (0.0 - 1.0)
    double maxCardHeight;  // Maksymalna wysokość karty
    double potOffset;      // Odstęp napisu POT od kart

    if (playerCount <= 3) {
      // LUŹNO (2-3 graczy): Karty nisko, duże, czytelne
      cardsTopFactor = 0.42;
      maxCardHeight = 90.0;
      potOffset = 0.14;
    }
    else if (playerCount <= 4) {
      // ŚREDNIO (4 graczy): Lekko wyżej
      cardsTopFactor = 0.48;
      maxCardHeight = 80.0;
      potOffset = 0.13;
    }
    else if (playerCount <= 6) {
      // TŁOCZNO (5-6 graczy): Boczni gracze wchodzą w środek.
      // Karty muszą iść w górę i być nieco mniejsze.
      cardsTopFactor = 0.37;
      maxCardHeight = 70.0;
      potOffset = 0.12;
    }
    else {
      // FULL RING (7-8 graczy): Bardzo ciasno.
      // Karty wysoko i kompaktowe, by nie zasłaniać graczy bocznych.
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
            child: Text(
              'Pot: $pot',
              style: TextStyle(
                fontFamily: 'MontserratBoldItalic',
                // Mniejszy font przy dużym tłoku
                fontSize: playerCount <= 5 ? 24.0 : 20.0,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: const [
                  Shadow(offset: Offset(0,1), blurRadius: 2, color: Colors.black54)
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}