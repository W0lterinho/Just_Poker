class StateDTO {
  final String? actionPlayerMail;
  final String? action;
  final int? chipsInRound;
  final int? chipsLeft;
  final int? pot;
  final int? nextPlayerToCall; // NOWE - kwota którą trzeba wpłacić żeby grać dalej
  final String? nextPlayerMail;
  final int? updateNumber; // NOWE - dla gap detection

  StateDTO({
    this.actionPlayerMail,
    this.action,
    this.chipsInRound,
    this.chipsLeft,
    this.pot,
    this.nextPlayerToCall,
    this.nextPlayerMail,
    this.updateNumber,
  });

  factory StateDTO.fromJson(Map<String, dynamic> json) => StateDTO(
    actionPlayerMail: json['actionPlayerMail'] as String?,
    action: json['action'] as String?,
    chipsInRound: json['chipsInRound'] as int?,
    chipsLeft: json['chipsLeft'] as int?,
    pot: json['pot'] as int?,
    nextPlayerToCall: json['nextPlayerToCall'] as int?,
    nextPlayerMail: json['nextPlayerMail'] as String?,
    updateNumber: json['updateNumber'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'actionPlayerMail': actionPlayerMail,
    'action': action,
    'chipsInRound': chipsInRound,
    'chipsLeft': chipsLeft,
    'pot': pot,
    'nextPlayerToCall': nextPlayerToCall,
    'nextPlayerMail': nextPlayerMail,
    'updateNumber': updateNumber,
  };
}