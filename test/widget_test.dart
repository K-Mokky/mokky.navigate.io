import 'package:flutter_test/flutter_test.dart';
import 'package:friend_tracker/config/supabase_config.dart';
import 'package:friend_tracker/providers/settings_provider.dart';

void main() {
  test('Supabase 기본 설정은 소스에 실제 프로젝트 값을 포함하지 않는다', () {
    expect(SupabaseConfig.url, isEmpty);
    expect(SupabaseConfig.anonKey, isEmpty);
    expect(SupabaseConfig.authRedirectUrl, 'radar://auth-callback/');
    expect(SupabaseConfig.isConfigured, isFalse);
  });

  test('근접 알림은 300m 진입 후 5km 이탈 시 재무장된다', () {
    expect(SupabaseConfig.proximityThresholdMeters, 300);
    expect(SupabaseConfig.proximityResetThresholdMeters, 5000);
    expect(SupabaseConfig.greetingNotificationCooldown.inSeconds, 3);
  });

  test('위치 업로드 주기는 이동 중 2초, 정지 중 10초다', () {
    expect(SupabaseConfig.movingLocationUploadInterval.inSeconds, 2);
    expect(SupabaseConfig.stationaryLocationUploadInterval.inSeconds, 10);
    expect(SupabaseConfig.locationUploadIntervalForSpeed(0).inSeconds, 10);
    expect(SupabaseConfig.locationUploadIntervalForSpeed(1 / 3.6).inSeconds, 2);
  });

  test('속도 단위는 km/h와 mph 표시를 지원한다', () {
    expect(SpeedUnit.kmh.formatFromKmh(10), '10 km/h');
    expect(SpeedUnit.mph.formatFromKmh(10), '6 mph');
  });
}
