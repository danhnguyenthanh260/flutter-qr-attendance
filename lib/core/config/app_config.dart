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

  // Prevent accidental construction of this class because it only stores constants.
  const AppConfig._();
}
