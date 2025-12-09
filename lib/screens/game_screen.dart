import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../bloc/game/game_cubit.dart';
import '../bloc/game/game_state.dart';
import '../widgets/game_header.dart';
import '../widgets/opponent_layer.dart';
import '../widgets/start_button.dart';
import '../widgets/in_game_layout.dart';
import '../widgets/ultimate_winner_overlay.dart';
import 'poker_tables_screen.dart';

class GameScreen extends StatefulWidget {
  static const routeName = '/game';
  final int tableCode;
  final bool isCreator;
  final dynamic syncDto;

  const GameScreen({
    Key? key,
    required this.tableCode,
    required this.isCreator,
    this.syncDto,
  }) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  bool _requestedPlayers = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Rejestracja obserwera cyklu życia

    // Sprawdź czy to reconnect czy normalny flow
    if (widget.syncDto != null) {
      // RECONNECT FLOW - inicjalizacja z SyncDTO
      print('GameScreen: Inicjalizacja z SyncDTO (reconnect)');
      context.read<GameCubit>().initFromSync(widget.syncDto);
    } else {
      // NORMALNY FLOW - standardowa inicjalizacja
      print('GameScreen: Standardowa inicjalizacja');
      context.read<GameCubit>().init(widget.tableCode);

      // Dla wszystkich typów stołów (creator i joiner) wysyłamy request o graczy po 3 sekundach
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(seconds: 3));
        if (mounted && !_requestedPlayers) {
          _requestedPlayers = true;
          context.read<GameCubit>().sendPlayersRequest();
        }
      });
    }
  }

  Future<void> _showLeaveDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Leave Game'),
          content: const Text('Are you sure that you want to back to menu?'),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'No',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Yes',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      // Użytkownik potwierdził - opuszczamy grę
      await context.read<GameCubit>().leaveTable();
      if (mounted) {
        // Przechodzimy do PokerTablesScreen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const PokerTablesScreen(),
          ),
        );
      }
    }
  }

  void _handleBackToLobby() {
    // Opuść stół i przejdź do lobby
    context.read<GameCubit>().leaveTable();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const PokerTablesScreen(),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Wyrejestrowanie obserwera
    super.dispose();
  }

  // Obsługa zmian cyklu życia aplikacji (minimalizacja/powrót)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      print('GameScreen: App resumed - wywołuję onAppResumed w Cubicie');
      context.read<GameCubit>().onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.read<FlutterSecureStorage>();
    return Scaffold(
      body: BlocBuilder<GameCubit, GameState>(
        builder: (ctx, state) {
          print('GameScreen: state.cardsVisible=${state.cardsVisible}, state.gameStarted=${state.gameStarted}, state.isMyTurn=${state.isMyTurn}, state.showingRevealedCards=${state.showingRevealedCards}, state.showingWinners=${state.showingWinners}, state.gameFinished=${state.gameFinished}, state.ultimateWinner=${state.ultimateWinner}, isReconnecting=${state.isReconnecting}');

          return Stack(
            fit: StackFit.expand,
            children: [
              SvgPicture.asset('assets/game_background.svg', fit: BoxFit.cover),

              // HEADER
              GameHeader(
                tableCode: widget.tableCode,
                onBack: () => _showLeaveDialog(ctx),
                showCode: !state.gameStarted,
              ),

              // PRZECIWNICY (lobby, przed startem gry)
              if (state.allPlayers.isNotEmpty && !state.gameStarted)
                OpponentLayer(
                  opponents: state.allPlayers,
                  activeEmail: state.nextPlayerMail,
                  localSeatIndex: state.allPlayers
                      .firstWhere((p) => p.email == (state.localEmail ?? ''),
                      orElse: () => state.allPlayers.first)
                      .seatIndex,
                  showCards: false, // W lobby nie pokazujemy kart
                  // NOWE - SHOWDOWN parametry (w lobby zawsze domyślne/puste)
                  revealedCards: const {},
                  showingRevealedCards: false,
                  winners: const [],
                  winnerWinSizes: const {}, // NOWE
                  showingWinners: false,
                  // NOWE - ELIMINATION parametry (w lobby zawsze puste)
                  eliminatedEmails: const [],
                ),

              // PRZYCISK STARTU
              if (!state.gameStarted && widget.isCreator)
                StartButton(
                  sending: false,
                  onStart: () => ctx.read<GameCubit>().startRound(),
                ),

              // LAYOUT GRY – tylko po starcie
              if (state.gameStarted)
                FutureBuilder<String?>(
                  future: storage.read(key: 'userEmail'),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox();
                    }
                    print('Renderuję InGameLayout z cardsVisible=${state.cardsVisible}, isMyTurn=${state.isMyTurn}, communityCards=${state.communityCards}, showingRevealedCards=${state.showingRevealedCards}, winners=${state.winners}, eliminatedEmails=${state.eliminatedEmails}');
                    return InGameLayout(
                      cards: state.myCards,
                      myChips: state.myChips,
                      pot: state.pot,
                      nextPlayerMail: state.nextPlayerMail,
                      allPlayers: state.allPlayers,
                      dealerMail: state.dealerMail,
                      lastAction: state.lastAction,
                      roundBets: state.roundBets,
                      localEmail: snapshot.data!,
                      cardsVisible: state.cardsVisible,
                      communityCards: state.communityCards,

                      // parametry dla akcji gracza
                      isMyTurn: state.isMyTurn,
                      showingRaiseSlider: state.showingRaiseSlider,
                      raiseAmount: state.raiseAmount,
                      nextPlayerToCall: state.nextPlayerToCall,

                      // NOWE - SHOWDOWN parametry
                      revealedCards: state.revealedCards,
                      showingRevealedCards: state.showingRevealedCards,
                      winners: state.winners,
                      winnerWinSizes: state.winnerWinSizes, // NOWE
                      showingWinners: state.showingWinners,

                      // NOWE - ELIMINATION parametry
                      eliminatedEmails: state.eliminatedEmails,

                      // callback functions
                      onFold: () => ctx.read<GameCubit>().performFoldAction(),
                      onCheckCall: () => ctx.read<GameCubit>().performCheckCallAction(),
                      onRaise: () => ctx.read<GameCubit>().performRaiseAction(),
                      onShowRaiseSlider: () => ctx.read<GameCubit>().showRaiseSlider(),
                      onHideRaiseSlider: () => ctx.read<GameCubit>().hideRaiseSlider(),
                      onRaiseAmountChanged: (amount) => ctx.read<GameCubit>().updateRaiseAmount(amount),
                      actionTimerSeconds: state.actionTimerSeconds,
                      actionTimerUrgent: state.actionTimerUrgent,
                      actionTimerGracePeriod: state.actionTimerGracePeriod,
                    );
                  },
                ),

              // NOWE - ULTIMATE WINNER OVERLAY (najwyższa warstwa)
              if (state.gameFinished && state.ultimateWinner != null)
                UltimateWinnerOverlay(
                  ultimateWinner: state.ultimateWinner!,
                  onBackToLobby: _handleBackToLobby,
                ),

              // RECONNECT OVERLAY (najwyższa warstwa - blokuje wszystko)
              if (state.isReconnecting)
                Container(
                  color: Colors.black.withOpacity(0.7),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFFC0A465), // Złoty kolor
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Reconnecting...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Please wait while we restore your connection',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}