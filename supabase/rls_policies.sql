-- ============================================================
-- 친추 - Row Level Security Policies
-- schema.sql 실행 후 이어서 실행하세요.
-- ============================================================

-- ─── profiles ──────────────────────────────────────────────

drop policy if exists "profiles_select" on public.profiles;
drop policy if exists "profiles_insert" on public.profiles;
drop policy if exists "profiles_update" on public.profiles;

-- 모든 인증 사용자가 프로필 조회 가능 (친구 검색용)
create policy "profiles_select"
  on public.profiles for select
  to authenticated
  using (true);

-- 본인 프로필만 수정 가능
create policy "profiles_insert"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

create policy "profiles_update"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- ─── locations ─────────────────────────────────────────────

drop policy if exists "locations_select" on public.locations;
drop policy if exists "locations_insert" on public.locations;
drop policy if exists "locations_update" on public.locations;

-- 친구 관계인 사용자끼리만 위치 조회 가능
create policy "locations_select"
  on public.locations for select
  to authenticated
  using (
    user_id = auth.uid()
    or (
      current_room_id is not null
      and public.is_room_member(current_room_id, auth.uid())
    )
    or (
      current_room_id is null
      and
      exists (
        select 1 from public.profiles p
        where p.id = locations.user_id
          and p.is_sharing_location = true
      )
      and exists (
        select 1 from public.friendships f
        where f.status = 'accepted'
          and (
            (f.requester_id = auth.uid() and f.addressee_id = user_id)
            or
            (f.addressee_id = auth.uid() and f.requester_id = user_id)
          )
        )
    )
  );

-- 본인 위치만 업로드 가능
create policy "locations_insert"
  on public.locations for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and (
      current_room_id is null
      or public.is_room_member(current_room_id, auth.uid())
    )
  );

create policy "locations_update"
  on public.locations for update
  to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and (
      current_room_id is null
      or public.is_room_member(current_room_id, auth.uid())
    )
  );

-- ─── recording_rooms / room_members / recording_sessions ───

drop policy if exists "recording_rooms_select" on public.recording_rooms;
drop policy if exists "recording_rooms_insert" on public.recording_rooms;
drop policy if exists "recording_rooms_update" on public.recording_rooms;
drop policy if exists "recording_rooms_delete" on public.recording_rooms;

create policy "recording_rooms_select"
  on public.recording_rooms for select
  to authenticated
  using (creator_id = auth.uid() or public.is_room_member(id, auth.uid()));

create policy "recording_rooms_insert"
  on public.recording_rooms for insert
  to authenticated
  with check (creator_id = auth.uid());

create policy "recording_rooms_update"
  on public.recording_rooms for update
  to authenticated
  using (creator_id = auth.uid())
  with check (creator_id = auth.uid());

create policy "recording_rooms_delete"
  on public.recording_rooms for delete
  to authenticated
  using (creator_id = auth.uid());

drop policy if exists "room_members_select" on public.room_members;
drop policy if exists "room_members_insert" on public.room_members;
drop policy if exists "room_members_delete" on public.room_members;

create policy "room_members_select"
  on public.room_members for select
  to authenticated
  using (public.is_room_member(room_id, auth.uid()));

create policy "room_members_insert"
  on public.room_members for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and role = 'owner'
    and exists (
      select 1
      from public.recording_rooms r
      where r.id = room_id
        and r.creator_id = auth.uid()
    )
  );

create policy "room_members_delete"
  on public.room_members for delete
  to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1
      from public.recording_rooms r
      where r.id = room_id
        and r.creator_id = auth.uid()
    )
  );

drop policy if exists "recording_sessions_select" on public.recording_sessions;
drop policy if exists "recording_sessions_insert" on public.recording_sessions;
drop policy if exists "recording_sessions_update" on public.recording_sessions;

create policy "recording_sessions_select"
  on public.recording_sessions for select
  to authenticated
  using (public.is_room_member(room_id, auth.uid()));

create policy "recording_sessions_insert"
  on public.recording_sessions for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and public.is_room_member(room_id, auth.uid())
  );

create policy "recording_sessions_update"
  on public.recording_sessions for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ─── location_history ──────────────────────────────────────

drop policy if exists "location_history_select" on public.location_history;
drop policy if exists "location_history_insert" on public.location_history;

-- 친구 관계인 사용자끼리만 경로 기록 조회 가능
create policy "location_history_select"
  on public.location_history for select
  to authenticated
  using (
    user_id = auth.uid()
    or (
      room_id is not null
      and public.is_room_member(room_id, auth.uid())
    )
    or (
      room_id is null
      and
      exists (
        select 1 from public.profiles p
        where p.id = location_history.user_id
          and p.is_sharing_location = true
      )
      and exists (
        select 1 from public.friendships f
        where f.status = 'accepted'
          and (
            (f.requester_id = auth.uid() and f.addressee_id = user_id)
            or
            (f.addressee_id = auth.uid() and f.requester_id = user_id)
          )
        )
    )
  );

-- 본인 경로만 기록 가능
create policy "location_history_insert"
  on public.location_history for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and (
      room_id is null
      or public.is_room_member(room_id, auth.uid())
    )
  );

-- ─── friendships ───────────────────────────────────────────

drop policy if exists "friendships_select" on public.friendships;
drop policy if exists "friendships_insert" on public.friendships;
drop policy if exists "friendships_update" on public.friendships;
drop policy if exists "friendships_delete" on public.friendships;

-- 본인이 포함된 친구 관계만 조회 가능
create policy "friendships_select"
  on public.friendships for select
  to authenticated
  using (
    requester_id = auth.uid()
    or addressee_id = auth.uid()
  );

-- 친구 요청 보내기 (requester = 본인)
create policy "friendships_insert"
  on public.friendships for insert
  to authenticated
  with check (requester_id = auth.uid() and status = 'pending');

-- 수락/거절: 요청 받은 사람만 변경 가능
-- 요청자가 취소할 때는 delete 정책으로 삭제한다.
create policy "friendships_update"
  on public.friendships for update
  to authenticated
  using (
    addressee_id = auth.uid()
  )
  with check (
    addressee_id = auth.uid()
  );

-- 친구 삭제: 본인이 포함된 관계만
create policy "friendships_delete"
  on public.friendships for delete
  to authenticated
  using (
    requester_id = auth.uid()
    or addressee_id = auth.uid()
  );

-- ─── friend_greetings ─────────────────────────────────────

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
  with check (
    sender_id = auth.uid()
    and exists (
      select 1
      from public.friendships f
      where f.status = 'accepted'
        and (
          (f.requester_id = auth.uid() and f.addressee_id = recipient_id)
          or
          (f.addressee_id = auth.uid() and f.requester_id = recipient_id)
        )
    )
  );

-- ─── Avatar storage ───────────────────────────────────────

drop policy if exists "avatars_public_select" on storage.objects;
drop policy if exists "avatars_owner_insert" on storage.objects;
drop policy if exists "avatars_owner_update" on storage.objects;
drop policy if exists "avatars_owner_delete" on storage.objects;

create policy "avatars_public_select"
  on storage.objects for select
  to public
  using (bucket_id = 'avatars');

create policy "avatars_owner_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars_owner_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars_owner_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
