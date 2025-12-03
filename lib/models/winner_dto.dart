class WinnerDTO {
  final String winnerEmail;
  final int winnerChips;
  final int winSize;

  WinnerDTO({
    required this.winnerEmail,
    required this.winnerChips,
    required this.winSize,
  });

  factory WinnerDTO.fromJson(Map<String, dynamic> json) => WinnerDTO(
    winnerEmail: json['winnerEmail'] as String,
    winnerChips: json['winnerChips'] as int,
    winSize: json['winSize'] as int,
  );

  Map<String, dynamic> toJson() => {
    'winnerEmail': winnerEmail,
    'winnerChips': winnerChips,
    'winSize': winSize,
  };

  @override
  String toString() => 'WinnerDTO(email: $winnerEmail, chips: $winnerChips, winSize: $winSize)';
}