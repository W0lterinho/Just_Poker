import 'package:flutter/material.dart';
import 'dart:async';

class UltimateWinnerOverlay extends StatefulWidget {
  final String ultimateWinner; // email zwycięzcy
  final VoidCallback onBackToLobby; // callback do powrotu do lobby

  const UltimateWinnerOverlay({
    Key? key,
    required this.ultimateWinner,
    required this.onBackToLobby,
  }) : super(key: key);

  @override
  State<UltimateWinnerOverlay> createState() => _UltimateWinnerOverlayState();
}

class _UltimateWinnerOverlayState extends State<UltimateWinnerOverlay>
    with TickerProviderStateMixin {

  AnimationController? _fadeController;
  AnimationController? _scaleController;
  AnimationController? _sparkleController;

  Animation<double>? _fadeAnimation;
  Animation<double>? _scaleAnimation;
  Animation<double>? _sparkleAnimation;

  bool _showWinnerText = false;
  Timer? _winnerTextTimer;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSequence();
  }

  void _setupAnimations() {
    // Fade in animacja dla całego overlay
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController!,
      curve: Curves.easeInOut,
    ));

    // Scale animacja dla tekstu zwycięzcy
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController!,
      curve: Curves.elasticOut,
    ));

    // Sparkle animacja dla efektów
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _sparkleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sparkleController!,
      curve: Curves.easeInOut,
    ));
  }

  void _startSequence() async {
    // Rozpocznij fade in overlay
    _fadeController?.forward();

    // Po 2 sekundach pokaż tekst zwycięzcy
    _winnerTextTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showWinnerText = true;
        });
        _scaleController?.forward();
        _sparkleController?.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _winnerTextTimer?.cancel();
    _fadeController?.dispose();
    _scaleController?.dispose();
    _sparkleController?.dispose();
    super.dispose();
  }

  // Funkcja do wyciągnięcia nicka z emaila (lub zwrócenia emaila jeśli nie ma @)
  String _extractNickFromEmail(String email) {
    if (email.contains('@')) {
      return email.split('@')[0];
    }
    return email;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _fadeAnimation ?? const AlwaysStoppedAnimation(1.0),
        _scaleAnimation ?? const AlwaysStoppedAnimation(1.0),
        _sparkleAnimation ?? const AlwaysStoppedAnimation(1.0),
      ]),
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Wyszarzony backdrop
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                color: Colors.black.withOpacity(0.85 * (_fadeAnimation?.value ?? 1.0)),
              ),

              // Sparkle effects w tle
              if (_sparkleController != null)
                ..._buildSparkleEffects(screenSize),

              // Główny content
              Center(
                child: Opacity(
                  opacity: _fadeAnimation?.value ?? 1.0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // "Here's the winner..." text
                      Text(
                        "Here's the winner...",
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 4),
                              blurRadius: 8,
                              color: Colors.black.withOpacity(0.8),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 40),

                      // Winner nick (pojawia się po 2 sekundach)
                      if (_showWinnerText)
                        Transform.scale(
                          scale: _scaleAnimation?.value ?? 1.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 20,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.yellow.withOpacity(0.9),
                                  Colors.orange.withOpacity(0.9),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.yellow.withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Text(
                              _extractNickFromEmail(widget.ultimateWinner),
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 2),
                                    blurRadius: 4,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                      const SizedBox(height: 60),

                      // Back to Lobby button (pojawia się razem z nickiem)
                      if (_showWinnerText)
                        Transform.scale(
                          scale: _scaleAnimation?.value ?? 1.0,
                          child: ElevatedButton(
                            onPressed: widget.onBackToLobby,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF388E3C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 15,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              elevation: 8,
                              shadowColor: Colors.black.withOpacity(0.3),
                            ),
                            child: const Text(
                              'Back to Lobby',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Funkcja do tworzenia efektów sparkle
  List<Widget> _buildSparkleEffects(Size screenSize) {
    final sparkleValue = _sparkleAnimation?.value ?? 0.0;
    final List<Widget> sparkles = [];

    // Dodaj kilka sparkle efektów w losowych pozycjach
    for (int i = 0; i < 12; i++) {
      final double x = (i * 0.083) * screenSize.width; // Rozłóż po szerokości
      final double y = (0.2 + (i % 3) * 0.3) * screenSize.height; // 3 rzędy

      sparkles.add(
        Positioned(
          left: x,
          top: y,
          child: Transform.scale(
            scale: 0.5 + sparkleValue * 1.5,
            child: Opacity(
              opacity: (1.0 - sparkleValue).clamp(0.0, 0.8),
              child: Icon(
                Icons.star,
                color: Colors.yellow.withOpacity(0.8),
                size: 20 + sparkleValue * 15,
              ),
            ),
          ),
        ),
      );
    }

    return sparkles;
  }
}
