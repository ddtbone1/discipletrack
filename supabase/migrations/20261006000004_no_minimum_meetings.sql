-- ============================================================
-- DiscipleTrack - Migration 011: No minimum meetings (N1 resolved)
-- ============================================================
--
-- ADR-017 (2026-10-06, user decision): meeting count does not determine
-- lesson completion. The authorized Discipler decides when the Disciple
-- has completed the lesson, based on the actual discipleship process.
-- Outcomes and counts stay factual history; they are never a progression
-- gate. A lesson never completes because of a count, and is never kept
-- from completion because of one.
--
-- Supersedes in Migration 007 (applied, not edited):
--   - private.lesson_meeting_policy(), the PLACEHOLDER floor
--     (submission_minimum 1, recommended_meetings NULL): dropped
--   - complete_lesson(): no count precondition; the eligible lesson may be
--     completed from NOT_STARTED as well as IN_PROGRESS. Refusals
--     below_submission_minimum and lesson_not_in_progress are no longer
--     raised
--   - recompute_lesson_progress(): no minimum; it still never touches
--     COMPLETED and never sets READY_FOR_COMPLETION or COMPLETED. The
--     dormant READY_FOR_COMPLETION auto-withdrawal is gone: with no
--     minimum, no count is ever "below" one
--   - get_disciple_journey(): the columns submission_minimum and
--     recommended_meetings are removed; can_complete is the caller's
--     authority on the current lesson, with no count condition
-- Supersedes in Migration 008 (applied, not edited):
--   - private.assert_void_keeps_completed() and the refusal
--     lesson_completed_protected: dropped. The invariant is now that a
--     void never changes a COMPLETED lesson, which recomputation already
--     guarantees; no count has to be preserved
--   - void_discipleship_meeting(), void_meeting_participant(): replaced
--     without that check; authority, refusal order, audit unchanged
--
-- Progress State Check (Migration 007, unchanged) requires started_at for
-- COMPLETED. started_at is the first credited meeting; a lesson completed
-- with no credited meeting gets started_at = completed_at (it was taken up
-- no later than it was completed). Undo and reopen recompute it as before.
--
-- Unchanged: authorization (assigned Discipler; Leader and Coordinator as
-- fallback; never one's own lesson), the undo window and the ADR-016 locks
-- (later_lesson_completed, next_lesson_started, later_lesson_has_meetings,
-- eligibility_lesson_protected), audit actions. required_meetings stays
-- unread by any function or client.


-- ============================================================
-- 1. RECOMPUTATION WITHOUT A MINIMUM
-- ============================================================

-- Brings one progress row in line with the person's credited meetings
-- for the lesson. Creates the row lazily. Leaves COMPLETED untouched.
-- A row found in READY_FOR_COMPLETION (dormant; nothing enters it) keeps
-- its state and only its start date is refreshed. Returns false: there is
-- no minimum to fall below, so nothing is ever withdrawn.
create or replace function private.recompute_lesson_progress(
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
  v_row   public.disciple_lesson_progress%rowtype;
  v_first timestamptz;
  v_count integer;
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

  if v_row.status = 'READY_FOR_COMPLETION' then
    update public.disciple_lesson_progress
    set started_at = coalesce(v_first, v_row.started_at)
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

  return false;
end;
$$;


-- ============================================================
-- 2. COMPLETION WITHOUT A COUNT PRECONDITION
-- ============================================================

-- complete_lesson(): "Mark Lesson n completed". The Discipler's explicit
-- judgement; no meeting count is required. Returns the next lesson, or
-- NULL when the curriculum is finished.
create or replace function public.complete_lesson(
  p_membership_id uuid,
  p_lesson_id     uuid
)
returns table (lesson_id uuid, next_lesson_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
-- The output column lesson_id must not shadow the table column in the
-- ON CONFLICT target below.
#variable_conflict use_column
declare
  v_uid      uuid := auth.uid();
  v_church   uuid;
  v_progress public.disciple_lesson_progress%rowtype;
  v_number   integer;
  v_count    integer;
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

  -- Only the current lesson, which is never COMPLETED.
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

  insert into public.disciple_lesson_progress (church_membership_id, lesson_id)
  values (p_membership_id, p_lesson_id)
  on conflict (church_membership_id, lesson_id) do nothing;

  select * into v_progress
  from public.disciple_lesson_progress p
  where p.church_membership_id = p_membership_id
    and p.lesson_id = p_lesson_id
  for update;

  -- Factual, for the audit row only; not a precondition.
  v_count := private.credited_count(p_membership_id, p_lesson_id);

  update public.disciple_lesson_progress
  set status       = 'COMPLETED',
      started_at   = coalesce(started_at, now()),
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


-- ============================================================
-- 3. JOURNEY WITHOUT POLICY COLUMNS
-- ============================================================

drop function public.get_disciple_journey(uuid);

create function public.get_disciple_journey(p_membership_id uuid)
returns table (
  lesson_id         uuid,
  lesson_number     integer,
  title             text,
  status            public.lesson_progress_status,
  credited_count    integer,
  started_at        timestamptz,
  ready_at          timestamptz,
  submitted_by_name text,
  completed_at      timestamptz,
  confirmed_by_name text,
  is_current        boolean,
  is_locked         boolean,
  can_record        boolean,
  can_complete      boolean,
  can_undo          boolean
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
         p.started_at,
         p.ready_at,
         sp.full_name,
         p.completed_at,
         cp.full_name,
         l.id = v_current,
         l.id is distinct from v_current
           and coalesce(p.status::text, 'NOT_STARTED') <> 'COMPLETED',
         v_can_record and l.id = v_current,
         -- No count condition (ADR-017): the caller's authority on the
         -- current lesson.
         v_manage and l.id = v_current,
         v_manage and l.id = v_latest
           and not private.next_lesson_has_meeting(p_membership_id, l.id)
  from public.church_memberships m
  join public.curricula c on c.church_id = m.church_id and c.status = 'ACTIVE'
  join public.curriculum_lessons l on l.curriculum_id = c.id
  left join public.disciple_lesson_progress p
    on p.church_membership_id = m.id and p.lesson_id = l.id
  left join public.profiles sp on sp.id = p.submitted_by
  left join public.profiles cp on cp.id = p.confirmed_by
  where m.id = p_membership_id
  order by l.lesson_number;
end;
$$;


-- ============================================================
-- 4. VOIDS WITHOUT A COUNT-BASED PROTECTION
-- ============================================================

-- As in Migration 008, minus assert_void_keeps_completed(): a void never
-- changes a COMPLETED lesson because recompute_lesson_progress() leaves
-- COMPLETED untouched, so nothing has to be refused to protect it.
create or replace function public.void_discipleship_meeting(p_meeting_id uuid)
returns table (meeting_id uuid, voided_at timestamptz)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid       uuid := (select auth.uid());
  v_meeting   public.discipleship_meetings%rowtype;
  v_church    uuid;
  v_number    integer;
  v_person    uuid;
  v_credited  uuid[];
  v_now       timestamptz := now();
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  if not exists (
       select 1 from public.discipleship_meetings dm where dm.id = p_meeting_id
     )
     or not private.can_view_meeting(p_meeting_id) then
    raise exception 'meeting_not_found' using errcode = 'PT404';
  end if;

  if private.is_meeting_participant(p_meeting_id) then
    raise exception 'cannot_void_own_meeting' using errcode = 'PT409';
  end if;

  if not private.can_void_meeting(p_meeting_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  perform 1
  from public.church_memberships m
  where m.id in (
    select p.church_membership_id
    from public.discipleship_meeting_participants p
    where p.meeting_id = p_meeting_id
  )
  order by m.id
  for update;

  select * into v_meeting
  from public.discipleship_meetings dm
  where dm.id = p_meeting_id
  for update;

  if v_meeting.status <> 'RECORDED' then
    raise exception 'meeting_not_recorded' using errcode = 'PT409';
  end if;

  select coalesce(array_agg(p.church_membership_id order by p.church_membership_id), '{}')
  into v_credited
  from public.discipleship_meeting_participants p
  where p.meeting_id = p_meeting_id
    and p.status = 'RECORDED'
    and p.attendance_status in ('PRESENT', 'LATE');

  update public.discipleship_meetings dm
  set status    = 'VOIDED',
      voided_by = v_uid,
      voided_at = v_now
  where dm.id = p_meeting_id;

  -- COMPLETED rows are left as they are by recomputation.
  foreach v_person in array v_credited loop
    perform private.recompute_lesson_progress(v_person, v_meeting.lesson_id);
  end loop;

  select g.church_id into v_church
  from public.d_groups g
  where g.id = v_meeting.d_group_id;

  select l.lesson_number into v_number
  from public.curriculum_lessons l
  where l.id = v_meeting.lesson_id;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_church,
    v_uid,
    'DISCIPLESHIP_MEETING_VOIDED',
    'discipleship_meetings',
    p_meeting_id,
    jsonb_build_object(
      'd_group_id', v_meeting.d_group_id,
      'lesson_id', v_meeting.lesson_id,
      'lesson_number', v_number,
      'occurred_at', v_meeting.occurred_at,
      'recorded_by', v_meeting.recorded_by,
      'participants', (
        select coalesce(jsonb_agg(jsonb_build_object(
                 'church_membership_id', p.church_membership_id,
                 'attendance_status', p.attendance_status,
                 'participant_status', p.status
               ) order by p.church_membership_id), '[]'::jsonb)
        from public.discipleship_meeting_participants p
        where p.meeting_id = p_meeting_id
      ),
      'credited_membership_ids', to_jsonb(v_credited)
    )
  );

  return query select p_meeting_id, v_now;
end;
$$;


create or replace function public.void_meeting_participant(p_participant_id uuid)
returns table (participant_id uuid, voided_at timestamptz)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid       uuid := (select auth.uid());
  v_row       public.discipleship_meeting_participants%rowtype;
  v_meeting   public.discipleship_meetings%rowtype;
  v_church    uuid;
  v_number    integer;
  v_credited  boolean;
  v_now       timestamptz := now();
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select * into v_row
  from public.discipleship_meeting_participants p
  where p.id = p_participant_id;

  if not found
     or not private.can_view_participant(v_row.meeting_id,
                                         v_row.church_membership_id) then
    raise exception 'participant_not_found' using errcode = 'PT404';
  end if;

  if private.is_my_membership(v_row.church_membership_id) then
    raise exception 'cannot_void_own_meeting' using errcode = 'PT409';
  end if;

  if not private.can_void_meeting(v_row.meeting_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  perform 1
  from public.church_memberships m
  where m.id = v_row.church_membership_id
  for update;

  select * into v_meeting
  from public.discipleship_meetings dm
  where dm.id = v_row.meeting_id
  for update;

  if v_meeting.status <> 'RECORDED' then
    raise exception 'meeting_not_recorded' using errcode = 'PT409';
  end if;

  select * into v_row
  from public.discipleship_meeting_participants p
  where p.id = p_participant_id
  for update;

  if v_row.status <> 'RECORDED' then
    raise exception 'participant_not_recorded' using errcode = 'PT409';
  end if;

  if not exists (
    select 1
    from public.discipleship_meeting_participants p
    where p.meeting_id = v_row.meeting_id
      and p.status = 'RECORDED'
      and p.id <> v_row.id
  ) then
    raise exception 'void_meeting_instead' using errcode = 'PT409';
  end if;

  v_credited := v_row.attendance_status in ('PRESENT', 'LATE');

  update public.discipleship_meeting_participants p
  set status    = 'VOIDED',
      voided_by = v_uid,
      voided_at = v_now
  where p.id = p_participant_id;

  -- COMPLETED rows are left as they are by recomputation.
  if v_credited then
    perform private.recompute_lesson_progress(
      v_row.church_membership_id, v_meeting.lesson_id);
  end if;

  select g.church_id into v_church
  from public.d_groups g
  where g.id = v_meeting.d_group_id;

  select l.lesson_number into v_number
  from public.curriculum_lessons l
  where l.id = v_meeting.lesson_id;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_church,
    v_uid,
    'MEETING_PARTICIPANT_VOIDED',
    'discipleship_meeting_participants',
    p_participant_id,
    jsonb_build_object(
      'meeting_id', v_meeting.id,
      'd_group_id', v_meeting.d_group_id,
      'lesson_id', v_meeting.lesson_id,
      'lesson_number', v_number,
      'church_membership_id', v_row.church_membership_id,
      'attendance_status', v_row.attendance_status,
      'was_credited', v_credited
    )
  );

  return query select p_participant_id, v_now;
end;
$$;


-- ============================================================
-- 5. DROP THE PLACEHOLDER POLICY AND THE PROTECTION
-- ============================================================

drop function private.assert_void_keeps_completed(uuid, uuid);
drop function private.lesson_meeting_policy(uuid);


-- ============================================================
-- 6. GRANTS
-- ============================================================

do $$
begin
  execute 'revoke execute on function public.get_disciple_journey(uuid) from public, anon';
  execute 'grant execute on function public.get_disciple_journey(uuid) to authenticated';
end
$$;
