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
      await repo.freshJoin(nickName: nickName);

      repo.createStompClient();

      await repo.connectionStatusStream.firstWhere((isConnected) => isConnected).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      if (mounted) {
        Navigator.pushReplacementNamed(context, PokerTablesScreen.routeName);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Fresh join failed: $e');
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
      print('=== ROZPOCZYNAM RECONNECT (YES) ===');

      // 1. Tworzymy klienta (BEZ CALLBACKÓW - repozytorium zarządza stanem)
      repo.createStompClient();

      // 2. Czekamy na sygnał ze strumienia, że połączono (timeout 15s)
      print('1. Czekam na połączenie WebSocket...');
      await repo.connectionStatusStream
          .firstWhere((isConnected) => isConnected)
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('WebSocket connection timeout'),
      );

      print('2. WebSocket połączony pomyślnie');

      // 3. Reszta logiki pozostaje bez zmian (pobranie kodu i sync)
      print('3. Pobieram tableCode z SecureStorage...');
      final tableCodeStr = await storage.read(key: 'tableCode');
      final tableCode = int.tryParse(tableCodeStr ?? '');

      if (tableCode == null) {
        throw Exception('Brak tableCode w SecureStorage');
      }

      print('4. tableCode: $tableCode');
      print('5. Wysyłam request sync...');

      // 4. Wyślij sync request i pobierz aktualny stan gry
      final syncDto = await repo.sendSync();

      print('6. Otrzymano SyncDTO: gameStarted=${syncDto.gameStarted}, players=${syncDto.players.length}');
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
                syncDto: syncDto, // Przekazujemy SyncDTO do inicjalizacji
              ),
            ),
          ),
        );
      }

      print('=== RECONNECT ZAKOŃCZONY POMYŚLNIE ===');

    } catch (e) {
      print('Błąd podczas reconnect: $e');
      if (mounted) {
        setState(() {
          _errorMsg = 'Reconnect failed: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _reconnecting = false);
    }
  }

  Future<void> _onJoin() async {
    final nick = _nickCtrl.text.trim();
    if (nick.isEmpty) return;

    setState(() {
      _joining = true;
      _errorMsg = null;
    });

    final repo = Provider.of<PokerRepository>(context, listen: false);

    try {
      await repo.joinPoker(nickName: nick);

      // 1. Tworzymy klienta
      repo.createStompClient();

      // 2. Czekamy na połączenie (timeout 15s)
      await repo.connectionStatusStream.firstWhere((isConnected) => isConnected).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      if (mounted) {
        Navigator.pushReplacementNamed(context, PokerTablesScreen.routeName);
      }

    } on ConflictException catch (e) {
      setState(() => _joining = false);
      await _showReconnectDialog(nick);
    } catch (e) {
      if (mounted) setState(() => _errorMsg = e.toString());
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
