-- ============================================================
-- DiscipleTrack - Migration 008: Meeting voids
-- ============================================================
--
-- Vertical Slice 5, step 6 (docs/plans/slice-5-discipleship-meeting-
-- progress.md, section J). Voiding is the only correction of a recorded
-- meeting: nothing is deleted or edited, the record stays in history as
-- VOIDED and counts for nothing (BR "Recorded meetings and outcomes are
-- not edited"; DC section "Voiding Rules").
--
-- Scope:
--   Helpers (schema private, no API endpoint)
--     - can_void_meeting(): RBAC "Void discipleship meeting or
--       participant": COORDINATOR; LEADER of the meeting's own D Group;
--       DISCIPLER for meetings they recorded themselves under their own
--       still-active DISCIPLER row
--     - is_meeting_participant(): the caller has a row in the meeting
--     - assert_void_keeps_completed(): COMPLETED protection (DC section
--       "COMPLETED Is Protected")
--   Operations
--     - void_discipleship_meeting(): the whole meeting; participant rows
--       are not modified (Slice 5 decision 5, no cascade)
--     - void_meeting_participant(): one person who should not have been
--       listed; the last RECORDED participant is refused
--   Reads
--     - get_meeting_history() replaced to return per-row courtesy flags
--       can_void_meeting and can_void_participant. The client shows void
--       actions only from these; the operations decide again.
--
-- Refusal order, both operations: authentication; existence within the
-- caller's view (no existence leak); the caller's own outcome; authority;
-- record state; last participant; COMPLETED protection.
--
-- RPC reasons (PTxxx SQLSTATE, reason as message):
--   PT401 authentication_required
--   PT403 not_authorized
--   PT404 meeting_not_found / participant_not_found
--   PT409 cannot_void_own_meeting (BR: no person voids their own official
--         meeting outcome, in any role) / meeting_not_recorded /
--         participant_not_recorded / void_meeting_instead /
--         lesson_completed_protected
--
-- lesson_completed_protected carries JSON detail: church_membership_id,
-- full_name, lesson_number, and undo_available (whether the caller can
-- undo that completion right now), so the client words the refusal
-- without deciding anything itself.
--
-- Not in this migration: reasons on voids (Slice 5 decision 11, out of
-- scope); CONSECUTIVE_ABSENCE recalculation (Slice 9, ADR-014).


-- ============================================================
-- 1. HELPERS
-- ============================================================

-- RBAC "Void discipleship meeting or participant". The Discipler branch
-- needs both recorded_by = self and the meeting's DISCIPLER row being the
-- caller's own and still active: owns_d_group_membership() alone does not
-- check that the row has not ended.
create function private.can_void_meeting(p_meeting_id uuid)
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
        or (
          dm.recorded_by = (select auth.uid())
          and exists (
            select 1
            from public.d_group_memberships d
            where d.id = dm.discipler_d_group_membership_id
              and d.responsibility = 'DISCIPLER'
              and d.ended_at is null
              and private.owns_d_group_membership(d.id)
          )
        )
      )
  );
$$;


-- The caller has a participant row in the meeting, whatever its status.
create function private.is_meeting_participant(p_meeting_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.discipleship_meeting_participants p
    where p.meeting_id = p_meeting_id
      and private.is_my_membership(p.church_membership_id)
  );
$$;


-- DC "COMPLETED Is Protected": refuses a void that would leave the
-- person's COMPLETED lesson with fewer credited participations than the
-- policy's submission_minimum. Called only for a credited participation
-- that the void removes. A void never changes a COMPLETED status.
create function private.assert_void_keeps_completed(
  p_membership_id uuid,
  p_lesson_id     uuid
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_status  public.lesson_progress_status;
  v_minimum integer;
  v_number  integer;
  v_name    text;
begin
  select p.status into v_status
  from public.disciple_lesson_progress p
  where p.church_membership_id = p_membership_id
    and p.lesson_id = p_lesson_id;

  if v_status is distinct from 'COMPLETED' then
    return;
  end if;

  select pol.submission_minimum into v_minimum
  from private.lesson_meeting_policy(p_lesson_id) pol;

  if private.credited_count(p_membership_id, p_lesson_id) - 1 >= v_minimum then
    return;
  end if;

  select l.lesson_number into v_number
  from public.curriculum_lessons l
  where l.id = p_lesson_id;

  select pr.full_name into v_name
  from public.church_memberships m
  join public.profiles pr on pr.id = m.user_id
  where m.id = p_membership_id;

  raise exception 'lesson_completed_protected'
    using errcode = 'PT409',
          detail = jsonb_build_object(
            'church_membership_id', p_membership_id,
            'full_name', v_name,
            'lesson_number', v_number,
            'undo_available',
              private.can_manage_progress_of(p_membership_id)
              and private.latest_completed_lesson(p_membership_id)
                  = p_lesson_id
              and not private.next_lesson_has_meeting(
                p_membership_id, p_lesson_id)
          )::text;
end;
$$;


-- ============================================================
-- 2. VOID A MEETING
-- ============================================================

-- void_discipleship_meeting(): the whole meeting becomes VOIDED. Its
-- participant rows are not modified: meeting status alone removes credit
-- (Slice 5 decision 5). Each credited person's lesson progress is then
-- recomputed; COMPLETED is never touched.
create function public.void_discipleship_meeting(p_meeting_id uuid)
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
  v_withdrawn uuid[] := '{}';
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

  -- Same lock order as recording and completion: the people first, then
  -- the meeting, then their progress.
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

  perform 1
  from public.disciple_lesson_progress lp
  where lp.lesson_id = v_meeting.lesson_id
    and lp.church_membership_id = any (v_credited)
  order by lp.church_membership_id
  for update;

  foreach v_person in array v_credited loop
    perform private.assert_void_keeps_completed(v_person, v_meeting.lesson_id);
  end loop;

  update public.discipleship_meetings dm
  set status    = 'VOIDED',
      voided_by = v_uid,
      voided_at = v_now
  where dm.id = p_meeting_id;

  foreach v_person in array v_credited loop
    if private.recompute_lesson_progress(v_person, v_meeting.lesson_id) then
      v_withdrawn := v_withdrawn || v_person;
    end if;
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
      'credited_membership_ids', to_jsonb(v_credited),
      'withdrawn_submissions', to_jsonb(v_withdrawn)
    )
  );

  return query select p_meeting_id, v_now;
end;
$$;


-- ============================================================
-- 3. VOID ONE PARTICIPANT
-- ============================================================

-- void_meeting_participant(): one person who should not have been listed
-- at all. Only that row changes; the meeting and the other participants
-- stay as recorded. The last RECORDED participant is refused, so a
-- RECORDED meeting always keeps at least one (Slice 5 decision 5).
create function public.void_meeting_participant(p_participant_id uuid)
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
  v_withdrawn boolean := false;
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

  if v_credited then
    perform 1
    from public.disciple_lesson_progress lp
    where lp.lesson_id = v_meeting.lesson_id
      and lp.church_membership_id = v_row.church_membership_id
    for update;

    perform private.assert_void_keeps_completed(
      v_row.church_membership_id, v_meeting.lesson_id);
  end if;

  update public.discipleship_meeting_participants p
  set status    = 'VOIDED',
      voided_by = v_uid,
      voided_at = v_now
  where p.id = p_participant_id;

  if v_credited then
    v_withdrawn := private.recompute_lesson_progress(
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
      'was_credited', v_credited,
      'withdrew_submission', v_withdrawn
    )
  );

  return query select p_participant_id, v_now;
end;
$$;


-- ============================================================
-- 4. MEETING HISTORY WITH VOID PERMISSIONS
-- ============================================================

-- get_meeting_history() as in Migration 007, plus two courtesy flags for
-- the caller, computed with the same checks the void operations make
-- before COMPLETED protection:
--   can_void_meeting: meeting RECORDED, caller may void it, and the
--     caller is not one of its participants
--   can_void_participant: as above for the parent, this row RECORDED,
--     not the caller's own, and another RECORDED participant remains
-- The return type changes, so the function is dropped and created again
-- (Migration 007 stays as applied).
drop function public.get_meeting_history(uuid, timestamptz, timestamptz);

create function public.get_meeting_history(
  p_membership_id uuid,
  p_from          timestamptz default null,
  p_to            timestamptz default null
)
returns table (
  meeting_id           uuid,
  participant_id       uuid,
  occurred_at          timestamptz,
  lesson_number        integer,
  lesson_title         text,
  meeting_status       public.discipleship_meeting_status,
  participant_status   public.meeting_participation_status,
  attendance_status    public.attendance_status,
  is_credited          boolean,
  ordinal              integer,
  recorded_by_name     text,
  notes                text,
  voided_at            timestamptz,
  voided_by_name       text,
  can_void_meeting     boolean,
  can_void_participant boolean
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
           end as ordinal,
           (r.meeting_status = 'RECORDED'
            and not private.is_meeting_participant(r.meeting_id)
            and private.can_void_meeting(r.meeting_id)) as meeting_voidable
    from rows r
  )
  select n.meeting_id, n.participant_id, n.occurred_at, n.lesson_number,
         n.lesson_title, n.meeting_status, n.participant_status,
         n.attendance_status, n.is_credited, n.ordinal, rp.full_name,
         n.notes, n.voided_at, vp.full_name,
         n.meeting_voidable,
         (n.participant_status = 'RECORDED'
          and not private.is_my_membership(p_membership_id)
          and n.meeting_status = 'RECORDED'
          and private.can_void_meeting(n.meeting_id)
          and exists (
            select 1
            from public.discipleship_meeting_participants o
            where o.meeting_id = n.meeting_id
              and o.status = 'RECORDED'
              and o.id <> n.participant_id
          ))
  from numbered n
  left join public.profiles rp on rp.id = n.recorded_by
  left join public.profiles vp on vp.id = n.voided_by
  where private.can_view_participant(n.meeting_id, p_membership_id)
    and (p_from is null or n.occurred_at >= p_from)
    and (p_to is null or n.occurred_at < p_to)
  order by n.occurred_at desc, n.meeting_id desc;
end;
$$;


-- ============================================================
-- 5. GRANTS
-- ============================================================

do $$
declare
  v_fn text;
begin
  foreach v_fn in array array[
    'public.void_discipleship_meeting(uuid)',
    'public.void_meeting_participant(uuid)',
    'public.get_meeting_history(uuid, timestamptz, timestamptz)'
  ]
  loop
    execute format('revoke execute on function %s from public, anon', v_fn);
    execute format('grant execute on function %s to authenticated', v_fn);
  end loop;

  foreach v_fn in array array[
    'private.can_void_meeting(uuid)',
    'private.is_meeting_participant(uuid)',
    'private.assert_void_keeps_completed(uuid, uuid)'
  ]
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', v_fn);
    execute format('grant execute on function %s to service_role', v_fn);
  end loop;
end
$$;
