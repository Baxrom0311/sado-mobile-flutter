abstract final class AppConstants {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://p01--sado-api--p5cg7q2cqsmk.code.run/api/v1',
  );
  static const appName = 'SADO';
  static const maxAudioDuration = Duration(seconds: 60);
  static const tokenRefreshBuffer = Duration(minutes: 2);
}
