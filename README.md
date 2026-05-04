# 친추

친구를 추적하자! 친구들의 실시간 위치, 이동 경로, 현재 속도와 상태를 게임 미니맵처럼 보여주는 Flutter 앱입니다. iOS와 Flutter Web을 지원하며, 백엔드는 Supabase(Auth/Postgres/Realtime)를 사용합니다.

## 핵심 기능

- Supabase 이메일 로그인/회원가입 및 사용자 프로필
- 친구 검색, 친구 요청, 수락/거절, 삭제
- 앱 실행 중 내 위치 실시간 업로드
- 지도 위 친구 위치 마커, 온라인 상태, 이동 속도 표시
- 내 이동 경로와 친구별 최근 이동 경로 폴리라인
- 설정 가능한 근접 거리 안에 친구가 들어오면 로컬 알림
- 친구 정보 시트에서 FaceTime 영상/음성 통화 연결
- 위치 공유 OFF 시 최신 위치를 오프라인으로 내리고 지도/경로 노출 차단
- 기록 공유 방 생성, 초대 링크/코드 참여
- 기록 시작~종료 동안 이동 중 2초마다, 정지 중 10초마다 위치/경로 저장
- 기록 종료 후 총 이동 거리와 만난 참가자 요약 저장
- Flutter Web에서 한국어 텍스트가 브라우저 폰트 fallback에 의존하지 않도록 Noto Sans KR을 앱에 번들

## 현재 기록 정책

- 위치 업로드: 기록 중 **이동 중 2초마다 1회, 정지 중 10초마다 1회**
- 기본 보관 기간: **7일**
- 방별 보관 기간: 생성 시 1~7일 선택
- 기록 저장 개수/거리: 별도 개수 제한 없음
- 만난 친구 기준: 같은 방 참가자가 50m 이내 진입
- 만료 정리: `public.cleanup_expired_recording_rooms()` 실행 시 방/세션/경로 기록 삭제

## 빠른 시작

자세한 설정은 [`SETUP.md`](SETUP.md)를 참고하세요.

```bash
flutter create . --platforms=web --org com.yourcompany --project-name friend_tracker
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

Supabase SQL Editor에서 다음 순서로 실행하세요.

1. `supabase/schema.sql`
2. `supabase/rls_policies.sql`
3. 기존 프로젝트를 보강할 때는 `supabase/security_hardening_20260504.sql`

실제 Supabase URL과 publishable/anon key는 `--dart-define`으로만 주입하고 저장소에는 커밋하지 않습니다.
친구 검색과 기록방 멤버 조회는 공개 프로필 필드만 반환하도록 SQL RPC/RLS가 분리되어 있습니다.
인사 이벤트도 `send_friend_greeting` RPC를 통해 서버가 발신자/거리/친구 관계를 검증합니다.

Supabase Authentication → URL Configuration에는 웹 실행 주소를 등록하세요.
로컬 웹 개발은 `http://localhost:*` 또는 실제 Chrome 실행 URL을, 배포 후에는 배포 도메인을
`Site URL`/`Redirect URLs`에 추가합니다. iOS도 함께 쓸 경우 기존 `radar://auth-callback/`도 유지하세요.

## 웹 실행 / 빌드

```bash
# 개발 서버
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY

# 정적 웹 산출물 생성
flutter build web \
  --web-renderer html \
  --no-web-resources-cdn \
  --csp \
  --pwa-strategy=none \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

빌드 결과는 `build/web/`에 생성되며 정적 호스팅(Netlify, Vercel, Supabase Storage 등)에 배포할 수 있습니다.
브라우저 위치 권한은 HTTPS 또는 `localhost`에서만 정상 동작합니다.
배포 빌드는 stale service worker 캐시로 인한 흰 화면/글자 미표시를 방지하기 위해 `--pwa-strategy=none`을 사용합니다.
데스크톱 브라우저별 WebGL/CanvasKit 차이로 글자가 사라지는 상황을 피하려고 배포 빌드는 Flutter 3.24.5에서 검증한 `--web-renderer html`을 사용합니다.

> 이 저장소는 앱의 Flutter/Dart 구현과 Supabase SQL을 포함합니다. iOS 위치 권한, 백그라운드 위치 모드, FaceTime URL 스킴과 `radar://` 인증 콜백 스킴은 `ios/Runner/Info.plist`에 반영되어 있으며, `ios/Runner/Info.plist.additions.xml`은 참고용입니다.
