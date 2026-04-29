-- ============================================================
-- 친추 - 친구 추적기
-- Supabase Database Schema
-- ============================================================
-- Supabase 콘솔 > SQL Editor에서 실행하세요.
-- https://app.supabase.com/project/_/sql

-- ─── Extensions ────────────────────────────────────────────
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ─── profiles ──────────────────────────────────────────────
-- auth.users와 1:1 연결되는 사용자 프로필
create table public.profiles (
  id           uuid references auth.users on delete cascade primary key,
  username     text unique not null,
  display_name text,
  avatar_url   text,
  phone        text,        -- FaceTime 전화번호
  email        text,        -- FaceTime 이메일 (로그인 이메일과 동일하게 사용)
  is_sharing_location boolean default true,
  created_at   timestamptz default now()
);

alter table public.profiles enable row level security;

-- ─── locations ─────────────────────────────────────────────
-- 사용자별 최신 위치 (1행 유지, upsert로 갱신)
create table public.locations (
  id          uuid default gen_random_uuid() primary key,
  user_id     uuid references public.profiles(id) on delete cascade not null,
  current_room_id uuid,
  current_session_id uuid,
  latitude    float8 not null,
  longitude   float8 not null,
  speed       float8 default 0,    -- m/s
  heading     float8 default 0,    -- 도 (0-360)
  accuracy    float8,              -- 미터
  is_online   boolean default true,
  updated_at  timestamptz default now(),
  constraint locations_user_id_unique unique (user_id)
);

alter table public.locations enable row level security;

-- Realtime 활성화 (친구 위치 실시간 수신)
-- 이미 추가된 테이블을 다시 추가하면 에러가 나므로 idempotent하게 처리
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'locations'
  ) then
    alter publication supabase_realtime add table public.locations;
  end if;
end $$;

-- ─── recording_rooms ───────────────────────────────────────
-- 위치 기록 공유 방. expires_at이 방 유지 기간이자 기록 보관 만료 시점.
create table public.recording_rooms (
  id             uuid default gen_random_uuid() primary key,
  creator_id     uuid references public.profiles(id) on delete cascade not null,
  name           text not null,
  invite_code    text unique not null,
  retention_days integer not null default 7
    check (retention_days between 1 and 7),
  expires_at     timestamptz not null,
  created_at     timestamptz default now()
);

alter table public.recording_rooms enable row level security;

-- ─── room_members ──────────────────────────────────────────
create table public.room_members (
  room_id   uuid references public.recording_rooms(id) on delete cascade not null,
  user_id   uuid references public.profiles(id) on delete cascade not null,
  role      text check (role in ('owner', 'member')) default 'member',
  joined_at timestamptz default now(),
  primary key (room_id, user_id)
);

alter table public.room_members enable row level security;

-- ─── recording_sessions ────────────────────────────────────
-- 사용자가 기록 시작~종료를 누른 한 번의 기록 세션.
create table public.recording_sessions (
  id                    uuid default gen_random_uuid() primary key,
  room_id               uuid references public.recording_rooms(id)
                          on delete cascade not null,
  user_id               uuid references public.profiles(id)
                          on delete cascade not null,
  started_at            timestamptz default now(),
  ended_at              timestamptz,
  total_distance_meters float8 default 0,
  met_friend_ids        uuid[] default '{}',
  summary               jsonb default '{}'::jsonb
);

alter table public.recording_sessions enable row level security;

alter table public.locations
  add constraint locations_current_room_id_fkey
  foreign key (current_room_id)
  references public.recording_rooms(id)
  on delete set null;

alter table public.locations
  add constraint locations_current_session_id_fkey
  foreign key (current_session_id)
  references public.recording_sessions(id)
  on delete set null;

-- ─── location_history ──────────────────────────────────────
-- 이동 경로 기록. 방 기록 중일 때만 room_id/session_id와 함께 저장.
create table public.location_history (
  id          uuid default gen_random_uuid() primary key,
  user_id     uuid references public.profiles(id) on delete cascade not null,
  room_id     uuid references public.recording_rooms(id) on delete cascade,
  session_id  uuid references public.recording_sessions(id) on delete cascade,
  latitude    float8 not null,
  longitude   float8 not null,
  speed       float8 default 0,
  heading     float8 default 0,
  recorded_at timestamptz default now()
);

alter table public.location_history enable row level security;

-- 조회 성능 인덱스
create index location_history_user_time_idx
  on public.location_history(user_id, recorded_at desc);

create index location_history_room_time_idx
  on public.location_history(room_id, recorded_at);

create index locations_current_room_idx
  on public.locations(current_room_id, updated_at desc);

-- ─── friendships ───────────────────────────────────────────
create table public.friendships (
  id            uuid default gen_random_uuid() primary key,
  requester_id  uuid references public.profiles(id) on delete cascade not null,
  addressee_id  uuid references public.profiles(id) on delete cascade not null,
  status        text check (status in ('pending', 'accepted', 'rejected'))
                  default 'pending',
  created_at    timestamptz default now(),
  constraint friendships_no_self check (requester_id != addressee_id)
);

alter table public.friendships enable row level security;

-- 같은 두 사용자가 방향만 바꿔 중복 요청/친구가 되는 것을 방지.
-- rejected는 새 요청을 다시 보낼 수 있도록 pending/accepted에만 적용한다.
create unique index friendships_active_pair_unique_idx
  on public.friendships (
    least(requester_id, addressee_id),
    greatest(requester_id, addressee_id)
  )
  where status in ('pending', 'accepted');

-- ─── friend_greetings ─────────────────────────────────────
-- 300m 이내 친구에게 보내는 가벼운 인사 이벤트.
-- 수신자는 Realtime 구독으로 즉시 앱 내부/로컬 알림을 받는다.
create table public.friend_greetings (
  id              uuid default gen_random_uuid() primary key,
  sender_id       uuid references public.profiles(id) on delete cascade not null,
  recipient_id    uuid references public.profiles(id) on delete cascade not null,
  sender_name     text not null,
  distance_meters float8 not null default 0,
  created_at      timestamptz default now(),
  constraint friend_greetings_no_self check (sender_id != recipient_id)
);

alter table public.friend_greetings enable row level security;

create index friend_greetings_recipient_time_idx
  on public.friend_greetings(recipient_id, created_at desc);

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'friend_greetings'
  ) then
    alter publication supabase_realtime add table public.friend_greetings;
  end if;
end $$;

-- ─── Avatar storage ───────────────────────────────────────
-- 프로필 사진은 public avatars 버킷의 {user_id}/avatar.ext 경로에 저장한다.
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = excluded.public;

-- ─── Room helpers ──────────────────────────────────────────
create or replace function public.is_room_member(
  p_room_id uuid,
  p_user_id uuid
)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.room_members m
    where m.room_id = p_room_id
      and m.user_id = p_user_id
  );
$$;

create or replace function public.join_room_by_code(p_invite_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target_room_id uuid;
begin
  select id
  into target_room_id
  from public.recording_rooms
  where invite_code = upper(trim(p_invite_code))
    and expires_at > now();

  if target_room_id is null then
    raise exception 'recording room not found or expired';
  end if;

  insert into public.room_members(room_id, user_id, role)
  values (target_room_id, auth.uid(), 'member')
  on conflict (room_id, user_id) do nothing;

  return target_room_id;
end;
$$;

create or replace function public.cleanup_expired_recording_rooms()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_count integer;
begin
  delete from public.recording_rooms
  where expires_at < now();

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

-- ─── Auto-populate email in profiles ───────────────────────
-- 회원가입 시 이메일을 profiles.email로 자동 복사
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  metadata jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  preferred_username text := coalesce(
    nullif(metadata ->> 'username', ''),
    'user_' || replace(left(new.id::text, 8), '-', '')
  );
  preferred_display_name text := coalesce(
    nullif(metadata ->> 'display_name', ''),
    preferred_username
  );
begin
  insert into public.profiles (
    id,
    username,
    display_name,
    phone,
    email
  )
  values (
    new.id,
    preferred_username,
    preferred_display_name,
    nullif(metadata ->> 'phone', ''),
    new.email
  )
  on conflict (id) do update
    set email = coalesce(public.profiles.email, excluded.email);

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ─── Auto-delete old room history ──────────────────────────
-- 방 유지 기간이 지난 기록방과 연결 기록 자동 삭제(pg_cron 사용 가능 플랜에서 실행 권장)
-- create extension if not exists pg_cron;
-- select cron.schedule('delete-expired-rooms', '0 * * * *',
--   'select public.cleanup_expired_recording_rooms()');
