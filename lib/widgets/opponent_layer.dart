import 'package:flutter/material.dart';
import '../models/player_dto.dart';
import 'opponent_widget.dart';

class OpponentLayer extends StatelessWidget {
  final List<PlayerDto> opponents; // ALL PLAYERS (w tym lokalny!)
  final String? activeEmail;
  final String? dealerMail;
  final Map<String, String> lastAction;
  final Map<String, int> roundBets;
  final int localSeatIndex; // Tylko seatIndex lokalnego!
  final bool showCards; // czy pokazywać karty przeciwników

  // NOWE - SHOWDOWN parametry
  final Map<String, List<String>>? revealedCards; // {email: [karta1, karta2]} - karty do pokazania
  final bool showingRevealedCards; // czy faza pokazywania kart jest aktywna
  final List<String> winners; // lista zwycięzców
  final Map<String, int> winnerWinSizes; // NOWE - {email: winSize} - wygrane kwoty
  final bool showingWinners; // czy faza pokazywania zwycięzców jest aktywna

  // NOWE - ELIMINATION parametry
  final List<String> eliminatedEmails; // lista wyeliminowanych graczy

  // 7 pozycji dookoła (8 = lokalny)
  static const List<Alignment> _positions = [
    Alignment(-0.8, 0.05),    // 1
    Alignment(-0.8, -0.44),    // 2
    Alignment(-0.6, -0.8),    // 3
    Alignment(0.0, -0.9),    // 4
    Alignment(0.6, -0.8),    // 5
    Alignment(0.8, -0.47),    // 6
    Alignment(0.8, 0.05),     // 7
    // 8 = lokalny
  ];

  const OpponentLayer({
    super.key,
    required this.opponents,
    this.activeEmail,
    this.dealerMail,
    this.lastAction = const {},
    this.roundBets = const {},
    required this.localSeatIndex,
    this.showCards = false,
    // NOWE - SHOWDOWN parametry z domyślnymi wartościami
    this.revealedCards,
    this.showingRevealedCards = false,
    this.winners = const [],
    this.winnerWinSizes = const {}, // NOWE
    this.showingWinners = false,
    // NOWE - ELIMINATION parametry z domyślnymi wartościami
    this.eliminatedEmails = const [],
  });

  @override
  Widget build(BuildContext context) {
    print('OpponentLayer: showCards=$showCards, opponents.length=${opponents.length}, showingRevealedCards=$showingRevealedCards, winners.length=${winners.length}, eliminatedEmails.length=${eliminatedEmails.length}');

    // Mapujemy WSZYSTKICH graczy po seatIndex, ale pomijamy lokalnego
    final Map<int, PlayerDto> seatMap = {
      for (final p in opponents) if (p.seatIndex != localSeatIndex) p.seatIndex: p
    };

    print('OpponentLayer: seatMap.length=${seatMap.length}, localSeatIndex=$localSeatIndex');

    final pad   = MediaQuery.of(context).padding;
    final size  = MediaQuery.of(context).size;
    final w     = size.width  - pad.left - pad.right;
    final h     = size.height - pad.top  - pad.bottom;
    final int count = seatMap.length;

    double heightFactor;
    switch (count) {
      case 1: heightFactor = 0.22; break;
      case 2:
      case 3: heightFactor = 0.18; break;
      case 4:
      case 5: heightFactor = 0.14; break;
      case 6: heightFactor = 0.133; break;
      default: heightFactor = 0.18;
    }
    final baseH = h * heightFactor;
    final scale = baseH / 70.0;
    final cardW = 50.0 * scale;
    final cardH = cardW * 1.4;

    final widgets = <Widget>[];

    // Rysujemy od lewo-dół do prawo-dół (sloty wokół stołu)
    for (int i = 1; i <= 7; i++) {
      final int seat = (localSeatIndex + i - 1) % 8 + 1;
      final player = seatMap[seat];
      if (player == null) continue;

      final Alignment pos = _positions[i - 1];
      final fx = (pos.x + 1) / 2;
      final fy = (pos.y + 1) / 2;
      double dx = pad.left + fx * w;
      double dy = pad.top  + fy * h;

      double top = dy - cardH / 2;
      if (top < pad.top + 4) top = pad.top + 4;

      double left = dx - cardW / 2;
      final minL = pad.left + 8;
      final maxL = pad.left + w - cardW - 8;
      if (left < minL) left = minL;
      if (left > maxL) left = maxL;

      widgets.add(
        Positioned(
          left:   left,
          top:    top,
          width:  cardW,
          height: 130.0 * scale,
          child: OpponentWidget(
            email: player.email,
            alignment: Alignment.center,
            nick:      player.nickName,
            chips:     player.chips,
            scale:     scale,
            isActive:  player.email == activeEmail,
            isDealer:  dealerMail == player.email,
            chipsInRound: roundBets[player.email] ?? 0, // ZMIENIONE - używamy roundBets zamiast player.chipsInRound
            showCards: showCards,
            isFolded: player.isFolded,
            lastAction: lastAction[player.email],
            // NOWE - SHOWDOWN parametry
            revealedCards: revealedCards,
            showingRevealedCards: showingRevealedCards,
            winners: winners,
            winnerWinSizes: winnerWinSizes,
            showingWinners: showingWinners,
            // NOWE - ELIMINATION parametry
            eliminatedEmails: eliminatedEmails,
          ),
        ),
      );

      print('Dodano OpponentWidget dla ${player.nickName}, email=${player.email}, showCards=$showCards, isFolded=${player.isFolded}, lastAction=${lastAction[player.email]}, isEliminated=${eliminatedEmails.contains(player.email)}');
    }

    return Stack(fit: StackFit.expand, children: widgets);
  }
}