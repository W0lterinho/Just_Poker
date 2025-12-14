import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PokerCardWidget extends StatelessWidget {
  final String code;       // Np. "CLUBS_QUEEN" albo "BACK"
  final double height;
  final bool showFront;    // Czy pokazujemy awers, czy rewers

  const PokerCardWidget({
    super.key,
    required this.code,
    required this.height,
    this.showFront = true,
  });

  @override
  Widget build(BuildContext context) {
    // Rewers karty
    if (code == "BACK" || !showFront) {
      return Container(
        height: height,
        width: height * 0.66,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height * 0.08), // Proporcjonalny radius
          boxShadow: [
            BoxShadow(
              blurRadius: height * 0.06,
              color: Colors.black.withOpacity(0.25),
              spreadRadius: 1,
              offset: Offset(0, height * 0.012),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height * 0.08),
          child: SvgPicture.asset(
            'assets/card_revers.svg',
            height: height,
            width: height * 0.66,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Parsowanie kodu karty
    final parts = code.split('_');
    if (parts.length < 2) {
      return _buildErrorCard();
    }

    String suit = parts[0];
    String rank = parts[1];

    // Mapowanie rang z cache dla lepszej wydajności
    String displayRank = _getRankDisplay(rank);

    // Mapowanie kolorów i symboli
    final suitData = _getSuitData(suit);

    return _buildCardFront(displayRank, suitData);
  }

  // Cache dla często używanych wartości
  static final Map<String, String> _rankCache = {
    "ACE": "A", "KING": "K", "QUEEN": "Q", "JACK": "J", "TEN": "10",
    "NINE": "9", "EIGHT": "8", "SEVEN": "7", "SIX": "6", "FIVE": "5",
    "FOUR": "4", "THREE": "3", "TWO": "2"
  };

  String _getRankDisplay(String rank) {
    return _rankCache[rank] ?? rank;
  }

  Map<String, dynamic> _getSuitData(String suit) {
    switch (suit) {
      case "HEARTS":
        return {"symbol": "♥", "color": const Color(0xFFD32F2F)};
      case "DIAMONDS":
        return {"symbol": "♦", "color": const Color(0xFFD32F2F)};
      case "CLUBS":
        return {"symbol": "♣", "color": const Color(0xFF000000)};
      case "SPADES":
        return {"symbol": "♠", "color": const Color(0xFF000000)};
      default:
        return {"symbol": "?", "color": const Color(0xFF616161)};
    }
  }

  Widget _buildErrorCard() {
    return Container(
      height: height,
      width: height * 0.66,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(height * 0.08),
        border: Border.all(color: Colors.red, width: 2),
      ),
      child: Center(
        child: Icon(
          Icons.error,
          color: Colors.red,
          size: height * 0.3,
        ),
      ),
    );
  }

  Widget _buildCardFront(String displayRank, Map<String, dynamic> suitData) {
    final String suitSymbol = suitData["symbol"];
    final Color suitColor = suitData["color"];

    return Container(
      height: height,
      width: height * 0.66,
      margin: EdgeInsets.symmetric(horizontal: height * 0.02),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(height * 0.08),
        boxShadow: [
          BoxShadow(
            blurRadius: height * 0.06,
            color: Colors.black.withOpacity(0.25),
            spreadRadius: 1,
            offset: Offset(0, height * 0.012),
          ),
        ],
        border: Border.all(
          color: Colors.black.withOpacity(0.15),
          width: height * 0.01,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height * 0.08),
        child: CustomPaint(
          painter: CardPainter(
            displayRank: displayRank,
            suitSymbol: suitSymbol,
            suitColor: suitColor,
            cardHeight: height,
          ),
          size: Size(height * 0.66, height),
        ),
      ),
    );
  }
}

class CardPainter extends CustomPainter {
  final String displayRank;
  final String suitSymbol;
  final Color suitColor;
  final double cardHeight;

  CardPainter({
    required this.displayRank,
    required this.suitSymbol,
    required this.suitColor,
    required this.cardHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Anti-aliasing dla gładkich krawędzi
    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    // OKREŚLENIE DOKŁADNEGO HEX KOLORU na podstawie symbolu
    Color exactColor;
    Color lighterRankColor; // NOWY - jaśniejszy kolor dla wartości karty

    if (suitSymbol == "♥" || suitSymbol == "♦") {
      exactColor = const Color(0xFFD32F2F); // Czerwony hex dla symboli
      lighterRankColor = const Color(0xFFEF5350); // JAŚNIEJSZY czerwony dla wartości
    } else if (suitSymbol == "♣" || suitSymbol == "♠") {
      exactColor = const Color(0xFF000000); // Czarny hex dla symboli
      lighterRankColor = const Color(0xFF424242); // JAŚNIEJSZY czarny (ciemnoszary) dla wartości
    } else {
      exactColor = const Color(0xFF616161); // Szary hex dla błędów
      lighterRankColor = const Color(0xFF757575); // Jaśniejszy szary dla wartości
    }

    // ROZWIĄZANIE: Różne kolory, ale ta sama grubość czcionki
    final rankTextStyle = TextStyle(
      color: lighterRankColor, // JAŚNIEJSZY kolor dla wartości
      fontWeight: FontWeight.w900, // NORMALNA grubość (nie chuda!)
      fontFamily: 'Georgia',
      height: 1.0,
      fontSize: cardHeight * 0.24,
    );

    // NORMALNE style dla symboli (ciemniejszy kolor)
    final symbolTextStyle = TextStyle(
      color: exactColor, // ORYGINALNY ciemniejszy kolor dla symboli
      fontWeight: FontWeight.w400,
      fontFamily: 'Roboto',
      height: 1.0,
    );

    // Styl tekstu dla małych symboli
    final smallSuitTextStyle = symbolTextStyle.copyWith(
      fontSize: cardHeight * 0.13,
    );

    // DUŻY symbol na środku
    final largeSuitTextStyle = symbolTextStyle.copyWith(
      fontSize: cardHeight * 0.36,
    );



    // Lewy górny róg - ranga (JAŚNIEJSZY kolor)
    _drawText(
      canvas,
      displayRank,
      rankTextStyle, // UŻYWAMY JAŚNIEJSZEGO KOLORU
      Offset(cardHeight * 0.05, cardHeight * 0.14),
      TextAlign.left,
    );

    // Lewy górny róg - symbol (pod rangą)
    _drawText(
      canvas,
      suitSymbol,
      smallSuitTextStyle,
      Offset(cardHeight * 0.12, cardHeight * 0.38), // Dostosowane do nowej pozycji rangi
      TextAlign.left,
    );

    // NOWA POZYCJA - Duży symbol przesunięty w kierunku prawego dolnego rogu
    // Pozycja wyliczona tak, aby być na linii diagonalnej z lewym górnym rogiem
    final largeSymbolX = size.width * 0.62;  // Przesunięcie w prawo
    final largeSymbolY = size.height * 0.7; // Przesunięcie w dół

    _drawText(
      canvas,
      suitSymbol,
      largeSuitTextStyle,
      Offset(largeSymbolX, largeSymbolY),
      TextAlign.center,
    );

    // USUNIĘTE - Prawy dolny róg (ranga i symbol) - zgodnie z wymaganiami
    // Kod został całkowicie usunięty dla lepszej czytelności i estetyki
  }

  void _drawText(Canvas canvas, String text, TextStyle style, Offset position, TextAlign align) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    );

    textPainter.layout();

    // Centrowanie tekstu względem pozycji
    final offset = Offset(
      position.dx - (align == TextAlign.center ? textPainter.width / 2 : 0),
      position.dy - textPainter.height / 2,
    );

    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}