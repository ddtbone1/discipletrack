-- ============================================================
-- DiscipleTrack - Migration 007: Discipleship Meeting + Progress
-- ============================================================
--
-- Database logic for Vertical Slice 5 (Journey / Meeting Progress).
-- This file is built in the order of the slice plan
-- (docs/plans/slice-5-discipleship-meeting-progress.md, section J).
-- Step 2 lands the schema, the grants and the integrity triggers.
-- Step 3 lands the policy points, the read helpers and RLS.
-- Step 4 lands recording and the reads that recording and Disciple
-- detail need.
-- Step 5 lands the meeting summary and the Home progress summary.
-- Lesson completion lands with ADR-015: the Discipler marks a lesson
-- completed in one step, with a short undo window; no Leader
-- confirmation.
--
-- Migration 001 says occurred_at immutability and participant rules
-- P1 to P3 are enforced "in Migration 002". Migration 002 deferred
-- both; they are enforced here.
--
-- Scope of this migration:
--   Schema
--     - meeting_participation_status: COUNTED renamed RECORDED (ADR-009)
--     - discipleship_meeting_participants.attendance_status, NOT NULL,
--       no default (ADR-009)
--     - disciple_lesson_progress.submitted_by (ADR-011)
--     - disciple_lesson_progress State Check (DC section 4)
--     - indexes for the meeting and progress reads
--   Grants
--     - anon loses everything on the curriculum, meeting, progress,
--       condition and follow-up tables
--     - authenticated keeps SELECT only (under RLS) on those tables;
--       on curriculum_lessons every column except required_meetings
--     - d_group_gatherings and gathering_attendance: all privileges
--       revoked from anon and authenticated (ADR-014 decision 14,
--       step 1; security only)
--   Integrity triggers (defence in depth, every writer)
--     - discipleship_meetings: Discipler row valid and active at
--       occurred_at, lesson in the group's church, context immutable,
--       VOIDED terminal
--     - discipleship_meeting_participants: P1 to P3 as of occurred_at,
--       same church, parent RECORDED, never the Discipler's own person,
--       identity and outcome immutable, VOIDED terminal
--     - disciple_lesson_progress: lesson in the member's church
--   Policy points (schema private, trusted operations only)
--     - lesson_meeting_policy(): PLACEHOLDER floor until N1 is decided
--     - discipler_eligibility_lesson(): 5 (ADR-012, D2)
--   Helpers (schema private, no API endpoint)
--     - curriculum read, progress and meeting visibility, credited
--       count, eligible lesson
--   RLS (read-only policies)
--     - curricula, curriculum_lessons: ACTIVE members of the church
--     - discipleship_meetings, discipleship_meeting_participants:
--       meeting-context scope; a Disciple sees only their own row
--     - disciple_lesson_progress: Coordinator, Leader of the current
--       group, current assigned Discipler (N7), self
--   Recording (step 4)
--     - recompute_lesson_progress(): NOT_STARTED / IN_PROGRESS only;
--       never READY_FOR_COMPLETION or COMPLETED
--     - record_discipleship_meeting()
--     - get_disciple_context(), get_disciple_journey(),
--       get_meeting_history(), list_disciple_progress(),
--       get_recording_options()
--   Journey and Home reads (step 5)
--     - get_disciple_meeting_summary(), get_progress_summary()
--   Lesson completion (ADR-015)
--     - complete_lesson(), undo_lesson_completion()
--   Curriculum of ten lessons (user decision, 2026-10-05)
--     - bootstrap_church() and assert_bootstrap_postconditions()
--       replaced with the count changed from twelve to ten; unreferenced
--       Lessons 11 and 12 removed from existing ACTIVE curricula
--
-- RPC reasons, as in Migration 006 (PTxxx SQLSTATE, reason as message):
--
--   PT400 participants_required / duplicate_participant /
--         invalid_attendance_status / occurred_at_required
--   PT401 authentication_required
--   PT403 not_authorized
--   PT404 lesson_not_found / progress_not_found
--   PT409 occurred_at_in_future / discipler_not_active_at_occurred_at /
--         lesson_not_in_active_curriculum / member_not_active /
--         cannot_record_own_meeting /
--         participant_not_assigned_at_occurred_at / lesson_not_eligible /
--         cannot_act_on_own_lesson / lesson_not_in_progress /
--         below_submission_minimum / lesson_not_completed /
--         later_lesson_completed / next_lesson_started
--
-- Integrity triggers raise check_violation (23514) with a stable reason
-- as the message, as in Migration 006:
--
--   meeting_discipler_invalid / meeting_discipler_not_active /
--   meeting_cross_church / meeting_immutable / meeting_voided_terminal /
--   participant_meeting_not_recorded / participant_cross_church /
--   participant_is_discipler / participant_not_disciple_at_occurred_at /
--   participant_not_assigned_at_occurred_at / participant_immutable /
--   participant_voided_terminal / progress_cross_church
--
-- Not in this migration: required_meetings is untouched (the meeting
-- policy is a function, Lesson Meeting Policy, DC section 4); no enum
-- value is added (ADR-014 withdraws CONSECUTIVE_MISSED_MEETINGS); no
-- policy is added to attention_conditions, follow_ups or
-- follow_up_actions; nothing about gatherings changes beyond grants.


-- ============================================================
-- 1. SCHEMA
-- ============================================================

-- ADR-009: participant status is record validity only.
alter type public.meeting_participation_status
  rename value 'COUNTED' to 'RECORDED';

alter table public.discipleship_meeting_participants
  alter column status set default 'RECORDED';

-- ADR-009: the outcome is always explicit, so the column has no
-- default. Adding a NOT NULL column without a default needs an empty
-- table; no write path to it has existed before this migration.
do $$
begin
  if exists (select 1 from public.discipleship_meeting_participants) then
    raise exception 'discipleship_meeting_participants must be empty '
      'before attendance_status is added';
  end if;
end;
$$;

alter table public.discipleship_meeting_participants
  add column attendance_status public.attendance_status not null;

-- ADR-011: who submitted the lesson as finished.
alter table public.disciple_lesson_progress
  add column submitted_by uuid,
  add constraint disciple_lesson_progress_submitted_by_fkey
    foreign key (submitted_by)
    references public.profiles (id) on delete no action;

-- DC section 4, Progress State Check.
alter table public.disciple_lesson_progress
  add constraint disciple_lesson_progress_state_check
    check (
      case status
        when 'NOT_STARTED' then
          started_at is null and ready_at is null and submitted_by is null
          and completed_at is null and confirmed_by is null
        when 'IN_PROGRESS' then
          started_at is not null and ready_at is null
          and submitted_by is null
          and completed_at is null and confirmed_by is null
        when 'READY_FOR_COMPLETION' then
          started_at is not null and ready_at is not null
          and submitted_by is not null
          and completed_at is null and confirmed_by is null
        when 'COMPLETED' then
          started_at is not null and ready_at is not null
          and submitted_by is not null
          and completed_at is not null and confirmed_by is not null
      end
    );

-- Meeting history per Discipler row in date order, per group by date,
-- and by lesson; participant rows per person.
create index discipleship_meetings_discipler_occurred_idx
  on public.discipleship_meetings
    (discipler_d_group_membership_id, occurred_at, id);

create index discipleship_meetings_group_occurred_idx
  on public.discipleship_meetings (d_group_id, occurred_at);

create index discipleship_meetings_lesson_idx
  on public.discipleship_meetings (lesson_id);

create index dmp_membership_idx
  on public.discipleship_meeting_participants (church_membership_id);


-- ============================================================
-- 2. GRANTS
-- ============================================================
--
-- As in Migration 006: RLS already denies these tables to clients, and
-- the default grants are narrowed too, so a future permissive policy
-- cannot open a write path by accident. Every write goes through the
-- SECURITY DEFINER operations of this slice.

revoke all on table
  public.curricula,
  public.curriculum_lessons,
  public.discipleship_meetings,
  public.discipleship_meeting_participants,
  public.disciple_lesson_progress,
  public.attention_conditions,
  public.follow_ups,
  public.follow_up_actions
from anon;

revoke insert, update, delete, truncate on table
  public.curricula,
  public.curriculum_lessons,
  public.discipleship_meetings,
  public.discipleship_meeting_participants,
  public.disciple_lesson_progress,
  public.attention_conditions,
  public.follow_ups,
  public.follow_up_actions
from authenticated;

-- DC section 4, Lesson Meeting Policy: no client reads
-- required_meetings. It is pre-ADR-011 seed data whose meaning waits on
-- N1, and exposing it would invite a client to treat it as a rule. Every
-- other column stays readable under RLS.
revoke select on table public.curriculum_lessons from authenticated;
grant select (
  id, curriculum_id, lesson_number, title, description, created_at,
  updated_at
) on table public.curriculum_lessons to authenticated;

-- ADR-014 decision 14, step 1: gatherings are removed from the MVP.
-- Lock-down only: RLS stays enabled with no policy, and no object,
-- column, trigger, enum or row is altered or dropped.
revoke all on table
  public.d_group_gatherings,
  public.gathering_attendance
from anon, authenticated;


-- ============================================================
-- 3. INTEGRITY TRIGGERS
-- ============================================================
--
-- Constraint triggers, not deferred, SECURITY DEFINER, as in Migration
-- 006. "Active at T" is started_at <= T and (ended_at is null or
-- ended_at > T) (DC section 4, Participant Validity).

-- DC section 4 (Meeting Records Are Immutable, occurred_at Is
-- Immutable) and section 10 (meetings vs D Group, Discipler, lesson).
create function private.check_discipleship_meeting_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_discipler     public.d_group_memberships%rowtype;
  v_group_church  uuid;
  v_lesson_church uuid;
begin
  if tg_op = 'UPDATE' then
    if new.d_group_id <> old.d_group_id
       or new.discipler_d_group_membership_id
          <> old.discipler_d_group_membership_id
       or new.lesson_id <> old.lesson_id
       or new.occurred_at <> old.occurred_at
       or new.recorded_by <> old.recorded_by
       or new.created_at <> old.created_at then
      raise exception 'meeting_immutable'
        using errcode = '23514',
              detail = 'A meeting''s context cannot change. Void it and record it again.';
    end if;

    if old.status = 'VOIDED'
       and (new.status, new.voided_by, new.voided_at)
           is distinct from (old.status, old.voided_by, old.voided_at) then
      raise exception 'meeting_voided_terminal'
        using errcode = '23514',
              detail = 'A voided meeting cannot change status.';
    end if;

    return null;
  end if;

  select * into v_discipler
  from public.d_group_memberships d
  where d.id = new.discipler_d_group_membership_id;

  if v_discipler.responsibility is distinct from 'DISCIPLER'
     or v_discipler.d_group_id <> new.d_group_id then
    raise exception 'meeting_discipler_invalid'
      using errcode = '23514',
            detail = 'discipler_d_group_membership_id must be a DISCIPLER row of the meeting''s D Group.';
  end if;

  if not (v_discipler.started_at <= new.occurred_at
          and (v_discipler.ended_at is null
               or v_discipler.ended_at > new.occurred_at)) then
    raise exception 'meeting_discipler_not_active'
      using errcode = '23514',
            detail = 'The Discipler row must be active at occurred_at.';
  end if;

  select g.church_id into v_group_church
  from public.d_groups g
  where g.id = new.d_group_id;

  select c.church_id into v_lesson_church
  from public.curriculum_lessons l
  join public.curricula c on c.id = l.curriculum_id
  where l.id = new.lesson_id;

  if v_lesson_church is distinct from v_group_church then
    raise exception 'meeting_cross_church'
      using errcode = '23514',
            detail = 'The lesson''s curriculum belongs to another church.';
  end if;

  return null;
end;
$$;

revoke execute on function private.check_discipleship_meeting_integrity()
  from public, anon, authenticated;

create constraint trigger discipleship_meetings_integrity
  after insert or update on public.discipleship_meetings
  for each row execute function private.check_discipleship_meeting_integrity();


-- DC section 4 (Participant Validity, Meeting Records Are Immutable)
-- and section 10. Only RECORDED rows are validated, at insert; VOIDED
-- rows are history (DC section 4).
create function private.check_meeting_participant_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meeting         public.discipleship_meetings%rowtype;
  v_group_church    uuid;
  v_member_church   uuid;
  v_discipler_cm    uuid;
begin
  if tg_op = 'UPDATE' then
    if new.meeting_id <> old.meeting_id
       or new.church_membership_id <> old.church_membership_id
       or new.attendance_status <> old.attendance_status
       or new.created_at <> old.created_at then
      raise exception 'participant_immutable'
        using errcode = '23514',
              detail = 'A participant''s person and outcome cannot change. Void the meeting and record it again.';
    end if;

    if old.status = 'VOIDED'
       and (new.status, new.voided_by, new.voided_at)
           is distinct from (old.status, old.voided_by, old.voided_at) then
      raise exception 'participant_voided_terminal'
        using errcode = '23514',
              detail = 'A voided participant cannot change status.';
    end if;

    return null;
  end if;

  if new.status <> 'RECORDED' then
    return null;
  end if;

  select * into v_meeting
  from public.discipleship_meetings m
  where m.id = new.meeting_id;

  if v_meeting.status is distinct from 'RECORDED' then
    raise exception 'participant_meeting_not_recorded'
      using errcode = '23514',
            detail = 'A RECORDED participant needs a RECORDED meeting.';
  end if;

  select g.church_id into v_group_church
  from public.d_groups g
  where g.id = v_meeting.d_group_id;

  select m.church_id into v_member_church
  from public.church_memberships m
  where m.id = new.church_membership_id;

  if v_member_church is distinct from v_group_church then
    raise exception 'participant_cross_church'
      using errcode = '23514',
            detail = 'The participant belongs to another church.';
  end if;

  -- Explicit, not inferred from the DISCIPLE / DISCIPLER exclusion,
  -- which ADR-012 relaxes in Slice 6 (plan section P, item 1).
  select d.church_membership_id into v_discipler_cm
  from public.d_group_memberships d
  where d.id = v_meeting.discipler_d_group_membership_id;

  if v_discipler_cm = new.church_membership_id then
    raise exception 'participant_is_discipler'
      using errcode = '23514',
            detail = 'The meeting''s Discipler cannot be a participant.';
  end if;

  -- P1 and P2.
  if not exists (
    select 1
    from public.d_group_memberships d
    where d.church_membership_id = new.church_membership_id
      and d.d_group_id = v_meeting.d_group_id
      and d.responsibility = 'DISCIPLE'
      and d.started_at <= v_meeting.occurred_at
      and (d.ended_at is null or d.ended_at > v_meeting.occurred_at)
  ) then
    raise exception 'participant_not_disciple_at_occurred_at'
      using errcode = '23514',
            detail = 'The participant was not a DISCIPLE of the meeting''s D Group at occurred_at.';
  end if;

  -- P3.
  if not exists (
    select 1
    from public.discipler_assignments a
    join public.d_group_memberships d
      on d.id = a.disciple_d_group_membership_id
    where d.church_membership_id = new.church_membership_id
      and a.discipler_d_group_membership_id
          = v_meeting.discipler_d_group_membership_id
      and a.started_at <= v_meeting.occurred_at
      and (a.ended_at is null or a.ended_at > v_meeting.occurred_at)
  ) then
    raise exception 'participant_not_assigned_at_occurred_at'
      using errcode = '23514',
            detail = 'The participant was not assigned to the meeting''s Discipler at occurred_at.';
  end if;

  return null;
end;
$$;

revoke execute on function private.check_meeting_participant_integrity()
  from public, anon, authenticated;

create constraint trigger discipleship_meeting_participants_integrity
  after insert or update on public.discipleship_meeting_participants
  for each row execute function private.check_meeting_participant_integrity();


-- DC section 10, disciple_lesson_progress vs curriculum.
create function private.check_lesson_progress_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select c.church_id
      from public.curriculum_lessons l
      join public.curricula c on c.id = l.curriculum_id
      where l.id = new.lesson_id)
     is distinct from
     (select m.church_id from public.church_memberships m
      where m.id = new.church_membership_id) then
    raise exception 'progress_cross_church'
      using errcode = '23514',
            detail = 'The lesson''s curriculum belongs to another church.';
  end if;

  return null;
end;
$$;

revoke execute on function private.check_lesson_progress_integrity()
  from public, anon, authenticated;

create constraint trigger disciple_lesson_progress_integrity
  after insert or update on public.disciple_lesson_progress
  for each row execute function private.check_lesson_progress_integrity();


-- ============================================================
-- 4. POLICY POINTS
-- ============================================================
--
-- Two numbers are ministry policy, each defined in exactly one place.
-- Callers use these functions and never encode either number. Neither
-- is granted to clients: they are read inside trusted operations.

-- DC section 4, Lesson Meeting Policy (ADR-011, open decision N1).
--
-- PLACEHOLDER, NOT A DECISION. N1 asks whether a lesson needs a minimum
-- number of credited meetings before it may be submitted as finished
-- (model B), or whether the number is only recommended (C) or
-- completely flexible (A). Until it is answered this returns the floor
-- that all three models share: submission_minimum = 1 (a lesson with no
-- credited participation is NOT_STARTED, so nothing can be submitted
-- below 1) and recommended_meetings = NULL. Returning 1 does not choose
-- model A. When N1 is decided, a forward migration replaces this body.
--
-- curriculum_lessons.required_meetings is deliberately not read: it is
-- seed data from before ADR-011 and no rule may depend on it until N1
-- says what, if anything, it means. In every model a meeting count
-- never completes a lesson or makes it READY_FOR_COMPLETION.
--
-- One row for an existing lesson, none for an unknown lesson.
create function private.lesson_meeting_policy(p_lesson_id uuid)
returns table (submission_minimum integer, recommended_meetings integer)
language sql
stable
security definer
set search_path = ''
as $$
  select 1, null::integer
  from public.curriculum_lessons l
  where l.id = p_lesson_id;
$$;

comment on function private.lesson_meeting_policy(uuid) is
  'PLACEHOLDER until N1 (minimum meetings) is decided: the floor shared by models A, B and C (submission_minimum 1, recommended_meetings NULL). Not a choice of model A. Does not read required_meetings. DC section 4, Lesson Meeting Policy.';


-- ADR-012 and D2 (decided 2026-10-05): the lesson whose confirmed
-- completion makes a Disciple eligible to be appointed a Discipler.
-- Ministry policy, not configuration: no argument and no setting. This
-- is the only place the number appears. Slice 5 reads it only in the
-- narrowed reopen precondition (step 7); Slice 6 derives eligibility
-- from it.
create function private.discipler_eligibility_lesson()
returns integer
language sql
immutable
set search_path = ''
as $$
  select 5;
$$;

comment on function private.discipler_eligibility_lesson() is
  'The Discipler eligibility lesson number (ADR-012, D2). The only place the number is encoded. DC section 11, Discipler Eligibility.';


-- ============================================================
-- 5. HELPERS
-- ============================================================
--
-- As in Migration 006: SECURITY DEFINER, so they read across RLS and
-- can be used inside the policies below without recursion. Every
-- predicate about the caller requires the caller's own membership to
-- be ACTIVE (RBAC section 1a), and every authority predicate decides
-- for the pair (caller, person viewed), never from holding a
-- responsibility in general (ADR-012 decision 8, N7).
--
-- The caller's current-Discipler relationship is
-- private.is_assigned_discipler_of(membership) from Migration 006,
-- which is exactly the relationship the plan calls
-- is_current_discipler_of; it is reused rather than duplicated.
--
-- Write-authority helpers (void, submit, withdraw, confirm) land with
-- the operations that use them, in later steps of the slice.

-- RBAC section 5: curriculum is readable by ACTIVE church members.
create function private.is_active_member_of(p_church_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.church_memberships m
    where m.church_id = p_church_id
      and m.user_id = (select auth.uid())
      and m.status = 'ACTIVE'
  );
$$;


create function private.can_read_curriculum(p_curriculum_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.curricula c
    where c.id = p_curriculum_id
      and private.is_active_member_of(c.church_id)
  );
$$;


-- The person's active DISCIPLE row, or NULL. Not about the caller.
create function private.current_disciple_row(p_membership_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select dgm.id
  from public.d_group_memberships dgm
  where dgm.church_membership_id = p_membership_id
    and dgm.responsibility = 'DISCIPLE'
    and dgm.ended_at is null;
$$;


-- RBAC section 2a, current-membership scope for LEADER: the caller
-- leads the group in which the person is currently a Disciple.
create function private.leads_current_group_of_disciple(p_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.d_group_memberships dd
    where dd.id = private.current_disciple_row(p_membership_id)
      and private.leads_d_group(dd.d_group_id)
  );
$$;


-- RBAC section 5, disciple_lesson_progress SELECT: Coordinator of the
-- person's church; Leader of the person's current group; the person's
-- current assigned Discipler only (N7: being in the same group is not
-- enough); the person themself.
create function private.can_view_progress_of(p_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_my_membership(p_membership_id)
      or private.is_assigned_discipler_of(p_membership_id)
      or private.leads_current_group_of_disciple(p_membership_id)
      or exists (
           select 1
           from public.church_memberships m
           where m.id = p_membership_id
             and private.is_church_coordinator(m.church_id)
         );
$$;


-- RBAC sections 2a and 5, meeting-context scope, the ministry branches:
-- Coordinator church-wide; Leader for meetings of their own group;
-- Discipler for meetings recorded under their own DISCIPLER row, ended
-- rows included, because history stays with the context it occurred
-- in. A Discipler does not read other Disciplers' meetings in the group
-- (contradiction O1, least privilege until decided).
create function private.can_oversee_meeting(p_meeting_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.discipleship_meetings dm
    join public.d_groups g on g.id = dm.d_group_id
    where dm.id = p_meeting_id
      and (
        private.is_church_coordinator(g.church_id)
        or private.leads_d_group(dm.d_group_id)
        or private.owns_d_group_membership(dm.discipler_d_group_membership_id)
      )
  );
$$;


-- discipleship_meetings SELECT: the ministry branches, or the caller is
-- a participant, whatever the recorded outcome.
create function private.can_view_meeting(p_meeting_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.can_oversee_meeting(p_meeting_id)
      or exists (
           select 1
           from public.discipleship_meeting_participants p
           where p.meeting_id = p_meeting_id
             and private.is_my_membership(p.church_membership_id)
         );
$$;


-- discipleship_meeting_participants SELECT: the parent meeting's
-- ministry branches, but a Disciple sees only their own row (Slice 5
-- decision 12, co-participant privacy).
create function private.can_view_participant(
  p_meeting_id           uuid,
  p_church_membership_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_my_membership(p_church_membership_id)
      or private.can_oversee_meeting(p_meeting_id);
$$;


-- DC section 11, Credited Meetings: RECORDED meeting, RECORDED
-- participation, outcome PRESENT or LATE. Derived, never stored.
create function private.credited_count(
  p_membership_id uuid,
  p_lesson_id     uuid
)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from public.discipleship_meeting_participants p
  join public.discipleship_meetings dm on dm.id = p.meeting_id
  where p.church_membership_id = p_membership_id
    and dm.lesson_id = p_lesson_id
    and dm.status = 'RECORDED'
    and p.status = 'RECORDED'
    and p.attendance_status in ('PRESENT', 'LATE');
$$;


-- DC section 4, sequential eligibility: the lowest-numbered lesson of
-- the person's church's ACTIVE curriculum that is not COMPLETED. NULL
-- when every lesson is COMPLETED or there is no ACTIVE curriculum.
create function private.eligible_lesson(p_membership_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select l.id
  from public.church_memberships m
  join public.curricula c on c.church_id = m.church_id and c.status = 'ACTIVE'
  join public.curriculum_lessons l on l.curriculum_id = c.id
  left join public.disciple_lesson_progress p
    on p.church_membership_id = m.id and p.lesson_id = l.id
  where m.id = p_membership_id
    and p.status is distinct from 'COMPLETED'
  order by l.lesson_number
  limit 1;
$$;


-- Helpers used by policies, which run as the caller.
do $$
declare
  v_fn text;
begin
  foreach v_fn in array array[
    'private.is_active_member_of(uuid)',
    'private.can_read_curriculum(uuid)',
    'private.current_disciple_row(uuid)',
    'private.leads_current_group_of_disciple(uuid)',
    'private.can_view_progress_of(uuid)',
    'private.can_oversee_meeting(uuid)',
    'private.can_view_meeting(uuid)',
    'private.can_view_participant(uuid, uuid)'
  ]
  loop
    execute format('revoke execute on function %s from public, anon', v_fn);
    execute format('grant execute on function %s to authenticated, service_role', v_fn);
  end loop;
end
$$;

-- Policy points and derivations are read only by trusted operations.
do $$
declare
  v_fn text;
begin
  foreach v_fn in array array[
    'private.lesson_meeting_policy(uuid)',
    'private.discipler_eligibility_lesson()',
    'private.credited_count(uuid, uuid)',
    'private.eligible_lesson(uuid)'
  ]
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', v_fn);
    execute format('grant execute on function %s to service_role', v_fn);
  end loop;
end
$$;


-- ============================================================
-- 6. RLS (read-only policies)
-- ============================================================
--
-- SELECT only. There is no client write path: every write goes through
-- a controlled operation. attention_conditions, follow_ups,
-- follow_up_actions, d_group_gatherings and gathering_attendance keep
-- zero policies.

create policy curricula_select_active_members
  on public.curricula for select to authenticated
  using (private.is_active_member_of(church_id));

create policy curriculum_lessons_select_active_members
  on public.curriculum_lessons for select to authenticated
  using (private.can_read_curriculum(curriculum_id));

create policy discipleship_meetings_select_scoped
  on public.discipleship_meetings for select to authenticated
  using (private.can_view_meeting(id));

create policy discipleship_meeting_participants_select_scoped
  on public.discipleship_meeting_participants for select to authenticated
  using (private.can_view_participant(meeting_id, church_membership_id));

create policy disciple_lesson_progress_select_scoped
  on public.disciple_lesson_progress for select to authenticated
  using (private.can_view_progress_of(church_membership_id));


-- ============================================================
-- 7. RECORDING (Slice 5 step 4)
-- ============================================================
--
-- Recording a meeting is the only attendance write path (ADR-014): each
-- Disciple's outcome is stated explicitly. A meeting count never
-- completes a lesson. recompute_lesson_progress() moves a lesson only
-- between NOT_STARTED and IN_PROGRESS, and withdraws a submission that
-- falls below the policy minimum; it never sets READY_FOR_COMPLETION or
-- COMPLETED (DC section 4, COMPLETED Is Protected).

-- The Discipler row of the person's current, active assignment, or NULL.
create function private.current_discipler_row(p_membership_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select a.discipler_d_group_membership_id
  from public.discipler_assignments a
  join public.d_group_memberships dd on dd.id = a.disciple_d_group_membership_id
  join public.d_group_memberships dr on dr.id = a.discipler_d_group_membership_id
  where dd.church_membership_id = p_membership_id
    and dd.ended_at is null
    and a.ended_at is null
    and dr.ended_at is null;
$$;


-- RBAC section 5, recording authority for the pair (caller, person):
-- the person's current assigned Discipler, the Leader of that
-- Discipler's group, or the Coordinator; never the person themself. The
-- person must be ACTIVE, paired, and have a lesson left to record.
create function private.can_record_for(p_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not private.is_my_membership(p_membership_id)
     and private.eligible_lesson(p_membership_id) is not null
     and exists (
       select 1
       from public.church_memberships m
       join public.d_group_memberships dr
         on dr.id = private.current_discipler_row(m.id)
       join public.d_groups g on g.id = dr.d_group_id
       where m.id = p_membership_id
         and m.status = 'ACTIVE'
         and (
           private.owns_d_group_membership(dr.id)
           or private.leads_d_group(dr.d_group_id)
           or private.is_church_coordinator(g.church_id)
         )
     );
$$;


-- Brings one progress row in line with the person's credited meetings
-- for the lesson. Creates the row lazily. Leaves COMPLETED untouched.
-- Returns true when it withdrew a READY_FOR_COMPLETION submission that
-- fell below the policy minimum, so the caller can audit it.
create function private.recompute_lesson_progress(
  p_membership_id uuid,
  p_lesson_id     uuid
)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_row     public.disciple_lesson_progress%rowtype;
  v_first   timestamptz;
  v_count   integer;
  v_minimum integer;
begin
  insert into public.disciple_lesson_progress (church_membership_id, lesson_id)
  values (p_membership_id, p_lesson_id)
  on conflict (church_membership_id, lesson_id) do nothing;

  select * into v_row
  from public.disciple_lesson_progress
  where church_membership_id = p_membership_id
    and lesson_id = p_lesson_id
  for update;

  if v_row.status = 'COMPLETED' then
    return false;
  end if;

  select min(dm.occurred_at), count(*)::integer into v_first, v_count
  from public.discipleship_meeting_participants p
  join public.discipleship_meetings dm on dm.id = p.meeting_id
  where p.church_membership_id = p_membership_id
    and dm.lesson_id = p_lesson_id
    and dm.status = 'RECORDED'
    and p.status = 'RECORDED'
    and p.attendance_status in ('PRESENT', 'LATE');

  select pol.submission_minimum into v_minimum
  from private.lesson_meeting_policy(p_lesson_id) pol;

  if v_row.status = 'READY_FOR_COMPLETION' and v_count >= v_minimum then
    update public.disciple_lesson_progress
    set started_at = v_first
    where id = v_row.id;
    return false;
  end if;

  update public.disciple_lesson_progress
  set status       = case when v_count > 0 then 'IN_PROGRESS'
                          else 'NOT_STARTED' end::public.lesson_progress_status,
      started_at   = v_first,
      ready_at     = null,
      submitted_by = null
  where id = v_row.id;

  return v_row.status = 'READY_FOR_COMPLETION';
end;
$$;


-- record_discipleship_meeting(): one meetup, after the fact, with every
-- Disciple's explicit outcome. p_participants is a JSON array of
-- {"church_membership_id": uuid, "attendance_status": text}.
--
-- Refusals that concern one participant carry that participant in the
-- error detail as JSON, so the client can name them.
create function public.record_discipleship_meeting(
  p_discipler_d_group_membership_id uuid,
  p_lesson_id                       uuid,
  p_occurred_at                     timestamptz,
  p_participants                    jsonb,
  p_notes                           text default null
)
returns table (meeting_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid       uuid := auth.uid();
  v_dr        public.d_group_memberships%rowtype;
  v_church    uuid;
  v_curr      public.curriculum_status;
  v_ids       uuid[];
  v_member    record;
  v_item      jsonb;
  v_meeting   uuid;
  v_pid       uuid;
  v_eligible  uuid;
  v_withdrawn uuid[] := '{}';
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select dgm.* into v_dr
  from public.d_group_memberships dgm
  where dgm.id = p_discipler_d_group_membership_id
    and dgm.responsibility = 'DISCIPLER';

  select g.church_id into v_church
  from public.d_groups g
  where g.id = v_dr.d_group_id;

  if v_dr.id is null
     or not (
       (private.owns_d_group_membership(v_dr.id) and v_dr.ended_at is null)
       or private.leads_d_group(v_dr.d_group_id)
       or private.is_church_coordinator(v_church)
     ) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  if p_occurred_at is null then
    raise exception 'occurred_at_required' using errcode = 'PT400';
  end if;
  if p_occurred_at > now() then
    raise exception 'occurred_at_in_future' using errcode = 'PT409';
  end if;
  if not (v_dr.started_at <= p_occurred_at
          and (v_dr.ended_at is null or v_dr.ended_at > p_occurred_at)) then
    raise exception 'discipler_not_active_at_occurred_at' using errcode = 'PT409';
  end if;

  select c.status into v_curr
  from public.curriculum_lessons l
  join public.curricula c on c.id = l.curriculum_id
  where l.id = p_lesson_id
    and c.church_id = v_church;
  if v_curr is null then
    raise exception 'lesson_not_found' using errcode = 'PT404';
  end if;
  if v_curr <> 'ACTIVE' then
    raise exception 'lesson_not_in_active_curriculum' using errcode = 'PT409';
  end if;

  if p_participants is null
     or jsonb_typeof(p_participants) <> 'array'
     or jsonb_array_length(p_participants) = 0 then
    raise exception 'participants_required' using errcode = 'PT400';
  end if;

  for v_item in select * from jsonb_array_elements(p_participants) loop
    if jsonb_typeof(v_item) <> 'object'
       or coalesce(v_item ->> 'church_membership_id', '') !~
          '^[0-9a-fA-F-]{36}$' then
      raise exception 'participants_required' using errcode = 'PT400';
    end if;
    if coalesce(v_item ->> 'attendance_status', '') not in
       ('PRESENT', 'LATE', 'ABSENT', 'EXCUSED') then
      raise exception 'invalid_attendance_status' using errcode = 'PT400';
    end if;
  end loop;

  select array_agg((e ->> 'church_membership_id')::uuid order by
                   (e ->> 'church_membership_id')::uuid)
    into v_ids
  from jsonb_array_elements(p_participants) e;

  if array_length(v_ids, 1) <> (select count(distinct x) from unnest(v_ids) x) then
    raise exception 'duplicate_participant' using errcode = 'PT400';
  end if;

  -- Lock the participants' memberships in id order, then validate each.
  perform 1
  from public.church_memberships m
  where m.id = any (v_ids)
  order by m.id
  for update;

  foreach v_pid in array v_ids loop
    select m.id, m.church_id, m.status, m.user_id into v_member
    from public.church_memberships m
    where m.id = v_pid;

    -- Unknown and other-church people are refused as not assigned, so
    -- the refusal reveals nothing about them.
    if v_member.id is null or v_member.church_id <> v_church then
      raise exception 'participant_not_assigned_at_occurred_at'
        using errcode = 'PT409',
              detail = jsonb_build_object('church_membership_id', v_pid)::text;
    end if;

    if v_member.user_id = v_uid
       or v_member.id = v_dr.church_membership_id then
      raise exception 'cannot_record_own_meeting'
        using errcode = 'PT409',
              detail = jsonb_build_object('church_membership_id', v_pid)::text;
    end if;

    if v_member.status <> 'ACTIVE' then
      raise exception 'member_not_active'
        using errcode = 'PT409',
              detail = jsonb_build_object('church_membership_id', v_pid)::text;
    end if;

    -- P1 to P3 as of occurred_at (DC section 4, Participant Validity).
    if not exists (
      select 1
      from public.d_group_memberships dd
      join public.discipler_assignments a
        on a.disciple_d_group_membership_id = dd.id
      where dd.church_membership_id = v_pid
        and dd.responsibility = 'DISCIPLE'
        and dd.d_group_id = v_dr.d_group_id
        and dd.started_at <= p_occurred_at
        and (dd.ended_at is null or dd.ended_at > p_occurred_at)
        and a.discipler_d_group_membership_id = v_dr.id
        and a.started_at <= p_occurred_at
        and (a.ended_at is null or a.ended_at > p_occurred_at)
    ) then
      raise exception 'participant_not_assigned_at_occurred_at'
        using errcode = 'PT409',
              detail = jsonb_build_object('church_membership_id', v_pid)::text;
    end if;

    v_eligible := private.eligible_lesson(v_pid);
    if v_eligible is distinct from p_lesson_id then
      raise exception 'lesson_not_eligible'
        using errcode = 'PT409',
              detail = jsonb_build_object(
                'church_membership_id', v_pid,
                'lesson_number', (select l.lesson_number
                                  from public.curriculum_lessons l
                                  where l.id = v_eligible)
              )::text;
    end if;
  end loop;

  insert into public.discipleship_meetings
    (d_group_id, discipler_d_group_membership_id, lesson_id, occurred_at,
     notes, recorded_by)
  values
    (v_dr.d_group_id, v_dr.id, p_lesson_id, p_occurred_at,
     nullif(trim(p_notes), ''), v_uid)
  returning id into v_meeting;

  insert into public.discipleship_meeting_participants
    (meeting_id, church_membership_id, attendance_status)
  select v_meeting,
         (e ->> 'church_membership_id')::uuid,
         (e ->> 'attendance_status')::public.attendance_status
  from jsonb_array_elements(p_participants) e;

  -- Never changes readiness or completion: recompute only starts a
  -- lesson or keeps its start date honest.
  for v_item in select * from jsonb_array_elements(p_participants) loop
    if private.recompute_lesson_progress(
         (v_item ->> 'church_membership_id')::uuid, p_lesson_id) then
      v_withdrawn := v_withdrawn || (v_item ->> 'church_membership_id')::uuid;
    end if;
  end loop;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_church,
    v_uid,
    'DISCIPLESHIP_MEETING_RECORDED',
    'discipleship_meetings',
    v_meeting,
    jsonb_build_object(
      'd_group_id', v_dr.d_group_id,
      'discipler_d_group_membership_id', v_dr.id,
      'lesson_id', p_lesson_id,
      'occurred_at', p_occurred_at,
      'participants', p_participants,
      'on_behalf_of_discipler', not private.owns_d_group_membership(v_dr.id)
    )
  );

  return query select v_meeting;
end;
$$;


-- ============================================================
-- 8. READS FOR RECORDING AND DISCIPLE DETAIL (Slice 5 step 4)
-- ============================================================
--
-- Each read authorizes the pair (caller, person) before it returns
-- anything, and refuses an unknown person the same way as one outside
-- the caller's scope, so a refusal never confirms that a person exists.

-- Who the person is, for the Disciple detail header.
create function public.get_disciple_context(p_membership_id uuid)
returns table (
  church_membership_id uuid,
  full_name            text,
  d_group_name         text,
  discipler_name       text,
  is_paired            boolean
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
  if not private.can_view_progress_of(p_membership_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  return query
  select m.id,
         pr.full_name,
         g.name,
         dpr.full_name,
         dr.id is not null
  from public.church_memberships m
  join public.profiles pr on pr.id = m.user_id
  left join public.d_group_memberships dd
    on dd.id = private.current_disciple_row(m.id)
  left join public.d_groups g on g.id = dd.d_group_id
  left join public.d_group_memberships dr
    on dr.id = private.current_discipler_row(m.id)
  left join public.church_memberships dm on dm.id = dr.church_membership_id
  left join public.profiles dpr on dpr.id = dm.user_id
  where m.id = p_membership_id;
end;
$$;


-- One row per lesson of the ACTIVE curriculum, with the person's state
-- on it. Totals (lessons completed, current lesson) are derived from
-- these rows; only COMPLETED counts as completed. The meeting count is
-- a fact beside the policy values; it decides nothing here. The
-- courtesy flags (can_record, can_complete, can_undo) are for the pair
-- (caller, person); the operations decide again on every call.
create function public.get_disciple_journey(p_membership_id uuid)
returns table (
  lesson_id            uuid,
  lesson_number        integer,
  title                text,
  status               public.lesson_progress_status,
  credited_count       integer,
  submission_minimum   integer,
  recommended_meetings integer,
  started_at           timestamptz,
  ready_at             timestamptz,
  submitted_by_name    text,
  completed_at         timestamptz,
  confirmed_by_name    text,
  is_current           boolean,
  is_locked            boolean,
  can_record           boolean,
  can_complete         boolean,
  can_undo             boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_current    uuid;
  v_can_record boolean;
  v_manage     boolean;
  v_latest     uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;
  if not private.can_view_progress_of(p_membership_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  v_current := private.eligible_lesson(p_membership_id);
  v_can_record := private.can_record_for(p_membership_id);
  v_manage := private.can_manage_progress_of(p_membership_id);
  v_latest := private.latest_completed_lesson(p_membership_id);

  return query
  select l.id,
         l.lesson_number,
         l.title,
         coalesce(p.status, 'NOT_STARTED'::public.lesson_progress_status),
         private.credited_count(p_membership_id, l.id),
         pol.submission_minimum,
         pol.recommended_meetings,
         p.started_at,
         p.ready_at,
         sp.full_name,
         p.completed_at,
         cp.full_name,
         l.id = v_current,
         l.id is distinct from v_current
           and coalesce(p.status::text, 'NOT_STARTED') <> 'COMPLETED',
         v_can_record and l.id = v_current,
         v_manage and l.id = v_current
           and p.status = 'IN_PROGRESS'
           and private.credited_count(p_membership_id, l.id)
               >= pol.submission_minimum,
         v_manage and l.id = v_latest
           and not private.next_lesson_has_meeting(p_membership_id, l.id)
  from public.church_memberships m
  join public.curricula c on c.church_id = m.church_id and c.status = 'ACTIVE'
  join public.curriculum_lessons l on l.curriculum_id = c.id
  cross join lateral private.lesson_meeting_policy(l.id) pol
  left join public.disciple_lesson_progress p
    on p.church_membership_id = m.id and p.lesson_id = l.id
  left join public.profiles sp on sp.id = p.submitted_by
  left join public.profiles cp on cp.id = p.confirmed_by
  where m.id = p_membership_id
  order by l.lesson_number;
end;
$$;


-- The person's meeting history, newest first, limited per row to what
-- the caller may see (RBAC section 5; a Discipler sees meetings under
-- their own row only, O1). Optional bounds on occurred_at serve the
-- monthly view. No "held" or "missed" label exists (ADR-014 decision
-- 8): each row is the recorded outcome.
create function public.get_meeting_history(
  p_membership_id uuid,
  p_from          timestamptz default null,
  p_to            timestamptz default null
)
returns table (
  meeting_id         uuid,
  participant_id     uuid,
  occurred_at        timestamptz,
  lesson_number      integer,
  lesson_title       text,
  meeting_status     public.discipleship_meeting_status,
  participant_status public.meeting_participation_status,
  attendance_status  public.attendance_status,
  is_credited        boolean,
  ordinal            integer,
  recorded_by_name   text,
  notes              text,
  voided_at          timestamptz,
  voided_by_name     text
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
  if not private.can_view_progress_of(p_membership_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  return query
  with rows as (
    select dm.id as meeting_id,
           p.id as participant_id,
           dm.occurred_at,
           l.lesson_number,
           l.title as lesson_title,
           dm.status as meeting_status,
           p.status as participant_status,
           p.attendance_status,
           (dm.status = 'RECORDED' and p.status = 'RECORDED'
            and p.attendance_status in ('PRESENT', 'LATE')) as is_credited,
           dm.lesson_id,
           dm.recorded_by,
           dm.notes,
           coalesce(dm.voided_at, p.voided_at) as voided_at,
           coalesce(dm.voided_by, p.voided_by) as voided_by
    from public.discipleship_meeting_participants p
    join public.discipleship_meetings dm on dm.id = p.meeting_id
    join public.curriculum_lessons l on l.id = dm.lesson_id
    where p.church_membership_id = p_membership_id
  ),
  numbered as (
    select r.*,
           case when r.is_credited then
             row_number() over (
               partition by r.lesson_id, r.is_credited
               order by r.occurred_at, r.meeting_id
             )::integer
           end as ordinal
    from rows r
  )
  select n.meeting_id, n.participant_id, n.occurred_at, n.lesson_number,
         n.lesson_title, n.meeting_status, n.participant_status,
         n.attendance_status, n.is_credited, n.ordinal, rp.full_name,
         n.notes, n.voided_at, vp.full_name
  from numbered n
  left join public.profiles rp on rp.id = n.recorded_by
  left join public.profiles vp on vp.id = n.voided_by
  where private.can_view_participant(n.meeting_id, p_membership_id)
    and (p_from is null or n.occurred_at >= p_from)
    and (p_to is null or n.occurred_at < p_to)
  order by n.occurred_at desc, n.meeting_id desc;
end;
$$;


-- The caller's own currently assigned Disciples, one row each (N7: a
-- Discipler's scope). Factual figures only. last_recorded_meeting_at is
-- the latest RECORDED meeting with a RECORDED row for the person,
-- whatever the outcome (user decision of 2026-10-05, section S6).
create function public.list_disciple_progress()
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
  order by pr.full_name;
end;
$$;


-- Everything Record a meeting needs for the person: their current
-- Discipler row, and every Disciple currently assigned to that row with
-- their current lesson, so Disciples on the same lesson can be recorded
-- together and the rest are shown as on another lesson. Refused unless
-- the caller may record for the person.
create function public.get_recording_options(p_membership_id uuid)
returns table (
  church_membership_id            uuid,
  full_name                       text,
  is_target                       boolean,
  lesson_id                       uuid,
  lesson_number                   integer,
  lesson_title                    text,
  paired_since                    timestamptz,
  discipler_d_group_membership_id uuid,
  discipler_name                  text,
  discipler_since                 timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_dr uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;
  if not private.can_record_for(p_membership_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  v_dr := private.current_discipler_row(p_membership_id);

  return query
  select m.id,
         pr.full_name,
         m.id = p_membership_id,
         l.id,
         l.lesson_number,
         l.title,
         greatest(dd.started_at, a.started_at),
         dr.id,
         dpr.full_name,
         dr.started_at
  from public.discipler_assignments a
  join public.d_group_memberships dr on dr.id = a.discipler_d_group_membership_id
  join public.church_memberships drm on drm.id = dr.church_membership_id
  join public.profiles dpr on dpr.id = drm.user_id
  join public.d_group_memberships dd
    on dd.id = a.disciple_d_group_membership_id and dd.ended_at is null
  join public.church_memberships m on m.id = dd.church_membership_id
  join public.profiles pr on pr.id = m.user_id
  join public.curriculum_lessons l on l.id = private.eligible_lesson(m.id)
  where a.discipler_d_group_membership_id = v_dr
    and a.ended_at is null
    and m.status = 'ACTIVE'
    and not private.is_my_membership(m.id)
  order by m.id <> p_membership_id, pr.full_name;
end;
$$;


do $$
declare
  v_fn text;
begin
  foreach v_fn in array array[
    'public.record_discipleship_meeting(uuid, uuid, timestamptz, jsonb, text)',
    'public.get_disciple_context(uuid)',
    'public.get_disciple_journey(uuid)',
    'public.get_meeting_history(uuid, timestamptz, timestamptz)',
    'public.list_disciple_progress()',
    'public.get_recording_options(uuid)'
  ]
  loop
    execute format('revoke execute on function %s from public, anon', v_fn);
    execute format('grant execute on function %s to authenticated', v_fn);
  end loop;

  foreach v_fn in array array[
    'private.current_discipler_row(uuid)',
    'private.can_record_for(uuid)',
    'private.recompute_lesson_progress(uuid, uuid)'
  ]
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', v_fn);
    execute format('grant execute on function %s to service_role', v_fn);
  end loop;
end
$$;


-- ============================================================
-- 9. JOURNEY AND HOME READS (Slice 5 step 5)
-- ============================================================

-- DC section 11, Meeting Facts and Consecutive Recorded Absences, for one
-- person. Counts and dates only; no ratio or percentage (decision 8).
--
-- last_recorded_meeting_at is the latest RECORDED row in a RECORDED
-- meeting, whatever the outcome (decision S6). The consecutive count
-- walks only meetings under the person's current discipler assignment,
-- newest first, and stops at the first PRESENT, LATE or EXCUSED; with no
-- current assignment it is 0. It is a fact; no condition is raised here
-- (ADR-014, monitoring is Slice 9).
create function public.get_disciple_meeting_summary(p_membership_id uuid)
returns table (
  meetings_attended             integer,
  recorded_absences             integer,
  excused                       integer,
  last_recorded_meeting_at      timestamptz,
  consecutive_recorded_absences integer
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
  if not private.can_view_progress_of(p_membership_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  return query
  with recorded as (
    select dm.id, dm.occurred_at, dm.discipler_d_group_membership_id,
           p.attendance_status
    from public.discipleship_meeting_participants p
    join public.discipleship_meetings dm on dm.id = p.meeting_id
    where p.church_membership_id = p_membership_id
      and p.status = 'RECORDED'
      and dm.status = 'RECORDED'
  ),
  assignment as (
    select a.discipler_d_group_membership_id, a.started_at
    from public.discipler_assignments a
    join public.d_group_memberships dd on dd.id = a.disciple_d_group_membership_id
    where dd.church_membership_id = p_membership_id
      and dd.ended_at is null
      and a.ended_at is null
  ),
  streak as (
    select r.attendance_status,
           row_number() over (order by r.occurred_at desc, r.id desc) as rn
    from recorded r
    join assignment a
      on a.discipler_d_group_membership_id = r.discipler_d_group_membership_id
     and r.occurred_at >= a.started_at
  )
  select
    (select count(*)::integer from recorded
     where attendance_status in ('PRESENT', 'LATE')),
    (select count(*)::integer from recorded where attendance_status = 'ABSENT'),
    (select count(*)::integer from recorded where attendance_status = 'EXCUSED'),
    (select max(occurred_at) from recorded),
    coalesce(
      (select min(rn)::integer - 1 from streak
       where attendance_status <> 'ABSENT'),
      (select count(*)::integer from streak)
    );
end;
$$;


-- Figures for Home, each over records the caller may already read (RBAC
-- section 2b). active_discipleships (DC section 11): the church-wide
-- count, for the Coordinator only; NULL for everyone else.
create function public.get_progress_summary()
returns table (
  active_discipleships integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_church uuid;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select me.church_id into v_church
  from public.church_memberships me
  where me.user_id = v_uid
    and private.is_church_coordinator(me.church_id);

  return query
  select
    case when v_church is not null then
      (select count(*)::integer
       from public.discipler_assignments a
       join public.d_groups g on g.id = a.d_group_id
       join public.d_group_memberships dd
         on dd.id = a.disciple_d_group_membership_id
        and dd.responsibility = 'DISCIPLE'
        and dd.ended_at is null
       join public.church_memberships dm
         on dm.id = dd.church_membership_id and dm.status = 'ACTIVE'
       where g.church_id = v_church
         and a.started_at <= now()
         and a.ended_at is null)
    end;
end;
$$;

do $$
declare
  v_fn text;
begin
  foreach v_fn in array array[
    'public.get_disciple_meeting_summary(uuid)',
    'public.get_progress_summary()'
  ]
  loop
    execute format('revoke execute on function %s from public, anon', v_fn);
    execute format('grant execute on function %s to authenticated', v_fn);
  end loop;
end
$$;


-- ============================================================
-- 10. LESSON COMPLETION (ADR-015)
-- ============================================================
--
-- The Discipler marks the current lesson completed in one explicit step;
-- the next lesson opens for every role at once. There is no Leader
-- confirmation. The existing columns are reused, so the Progress State
-- Check is unchanged: completed_at and ready_at are the moment it was
-- marked, confirmed_by and submitted_by the person who marked it.
-- READY_FOR_COMPLETION is no longer entered.
--
-- A completion can be undone by the same people while it is the latest
-- completed lesson and nothing has been recorded on the next lesson.
-- After that, only the Coordinator can reopen (reopen_lesson_completion,
-- a later step). A meeting count never completes a lesson: marking it
-- completed is a judgement, gated only by the meeting policy's minimum
-- (still the placeholder floor until N1 is decided).

-- Progress authority for the pair (caller, person): the person's
-- current assigned Discipler, the Leader of the person's current group,
-- or the Coordinator; never the person themself. Unlike recording, the
-- Leader and Coordinator need no current pairing.
create function private.can_manage_progress_of(p_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not private.is_my_membership(p_membership_id)
     and exists (
       select 1
       from public.church_memberships m
       where m.id = p_membership_id
         and m.status = 'ACTIVE'
         and (
           private.is_assigned_discipler_of(m.id)
           or private.leads_current_group_of_disciple(m.id)
           or private.is_church_coordinator(m.church_id)
         )
     );
$$;


-- The person's highest-numbered COMPLETED lesson in the ACTIVE
-- curriculum, or NULL.
create function private.latest_completed_lesson(p_membership_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select l.id
  from public.church_memberships m
  join public.curricula c on c.church_id = m.church_id and c.status = 'ACTIVE'
  join public.curriculum_lessons l on l.curriculum_id = c.id
  join public.disciple_lesson_progress p
    on p.church_membership_id = m.id and p.lesson_id = l.id
  where m.id = p_membership_id
    and p.status = 'COMPLETED'
  order by l.lesson_number desc
  limit 1;
$$;


-- Whether any meeting, whatever the outcome, has been recorded for the
-- person on the lesson after p_lesson_id: a RECORDED row in a RECORDED
-- meeting. It closes the undo window.
create function private.next_lesson_has_meeting(
  p_membership_id uuid,
  p_lesson_id     uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.curriculum_lessons cur
    join public.curriculum_lessons nxt
      on nxt.curriculum_id = cur.curriculum_id
     and nxt.lesson_number = cur.lesson_number + 1
    join public.discipleship_meetings dm
      on dm.lesson_id = nxt.id and dm.status = 'RECORDED'
    join public.discipleship_meeting_participants p
      on p.meeting_id = dm.id and p.status = 'RECORDED'
    where cur.id = p_lesson_id
      and p.church_membership_id = p_membership_id
  );
$$;


-- complete_lesson(): "Mark Lesson n completed". Returns the next lesson,
-- or NULL when the curriculum is finished.
create function public.complete_lesson(
  p_membership_id uuid,
  p_lesson_id     uuid
)
returns table (lesson_id uuid, next_lesson_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := auth.uid();
  v_church   uuid;
  v_progress public.disciple_lesson_progress%rowtype;
  v_number   integer;
  v_count    integer;
  v_minimum  integer;
  v_next     uuid;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;
  if private.is_my_membership(p_membership_id) then
    raise exception 'cannot_act_on_own_lesson' using errcode = 'PT409';
  end if;
  if not private.can_manage_progress_of(p_membership_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  select m.church_id into v_church
  from public.church_memberships m
  where m.id = p_membership_id
  for update;

  select l.lesson_number into v_number
  from public.curriculum_lessons l
  join public.curricula c on c.id = l.curriculum_id
  where l.id = p_lesson_id and c.church_id = v_church and c.status = 'ACTIVE';
  if v_number is null then
    raise exception 'lesson_not_found' using errcode = 'PT404';
  end if;

  if private.eligible_lesson(p_membership_id) is distinct from p_lesson_id then
    raise exception 'lesson_not_eligible'
      using errcode = 'PT409',
            detail = jsonb_build_object(
              'church_membership_id', p_membership_id,
              'lesson_number', (select l.lesson_number
                                from public.curriculum_lessons l
                                where l.id = private.eligible_lesson(p_membership_id))
            )::text;
  end if;

  select * into v_progress
  from public.disciple_lesson_progress p
  where p.church_membership_id = p_membership_id
    and p.lesson_id = p_lesson_id
  for update;
  if v_progress.status is distinct from 'IN_PROGRESS' then
    raise exception 'lesson_not_in_progress'
      using errcode = 'PT409',
            detail = jsonb_build_object('lesson_number', v_number)::text;
  end if;

  v_count := private.credited_count(p_membership_id, p_lesson_id);
  select pol.submission_minimum into v_minimum
  from private.lesson_meeting_policy(p_lesson_id) pol;
  if v_count < v_minimum then
    raise exception 'below_submission_minimum'
      using errcode = 'PT409',
            detail = jsonb_build_object(
              'lesson_number', v_number,
              'minimum', v_minimum,
              'count', v_count
            )::text;
  end if;

  update public.disciple_lesson_progress
  set status       = 'COMPLETED',
      ready_at     = now(),
      submitted_by = v_uid,
      completed_at = now(),
      confirmed_by = v_uid
  where id = v_progress.id;

  select l.id into v_next
  from public.curriculum_lessons cur
  join public.curriculum_lessons l
    on l.curriculum_id = cur.curriculum_id
   and l.lesson_number = cur.lesson_number + 1
  where cur.id = p_lesson_id;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_church,
    v_uid,
    'LESSON_COMPLETED',
    'disciple_lesson_progress',
    v_progress.id,
    jsonb_build_object(
      'church_membership_id', p_membership_id,
      'lesson_id', p_lesson_id,
      'lesson_number', v_number,
      'credited_meetings', v_count,
      'on_behalf_of_discipler', not private.is_assigned_discipler_of(p_membership_id)
    )
  );

  return query select p_lesson_id, v_next;
end;
$$;


-- undo_lesson_completion(): within the undo window only. Returns the
-- lesson to IN_PROGRESS (NOT_STARTED when it has no credited meeting),
-- clears the completion and audits the prior values.
--
-- From Slice 6, the eligibility-lesson protection for an appointed
-- person (ADR-012 decision 9) applies here as well as to reopening.
-- No appointment exists before Slice 6, so it is not checked yet.
create function public.undo_lesson_completion(
  p_membership_id uuid,
  p_lesson_id     uuid
)
returns table (lesson_id uuid, status public.lesson_progress_status)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := auth.uid();
  v_church   uuid;
  v_progress public.disciple_lesson_progress%rowtype;
  v_number   integer;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;
  if private.is_my_membership(p_membership_id) then
    raise exception 'cannot_act_on_own_lesson' using errcode = 'PT409';
  end if;
  if not private.can_manage_progress_of(p_membership_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  select m.church_id into v_church
  from public.church_memberships m
  where m.id = p_membership_id
  for update;

  select l.lesson_number into v_number
  from public.curriculum_lessons l
  join public.curricula c on c.id = l.curriculum_id
  where l.id = p_lesson_id and c.church_id = v_church and c.status = 'ACTIVE';
  if v_number is null then
    raise exception 'lesson_not_found' using errcode = 'PT404';
  end if;

  select * into v_progress
  from public.disciple_lesson_progress p
  where p.church_membership_id = p_membership_id
    and p.lesson_id = p_lesson_id
  for update;
  if v_progress.status is distinct from 'COMPLETED' then
    raise exception 'lesson_not_completed'
      using errcode = 'PT409',
            detail = jsonb_build_object('lesson_number', v_number)::text;
  end if;

  if private.latest_completed_lesson(p_membership_id) <> p_lesson_id then
    raise exception 'later_lesson_completed'
      using errcode = 'PT409',
            detail = jsonb_build_object('lesson_number', v_number)::text;
  end if;

  if private.next_lesson_has_meeting(p_membership_id, p_lesson_id) then
    raise exception 'next_lesson_started'
      using errcode = 'PT409',
            detail = jsonb_build_object('lesson_number', v_number)::text;
  end if;

  update public.disciple_lesson_progress
  set status       = 'IN_PROGRESS',
      ready_at     = null,
      submitted_by = null,
      completed_at = null,
      confirmed_by = null
  where id = v_progress.id;

  -- Brings the status and start date in line with credited meetings.
  perform private.recompute_lesson_progress(p_membership_id, p_lesson_id);

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_church,
    v_uid,
    'LESSON_COMPLETION_UNDONE',
    'disciple_lesson_progress',
    v_progress.id,
    jsonb_build_object(
      'church_membership_id', p_membership_id,
      'lesson_id', p_lesson_id,
      'lesson_number', v_number,
      'prior_completed_at', v_progress.completed_at,
      'prior_completed_by', v_progress.confirmed_by
    )
  );

  return query
  select p.lesson_id, p.status
  from public.disciple_lesson_progress p
  where p.id = v_progress.id;
end;
$$;


do $$
declare
  v_fn text;
begin
  foreach v_fn in array array[
    'public.complete_lesson(uuid, uuid)',
    'public.undo_lesson_completion(uuid, uuid)'
  ]
  loop
    execute format('revoke execute on function %s from public, anon', v_fn);
    execute format('grant execute on function %s to authenticated', v_fn);
  end loop;

  foreach v_fn in array array[
    'private.can_manage_progress_of(uuid)',
    'private.latest_completed_lesson(uuid)',
    'private.next_lesson_has_meeting(uuid, uuid)'
  ]
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', v_fn);
    execute format('grant execute on function %s to service_role', v_fn);
  end loop;
end
$$;


-- ============================================================
-- 11. CURRICULUM OF TEN LESSONS (user decision, 2026-10-05)
-- ============================================================
--
-- The ministry's curriculum has ten lessons, not twelve. Migration 004
-- (applied, immutable) seeds twelve and asserts twelve, so both
-- functions are replaced here with the count changed and nothing else.
-- Nothing else in the database or the app encodes a lesson total: every
-- total comes from the ACTIVE curriculum's rows (BR-036). The Discipler
-- eligibility lesson stays 5 (private.discipler_eligibility_lesson()).

create or replace function private.assert_bootstrap_postconditions(
  p_church_id uuid,
  p_initial_user_id uuid
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_join_code text;
  v_membership_id uuid;
begin
  select c.join_code into v_join_code
  from public.churches c
  where c.id = p_church_id and c.status = 'ACTIVE';

  if v_join_code is null then
    raise exception 'bootstrap: no ACTIVE church with id %', p_church_id;
  end if;

  if v_join_code !~ '^[A-HJ-NP-Z2-9]{10}$' then
    raise exception 'bootstrap: join_code does not meet the format/entropy rule';
  end if;

  if not exists (
    select 1 from public.church_settings s
    where s.church_id = p_church_id
      and s.consecutive_absence_threshold = 3
      and s.consecutive_missed_meeting_threshold = 3
      and s.follow_up_due_days = 7
  ) then
    raise exception 'bootstrap: church_settings missing or not at the DC section 0 defaults';
  end if;

  select m.id into v_membership_id
  from public.church_memberships m
  where m.church_id = p_church_id
    and m.user_id = p_initial_user_id
    and m.status = 'ACTIVE';

  if v_membership_id is null then
    raise exception 'bootstrap: initial user % has no ACTIVE membership', p_initial_user_id;
  end if;

  if (
    select count(distinct r.role)
    from public.church_role_assignments r
    where r.church_membership_id = v_membership_id
      and r.ended_at is null
      and r.role in ('ADMIN', 'COORDINATOR')
  ) <> 2 then
    raise exception 'bootstrap: initial user must hold active ADMIN and COORDINATOR roles';
  end if;

  if (
    select count(*) from public.curricula cu
    where cu.church_id = p_church_id and cu.status = 'ACTIVE'
  ) <> 1 then
    raise exception 'bootstrap: exactly one ACTIVE curriculum is required';
  end if;

  if (
    select count(*)
    from public.curriculum_lessons l
    join public.curricula cu on cu.id = l.curriculum_id
    where cu.church_id = p_church_id
      and cu.status = 'ACTIVE'
      and l.lesson_number between 1 and 10
      and l.required_meetings = 4
  ) <> 10 then
    raise exception 'bootstrap: ten lessons numbered 1 to 10 with required_meetings = 4 are required';
  end if;
end;
$$;

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

  -- 3. church_memberships
  insert into public.church_memberships (church_id, user_id, status, joined_at)
  values (p_church_id, p_initial_user_id, 'ACTIVE', now())
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

-- Existing churches: remove Lessons 11 and 12 from ACTIVE curricula, but
-- only when nothing refers to them. If a meeting or a progress row does,
-- this migration stops rather than delete history (AGENTS.md).
do $$
begin
  if exists (
    select 1
    from public.curriculum_lessons l
    join public.curricula c on c.id = l.curriculum_id and c.status = 'ACTIVE'
    where l.lesson_number > 10
      and (
        exists (select 1 from public.discipleship_meetings dm where dm.lesson_id = l.id)
        or exists (select 1 from public.disciple_lesson_progress p where p.lesson_id = l.id)
      )
  ) then
    raise exception 'curriculum: lessons 11 and 12 are referenced by meetings or progress; resolve by hand before reducing the curriculum to ten lessons';
  end if;

  delete from public.curriculum_lessons l
  using public.curricula c
  where c.id = l.curriculum_id
    and c.status = 'ACTIVE'
    and l.lesson_number > 10;
end
$$;
