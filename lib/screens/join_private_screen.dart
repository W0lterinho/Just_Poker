import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../repository/poker_repository.dart';
import '../models/request_dto.dart';
import 'game_screen.dart';
import '../bloc/game/game_cubit.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class JoinPrivateScreen extends StatefulWidget {
  static const routeName = '/join_private';
  const JoinPrivateScreen({Key? key}) : super(key: key);

  @override
  State<JoinPrivateScreen> createState() => _JoinPrivateScreenState();
}

class _JoinPrivateScreenState extends State<JoinPrivateScreen> {
  final _ctrl = TextEditingController();
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryProvider.of<PokerRepository>(context);
    final valid = _ctrl.text.trim().length == 4;

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
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    label: const Text('Back', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 48),
                CustomTextField(
                  controller: _ctrl,
                  hint: 'Please provide the table code',
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: 'Join',
                  onPressed: valid
                      ? () async {
                    final mail = await _storage.read(key: 'userEmail') ?? '';
                    final code = int.parse(_ctrl.text.trim());

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const Center(child: CircularProgressIndicator()),
                    );

                    try {
                      final resp = await repo.sendRequest<RequestDTO, dynamic>(
                        '/app/table/joinPrivate',
                        RequestDTO(
                          playerMail: mail,
                          tableCode: code,
                          chips: null,
                        ),
                            (dto) => dto.toJson(),
                            (data) => data,
                      );
                      Navigator.pop(context);

                      if (resp is String) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(resp)),
                        );
                        return;
                      }

                      await _storage.write(key: 'tableCode', value: code.toString());

                      // POPRAWIONA NAWIGACJA - używamy ctx zamiast _
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider(
                            create: (ctx) => GameCubit(
                              ctx.read<PokerRepository>(),
                              ctx.read<FlutterSecureStorage>(),
                            ),
                            child: GameScreen(
                              tableCode: code,
                              isCreator: false,
                            ),
                          ),
                        ),
                      );
                    } catch (e) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
