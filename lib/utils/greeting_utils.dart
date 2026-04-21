/// Utility functions for time-based greetings
/// Returns greeting based on Indian Standard Time (IST)

String getGreeting() {
  // Get current time in IST (UTC+5:30)
  final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  final hour = now.hour;

  if (hour >= 5 && hour < 12) {
    return 'Good morning';
  } else if (hour >= 12 && hour < 17) {
    return 'Good afternoon';
  } else if (hour >= 17 && hour < 21) {
    return 'Good evening';
  } else {
    return 'Good night';
  }
}
