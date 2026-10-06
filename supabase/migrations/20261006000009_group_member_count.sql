-- ============================================================
-- DiscipleTrack - Migration 016: D Group member count (Slice 6)
-- ============================================================
--
-- Group membership and responsibility are separate (ADR-018): once a
-- person has been added to a group they count as a member, even before
-- their responsibility is set up. The roster deliberately leaves out
-- people who still need setup (they are not shown by name to group
-- mates), so a count taken from roster rows undercounts.
--
-- get_my_d_group_roster() gains d_group_member_count: the number of
-- active placements in the caller's group, the same on every row. A
-- count reveals no names. Disciple and Discipler counts stay
-- responsibility-specific and are not affected.
--
-- The return type changes, so the function is dropped and recreated;
-- the body is Migration 012's with the one added column.
--
-- Migrations 001 to 015 are not modified.
-- ============================================================

drop function public.get_my_d_group_roster();

create function public.get_my_d_group_roster()
returns table (
  d_group_id            uuid,
  d_group_name          text,
  d_group_membership_id uuid,
  church_membership_id  uuid,
  full_name             text,
  responsibility        public.d_group_responsibility,
  phone                 text,
  is_me                 boolean,
  is_my_leader          boolean,
  is_my_discipler       boolean,
  is_my_disciple        boolean,
  d_group_member_count  integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := (select auth.uid());
  v_me    uuid;
  v_group uuid;
  v_set_up boolean;
  v_count  integer;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select pl.church_membership_id, pl.d_group_id into v_me, v_group
  from public.d_group_placements pl
  join public.church_memberships m on m.id = pl.church_membership_id
  where m.user_id = v_uid
    and m.status = 'ACTIVE'
    and pl.ended_at is null
  limit 1;

  if v_group is null then
    return;
  end if;

  v_count := (
    select count(*)::integer
    from public.d_group_placements pl
    where pl.d_group_id = v_group
      and pl.ended_at is null
  );

  v_set_up := exists (
    select 1
    from public.d_group_memberships dgm
    where dgm.church_membership_id = v_me
      and dgm.d_group_id = v_group
      and dgm.ended_at is null
  );

  return query
    with mine as (
      select dgm.id, dgm.responsibility
      from public.d_group_memberships dgm
      where dgm.church_membership_id = v_me
        and dgm.d_group_id = v_group
        and dgm.ended_at is null
    ),
    my_discipler as (
      select dr.church_membership_id
      from public.discipler_assignments a
      join public.d_group_memberships dr on dr.id = a.discipler_d_group_membership_id
      where a.ended_at is null
        and a.disciple_d_group_membership_id in (select mine.id from mine)
    ),
    my_disciples as (
      select dd.church_membership_id
      from public.discipler_assignments a
      join public.d_group_memberships dd on dd.id = a.disciple_d_group_membership_id
      where a.ended_at is null
        and dd.ended_at is null
        and a.discipler_d_group_membership_id in (select mine.id from mine)
    )
    select
      g.id,
      g.name,
      dgm.id,
      dgm.church_membership_id,
      p.full_name,
      dgm.responsibility,
      case
        when dgm.church_membership_id = v_me then p.phone
        when (dgm.responsibility = 'LEADER'
              and exists (select 1 from mine where mine.responsibility <> 'LEADER'))
          or dgm.church_membership_id in (select md.church_membership_id from my_discipler md)
          or dgm.church_membership_id in (select mds.church_membership_id from my_disciples mds)
          then p.phone
        else null
      end,
      dgm.church_membership_id = v_me,
      dgm.responsibility = 'LEADER' and dgm.church_membership_id <> v_me,
      dgm.church_membership_id in (select md.church_membership_id from my_discipler md),
      dgm.church_membership_id in (select mds.church_membership_id from my_disciples mds),
      v_count
    from public.d_group_memberships dgm
    join public.d_groups g on g.id = dgm.d_group_id
    join public.church_memberships m on m.id = dgm.church_membership_id
    join public.profiles p on p.id = m.user_id
    where dgm.d_group_id = v_group
      and dgm.ended_at is null
      and (v_set_up or dgm.responsibility = 'LEADER')
    order by
      case dgm.responsibility
        when 'LEADER' then 0
        when 'DISCIPLER' then 1
        else 2
      end,
      lower(p.full_name);
end;
$$;

comment on function public.get_my_d_group_roster() is
  'The caller''s D Group roster by name, with phone numbers only for their own Leader, own Discipler and, for a Discipler, their assigned Disciples. A caller who still needs setup gets only their Leader''s row, without a phone number. d_group_member_count counts everyone placed in the group, including people who still need setup.';

revoke execute on function public.get_my_d_group_roster() from public, anon;
grant execute on function public.get_my_d_group_roster() to authenticated, service_role;
