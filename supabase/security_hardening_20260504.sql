-- ============================================================
-- 친추 - Security hardening patch (2026-05-04)
-- Existing Supabase projects can run this after schema.sql and
-- rls_policies.sql without recreating tables.
-- ============================================================

create extension if not exists "pgcrypto";

-- Older deployed databases may not have the lightweight greeting-event table
-- yet. Create it before replacing policies/functions that reference it.
create table if not exists public.friend_greetings (
  id              uuid default gen_random_uuid() primary key,
  sender_id       uuid references public.profiles(id) on delete cascade not null,
  recipient_id    uuid references public.profiles(id) on delete cascade not null,
  sender_name     text not null,
  distance_meters float8 not null default 0,
  created_at      timestamptz default now(),
  constraint friend_greetings_no_self check (sender_id != recipient_id)
);

alter table public.friend_greetings enable row level security;

create index if not exists friend_greetings_recipient_time_idx
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
      and auth.uid() = p_user_id
  );
$$;

create or replace function public.is_recording_session_owner(
  p_session_id uuid,
  p_user_id uuid,
  p_room_id uuid
)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.recording_sessions s
    where s.id = p_session_id
      and s.user_id = p_user_id
      and (p_room_id is null or s.room_id = p_room_id)
      and auth.uid() = p_user_id
  );
$$;

create or replace function public.send_friend_greeting(
  p_recipient_id uuid,
  p_distance_meters float8
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  sender_name text;
  normalized_distance float8 := coalesce(p_distance_meters, 0);
  greeting_id uuid;
begin
  if auth.uid() is null then
    raise exception 'login required';
  end if;

  if p_recipient_id is null or p_recipient_id = auth.uid() then
    raise exception 'invalid recipient';
  end if;

  if normalized_distance < 0
    or normalized_distance > 300 then
    raise exception 'greeting is only allowed within proximity range';
  end if;

  if not exists (
    select 1
    from public.friendships f
    where f.status = 'accepted'
      and (
        (f.requester_id = auth.uid() and f.addressee_id = p_recipient_id)
        or
        (f.addressee_id = auth.uid() and f.requester_id = p_recipient_id)
      )
  ) then
    raise exception 'recipient is not an accepted friend';
  end if;

  select
    coalesce(nullif(display_name, ''), username, '친구')
  into sender_name
  from public.profiles
  where id = auth.uid();

  if sender_name is null then
    raise exception 'sender profile not found';
  end if;

  insert into public.friend_greetings (
    sender_id,
    recipient_id,
    sender_name,
    distance_meters
  )
  values (
    auth.uid(),
    p_recipient_id,
    left(sender_name, 80),
    normalized_distance
  )
  returning id into greeting_id;

  return greeting_id;
end;
$$;

revoke execute on function public.send_friend_greeting(uuid, float8)
  from public, anon;
grant execute on function public.send_friend_greeting(uuid, float8)
  to authenticated;

drop policy if exists "friend_greetings_select" on public.friend_greetings;
drop policy if exists "friend_greetings_insert" on public.friend_greetings;

create policy "friend_greetings_select"
  on public.friend_greetings for select
  to authenticated
  using (
    sender_id = auth.uid()
    or recipient_id = auth.uid()
  );

create policy "friend_greetings_insert"
  on public.friend_greetings for insert
  to authenticated
  with check (false);

create or replace function public.cleanup_expired_recording_rooms()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_count integer;
begin
  if coalesce(auth.role(), '') in ('anon', 'authenticated') then
    raise exception 'cleanup requires privileged execution';
  end if;

  delete from public.recording_rooms
  where expires_at < now();

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

revoke execute on function public.cleanup_expired_recording_rooms()
  from public, anon, authenticated;
