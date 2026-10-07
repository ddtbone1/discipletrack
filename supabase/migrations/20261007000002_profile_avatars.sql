-- Migration 021: profile avatars (user decision 2026-10-07).
--
-- A member picks one of the app's bundled avatars (CC0 illustrations,
-- assets/avatars/). profiles.avatar_url holds its key, "preset:1" to
-- "preset:12". Photo uploads are not part of this: they would need file
-- storage and a decision of their own, so the column accepts preset keys
-- only, never an arbitrary URL.
--
-- Avatars show wherever a member's initials show (rosters, Home, Disciple
-- rows), so fellow ACTIVE members of the same church may read the key. A
-- key is a choice of picture, nothing more: no name, contact or progress
-- travels with it.

update public.profiles
set avatar_url = null
where avatar_url is not null and avatar_url !~ '^preset:([1-9]|1[0-2])$';

alter table public.profiles
  add constraint profiles_avatar_preset_check
  check (avatar_url is null or avatar_url ~ '^preset:([1-9]|1[0-2])$');

comment on column public.profiles.avatar_url is
  'The member''s avatar: a bundled preset key, "preset:1" to "preset:12", or null for initials. Migration 021.';

-- The avatars of the caller's church: one row per ACTIVE membership with
-- an avatar chosen. Only an ACTIVE member of that church may ask.
create function public.get_church_avatars()
returns table (
  church_membership_id uuid,
  avatar               text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_church uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select m.church_id into v_church
  from public.church_memberships m
  where m.user_id = (select auth.uid())
    and m.status = 'ACTIVE';

  if v_church is null then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  return query
    select m.id, p.avatar_url
    from public.church_memberships m
    join public.profiles p on p.id = m.user_id
    where m.church_id = v_church
      and m.status = 'ACTIVE'
      and p.avatar_url is not null;
end;
$$;

revoke execute on function public.get_church_avatars() from public, anon;
grant execute on function public.get_church_avatars() to authenticated;

comment on function public.get_church_avatars() is
  'Avatar keys of the caller''s church''s ACTIVE members, for showing in place of initials. Migration 021.';
