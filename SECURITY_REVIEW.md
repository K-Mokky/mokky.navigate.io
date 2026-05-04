# 보안 검증 보고서

검증일: 2026-05-04  
범위: Flutter Web 앱, Vercel 정적 배포 설정, Supabase SQL schema/RLS, 인증/위치/친구/기록방 흐름

## 요약

- 전체 평가: 배포 가능 수준으로 개선됨
- Critical: 0
- High: 0
- Medium: 2개 완화 완료
- Low / 운영 주의: 2개 남음

## 외부 공격자 관점

외부 공격자는 로그인하지 않은 사용자, 임의 웹 요청자, 정적 웹 자산 접근자를 가정했다.

### 확인 결과

- Supabase URL/anon key는 소스에 실제 프로젝트 값이 없고 `--dart-define`/Vercel 환경변수로 주입된다.
- Supabase CLI 임시 연결 정보는 `supabase/.temp/` ignore 규칙으로 커밋 대상에서 제외된다.
- `profiles`, `locations`, `friendships`, `recording_rooms`, `room_members`, `recording_sessions`, `location_history`, `friend_greetings`는 RLS가 켜져 있다.
- 웹 배포에는 SPA fallback이 있어 `/map`, `/friends` 같은 직접 진입 URL이 `index.html`로 복구된다.
- Vercel 응답 헤더에 CSP, frame 차단, MIME sniffing 방지, referrer 정책, 권한 정책, HSTS가 추가됐다.
- 공개 저장소에 `.env`, private key, service-role key, 모바일 provisioning 파일이 추적되지 않는다.

### 완화한 항목

1. **정적 웹 보안 헤더 부재**
   - 영향: 클릭재킹, 과도한 브라우저 권한 노출, 약한 기본 브라우저 정책
   - 조치: `vercel.json`에 `Content-Security-Policy`, `X-Frame-Options`, `Permissions-Policy`, `X-Content-Type-Options`, `Referrer-Policy`, `Strict-Transport-Security` 추가

2. **웹 직접 URL 진입 시 정적 호스팅 404 가능성**
   - 영향: 웹 앱 라우트가 새로고침/공유 링크에서 실패
   - 조치: `vercel.json`에 SPA rewrite 추가

## 내부 공격자 관점

내부 공격자는 정상 계정을 가진 사용자가 브라우저 devtools나 직접 Supabase REST/RPC 호출로 클라이언트 값을 조작하는 상황을 가정했다.

### 완화한 항목

1. **인사 이벤트 발신자/거리 조작**
   - 기존 위험: 인증 사용자가 `friend_greetings` insert payload의 `sender_name`, `distance_meters`를 임의 조작할 수 있었다.
   - 조치:
    - 클라이언트 직접 insert를 RLS에서 차단했다.
    - `public.send_friend_greeting()` RPC가 현재 `auth.uid()`의 프로필명으로 sender를 결정한다.
    - 수신자가 수락된 친구인지 확인한다.
    - 자기 자신에게 보내는 인사와 300m 초과/음수 거리를 거부한다.
    - 기존 DB에는 `supabase/security_hardening_20260504.sql`을 적용하면 된다.

2. **security definer helper RPC 직접 호출을 통한 멤버십 판정 남용**
   - 기존 위험: `is_room_member(room_id, user_id)`, `is_recording_session_owner(session_id, user_id, room_id)`가 public RPC로 직접 호출될 경우 다른 사용자의 멤버십/세션 소유 여부를 추측하는 데 악용될 수 있었다.
   - 조치: helper 함수 내부에 `auth.uid() = p_user_id` 조건을 추가해 현재 사용자 기준으로만 참을 반환하게 했다.

3. **만료 방 정리 RPC의 일반 사용자 호출**
   - 기존 위험: 일반 인증 사용자가 정리 RPC를 직접 호출해 운영 작업을 임의 트리거할 수 있었다.
   - 조치: `public.cleanup_expired_recording_rooms()`가 `anon`/`authenticated` 역할 호출을 거부하게 했다.

## 남은 운영 주의

- `dart pub outdated`에서 다수 패키지가 최신 버전보다 낮고, 현재 Dart/Flutter pub 클라이언트가 일부 advisory 응답(`http`, `shared_preferences_android`)을 파싱하지 못하는 경고를 출력했다. 현재 빌드/테스트는 통과하지만, Flutter SDK와 의존성 업그레이드는 별도 호환성 테스트와 함께 진행하는 것이 좋다.
- 위치/기록 업로드의 서버 측 rate limit은 Supabase RLS만으로 강제하지 않았다. 악성 정상 사용자의 과도한 업로드는 Supabase quota/rate limiting, Edge Function, DB trigger 기반 제한으로 추가 방어할 수 있다.

## 검증 증거

- `flutter analyze` → No issues found
- `flutter test` → 7 tests passed
- `flutter build web` → `✓ Built build/web`
- secrets grep → 실제 Supabase key/service role/private key 패턴 미검출
- `dart pub outdated` → 네트워크 조회 성공, advisory 파싱 경고와 outdated 목록 확인
