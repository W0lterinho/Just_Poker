import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:just_poker/bloc/auth/auth_bloc.dart';
import 'package:just_poker/bloc/auth/auth_event.dart';
import 'package:just_poker/bloc/auth/auth_state.dart';
import 'package:just_poker/widgets/custom_button.dart';
import 'package:just_poker/widgets/custom_text_field.dart';

class RegisterScreen extends StatefulWidget {
  static const routeName = '/register';
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (ctx, state) {
          if (state is AuthInitial) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Rejestracja powiodła się')),
            );
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
              // ZMIANA: LayoutBuilder dla centrowania
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            // ZMIANA: Centrowanie w pionie
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                'assets/brain.svg',
                                width: 120, // ZMIANA: 100 -> 120
                              ),
                              const SizedBox(height: 48), // ZMIANA: 24 -> 48
                              CustomTextField(
                                controller: _firstCtrl,
                                hint: 'First Name',
                              ),
                              const SizedBox(height: 16),
                              CustomTextField(
                                controller: _lastCtrl,
                                hint: 'Last Name',
                              ),
                              const SizedBox(height: 16),
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
                                text: 'Register',
                                onPressed: () {
                                  BlocProvider.of<AuthBloc>(context).add(
                                    RegisterRequested(
                                      email: _emailCtrl.text.trim(),
                                      password: _passCtrl.text.trim(),
                                      firstName: _firstCtrl.text.trim(),
                                      lastName: _lastCtrl.text.trim(),
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

