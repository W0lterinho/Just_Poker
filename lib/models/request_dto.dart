class RequestDTO {
  final String? tableName;
  final int? tableCode;
  final String playerMail;
  final int? chips;

  RequestDTO({
    this.tableName,
    this.tableCode,
    required this.playerMail,
    this.chips,
  });

  factory RequestDTO.fromJson(Map<String, dynamic> json) => RequestDTO(
    tableName: json['tableName'] as String?,
    tableCode: json['tableCode'] as int?,
    playerMail: json['playerMail'] as String,
    chips: json['chips'] as int?,
  );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'tableName': tableName,
      'tableCode': tableCode,
      'playerMail': playerMail,
    };
    if (chips != null) map['chips'] = chips;
    return map;
  }
}

