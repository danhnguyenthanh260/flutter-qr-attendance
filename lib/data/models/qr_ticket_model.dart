class QrTicketModel {
  final String ticketCode;
  final String formUrl;
  final int generation;
  final int validSeconds;
  final DateTime createdAt;
  final DateTime expiresAt;

  const QrTicketModel({
    required this.ticketCode,
    required this.formUrl,
    required this.generation,
    required this.validSeconds,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  int get remainingSeconds {
    final diff = expiresAt.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  factory QrTicketModel.fromJson(Map<String, dynamic> json) {
    return QrTicketModel(
      ticketCode: json['ticket_code'] as String,
      formUrl: json['form_url'] as String,
      generation: json['generation'] as int,
      validSeconds: json['valid_seconds'] as int? ?? 30,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ticket_code': ticketCode,
      'form_url': formUrl,
      'generation': generation,
      'valid_seconds': validSeconds,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QrTicketModel &&
          runtimeType == other.runtimeType &&
          ticketCode == other.ticketCode;

  @override
  int get hashCode => ticketCode.hashCode;
}
