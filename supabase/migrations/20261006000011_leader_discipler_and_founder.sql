-- ============================================================
-- DiscipleTrack - Migration 018: every Leader is a Discipler;
-- the founding Admin skips the welcome
-- ============================================================
--
-- ADR-020 (user decision 2026-10-06): a D Group Leader always holds the
-- DISCIPLER responsibility in their group. Before, a Leader *could*
-- add themselves as Discipler (add_self_as_discipler, ADR-018); now the
-- role comes with the leadership:
--
--   - create_d_group() and assign_d_group_leader() give the new Leader
--     a DISCIPLER row (discipler_basis LEADER_SELF) unless they already
--     hold one. A replaced Leader keeps it, as before, and so stays in
--     the group as a Discipler.
--   - Existing Leaders without one are given one here.
--   - A deferred constraint trigger refuses, at commit, any state where
--     an active LEADER row has no active DISCIPLER row for the same
--     person and group. Every path that ends rows (removal, leaving the
--     church, archiving the group) ends both together or refuses the
--     Leader, so the check holds them to it in one place.
--   - add_self_as_discipler() is kept; for any active Leader it now
--     answers already_discipler.
--
-- Bootstrap (user decision 2026-10-06): the founding Admin creates the
-- church and has no welcome to see. private.bootstrap_church() is
-- Migration 007's with onboarding_completed_at set on the founder's
-- membership; founders of existing churches are backfilled.
--
-- Migrations 001 to 017 are not modified.
-- ============================================================


-- ============================================================
-- 1. LEADERS HOLD DISCIPLER
-- ============================================================

comment on column public.d_group_memberships.discipler_basis is
  'Why a DISCIPLER row exists: INITIAL_ROLLOUT (recognized during the initial setup window), LEADER_SELF (the Leader''s own Discipler role, which comes with the leadership, ADR-020) or APPOINTMENT (appointed after Lesson 5; see ministry_role_transitions). Null for LEADER and DISCIPLE rows.';

-- Backfill: every active Leader without an active DISCIPLER row in the
-- same group. assigned_by is whoever assigned the leadership.
with added as (
  insert into public.d_group_memberships
    (d_group_id, church_membership_id, responsibility, started_at,
     assigned_by, discipler_basis)
  select l.d_group_id, l.church_membership_id, 'DISCIPLER', now(),
         l.assigned_by, 'LEADER_SELF'
  from public.d_group_memberships l
  where l.responsibility = 'LEADER'
    and l.ended_at is null
    and not exists (
      select 1
      from public.d_group_memberships d
      where d.church_membership_id = l.church_membership_id
        and d.d_group_id = l.d_group_id
        and d.responsibility = 'DISCIPLER'
        and d.ended_at is null
    )
  returning id, d_group_id, church_membership_id, assigned_by
)
insert into public.audit_events
  (church_id, actor_user_id, action, entity_type, entity_id, metadata)
select g.church_id, a.assigned_by, 'D_GROUP_MEMBER_ADDED',
       'd_group_memberships', a.id,
       jsonb_build_object(
         'd_group_id', a.d_group_id,
         'church_membership_id', a.church_membership_id,
         'responsibility', 'DISCIPLER',
         'discipler_basis', 'LEADER_SELF',
         'with_leadership', true,
         'backfill', 'migration 018'
       )
from added a
join public.d_groups g on g.id = a.d_group_id;


create function private.check_leader_holds_discipler()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.d_group_memberships l
    where l.church_membership_id = new.church_membership_id
      and l.d_group_id = new.d_group_id
      and l.responsibility = 'LEADER'
      and l.ended_at is null
  ) and not exists (
    select 1
    from public.d_group_memberships d
    where d.church_membership_id = new.church_membership_id
      and d.d_group_id = new.d_group_id
      and d.responsibility = 'DISCIPLER'
      and d.ended_at is null
  ) then
    raise exception 'leader_must_be_discipler'
      using errcode = '23514',
            detail = 'An active D Group Leader holds the DISCIPLER responsibility in the same group (ADR-020).';
  end if;

  return null;
end;
$$;

revoke execute on function private.check_leader_holds_discipler()
  from public, anon, authenticated;

create constraint trigger d_group_memberships_leader_discipler
  after insert or update on public.d_group_memberships
  deferrable initially deferred
  for each row execute function private.check_leader_holds_discipler();


-- As Migration 012, plus the Leader's DISCIPLER row.
create or replace function public.create_d_group(
  p_name                 text,
  p_description          text,
  p_leader_membership_id uuid
)
returns table (d_group_id uuid, leader_d_group_membership_id uuid)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid       uuid := (select auth.uid());
  v_leader    public.church_memberships%rowtype;
  v_name      text := trim(coalesce(p_name, ''));
  v_group     uuid;
  v_dgm       uuid;
  v_discipler uuid;
  v_now       timestamptz := now();
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select * into v_leader
  from public.church_memberships m
  where m.id = p_leader_membership_id
  for update;

  if not found then
    raise exception 'membership_not_found' using errcode = 'PT404';
  end if;

  if not private.is_church_coordinator(v_leader.church_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  if v_name = '' then
    raise exception 'd_group_name_required' using errcode = 'PT400';
  end if;

  if v_leader.status <> 'ACTIVE' then
    raise exception 'member_not_active' using errcode = 'PT409';
  end if;

  if not private.is_unplaced(v_leader.id) then
    raise exception 'member_already_placed' using errcode = 'PT409';
  end if;

  begin
    insert into public.d_groups (church_id, name, description, created_by)
    values (
      v_leader.church_id,
      v_name,
      nullif(trim(coalesce(p_description, '')), ''),
      v_uid
    )
    returning id into v_group;
  exception
    when unique_violation then
      raise exception 'd_group_name_taken' using errcode = 'PT409';
  end;

  insert into public.d_group_placements
    (d_group_id, church_membership_id, started_at, placed_by)
  values (v_group, v_leader.id, v_now, v_uid);

  insert into public.d_group_memberships
    (d_group_id, church_membership_id, responsibility, started_at, assigned_by)
  values (v_group, v_leader.id, 'LEADER', v_now, v_uid)
  returning id into v_dgm;

  insert into public.d_group_memberships
    (d_group_id, church_membership_id, responsibility, started_at,
     assigned_by, discipler_basis)
  values (v_group, v_leader.id, 'DISCIPLER', v_now, v_uid, 'LEADER_SELF')
  returning id into v_discipler;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_leader.church_id,
    v_uid,
    'D_GROUP_CREATED',
    'd_groups',
    v_group,
    jsonb_build_object(
      'name', v_name,
      'leader_church_membership_id', v_leader.id,
      'leader_d_group_membership_id', v_dgm,
      'leader_discipler_d_group_membership_id', v_discipler
    )
  );

  return query select v_group, v_dgm;
end;
$$;

comment on function public.create_d_group(text, text, uuid) is
  'Coordinator only. Creates an ACTIVE D Group with an unplaced ACTIVE member as its Leader, who also holds DISCIPLER there (ADR-020). Audited as D_GROUP_CREATED.';


-- As Migration 012, plus the new Leader's DISCIPLER row when they do
-- not hold one. The replaced Leader keeps theirs and stays a Discipler.
create or replace function public.assign_d_group_leader(
  p_d_group_id    uuid,
  p_membership_id uuid
)
returns table (d_group_membership_id uuid)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid       uuid := (select auth.uid());
  v_group     public.d_groups%rowtype;
  v_target    public.church_memberships%rowtype;
  v_old       public.d_group_memberships%rowtype;
  v_dgm       uuid;
  v_discipler uuid;
  v_now       timestamptz := now();
  v_old_left  boolean := false;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select * into v_group
  from public.d_groups g
  where g.id = p_d_group_id
  for update;

  if not found then
    raise exception 'd_group_not_found' using errcode = 'PT404';
  end if;

  if not private.is_church_coordinator(v_group.church_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  if v_group.status <> 'ACTIVE' then
    raise exception 'd_group_not_active' using errcode = 'PT409';
  end if;

  select * into v_old
  from public.d_group_memberships dgm
  where dgm.d_group_id = v_group.id
    and dgm.responsibility = 'LEADER'
    and dgm.ended_at is null;

  -- Lock both people in id order so two replacements cannot deadlock.
  perform 1
  from public.church_memberships m
  where m.id in (p_membership_id, v_old.church_membership_id)
    and m.church_id = v_group.church_id
  order by m.id
  for update;

  select * into v_target
  from public.church_memberships m
  where m.id = p_membership_id
    and m.church_id = v_group.church_id;

  if not found then
    raise exception 'membership_not_found' using errcode = 'PT404';
  end if;

  if v_target.status <> 'ACTIVE' then
    raise exception 'member_not_active' using errcode = 'PT409';
  end if;

  if v_old.church_membership_id = v_target.id then
    raise exception 'already_leader' using errcode = 'PT409';
  end if;

  if exists (
    select 1
    from public.d_group_placements p
    where p.church_membership_id = v_target.id
      and p.ended_at is null
      and p.d_group_id <> v_group.id
  ) or exists (
    select 1
    from public.d_group_memberships dgm
    where dgm.church_membership_id = v_target.id
      and dgm.ended_at is null
      and dgm.responsibility <> 'DISCIPLER'
  ) then
    raise exception 'leader_not_eligible' using errcode = 'PT409';
  end if;

  if v_old.id is not null then
    update public.d_group_memberships dgm
    set ended_at = v_now
    where dgm.id = v_old.id;

    if not exists (
      select 1
      from public.d_group_memberships dgm
      where dgm.church_membership_id = v_old.church_membership_id
        and dgm.d_group_id = v_group.id
        and dgm.ended_at is null
    ) then
      update public.d_group_placements p
      set ended_at = v_now,
          ended_by = v_uid
      where p.church_membership_id = v_old.church_membership_id
        and p.d_group_id = v_group.id
        and p.ended_at is null;
      v_old_left := true;
    end if;
  end if;

  if private.is_unplaced(v_target.id) then
    insert into public.d_group_placements
      (d_group_id, church_membership_id, started_at, placed_by)
    values (v_group.id, v_target.id, v_now, v_uid);
  end if;

  insert into public.d_group_memberships
    (d_group_id, church_membership_id, responsibility, started_at, assigned_by)
  values (v_group.id, v_target.id, 'LEADER', v_now, v_uid)
  returning id into v_dgm;

  if not exists (
    select 1
    from public.d_group_memberships dgm
    where dgm.church_membership_id = v_target.id
      and dgm.d_group_id = v_group.id
      and dgm.responsibility = 'DISCIPLER'
      and dgm.ended_at is null
  ) then
    insert into public.d_group_memberships
      (d_group_id, church_membership_id, responsibility, started_at,
       assigned_by, discipler_basis)
    values (v_group.id, v_target.id, 'DISCIPLER', v_now, v_uid, 'LEADER_SELF')
    returning id into v_discipler;
  end if;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_group.church_id,
    v_uid,
    'D_GROUP_LEADER_ASSIGNED',
    'd_groups',
    v_group.id,
    jsonb_build_object(
      'from_church_membership_id', v_old.church_membership_id,
      'from_d_group_membership_id', v_old.id,
      'from_left_group', v_old_left,
      'to_church_membership_id', v_target.id,
      'to_d_group_membership_id', v_dgm,
      'to_discipler_d_group_membership_id', v_discipler
    )
  );

  return query select v_dgm;
end;
$$;

comment on function public.assign_d_group_leader(uuid, uuid) is
  'Coordinator only. Replaces (or sets) the active LEADER of a D Group in one transaction. The new Leader is unplaced, or in this group with no responsibility other than DISCIPLER, and holds DISCIPLER there afterwards (ADR-020). The previous Leader keeps their DISCIPLER row and stays in the group. Audited as D_GROUP_LEADER_ASSIGNED.';


-- ============================================================
-- 2. THE FOUNDER SKIPS THE WELCOME
-- ============================================================

-- As Migration 007, with onboarding_completed_at set on the founder's
-- membership (step 3).
create or replace function private.bootstrap_church(
  p_church_id uuid,
  p_name text,
  p_initial_user_id uuid,
  p_join_code text default null,
  p_curriculum_name text default 'Discipleship Curriculum',
  p_lesson_titles text[] default null
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name text := trim(coalesce(p_name, ''));
  v_join_code text;
  v_titles text[];
  v_membership_id uuid;
  v_curriculum_id uuid;
begin
  if p_church_id is null then
    raise exception 'bootstrap: p_church_id is required';
  end if;

  -- Idempotency: an existing church is verified, never modified.
  if exists (select 1 from public.churches c where c.id = p_church_id) then
    perform private.assert_bootstrap_postconditions(p_church_id, p_initial_user_id);
    return p_church_id;
  end if;

  if v_name = '' then
    raise exception 'bootstrap: church name is required';
  end if;

  if p_initial_user_id is null
     or not exists (select 1 from public.profiles p where p.id = p_initial_user_id) then
    raise exception 'bootstrap: the initial user must already have a profiles row (%)',
      p_initial_user_id;
  end if;

  v_join_code := coalesce(upper(trim(p_join_code)), private.generate_join_code());
  if v_join_code !~ '^[A-HJ-NP-Z2-9]{10}$' then
    raise exception 'bootstrap: join code must match ^[A-HJ-NP-Z2-9]{10}$';
  end if;

  v_titles := coalesce(
    p_lesson_titles,
    array(select 'Lesson ' || g::text from generate_series(1, 10) as g)
  );
  if coalesce(array_length(v_titles, 1), 0) <> 10 then
    raise exception 'bootstrap: exactly ten lesson titles are required';
  end if;

  -- 1. churches
  insert into public.churches (id, name, join_code, join_code_updated_at, status)
  values (p_church_id, v_name, v_join_code, now(), 'ACTIVE');

  -- 2. church_settings
  insert into public.church_settings (
    church_id,
    consecutive_absence_threshold,
    consecutive_missed_meeting_threshold,
    follow_up_due_days
  )
  values (p_church_id, 3, 3, 7);

  -- 3. church_memberships: the founder set up the church, so there is no
  --    first-entry welcome to show them.
  insert into public.church_memberships
    (church_id, user_id, status, joined_at, onboarding_completed_at)
  values (p_church_id, p_initial_user_id, 'ACTIVE', now(), now())
  returning id into v_membership_id;

  -- 4. church_role_assignments
  insert into public.church_role_assignments
    (church_membership_id, role, assigned_by, started_at)
  values
    (v_membership_id, 'ADMIN', p_initial_user_id, now()),
    (v_membership_id, 'COORDINATOR', p_initial_user_id, now());

  -- 5. curricula
  insert into public.curricula (church_id, name, status)
  values (
    p_church_id,
    coalesce(nullif(trim(p_curriculum_name), ''), 'Discipleship Curriculum'),
    'ACTIVE'
  )
  returning id into v_curriculum_id;

  -- 6. curriculum_lessons
  insert into public.curriculum_lessons
    (curriculum_id, lesson_number, title, required_meetings)
  select v_curriculum_id, g, v_titles[g], 4
  from generate_series(1, 10) as g;

  -- 7. audit_events
  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    p_church_id,
    p_initial_user_id,
    'CHURCH_BOOTSTRAPPED',
    'churches',
    p_church_id,
    jsonb_build_object(
      'name', v_name,
      'initial_user_id', p_initial_user_id,
      'curriculum_id', v_curriculum_id
    )
  );

  perform private.assert_bootstrap_postconditions(p_church_id, p_initial_user_id);
  return p_church_id;
end;
$$;

-- Founders of existing churches, identified by the bootstrap's audit
-- event, who have not seen the welcome yet.
update public.church_memberships m
set onboarding_completed_at = now()
from public.audit_events a
where a.action = 'CHURCH_BOOTSTRAPPED'
  and a.church_id = m.church_id
  and (a.metadata ->> 'initial_user_id')::uuid = m.user_id
  and m.status = 'ACTIVE'
  and m.onboarding_completed_at is null;
