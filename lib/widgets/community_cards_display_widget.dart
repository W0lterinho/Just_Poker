import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'poker_card_widget.dart';
import 'dart:async';

class CommunityCardsDisplayWidget extends StatefulWidget {
  final List<String> communityCards;
  final double maxWidth;
  final double maxCardHeight;

  const CommunityCardsDisplayWidget({
    super.key,
    required this.communityCards,
    required this.maxWidth,
    this.maxCardHeight = 70.0,
  });

  @override
  State<CommunityCardsDisplayWidget> createState() => _CommunityCardsDisplayWidgetState();
}

class _CommunityCardsDisplayWidgetState extends State<CommunityCardsDisplayWidget>
    with TickerProviderStateMixin {

  final AudioPlayer _audioPlayer = AudioPlayer();

  // Lista kart już wyświetlonych (statycznych)
  List<String> _displayedCards = [];

  // Kolejka kart, które dopiero mają się pojawić (animowane)
  final List<String> _pendingCards = [];

  // Flaga blokująca dublowanie procesora kolejki
  bool _isAnimatingQueue = false;

  // Kontrolery animacji
  final List<AnimationController> _controllers = [];
  final List<Animation<double>> _fadeAnimations = [];
  final List<Animation<Offset>> _slideAnimations = [];
  final List<Animation<double>> _scaleAnimations = [];

  @override
  void initState() {
    super.initState();
    // NA STARCIE: Ładujemy to co przyszło bez animacji (reconnect/odświeżenie)
    _displayedCards = List.from(widget.communityCards);

    // Tworzymy "martwe" kontrolery dla kart startowych, żeby były widoczne
    for (int i = 0; i < _displayedCards.length; i++) {
      _addCompletedController();
    }
  }

  @override
  void didUpdateWidget(CommunityCardsDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 1. WYKRYWANIE NOWYCH KART Z ZABEZPIECZENIEM PRZED DUPLIKATAMI
    // Zamiast prostego sublist, sprawdzamy każdą kartę z nowej listy
    bool hasNewCards = false;

    for (final card in widget.communityCards) {
      // Jeśli karty nie ma ani na stole, ani w kolejce -> dodajemy
      if (!_displayedCards.contains(card) && !_pendingCards.contains(card)) {
        _pendingCards.add(card);
        hasNewCards = true;
      }
    }

    // Jeśli doszły karty, uruchom procesor (jeśli nie działa)
    if (hasNewCards && !_isAnimatingQueue) {
      _processPendingCards();
    }

    // 2. RESET (NOWA RUNDA)
    // Jeśli lista z backendu jest krótsza niż to co mamy, to znaczy że był reset gry
    else if (widget.communityCards.length < _displayedCards.length) {
      _resetCards();
    }
  }

  // Asynchroniczna pętla animująca karty jedna po drugiej
  Future<void> _processPendingCards() async {
    if (_isAnimatingQueue) return;
    _isAnimatingQueue = true;

    while (_pendingCards.isNotEmpty && mounted) {
      // Pobierz pierwszą kartę z kolejki
      final card = _pendingCards.removeAt(0);

      // Uruchom animację dla tej karty
      _addNewCardWithAnimation(card);

      // Czekaj na efekt dźwiękowy i wizualny przed następną kartą
      // 600ms to optymalny czas (animacja trwa 500ms)
      if (_pendingCards.isNotEmpty && mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }

    _isAnimatingQueue = false;
  }

  void _addCompletedController() {
    final controller = AnimationController(vsync: this, duration: Duration.zero);
    controller.value = 1.0;
    _controllers.add(controller);
    _fadeAnimations.add(AlwaysStoppedAnimation(1.0));
    _slideAnimations.add(AlwaysStoppedAnimation(Offset.zero));
    _scaleAnimations.add(AlwaysStoppedAnimation(1.0));
  }

  void _addNewCardWithAnimation(String card) {
    setState(() {
      _displayedCards.add(card);
    });

    final controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: const Interval(0.0, 1.0, curve: Curves.easeOut)),
    );

    final slide = Tween<Offset>(begin: const Offset(-0.5, 0.0), end: Offset.zero).animate(
      CurvedAnimation(parent: controller, curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack)),
    );

    final scale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: const Interval(0.0, 0.8, curve: Curves.elasticOut)),
    );

    _controllers.add(controller);
    _fadeAnimations.add(fade);
    _slideAnimations.add(slide);
    _scaleAnimations.add(scale);

    controller.forward();

    // ODTWARZANIE DŹWIĘKU (Naprawione)
    _playCardSound();
  }

  void _resetCards() {
    _pendingCards.clear();
    _isAnimatingQueue = false;

    for (var c in _controllers) c.dispose();
    _controllers.clear();
    _fadeAnimations.clear();
    _slideAnimations.clear();
    _scaleAnimations.clear();

    // Przy resecie ustawiamy stan na to co przyszło z backendu (zazwyczaj pusta lista)
    setState(() {
      _displayedCards = List.from(widget.communityCards);
    });

    for (int i = 0; i < _displayedCards.length; i++) {
      _addCompletedController();
    }
  }

  Future<void> _playCardSound() async {
    try {
      // Używamy AssetSource, zakładając że plik jest w assets/sounds/flip_card.mp3
      // Jeśli plik nazywa się inaczej, zmień nazwę tutaj.
      await _audioPlayer.play(AssetSource('sounds/flip_card.mp3'));
    } catch (e) {
      print('Błąd odtwarzania dźwięku karty: $e');
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) c.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_displayedCards.isEmpty) return const SizedBox.shrink();

    final cardAspectRatio = 0.7;
    final spacing = 8.0;

    // Obliczamy rozmiar kart
    double calculatedHeight = widget.maxCardHeight;
    double calculatedWidth = calculatedHeight * cardAspectRatio;

    // Sprawdzamy czy zmieścimy się na szerokość
    final totalSpacing = (_displayedCards.length - 1) * spacing;
    final totalWidthNeeded = (_displayedCards.length * calculatedWidth) + totalSpacing;

    if (totalWidthNeeded > widget.maxWidth) {
      final availableWidthPerCard = (widget.maxWidth - totalSpacing) / _displayedCards.length;
      calculatedWidth = availableWidthPerCard;
      calculatedHeight = calculatedWidth / cardAspectRatio;
    }

    return SizedBox(
      height: calculatedHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _displayedCards.asMap().entries.map((entry) {
          final index = entry.key;
          final card = entry.value;

          if (index >= _controllers.length) return const SizedBox();

          return AnimatedBuilder(
            animation: _controllers[index],
            builder: (context, child) {
              return Container(
                width: calculatedWidth,
                margin: EdgeInsets.only(right: index < _displayedCards.length - 1 ? spacing : 0),
                child: Transform.translate(
                  offset: _slideAnimations[index].value * calculatedWidth,
                  child: Transform.scale(
                    scale: _scaleAnimations[index].value,
                    child: Opacity(
                      opacity: _fadeAnimations[index].value,
                      child: PokerCardWidget(
                        code: card,
                        height: calculatedHeight,
                        showFront: true,
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