-- ============================================================
-- DiscipleTrack - Migration 005: Church Join, Membership Approval,
--                                First Entry
-- ============================================================
--
-- Database logic for the Church Join + Membership Approval + First
-- Entry vertical slice.
--
-- Scope of this migration:
--   Schema
--     - church_memberships.onboarding_completed_at
--     - churches join-code format CHECK
--     - private.join_code_attempts (rate-limit state)
--   Helpers (schema private, no API endpoint)
--     - normalize_join_code(), enforce_join_rate_limit()
--     - is_church_admin_or_coordinator(), can_view_profile_as_church_admin()
--   Controlled operations (schema public, RPC)
--     - lookup_church_by_join_code()
--     - request_join_church()
--     - approve_church_membership()
--     - reject_church_membership()
--     - complete_onboarding()
--   RLS
--     - churches: column-level SELECT (join_code never client-readable)
--       and own-church visibility for PENDING and ACTIVE members
--     - church_memberships: ADMIN / COORDINATOR own-church read scope
--     - profiles: ADMIN / COORDINATOR own-church read scope
--     - church_role_assignments: own roles
--
-- Error convention for RPCs: guessable failures (a wrong join code)
-- are RETURNED as results, never raised, so the rate-limit attempt
-- row written in the same transaction commits. Genuine faults use
-- PostgREST status SQLSTATEs so the client can branch on the code:
--
--   PT401 authentication_required
--   PT403 not_authorized / cannot_approve_self
--   PT404 membership_not_found
--   PT409 membership_not_pending / no_active_membership
--   PT429 rate_limited
--
-- Every new function revokes EXECUTE from PUBLIC and anon
-- explicitly. Supabase's default privileges grant EXECUTE on new
-- public functions to anon, authenticated and service_role, so
-- revoking from PUBLIC alone would not be enough.
--
-- Migrations 001 to 004 are not modified.
--
-- References:
--   DC   = docs/database/DATABASE_CONSTRAINTS.md
--   RBAC = docs/security/RBAC_RLS_MATRIX.md
--   ERD  = docs/erd/discipletrack.dbml
-- ============================================================


-- ============================================================
-- 1. SCHEMA
-- ============================================================

-- First-entry welcome state. NULL until the member completes the
-- one-time welcome after their membership first becomes ACTIVE.
-- Server-backed so a reinstall or another device never replays it.
-- Written only by complete_onboarding(). Never reset by reactivation.
alter table public.church_memberships
  add column onboarding_completed_at timestamptz;

comment on column public.church_memberships.onboarding_completed_at is
  'When the member completed the one-time first-entry welcome. NULL until then. Set only by complete_onboarding(). See DATABASE_CONSTRAINTS.md section 1.';

-- DC section 1: the join-code format chosen for the entropy rule.
-- Migration 004 documents the alphabet.
alter table public.churches
  add constraint churches_join_code_format_check
  check (join_code ~ '^[A-HJ-NP-Z2-9]{10}$');

-- Rate-limit state for join-code lookups and join requests
-- (DC section 1: "Join-code lookup and join requests must be rate
-- limited"). Keyed by auth user id with no foreign key, so the log
-- never blocks account deletion; rows older than a day are pruned
-- opportunistically. No client role can read or write it.
create table private.join_code_attempts (
  id            uuid        not null default gen_random_uuid(),
  user_id       uuid        not null,
  kind          text        not null,
  attempted_at  timestamptz not null default now(),

  constraint join_code_attempts_pkey primary key (id),
  constraint join_code_attempts_kind_check check (kind in ('LOOKUP', 'REQUEST'))
);

comment on table private.join_code_attempts is
  'Per-user join-code lookup/request attempts for rate limiting. Pruned after 24 hours. Not exposed to any client.';

create index join_code_attempts_user_time_idx
  on private.join_code_attempts (user_id, attempted_at desc);

alter table private.join_code_attempts enable row level security;
revoke all on table private.join_code_attempts from public, anon, authenticated;


-- ============================================================
-- 2. HELPERS
-- ============================================================

-- Uppercases and strips whitespace and hyphens, so a code typed as
-- "7qk4 mzp2-xr" matches "7QK4MZP2XR". Safe because the alphabet
-- excludes the ambiguous characters; no other substitution is done.
create function private.normalize_join_code(p_code text)
returns text
language sql
immutable
set search_path = ''
as $$
  select upper(regexp_replace(coalesce(p_code, ''), '[[:space:]-]', '', 'g'));
$$;

revoke execute on function private.normalize_join_code(text) from public, anon;
grant execute on function private.normalize_join_code(text) to authenticated, service_role;


-- Limits (DC section 1, mechanism chosen here):
--   5 attempts of any kind per user per 10 minutes
--   3 REQUEST attempts per user per hour
--
-- Counts committed rows first and raises before inserting, so a
-- refused call writes nothing and the window is always computed
-- from attempts that actually happened. Callers must return (not
-- raise) on a code miss so their attempt row commits.
create function private.enforce_join_rate_limit(p_user_id uuid, p_kind text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_recent   integer;
  v_requests integer;
begin
  delete from private.join_code_attempts a
  where a.attempted_at < now() - interval '24 hours';

  select count(*) into v_recent
  from private.join_code_attempts a
  where a.user_id = p_user_id
    and a.attempted_at > now() - interval '10 minutes';

  if v_recent >= 5 then
    raise exception 'rate_limited'
      using errcode = 'PT429',
            hint = 'Too many attempts. Try again in a few minutes.';
  end if;

  if p_kind = 'REQUEST' then
    select count(*) into v_requests
    from private.join_code_attempts a
    where a.user_id = p_user_id
      and a.kind = 'REQUEST'
      and a.attempted_at > now() - interval '1 hour';

    if v_requests >= 3 then
      raise exception 'rate_limited'
        using errcode = 'PT429',
              hint = 'Too many join requests. Try again later.';
    end if;
  end if;

  insert into private.join_code_attempts (user_id, kind)
  values (p_user_id, p_kind);
end;
$$;

revoke execute on function private.enforce_join_rate_limit(uuid, text)
  from public, anon, authenticated;
grant execute on function private.enforce_join_rate_limit(uuid, text) to service_role;


-- RBAC section 1a: a role attached to a non-ACTIVE membership grants
-- nothing, so the caller's own membership must be ACTIVE and the
-- role assignment open.
--
-- SECURITY DEFINER and owned by postgres, the table owner, so it
-- reads church_memberships and church_role_assignments without RLS
-- and can be used inside a policy on church_memberships itself
-- without recursion.
create function private.is_church_admin_or_coordinator(p_church_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.church_memberships m
    join public.church_role_assignments r on r.church_membership_id = m.id
    where m.church_id = p_church_id
      and m.user_id = (select auth.uid())
      and m.status = 'ACTIVE'
      and r.ended_at is null
      and r.role in ('ADMIN', 'COORDINATOR')
  );
$$;

comment on function private.is_church_admin_or_coordinator(uuid) is
  'True when the caller holds an active ADMIN or COORDINATOR role on an ACTIVE membership in the church. RBAC sections 1a and 3.';

revoke execute on function private.is_church_admin_or_coordinator(uuid) from public, anon;
grant execute on function private.is_church_admin_or_coordinator(uuid)
  to authenticated, service_role;


-- RBAC section 3, profiles: Admin -> profiles required for member
-- administration; Coordinator -> profiles required for ministry
-- operations. Implemented as: any person holding a membership row in
-- a church where the caller is ADMIN or COORDINATOR. Needed so the
-- pending-request list can show the applicant's name.
create function private.can_view_profile_as_church_admin(p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.church_memberships m
    where m.user_id = p_profile_id
      and private.is_church_admin_or_coordinator(m.church_id)
  );
$$;

revoke execute on function private.can_view_profile_as_church_admin(uuid) from public, anon;
grant execute on function private.can_view_profile_as_church_admin(uuid)
  to authenticated, service_role;


-- ============================================================
-- 3. CONTROLLED OPERATIONS
-- ============================================================

-- RBAC section 10: SECURITY DEFINER; requires an authenticated
-- caller; returns only minimal church confirmation information
-- (id and name); rate limited.
--
-- A miss returns an empty set rather than raising, so the attempt
-- recorded by enforce_join_rate_limit() commits. Malformed input is
-- treated as a miss and still costs an attempt.
create function public.lookup_church_by_join_code(p_code text)
returns table (church_id uuid, church_name text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := (select auth.uid());
  v_code text;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  perform private.enforce_join_rate_limit(v_uid, 'LOOKUP');

  v_code := private.normalize_join_code(p_code);
  if v_code !~ '^[A-HJ-NP-Z2-9]{10}$' then
    return;
  end if;

  return query
    select c.id, c.name
    from public.churches c
    where c.join_code = v_code
      and c.status = 'ACTIVE';
end;
$$;

comment on function public.lookup_church_by_join_code(text) is
  'Resolves a join code to the church id and name for the authenticated caller. Empty on miss. Rate limited. RBAC section 10.';

revoke execute on function public.lookup_church_by_join_code(text) from public, anon;
grant execute on function public.lookup_church_by_join_code(text) to authenticated, service_role;


-- RBAC section 10: takes the church identifier returned by the prior
-- lookup; creates a PENDING membership; rate limited.
--
-- The join code is required again and must resolve to p_church_id.
-- The code is the shared secret; the id only confirms the church the
-- person saw and accepted. A leaked church UUID therefore cannot
-- bypass the code.
--
-- Outcomes, returned rather than raised:
--   REQUESTED        a new PENDING membership was created
--   ALREADY_PENDING  the caller already has a PENDING request here
--   ALREADY_ACTIVE   the caller is already an ACTIVE member here
--   NOT_REQUESTABLE  an INACTIVE / TRANSFERRED / ARCHIVED row exists;
--                    DC section 1 allows only controlled
--                    reactivation or reinstatement from those states
--   INVALID_CODE     the code does not resolve to that ACTIVE church
--
-- Nothing else is written: no role, no D Group responsibility, no
-- status other than PENDING (DC section 1, BR-003, BR-005).
create function public.request_join_church(p_church_id uuid, p_join_code text)
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

  insert into public.church_memberships (church_id, user_id, status)
  values (v_church_id, v_uid, 'PENDING')
  returning * into v_row;

  return query select 'REQUESTED'::text, v_row.id, v_row.status;
end;
$$;

comment on function public.request_join_church(uuid, text) is
  'Creates a PENDING membership for the caller in the church identified by the lookup and its join code. Idempotent. Rate limited. RBAC section 10.';

revoke execute on function public.request_join_church(uuid, text) from public, anon;
grant execute on function public.request_join_church(uuid, text) to authenticated, service_role;


-- RBAC section 2: Approve church membership -> ADMIN Yes,
-- COORDINATOR Yes, same church only. DC section 1: PENDING -> ACTIVE.
--
-- Field semantics fixed here (DC section 1):
--   approved_by / approved_at  the approver and the moment of approval
--   joined_at                  the first time the membership became
--                              ACTIVE; never overwritten later
create function public.approve_church_membership(p_membership_id uuid)
returns table (membership_id uuid, membership_status public.membership_status)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_row public.church_memberships%rowtype;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select * into v_row
  from public.church_memberships m
  where m.id = p_membership_id
  for update;

  if not found then
    raise exception 'membership_not_found' using errcode = 'PT404';
  end if;

  if not private.is_church_admin_or_coordinator(v_row.church_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  -- Structurally impossible (an approver is ACTIVE, the target is
  -- PENDING, one row per person per church), asserted anyway.
  if v_row.user_id = v_uid then
    raise exception 'cannot_approve_self' using errcode = 'PT403';
  end if;

  if v_row.status <> 'PENDING' then
    raise exception 'membership_not_pending' using errcode = 'PT409';
  end if;

  update public.church_memberships m
  set status      = 'ACTIVE',
      approved_by = v_uid,
      approved_at = now(),
      joined_at   = coalesce(m.joined_at, now())
  where m.id = p_membership_id
  returning * into v_row;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_row.church_id,
    v_uid,
    'MEMBERSHIP_APPROVED',
    'church_memberships',
    v_row.id,
    jsonb_build_object('from', 'PENDING', 'to', 'ACTIVE', 'user_id', v_row.user_id)
  );

  return query select v_row.id, v_row.status;
end;
$$;

comment on function public.approve_church_membership(uuid) is
  'PENDING -> ACTIVE by an ADMIN or COORDINATOR of the same church. Sets approved_by, approved_at and joined_at. Audited. RBAC sections 2 and 10.';

revoke execute on function public.approve_church_membership(uuid) from public, anon;
grant execute on function public.approve_church_membership(uuid) to authenticated, service_role;


-- DC section 1: PENDING -> ARCHIVED (rejection). Same authority as
-- approval. approved_by / approved_at stay NULL because nothing was
-- approved. ARCHIVED -> ACTIVE is a separate controlled reinstatement
-- and is not part of this slice.
create function public.reject_church_membership(p_membership_id uuid)
returns table (membership_id uuid, membership_status public.membership_status)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_row public.church_memberships%rowtype;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select * into v_row
  from public.church_memberships m
  where m.id = p_membership_id
  for update;

  if not found then
    raise exception 'membership_not_found' using errcode = 'PT404';
  end if;

  if not private.is_church_admin_or_coordinator(v_row.church_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  if v_row.user_id = v_uid then
    raise exception 'cannot_reject_self' using errcode = 'PT403';
  end if;

  if v_row.status <> 'PENDING' then
    raise exception 'membership_not_pending' using errcode = 'PT409';
  end if;

  update public.church_memberships m
  set status = 'ARCHIVED'
  where m.id = p_membership_id
  returning * into v_row;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_row.church_id,
    v_uid,
    'MEMBERSHIP_REJECTED',
    'church_memberships',
    v_row.id,
    jsonb_build_object('from', 'PENDING', 'to', 'ARCHIVED', 'user_id', v_row.user_id)
  );

  return query select v_row.id, v_row.status;
end;
$$;

comment on function public.reject_church_membership(uuid) is
  'PENDING -> ARCHIVED by an ADMIN or COORDINATOR of the same church. Audited. DC section 1 lifecycle.';

revoke execute on function public.reject_church_membership(uuid) from public, anon;
grant execute on function public.reject_church_membership(uuid) to authenticated, service_role;


-- Marks the caller's first-entry welcome complete. Idempotent: a
-- second call keeps the original timestamp. Only an ACTIVE membership
-- can complete onboarding, because the welcome is shown only once
-- the membership is ACTIVE.
create function public.complete_onboarding()
returns table (membership_id uuid, onboarding_completed_at timestamptz)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_id  uuid;
  v_at  timestamptz;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  update public.church_memberships m
  set onboarding_completed_at = coalesce(m.onboarding_completed_at, now())
  where m.user_id = v_uid
    and m.status = 'ACTIVE'
  returning m.id, m.onboarding_completed_at into v_id, v_at;

  if v_id is null then
    raise exception 'no_active_membership' using errcode = 'PT409';
  end if;

  return query select v_id, v_at;
end;
$$;

comment on function public.complete_onboarding() is
  'Sets church_memberships.onboarding_completed_at once for the caller''s ACTIVE membership. Idempotent.';

revoke execute on function public.complete_onboarding() from public, anon;
grant execute on function public.complete_onboarding() to authenticated, service_role;


-- ============================================================
-- 4. ROW LEVEL SECURITY
-- ============================================================

-- ------------------------------------------------------------
-- churches
-- ------------------------------------------------------------
--
-- RBAC section 3: SELECT -> active church members, own church; lookup
-- by join code is NOT a direct client SELECT. RBAC section 1a
-- (clarified for this slice): a PENDING member may read the name of
-- the church they requested, which is part of their minimum
-- onboarding state.
--
-- join_code is removed from every client role at the column level.
-- RLS cannot hide a column, and no client ever needs to read it: the
-- lookup RPC compares it server-side and regeneration is a future
-- ADMIN-only controlled operation. A `select=*` on churches is
-- therefore refused (42501); clients name their columns.

revoke all on table public.churches from anon;
revoke select on table public.churches from authenticated;
grant select (id, name, status) on table public.churches to authenticated;

create policy churches_select_own_church
  on public.churches
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.church_memberships m
      where m.church_id = churches.id
        and m.user_id = (select auth.uid())
        and m.status in ('PENDING', 'ACTIVE')
    )
  );


-- ------------------------------------------------------------
-- church_memberships
-- ------------------------------------------------------------
--
-- RBAC section 3: SELECT -> ADMIN own church, COORDINATOR own church.
-- Additive to church_memberships_select_own (Migration 003).
-- INSERT and UPDATE stay closed; every write goes through the RPCs
-- above. LEADER and DISCIPLER scopes arrive with the D Group slice.

create policy church_memberships_select_church_admin
  on public.church_memberships
  for select
  to authenticated
  using (private.is_church_admin_or_coordinator(church_id));


-- ------------------------------------------------------------
-- profiles
-- ------------------------------------------------------------
--
-- RBAC section 3: Admin and Coordinator read scopes, restricted to
-- people with a membership row in a church they administer.
-- Additive to profiles_select_own (Migration 003). UPDATE stays
-- own-row and own-columns only.

create policy profiles_select_church_admin
  on public.profiles
  for select
  to authenticated
  using (private.can_view_profile_as_church_admin(id));


-- ------------------------------------------------------------
-- church_role_assignments
-- ------------------------------------------------------------
--
-- RBAC section 3: SELECT -> User, own roles where needed. The home
-- screen uses this to show the membership-request entry point to
-- approvers; authority is still enforced server-side. ADMIN and
-- COORDINATOR read scopes arrive with role management. WRITE stays
-- closed (controlled role-management operations only).

create policy church_role_assignments_select_own
  on public.church_role_assignments
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.church_memberships m
      where m.id = church_role_assignments.church_membership_id
        and m.user_id = (select auth.uid())
    )
  );
