-- ============================================================
-- DiscipleTrack - Migration 023: platform roles, ADMIN retired,
--                                the Coordinator invariant
-- ============================================================
--
-- Slice 8 (ADR-022). Scope:
--   1. platform_role, platform_roles, private.is_super_admin(), and
--      the service-role grant and end functions (decision 4)
--   2. church ADMIN retired: every active row ended and audited, then
--      a CHECK keeps an active one from existing (decision 2)
--   3. approval Coordinator-only: is_church_admin_or_coordinator()
--      now checks COORDINATOR (decision 3)
--   4. one church per person: UNIQUE church_memberships(user_id)
--      (decision 9, an intentional MVP limitation)
--   5. the Coordinator invariant: an ACTIVE church has an active
--      Coordinator at every commit, by deferred constraint triggers
--      that lock the church row before counting (decisions 11, 12)
--   6. church status transitions (decision 13)
--   7. bootstrap grants COORDINATOR only, with its postconditions
--
-- Steps 4 and 5 first verify the existing data and stop, changing
-- nothing, if it does not already satisfy them.
--
-- Applied migrations are not modified.
--
-- References:
--   ADR-022, DATABASE_CONSTRAINTS.md sections 0 and 1,
--   RBAC_RLS_MATRIX.md sections 1, 3 (platform_roles) and 10
-- ============================================================


-- ============================================================
-- 1. PLATFORM ROLES
-- ============================================================

create type public.platform_role as enum ('SUPER_ADMIN');

create table public.platform_roles (
  id          uuid                 not null default gen_random_uuid(),
  user_id     uuid                 not null,
  role        public.platform_role not null,
  granted_by  uuid,
  started_at  timestamptz          not null default now(),
  ended_at    timestamptz,
  ended_by    uuid,
  created_at  timestamptz          not null default now(),

  constraint platform_roles_pkey primary key (id),
  constraint platform_roles_user_id_fkey foreign key (user_id)
    references public.profiles (id) on delete no action,
  constraint platform_roles_granted_by_fkey foreign key (granted_by)
    references public.profiles (id) on delete no action,
  constraint platform_roles_ended_by_fkey foreign key (ended_by)
    references public.profiles (id) on delete no action,
  constraint platform_roles_period_check
    check (ended_at is null or ended_at > started_at)
);

comment on table public.platform_roles is
  'Platform-level roles (ADR-022), independent of church membership. Written only by private.grant_platform_role() / private.end_platform_role() (service_role). A person reads their own rows only.';

create unique index platform_roles_active_uidx
  on public.platform_roles (user_id, role)
  where ended_at is null;

alter table public.platform_roles enable row level security;
revoke all on table public.platform_roles from public, anon, authenticated;
grant select on table public.platform_roles to authenticated;

create policy platform_roles_select_own
  on public.platform_roles
  for select
  to authenticated
  using (user_id = (select auth.uid()));


-- Reads the table only, for the caller. Never a JWT claim, profile
-- field, user metadata or parameter (ADR-022 decision 4).
create function private.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.platform_roles r
    where r.user_id = (select auth.uid())
      and r.role = 'SUPER_ADMIN'
      and r.ended_at is null
  );
$$;

comment on function private.is_super_admin() is
  'True when the caller holds an active SUPER_ADMIN platform role. ADR-022.';

revoke execute on function private.is_super_admin() from public, anon;
grant execute on function private.is_super_admin() to authenticated, service_role;


-- Trusted tooling only (tool/grant_super_admin.ps1, supabase/seed.sql).
-- Idempotent while an active row exists. The audit actor is the
-- granting Super Admin, or the grantee when tooling grants it, as
-- bootstrap records its founder.
create function private.grant_platform_role(
  p_user_id    uuid,
  p_role       public.platform_role default 'SUPER_ADMIN',
  p_granted_by uuid default null
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if p_user_id is null
     or not exists (select 1 from public.profiles p where p.id = p_user_id) then
    raise exception 'grant_platform_role: no profile for user %', p_user_id;
  end if;

  select r.id into v_id
  from public.platform_roles r
  where r.user_id = p_user_id and r.role = p_role and r.ended_at is null;

  if v_id is not null then
    return v_id;
  end if;

  insert into public.platform_roles (user_id, role, granted_by, started_at)
  values (p_user_id, p_role, p_granted_by, now())
  returning id into v_id;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    null,
    coalesce(p_granted_by, p_user_id),
    'PLATFORM_ROLE_GRANTED',
    'platform_roles',
    v_id,
    jsonb_build_object(
      'user_id', p_user_id,
      'role', p_role,
      'source', case when p_granted_by is null then 'tooling' else 'super_admin' end
    )
  );

  return v_id;
end;
$$;

create function private.end_platform_role(
  p_user_id  uuid,
  p_role     public.platform_role default 'SUPER_ADMIN',
  p_ended_by uuid default null
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  update public.platform_roles r
  set ended_at = greatest(now(), r.started_at + interval '1 millisecond'),
      ended_by = p_ended_by
  where r.user_id = p_user_id and r.role = p_role and r.ended_at is null
  returning r.id into v_id;

  if v_id is null then
    return null;
  end if;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    null,
    coalesce(p_ended_by, p_user_id),
    'PLATFORM_ROLE_ENDED',
    'platform_roles',
    v_id,
    jsonb_build_object(
      'user_id', p_user_id,
      'role', p_role,
      'source', case when p_ended_by is null then 'tooling' else 'super_admin' end
    )
  );

  return v_id;
end;
$$;

revoke execute on function private.grant_platform_role(uuid, public.platform_role, uuid)
  from public, anon, authenticated;
grant execute on function private.grant_platform_role(uuid, public.platform_role, uuid)
  to service_role;
revoke execute on function private.end_platform_role(uuid, public.platform_role, uuid)
  from public, anon, authenticated;
grant execute on function private.end_platform_role(uuid, public.platform_role, uuid)
  to service_role;


-- ============================================================
-- 2. CHURCH ADMIN RETIRED
-- ============================================================
--
-- Every active ADMIN row is ended, never deleted, with one
-- CHURCH_ROLE_ENDED event each. The actor is the row's assigned_by, as
-- the Migration 018 backfill recorded its rows. A person who held
-- ADMIN without COORDINATOR is reported for an operator to review.

do $$
declare
  v_row record;
begin
  for v_row in
    select m.church_id, m.user_id, r.id
    from public.church_role_assignments r
    join public.church_memberships m on m.id = r.church_membership_id
    where r.role = 'ADMIN'
      and r.ended_at is null
      and not exists (
        select 1 from public.church_role_assignments c
        where c.church_membership_id = r.church_membership_id
          and c.role = 'COORDINATOR'
          and c.ended_at is null
      )
  loop
    raise notice 'ADMIN retired without COORDINATOR: user % in church % (role row %)',
      v_row.user_id, v_row.church_id, v_row.id;
  end loop;
end
$$;

with ended as (
  update public.church_role_assignments r
  set ended_at = greatest(now(), r.started_at + interval '1 millisecond')
  where r.role = 'ADMIN'
    and r.ended_at is null
  returning r.id, r.church_membership_id, r.assigned_by
)
insert into public.audit_events
  (church_id, actor_user_id, action, entity_type, entity_id, metadata)
select m.church_id,
       e.assigned_by,
       'CHURCH_ROLE_ENDED',
       'church_role_assignments',
       e.id,
       jsonb_build_object(
         'role', 'ADMIN',
         'reason', 'admin_retired',
         'church_membership_id', e.church_membership_id,
         'also_coordinator', exists (
           select 1 from public.church_role_assignments c
           where c.church_membership_id = e.church_membership_id
             and c.role = 'COORDINATOR'
             and c.ended_at is null
         )
       )
from ended e
join public.church_memberships m on m.id = e.church_membership_id;

alter table public.church_role_assignments
  add constraint church_role_assignments_admin_retired
  check (role <> 'ADMIN' or ended_at is not null);


-- ============================================================
-- 3. APPROVAL IS THE COORDINATOR'S
-- ============================================================
--
-- The name is kept so every caller (approve, reject, the membership
-- and profile read policies) stays correct; the body now checks
-- COORDINATOR only. Migration 026 adds the church status condition.

create or replace function private.is_church_admin_or_coordinator(p_church_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_church_coordinator(p_church_id);
$$;

comment on function private.is_church_admin_or_coordinator(uuid) is
  'COORDINATOR only since ADR-022 (the church ADMIN role is retired). Name kept for its callers.';


-- ============================================================
-- 4. ONE CHURCH PER PERSON
-- ============================================================
--
-- An intentional MVP limitation (ADR-022 decision 9). Lifting it later
-- is a forward migration that drops this key, plus app support for
-- choosing a church.

do $$
declare
  v_user uuid;
begin
  select m.user_id into v_user
  from public.church_memberships m
  group by m.user_id
  having count(distinct m.church_id) > 1
  limit 1;

  if v_user is not null then
    raise exception 'one church per person: user % holds memberships in more than one church; resolve before applying this migration', v_user;
  end if;
end
$$;

alter table public.church_memberships
  add constraint church_memberships_user_key unique (user_id);


-- ============================================================
-- 5. THE COORDINATOR INVARIANT
-- ============================================================
--
-- An active Coordinator is an active COORDINATOR row on an ACTIVE
-- membership of the church. An ACTIVE church has one at every commit.
--
-- The check:
--   - is DEFERRABLE INITIALLY DEFERRED, so a church and its Coordinator
--     can be written in either order inside one transaction;
--   - re-reads the church's current state, never the firing row's
--     values;
--   - checks every affected church (old and new);
--   - locks the church row FOR UPDATE before counting, so two
--     transactions that each end one of two Coordinators cannot both
--     commit (write skew): the second waits, then its next statement
--     sees the first's commit.

create function private.church_has_active_coordinator(p_church_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.church_role_assignments r
    join public.church_memberships m on m.id = r.church_membership_id
    where m.church_id = p_church_id
      and m.status = 'ACTIVE'
      and r.role = 'COORDINATOR'
      and r.ended_at is null
  );
$$;

revoke execute on function private.church_has_active_coordinator(uuid)
  from public, anon, authenticated;
grant execute on function private.church_has_active_coordinator(uuid) to service_role;


create function private.assert_church_coordinator(p_church_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_status public.church_status;
begin
  if p_church_id is null then
    return;
  end if;

  select c.status into v_status
  from public.churches c
  where c.id = p_church_id
  for update;

  if v_status = 'ACTIVE' and not private.church_has_active_coordinator(p_church_id) then
    raise exception 'church_requires_coordinator'
      using errcode = '23514',
            detail = 'An ACTIVE church has at least one active Coordinator (ADR-022 decision 11).';
  end if;
end;
$$;

revoke execute on function private.assert_church_coordinator(uuid)
  from public, anon, authenticated;


create function private.check_coordinator_on_church()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.assert_church_coordinator(new.id);
  return null;
end;
$$;

create function private.check_coordinator_on_role()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_church uuid;
begin
  if tg_op in ('UPDATE', 'DELETE') and old.role = 'COORDINATOR' then
    select m.church_id into v_church
    from public.church_memberships m where m.id = old.church_membership_id;
    perform private.assert_church_coordinator(v_church);
  end if;
  if tg_op in ('INSERT', 'UPDATE') and new.role = 'COORDINATOR' then
    select m.church_id into v_church
    from public.church_memberships m where m.id = new.church_membership_id;
    perform private.assert_church_coordinator(v_church);
  end if;
  return null;
end;
$$;

create function private.check_coordinator_on_membership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.assert_church_coordinator(old.church_id);
  if tg_op = 'UPDATE' and new.church_id is distinct from old.church_id then
    perform private.assert_church_coordinator(new.church_id);
  end if;
  return null;
end;
$$;

do $$
declare
  v_fn text;
begin
  foreach v_fn in array array[
    'private.check_coordinator_on_church()',
    'private.check_coordinator_on_role()',
    'private.check_coordinator_on_membership()'
  ]
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', v_fn);
  end loop;
end
$$;

-- The existing data must already satisfy the invariant.
do $$
declare
  v_church uuid;
begin
  select c.id into v_church
  from public.churches c
  where c.status = 'ACTIVE'
    and not private.church_has_active_coordinator(c.id)
  limit 1;

  if v_church is not null then
    raise exception 'Coordinator invariant: ACTIVE church % has no active Coordinator; assign one before applying this migration', v_church;
  end if;
end
$$;

create constraint trigger churches_coordinator_invariant
  after insert or update of status on public.churches
  deferrable initially deferred
  for each row execute function private.check_coordinator_on_church();

create constraint trigger church_role_assignments_coordinator_invariant
  after insert or update or delete on public.church_role_assignments
  deferrable initially deferred
  for each row execute function private.check_coordinator_on_role();

create constraint trigger church_memberships_coordinator_invariant
  after update of status, church_id or delete on public.church_memberships
  deferrable initially deferred
  for each row execute function private.check_coordinator_on_membership();


-- ============================================================
-- 6. CHURCH STATUS TRANSITIONS
-- ============================================================
--
--   ACTIVE    -> SUSPENDED | ARCHIVED
--   SUSPENDED -> ACTIVE | ARCHIVED
--   ARCHIVED  -> none
--
-- Enforced for every writer, a SECURITY DEFINER function included.

create function private.check_church_status_transition()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status is distinct from old.status
     and (old.status = 'ARCHIVED'
          or (old.status = 'ACTIVE' and new.status not in ('SUSPENDED', 'ARCHIVED'))
          or (old.status = 'SUSPENDED' and new.status not in ('ACTIVE', 'ARCHIVED'))) then
    raise exception 'church_status_transition_not_allowed'
      using errcode = '23514',
            detail = format('%s -> %s is not an allowed church status change (ADR-022 decision 13).',
                            old.status, new.status);
  end if;
  return new;
end;
$$;

revoke execute on function private.check_church_status_transition()
  from public, anon, authenticated;

create trigger churches_status_transition
  before update of status on public.churches
  for each row execute function private.check_church_status_transition();


-- ============================================================
-- 7. BOOTSTRAP GRANTS COORDINATOR ONLY
-- ============================================================

-- As Migration 007, with the role check changed: an active COORDINATOR,
-- no active ADMIN, and no membership in another church.
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

  if not exists (
    select 1 from public.church_role_assignments r
    where r.church_membership_id = v_membership_id
      and r.ended_at is null
      and r.role = 'COORDINATOR'
  ) then
    raise exception 'bootstrap: initial user must hold an active COORDINATOR role';
  end if;

  if exists (
    select 1 from public.church_role_assignments r
    where r.church_membership_id = v_membership_id
      and r.ended_at is null
      and r.role = 'ADMIN'
  ) then
    raise exception 'bootstrap: the retired ADMIN role must not be active (ADR-022)';
  end if;

  if exists (
    select 1 from public.church_memberships m
    where m.user_id = p_initial_user_id and m.church_id <> p_church_id
  ) then
    raise exception 'bootstrap: initial user % belongs to another church', p_initial_user_id;
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

-- As Migration 018, with COORDINATOR as the founder's only role (step 4).
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

  -- 1. churches. The Coordinator invariant is checked at commit, after
  --    step 4 has written the Coordinator.
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

  -- 4. church_role_assignments: COORDINATOR only (ADR-022).
  insert into public.church_role_assignments
    (church_membership_id, role, assigned_by, started_at)
  values
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
