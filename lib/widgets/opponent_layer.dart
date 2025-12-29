import 'package:flutter/material.dart';
import '../models/player_dto.dart';
import 'opponent_widget.dart';

class OpponentLayer extends StatelessWidget {
  final List<PlayerDto> opponents;
  final String? activeEmail;
  final String? dealerMail;
  final Map<String, String> lastAction;
  final Map<String, int> roundBets;
  final int localSeatIndex;
  final bool showCards;
  final Map<String, List<String>>? revealedCards;
  final bool showingRevealedCards;
  final List<String> winners;
  final Map<String, int> winnerWinSizes;
  final bool showingWinners;
  final List<String> eliminatedEmails;

  const OpponentLayer({
    super.key,
    required this.opponents,
    this.activeEmail,
    this.dealerMail,
    this.lastAction = const {},
    this.roundBets = const {},
    required this.localSeatIndex,
    this.showCards = false,
    this.revealedCards,
    this.showingRevealedCards = false,
    this.winners = const [],
    this.winnerWinSizes = const {},
    this.showingWinners = false,
    this.eliminatedEmails = const [],
  });

  // --- NOWE LAYOUTY (Bezpieczne strefy: X max 0.85, Y dopasowany) ---
  // Kolejność w listach odpowiada sortowaniu: od lewej gracza (clockwise) do prawej.

  // 1 Przeciwnik (Heads-up, Total: 2)
  static const List<Alignment> _layout1 = [
    Alignment(0.0, -0.85), // Top Center
  ];

  // 2 Przeciwników (Total: 3) - Trójkąt
  static const List<Alignment> _layout2 = [
    Alignment(-0.70, -0.55), // Top Left (wsunięte)
    Alignment(0.70, -0.55),  // Top Right (wsunięte)
  ];

  // 3 Przeciwników (Total: 4) - Łuk Górny
  static const List<Alignment> _layout3 = [
    Alignment(-0.68, -0.35), // Left Side High
    Alignment(0.0, -0.90),   // Top Center
    Alignment(0.68, -0.35),  // Right Side High
  ];

  // 4 Przeciwników (Total: 5) - Trapez (To naprawia problem ucinania przy 5 graczach)
  static const List<Alignment> _layout4 = [
    Alignment(-0.8, 0.0), // Left Side Low (nadal wysoko, ale niżej niż góra)
    Alignment(-0.50, -0.85), // Top Left
    Alignment(0.50, -0.85),  // Top Right
    Alignment(0.8, 0.0),  // Right Side Low
  ];

  // 5 Przeciwników (Total: 6) - Pięciokąt (Naprawia problem 6 graczy)
  static const List<Alignment> _layout5 = [
    Alignment(-0.78, 0.1),   // Left Side Middle
    Alignment(-0.68, -0.60), // Top Left
    Alignment(0.0, -0.92),   // Top Center
    Alignment(0.68, -0.60),  // Top Right
    Alignment(0.78, 0.1),    // Right Side Middle
  ];

  // 6 Przeciwników (Total: 7)
  static const List<Alignment> _layout6 = [
    Alignment(-0.7, 0.20),  // Left Side Low
    Alignment(-0.72, -0.35), // Left Side High
    Alignment(-0.45, -0.90), // Top Left Center
    Alignment(0.45, -0.90),  // Top Right Center
    Alignment(0.72, -0.35),  // Right Side High
    Alignment(0.7, 0.20),   // Right Side Low
  ];

  // 7 Przeciwników (Total: 8 - MAX) - Pełny Ring
  static const List<Alignment> _layout7 = [
    Alignment(-0.85, 0.35),  // Left Side Bottom
    Alignment(-0.85, -0.25), // Left Side Top
    Alignment(-0.55, -0.88), // Top Left
    Alignment(0.0, -0.95),   // Top Center
    Alignment(0.55, -0.88),  // Top Right
    Alignment(0.85, -0.25),  // Right Side Top
    Alignment(0.85, 0.35),   // Right Side Bottom
  ];

  int _calculateDistance(int currentSeat, int localSeat) {
    // Oblicza odległość zgodnie z ruchem wskazówek zegara (clockwise)
    // To zapewnia, że lista opponentsList jest posortowana:
    // [Gracz po lewej, ..., Gracz na górze, ..., Gracz po prawej]
    return (currentSeat - localSeat + 8) % 8; // Zakładamy max 8 miejsc logicznych
  }

  @override
  Widget build(BuildContext context) {
    final pad   = MediaQuery.of(context).padding;
    final size  = MediaQuery.of(context).size;
    final w     = size.width  - pad.left - pad.right;
    final h     = size.height - pad.top  - pad.bottom;

    final opponentsList = opponents.where((p) => p.seatIndex != localSeatIndex).toList();

    // Sortowanie względem gracza lokalnego (zachowanie logiki nextPlayer)
    opponentsList.sort((a, b) {
      final distA = _calculateDistance(a.seatIndex, localSeatIndex);
      final distB = _calculateDistance(b.seatIndex, localSeatIndex);
      return distA.compareTo(distB);
    });

    final int count = opponentsList.length;

    // Wybór odpowiedniego layoutu
    List<Alignment> currentLayout;
    if (count <= 1) currentLayout = _layout1;
    else if (count == 2) currentLayout = _layout2;
    else if (count == 3) currentLayout = _layout3;
    else if (count == 4) currentLayout = _layout4;
    else if (count == 5) currentLayout = _layout5;
    else if (count == 6) currentLayout = _layout6;
    else currentLayout = _layout7;

    // SKALOWANIE:
    // Im więcej graczy, tym mniejsze elementy, by uniknąć tłoku
    double heightFactor;
    if (count <= 1) heightFactor = 0.22;
    else if (count <= 3) heightFactor = 0.18;
    else if (count <= 5) heightFactor = 0.16;
    else heightFactor = 0.14; // Max compression for 7-8 players

    final baseH = h * heightFactor;
    final scale = baseH / 70.0;
    // Nieco węższa karta dla obliczeń pozycji, by nie nachodziły na siebie
    final cardW = 50.0 * scale;

    final widgets = <Widget>[];

    for (int i = 0; i < count; i++) {
      // Zabezpieczenie, jeśli layout nie przewidział tylu graczy (fallback)
      if (i >= currentLayout.length) break;

      final player = opponentsList[i];
      final Alignment pos = currentLayout[i];

      // Konwersja Alignment (-1..1) na piksele
      final fx = (pos.x + 1) / 2;
      final fy = (pos.y + 1) / 2;
      double dx = pad.left + fx * w;
      double dy = pad.top  + fy * h;

      // Centrowanie widgetu względem punktu (dx, dy)
      // OpponentWidget ma środek w ikonie, ale zajmuje miejsce w górę (karty) i dół (nick)
      // Przesuwamy anchor point nieco, aby Alignment wskazywał na środek avatara
      double top = dy - 65.0 * scale;
      double left = dx - cardW / 2;

      // Hard clamp: Nie pozwól wyjść poza górną krawędź (status bar)
      if (top < pad.top + 4) top = pad.top + 4;

      widgets.add(
        Positioned(
          left:   left,
          top:    top,
          width:  cardW, // Używane tylko jako constraints dla Stacka wewnątrz
          height: 130.0 * scale,
          child: OpponentWidget(
            email:     player.email,
            nick:      player.nickName,
            chips:     player.chips,
            alignment: pos,
            scale:     scale,
            isActive:  player.email == activeEmail,
            isDealer:  dealerMail == player.email,
            chipsInRound: roundBets[player.email] ?? 0,
            showCards: showCards,
            isFolded:  player.isFolded,
            lastAction: lastAction[player.email],
            revealedCards: revealedCards,
            showingRevealedCards: showingRevealedCards,
            winners: winners,
            winnerWinSizes: winnerWinSizes,
            showingWinners: showingWinners,
            eliminatedEmails: eliminatedEmails,
          ),
        ),
      );
    }

    return Stack(fit: StackFit.expand, children: widgets);
  }
}