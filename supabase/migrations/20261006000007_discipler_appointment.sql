-- ============================================================
-- DiscipleTrack - Migration 014: Discipler eligibility and
-- appointment (Slice 6.3)
-- ============================================================
--
-- The normal progression path (ADR-012, BR-036, BR-037, DC sections 5
-- and 11): a Disciple whose eligibility lesson (Lesson 5,
-- private.discipler_eligibility_lesson()) of the church's ACTIVE
-- curriculum is COMPLETED is eligible; the Coordinator appoints them.
--
-- Eligibility is derived at read time and never stored; it appoints
-- nobody by itself. Appointment adds a DISCIPLER row with
-- discipler_basis APPOINTMENT in the same D Group and records the
-- appointment in ministry_role_transitions. The DISCIPLE row, the
-- person's own discipler assignment and their lesson progress are not
-- touched, so their own journey continues.
--
-- Slice 6 decisions (ADR-012 open items, defaults accepted 2026-10-06):
--   D5  no appointment before eligibility
--   D8  no appointment once the DISCIPLE row has ended
--   D9  a Coordinator cannot appoint themselves
--
-- Scope:
--   Helpers   private.is_discipler_eligible(), private.eligible_since()
--   Ops       appoint_discipler(), list_discipler_candidates()
--   RLS       ministry_role_transitions read policies
--
-- New error reasons:
--   PT409 cannot_appoint_self / not_an_active_disciple /
--         not_eligible / already_discipler
--
-- Migrations 001 to 013 are not modified.
-- ============================================================


-- ============================================================
-- 1. HELPERS
-- ============================================================

-- DC section 11, Discipler Eligibility. The completion time of the
-- eligibility lesson, or null when the person is not eligible.
create function private.eligible_since(p_membership_id uuid)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select p.completed_at
  from public.church_memberships m
  join public.curricula c
    on c.church_id = m.church_id and c.status = 'ACTIVE'
  join public.curriculum_lessons l
    on l.curriculum_id = c.id
   and l.lesson_number = private.discipler_eligibility_lesson()
  join public.disciple_lesson_progress p
    on p.church_membership_id = m.id and p.lesson_id = l.id
  where m.id = p_membership_id
    and p.status = 'COMPLETED';
$$;

create function private.is_discipler_eligible(p_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.eligible_since(p_membership_id) is not null;
$$;

comment on function private.is_discipler_eligible(uuid) is
  'DC section 11: true when the eligibility lesson of the church''s ACTIVE curriculum is COMPLETED for the person. Derived, never stored; appoints nobody.';

revoke execute on function private.eligible_since(uuid) from public, anon;
revoke execute on function private.is_discipler_eligible(uuid) from public, anon;
grant execute on function private.eligible_since(uuid) to authenticated, service_role;
grant execute on function private.is_discipler_eligible(uuid) to authenticated, service_role;


-- ============================================================
-- 2. CONTROLLED OPERATIONS
-- ============================================================

-- DC section 5, preconditions 1 to 5, plus D5, D8 and D9.
create function public.appoint_discipler(p_membership_id uuid)
returns table (
  d_group_membership_id      uuid,
  ministry_role_transition_id uuid
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := (select auth.uid());
  v_target   public.church_memberships%rowtype;
  v_disciple public.d_group_memberships%rowtype;
  v_group    public.d_groups%rowtype;
  v_since    timestamptz;
  v_dgm      uuid;
  v_mrt      uuid;
  v_now      timestamptz := now();
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select * into v_target
  from public.church_memberships m
  where m.id = p_membership_id;

  -- Precondition 1. Unknown and another church's member are refused
  -- alike, revealing nothing.
  if not found or not private.is_church_coordinator(v_target.church_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  -- D9.
  if v_target.user_id = v_uid then
    raise exception 'cannot_appoint_self' using errcode = 'PT409';
  end if;

  select * into v_target
  from public.church_memberships m
  where m.id = p_membership_id
  for update;

  -- Precondition 2.
  if v_target.status <> 'ACTIVE' then
    raise exception 'member_not_active' using errcode = 'PT409';
  end if;

  -- Precondition 3 and D8.
  select * into v_disciple
  from public.d_group_memberships dgm
  where dgm.church_membership_id = v_target.id
    and dgm.responsibility = 'DISCIPLE'
    and dgm.ended_at is null;

  if not found then
    raise exception 'not_an_active_disciple' using errcode = 'PT409';
  end if;

  select * into v_group
  from public.d_groups g
  where g.id = v_disciple.d_group_id;

  if v_group.status <> 'ACTIVE' then
    raise exception 'd_group_not_active' using errcode = 'PT409';
  end if;

  -- Precondition 5.
  if exists (
    select 1
    from public.d_group_memberships dgm
    where dgm.church_membership_id = v_target.id
      and dgm.responsibility = 'DISCIPLER'
      and dgm.ended_at is null
  ) then
    raise exception 'already_discipler' using errcode = 'PT409';
  end if;

  -- Precondition 4 and D5.
  v_since := private.eligible_since(v_target.id);
  if v_since is null then
    raise exception 'not_eligible' using errcode = 'PT409',
      detail = jsonb_build_object(
        'eligibility_lesson_number', private.discipler_eligibility_lesson()
      )::text;
  end if;

  -- Effect 1: DISCIPLER in the same group (ADR-012 decision 3).
  insert into public.d_group_memberships
    (d_group_id, church_membership_id, responsibility, started_at,
     assigned_by, discipler_basis)
  values
    (v_group.id, v_target.id, 'DISCIPLER', v_now, v_uid, 'APPOINTMENT')
  returning id into v_dgm;

  -- Effect 2: the appointment record.
  insert into public.ministry_role_transitions
    (church_membership_id, d_group_id, from_responsibility,
     to_responsibility, approved_by, approved_at)
  values
    (v_target.id, v_group.id, 'DISCIPLE', 'DISCIPLER', v_uid, v_now)
  returning id into v_mrt;

  -- Effect 3 is an absence: the DISCIPLE row, the person's assignment
  -- and their progress are left as they are (ADR-012 decision 4).

  -- Effect 4.
  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_target.church_id,
    v_uid,
    'DISCIPLER_APPOINTED',
    'ministry_role_transitions',
    v_mrt,
    jsonb_build_object(
      'church_membership_id', v_target.id,
      'd_group_id', v_group.id,
      'd_group_membership_id', v_dgm,
      'eligible_since', v_since,
      'eligibility_lesson_number', private.discipler_eligibility_lesson()
    )
  );

  return query select v_dgm, v_mrt;
end;
$$;

comment on function public.appoint_discipler(uuid) is
  'Coordinator only, never for themselves. Appoints an eligible Disciple (Lesson 5 completed) as a Discipler in their D Group: a DISCIPLER row with discipler_basis APPOINTMENT and a ministry_role_transitions row. Their Disciple journey continues untouched. Audited as DISCIPLER_APPOINTED.';


-- Read-only. Eligible Disciples who are not Disciplers: for one group
-- (its Leader or the Coordinator), or church-wide when p_d_group_id is
-- null (the Coordinator). Eligible is not appointed; the list is what
-- the Coordinator reviews.
create function public.list_discipler_candidates(
  p_d_group_id uuid default null,
  p_church_id  uuid default null
)
returns table (
  church_membership_id uuid,
  full_name            text,
  d_group_id           uuid,
  d_group_name         text,
  eligible_since       timestamptz
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

  if p_d_group_id is not null then
    if not private.can_manage_d_group_members(p_d_group_id) then
      raise exception 'not_authorized' using errcode = 'PT403';
    end if;
  elsif p_church_id is null or not private.is_church_coordinator(p_church_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  else
    v_church := p_church_id;
  end if;

  return query
    select m.id, pr.full_name, g.id, g.name, private.eligible_since(m.id)
    from public.d_group_memberships dd
    join public.d_groups g on g.id = dd.d_group_id
    join public.church_memberships m on m.id = dd.church_membership_id
    join public.profiles pr on pr.id = m.user_id
    where dd.responsibility = 'DISCIPLE'
      and dd.ended_at is null
      and m.status = 'ACTIVE'
      and (p_d_group_id is null or dd.d_group_id = p_d_group_id)
      and (v_church is null or g.church_id = v_church)
      and private.is_discipler_eligible(m.id)
      and not exists (
        select 1
        from public.d_group_memberships dr
        where dr.church_membership_id = m.id
          and dr.responsibility = 'DISCIPLER'
          and dr.ended_at is null
      )
    order by private.eligible_since(m.id), lower(pr.full_name);
end;
$$;

comment on function public.list_discipler_candidates(uuid, uuid) is
  'Eligible Disciples (Lesson 5 completed) who are not Disciplers, with eligible-since. One group for its Leader or the Coordinator; church-wide for the Coordinator.';


do $$
declare
  v_fn text;
begin
  foreach v_fn in array array[
    'public.appoint_discipler(uuid)',
    'public.list_discipler_candidates(uuid, uuid)'
  ]
  loop
    execute format('revoke execute on function %s from public, anon', v_fn);
    execute format('grant execute on function %s to authenticated, service_role', v_fn);
  end loop;
end
$$;


-- ============================================================
-- 3. ROW LEVEL SECURITY
-- ============================================================
--
-- Appointment history (ADR-012 consequences): the Coordinator
-- church-wide, the Leader for their own group, the person their own.
-- Writes only through appoint_discipler() (grants revoked in
-- Migration 006).

create policy ministry_role_transitions_select_manager
  on public.ministry_role_transitions
  for select
  to authenticated
  using (private.can_manage_d_group_members(d_group_id));

create policy ministry_role_transitions_select_own
  on public.ministry_role_transitions
  for select
  to authenticated
  using (private.is_my_membership(church_membership_id));
