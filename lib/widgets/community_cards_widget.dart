import 'package:flutter/material.dart';
import 'community_cards_display_widget.dart';

class CommunityCardsWidget extends StatelessWidget {
  final int pot;
  final List<String> communityCards; // NOWE - karty wspólne
  final int playerCount; // NOWE - liczba graczy dla skalowania

  const CommunityCardsWidget({
    Key? key,
    required this.pot,
    this.communityCards = const [], // NOWE - domyślnie pusta lista
    this.playerCount = 2, // NOWE - domyślnie 2 graczy
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final padding = MediaQuery.of(context).padding;
    final availableWidth = screenWidth - padding.left - padding.right - 32; // Marginesy 16 po bokach

    // POPRAWIONE SKALOWANIE pozycji i rozmiarów w zależności od liczby graczy
    double topPositionFactor;
    double maxCardHeight;
    double potFontSize;

    switch (playerCount) {
      case 1:
      case 2:
      case 3:
        topPositionFactor = 0.37; // 38% od góry - niżej dla lepszej równowagi
        maxCardHeight = 90.0; // Większe karty przy mniejszej liczbie graczy
        potFontSize = 24.0;
        break;
      case 4:
      case 5:
        topPositionFactor = 0.42; // 42% od góry
        maxCardHeight = 75.0; // Średnie karty
        potFontSize = 22.0;
        break;
      case 6:
      case 7:
      default:
        topPositionFactor = 0.375; // 45% od góry - więcej miejsca na górnych graczy
        maxCardHeight = 60.0; // Mniejsze karty przy większej liczbie graczy
        potFontSize = 20.0;
        break;
    }

    return Positioned(
      top: screenHeight * topPositionFactor,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // POT na górze - z dostosowanym rozmiarem czcionki
          Text(
            'Pot: $pot',
            style: TextStyle(
              fontFamily: 'MontserratBoldItalic',
              fontSize: potFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: const [
                Shadow(offset: Offset(0,1), blurRadius: 2, color: Colors.black54)
              ],
            ),
          ),

          // KARTY WSPÓLNE pod POT (z animacjami i dostosowanym rozmiarem)
          if (communityCards.isNotEmpty) ...[
            const SizedBox(height: 16), // Odstęp między POT a kartami
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CommunityCardsDisplayWidget(
                communityCards: communityCards,
                maxWidth: availableWidth,
                maxCardHeight: maxCardHeight, // NOWE - przekazujemy maksymalną wysokość
              ),
            ),
          ],
        ],
      ),
    );
  }
}