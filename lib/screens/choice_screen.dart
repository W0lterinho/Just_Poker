import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../repository/poker_repository.dart';
import 'poker_tables_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../exceptions/conflict_exception.dart';
import '../models/sync_dto.dart';
import '../bloc/game/game_cubit.dart';
import 'game_screen.dart';

class ChoiceScreen extends StatefulWidget {
  static const routeName = '/choice';
  const ChoiceScreen({super.key});

  @override
  State<ChoiceScreen> createState() => _ChoiceScreenState();
}

class _ChoiceScreenState extends State<ChoiceScreen> {
  bool _showJoinForm = false;
  bool _joining     = false;
  String? _errorMsg;
  late var _stompClient;  //

  final _nickCtrl = TextEditingController();
  bool _reconnecting = false; // Flaga dla reconnect flow
  final _storage  = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    // dodajemy listener, żeby przy każdej zmianie tekstu przerysować UI
    _nickCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nickCtrl.removeListener(() {}); // choć niekonieczne przy jednowątkowym listenerze
    _nickCtrl.dispose();
    super.dispose();
  }
  Future<void> _showReconnectDialog(String nickName) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Ongoing Game Detected'),
          content: const Text('You are participating in ongoing game. Do you want to rejoin?'),
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
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      // User chose "Yes" - reconnect
      await _handleReconnectYes();
    } else if (result == false) {
      // User chose "No" - fresh join
      await _handleReconnectNo(nickName);
    }
  }

  Future<void> _handleReconnectNo(String nickName) async {
    setState(() {
      _joining = true;
      _errorMsg = null;
    });

    final repo = Provider.of<PokerRepository>(context, listen: false);

    try {
      // 1. Wykonaj fresh join (reset gracza na serwerze)
      await repo.freshJoin(nickName: nickName);

      print('Fresh join successful - nawiązuję WebSocket connection');

      // 2. Nawiąż połączenie WebSocket (identycznie jak w normalnym flow)
      int retryCount = 0;
      const retryInterval = Duration(seconds: 5);
      const maxRetries = 12; // 12*5s = 60s

      _stompClient = repo.createStompClient(
        onConnect: (frame) {
          print('WebSocket połączony - nawiguję do PokerTablesScreen');
          Navigator.pushReplacementNamed(
            context,
            PokerTablesScreen.routeName,
          );
        },
        onError: (error) {
          print('WebSocket error: $error');
          setState(() {
            _errorMsg = 'WebSocket error: $error';
          });
        },
        onDisconnect: () {
          print('WebSocket disconnected - retry logic');
          Timer.periodic(retryInterval, (timer) {
            retryCount++;
            if (_stompClient.connected) {
              timer.cancel();
            } else if (retryCount <= maxRetries) {
              _stompClient.activate();
            } else {
              timer.cancel();
              Navigator.pushReplacementNamed(
                context,
                ChoiceScreen.routeName,
              );
            }
          });
        },
      );

    } catch (e) {
      print('Błąd podczas fresh join: $e');
      setState(() {
        _errorMsg = 'Fresh join failed: $e';
      });
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _handleReconnectYes() async {
    setState(() {
      _reconnecting = true;
      _errorMsg = null;
    });

    final repo = Provider.of<PokerRepository>(context, listen: false);
    final storage = const FlutterSecureStorage();

    try {
      print('=== ROZPOCZYNAM RECONNECT ===');

      // 1. Nawiąż połączenie WebSocket
      print('1. Nawiązuję połączenie WebSocket...');

      final completer = Completer<void>();

      _stompClient = repo.createStompClient(
        onConnect: (frame) {
          print('2. WebSocket połączony pomyślnie');
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (error) {
          print('Błąd WebSocket: $error');
          if (!completer.isCompleted) {
            completer.completeError('WebSocket connection failed: $error');
          }
        },
        onDisconnect: () {
          print('WebSocket rozłączony');
        },
      );

      // Czekaj na połączenie (max 10 sekund)
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('WebSocket connection timeout');
        },
      );

      print('3. Pobieram tableCode z SecureStorage...');
      final tableCodeStr = await storage.read(key: 'tableCode');
      final tableCode = int.tryParse(tableCodeStr ?? '');

      if (tableCode == null) {
        throw Exception('Brak tableCode w SecureStorage');
      }

      print('4. tableCode: $tableCode');
      print('5. Wysyłam request sync...');

      // 2. Wyślij sync request
      final syncDto = await repo.sendSync();

      print('6. Otrzymano SyncDTO: gameStarted=${syncDto.gameStarted}, players=${syncDto.players.length}');

      // 3. Nawiguj do GameScreen z syncDto
      print('7. Nawiguję do GameScreen z syncDto...');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider(
              create: (context) => GameCubit(
                context.read<PokerRepository>(),
                context.read<FlutterSecureStorage>(),
              ),
              child: GameScreen(
                tableCode: tableCode,
                isCreator: false,
                syncDto: syncDto,
              ),
            ),
          ),
        );
      }

      print('=== RECONNECT ZAKOŃCZONY POMYŚLNIE ===');

    } catch (e) {
      print('Błąd podczas reconnect: $e');
      setState(() {
        _errorMsg = 'Reconnect failed: $e';
      });
    } finally {
      if (mounted) setState(() => _reconnecting = false);
    }
  }

  Future<void> _onJoin() async {
    final nick = _nickCtrl.text.trim();
    if (nick.isEmpty) return;

    setState(() {
      _joining  = true;
      _errorMsg = null;
    });

    final repo = Provider.of<PokerRepository>(context, listen: false);

    try {
      await repo.joinPoker(nickName: nick);

      // Join succeeded - normal flow
      int retryCount = 0;
      const retryInterval = Duration(seconds: 5);
      const maxRetries = 12; // 12*5s = 60s

      _stompClient = repo.createStompClient(
        onConnect: (frame) {
          Navigator.pushReplacementNamed(
            context,
            PokerTablesScreen.routeName,
          );
        },
        onError: (error) {
          setState(() {
            _errorMsg = 'WebSocket error: $error';
          });
        },
        onDisconnect: () {
          Timer.periodic(retryInterval, (timer) {
            retryCount++;
            if (_stompClient.connected) {
              timer.cancel();
            } else if (retryCount <= maxRetries) {
              _stompClient.activate();
            } else {
              timer.cancel();
              Navigator.pushReplacementNamed(
                context,
                ChoiceScreen.routeName,
              );
            }
          });
        },
      );
    } on ConflictException catch (e) {
      // HTTP 409 - gracz jest już w grze
      print('Otrzymano ConflictException: $e');
      setState(() => _joining = false);

      // Pokaż dialog reconnect
      await _showReconnectDialog(nick);

    } catch (e) {
      setState(() {
        _errorMsg = e.toString();
      });
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A3D62), Color(0xFF079992)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _showJoinForm ? _buildJoinSection() : _buildMainOptions(),
        ),
      ),
    );
  }

  Widget _buildMainOptions() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/brain.svg', width: 150, height: 150),
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                CustomButton(
                  text: 'Join Poker',
                  onPressed: () => setState(() => _showJoinForm = true),
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'User Center',
                  onPressed: null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinSection() {
    final isEmpty = _nickCtrl.text.trim().isEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showJoinForm = false;
                  _errorMsg    = null;
                  _nickCtrl.clear();
                });
              },
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: const Text('Back', style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
          SvgPicture.asset('assets/brain.svg', width: 120, height: 120),
          const SizedBox(height: 32),
          if (_errorMsg != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _errorMsg!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          CustomTextField(
            controller: _nickCtrl,
            hint:       'provide the nickname',
          ),
          const SizedBox(height: 24),
          if (_joining || _reconnecting)
            const CircularProgressIndicator()
          else
            CustomButton(
              text: 'Join',
              onPressed: isEmpty ? null : _onJoin,
            ),
        ],
      ),
    );
  }
}
