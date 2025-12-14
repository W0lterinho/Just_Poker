import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'poker_card_widget.dart'; // ZMIENIONE - używamy bezpośrednio PokerCardWidget
import 'dart:async';

class CommunityCardsDisplayWidget extends StatefulWidget {
  final List<String> communityCards;
  final double maxWidth; // Maksymalna szerokość dostępna dla kart
  final double maxCardHeight; // NOWE - maksymalna wysokość kart

  const CommunityCardsDisplayWidget({
    super.key,
    required this.communityCards,
    required this.maxWidth,
    this.maxCardHeight = 70.0, // NOWE - domyślna wysokość
  });

  @override
  State<CommunityCardsDisplayWidget> createState() => _CommunityCardsDisplayWidgetState();
}

class _CommunityCardsDisplayWidgetState extends State<CommunityCardsDisplayWidget>
    with TickerProviderStateMixin {

  final AudioPlayer _audioPlayer = AudioPlayer();
  List<String> _displayedCards = [];
  final List<AnimationController> _animationControllers = [];
  final List<Animation<double>> _fadeAnimations = [];
  final List<Animation<Offset>> _slideAnimations = [];
  final List<Animation<double>> _scaleAnimations = [];

  // NOWE - Kolejka animacji i stan przetwarzania
  List<String> _pendingCards = [];
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _displayedCards = [];
    _pendingCards = [];
  }

  @override
  void didUpdateWidget(CommunityCardsDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    print('CommunityCardsDisplayWidget didUpdateWidget:');
    print('  Old: ${oldWidget.communityCards}');
    print('  New: ${widget.communityCards}');
    print('  Displayed: $_displayedCards');
    print('  Pending: $_pendingCards');
    print('  IsAnimating: $_isAnimating');

    // Sprawdź czy są nowe karty
    if (widget.communityCards.length > _displayedCards.length) {
      print('  → Wykryto nowe karty, kolejkuję...');
      _queueNewCards();
    } else if (widget.communityCards.length < _displayedCards.length) {
      // Reset jeśli lista się zmniejszyła (nowa runda)
      print('  → Lista się zmniejszyła, resetuję...');
      _resetCards();
    } else {
      print('  → Brak zmian w kartach');
    }
  }

  void _queueNewCards() {
    // Zabezpieczenie przed błędnymi stanami
    if (_displayedCards.length > widget.communityCards.length) {
      print('BŁĄD: _displayedCards (${_displayedCards.length}) > communityCards (${widget.communityCards.length})');
      _resetCards();
      return;
    }

    // NAPRAWIONE - Sprawdź które karty są naprawdę nowe
    final newCards = widget.communityCards.sublist(_displayedCards.length);
    if (newCards.isNotEmpty) {
      // NAPRAWIONE - Sprawdź czy karty już nie są w kolejce (unikaj duplikatów)
      final cardsToAdd = <String>[];
      for (final card in newCards) {
        if (!_pendingCards.contains(card)) {
          cardsToAdd.add(card);
        } else {
          print('Karta $card już jest w kolejce - pomijam');
        }
      }

      if (cardsToAdd.isNotEmpty) {
        _pendingCards.addAll(cardsToAdd);
        print('Dodano ${cardsToAdd.length} kart do kolejki: $cardsToAdd. Całkowita kolejka: $_pendingCards');

        // Jeśli nie animujemy, zacznij przetwarzanie kolejki
        if (!_isAnimating) {
          _processQueue();
        }
      } else {
        print('Wszystkie nowe karty już są w kolejce - nie dodaję nic');
      }
    }
  }

  void _processQueue() async {
    if (_pendingCards.isEmpty || _isAnimating) {
      print('_processQueue: Przeskakuję - pendingCards.isEmpty=${_pendingCards.isEmpty}, _isAnimating=$_isAnimating');
      return;
    }

    _isAnimating = true;
    print('=== ROZPOCZYNAM PRZETWARZANIE KOLEJKI KART ===');
    print('Kolejka do przetworzenia: $_pendingCards');

    while (_pendingCards.isNotEmpty && mounted) {
      final cardToAnimate = _pendingCards.removeAt(0);
      print('Przetwarzam kartę z kolejki: $cardToAnimate (pozostało: ${_pendingCards.length})');

      await _animateSingleCard(cardToAnimate);

      // Opóźnienie między kartami
      if (_pendingCards.isNotEmpty) {
        print('Czekam 600ms przed następną kartą...');
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }

    _isAnimating = false;
    print('=== ZAKOŃCZONO PRZETWARZANIE KOLEJKI KART ===');
  }

  Future<void> _animateSingleCard(String card) async {
    print('=== ANIMUJĘ KARTĘ: $card ===');

    // NAPRAWIONE - Sprawdź czy karta już nie jest wyświetlana (dodatkowe zabezpieczenie)
    if (_displayedCards.contains(card)) {
      print('Karta $card już jest wyświetlana - pomijam animację');
      return;
    }

    // Dodaj kartę do wyświetlanych (SYNCHRONICZNIE - karta jest "claimed")
    _displayedCards.add(card);
    print('Karta $card dodana do _displayedCards: $_displayedCards');

    // Stwórz controller animacji
    final animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Animacja fade in
    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));

    // Animacja slide in z lewa
    final slideAnimation = Tween<Offset>(
      begin: const Offset(-0.5, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
    ));

    // Animacja scale
    final scaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animationController,
      curve: const Interval(0.1, 0.9, curve: Curves.elasticOut),
    ));

    _animationControllers.add(animationController);
    _fadeAnimations.add(fadeAnimation);
    _slideAnimations.add(slideAnimation);
    _scaleAnimations.add(scaleAnimation);

    // Odtwórz dźwięk karty
    _playCardSound();

    // Uruchom animację i czekaj na jej zakończenie
    if (mounted) {
      setState(() {}); // Wymusza rebuild z nową kartą
      print('Rozpoczynam animację karty $card');
      await animationController.forward();
      print('Zakończono animację karty $card');
    }
  }

  void _resetCards() {
    print('Resetuję karty - nowa runda');

    // Wyczyść kolejkę
    _pendingCards.clear();
    _isAnimating = false;

    // Wyczyść wszystkie animacje
    for (final controller in _animationControllers) {
      controller.dispose();
    }
    _animationControllers.clear();
    _fadeAnimations.clear();
    _slideAnimations.clear();
    _scaleAnimations.clear();
    _displayedCards.clear();

    // Jeśli są jakieś karty, dodaj je do kolejki
    if (widget.communityCards.isNotEmpty) {
      _pendingCards.addAll(widget.communityCards);
      _processQueue();
    }
  }

  Future<void> _playCardSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/another_card_on_table.mp3'));
    } catch (e) {
      print('Błąd odtwarzania dźwięku karty wspólnej: $e');
    }
  }

  @override
  void dispose() {
    for (final controller in _animationControllers) {
      controller.dispose();
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_displayedCards.isEmpty) {
      return const SizedBox.shrink();
    }

    // Oblicz optymalną wysokość kart na podstawie dostępnej szerokości
    final cardAspectRatio = 0.7; // szerokość/wysokość karty
    final spacing = 8.0;
    final totalSpacing = (_displayedCards.length - 1) * spacing;
    final availableWidthForCards = widget.maxWidth - totalSpacing;
    final cardWidth = availableWidthForCards / _displayedCards.length;
    final cardHeight = cardWidth / cardAspectRatio;

    // NOWE - Ograniczenia z uwzględnieniem maxCardHeight
    final clampedCardHeight = cardHeight.clamp(40.0, widget.maxCardHeight);
    final clampedCardWidth = clampedCardHeight * cardAspectRatio;

    return SizedBox(
      height: clampedCardHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _displayedCards.asMap().entries.map((entry) {
          final index = entry.key;
          final card = entry.value;

          // Jeśli animacja jeszcze nie istnieje, pokaż transparent card
          if (index >= _animationControllers.length) {
            return Container(
              width: clampedCardWidth,
              height: clampedCardHeight,
              margin: EdgeInsets.only(right: index < _displayedCards.length - 1 ? spacing : 0),
            );
          }

          return AnimatedBuilder(
            animation: Listenable.merge([
              _fadeAnimations[index],
              _slideAnimations[index],
              _scaleAnimations[index],
            ]),
            builder: (context, child) {
              return Container(
                margin: EdgeInsets.only(right: index < _displayedCards.length - 1 ? spacing : 0),
                child: Transform.translate(
                  offset: _slideAnimations[index].value * clampedCardWidth,
                  child: Transform.scale(
                    scale: _scaleAnimations[index].value,
                    child: Opacity(
                      opacity: _fadeAnimations[index].value,
                      child: PokerCardWidget(
                        code: card, // ZMIENIONE - bezpośrednio kod karty
                        height: clampedCardHeight,
                        showFront: true, // ZAWSZE AWERS dla kart wspólnych
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}