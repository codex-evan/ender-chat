/// Configuration constants for the app

class AppConfig {
  AppConfig._();
  
  /// WebSocket server URL
  /// Replace with your actual server address
  static const String serverUrl = 'ws://162.211.181.145:3000/ws';
  
  /// HTTPS/WSS URL (for production)
  static const String secureServerUrl = 'wss://your-domain.com/ws';
  
  /// Default file size limit (100MB)
  static const int maxFileSize = 100 * 1024 * 1024;
  
  /// Default message size limit (1MB)
  static const int maxMessageSize = 1024 * 1024;
  
  /// Reconnect delay in milliseconds
  static const int reconnectDelayMs = 3000;
  
  /// Maximum reconnect attempts
  static const int maxReconnectAttempts = 10;
  
  /// Message TTL in days
  static const int messageTtlDays = 7;
  
  /// App version
  static const String version = '1.0.0';
  
  /// App name
  static const String appName = 'EncChat';
  
  /// Deep link scheme
  static const String deepLinkScheme = 'encchat';
}
