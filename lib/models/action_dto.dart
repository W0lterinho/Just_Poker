class ActionDTO {
  final String action;
  final String playerEmail;
  final int chips;
  final String? tableName;
  final int? tableCode;

  ActionDTO({
    required this.action,
    required this.playerEmail,
    required this.chips,
    this.tableName,
    this.tableCode,
  });

  factory ActionDTO.fromJson(Map<String, dynamic> json) => ActionDTO(
    action: json['action'] as String,
    playerEmail: json['playerEmail'] as String,
    chips: json['chips'] as int,
    tableName: json['tableName'] as String?,
    tableCode: json['tableCode'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'action': action,
    'playerEmail': playerEmail,
    'chips': chips,
    'tableName': tableName,
    'tableCode': tableCode,
  };
}
