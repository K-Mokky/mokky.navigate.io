import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../config/supabase_config.dart';

class LocationService {
  static StreamSubscription<Position>? _subscription;

  static Future<bool> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  static Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static StreamSubscription<Position> startTracking(
      void Function(Position) onUpdate) {
    _subscription?.cancel();

    final LocationSettings settings;
    if (kIsWeb) {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        distanceFilter: 5,
        pauseLocationUpdatesAutomatically: false,
        // 백그라운드 위치 표시 상태바 (Info.plist에 UIBackgroundModes location 필요)
        showBackgroundLocationIndicator: true,
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        intervalDuration: SupabaseConfig.movingLocationUploadInterval,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: '친추가 기록방 위치를 기록 중입니다',
          notificationTitle: '위치 기록 활성화',
          enableWakeLock: true,
        ),
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
    }

    _subscription = Geolocator.getPositionStream(locationSettings: settings)
        .listen(onUpdate);
    return _subscription!;
  }

  static Future<void> stopTracking() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  static double distanceBetween(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }
}
