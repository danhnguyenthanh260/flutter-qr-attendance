/// Central application configuration.
///
/// Values in this file are safe for the Flutter client to use. The Web App URL
/// is an endpoint, not a Google account credential or a private access token.
class AppConfig {
  /// Google Apps Script Web App endpoint used by the Flutter application.
  ///
  /// Keep the `/exec` suffix because it points to the deployed version that
  /// the application is allowed to call.
  static const String googleSheetsApiUrl =
      'https://script.google.com/macros/s/AKfycbyk6yBoDmp3DpFXNjyHuTOeno7eFF6odQNMIQ1-FruSME9ZlUOcGSNoCplElJ_-Poz-xQ/exec';

  /// Runtime values for the new authenticated teacher API. They intentionally
  /// have no source-controlled defaults: deployment must supply them with
  /// `--dart-define` after the Apps Script Web App is configured.
  static const String teacherApiUrl = String.fromEnvironment(
    'ATTENDANCE_TEACHER_API_URL',
  );
  static const String teacherApiKey = String.fromEnvironment(
    'ATTENDANCE_TEACHER_API_KEY',
  );
  static const String teacherId = String.fromEnvironment(
    'ATTENDANCE_TEACHER_ID',
  );

  /// Opt-in switch for the seeded in-memory dataset. It is never enabled by
  /// default, so a release without teacher API configuration still fails closed
  /// instead of showing demo numbers as if they were real attendance.
  static const bool useSeededMockData = bool.fromEnvironment(
    'ATTENDANCE_USE_MOCK',
  );

  static bool get hasTeacherApiConfiguration =>
      teacherApiUrl.isNotEmpty &&
      teacherApiKey.isNotEmpty &&
      teacherId.isNotEmpty;

  // Prevent accidental construction of this class because it only stores constants.
  const AppConfig._();
}
