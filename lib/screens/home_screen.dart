import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:just_poker/screens/login_screen.dart';
import 'package:just_poker/screens/register_screen.dart';
import 'package:just_poker/widgets/custom_button.dart';

class HomeScreen extends StatelessWidget {
  static const routeName = '/';
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A3D62), Color(0xFF079992)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'JustPoker',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Friends & AI',
                style: TextStyle(color: Colors.white70, fontSize: 20),
              ),
              const SizedBox(height: 32),
              SvgPicture.asset(
                'assets/brain.svg',
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    CustomButton(
                      text: 'Login',
                      onPressed: () =>
                          Navigator.pushNamed(context, LoginScreen.routeName),
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      text: 'Register',
                      onPressed: () => Navigator.pushNamed(
                          context, RegisterScreen.routeName),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
