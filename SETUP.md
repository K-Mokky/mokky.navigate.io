# 친추 - 설정 가이드

## 1. Flutter 프로젝트 초기화

```bash
# 프로젝트 루트에서 실행
# Flutter Web 플랫폼 파일까지 함께 생성
flutter create . --platforms=web --org com.yourcompany --project-name friend_tracker
# (기존 lib/ 파일들을 덮어쓰지 않도록 주의)
```

## 2. Supabase 설정

### 2-1. 프로젝트 생성
[app.supabase.com](https://app.supabase.com)에서 새 프로젝트를 생성합니다.

### 2-2. 스키마 및 RLS 정책 적용
Supabase 콘솔 → **SQL Editor**에서 다음 순서로 실행:
1. `supabase/schema.sql`
2. `supabase/rls_policies.sql`

### 2-3. Realtime 활성화
Supabase 콘솔 → **Database → Replication** →  
`locations` 테이블을 Realtime 대상에 추가합니다.

### 2-4. 앱에 키 입력
실행 시 `--dart-define`으로 주입합니다. 프로젝트 URL/publishable key를 소스에 직접 넣어 커밋하지 마세요.

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGc...
```

> 키는 Supabase 콘솔 → **Settings → API**에서 확인할 수 있습니다. `anon`/`publishable` key는 클라이언트에 포함되는 공개 키지만, 저장소에는 실제 프로젝트 값을 커밋하지 않고 RLS 정책으로 접근을 제한합니다.

### 2-5. 회원가입 인증 메일 Redirect URL 설정

Supabase 콘솔 → **Authentication → URL Configuration**에서 아래 값을 설정합니다.

#### Flutter Web

| 항목 | 값 |
|------|----|
| Site URL | 배포 주소 예: `https://your-domain.com` |
| Redirect URLs | `http://localhost:*`, 배포 주소 예: `https://your-domain.com` |

웹에서는 `SUPABASE_AUTH_REDIRECT_URL`을 따로 주입하지 않으면 현재 브라우저 origin으로
리다이렉트합니다. 배포 도메인이 있으면 아래처럼 명시해도 됩니다.

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGc... \
  --dart-define=SUPABASE_AUTH_REDIRECT_URL=http://localhost:12345
```

#### iOS 앱도 함께 사용할 때

| 항목 | 값 |
|------|----|
| Site URL | `radar://auth-callback/` |
| Redirect URLs | `radar://auth-callback/` |

iOS 앱의 회원가입 코드는 기본적으로 `emailRedirectTo`로 `radar://auth-callback/`을 전달합니다.
웹 빌드는 현재 웹 주소를 전달합니다. 필요한 플랫폼의 Redirect URL이 빠져 있으면
Supabase 기본값이나 허용되지 않은 URL로 이동할 수 있습니다.

이메일 템플릿을 직접 수정한 적이 있다면 **Authentication → Email Templates**에서
확인 링크가 `{{ .ConfirmationURL }}`을 사용하거나, redirect 값을 직접 조립하는 경우
`{{ .RedirectTo }}`를 사용하도록 맞춰야 합니다.

## 3. iOS 권한 설정

`ios/Runner/Info.plist`에는 위치 권한, 백그라운드 위치 모드, FaceTime URL 스킴,
`radar://` 초대 링크 및 인증 콜백 스킴이 이미 반영되어 있습니다.
`ios/Runner/Info.plist.additions.xml`은 같은 설정을 다시 확인할 때 참고하세요.

## 4. 패키지 설치 및 실행

```bash
flutter pub get
flutter run
```

웹에서 실행하려면:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGc...
```

정적 웹 앱으로 빌드하려면:

```bash
flutter build web \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGc...
```

생성된 `build/web/` 폴더를 정적 호스팅에 업로드하면 됩니다. 위치 기능은 브라우저 보안 정책상
HTTPS 또는 `localhost`에서만 권한 요청과 좌표 취득이 안정적으로 동작합니다.

## 5. 주요 기능

| 기능 | 설명 |
|------|------|
| 실시간 지도 | CARTO Dark Matter 타일 기반 다크 게임맵 스타일 |
| 친구 마커 | 이름, 온라인 상태, 이동 속도 배지 표시 |
| 이동 경로 | 최근 60개 포인트를 색상 폴리라인으로 표시 |
| 속도 표시 | 우측 원형 속도계 (정지/저속/고속별 색상 변화) |
| 근접 알림 | 500m 이내 접근 시 모바일은 로컬 푸시, 웹은 앱 상단 인앱 알림으로 표시 |
| FaceTime | 친구 마커 탭 → 영상/음성 FaceTime 바로 연결(웹은 브라우저/OS 지원 범위에 따름) |
| 방향 표시 | 내 마커에 이동 방향 삼각형 + 펄스 애니메이션 |
| 위치 프라이버시 | 위치 공유 OFF 시 온라인 상태와 지도 마커/경로 노출 중단 |
| 기록 공유 방 | 방 생성 → 링크/코드 공유 → 참가자별 기록 시작/종료 |
| 기록 요약 | 기록 종료 시 총 이동 거리와 만난 참가자 저장 |

### 위치 기록 정책

| 항목 | 현재 설정 |
|------|-----------|
| 위치 업로드 주기 | 기록 중 이동 중 2초마다 1회, 정지 중 10초마다 1회 |
| 기본 방 유지/보관 기간 | 7일 |
| 방 생성 시 보관 기간 | 1~7일 선택 |
| 기록 저장 개수 | 제한 없음, 방 만료/정리 시 삭제 |
| 만난 친구 기준 | 같은 방 참가자가 50m 이내 진입 |
| 일반 지도 경로 표시 | 최근 60포인트만 표시 |

> Supabase Free Plan에서 7일 보관을 안정적으로 유지하려면
> `public.cleanup_expired_recording_rooms()`를 주기적으로 실행하세요.
> pg_cron 사용 가능 환경이라면 `supabase/schema.sql` 하단의 예시 cron을 활성화하면 됩니다.

## 5-1. 회원가입 이메일 확인 설정

Supabase Auth에서 이메일 확인을 켜도 동작하도록 `schema.sql`의
`handle_new_user()` 트리거가 `auth.users.raw_user_meta_data`를 기반으로
`profiles` 행을 자동 생성합니다. 앱의 회원가입 코드는 username/display name/phone을
auth metadata로 전달하고, 즉시 세션이 생기는 설정에서는 클라이언트가 한 번 더 upsert로
보강합니다.

## 6. 근접 알림 거리 조정

`lib/config/supabase_config.dart`:
```dart
static const double proximityThresholdMeters = 500.0; // 원하는 거리(미터)로 변경
```

## 6-1. 기록방 기본 보관 기간 / 업로드 주기 조정

`lib/config/supabase_config.dart`:

```dart
static const Duration movingLocationUploadInterval = Duration(seconds: 2);
static const Duration stationaryLocationUploadInterval = Duration(seconds: 10);
static const int defaultRoomRetentionDays = 7;
static const int maxRoomRetentionDays = 7;
static const double encounterThresholdMeters = 50.0;
```

## 7. 아키텍처

```
lib/
├── config/          # Supabase 설정
├── models/          # 데이터 모델 (UserProfile, LocationPoint, Friendship)
├── services/        # API 호출 (Supabase, 위치, 알림, FaceTime)
├── providers/       # 상태 관리 (Provider)
├── screens/         # 화면 (Splash, 로그인, 회원가입, 지도, 친구)
└── widgets/         # 재사용 위젯 (마커, 속도계, 정보 시트)

supabase/
├── schema.sql       # 테이블 정의
└── rls_policies.sql # Row Level Security
```
