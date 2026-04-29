class NotificationService {
  static Future<void> initialize() async {
    // flutter_local_notifications has no browser implementation in this app.
    // Friend/greeting notices are still shown through the in-app overlay.
  }

  static Future<void> showProximityAlert({
    required String friendName,
    required double distanceMeters,
    required String friendId,
  }) async {
    // No-op on web: browser notification permission UX should be added
    // deliberately if push notifications become a web product requirement.
  }

  static Future<void> showGreetingAlert({
    required String senderName,
    required double distanceMeters,
    required String senderId,
  }) async {
    // No-op on web; see initialize().
  }

  static String formatDistance(double distanceMeters) {
    if (distanceMeters < 1000) return '${distanceMeters.round()}m';
    return '${(distanceMeters / 1000).toStringAsFixed(1)}km';
  }
}
