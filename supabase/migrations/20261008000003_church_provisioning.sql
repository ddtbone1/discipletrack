-- ============================================================
-- DiscipleTrack - Migration 024: church provisioning
-- ============================================================
--
-- Slice 8 (ADR-022 decisions 5 to 14). Super Admin operations:
--   create_church(), preview_coordinator_account(),
--   assign_church_coordinator(), replace_church_coordinator(),
--   end_church_coordinator(), regenerate_join_code(),
--   set_church_status(), list_churches(), list_platform_audit()
-- The church's Coordinator:
--   get_church_join_code() (decision 10a), read-only
-- And request_join_church() with the IN_ANOTHER_CHURCH outcome
-- (decision 9).
--
-- Every platform operation checks private.is_super_admin() first and
-- raises PT403 before reading anything. Every operation that changes a
-- Coordinator or a church's status locks the church row first, the
-- same lock the Coordinator invariant takes at commit (Migration 023),
-- so concurrent changes serialise and the usable refusal
-- (last_coordinator) is decided on the same view.
--
-- Refusals:
--   PT400 church_name_required
--   PT401 authentication_required
--   PT403 not_authorized, cannot_assign_self
--   PT404 church_not_found, account_not_found, coordinator_not_found
--   PT409 email_not_confirmed, member_of_another_church,
--         already_coordinator, last_coordinator, church_archived,
--         status_unchanged, coordinator_required, join_code_collision
--
-- References:
--   ADR-022, RBAC_RLS_MATRIX.md section 10,
--   DATABASE_CONSTRAINTS.md section 1
-- ============================================================


-- ============================================================
-- 1. HELPERS
-- ============================================================

-- The registered account behind an email, case-insensitively.
create function private.account_by_email(p_email text)
returns table (user_id uuid, full_name text, email text, email_confirmed boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select u.id, p.full_name, u.email::text, u.email_confirmed_at is not null
  from auth.users u
  join public.profiles p on p.id = u.id
  where lower(u.email) = lower(trim(coalesce(p_email, '')))
  limit 1;
$$;

revoke execute on function private.account_by_email(text) from public, anon, authenticated;


-- Raises unless the caller is a Super Admin.
create function private.require_super_admin()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;
  if not private.is_super_admin() then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;
  return v_uid;
end;
$$;

revoke execute on function private.require_super_admin() from public, anon;
grant execute on function private.require_super_admin() to authenticated, service_role;


-- Locks the church row (the Coordinator invariant's lock) and returns
-- its status; raises when there is no such church.
create function private.lock_church(p_church_id uuid)
returns public.church_status
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_status public.church_status;
begin
  select c.status into v_status
  from public.churches c
  where c.id = p_church_id
  for update;

  if v_status is null then
    raise exception 'church_not_found' using errcode = 'PT404';
  end if;
  return v_status;
end;
$$;

revoke execute on function private.lock_church(uuid) from public, anon, authenticated;


-- The account an email names, checked for Coordinator provisioning in
-- p_church_id: registered, confirmed, not the caller, and in no other
-- church (ADR-022 decisions 6, 8, 9).
create function private.coordinator_account(p_church_id uuid, p_email text)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_acc record;
begin
  select * into v_acc from private.account_by_email(p_email);

  if v_acc.user_id is null then
    raise exception 'account_not_found' using errcode = 'PT404';
  end if;
  if not v_acc.email_confirmed then
    raise exception 'email_not_confirmed' using errcode = 'PT409';
  end if;
  if v_acc.user_id = (select auth.uid()) then
    raise exception 'cannot_assign_self' using errcode = 'PT403';
  end if;
  if exists (
    select 1 from public.church_memberships m
    where m.user_id = v_acc.user_id
      and m.church_id is distinct from p_church_id
  ) then
    raise exception 'member_of_another_church' using errcode = 'PT409';
  end if;
  return v_acc.user_id;
end;
$$;

revoke execute on function private.coordinator_account(uuid, text) from public, anon, authenticated;


-- Creates or reactivates the person's membership in the church as
-- ACTIVE with onboarding complete, and grants COORDINATOR. A
-- provisioned membership is not approved, so approved_by and
-- approved_at stay as they were. Returns the membership id and its
-- status before the change (null when created).
create function private.provision_coordinator(
  p_church_id uuid,
  p_user_id   uuid,
  p_actor     uuid
)
returns table (membership_id uuid, prior_status public.membership_status)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_row   public.church_memberships%rowtype;
  v_prior public.membership_status;
begin
  select * into v_row
  from public.church_memberships m
  where m.church_id = p_church_id and m.user_id = p_user_id
  for update;

  if found then
    v_prior := v_row.status;
    if exists (
      select 1 from public.church_role_assignments r
      where r.church_membership_id = v_row.id
        and r.role = 'COORDINATOR'
        and r.ended_at is null
    ) and v_row.status = 'ACTIVE' then
      raise exception 'already_coordinator' using errcode = 'PT409';
    end if;

    update public.church_memberships m
    set status = 'ACTIVE',
        joined_at = coalesce(m.joined_at, now()),
        onboarding_completed_at = coalesce(m.onboarding_completed_at, now())
    where m.id = v_row.id;
  else
    insert into public.church_memberships
      (church_id, user_id, status, joined_at, onboarding_completed_at)
    values (p_church_id, p_user_id, 'ACTIVE', now(), now())
    returning * into v_row;
  end if;

  if not exists (
    select 1 from public.church_role_assignments r
    where r.church_membership_id = v_row.id
      and r.role = 'COORDINATOR'
      and r.ended_at is null
  ) then
    insert into public.church_role_assignments
      (church_membership_id, role, assigned_by, started_at)
    values (v_row.id, 'COORDINATOR', p_actor, now());
  end if;

  return query select v_row.id, v_prior;
end;
$$;

revoke execute on function private.provision_coordinator(uuid, uuid, uuid)
  from public, anon, authenticated;


-- A new code for the church, retried on a unique collision.
create function private.set_new_join_code(p_church_id uuid)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_code text;
begin
  for i in 1..5 loop
    v_code := private.generate_join_code();
    begin
      update public.churches c
      set join_code = v_code, join_code_updated_at = now()
      where c.id = p_church_id;
      return v_code;
    exception when unique_violation then
      null;
    end;
  end loop;
  raise exception 'join_code_collision' using errcode = 'PT409';
end;
$$;

revoke execute on function private.set_new_join_code(uuid) from public, anon, authenticated;


-- ============================================================
-- 2. CREATE A CHURCH WITH ITS COORDINATOR
-- ============================================================
--
-- One transaction: the church (ACTIVE), its settings, its curriculum
-- rows, a generated join code, the Coordinator's ACTIVE onboarded
-- membership and COORDINATOR. The same records and postconditions as
-- bootstrap (DATABASE_CONSTRAINTS.md section 0), checked by the same
-- function. The church row is written first; the Coordinator invariant
-- is checked at commit.

create function public.create_church(p_name text, p_coordinator_email text)
returns table (church_id uuid, join_code text, coordinator_membership_id uuid)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid        uuid := private.require_super_admin();
  v_name       text := trim(coalesce(p_name, ''));
  v_church     uuid := gen_random_uuid();
  v_user       uuid;
  v_code       text;
  v_membership uuid;
  v_curriculum uuid;
begin
  if v_name = '' then
    raise exception 'church_name_required' using errcode = 'PT400';
  end if;

  v_user := private.coordinator_account(null, p_coordinator_email);

  for i in 1..5 loop
    v_code := private.generate_join_code();
    begin
      insert into public.churches (id, name, join_code, join_code_updated_at, status)
      values (v_church, v_name, v_code, now(), 'ACTIVE');
      exit;
    exception when unique_violation then
      if i = 5 then
        raise exception 'join_code_collision' using errcode = 'PT409';
      end if;
    end;
  end loop;

  insert into public.church_settings (
    church_id,
    consecutive_absence_threshold,
    consecutive_missed_meeting_threshold,
    follow_up_due_days
  )
  values (v_church, 3, 3, 7);

  select p.membership_id into v_membership
  from private.provision_coordinator(v_church, v_user, v_uid) p;

  insert into public.curricula (church_id, name, status)
  values (v_church, 'Discipleship Curriculum', 'ACTIVE')
  returning id into v_curriculum;

  insert into public.curriculum_lessons
    (curriculum_id, lesson_number, title, required_meetings)
  select v_curriculum, g, 'Lesson ' || g::text, 4
  from generate_series(1, 10) as g;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values
    (v_church, v_uid, 'CHURCH_CREATED', 'churches', v_church,
     jsonb_build_object('name', v_name, 'curriculum_id', v_curriculum)),
    (v_church, v_uid, 'COORDINATOR_ASSIGNED', 'church_memberships', v_membership,
     jsonb_build_object('user_id', v_user, 'prior_status', null));

  perform private.assert_bootstrap_postconditions(v_church, v_user);

  return query select v_church, v_code, v_membership;
end;
$$;

comment on function public.create_church(text, text) is
  'Super Admin only. Creates an ACTIVE church with its settings, curriculum rows, a generated join code and its Coordinator (a registered, confirmed account in no other church, never the caller), in one transaction. Audited as CHURCH_CREATED and COORDINATOR_ASSIGNED. ADR-022 decision 7.';


-- ============================================================
-- 3. THE CONFIRM STEP
-- ============================================================
--
-- Read-only. Tells the Super Admin whose account an email is, so a
-- mistyped email is caught before anything changes. Nothing else about
-- the person. p_church_id is null when creating a church.

create function public.preview_coordinator_account(p_church_id uuid, p_email text)
returns table (
  account_found     boolean,
  email_confirmed   boolean,
  full_name         text,
  membership        text,
  membership_status public.membership_status,
  is_coordinator    boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_acc record;
  v_m   public.church_memberships%rowtype;
begin
  perform private.require_super_admin();

  select * into v_acc from private.account_by_email(p_email);
  if v_acc.user_id is null then
    return query select false, null::boolean, null::text, null::text,
                        null::public.membership_status, null::boolean;
    return;
  end if;

  select * into v_m
  from public.church_memberships m
  where m.user_id = v_acc.user_id;

  return query select
    true,
    v_acc.email_confirmed,
    v_acc.full_name,
    case
      when v_m.id is null then 'NONE'
      when v_m.church_id = p_church_id then 'THIS_CHURCH'
      else 'OTHER_CHURCH'
    end,
    case when v_m.church_id = p_church_id then v_m.status end,
    case when v_m.church_id = p_church_id then exists (
      select 1 from public.church_role_assignments r
      where r.church_membership_id = v_m.id
        and r.role = 'COORDINATOR' and r.ended_at is null
    ) end;
end;
$$;

comment on function public.preview_coordinator_account(uuid, text) is
  'Super Admin only, read-only: whether a registered, confirmed account has this email, its full name, and whether it belongs to this church, another church or none. ADR-022 decision 8.';


-- ============================================================
-- 4. ASSIGN, REPLACE, END A COORDINATOR
-- ============================================================

create function public.assign_church_coordinator(p_church_id uuid, p_email text)
returns table (membership_id uuid, prior_status public.membership_status)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := private.require_super_admin();
  v_status public.church_status := private.lock_church(p_church_id);
  v_user   uuid;
  v_res    record;
begin
  if v_status = 'ARCHIVED' then
    raise exception 'church_archived' using errcode = 'PT409';
  end if;

  v_user := private.coordinator_account(p_church_id, p_email);
  select * into v_res from private.provision_coordinator(p_church_id, v_user, v_uid);

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    p_church_id, v_uid, 'COORDINATOR_ASSIGNED', 'church_memberships', v_res.membership_id,
    jsonb_build_object('user_id', v_user, 'prior_status', v_res.prior_status)
  );

  return query select v_res.membership_id, v_res.prior_status;
end;
$$;

comment on function public.assign_church_coordinator(uuid, text) is
  'Super Admin only, ACTIVE or SUSPENDED church. Adds a Coordinator by the email of a registered, confirmed account in no other church (never the caller); the membership is created or reactivated ACTIVE with onboarding complete. Audited as COORDINATOR_ASSIGNED.';


create function public.replace_church_coordinator(
  p_church_id             uuid,
  p_current_membership_id uuid,
  p_email                 text
)
returns table (membership_id uuid, prior_status public.membership_status)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := private.require_super_admin();
  v_status  public.church_status := private.lock_church(p_church_id);
  v_role    uuid;
  v_current uuid;
  v_user    uuid;
  v_res     record;
begin
  if v_status = 'ARCHIVED' then
    raise exception 'church_archived' using errcode = 'PT409';
  end if;

  select r.id, m.user_id into v_role, v_current
  from public.church_role_assignments r
  join public.church_memberships m on m.id = r.church_membership_id
  where r.church_membership_id = p_current_membership_id
    and m.church_id = p_church_id
    and r.role = 'COORDINATOR'
    and r.ended_at is null
  for update of r;

  if v_role is null then
    raise exception 'coordinator_not_found' using errcode = 'PT404';
  end if;

  v_user := private.coordinator_account(p_church_id, p_email);
  if v_user = v_current then
    raise exception 'already_coordinator' using errcode = 'PT409';
  end if;

  update public.church_role_assignments r
  set ended_at = greatest(now(), r.started_at + interval '1 millisecond')
  where r.id = v_role;

  select * into v_res from private.provision_coordinator(p_church_id, v_user, v_uid);

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    p_church_id, v_uid, 'COORDINATOR_REPLACED', 'church_memberships', v_res.membership_id,
    jsonb_build_object(
      'from_membership_id', p_current_membership_id,
      'from_user_id', v_current,
      'to_user_id', v_user,
      'prior_status', v_res.prior_status
    )
  );

  return query select v_res.membership_id, v_res.prior_status;
end;
$$;

comment on function public.replace_church_coordinator(uuid, uuid, text) is
  'Super Admin only, ACTIVE or SUSPENDED church. Ends the current Coordinator''s role and grants the new one in one transaction, so the church is never without one. The replaced person stays an ACTIVE member. Audited as COORDINATOR_REPLACED. ADR-022 decision 12.';


create function public.end_church_coordinator(p_church_id uuid, p_membership_id uuid)
returns table (membership_id uuid)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := private.require_super_admin();
  v_status public.church_status := private.lock_church(p_church_id);
  v_role   uuid;
begin
  if v_status = 'ARCHIVED' then
    raise exception 'church_archived' using errcode = 'PT409';
  end if;

  select r.id into v_role
  from public.church_role_assignments r
  join public.church_memberships m on m.id = r.church_membership_id
  where r.church_membership_id = p_membership_id
    and m.church_id = p_church_id
    and r.role = 'COORDINATOR'
    and r.ended_at is null
  for update of r;

  if v_role is null then
    raise exception 'coordinator_not_found' using errcode = 'PT404';
  end if;

  -- Never the last one, ACTIVE or SUSPENDED (ADR-022 decision 12).
  if (
    select count(*)
    from public.church_role_assignments r
    join public.church_memberships m on m.id = r.church_membership_id
    where m.church_id = p_church_id
      and m.status = 'ACTIVE'
      and r.role = 'COORDINATOR'
      and r.ended_at is null
      and r.id <> v_role
  ) = 0 then
    raise exception 'last_coordinator' using errcode = 'PT409';
  end if;

  update public.church_role_assignments r
  set ended_at = greatest(now(), r.started_at + interval '1 millisecond')
  where r.id = v_role;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    p_church_id, v_uid, 'COORDINATOR_ENDED', 'church_memberships', p_membership_id,
    jsonb_build_object('role_id', v_role)
  );

  return query select p_membership_id;
end;
$$;

comment on function public.end_church_coordinator(uuid, uuid) is
  'Super Admin only, ACTIVE or SUSPENDED church. Ends one of several Coordinators; never the last (last_coordinator). Audited as COORDINATOR_ENDED.';


-- ============================================================
-- 5. JOIN CODE AND STATUS
-- ============================================================

create function public.regenerate_join_code(p_church_id uuid)
returns table (join_code text, join_code_updated_at timestamptz)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := private.require_super_admin();
  v_status public.church_status := private.lock_church(p_church_id);
  v_code   text;
begin
  if v_status = 'ARCHIVED' then
    raise exception 'church_archived' using errcode = 'PT409';
  end if;

  v_code := private.set_new_join_code(p_church_id);

  -- No code value in the audit (ADR-022 decision 10).
  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (p_church_id, v_uid, 'JOIN_CODE_REGENERATED', 'churches', p_church_id, '{}'::jsonb);

  return query
    select c.join_code, c.join_code_updated_at
    from public.churches c where c.id = p_church_id;
end;
$$;

comment on function public.regenerate_join_code(uuid) is
  'Super Admin only, ACTIVE or SUSPENDED church. Replaces the join code; the old code stops matching at once and pending requests stay PENDING. Audited as JOIN_CODE_REGENERATED, without the code. ADR-022 decision 10.';


create function public.set_church_status(p_church_id uuid, p_status public.church_status)
returns table (church_id uuid, status public.church_status)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := private.require_super_admin();
  v_status public.church_status := private.lock_church(p_church_id);
begin
  if v_status = 'ARCHIVED' then
    raise exception 'church_archived' using errcode = 'PT409';
  end if;
  if p_status is null or p_status = v_status then
    raise exception 'status_unchanged' using errcode = 'PT409';
  end if;
  if p_status = 'ACTIVE' and not private.church_has_active_coordinator(p_church_id) then
    raise exception 'coordinator_required' using errcode = 'PT409';
  end if;

  -- Writes the status only (ADR-022 decision 14); the transition
  -- trigger and the Coordinator invariant still apply.
  update public.churches c set status = p_status where c.id = p_church_id;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    p_church_id, v_uid, 'CHURCH_STATUS_CHANGED', 'churches', p_church_id,
    jsonb_build_object('from', v_status, 'to', p_status)
  );

  return query select p_church_id, p_status;
end;
$$;

comment on function public.set_church_status(uuid, public.church_status) is
  'Super Admin only. ACTIVE <-> SUSPENDED, ACTIVE or SUSPENDED -> ARCHIVED (final). To ACTIVE requires an active Coordinator. Changes nothing but the status. Audited as CHURCH_STATUS_CHANGED.';


-- ============================================================
-- 6. PLATFORM READS
-- ============================================================

-- Counts and the Coordinators only; no other member and no ministry
-- data (ADR-022 decision 5).
create function public.list_churches()
returns table (
  church_id            uuid,
  name                 text,
  status               public.church_status,
  join_code            text,
  join_code_updated_at timestamptz,
  created_at           timestamptz,
  members_active       integer,
  members_pending      integer,
  members_other        integer,
  d_groups             integer,
  coordinators         jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_super_admin();

  return query
    select c.id, c.name, c.status, c.join_code, c.join_code_updated_at, c.created_at,
           (select count(*)::integer from public.church_memberships m
            where m.church_id = c.id and m.status = 'ACTIVE'),
           (select count(*)::integer from public.church_memberships m
            where m.church_id = c.id and m.status = 'PENDING'),
           (select count(*)::integer from public.church_memberships m
            where m.church_id = c.id and m.status not in ('ACTIVE', 'PENDING')),
           (select count(*)::integer from public.d_groups g
            where g.church_id = c.id and g.status <> 'ARCHIVED'),
           coalesce((
             select jsonb_agg(jsonb_build_object(
                      'membership_id', m.id,
                      'full_name', p.full_name,
                      'email', u.email
                    ) order by p.full_name)
             from public.church_role_assignments r
             join public.church_memberships m on m.id = r.church_membership_id
             join public.profiles p on p.id = m.user_id
             join auth.users u on u.id = m.user_id
             where m.church_id = c.id
               and m.status = 'ACTIVE'
               and r.role = 'COORDINATOR'
               and r.ended_at is null
           ), '[]'::jsonb)
    from public.churches c
    order by c.name;
end;
$$;

comment on function public.list_churches() is
  'Super Admin only: per church its name, status, join code, created date, member counts by status, D Group count, and the active Coordinators'' name and email. Nothing else. ADR-022 decision 5.';


-- Platform events only. The ADMIN retirement events name a member who
-- may not be a Coordinator, so their metadata is reduced to the reason.
create function public.list_platform_audit(
  p_church_id uuid default null,
  p_before    timestamptz default null,
  p_limit     integer default 50
)
returns table (
  event_id    uuid,
  created_at  timestamptz,
  action      text,
  church_id   uuid,
  church_name text,
  actor_name  text,
  metadata    jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_super_admin();

  return query
    select e.id, e.created_at, e.action, e.church_id, c.name, p.full_name,
           case
             when e.action = 'CHURCH_ROLE_ENDED' then jsonb_build_object('reason', e.metadata ->> 'reason')
             else e.metadata
           end
    from public.audit_events e
    left join public.churches c on c.id = e.church_id
    left join public.profiles p on p.id = e.actor_user_id
    where (e.action in (
             'PLATFORM_ROLE_GRANTED', 'PLATFORM_ROLE_ENDED', 'CHURCH_CREATED',
             'JOIN_CODE_REGENERATED', 'COORDINATOR_ASSIGNED', 'COORDINATOR_REPLACED',
             'COORDINATOR_ENDED', 'CHURCH_STATUS_CHANGED')
           or (e.action = 'CHURCH_ROLE_ENDED' and e.metadata ->> 'reason' = 'admin_retired'))
      and (p_church_id is null or e.church_id = p_church_id)
      and (p_before is null or e.created_at < p_before)
    order by e.created_at desc, e.id
    limit least(greatest(coalesce(p_limit, 50), 1), 200);
end;
$$;

comment on function public.list_platform_audit(uuid, timestamptz, integer) is
  'Super Admin only: platform audit events, newest first, paged. Never church ministry events. ADR-022, RBAC section 9.';


-- ============================================================
-- 7. THE COORDINATOR READS THE JOIN CODE
-- ============================================================
--
-- ADR-022 decision 10a. Not a platform operation: only an active
-- Coordinator of that church, on an ACTIVE membership, while the church
-- is ACTIVE. Read-only; no column grant is opened.

create function public.get_church_join_code(p_church_id uuid)
returns table (join_code text, join_code_updated_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  if not private.is_church_coordinator(p_church_id)
     or not exists (
       select 1 from public.churches c
       where c.id = p_church_id and c.status = 'ACTIVE'
     ) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  return query
    select c.join_code, c.join_code_updated_at
    from public.churches c where c.id = p_church_id;
end;
$$;

comment on function public.get_church_join_code(uuid) is
  'The church''s active Coordinator, while the church is ACTIVE: the current join code, read-only. Only the Super Admin generates or regenerates it. ADR-022 decision 10a.';


-- ============================================================
-- 8. JOIN REQUESTS: ONE CHURCH PER PERSON
-- ============================================================

-- As Migration 005, with IN_ANOTHER_CHURCH: the caller already has a
-- membership row in another church (ADR-022 decision 9). Checked after
-- the code, so a wrong code still says only INVALID_CODE.
create or replace function public.request_join_church(p_church_id uuid, p_join_code text)
returns table (
  outcome text,
  membership_id uuid,
  membership_status public.membership_status
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid       uuid := (select auth.uid());
  v_code      text;
  v_church_id uuid;
  v_row       public.church_memberships%rowtype;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  perform private.enforce_join_rate_limit(v_uid, 'REQUEST');

  v_code := private.normalize_join_code(p_join_code);

  select c.id into v_church_id
  from public.churches c
  where c.id = p_church_id
    and c.join_code = v_code
    and c.status = 'ACTIVE';

  if v_church_id is null then
    return query select 'INVALID_CODE'::text, null::uuid, null::public.membership_status;
    return;
  end if;

  select * into v_row
  from public.church_memberships m
  where m.church_id = v_church_id
    and m.user_id = v_uid;

  if found then
    return query select
      case v_row.status
        when 'PENDING' then 'ALREADY_PENDING'
        when 'ACTIVE'  then 'ALREADY_ACTIVE'
        else 'NOT_REQUESTABLE'
      end::text,
      v_row.id,
      v_row.status;
    return;
  end if;

  if exists (select 1 from public.church_memberships m where m.user_id = v_uid) then
    return query select 'IN_ANOTHER_CHURCH'::text, null::uuid, null::public.membership_status;
    return;
  end if;

  insert into public.church_memberships (church_id, user_id, status)
  values (v_church_id, v_uid, 'PENDING')
  returning * into v_row;

  return query select 'REQUESTED'::text, v_row.id, v_row.status;
end;
$$;


-- ============================================================
-- 9. GRANTS
-- ============================================================
--
-- Supabase grants EXECUTE on new public functions to anon by default,
-- so every function revokes from PUBLIC and anon explicitly.

do $$
declare
  v_fn text;
begin
  foreach v_fn in array array[
    'public.create_church(text, text)',
    'public.preview_coordinator_account(uuid, text)',
    'public.assign_church_coordinator(uuid, text)',
    'public.replace_church_coordinator(uuid, uuid, text)',
    'public.end_church_coordinator(uuid, uuid)',
    'public.regenerate_join_code(uuid)',
    'public.set_church_status(uuid, public.church_status)',
    'public.list_churches()',
    'public.list_platform_audit(uuid, timestamptz, integer)',
    'public.get_church_join_code(uuid)'
  ]
  loop
    execute format('revoke execute on function %s from public, anon', v_fn);
    execute format('grant execute on function %s to authenticated, service_role', v_fn);
  end loop;
end
$$;
