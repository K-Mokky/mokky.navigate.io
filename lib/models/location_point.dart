import 'package:latlong2/latlong.dart';

class LocationPoint {
  final String userId;
  final double latitude;
  final double longitude;
  final double speed; // m/s
  final double heading; // degrees (0-360)
  final double? accuracy;
  final bool isOnline;
  final DateTime updatedAt;
  final String? roomId;
  final String? sessionId;

  LocationPoint({
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.speed = 0,
    this.heading = 0,
    this.accuracy,
    this.isOnline = true,
    required this.updatedAt,
    this.roomId,
    this.sessionId,
  });

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    final timestamp = (json['updated_at'] ?? json['recorded_at']) as String;
    return LocationPoint(
      userId: json['user_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      speed: (json['speed'] as num?)?.toDouble() ?? 0,
      heading: (json['heading'] as num?)?.toDouble() ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      isOnline: json['is_online'] as bool? ?? true,
      updatedAt: DateTime.parse(timestamp),
      roomId: (json['room_id'] ?? json['current_room_id']) as String?,
      sessionId: (json['session_id'] ?? json['current_session_id']) as String?,
    );
  }

  LatLng get latLng => LatLng(latitude, longitude);

  double get speedKmh => speed * 3.6;

  bool get isStale =>
      DateTime.now().toUtc().difference(updatedAt.toUtc()) >
      const Duration(minutes: 3);

  bool get isActive => isOnline && !isStale;

  // 이동 상태 라벨
  String get movementLabel {
    if (speedKmh < 1) return '정지';
    if (speedKmh < 5) return '걷는 중';
    if (speedKmh < 25) return '자전거/달리는 중';
    if (speedKmh < 60) return '차량 이동 중';
    return '고속 이동 중';
  }
}
