-- ============================================================
-- DiscipleTrack - Migration 013: Responsibility setup and pairing
-- (Slice 6.2)
-- ============================================================
--
-- A member placed in a D Group (Migration 012) is set up by the
-- Coordinator or the group's Leader as a Disciple, or, during the
-- church's initial setup window, recognized as an Existing Discipler.
--
-- Three ways to hold DISCIPLER stay distinguishable on the row itself
-- (d_group_memberships.discipler_basis):
--   INITIAL_ROLLOUT  recognized at setup while the window was open; the
--                    person already disciples in the church
--   LEADER_SELF      the group's Leader added themselves
--   APPOINTMENT      a Disciple appointed by the Coordinator after
--                    Lesson 5 (Migration 014, with a
--                    ministry_role_transitions row)
-- ministry_role_transitions stays the appointment record only, so the
-- Slice 5 reopen protection (an appointment row to DISCIPLER) keeps its
-- documented meaning and is not edited.
--
-- ADR-012 relaxation (decision 5): DISCIPLE may coexist with DISCIPLER;
-- DISCIPLE still excludes LEADER. Its replacement protections:
-- no self-pairing across church memberships (decision 6) and no
-- reciprocal pairing (D7).
--
-- Scope:
--   Schema
--     - discipler_basis enum and column, backfilled for existing rows
--     - church_settings.initial_setup_closed_at (open while null)
--   Integrity triggers (replaced bodies, same names)
--     - membership: DISCIPLE conflicts with LEADER only
--     - assignment: different church memberships on the two sides, no
--       reciprocal pair
--   Controlled operations
--     - set_up_member(), set_initial_setup_open(),
--       get_initial_setup_status()
--     - add_self_as_discipler() and set_discipler() replaced
--
-- New error reasons:
--   PT400 invalid_responsibility
--   PT409 already_disciple / leader_cannot_be_disciple /
--         initial_setup_closed / initial_setup_already_open /
--         initial_setup_already_closed / cannot_pair_with_self /
--         reciprocal_pairing
--
-- Migrations 001 to 012 are not modified.
-- ============================================================


-- ============================================================
-- 1. SCHEMA
-- ============================================================

create type public.discipler_basis as enum (
  'INITIAL_ROLLOUT', 'LEADER_SELF', 'APPOINTMENT'
);

alter table public.d_group_memberships
  add column discipler_basis public.discipler_basis;

comment on column public.d_group_memberships.discipler_basis is
  'Why a DISCIPLER row exists: INITIAL_ROLLOUT (recognized during the initial setup window), LEADER_SELF (the Leader added themselves) or APPOINTMENT (appointed after Lesson 5; see ministry_role_transitions). Null for LEADER and DISCIPLE rows.';

-- Existing DISCIPLER rows predate Slice 6. A row whose holder also led
-- the group when it started was the Leader adding themselves; every
-- other one was a placement of someone who already disciples, which is
-- what initial rollout recognition means.
update public.d_group_memberships d
set discipler_basis = case
  when exists (
    select 1
    from public.d_group_memberships l
    where l.church_membership_id = d.church_membership_id
      and l.d_group_id = d.d_group_id
      and l.responsibility = 'LEADER'
      and tstzrange(l.started_at, l.ended_at, '[)') @> d.started_at
  ) then 'LEADER_SELF'::public.discipler_basis
  else 'INITIAL_ROLLOUT'::public.discipler_basis
end
where d.responsibility = 'DISCIPLER';

alter table public.d_group_memberships
  add constraint d_group_memberships_discipler_basis_check
  check ((responsibility = 'DISCIPLER') = (discipler_basis is not null));


alter table public.church_settings
  add column initial_setup_closed_at timestamptz;

comment on column public.church_settings.initial_setup_closed_at is
  'Null while the church''s initial setup window is open, when an Existing Discipler may be recognized at setup. Set by the Coordinator to close it (set_initial_setup_open); after that DISCIPLER comes only from appointment.';


-- ============================================================
-- 2. INTEGRITY TRIGGERS
-- ============================================================

-- As Migration 006, with the DISCIPLE / DISCIPLER exclusion removed
-- (ADR-012 decision 5). DISCIPLE still excludes LEADER (BR-015).
create or replace function private.check_d_group_membership_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_group_church  uuid;
  v_member_church uuid;
  v_period        tstzrange := tstzrange(new.started_at, new.ended_at, '[)');
begin
  select g.church_id into v_group_church
  from public.d_groups g
  where g.id = new.d_group_id;

  select m.church_id into v_member_church
  from public.church_memberships m
  where m.id = new.church_membership_id;

  if v_group_church is distinct from v_member_church then
    raise exception 'd_group_membership_cross_church'
      using errcode = '23514',
            detail = 'The D Group and the church membership belong to different churches.';
  end if;

  if exists (
    select 1
    from public.d_group_memberships o
    where o.id <> new.id
      and o.church_membership_id = new.church_membership_id
      and o.d_group_id = new.d_group_id
      and o.responsibility = new.responsibility
      and tstzrange(o.started_at, o.ended_at, '[)') && v_period
  ) then
    raise exception 'd_group_membership_overlap'
      using errcode = '23514',
            detail = 'Overlapping periods for the same person, D Group and responsibility.';
  end if;

  if exists (
    select 1
    from public.d_group_memberships o
    where o.id <> new.id
      and o.church_membership_id = new.church_membership_id
      and o.d_group_id <> new.d_group_id
      and tstzrange(o.started_at, o.ended_at, '[)') && v_period
  ) then
    raise exception 'd_group_membership_spans_groups'
      using errcode = '23514',
            detail = 'A person''s responsibilities must all be in one D Group at a time.';
  end if;

  if exists (
    select 1
    from public.d_group_memberships o
    where o.id <> new.id
      and o.church_membership_id = new.church_membership_id
      and tstzrange(o.started_at, o.ended_at, '[)') && v_period
      and (
        (o.responsibility = 'DISCIPLE' and new.responsibility = 'LEADER')
        or (o.responsibility = 'LEADER' and new.responsibility = 'DISCIPLE')
      )
  ) then
    raise exception 'd_group_membership_disciple_conflict'
      using errcode = '23514',
            detail = 'DISCIPLE cannot overlap LEADER for the same person.';
  end if;

  return null;
end;
$$;


-- As Migration 006, plus: the two sides belong to different people
-- (ADR-012 decision 6), and no reciprocal pair overlaps (D7).
create or replace function private.check_discipler_assignment_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_discipler public.d_group_memberships%rowtype;
  v_disciple  public.d_group_memberships%rowtype;
begin
  select * into v_discipler
  from public.d_group_memberships d
  where d.id = new.discipler_d_group_membership_id;

  select * into v_disciple
  from public.d_group_memberships d
  where d.id = new.disciple_d_group_membership_id;

  if v_discipler.responsibility is distinct from 'DISCIPLER' then
    raise exception 'assignment_discipler_side_invalid'
      using errcode = '23514',
            detail = 'discipler_d_group_membership_id must reference a DISCIPLER responsibility.';
  end if;

  if v_disciple.responsibility is distinct from 'DISCIPLE' then
    raise exception 'assignment_disciple_side_invalid'
      using errcode = '23514',
            detail = 'disciple_d_group_membership_id must reference a DISCIPLE responsibility.';
  end if;

  if v_discipler.d_group_id <> new.d_group_id
     or v_disciple.d_group_id <> new.d_group_id then
    raise exception 'assignment_cross_group'
      using errcode = '23514',
            detail = 'Both sides of a discipler assignment must be in the assignment''s D Group.';
  end if;

  if v_discipler.church_membership_id = v_disciple.church_membership_id then
    raise exception 'assignment_self_pairing'
      using errcode = '23514',
            detail = 'A person cannot be their own Discipler.';
  end if;

  if exists (
    select 1
    from public.discipler_assignments o
    where o.id <> new.id
      and o.disciple_d_group_membership_id = new.disciple_d_group_membership_id
      and tstzrange(o.started_at, o.ended_at, '[)')
          && tstzrange(new.started_at, new.ended_at, '[)')
  ) then
    raise exception 'assignment_overlap'
      using errcode = '23514',
            detail = 'A Disciple''s discipler assignments cannot overlap.';
  end if;

  if exists (
    select 1
    from public.discipler_assignments o
    join public.d_group_memberships od on od.id = o.disciple_d_group_membership_id
    join public.d_group_memberships orr on orr.id = o.discipler_d_group_membership_id
    where o.id <> new.id
      and od.church_membership_id = v_discipler.church_membership_id
      and orr.church_membership_id = v_disciple.church_membership_id
      and tstzrange(o.started_at, o.ended_at, '[)')
          && tstzrange(new.started_at, new.ended_at, '[)')
  ) then
    raise exception 'assignment_reciprocal'
      using errcode = '23514',
            detail = 'Two people cannot disciple each other at the same time.';
  end if;

  return null;
end;
$$;


-- ============================================================
-- 3. HELPERS
-- ============================================================

create function private.initial_setup_open(p_church_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select s.initial_setup_closed_at is null
    from public.church_settings s
    where s.church_id = p_church_id
  ), false);
$$;

revoke execute on function private.initial_setup_open(uuid) from public, anon;
grant execute on function private.initial_setup_open(uuid) to authenticated, service_role;


-- ============================================================
-- 4. CONTROLLED OPERATIONS
-- ============================================================

-- Sets up a placed member, or adds a second responsibility:
--   DISCIPLE   always, unless they lead the group (BR-015)
--   DISCIPLER  Existing Discipler recognition, only while the church's
--              initial setup window is open (Slice 6 decision 2);
--              recorded as INITIAL_ROLLOUT
create function public.set_up_member(
  p_d_group_placement_id uuid,
  p_responsibility       public.d_group_responsibility
)
returns table (d_group_membership_id uuid)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := (select auth.uid());
  v_pl     public.d_group_placements%rowtype;
  v_group  public.d_groups%rowtype;
  v_status public.membership_status;
  v_basis  public.discipler_basis;
  v_dgm    uuid;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select * into v_pl
  from public.d_group_placements p
  where p.id = p_d_group_placement_id;

  if not found or not private.can_manage_d_group_members(v_pl.d_group_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  if p_responsibility is null or p_responsibility not in ('DISCIPLE', 'DISCIPLER') then
    raise exception 'invalid_responsibility' using errcode = 'PT400';
  end if;

  select m.status into v_status
  from public.church_memberships m
  where m.id = v_pl.church_membership_id
  for update;

  select * into v_pl
  from public.d_group_placements p
  where p.id = p_d_group_placement_id
  for update;

  if v_pl.ended_at is not null then
    raise exception 'd_group_placement_not_active' using errcode = 'PT409';
  end if;

  select * into v_group
  from public.d_groups g
  where g.id = v_pl.d_group_id;

  if v_group.status <> 'ACTIVE' then
    raise exception 'd_group_not_active' using errcode = 'PT409';
  end if;

  if v_status <> 'ACTIVE' then
    raise exception 'member_not_active' using errcode = 'PT409';
  end if;

  if exists (
    select 1
    from public.d_group_memberships dgm
    where dgm.church_membership_id = v_pl.church_membership_id
      and dgm.d_group_id = v_pl.d_group_id
      and dgm.responsibility = p_responsibility
      and dgm.ended_at is null
  ) then
    if p_responsibility = 'DISCIPLE' then
      raise exception 'already_disciple' using errcode = 'PT409';
    end if;
    raise exception 'already_discipler' using errcode = 'PT409';
  end if;

  if p_responsibility = 'DISCIPLE' then
    if exists (
      select 1
      from public.d_group_memberships dgm
      where dgm.church_membership_id = v_pl.church_membership_id
        and dgm.responsibility = 'LEADER'
        and dgm.ended_at is null
    ) then
      raise exception 'leader_cannot_be_disciple' using errcode = 'PT409';
    end if;
  else
    if not private.initial_setup_open(v_group.church_id) then
      raise exception 'initial_setup_closed' using errcode = 'PT409';
    end if;
    v_basis := 'INITIAL_ROLLOUT';
  end if;

  insert into public.d_group_memberships
    (d_group_id, church_membership_id, responsibility, started_at,
     assigned_by, discipler_basis)
  values
    (v_pl.d_group_id, v_pl.church_membership_id, p_responsibility, now(),
     v_uid, v_basis)
  returning id into v_dgm;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_group.church_id,
    v_uid,
    'D_GROUP_MEMBER_SET_UP',
    'd_group_memberships',
    v_dgm,
    jsonb_build_object(
      'd_group_id', v_pl.d_group_id,
      'd_group_placement_id', v_pl.id,
      'church_membership_id', v_pl.church_membership_id,
      'responsibility', p_responsibility,
      'discipler_basis', v_basis
    )
  );

  return query select v_dgm;
end;
$$;

comment on function public.set_up_member(uuid, public.d_group_responsibility) is
  'Coordinator or the group''s Leader. Gives a placed member a DISCIPLE responsibility, or (while the church''s initial setup window is open) recognizes them as an Existing Discipler with discipler_basis INITIAL_ROLLOUT. Audited as D_GROUP_MEMBER_SET_UP.';


-- Coordinator only. Closes or reopens the initial setup window.
create function public.set_initial_setup_open(
  p_church_id uuid,
  p_open      boolean
)
returns table (initial_setup_open boolean, closed_at timestamptz)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := (select auth.uid());
  v_closed timestamptz;
  v_new    timestamptz;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  if p_church_id is null or not private.is_church_coordinator(p_church_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  if p_open is null then
    raise exception 'invalid_request' using errcode = 'PT400';
  end if;

  select s.initial_setup_closed_at into v_closed
  from public.church_settings s
  where s.church_id = p_church_id
  for update;

  if p_open and v_closed is null then
    raise exception 'initial_setup_already_open' using errcode = 'PT409';
  end if;

  if not p_open and v_closed is not null then
    raise exception 'initial_setup_already_closed' using errcode = 'PT409';
  end if;

  v_new := case when p_open then null else now() end;

  update public.church_settings s
  set initial_setup_closed_at = v_new
  where s.church_id = p_church_id;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    p_church_id,
    v_uid,
    case when p_open then 'INITIAL_SETUP_REOPENED' else 'INITIAL_SETUP_CLOSED' end,
    'church_settings',
    p_church_id,
    jsonb_build_object('previous_closed_at', v_closed)
  );

  return query select p_open, v_new;
end;
$$;

comment on function public.set_initial_setup_open(uuid, boolean) is
  'Coordinator only. Closes (p_open false) or reopens the church''s initial setup window, during which an Existing Discipler may be recognized at setup. Audited as INITIAL_SETUP_CLOSED / INITIAL_SETUP_REOPENED.';


-- Read-only, for any ACTIVE member of the church: whether Existing
-- Discipler recognition is available.
create function public.get_initial_setup_status(p_church_id uuid)
returns table (initial_setup_open boolean, closed_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  if not private.is_active_member_of(p_church_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  return query
    select s.initial_setup_closed_at is null, s.initial_setup_closed_at
    from public.church_settings s
    where s.church_id = p_church_id;
end;
$$;


-- As Migration 006, recording discipler_basis LEADER_SELF. Not bounded
-- by the setup window: a Leader can never be a Disciple, so the Lesson 5
-- path does not exist for them (Plan decision 2).
create or replace function public.add_self_as_discipler(p_d_group_id uuid)
returns table (d_group_membership_id uuid)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := (select auth.uid());
  v_group  public.d_groups%rowtype;
  v_leader public.d_group_memberships%rowtype;
  v_dgm    uuid;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select * into v_group
  from public.d_groups g
  where g.id = p_d_group_id
  for share;

  if not found then
    raise exception 'd_group_not_found' using errcode = 'PT404';
  end if;

  if not private.leads_d_group(v_group.id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  if v_group.status <> 'ACTIVE' then
    raise exception 'd_group_not_active' using errcode = 'PT409';
  end if;

  select dgm.* into v_leader
  from public.d_group_memberships dgm
  where dgm.d_group_id = v_group.id
    and dgm.responsibility = 'LEADER'
    and dgm.ended_at is null;

  perform 1
  from public.church_memberships m
  where m.id = v_leader.church_membership_id
  for update;

  if exists (
    select 1
    from public.d_group_memberships dgm
    where dgm.church_membership_id = v_leader.church_membership_id
      and dgm.d_group_id = v_group.id
      and dgm.responsibility = 'DISCIPLER'
      and dgm.ended_at is null
  ) then
    raise exception 'already_discipler' using errcode = 'PT409';
  end if;

  insert into public.d_group_memberships
    (d_group_id, church_membership_id, responsibility, started_at,
     assigned_by, discipler_basis)
  values
    (v_group.id, v_leader.church_membership_id, 'DISCIPLER', now(),
     v_uid, 'LEADER_SELF')
  returning id into v_dgm;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_group.church_id,
    v_uid,
    'D_GROUP_MEMBER_ADDED',
    'd_group_memberships',
    v_dgm,
    jsonb_build_object(
      'd_group_id', v_group.id,
      'church_membership_id', v_leader.church_membership_id,
      'responsibility', 'DISCIPLER',
      'discipler_basis', 'LEADER_SELF',
      'self', true
    )
  );

  return query select v_dgm;
end;
$$;


-- As Migration 006, plus the self-pairing and reciprocal refusals, so
-- the caller gets a reason rather than the trigger's constraint error.
create or replace function public.set_discipler(
  p_disciple_d_group_membership_id  uuid,
  p_discipler_d_group_membership_id uuid
)
returns table (outcome text, discipler_assignment_id uuid)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid       uuid := (select auth.uid());
  v_disciple  public.d_group_memberships%rowtype;
  v_discipler public.d_group_memberships%rowtype;
  v_current   public.discipler_assignments%rowtype;
  v_church    uuid;
  v_status    public.membership_status;
  v_new       uuid;
  v_action    text;
  v_outcome   text;
  v_now       timestamptz := now();
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select * into v_disciple
  from public.d_group_memberships dgm
  where dgm.id = p_disciple_d_group_membership_id;

  if not found then
    raise exception 'd_group_membership_not_found' using errcode = 'PT404';
  end if;

  if not private.can_manage_d_group_members(v_disciple.d_group_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  select m.status into v_status
  from public.church_memberships m
  where m.id = v_disciple.church_membership_id
  for update;

  select * into v_disciple
  from public.d_group_memberships dgm
  where dgm.id = p_disciple_d_group_membership_id
  for update;

  if v_disciple.responsibility <> 'DISCIPLE' or v_disciple.ended_at is not null then
    raise exception 'not_an_active_disciple' using errcode = 'PT409';
  end if;

  if v_status <> 'ACTIVE' then
    raise exception 'member_not_active' using errcode = 'PT409';
  end if;

  select * into v_current
  from public.discipler_assignments a
  where a.disciple_d_group_membership_id = v_disciple.id
    and a.ended_at is null
  for update;

  if p_discipler_d_group_membership_id is null then
    if v_current.id is null then
      raise exception 'not_paired' using errcode = 'PT409';
    end if;
    v_action  := 'DISCIPLER_UNASSIGNED';
    v_outcome := 'UNASSIGNED';
  else
    select * into v_discipler
    from public.d_group_memberships dgm
    where dgm.id = p_discipler_d_group_membership_id
    for share;

    if not found then
      raise exception 'd_group_membership_not_found' using errcode = 'PT404';
    end if;

    if v_discipler.responsibility <> 'DISCIPLER'
       or v_discipler.ended_at is not null
       or v_discipler.d_group_id <> v_disciple.d_group_id then
      raise exception 'not_an_active_discipler' using errcode = 'PT409';
    end if;

    if v_discipler.church_membership_id = v_disciple.church_membership_id then
      raise exception 'cannot_pair_with_self' using errcode = 'PT409';
    end if;

    select m.status into v_status
    from public.church_memberships m
    where m.id = v_discipler.church_membership_id;

    if v_status <> 'ACTIVE' then
      raise exception 'member_not_active' using errcode = 'PT409';
    end if;

    if v_current.discipler_d_group_membership_id = v_discipler.id then
      raise exception 'already_paired' using errcode = 'PT409';
    end if;

    -- D7: the chosen Discipler is not currently the Disciple of the
    -- person they would disciple.
    if exists (
      select 1
      from public.discipler_assignments a
      join public.d_group_memberships dd on dd.id = a.disciple_d_group_membership_id
      join public.d_group_memberships dr on dr.id = a.discipler_d_group_membership_id
      where a.ended_at is null
        and dd.church_membership_id = v_discipler.church_membership_id
        and dr.church_membership_id = v_disciple.church_membership_id
    ) then
      raise exception 'reciprocal_pairing' using errcode = 'PT409';
    end if;

    if v_current.id is null then
      v_action  := 'DISCIPLER_ASSIGNED';
      v_outcome := 'ASSIGNED';
    else
      v_action  := 'DISCIPLER_REASSIGNED';
      v_outcome := 'REASSIGNED';
    end if;
  end if;

  if v_current.id is not null then
    -- MONITORING HOOK: resolve the ACTIVE condition belonging to the
    -- assignment ended here when Slice 9 adds one.
    update public.discipler_assignments a
    set ended_at = v_now
    where a.id = v_current.id;
  end if;

  if v_discipler.id is not null then
    insert into public.discipler_assignments
      (d_group_id, discipler_d_group_membership_id,
       disciple_d_group_membership_id, assigned_by, started_at)
    values
      (v_disciple.d_group_id, v_discipler.id, v_disciple.id, v_uid, v_now)
    returning id into v_new;
  end if;

  select g.church_id into v_church
  from public.d_groups g
  where g.id = v_disciple.d_group_id;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_church,
    v_uid,
    v_action,
    'discipler_assignments',
    coalesce(v_new, v_current.id),
    jsonb_build_object(
      'd_group_id', v_disciple.d_group_id,
      'disciple_d_group_membership_id', v_disciple.id,
      'from_discipler_d_group_membership_id', v_current.discipler_d_group_membership_id,
      'to_discipler_d_group_membership_id', v_discipler.id,
      'ended_discipler_assignment_id', v_current.id
    )
  );

  return query select v_outcome, v_new;
end;
$$;


do $$
declare
  v_fn text;
begin
  foreach v_fn in array array[
    'public.set_up_member(uuid, public.d_group_responsibility)',
    'public.set_initial_setup_open(uuid, boolean)',
    'public.get_initial_setup_status(uuid)'
  ]
  loop
    execute format('revoke execute on function %s from public, anon', v_fn);
    execute format('grant execute on function %s to authenticated, service_role', v_fn);
  end loop;
end
$$;
