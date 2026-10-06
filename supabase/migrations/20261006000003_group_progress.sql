-- ============================================================
-- DiscipleTrack - Migration 010: Group members' progress
-- ============================================================
--
-- Vertical Slice 5, step 8 (plan section J): the Members section of
-- D Group detail for the group's Leader and the Coordinator.
--
-- list_group_progress(p_d_group_id): one row per current Disciple of the
-- group, with the same factual figures as list_disciple_progress()
-- (Migration 007), plus the Disciple's current Discipler (NULL when
-- unpaired). Authority (RBAC "View progress"): the Leader of that group,
-- or a Coordinator of its church. A Discipler is refused even for their
-- own group: they see only their own currently assigned Disciples,
-- through list_disciple_progress() (N7, Slice 5 decision 13).
--
-- Derived figures only (lessons completed, credited count, last recorded
-- meeting, recorded absences); nothing is stored (AGENTS: no derived
-- values as sources of truth).
--
-- RPC reasons: PT401 authentication_required; PT403 not_authorized (also
-- for a group in another church or one that does not exist, so its
-- existence is not revealed).


create function public.list_group_progress(p_d_group_id uuid)
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

  if not exists (
    select 1
    from public.d_groups g
    where g.id = p_d_group_id
      and (private.leads_d_group(g.id)
           or private.is_church_coordinator(g.church_id))
  ) then
    raise exception 'not_authorized' using errcode = 'PT403';
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
         private.is_assigned_discipler_of(m.id)
  from public.d_group_memberships dd
  join public.church_memberships m on m.id = dd.church_membership_id
  join public.profiles pr on pr.id = m.user_id
  left join public.discipler_assignments a
    on a.disciple_d_group_membership_id = dd.id and a.ended_at is null
  left join public.d_group_memberships dr
    on dr.id = a.discipler_d_group_membership_id
  left join public.church_memberships me on me.id = dr.church_membership_id
  left join public.profiles dpr on dpr.id = me.user_id
  left join public.curriculum_lessons cl on cl.id = private.eligible_lesson(m.id)
  left join public.disciple_lesson_progress cp
    on cp.church_membership_id = m.id and cp.lesson_id = cl.id
  where dd.d_group_id = p_d_group_id
    and dd.responsibility = 'DISCIPLE'
    and dd.ended_at is null
  order by pr.full_name;
end;
$$;


do $$
begin
  execute 'revoke execute on function public.list_group_progress(uuid) from public, anon';
  execute 'grant execute on function public.list_group_progress(uuid) to authenticated';
end
$$;
