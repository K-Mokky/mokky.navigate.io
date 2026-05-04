import 'dart:convert';
import 'dart:io';

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

  test('인사 이벤트는 서버 RPC와 RLS로 발신자 조작을 막는다', () {
    final schema = File('supabase/schema.sql').readAsStringSync();
    final policies = File('supabase/rls_policies.sql').readAsStringSync();
    final hardening =
        File('supabase/security_hardening_20260504.sql').readAsStringSync();

    expect(schema, contains('public.send_friend_greeting'));
    expect(hardening,
        contains('create table if not exists public.friend_greetings'));
    expect(schema, contains('sender_id,\n    recipient_id,\n    sender_name'));
    expect(schema, contains('p_recipient_id = auth.uid()'));
    expect(schema, contains('normalized_distance > 300'));
    expect(schema,
        contains('grant execute on function public.send_friend_greeting'));
    expect(policies, contains('with check (false)'));
  });

  test('보조 security definer 함수는 현재 사용자 기준으로만 판정한다', () {
    final schema = File('supabase/schema.sql').readAsStringSync();

    expect(schema, contains('and auth.uid() = p_user_id'));
    expect(
      schema,
      contains("coalesce(auth.role(), '') in ('anon', 'authenticated')"),
    );
  });

  test('Vercel 웹 배포는 SPA fallback과 보안 헤더를 포함한다', () {
    final vercel = jsonDecode(File('vercel.json').readAsStringSync())
        as Map<String, dynamic>;
    final rewrites = vercel['rewrites'] as List<dynamic>;
    final headers = vercel['headers'] as List<dynamic>;
    final headerValues =
        (headers.first as Map<String, dynamic>)['headers'] as List<dynamic>;

    expect(rewrites.first['destination'], '/index.html');
    expect(vercel['buildCommand'], contains('--no-web-resources-cdn'));
    expect(vercel['buildCommand'], contains('--csp'));
    expect(
      headerValues.any((header) =>
          header['key'] == 'Content-Security-Policy' &&
          (header['value'] as String).contains("frame-ancestors 'none'") &&
          (header['value'] as String).contains('https://www.gstatic.com')),
      isTrue,
    );
    expect(
      headerValues.any((header) => header['key'] == 'Permissions-Policy'),
      isTrue,
    );
  });
}
