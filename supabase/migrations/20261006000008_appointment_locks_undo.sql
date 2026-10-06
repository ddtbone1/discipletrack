-- ============================================================
-- DiscipleTrack - Migration 015: appointment locks undo of the
-- eligibility lesson (Slice 6.3)
-- ============================================================
--
-- User decision 2026-10-06 (Slice 6): once a person has been appointed
-- as a Discipler (a ministry_role_transitions row to DISCIPLER, written
-- only by appoint_discipler()), the eligibility lesson and earlier
-- lessons can no longer be undone. This extends ADR-012 decision 9,
-- which protects the same lessons from reopening, to undo, as the
-- Slice 5 comment on this function anticipated. Without it, an undo
-- inside the undo window could leave an appointed Discipler whose
-- eligibility lesson is no longer completed.
--
-- Initial rollout recognition (discipler_basis INITIAL_ROLLOUT) writes no
-- transition row, so it does not lock anything: those Disciplers were
-- not appointed on the strength of their lessons.
--
-- The function is replaced with one added precondition, raised with
-- the same reason reopen uses: eligibility_lesson_protected (PT409).
-- Everything else is Migration 007's body, unchanged.
--
-- Migrations 001 to 014 are not modified.
-- ============================================================

create or replace function public.undo_lesson_completion(
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

  -- Slice 6: an appointed person's eligibility lesson and earlier lessons
  -- are locked (ADR-012 decision 9, extended to undo).
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


-- The journey offers Undo only where undo_lesson_completion() would
-- accept it, so an appointed person's locked lessons show no Undo.
-- Migration 011's body with that one condition added.
create or replace function public.get_disciple_journey(p_membership_id uuid)
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
  v_appointed  boolean;
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
  v_appointed := exists (
    select 1
    from public.ministry_role_transitions t
    where t.church_membership_id = p_membership_id
      and t.to_responsibility = 'DISCIPLER'
  );

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
           and not (v_appointed
                    and l.lesson_number <= private.discipler_eligibility_lesson())
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
