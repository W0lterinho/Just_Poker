import 'player_dto.dart';

class SyncDTO {
  final bool gameStarted;
  final int? updateNumber;
  final int pot;
  final String? nextPlayerMail;
  final int nextPlayerToCall;
  final String? dealerMail;
  final List<String> communityCards;
  final Map<String, PlayerDto> players;
  final List<String> myCards;
  final List<String> eliminatedEmails;

  SyncDTO({
    required this.gameStarted,
    this.updateNumber,
    required this.pot,
    this.nextPlayerMail,
    required this.nextPlayerToCall,
    this.dealerMail,
    required this.communityCards,
    required this.players,
    required this.myCards,
    required this.eliminatedEmails,
  });

  factory SyncDTO.fromJson(Map<String, dynamic> json) {
    // Parsowanie mapy graczy
    final playersMap = <String, PlayerDto>{};
    if (json['players'] is Map<String, dynamic>) {
      (json['players'] as Map<String, dynamic>).forEach((email, playerData) {
        if (playerData is Map<String, dynamic>) {
          playersMap[email] = PlayerDto.fromMap(playerData);
        }
      });
    }

    return SyncDTO(
      gameStarted: json['gameStarted'] as bool? ?? false,
      updateNumber: json['updateNumber'] as int?,
      pot: json['pot'] as int? ?? 0,
      nextPlayerMail: json['nextPlayerMail'] as String?,
      nextPlayerToCall: json['nextPlayerToCall'] as int? ?? 0,
      dealerMail: json['dealerMail'] as String?,
      communityCards: json['communityCards'] != null
          ? List<String>.from(json['communityCards'])
          : [],
      players: playersMap,
      myCards: json['myCards'] != null
          ? List<String>.from(json['myCards'])
          : [],
      eliminatedEmails: json['eliminatedEmails'] != null
          ? List<String>.from(json['eliminatedEmails'])
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    final playersJson = <String, dynamic>{};
    players.forEach((email, player) {
      playersJson[email] = player.toMap();
    });

    return {
      'gameStarted': gameStarted,
      'updateNumber': updateNumber,
      'pot': pot,
      'nextPlayerMail': nextPlayerMail,
      'nextPlayerToCall': nextPlayerToCall,
      'dealerMail': dealerMail,
      'communityCards': communityCards,
      'players': playersJson,
      'myCards': myCards,
      'eliminatedEmails': eliminatedEmails,
    };
  }
}