import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:just_poker/bloc/auth/auth_bloc.dart';
import 'package:just_poker/bloc/auth/auth_event.dart';
import 'package:just_poker/bloc/auth/auth_state.dart';
import 'package:just_poker/screens/choice_screen.dart';
import 'package:just_poker/widgets/custom_button.dart';
import 'package:just_poker/widgets/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (ctx, state) {
          if (state is AuthAuthenticated) {
            Navigator.pushReplacementNamed(context, ChoiceScreen.routeName);
          }
          if (state is AuthError) {
            final msg = state.message.replaceAll('Exception: ', '');
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(msg)));
          }
        },
        builder: (ctx, state) {
          return Container(
            constraints: const BoxConstraints.expand(),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A3D62), Color(0xFF079992)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              // ZMIANA: LayoutBuilder pozwala pobrać dostępną wysokość
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      // ZMIANA: Wymuszamy minimalną wysokość równą ekranowi
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      // ZMIANA: IntrinsicHeight pomaga w poprawnym rozłożeniu elementów w centrum
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            // ZMIANA: Kluczowe centrowanie w pionie
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Usunięto górny SizedBox(height: 24), bo centrujemy
                              SvgPicture.asset(
                                'assets/brain.svg',
                                width: 120, // ZMIANA: 100 -> 120 (ujednolicenie z Home)
                              ),
                              const SizedBox(height: 48), // ZMIANA: 24 -> 48 (ujednolicenie z Home)
                              CustomTextField(
                                controller: _emailCtrl,
                                hint: 'Email',
                              ),
                              const SizedBox(height: 16),
                              CustomTextField(
                                controller: _passCtrl,
                                hint: 'Password',
                                obscure: true,
                              ),
                              const SizedBox(height: 24),
                              state is AuthLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : CustomButton(
                                text: 'Login',
                                onPressed: () {
                                  BlocProvider.of<AuthBloc>(context).add(
                                    LoginRequested(
                                      _emailCtrl.text.trim(),
                                      _passCtrl.text.trim(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

