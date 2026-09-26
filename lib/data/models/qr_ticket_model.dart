class QrTicketModel {
  final String ticketCode;
  final String formUrl;
  final int generation;
  final int validSeconds;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? localExpiresAt;

  const QrTicketModel({
    required this.ticketCode,
    required this.formUrl,
    required this.generation,
    required this.validSeconds,
    required this.createdAt,
    required this.expiresAt,
    this.localExpiresAt,
  });

  bool get isExpired => remainingSeconds == 0;

  int get remainingSeconds {
    final diff = (localExpiresAt ?? expiresAt)
        .difference(DateTime.now())
        .inSeconds;
    return diff.clamp(0, validSeconds);
  }

  factory QrTicketModel.fromJson(
    Map<String, dynamic> json, {
    Duration transit = Duration.zero,
  }) {
    final expiresAt = DateTime.parse(json['expires_at'] as String);
    final serverTime = DateTime.tryParse(json['server_time'] as String? ?? '');
    // Subtract the full round trip conservatively; local clock skew must not
    // make a server-expired ticket appear valid.
    final localExpiry = serverTime == null
        ? null
        : DateTime.now().add(expiresAt.difference(serverTime) - transit);
    return QrTicketModel(
      ticketCode: json['ticket_code'] as String,
      formUrl: json['form_url'] as String,
      generation: json['generation'] as int,
      validSeconds: json['valid_seconds'] as int? ?? 30,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: expiresAt,
      localExpiresAt: localExpiry,
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
