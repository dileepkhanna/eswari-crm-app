class ApiConfig {
  // Change to your server IP for local dev, or domain for production
  // static const String baseUrl = 'http://10.0.2.2:8000/api'; // Android emulator
  // static const String baseUrl = 'http://192.168.0.183:8000/api'; // Real device on WiFi
  static const String baseUrl = 'http://127.0.0.1:8000/api'; // Real device via ADB reverse (requires: adb reverse tcp:8000 tcp:8000)
  // static const String baseUrl = 'https://your-domain.com/api'; // Production

  static const String login        = '/auth/login/';
  static const String tokenRefresh = '/auth/token/refresh/';
  static const String profile      = '/auth/profile/';
  static const String users        = '/auth/users/';
  static const String leads        = '/leads/';
  static const String tasks        = '/tasks/';
  static const String leaves       = '/leaves/';
  static const String projects     = '/projects/';
  static const String customers    = '/customers/';
  static const String announcements= '/announcements/';
  static const String notifications= '/notifications/';
  static const String holidays     = '/holidays/';
  static const String birthdays    = '/birthdays/';
  static const String activityLogs = '/activity-logs/';
}
