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
    defaultValue:
        'https://script.google.com/macros/s/AKfycbxGzNHyaXatKZylXpE7ObHSnqwTJ_gT3-1adJkqsSrpQYYWYQ34PXLAYynavU9HJ0oo9w/exec',
  );
  static const String teacherApiKey = String.fromEnvironment(
    'ATTENDANCE_TEACHER_API_KEY',
    defaultValue: 'YHWB2BXZD92TYZecEClAIcd-BfBZdM2O8r3BxFZsekg',
  );
  static const String teacherId = String.fromEnvironment(
    'ATTENDANCE_TEACHER_ID',
    defaultValue: 'teacher-test',
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

  /// Optional Gemini API key for the Person 5 AI Assistant module.
  /// Can be supplied via `--dart-define=GEMINI_API_KEY=...` or `--dart-define=GEMINI_API_KEYS=key1,key2`
  static const String geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY');

  static const String geminiApiKeysEnv =
      String.fromEnvironment('GEMINI_API_KEYS');

  static bool get hasGeminiApiKey => initialGeminiApiKeys.isNotEmpty;

  /// Returns parsed initial Gemini API keys from environment variables.
  static List<String> get initialGeminiApiKeys {
    final raw = geminiApiKeysEnv.isNotEmpty ? geminiApiKeysEnv : geminiApiKey;
    if (raw.trim().isEmpty) return const [];
    return raw
        .split(RegExp(r'[,;\n]'))
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList(growable: false);
  }

  // Prevent accidental construction of this class because it only stores constants.
  const AppConfig._();
}
