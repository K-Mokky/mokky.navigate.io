-- Backfill production RPCs that older Supabase projects may be missing.
-- Safe to re-run: all functions are created with CREATE OR REPLACE and grants
-- are reset to authenticated callers only where the Flutter app expects RPCs.

create or replace function public.search_profiles(p_query text)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  is_sharing_location boolean,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_query text := left(regexp_replace(trim(coalesce(p_query, '')), '\s+', ' ', 'g'), 32);
  escaped_query text;
begin
  if auth.uid() is null or length(normalized_query) < 2 then
    return;
  end if;

  escaped_query := replace(
    replace(
      replace(normalized_query, '\', '\\'),
      '%',
      '\%'
    ),
    '_',
    '\_'
  );

  return query
  select
    p.id,
    p.username,
    p.display_name,
    p.avatar_url,
    p.is_sharing_location,
    p.created_at
  from public.profiles p
  where p.id <> auth.uid()
    and p.username ilike '%' || escaped_query || '%' escape '\'
  order by p.username
  limit 20;
end;
$$;

create or replace function public.get_room_members_public(p_room_id uuid)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  is_sharing_location boolean,
  created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    p.id,
    p.username,
    p.display_name,
    p.avatar_url,
    p.is_sharing_location,
    p.created_at
  from public.room_members m
  join public.profiles p on p.id = m.user_id
  where m.room_id = p_room_id
    and public.is_room_member(p_room_id, auth.uid())
  order by m.joined_at;
$$;

create or replace function public.join_room_by_code(p_invite_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target_room_id uuid;
  normalized_code text := upper(trim(coalesce(p_invite_code, '')));
begin
  if auth.uid() is null then
    raise exception 'login required';
  end if;

  if normalized_code !~ '^[A-Z0-9]{6,32}$' then
    raise exception 'invalid invite code';
  end if;

  select id
  into target_room_id
  from public.recording_rooms
  where invite_code = normalized_code
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

revoke execute on function public.search_profiles(text)
  from public, anon;
revoke execute on function public.get_room_members_public(uuid)
  from public, anon;
revoke execute on function public.join_room_by_code(text)
  from public, anon;

grant execute on function public.search_profiles(text)
  to authenticated;
grant execute on function public.get_room_members_public(uuid)
  to authenticated;
grant execute on function public.join_room_by_code(text)
  to authenticated;
