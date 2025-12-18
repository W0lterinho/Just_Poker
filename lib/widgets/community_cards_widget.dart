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
    final padding = MediaQuery.of(context).padding;
    final availableWidth = MediaQuery.of(context).size.width - 32;

    // --- POPRAWKA POZYCJONOWANIA ---
    // Zamiast dynamicznego switcha, który psuł układ przy małej liczbie graczy,
    // ustawiamy karty w stałym punkcie logicznym, który zawsze jest wolny.
    // 0.35 to 35% wysokości ekranu od góry.
    // Opponenci są teraz na pozycjach ~0.15-0.20 (Top), więc 0.35 jest bezpieczne.
    // Gracz lokalny i przyciski zaczynają się od dołu (~0.60), więc jest miejsce.
    const double fixedTopFactor = 0.35;

    // Maksymalna wysokość kart - lekko zmniejszona dla bezpieczeństwa
    const double safeMaxCardHeight = 65.0;

    return Positioned(
      top: screenHeight * fixedTopFactor,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // POT (Pula)
          Text(
            'Pot: $pot',
            style: const TextStyle(
              fontFamily: 'MontserratBoldItalic',
              fontSize: 22.0, // Stała, czytelna wielkość
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(offset: Offset(0,1), blurRadius: 2, color: Colors.black54)
              ],
            ),
          ),

          const SizedBox(height: 12),

          // KARTY WSPÓLNE
          if (communityCards.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CommunityCardsDisplayWidget(
                communityCards: communityCards,
                maxWidth: availableWidth,
                maxCardHeight: safeMaxCardHeight,
              ),
            ),
        ],
      ),
    );
  }
}