-- ============================================================
-- DiscipleTrack - Migration 009: Reopen lesson completion
-- ============================================================
--
-- Vertical Slice 5, step 7 (ADR-015 decision 6; DC section 4,
-- "reopen_lesson_completion()"; RBAC "Reopen lesson completion":
-- COORDINATOR only). Completes the lesson-completion lifecycle under
-- ADR-015: complete_lesson() and undo_lesson_completion() are in
-- Migration 007. There is no Discipler-submit / Leader-confirm step.
--
-- Preconditions, in this order (DC section 4):
--   - the caller is not the person (RBAC: no caller reopens their own
--     lesson): cannot_act_on_own_lesson
--   1. the caller is a COORDINATOR in the person's church: not_authorized
--   - the lesson is in the church's ACTIVE curriculum: lesson_not_found
--   2. the progress row is COMPLETED: lesson_not_completed
--   3. no later lesson is COMPLETED (later_lesson_completed) and no later
--      lesson has a RECORDED participant row for the person in a RECORDED
--      meeting, whatever the outcome (later_lesson_has_meetings). A later
--      meeting or a later completed lesson locks the earlier lesson.
--      Reopening never moves, voids or deletes later history.
--   4. an appointed person (a ministry_role_transitions row to DISCIPLER)
--      cannot have the eligibility lesson or an earlier lesson reopened
--      (ADR-012 decision 9): eligibility_lesson_protected
--
-- Effect: IN_PROGRESS, or NOT_STARTED when no credited participation
-- remains (never READY_FOR_COMPLETION); ready_at, submitted_by,
-- completed_at and confirmed_by cleared; started_at kept. Audited as
-- LESSON_COMPLETION_REOPENED with the prior values, so the original
-- completion stays recoverable.
--
-- Refusal details are JSON: lesson_number, and for
-- later_lesson_completed / later_lesson_has_meetings the later lesson's
-- number (later_lesson_number), so the client can state the lock.


-- Whether any lesson after p_lesson_id in its curriculum has a RECORDED
-- participant row for the person in a RECORDED meeting. Returns the
-- lowest such lesson number, or NULL.
create function private.first_later_lesson_with_meeting(
  p_membership_id uuid,
  p_lesson_id     uuid
)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select min(later.lesson_number)
  from public.curriculum_lessons cur
  join public.curriculum_lessons later
    on later.curriculum_id = cur.curriculum_id
   and later.lesson_number > cur.lesson_number
  join public.discipleship_meetings dm
    on dm.lesson_id = later.id and dm.status = 'RECORDED'
  join public.discipleship_meeting_participants p
    on p.meeting_id = dm.id and p.status = 'RECORDED'
  where cur.id = p_lesson_id
    and p.church_membership_id = p_membership_id;
$$;


create function public.reopen_lesson_completion(
  p_membership_id uuid,
  p_lesson_id     uuid
)
returns table (lesson_id uuid, status public.lesson_progress_status)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid       uuid := (select auth.uid());
  v_church    uuid;
  v_number    integer;
  v_progress  public.disciple_lesson_progress%rowtype;
  v_later     integer;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;
  if private.is_my_membership(p_membership_id) then
    raise exception 'cannot_act_on_own_lesson' using errcode = 'PT409';
  end if;

  select m.church_id into v_church
  from public.church_memberships m
  where m.id = p_membership_id;

  if v_church is null or not private.is_church_coordinator(v_church) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  -- Same lock order as recording, completion and voids.
  perform 1
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

  select min(l.lesson_number) into v_later
  from public.curriculum_lessons l
  join public.disciple_lesson_progress p
    on p.lesson_id = l.id and p.church_membership_id = p_membership_id
  where l.curriculum_id = (select cl.curriculum_id
                           from public.curriculum_lessons cl
                           where cl.id = p_lesson_id)
    and l.lesson_number > v_number
    and p.status = 'COMPLETED';
  if v_later is not null then
    raise exception 'later_lesson_completed'
      using errcode = 'PT409',
            detail = jsonb_build_object(
              'lesson_number', v_number,
              'later_lesson_number', v_later
            )::text;
  end if;

  v_later := private.first_later_lesson_with_meeting(p_membership_id, p_lesson_id);
  if v_later is not null then
    raise exception 'later_lesson_has_meetings'
      using errcode = 'PT409',
            detail = jsonb_build_object(
              'lesson_number', v_number,
              'later_lesson_number', v_later
            )::text;
  end if;

  if v_number <= private.discipler_eligibility_lesson()
     and exists (
       select 1
       from public.ministry_role_transitions t
       where t.church_membership_id = p_membership_id
         and t.to_responsibility = 'DISCIPLER'
     ) then
    raise exception 'eligibility_lesson_protected'
      using errcode = 'PT409',
            detail = jsonb_build_object(
              'lesson_number', v_number,
              'eligibility_lesson_number', private.discipler_eligibility_lesson()
            )::text;
  end if;

  update public.disciple_lesson_progress
  set status       = 'IN_PROGRESS',
      ready_at     = null,
      submitted_by = null,
      completed_at = null,
      confirmed_by = null
  where id = v_progress.id;

  -- IN_PROGRESS, or NOT_STARTED when no credited participation remains.
  perform private.recompute_lesson_progress(p_membership_id, p_lesson_id);

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_church,
    v_uid,
    'LESSON_COMPLETION_REOPENED',
    'disciple_lesson_progress',
    v_progress.id,
    jsonb_build_object(
      'church_membership_id', p_membership_id,
      'lesson_id', p_lesson_id,
      'lesson_number', v_number,
      'prior_ready_at', v_progress.ready_at,
      'prior_submitted_by', v_progress.submitted_by,
      'prior_completed_at', v_progress.completed_at,
      'prior_confirmed_by', v_progress.confirmed_by
    )
  );

  return query
  select p.lesson_id, p.status
  from public.disciple_lesson_progress p
  where p.id = v_progress.id;
end;
$$;


do $$
begin
  execute 'revoke execute on function public.reopen_lesson_completion(uuid, uuid) from public, anon';
  execute 'grant execute on function public.reopen_lesson_completion(uuid, uuid) to authenticated';
  execute 'revoke execute on function private.first_later_lesson_with_meeting(uuid, uuid) from public, anon, authenticated';
  execute 'grant execute on function private.first_later_lesson_with_meeting(uuid, uuid) to service_role';
end
$$;
