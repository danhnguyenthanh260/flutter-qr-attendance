class AttendanceApiException implements Exception {
  final String code;
  final String message;
  final Map<String, dynamic>? details;

  const AttendanceApiException({
    required this.code,
    required this.message,
    this.details,
  });

  bool get isRosterMissing => code == 'roster_missing';

  bool get isNotFound => code == 'not_found';

  bool get isUnauthorized => code == 'unauthorized';

  bool get isConfigurationRequired => code == 'configuration_required';

  @override
  String toString() => 'AttendanceApiException($code): $message';
}
