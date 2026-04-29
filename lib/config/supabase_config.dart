import 'package:flutter/foundation.dart';

class SupabaseConfig {
  // Supabase 프로젝트 설정은 소스에 커밋하지 않고 dart-define으로 주입합니다.
  // flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  static String get authRedirectUrl {
    const configured = String.fromEnvironment('SUPABASE_AUTH_REDIRECT_URL');
    if (configured.isNotEmpty) return configured;

    // Web builds must redirect back to the browser origin so Supabase can
    // complete email confirmation / magic-link flows inside the web app.
    if (kIsWeb) return Uri.base.origin;

    return 'radar://auth-callback/';
  }

  static bool get isConfigured =>
      url.startsWith('https://') &&
      Uri.tryParse(url)?.isAbsolute == true &&
      anonKey.isNotEmpty;

  // 친구 근접 알림/인사 가능 거리 (미터)
  static const double proximityThresholdMeters = 300.0;

  // 근접 알림을 다시 받을 수 있게 되는 재진입 기준 거리 (미터)
  static const double proximityResetThresholdMeters = 5000.0;

  // 인사 수신 알림 최소 간격. 너무 잦은 인사 알림을 막는다.
  static const Duration greetingNotificationCooldown = Duration(seconds: 3);

  // 위치 업로드 최소 주기. 이동 중에는 빠르게 반영하고, 정지 중에는 서버 사용량을 줄입니다.
  static const Duration movingLocationUploadInterval = Duration(seconds: 2);
  static const Duration stationaryLocationUploadInterval =
      Duration(seconds: 10);

  // UI의 '정지' 기준과 맞춰 1km/h 미만은 GPS 노이즈로 보고 정지로 처리합니다.
  static const double movingSpeedThresholdMetersPerSecond = 1 / 3.6;

  // 가장 짧은 업로드 주기. 위치 스트림 수집 주기처럼 빠른 쪽 기준이 필요한 곳에서 사용합니다.
  static const Duration locationUploadInterval = movingLocationUploadInterval;

  static Duration locationUploadIntervalForSpeed(double speedMetersPerSecond) {
    final normalizedSpeed =
        speedMetersPerSecond.isNegative ? 0.0 : speedMetersPerSecond;
    return normalizedSpeed >= movingSpeedThresholdMetersPerSecond
        ? movingLocationUploadInterval
        : stationaryLocationUploadInterval;
  }

  // 방 생성 시 기본 기록 보관 기간.
  static const int defaultRoomRetentionDays = 7;

  // 무료 플랜 용량 관리를 위해 기록방 보관 기간은 최대 7일로 제한.
  static const int maxRoomRetentionDays = 7;

  // 일반 친구 지도에 표시할 이동 경로 포인트 수.
  // 기록방의 location_history 저장 개수는 제한하지 않고 보관 기간으로 관리합니다.
  static const int pathHistoryLength = 60;
}
