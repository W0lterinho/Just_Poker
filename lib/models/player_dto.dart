import 'dart:convert';

class PlayerDto {
  final String email;
  final String nickName;
  final List<String> playerCards;
  final int chips;
  final int seatIndex;
  final int chipsInRound;
  final bool isFolded; // NOWE POLE - czy gracz spasował

  PlayerDto({
    required this.email,
    required this.nickName,
    required this.playerCards,
    required this.chips,
    required this.seatIndex,
    required this.chipsInRound,
    this.isFolded = false,
  });

  factory PlayerDto.fromMap(Map<String, dynamic> map) {
    String parsedNick = '';
    try {
      parsedNick = (jsonDecode(map['name']) as Map<String, dynamic>)['nickName'];
    } catch (e) {
      parsedNick = map['name'].toString();
    }
    return PlayerDto(
      email: map['email'],
      nickName: parsedNick,
      playerCards: List<String>.from(map['playerCards'] ?? []),
      chips: map['chips'] ?? 0,
      seatIndex: map['seatIndex'] ?? 1,
      chipsInRound: map['chipsInRound'] ?? 0,
      isFolded: map['isFolded'] ?? map['folded'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'email': email,
    'name': jsonEncode({'nickName': nickName}),
    'playerCards': playerCards,
    'chips': chips,
    'seatIndex': seatIndex,
    'chipsInRound': chipsInRound,
    'isFolded': isFolded,
  };

  PlayerDto copyWith({
    String? email,
    String? nickName,
    List<String>? playerCards,
    int? chips,
    int? seatIndex,
    int? chipsInRound,
    bool? isFolded,
  }) {
    return PlayerDto(
      email: email ?? this.email,
      nickName: nickName ?? this.nickName,
      playerCards: playerCards ?? this.playerCards,
      chips: chips ?? this.chips,
      seatIndex: seatIndex ?? this.seatIndex,
      chipsInRound: chipsInRound ?? this.chipsInRound,
      isFolded: isFolded ?? this.isFolded,
    );
  }
}