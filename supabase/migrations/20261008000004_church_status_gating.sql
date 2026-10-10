-- ============================================================
-- DiscipleTrack - Migration 025: church status gating
-- ============================================================
--
-- Slice 8 (ADR-022 decisions 14 and 15). The effective-membership
-- predicate (RBAC section 1a) becomes "an ACTIVE membership in an
-- ACTIVE church". A role, a D Group responsibility or an assignment
-- grants nothing while the church is SUSPENDED or ARCHIVED.
--
-- How it is applied:
--   1. private.church_is_active().
--   2. Every helper that identifies the caller through their own
--      membership (user_id = auth.uid() and status = 'ACTIVE') also
--      requires the church to be ACTIVE. Every RLS policy and every
--      controlled operation decides authority through these helpers
--      (or through helpers built on them), so this one change covers
--      them all: reads return nothing and writes refuse.
--   3. The five client operations that identify the caller inline,
--      rather than through a helper, are redefined with the same
--      condition: get_church_avatars(), get_lesson_covers(),
--      get_my_d_group_roster(), list_disciple_progress(),
--      complete_onboarding().
--
-- Deliberately unchanged, so the app can explain the state:
--   church_memberships_select_own (the person's own row),
--   churches_select_own_church (id, name, status),
--   profiles_select_own / profiles_update_own (profiles are
--   platform-level), church_role_assignments_select_own (grants
--   nothing).
--
-- Refusals keep each operation's existing code (PT403 not_authorized,
-- or not found where an operation hides what it cannot show). No data
-- is changed by a status change; reactivation restores every read.
--
-- Generated from the latest definitions of the functions in step 3,
-- with one asserted change each.
--
-- References:
--   ADR-022, RBAC_RLS_MATRIX.md section 1a,
--   DATABASE_CONSTRAINTS.md section 1 (Church Status)
-- ============================================================


-- ============================================================
-- 1. THE CHURCH CONDITION
-- ============================================================

create function private.church_is_active(p_church_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.churches c
    where c.id = p_church_id and c.status = 'ACTIVE'
  );
$$;

comment on function private.church_is_active(uuid) is
  'True when the church''s status is ACTIVE. Part of the effective-membership predicate (RBAC section 1a, ADR-022).';

revoke execute on function private.church_is_active(uuid) from public, anon;
grant execute on function private.church_is_active(uuid) to authenticated, service_role;


-- ============================================================
-- 2. CALLER HELPERS REQUIRE AN ACTIVE CHURCH
-- ============================================================
--
-- Each is its latest definition with the caller's membership joined to
-- an ACTIVE church.

-- Migration 006.
create or replace function private.is_church_coordinator(p_church_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.church_memberships m
    join public.churches c on c.id = m.church_id and c.status = 'ACTIVE'
    join public.church_role_assignments r on r.church_membership_id = m.id
    where m.church_id = p_church_id
      and m.user_id = (select auth.uid())
      and m.status = 'ACTIVE'
      and r.ended_at is null
      and r.role = 'COORDINATOR'
  );
$$;

-- Migration 007.
create or replace function private.is_active_member_of(p_church_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.church_memberships m
    join public.churches c on c.id = m.church_id and c.status = 'ACTIVE'
    where m.church_id = p_church_id
      and m.user_id = (select auth.uid())
      and m.status = 'ACTIVE'
  );
$$;

-- Migration 006.
create or replace function private.is_my_membership(p_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.church_memberships m
    join public.churches c on c.id = m.church_id and c.status = 'ACTIVE'
    where m.id = p_membership_id
      and m.user_id = (select auth.uid())
      and m.status = 'ACTIVE'
  );
$$;

-- Migration 006.
create or replace function private.owns_d_group_membership(p_d_group_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.d_group_memberships dgm
    join public.church_memberships m on m.id = dgm.church_membership_id
    join public.churches c on c.id = m.church_id and c.status = 'ACTIVE'
    where dgm.id = p_d_group_membership_id
      and m.user_id = (select auth.uid())
      and m.status = 'ACTIVE'
  );
$$;

-- Migration 006.
create or replace function private.has_active_responsibility_in(
  p_d_group_id     uuid,
  p_responsibility public.d_group_responsibility default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.d_group_memberships dgm
    join public.church_memberships m on m.id = dgm.church_membership_id
    join public.churches c on c.id = m.church_id and c.status = 'ACTIVE'
    where dgm.d_group_id = p_d_group_id
      and dgm.ended_at is null
      and (p_responsibility is null or dgm.responsibility = p_responsibility)
      and m.user_id = (select auth.uid())
      and m.status = 'ACTIVE'
  );
$$;

-- Migration 006.
create or replace function private.is_assigned_discipler_of(p_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.discipler_assignments a
    join public.d_group_memberships dr on dr.id = a.discipler_d_group_membership_id
    join public.d_group_memberships dd on dd.id = a.disciple_d_group_membership_id
    join public.church_memberships me on me.id = dr.church_membership_id
    join public.churches c on c.id = me.church_id and c.status = 'ACTIVE'
    where a.ended_at is null
      and dr.ended_at is null
      and dd.ended_at is null
      and dd.church_membership_id = p_membership_id
      and me.user_id = (select auth.uid())
      and me.status = 'ACTIVE'
  );
$$;

-- Migration 012.
create or replace function private.leads_group_of_membership(p_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.d_group_memberships l
    join public.church_memberships me on me.id = l.church_membership_id
    join public.churches c on c.id = me.church_id and c.status = 'ACTIVE'
    join public.d_group_placements t on t.d_group_id = l.d_group_id
    where l.responsibility = 'LEADER'
      and l.ended_at is null
      and me.user_id = (select auth.uid())
      and me.status = 'ACTIVE'
      and t.church_membership_id = p_membership_id
      and t.ended_at is null
  );
$$;

-- Migration 012.
create or replace function private.is_placed_in(p_d_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.d_group_placements p
    join public.church_memberships m on m.id = p.church_membership_id
    join public.churches c on c.id = m.church_id and c.status = 'ACTIVE'
    where p.d_group_id = p_d_group_id
      and p.ended_at is null
      and m.user_id = (select auth.uid())
      and m.status = 'ACTIVE'
  );
$$;

-- Migration 006.
create or replace function private.is_my_leader_or_discipler(p_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
           select 1
           from public.d_group_memberships l
           join public.d_group_memberships mine on mine.d_group_id = l.d_group_id
           join public.church_memberships me on me.id = mine.church_membership_id
           join public.churches c on c.id = me.church_id and c.status = 'ACTIVE'
           where l.church_membership_id = p_membership_id
             and l.responsibility = 'LEADER'
             and l.ended_at is null
             and mine.ended_at is null
             and mine.responsibility in ('DISCIPLER', 'DISCIPLE')
             and me.user_id = (select auth.uid())
             and me.status = 'ACTIVE'
         )
      or exists (
           select 1
           from public.discipler_assignments a
           join public.d_group_memberships dr on dr.id = a.discipler_d_group_membership_id
           join public.d_group_memberships dd on dd.id = a.disciple_d_group_membership_id
           join public.church_memberships me on me.id = dd.church_membership_id
           join public.churches c on c.id = me.church_id and c.status = 'ACTIVE'
           where a.ended_at is null
             and dr.ended_at is null
             and dd.ended_at is null
             and dr.church_membership_id = p_membership_id
             and me.user_id = (select auth.uid())
             and me.status = 'ACTIVE'
         );
$$;


-- ============================================================
-- 3. OPERATIONS THAT IDENTIFY THE CALLER INLINE
-- ============================================================


-- As Migration 021, with the church ACTIVE.
create or replace function public.get_church_avatars()
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
    and m.status = 'ACTIVE'
    and private.church_is_active(m.church_id);

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


-- As Migration 019, with the church ACTIVE.
create or replace function public.get_lesson_covers()
returns table (lesson_id uuid, image text, mime_type text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  return query
    select lc.lesson_id, lc.image, lc.mime_type
    from public.lesson_covers lc
    join public.curriculum_lessons l on l.id = lc.lesson_id
    join public.curricula c on c.id = l.curriculum_id and c.status = 'ACTIVE'
    join public.church_memberships m
      on m.church_id = c.church_id
     and m.user_id = (select auth.uid())
     and m.status = 'ACTIVE'
    where private.church_is_active(c.church_id);
end;
$$;


-- As Migration 016, with the church ACTIVE.
create or replace function public.get_my_d_group_roster()
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
    and private.church_is_active(m.church_id)
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


-- As Migration 007, with the church ACTIVE.
create or replace function public.list_disciple_progress()
returns table (
  church_membership_id     uuid,
  full_name                text,
  discipler_name           text,
  current_lesson_number    integer,
  current_lesson_title     text,
  current_status           public.lesson_progress_status,
  credited_count           integer,
  lessons_total            integer,
  lessons_completed        integer,
  submitted_by_name        text,
  last_recorded_meeting_at timestamptz,
  recorded_absences        integer,
  is_assigned_to_me        boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  return query
  select m.id,
         pr.full_name,
         dpr.full_name,
         cl.lesson_number,
         cl.title,
         coalesce(cp.status, 'NOT_STARTED'::public.lesson_progress_status),
         case when cl.id is null then 0
              else private.credited_count(m.id, cl.id) end,
         (select count(*)::integer
          from public.curricula c
          join public.curriculum_lessons l on l.curriculum_id = c.id
          where c.church_id = m.church_id and c.status = 'ACTIVE'),
         (select count(*)::integer
          from public.curricula c
          join public.curriculum_lessons l on l.curriculum_id = c.id
          join public.disciple_lesson_progress p
            on p.lesson_id = l.id and p.church_membership_id = m.id
          where c.church_id = m.church_id and c.status = 'ACTIVE'
            and p.status = 'COMPLETED'),
         sp.full_name,
         (select max(dm.occurred_at)
          from public.discipleship_meeting_participants p
          join public.discipleship_meetings dm on dm.id = p.meeting_id
          where p.church_membership_id = m.id
            and p.status = 'RECORDED' and dm.status = 'RECORDED'),
         (select count(*)::integer
          from public.discipleship_meeting_participants p
          join public.discipleship_meetings dm on dm.id = p.meeting_id
          where p.church_membership_id = m.id
            and p.status = 'RECORDED' and dm.status = 'RECORDED'
            and p.attendance_status = 'ABSENT'),
         true
  from public.d_group_memberships dr
  join public.church_memberships me on me.id = dr.church_membership_id
  join public.discipler_assignments a
    on a.discipler_d_group_membership_id = dr.id and a.ended_at is null
  join public.d_group_memberships dd
    on dd.id = a.disciple_d_group_membership_id and dd.ended_at is null
  join public.church_memberships m on m.id = dd.church_membership_id
  join public.profiles pr on pr.id = m.user_id
  join public.profiles dpr on dpr.id = me.user_id
  left join public.curriculum_lessons cl on cl.id = private.eligible_lesson(m.id)
  left join public.disciple_lesson_progress cp
    on cp.church_membership_id = m.id and cp.lesson_id = cl.id
  left join public.profiles sp on sp.id = cp.submitted_by
  where dr.responsibility = 'DISCIPLER'
    and dr.ended_at is null
    and me.user_id = auth.uid()
    and me.status = 'ACTIVE'
    and private.church_is_active(me.church_id)
  order by pr.full_name;
end;
$$;


-- As Migration 005, with the church ACTIVE.
create or replace function public.complete_onboarding()
returns table (membership_id uuid, onboarding_completed_at timestamptz)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_id  uuid;
  v_at  timestamptz;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  update public.church_memberships m
  set onboarding_completed_at = coalesce(m.onboarding_completed_at, now())
  where m.user_id = v_uid
    and m.status = 'ACTIVE'
    and private.church_is_active(m.church_id)
  returning m.id, m.onboarding_completed_at into v_id, v_at;

  if v_id is null then
    raise exception 'no_active_membership' using errcode = 'PT409';
  end if;

  return query select v_id, v_at;
end;
$$;
