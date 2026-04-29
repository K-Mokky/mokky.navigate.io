import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const initSettings = InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    await _plugin.initialize(initSettings);
  }

  static Future<void> showProximityAlert({
    required String friendName,
    required double distanceMeters,
    required String friendId,
  }) async {
    final distance = formatDistance(distanceMeters);

    await _plugin.show(
      friendId.hashCode.abs(),
      '친구가 근처에 있어요!',
      '$friendName이 $distance 안에 있습니다! 어서 인사해보세요!',
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
        ),
      ),
    );
  }

  static Future<void> showGreetingAlert({
    required String senderName,
    required double distanceMeters,
    required String senderId,
  }) async {
    final distance = formatDistance(distanceMeters);

    await _plugin.show(
      'greeting_$senderId'.hashCode.abs(),
      '친구가 인사했어요!',
      '$distance만큼 떨어져있는 $senderName이 인사합니다!',
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
        ),
      ),
    );
  }

  static String formatDistance(double distanceMeters) {
    if (distanceMeters < 1000) return '${distanceMeters.round()}m';
    return '${(distanceMeters / 1000).toStringAsFixed(1)}km';
  }
}
