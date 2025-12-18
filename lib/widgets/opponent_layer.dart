// W pliku: lib/widgets/opponent_layer.dart
// Podmień całą zawartość klasy (lub podmień layouty i metodę build)

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

  // --- POPRAWIONE LAYOUTY (Zapobiegają ucinaniu graczy) ---

  // 1 Przeciwnik (Heads-up)
  static const List<Alignment> _layout1 = [
    Alignment(0.0, -0.85),
  ];

  // 2 Przeciwników (3 graczy total) - Rogi
  static const List<Alignment> _layout2 = [
    Alignment(-0.75, -0.8),
    Alignment(0.75, -0.8),
  ];

  // 3 Przeciwników (4 graczy total) - NAPRAWIONE UCINANIE
  // Zmniejszono rozstaw boczny z 0.85 na 0.72
  static const List<Alignment> _layout3 = [
    Alignment(-0.72, -0.55), // Left Upper (wsunięty do środka)
    Alignment(0.0, -0.88),   // Top Center
    Alignment(0.72, -0.55),  // Right Upper (wsunięty do środka)
  ];

  // 4 Przeciwników
  static const List<Alignment> _layout4 = [
    Alignment(-0.8, -0.15),
    Alignment(-0.65, -0.82),
    Alignment(0.65, -0.82),
    Alignment(0.8, -0.15),
  ];

  // 5 Przeciwników
  static const List<Alignment> _layout5 = [
    Alignment(-0.8, 0.1),
    Alignment(-0.75, -0.5),
    Alignment(0.0, -0.85),
    Alignment(0.75, -0.5),
    Alignment(0.8, 0.1),
  ];

  // 6-7 Przeciwników (Full Ring) - NAPRAWIONE UCINANIE
  // Maksymalne wychylenie ograniczone do 0.78-0.85 zamiast 0.95
  static const List<Alignment> _layoutMax = [
    Alignment(-0.85, 0.28),
    Alignment(-0.78, -0.25),  // Wsunięty
    Alignment(-0.6, -0.85),
    Alignment(0.0, -0.92),
    Alignment(0.6, -0.85),
    Alignment(0.78, -0.25),   // Wsunięty
    Alignment(0.85, 0.28),
  ];

  int _calculateDistance(int currentSeat, int localSeat) {
    return (currentSeat - localSeat + 8) % 8;
  }

  @override
  Widget build(BuildContext context) {
    final pad   = MediaQuery.of(context).padding;
    final size  = MediaQuery.of(context).size;
    final w     = size.width  - pad.left - pad.right;
    final h     = size.height - pad.top  - pad.bottom;

    final opponentsList = opponents.where((p) => p.seatIndex != localSeatIndex).toList();

    // Sortowanie wizualne
    opponentsList.sort((a, b) {
      final distA = _calculateDistance(a.seatIndex, localSeatIndex);
      final distB = _calculateDistance(b.seatIndex, localSeatIndex);
      return distA.compareTo(distB);
    });

    final int count = opponentsList.length;

    List<Alignment> currentLayout;
    if (count <= 1) currentLayout = _layout1;
    else if (count == 2) currentLayout = _layout2;
    else if (count == 3) currentLayout = _layout3;
    else if (count == 4) currentLayout = _layout4;
    else if (count == 5) currentLayout = _layout5;
    else currentLayout = _layoutMax;

    // SKALOWANIE: Zmniejszamy nieco ikony przy 4+ graczach (count >= 3)
    // aby zyskać więcej miejsca i uniknąć tłoku
    double heightFactor;
    switch (count) {
      case 1: heightFactor = 0.22; break;
      case 2: heightFactor = 0.19; break;
      case 3: heightFactor = 0.17; break; // Zmniejszono z 0.19
      default: heightFactor = 0.145; // Zmniejszono dla pełnego stołu
    }

    final baseH = h * heightFactor;
    final scale = baseH / 70.0;
    final cardW = 50.0 * scale;

    final widgets = <Widget>[];

    for (int i = 0; i < count; i++) {
      if (i >= currentLayout.length) break;

      final player = opponentsList[i];
      final Alignment pos = currentLayout[i];

      final fx = (pos.x + 1) / 2;
      final fy = (pos.y + 1) / 2;
      double dx = pad.left + fx * w;
      double dy = pad.top  + fy * h;

      double top = dy - 65.0 * scale;
      double left = dx - cardW / 2;

      if (top < pad.top + 4) top = pad.top + 4;

      widgets.add(
        Positioned(
          left:   left,
          top:    top,
          width:  cardW,
          height: 130.0 * scale,
          child: OpponentWidget(
            email: player.email,
            nick:      player.nickName,
            chips:     player.chips,
            alignment: pos,
            scale:     scale,
            isActive:  player.email == activeEmail,
            isDealer:  dealerMail == player.email,
            chipsInRound: roundBets[player.email] ?? 0,
            showCards: showCards,
            isFolded: player.isFolded,
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