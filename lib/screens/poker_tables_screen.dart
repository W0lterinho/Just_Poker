import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../widgets/custom_button.dart';
import '../repository/poker_repository.dart';
import '../models/request_dto.dart';
import '../bloc/game/game_cubit.dart';
import 'choice_screen.dart';
import 'join_private_screen.dart';
import 'game_screen.dart';

class PokerTablesScreen extends StatefulWidget {
  static const routeName = '/poker_tables';
  const PokerTablesScreen({super.key});

  @override
  State<PokerTablesScreen> createState() => _PokerTablesScreenState();
}

class _PokerTablesScreenState extends State<PokerTablesScreen> {
  bool _creating = false;
  bool _creatingWithAI = false;
  String? _errorMsg;
  final _storage = const FlutterSecureStorage();

  Future<void> _onCreatePrivate() async {
    setState(() {
      _creating = true;
      _errorMsg = null;
    });

    final repo = Provider.of<PokerRepository>(context, listen: false);
    final mail = await _storage.read(key: 'userEmail') ?? '';

    // wybór żetonów
    final chips = await showDialog<int>(
      context: context,
      builder: (dc) => SimpleDialog(
        title: const Text('Select starting chips'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dc, 1000),
            child: const Text('1000'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dc, 2000),
            child: const Text('2000'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dc, 3000),
            child: const Text('3000'),
          ),
        ],
      ),
    );
    if (chips == null) {
      // anulowano
      setState(() => _creating = false);
      return;
    }

    // loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // wysyłamy RequestDTO {playerMail, chips}
      final code = await repo.sendRequest<RequestDTO, int>(
        '/app/table/createPrivate',
        RequestDTO(playerMail: mail, chips: chips),
            (dto) => dto.toJson(),
            (data) => data as int,
      );

      // zapisz kod w storage
      await _storage.write(key: 'tableCode', value: code.toString());

      // zamknij loader i przejdź do GameScreen
      Navigator.pop(context);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => GameCubit(
              context.read<PokerRepository>(),
              context.read<FlutterSecureStorage>(),
            ),
            child: GameScreen(
              tableCode: code,
              isCreator: true,
            ),
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      setState(() => _errorMsg = e.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _onPlayWithFriendsAndAI() async {
    setState(() {
      _creatingWithAI = true;
      _errorMsg = null;
    });

    final repo = Provider.of<PokerRepository>(context, listen: false);
    final mail = await _storage.read(key: 'userEmail') ?? '';

    // loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // wysyłamy RequestDTO z automatycznymi 1000 żetonami
      final code = await repo.sendRequest<RequestDTO, int>(
        '/app/table/createAI',
        RequestDTO(
          tableName: null,
          tableCode: null,
          playerMail: mail,
          chips: 1000,
        ),
            (dto) => dto.toJson(),
            (data) => data as int,
      );

      // zapisz kod w storage
      await _storage.write(key: 'tableCode', value: code.toString());

      // zamknij loader i przejdź do GameScreen
      Navigator.pop(context);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => GameCubit(
              context.read<PokerRepository>(),
              context.read<FlutterSecureStorage>(),
            ),
            child: GameScreen(
              tableCode: code,
              isCreator: true,
            ),
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      setState(() => _errorMsg = e.toString());
    } finally {
      if (mounted) setState(() => _creatingWithAI = false);
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
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_errorMsg != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _errorMsg!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      if (_creating || _creatingWithAI)
                        const CircularProgressIndicator()
                      else ...[
                        CustomButton(
                          text: 'Create private table',
                          onPressed: _onCreatePrivate,
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          text: 'Join private table',
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const JoinPrivateScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          text: 'Play with Friends & AI',
                          onPressed: _onPlayWithFriendsAndAI,
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          text: 'Create public table',
                          onPressed: null,
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          text: 'Join public table',
                          onPressed: null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // BACK button
              Align(
                alignment: Alignment.topRight,
                child: TextButton.icon(
                  onPressed: () {
                    Provider.of<PokerRepository>(context, listen: false).disconnectWebSocket();
                    Navigator.pushReplacementNamed(context, ChoiceScreen.routeName);
                  },
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  label: const Text('Back',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}