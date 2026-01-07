/// Analytics configuration for Batch-20260107-101049-platformer-01
class AnalyticsConfig {
  AnalyticsConfig._();

  /// Game identifier
  static const String gameId = 'f6841ec1-8e1f-4f53-99db-6a216f12c871';
  
  /// App version
  static const String appVersion = '1.0.0';
  
  /// Backend URL for event forwarding
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://api.gamefactory.com',
  );
  
  /// API key for backend authentication
  static const String apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: '',
  );
  
  /// Whether to forward events to backend
  static const bool forwardToBackend = true;
  
  /// Debug mode logging
  static const bool debugLogging = bool.fromEnvironment('DEBUG', defaultValue: false);
}
