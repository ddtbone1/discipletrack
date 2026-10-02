-- ============================================================
-- DiscipleTrack - Migration 006: Ministry Structure
-- ============================================================
--
-- Database logic for Vertical Slice 3 (Ministry Structure): D Groups
-- with a Leader, confirmed placement by invitation, Discipler pairing,
-- removal, and role-scoped reads.
--
-- Scope of this migration:
--   Grants
--     - anon loses everything on the D Group tables and audit_events
--     - authenticated keeps SELECT only (under RLS) on the D Group
--       tables, audit_events and church_role_assignments
--   Schema
--     - d_group_invitation_status enum, d_group_invitations table
--     - d_groups name CHECK and per-church case-insensitive unique name
--     - d_group_memberships active-row unique index
--     - discipler_assignments distinct-sides CHECK
--   Integrity triggers (defence in depth, every writer)
--     - d_group_memberships: same church, no overlapping periods,
--       DISCIPLE / DISCIPLER exclusion, one group per person
--     - discipler_assignments: DISCIPLER side, DISCIPLE side, same
--       group, no overlapping periods per Disciple
--     - d_group_invitations: same church
--   Helpers (schema private, no API endpoint)
--   Controlled operations (schema public, RPC)
--     - create_d_group(), assign_d_group_leader()
--     - invite_to_d_group(), withdraw_d_group_invitation(),
--       respond_to_d_group_invitation()
--     - add_self_as_discipler(), end_d_group_membership(),
--       set_discipler()
--     - list_placeable_members(), get_my_pending_invitation(),
--       get_my_d_group_roster()
--   RLS (read-only policies)
--     - d_groups, d_group_memberships, discipler_assignments,
--       d_group_invitations
--     - church_memberships and profiles: Leader, Discipler and Disciple
--       scopes
--
-- Error convention, as in Migration 005. RPCs raise PostgREST status
-- SQLSTATEs so the client can branch on the code, and the message is
-- a stable reason the client maps to wording:
--
--   PT400 d_group_name_required / invalid_responsibility
--   PT401 authentication_required
--   PT403 not_authorized
--   PT404 d_group_not_found / membership_not_found /
--         invitation_not_found / d_group_membership_not_found
--   PT409 member_not_active / member_already_placed /
--         member_has_pending_invitation / d_group_name_taken /
--         d_group_not_active / invitation_not_pending /
--         invitation_expired / already_leader / leader_not_eligible /
--         already_discipler / leader_cannot_be_ended /
--         d_group_membership_not_active / not_an_active_disciple /
--         not_an_active_discipler / already_paired / not_paired
--
-- Invitation expiry is lazy; there is no scheduler. A PENDING row
-- whose expires_at has passed is EXPIRED in meaning everywhere: the
-- read operations exclude it and the write operations refuse it. The
-- row itself is marked EXPIRED by the next successful write that
-- touches it (an invitation to the same member, or a withdrawal). An
-- operation that refuses an expired invitation cannot persist the
-- mark, because raising rolls the transaction back.
--
-- Concurrency: every operation that changes a person's D Group rows
-- first locks that person's church_memberships row FOR UPDATE, so two
-- operations on the same person serialise and the integrity triggers
-- see each other's committed rows.
--
-- Migrations 001 to 005 are not modified.
--
-- References:
--   DC   = docs/database/DATABASE_CONSTRAINTS.md
--   RBAC = docs/security/RBAC_RLS_MATRIX.md
--   ERD  = docs/erd/discipletrack.dbml
--   Plan = docs/plans/slice-3-ministry-structure.md
-- ============================================================


-- ============================================================
-- 1. SCHEMA
-- ============================================================

create type public.d_group_invitation_status as enum (
  'PENDING', 'ACCEPTED', 'DECLINED', 'WITHDRAWN', 'EXPIRED'
);

-- Confirmed placement: a Leader or Coordinator invites an unplaced
-- ACTIVE member, and the member accepts or declines once. Accepting
-- creates the d_group_memberships row. See ERD d_group_invitations.
create table public.d_group_invitations (
  id                               uuid                             not null default gen_random_uuid(),
  d_group_id                       uuid                             not null,
  church_membership_id             uuid                             not null,
  responsibility                   public.d_group_responsibility    not null,
  status                           public.d_group_invitation_status not null default 'PENDING',
  invited_by                       uuid                             not null,
  created_at                       timestamptz                      not null default now(),
  expires_at                       timestamptz                      not null,
  responded_at                     timestamptz,
  resulting_d_group_membership_id  uuid,

  constraint d_group_invitations_pkey primary key (id),
  constraint d_group_invitations_d_group_id_fkey foreign key (d_group_id)
    references public.d_groups (id) on delete no action,
  constraint d_group_invitations_membership_fkey
    foreign key (church_membership_id)
    references public.church_memberships (id) on delete no action,
  constraint d_group_invitations_invited_by_fkey foreign key (invited_by)
    references public.profiles (id) on delete no action,
  constraint d_group_invitations_resulting_dgm_fkey
    foreign key (resulting_d_group_membership_id)
    references public.d_group_memberships (id) on delete no action,

  -- LEADER is appointed directly by the Coordinator, never invited.
  constraint d_group_invitations_responsibility_check
    check (responsibility in ('DISCIPLER', 'DISCIPLE')),

  constraint d_group_invitations_expiry_check
    check (expires_at > created_at),

  -- responded_at is when the invitation left PENDING. For EXPIRED it
  -- is expires_at, the moment it actually lapsed, not the moment the
  -- row happened to be marked.
  constraint d_group_invitations_state_check check (
    (status = 'PENDING'
      and responded_at is null
      and resulting_d_group_membership_id is null)
    or
    (status = 'ACCEPTED'
      and responded_at is not null
      and resulting_d_group_membership_id is not null)
    or
    (status in ('DECLINED', 'WITHDRAWN', 'EXPIRED')
      and responded_at is not null
      and resulting_d_group_membership_id is null)
  )
);

comment on table public.d_group_invitations is
  'Invitations to join a D Group as DISCIPLER or DISCIPLE. Written only by the controlled operations in Migration 006. A PENDING row past expires_at is treated as EXPIRED and is marked so by the next write that touches it.';

-- Plan decision 3: a member holds at most one pending invitation.
create unique index d_group_invitations_one_pending_uidx
  on public.d_group_invitations (church_membership_id)
  where status = 'PENDING'::public.d_group_invitation_status;

create index d_group_invitations_group_status_idx
  on public.d_group_invitations (d_group_id, status);

alter table public.d_group_invitations enable row level security;


-- Plan decision 10: group names are unique per church, ignoring case
-- and surrounding spaces. ARCHIVED groups release their name.
alter table public.d_groups
  add constraint d_groups_name_not_blank_check
  check (length(trim(name)) > 0);

create unique index d_groups_church_name_uidx
  on public.d_groups (church_id, lower(trim(name)))
  where status <> 'ARCHIVED'::public.d_group_status;

-- One active row per person, group and responsibility. The integrity
-- trigger below also rejects overlapping historical periods.
create unique index d_group_memberships_active_responsibility_uidx
  on public.d_group_memberships (church_membership_id, d_group_id, responsibility)
  where ended_at is null;

-- A Disciple cannot be paired with themselves. The integrity trigger
-- already requires one DISCIPLER side and one DISCIPLE side; this
-- states the simplest case declaratively.
alter table public.discipler_assignments
  add constraint discipler_assignments_distinct_sides_check
  check (discipler_d_group_membership_id <> disciple_d_group_membership_id);


-- ============================================================
-- 2. GRANTS
-- ============================================================
--
-- Supabase's default privileges grant ALL on new public tables to anon
-- and authenticated. RLS already denied these tables to clients, but
-- the grants are narrowed as well so a future permissive policy cannot
-- open a write path by accident. Every write goes through the
-- SECURITY DEFINER operations below.

revoke all on table
  public.d_groups,
  public.d_group_memberships,
  public.discipler_assignments,
  public.ministry_role_transitions,
  public.audit_events,
  public.d_group_invitations
from anon;

revoke insert, update, delete, truncate on table
  public.d_groups,
  public.d_group_memberships,
  public.discipler_assignments,
  public.ministry_role_transitions,
  public.audit_events,
  public.d_group_invitations,
  public.church_role_assignments
from authenticated;


-- ============================================================
-- 3. INTEGRITY TRIGGERS
-- ============================================================
--
-- Constraint triggers, not deferred, so a violation is reported by
-- the statement that caused it. SECURITY DEFINER so they read across
-- RLS whoever the writer is. Periods are half-open [started, ended),
-- so a responsibility ending at T and another starting at T do not
-- overlap; a NULL ended_at is unbounded.

-- DC sections 2 and 10, Plan decision 7.
create function private.check_d_group_membership_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_group_church  uuid;
  v_member_church uuid;
  v_period        tstzrange := tstzrange(new.started_at, new.ended_at, '[)');
begin
  select g.church_id into v_group_church
  from public.d_groups g
  where g.id = new.d_group_id;

  select m.church_id into v_member_church
  from public.church_memberships m
  where m.id = new.church_membership_id;

  if v_group_church is distinct from v_member_church then
    raise exception 'd_group_membership_cross_church'
      using errcode = '23514',
            detail = 'The D Group and the church membership belong to different churches.';
  end if;

  -- DC section 2, Temporal Integrity.
  if exists (
    select 1
    from public.d_group_memberships o
    where o.id <> new.id
      and o.church_membership_id = new.church_membership_id
      and o.d_group_id = new.d_group_id
      and o.responsibility = new.responsibility
      and tstzrange(o.started_at, o.ended_at, '[)') && v_period
  ) then
    raise exception 'd_group_membership_overlap'
      using errcode = '23514',
            detail = 'Overlapping periods for the same person, D Group and responsibility.';
  end if;

  -- Plan decision 7: all of a person's responsibilities at any moment
  -- are in one D Group.
  if exists (
    select 1
    from public.d_group_memberships o
    where o.id <> new.id
      and o.church_membership_id = new.church_membership_id
      and o.d_group_id <> new.d_group_id
      and tstzrange(o.started_at, o.ended_at, '[)') && v_period
  ) then
    raise exception 'd_group_membership_spans_groups'
      using errcode = '23514',
            detail = 'A person''s responsibilities must all be in one D Group at a time.';
  end if;

  -- DC section 2 and Plan decision 7: DISCIPLE excludes LEADER and
  -- DISCIPLER. LEADER with DISCIPLER is allowed.
  if exists (
    select 1
    from public.d_group_memberships o
    where o.id <> new.id
      and o.church_membership_id = new.church_membership_id
      and tstzrange(o.started_at, o.ended_at, '[)') && v_period
      and (o.responsibility = 'DISCIPLE') <> (new.responsibility = 'DISCIPLE')
  ) then
    raise exception 'd_group_membership_disciple_conflict'
      using errcode = '23514',
            detail = 'DISCIPLE cannot overlap LEADER or DISCIPLER for the same person.';
  end if;

  return null;
end;
$$;

revoke execute on function private.check_d_group_membership_integrity()
  from public, anon, authenticated;

create constraint trigger d_group_memberships_integrity
  after insert or update on public.d_group_memberships
  for each row execute function private.check_d_group_membership_integrity();


-- DC section 2, Responsibility Correctness, and section 10.
-- Activeness of the referenced rows stays a controlled-operation
-- invariant, as DC section 2 says.
create function private.check_discipler_assignment_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_discipler public.d_group_memberships%rowtype;
  v_disciple  public.d_group_memberships%rowtype;
begin
  select * into v_discipler
  from public.d_group_memberships d
  where d.id = new.discipler_d_group_membership_id;

  select * into v_disciple
  from public.d_group_memberships d
  where d.id = new.disciple_d_group_membership_id;

  if v_discipler.responsibility is distinct from 'DISCIPLER' then
    raise exception 'assignment_discipler_side_invalid'
      using errcode = '23514',
            detail = 'discipler_d_group_membership_id must reference a DISCIPLER responsibility.';
  end if;

  if v_disciple.responsibility is distinct from 'DISCIPLE' then
    raise exception 'assignment_disciple_side_invalid'
      using errcode = '23514',
            detail = 'disciple_d_group_membership_id must reference a DISCIPLE responsibility.';
  end if;

  if v_discipler.d_group_id <> new.d_group_id
     or v_disciple.d_group_id <> new.d_group_id then
    raise exception 'assignment_cross_group'
      using errcode = '23514',
            detail = 'Both sides of a discipler assignment must be in the assignment''s D Group.';
  end if;

  if exists (
    select 1
    from public.discipler_assignments o
    where o.id <> new.id
      and o.disciple_d_group_membership_id = new.disciple_d_group_membership_id
      and tstzrange(o.started_at, o.ended_at, '[)')
          && tstzrange(new.started_at, new.ended_at, '[)')
  ) then
    raise exception 'assignment_overlap'
      using errcode = '23514',
            detail = 'A Disciple''s discipler assignments cannot overlap.';
  end if;

  return null;
end;
$$;

revoke execute on function private.check_discipler_assignment_integrity()
  from public, anon, authenticated;

create constraint trigger discipler_assignments_integrity
  after insert or update on public.discipler_assignments
  for each row execute function private.check_discipler_assignment_integrity();


-- DC section 10.
create function private.check_d_group_invitation_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select g.church_id from public.d_groups g where g.id = new.d_group_id)
     is distinct from
     (select m.church_id from public.church_memberships m
      where m.id = new.church_membership_id) then
    raise exception 'd_group_invitation_cross_church'
      using errcode = '23514',
            detail = 'The D Group and the invitee belong to different churches.';
  end if;

  return null;
end;
$$;

revoke execute on function private.check_d_group_invitation_integrity()
  from public, anon, authenticated;

create constraint trigger d_group_invitations_integrity
  after insert or update on public.d_group_invitations
  for each row execute function private.check_d_group_invitation_integrity();


-- ============================================================
-- 4. HELPERS
-- ============================================================
--
-- SECURITY DEFINER and owned by postgres, so they read the D Group
-- tables without RLS and can be used inside policies on those same
-- tables without recursion. Every predicate about the caller requires
-- the caller's own membership to be ACTIVE (RBAC section 1a).

create function private.is_church_coordinator(p_church_id uuid)
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
      and r.role = 'COORDINATOR'
  );
$$;

comment on function private.is_church_coordinator(uuid) is
  'True when the caller holds an active COORDINATOR role on an ACTIVE membership in the church. RBAC sections 1a and 2.';


-- The caller holds an active responsibility in the group, optionally
-- of one kind.
create function private.has_active_responsibility_in(
  p_d_group_id     uuid,
  p_responsibility public.d_group_responsibility default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.d_group_memberships dgm
    join public.church_memberships m on m.id = dgm.church_membership_id
    where dgm.d_group_id = p_d_group_id
      and dgm.ended_at is null
      and (p_responsibility is null or dgm.responsibility = p_responsibility)
      and m.user_id = (select auth.uid())
      and m.status = 'ACTIVE'
  );
$$;


create function private.leads_d_group(p_d_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.has_active_responsibility_in(p_d_group_id, 'LEADER');
$$;


-- Plan section B: the Coordinator for any group in their church, or
-- that group's own Leader.
create function private.can_manage_d_group_members(p_d_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
           select 1
           from public.d_groups g
           where g.id = p_d_group_id
             and private.is_church_coordinator(g.church_id)
         )
      or private.leads_d_group(p_d_group_id);
$$;


-- No active D Group responsibility of any kind.
create function private.is_unplaced(p_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1
    from public.d_group_memberships dgm
    where dgm.church_membership_id = p_membership_id
      and dgm.ended_at is null
  );
$$;


create function private.is_my_membership(p_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.church_memberships m
    where m.id = p_membership_id
      and m.user_id = (select auth.uid())
      and m.status = 'ACTIVE'
  );
$$;


create function private.owns_d_group_membership(p_d_group_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.d_group_memberships dgm
    join public.church_memberships m on m.id = dgm.church_membership_id
    where dgm.id = p_d_group_membership_id
      and m.user_id = (select auth.uid())
      and m.status = 'ACTIVE'
  );
$$;


-- The caller is the active Discipler of the person.
create function private.is_assigned_discipler_of(p_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.discipler_assignments a
    join public.d_group_memberships dr on dr.id = a.discipler_d_group_membership_id
    join public.d_group_memberships dd on dd.id = a.disciple_d_group_membership_id
    join public.church_memberships me on me.id = dr.church_membership_id
    where a.ended_at is null
      and dr.ended_at is null
      and dd.ended_at is null
      and dd.church_membership_id = p_membership_id
      and me.user_id = (select auth.uid())
      and me.status = 'ACTIVE'
  );
$$;


-- The person is the caller's own Leader (the caller being a Discipler
-- or Disciple in that group) or the caller's own active Discipler.
create function private.is_my_leader_or_discipler(p_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
           select 1
           from public.d_group_memberships l
           join public.d_group_memberships mine on mine.d_group_id = l.d_group_id
           join public.church_memberships me on me.id = mine.church_membership_id
           where l.church_membership_id = p_membership_id
             and l.responsibility = 'LEADER'
             and l.ended_at is null
             and mine.ended_at is null
             and mine.responsibility in ('DISCIPLER', 'DISCIPLE')
             and me.user_id = (select auth.uid())
             and me.status = 'ACTIVE'
         )
      or exists (
           select 1
           from public.discipler_assignments a
           join public.d_group_memberships dr on dr.id = a.discipler_d_group_membership_id
           join public.d_group_memberships dd on dd.id = a.disciple_d_group_membership_id
           join public.church_memberships me on me.id = dd.church_membership_id
           where a.ended_at is null
             and dr.ended_at is null
             and dd.ended_at is null
             and dr.church_membership_id = p_membership_id
             and me.user_id = (select auth.uid())
             and me.status = 'ACTIVE'
         );
$$;


-- RBAC section 3, LEADER -> members of own D Group. Also covers people
-- invited to the Leader's group, whose names the pending and declined
-- invitations list must show.
create function private.leads_group_of_membership(p_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.d_group_memberships l
    join public.church_memberships me on me.id = l.church_membership_id
    where l.responsibility = 'LEADER'
      and l.ended_at is null
      and me.user_id = (select auth.uid())
      and me.status = 'ACTIVE'
      and (
        exists (
          select 1
          from public.d_group_memberships t
          where t.d_group_id = l.d_group_id
            and t.church_membership_id = p_membership_id
            and t.ended_at is null
        )
        or exists (
          select 1
          from public.d_group_invitations i
          where i.d_group_id = l.d_group_id
            and i.church_membership_id = p_membership_id
        )
      )
  );
$$;


-- Ministry read scope for church_memberships and profiles, additive to
-- the own-row and Admin/Coordinator policies of Migrations 003 and 005.
create function private.can_view_membership_in_ministry(p_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.leads_group_of_membership(p_membership_id)
      or private.is_assigned_discipler_of(p_membership_id)
      or private.is_my_leader_or_discipler(p_membership_id);
$$;


create function private.can_view_profile_in_ministry(p_profile_id uuid)
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
      and private.can_view_membership_in_ministry(m.id)
  );
$$;


-- Marks the person's overdue PENDING invitations EXPIRED. Called by
-- write operations before they test for a pending invitation.
create function private.expire_overdue_d_group_invitations(p_membership_id uuid)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  update public.d_group_invitations i
  set status       = 'EXPIRED',
      responded_at = i.expires_at
  where i.church_membership_id = p_membership_id
    and i.status = 'PENDING'
    and i.expires_at <= now();
$$;


do $$
declare
  v_fn text;
begin
  foreach v_fn in array array[
    'private.is_church_coordinator(uuid)',
    'private.has_active_responsibility_in(uuid, public.d_group_responsibility)',
    'private.leads_d_group(uuid)',
    'private.can_manage_d_group_members(uuid)',
    'private.is_unplaced(uuid)',
    'private.is_my_membership(uuid)',
    'private.owns_d_group_membership(uuid)',
    'private.is_assigned_discipler_of(uuid)',
    'private.is_my_leader_or_discipler(uuid)',
    'private.leads_group_of_membership(uuid)',
    'private.can_view_membership_in_ministry(uuid)',
    'private.can_view_profile_in_ministry(uuid)'
  ]
  loop
    execute format('revoke execute on function %s from public, anon', v_fn);
    execute format('grant execute on function %s to authenticated, service_role', v_fn);
  end loop;
end
$$;

revoke execute on function private.expire_overdue_d_group_invitations(uuid)
  from public, anon, authenticated;
grant execute on function private.expire_overdue_d_group_invitations(uuid)
  to service_role;


-- ============================================================
-- 5. CONTROLLED OPERATIONS
-- ============================================================
--
-- Each operation: authenticates the caller, checks authority before
-- revealing anything about the target, requires ACTIVE target
-- memberships, locks rows before changing them, uses now() for every
-- domain timestamp and writes one audit event (RBAC section 10).
--
-- Monitoring hook. When the Discipleship Meeting slice adds
-- CONSECUTIVE_MISSED_MEETINGS, ending a discipler assignment must
-- resolve the ACTIVE condition belonging to it (RBAC section 10,
-- transfer_disciple / reassign_discipler). Each place an assignment
-- ends is marked "MONITORING HOOK".


-- Plan decision 2: the Coordinator creates each group together with
-- its Leader, who must be an unplaced ACTIVE member of the church.
create function public.create_d_group(
  p_name                 text,
  p_description          text,
  p_leader_membership_id uuid
)
returns table (d_group_id uuid, leader_d_group_membership_id uuid)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := (select auth.uid());
  v_leader public.church_memberships%rowtype;
  v_name   text := trim(coalesce(p_name, ''));
  v_group  uuid;
  v_dgm    uuid;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select * into v_leader
  from public.church_memberships m
  where m.id = p_leader_membership_id
  for update;

  if not found then
    raise exception 'membership_not_found' using errcode = 'PT404';
  end if;

  if not private.is_church_coordinator(v_leader.church_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  if v_name = '' then
    raise exception 'd_group_name_required' using errcode = 'PT400';
  end if;

  if v_leader.status <> 'ACTIVE' then
    raise exception 'member_not_active' using errcode = 'PT409';
  end if;

  if not private.is_unplaced(v_leader.id) then
    raise exception 'member_already_placed' using errcode = 'PT409';
  end if;

  begin
    insert into public.d_groups (church_id, name, description, created_by)
    values (
      v_leader.church_id,
      v_name,
      nullif(trim(coalesce(p_description, '')), ''),
      v_uid
    )
    returning id into v_group;
  exception
    when unique_violation then
      raise exception 'd_group_name_taken' using errcode = 'PT409';
  end;

  insert into public.d_group_memberships
    (d_group_id, church_membership_id, responsibility, started_at, assigned_by)
  values (v_group, v_leader.id, 'LEADER', now(), v_uid)
  returning id into v_dgm;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_leader.church_id,
    v_uid,
    'D_GROUP_CREATED',
    'd_groups',
    v_group,
    jsonb_build_object(
      'name', v_name,
      'leader_church_membership_id', v_leader.id,
      'leader_d_group_membership_id', v_dgm
    )
  );

  return query select v_group, v_dgm;
end;
$$;

comment on function public.create_d_group(text, text, uuid) is
  'Coordinator only. Creates a D Group and its LEADER responsibility for an unplaced ACTIVE member. Audited as D_GROUP_CREATED.';


-- Plan decision 2: the Leader can be replaced but never left empty.
-- The new Leader is either unplaced or already a DISCIPLER in this
-- group (LEADER + DISCIPLER in one group is allowed). The replaced
-- Leader keeps any DISCIPLER row they hold here; otherwise they become
-- unplaced. History is kept by ending the old row.
create function public.assign_d_group_leader(
  p_d_group_id    uuid,
  p_membership_id uuid
)
returns table (d_group_membership_id uuid)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := (select auth.uid());
  v_group  public.d_groups%rowtype;
  v_target public.church_memberships%rowtype;
  v_old    public.d_group_memberships%rowtype;
  v_dgm    uuid;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select * into v_group
  from public.d_groups g
  where g.id = p_d_group_id
  for update;

  if not found then
    raise exception 'd_group_not_found' using errcode = 'PT404';
  end if;

  if not private.is_church_coordinator(v_group.church_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  if v_group.status <> 'ACTIVE' then
    raise exception 'd_group_not_active' using errcode = 'PT409';
  end if;

  select * into v_target
  from public.church_memberships m
  where m.id = p_membership_id
    and m.church_id = v_group.church_id
  for update;

  if not found then
    raise exception 'membership_not_found' using errcode = 'PT404';
  end if;

  if v_target.status <> 'ACTIVE' then
    raise exception 'member_not_active' using errcode = 'PT409';
  end if;

  select * into v_old
  from public.d_group_memberships dgm
  where dgm.d_group_id = v_group.id
    and dgm.responsibility = 'LEADER'
    and dgm.ended_at is null
  for update;

  if found and v_old.church_membership_id = v_target.id then
    raise exception 'already_leader' using errcode = 'PT409';
  end if;

  -- Unplaced, or holding nothing but a DISCIPLER row in this group.
  if exists (
    select 1
    from public.d_group_memberships dgm
    where dgm.church_membership_id = v_target.id
      and dgm.ended_at is null
      and not (dgm.d_group_id = v_group.id and dgm.responsibility = 'DISCIPLER')
  ) then
    raise exception 'leader_not_eligible' using errcode = 'PT409';
  end if;

  if v_old.id is not null then
    update public.d_group_memberships dgm
    set ended_at = now()
    where dgm.id = v_old.id;
  end if;

  insert into public.d_group_memberships
    (d_group_id, church_membership_id, responsibility, started_at, assigned_by)
  values (v_group.id, v_target.id, 'LEADER', now(), v_uid)
  returning id into v_dgm;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_group.church_id,
    v_uid,
    'D_GROUP_LEADER_ASSIGNED',
    'd_groups',
    v_group.id,
    jsonb_build_object(
      'from_church_membership_id', v_old.church_membership_id,
      'from_d_group_membership_id', v_old.id,
      'to_church_membership_id', v_target.id,
      'to_d_group_membership_id', v_dgm
    )
  );

  return query select v_dgm;
end;
$$;

comment on function public.assign_d_group_leader(uuid, uuid) is
  'Coordinator only. Replaces (or sets) the active LEADER of a D Group in one transaction, ending the previous LEADER row. Audited as D_GROUP_LEADER_ASSIGNED.';


-- Plan decision 3.
create function public.invite_to_d_group(
  p_d_group_id     uuid,
  p_membership_id  uuid,
  p_responsibility public.d_group_responsibility
)
returns table (invitation_id uuid, expires_at timestamptz)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := (select auth.uid());
  v_group  public.d_groups%rowtype;
  v_target public.church_memberships%rowtype;
  v_id     uuid;
  v_exp    timestamptz;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select * into v_group
  from public.d_groups g
  where g.id = p_d_group_id
  for share;

  if not found then
    raise exception 'd_group_not_found' using errcode = 'PT404';
  end if;

  if not private.can_manage_d_group_members(v_group.id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  if v_group.status <> 'ACTIVE' then
    raise exception 'd_group_not_active' using errcode = 'PT409';
  end if;

  if p_responsibility is null or p_responsibility not in ('DISCIPLER', 'DISCIPLE') then
    raise exception 'invalid_responsibility' using errcode = 'PT400';
  end if;

  select * into v_target
  from public.church_memberships m
  where m.id = p_membership_id
    and m.church_id = v_group.church_id
  for update;

  if not found then
    raise exception 'membership_not_found' using errcode = 'PT404';
  end if;

  if v_target.status <> 'ACTIVE' then
    raise exception 'member_not_active' using errcode = 'PT409';
  end if;

  perform private.expire_overdue_d_group_invitations(v_target.id);

  if not private.is_unplaced(v_target.id) then
    raise exception 'member_already_placed' using errcode = 'PT409';
  end if;

  if exists (
    select 1
    from public.d_group_invitations i
    where i.church_membership_id = v_target.id
      and i.status = 'PENDING'
  ) then
    raise exception 'member_has_pending_invitation' using errcode = 'PT409';
  end if;

  insert into public.d_group_invitations
    (d_group_id, church_membership_id, responsibility, invited_by,
     created_at, expires_at)
  values
    (v_group.id, v_target.id, p_responsibility, v_uid,
     now(), now() + interval '14 days')
  returning id, d_group_invitations.expires_at into v_id, v_exp;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_group.church_id,
    v_uid,
    'D_GROUP_INVITATION_SENT',
    'd_group_invitations',
    v_id,
    jsonb_build_object(
      'd_group_id', v_group.id,
      'church_membership_id', v_target.id,
      'responsibility', p_responsibility
    )
  );

  return query select v_id, v_exp;
end;
$$;

comment on function public.invite_to_d_group(uuid, uuid, public.d_group_responsibility) is
  'Coordinator or the group''s Leader. Invites an unplaced ACTIVE member with no pending invitation as DISCIPLER or DISCIPLE; expires after 14 days. Audited as D_GROUP_INVITATION_SENT.';


-- Plan section C: the Coordinator, or the inviter while they lead the
-- group. An invitation that has already lapsed is marked EXPIRED and
-- reported as such rather than refused: either way it is gone, which
-- is what the caller asked for.
create function public.withdraw_d_group_invitation(p_invitation_id uuid)
returns table (invitation_id uuid, invitation_status public.d_group_invitation_status)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := (select auth.uid());
  v_inv    public.d_group_invitations%rowtype;
  v_church uuid;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select * into v_inv
  from public.d_group_invitations i
  where i.id = p_invitation_id
  for update;

  if not found then
    raise exception 'invitation_not_found' using errcode = 'PT404';
  end if;

  select g.church_id into v_church
  from public.d_groups g
  where g.id = v_inv.d_group_id;

  if not (
    private.is_church_coordinator(v_church)
    or (v_inv.invited_by = v_uid and private.leads_d_group(v_inv.d_group_id))
  ) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  if v_inv.status <> 'PENDING' then
    raise exception 'invitation_not_pending' using errcode = 'PT409';
  end if;

  if v_inv.expires_at <= now() then
    perform private.expire_overdue_d_group_invitations(v_inv.church_membership_id);
    return query select v_inv.id, 'EXPIRED'::public.d_group_invitation_status;
    return;
  end if;

  update public.d_group_invitations i
  set status       = 'WITHDRAWN',
      responded_at = now()
  where i.id = v_inv.id;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_church,
    v_uid,
    'D_GROUP_INVITATION_WITHDRAWN',
    'd_group_invitations',
    v_inv.id,
    jsonb_build_object(
      'd_group_id', v_inv.d_group_id,
      'church_membership_id', v_inv.church_membership_id
    )
  );

  return query select v_inv.id, 'WITHDRAWN'::public.d_group_invitation_status;
end;
$$;

comment on function public.withdraw_d_group_invitation(uuid) is
  'Coordinator, or the inviter while Leader of the group. PENDING -> WITHDRAWN, or EXPIRED when already lapsed. Audited as D_GROUP_INVITATION_WITHDRAWN.';


-- Plan decision 3: the invitee accepts or declines once. Accepting
-- re-checks that they are still unplaced and creates the
-- responsibility. assigned_by is the inviter, whose decision the
-- placement records; the audit row records the invitee as the actor of
-- the acceptance.
create function public.respond_to_d_group_invitation(
  p_invitation_id uuid,
  p_accept        boolean
)
returns table (
  invitation_id         uuid,
  invitation_status     public.d_group_invitation_status,
  d_group_membership_id uuid
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := (select auth.uid());
  v_inv    public.d_group_invitations%rowtype;
  v_member public.church_memberships%rowtype;
  v_group  public.d_groups%rowtype;
  v_dgm    uuid;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  if p_accept is null then
    raise exception 'invalid_response' using errcode = 'PT400';
  end if;

  select * into v_inv
  from public.d_group_invitations i
  where i.id = p_invitation_id
  for update;

  if not found then
    raise exception 'invitation_not_found' using errcode = 'PT404';
  end if;

  select * into v_member
  from public.church_memberships m
  where m.id = v_inv.church_membership_id
  for update;

  if v_member.user_id <> v_uid or v_member.status <> 'ACTIVE' then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  if v_inv.status <> 'PENDING' then
    raise exception 'invitation_not_pending' using errcode = 'PT409';
  end if;

  if v_inv.expires_at <= now() then
    raise exception 'invitation_expired' using errcode = 'PT409';
  end if;

  select * into v_group
  from public.d_groups g
  where g.id = v_inv.d_group_id;

  if not p_accept then
    update public.d_group_invitations i
    set status       = 'DECLINED',
        responded_at = now()
    where i.id = v_inv.id;

    insert into public.audit_events
      (church_id, actor_user_id, action, entity_type, entity_id, metadata)
    values (
      v_group.church_id,
      v_uid,
      'D_GROUP_INVITATION_DECLINED',
      'd_group_invitations',
      v_inv.id,
      jsonb_build_object('d_group_id', v_inv.d_group_id)
    );

    return query select v_inv.id, 'DECLINED'::public.d_group_invitation_status, null::uuid;
    return;
  end if;

  if v_group.status <> 'ACTIVE' then
    raise exception 'd_group_not_active' using errcode = 'PT409';
  end if;

  if not private.is_unplaced(v_member.id) then
    raise exception 'member_already_placed' using errcode = 'PT409';
  end if;

  insert into public.d_group_memberships
    (d_group_id, church_membership_id, responsibility, started_at, assigned_by)
  values (v_group.id, v_member.id, v_inv.responsibility, now(), v_inv.invited_by)
  returning id into v_dgm;

  update public.d_group_invitations i
  set status                          = 'ACCEPTED',
      responded_at                    = now(),
      resulting_d_group_membership_id = v_dgm
  where i.id = v_inv.id;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_group.church_id,
    v_uid,
    'D_GROUP_INVITATION_ACCEPTED',
    'd_group_invitations',
    v_inv.id,
    jsonb_build_object(
      'd_group_id', v_group.id,
      'responsibility', v_inv.responsibility,
      'd_group_membership_id', v_dgm
    )
  );

  return query select v_inv.id, 'ACCEPTED'::public.d_group_invitation_status, v_dgm;
end;
$$;

comment on function public.respond_to_d_group_invitation(uuid, boolean) is
  'The invitee only. Accept creates the D Group responsibility if they are still unplaced; decline closes the invitation. An expired invitation is refused. Audited as D_GROUP_INVITATION_ACCEPTED / _DECLINED.';


-- Plan decision 7: a Leader may add themselves as Discipler directly.
create function public.add_self_as_discipler(p_d_group_id uuid)
returns table (d_group_membership_id uuid)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := (select auth.uid());
  v_group  public.d_groups%rowtype;
  v_leader public.d_group_memberships%rowtype;
  v_dgm    uuid;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select * into v_group
  from public.d_groups g
  where g.id = p_d_group_id
  for share;

  if not found then
    raise exception 'd_group_not_found' using errcode = 'PT404';
  end if;

  if not private.leads_d_group(v_group.id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  if v_group.status <> 'ACTIVE' then
    raise exception 'd_group_not_active' using errcode = 'PT409';
  end if;

  select dgm.* into v_leader
  from public.d_group_memberships dgm
  where dgm.d_group_id = v_group.id
    and dgm.responsibility = 'LEADER'
    and dgm.ended_at is null;

  perform 1
  from public.church_memberships m
  where m.id = v_leader.church_membership_id
  for update;

  if exists (
    select 1
    from public.d_group_memberships dgm
    where dgm.church_membership_id = v_leader.church_membership_id
      and dgm.d_group_id = v_group.id
      and dgm.responsibility = 'DISCIPLER'
      and dgm.ended_at is null
  ) then
    raise exception 'already_discipler' using errcode = 'PT409';
  end if;

  insert into public.d_group_memberships
    (d_group_id, church_membership_id, responsibility, started_at, assigned_by)
  values (v_group.id, v_leader.church_membership_id, 'DISCIPLER', now(), v_uid)
  returning id into v_dgm;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_group.church_id,
    v_uid,
    'D_GROUP_MEMBER_ADDED',
    'd_group_memberships',
    v_dgm,
    jsonb_build_object(
      'd_group_id', v_group.id,
      'church_membership_id', v_leader.church_membership_id,
      'responsibility', 'DISCIPLER',
      'self', true
    )
  );

  return query select v_dgm;
end;
$$;

comment on function public.add_self_as_discipler(uuid) is
  'The group''s Leader only. Adds a DISCIPLER responsibility for the caller in the group they lead. Audited as D_GROUP_MEMBER_ADDED.';


-- Plan decision 5: removal is direct. Ends a DISCIPLER or DISCIPLE row
-- and every active assignment on either side of it. LEADER rows are
-- replaced through assign_d_group_leader(), never ended here.
--
-- The target's membership is not required to be ACTIVE: removing a
-- person from a group must stay possible whatever their church status.
create function public.end_d_group_membership(p_d_group_membership_id uuid)
returns table (d_group_membership_id uuid, ended_at timestamptz)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := (select auth.uid());
  v_dgm      public.d_group_memberships%rowtype;
  v_church   uuid;
  v_ended    uuid[];
  v_now      timestamptz := now();
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select * into v_dgm
  from public.d_group_memberships dgm
  where dgm.id = p_d_group_membership_id;

  if not found then
    raise exception 'd_group_membership_not_found' using errcode = 'PT404';
  end if;

  if not private.can_manage_d_group_members(v_dgm.d_group_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  perform 1
  from public.church_memberships m
  where m.id = v_dgm.church_membership_id
  for update;

  select * into v_dgm
  from public.d_group_memberships dgm
  where dgm.id = p_d_group_membership_id
  for update;

  if v_dgm.ended_at is not null then
    raise exception 'd_group_membership_not_active' using errcode = 'PT409';
  end if;

  if v_dgm.responsibility = 'LEADER' then
    raise exception 'leader_cannot_be_ended' using errcode = 'PT409';
  end if;

  -- MONITORING HOOK: resolve the ACTIVE CONSECUTIVE_MISSED_MEETINGS
  -- condition of each assignment ended here.
  with ended as (
    update public.discipler_assignments a
    set ended_at = v_now
    where a.ended_at is null
      and (a.discipler_d_group_membership_id = v_dgm.id
           or a.disciple_d_group_membership_id = v_dgm.id)
    returning a.id
  )
  select coalesce(array_agg(ended.id), '{}') into v_ended from ended;

  update public.d_group_memberships dgm
  set ended_at = v_now
  where dgm.id = v_dgm.id;

  select g.church_id into v_church
  from public.d_groups g
  where g.id = v_dgm.d_group_id;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_church,
    v_uid,
    'D_GROUP_MEMBER_ENDED',
    'd_group_memberships',
    v_dgm.id,
    jsonb_build_object(
      'd_group_id', v_dgm.d_group_id,
      'church_membership_id', v_dgm.church_membership_id,
      'responsibility', v_dgm.responsibility,
      'ended_discipler_assignment_ids', to_jsonb(v_ended)
    )
  );

  return query select v_dgm.id, v_now;
end;
$$;

comment on function public.end_d_group_membership(uuid) is
  'Coordinator or the group''s Leader. Ends an active DISCIPLER or DISCIPLE responsibility and its discipler assignments on either side. LEADER rows are refused. Audited as D_GROUP_MEMBER_ENDED.';


-- Plan decision 4: one operation pairs, re-pairs or unpairs. A null
-- p_discipler_d_group_membership_id unpairs. Replaces the separate
-- assign_discipler() / reassign_discipler() names of RBAC section 10.
create function public.set_discipler(
  p_disciple_d_group_membership_id  uuid,
  p_discipler_d_group_membership_id uuid
)
returns table (outcome text, discipler_assignment_id uuid)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid       uuid := (select auth.uid());
  v_disciple  public.d_group_memberships%rowtype;
  v_discipler public.d_group_memberships%rowtype;
  v_current   public.discipler_assignments%rowtype;
  v_church    uuid;
  v_status    public.membership_status;
  v_new       uuid;
  v_action    text;
  v_outcome   text;
  v_now       timestamptz := now();
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select * into v_disciple
  from public.d_group_memberships dgm
  where dgm.id = p_disciple_d_group_membership_id;

  if not found then
    raise exception 'd_group_membership_not_found' using errcode = 'PT404';
  end if;

  if not private.can_manage_d_group_members(v_disciple.d_group_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  select m.status into v_status
  from public.church_memberships m
  where m.id = v_disciple.church_membership_id
  for update;

  select * into v_disciple
  from public.d_group_memberships dgm
  where dgm.id = p_disciple_d_group_membership_id
  for update;

  if v_disciple.responsibility <> 'DISCIPLE' or v_disciple.ended_at is not null then
    raise exception 'not_an_active_disciple' using errcode = 'PT409';
  end if;

  if v_status <> 'ACTIVE' then
    raise exception 'member_not_active' using errcode = 'PT409';
  end if;

  select * into v_current
  from public.discipler_assignments a
  where a.disciple_d_group_membership_id = v_disciple.id
    and a.ended_at is null
  for update;

  if p_discipler_d_group_membership_id is null then
    if v_current.id is null then
      raise exception 'not_paired' using errcode = 'PT409';
    end if;
    v_action  := 'DISCIPLER_UNASSIGNED';
    v_outcome := 'UNASSIGNED';
  else
    select * into v_discipler
    from public.d_group_memberships dgm
    where dgm.id = p_discipler_d_group_membership_id
    for share;

    if not found then
      raise exception 'd_group_membership_not_found' using errcode = 'PT404';
    end if;

    if v_discipler.responsibility <> 'DISCIPLER'
       or v_discipler.ended_at is not null
       or v_discipler.d_group_id <> v_disciple.d_group_id then
      raise exception 'not_an_active_discipler' using errcode = 'PT409';
    end if;

    select m.status into v_status
    from public.church_memberships m
    where m.id = v_discipler.church_membership_id;

    if v_status <> 'ACTIVE' then
      raise exception 'member_not_active' using errcode = 'PT409';
    end if;

    if v_current.discipler_d_group_membership_id = v_discipler.id then
      raise exception 'already_paired' using errcode = 'PT409';
    end if;

    if v_current.id is null then
      v_action  := 'DISCIPLER_ASSIGNED';
      v_outcome := 'ASSIGNED';
    else
      v_action  := 'DISCIPLER_REASSIGNED';
      v_outcome := 'REASSIGNED';
    end if;
  end if;

  if v_current.id is not null then
    -- MONITORING HOOK: resolve the ACTIVE CONSECUTIVE_MISSED_MEETINGS
    -- condition belonging to the assignment ended here.
    update public.discipler_assignments a
    set ended_at = v_now
    where a.id = v_current.id;
  end if;

  if v_discipler.id is not null then
    insert into public.discipler_assignments
      (d_group_id, discipler_d_group_membership_id,
       disciple_d_group_membership_id, assigned_by, started_at)
    values
      (v_disciple.d_group_id, v_discipler.id, v_disciple.id, v_uid, v_now)
    returning id into v_new;
  end if;

  select g.church_id into v_church
  from public.d_groups g
  where g.id = v_disciple.d_group_id;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_church,
    v_uid,
    v_action,
    'discipler_assignments',
    coalesce(v_new, v_current.id),
    jsonb_build_object(
      'd_group_id', v_disciple.d_group_id,
      'disciple_d_group_membership_id', v_disciple.id,
      'from_discipler_d_group_membership_id', v_current.discipler_d_group_membership_id,
      'to_discipler_d_group_membership_id', v_discipler.id,
      'ended_discipler_assignment_id', v_current.id
    )
  );

  return query select v_outcome, v_new;
end;
$$;

comment on function public.set_discipler(uuid, uuid) is
  'Coordinator or the group''s Leader. Pairs, re-pairs or (with a null discipler) unpairs a Disciple, ending the previous assignment. Audited as DISCIPLER_ASSIGNED / _REASSIGNED / _UNASSIGNED.';


-- Read-only. The people a Coordinator or Leader can choose from when
-- creating a group or inviting: names, current placement and the
-- pending flag, never phone numbers.
--
--   p_d_group_id given  -> the group's church; Coordinator sees every
--                          ACTIVE member, the group's Leader only the
--                          unplaced ones
--   p_d_group_id null   -> p_church_id, Coordinator only (the Leader
--                          picker when creating a group)
create function public.list_placeable_members(
  p_d_group_id uuid default null,
  p_church_id  uuid default null
)
returns table (
  church_membership_id         uuid,
  full_name                    text,
  current_d_group_id           uuid,
  current_d_group_name         text,
  current_responsibilities     public.d_group_responsibility[],
  has_pending_invitation       boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid         uuid := (select auth.uid());
  v_church      uuid;
  v_unplaced_only boolean;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  if p_d_group_id is not null then
    select g.church_id into v_church
    from public.d_groups g
    where g.id = p_d_group_id;

    if not found then
      raise exception 'd_group_not_found' using errcode = 'PT404';
    end if;

    if not private.can_manage_d_group_members(p_d_group_id) then
      raise exception 'not_authorized' using errcode = 'PT403';
    end if;
  else
    v_church := p_church_id;
  end if;

  if v_church is null or (p_d_group_id is null and not private.is_church_coordinator(v_church)) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  v_unplaced_only := not private.is_church_coordinator(v_church);

  return query
    select
      m.id,
      p.full_name,
      cur.d_group_id,
      cur.d_group_name,
      cur.responsibilities,
      exists (
        select 1
        from public.d_group_invitations i
        where i.church_membership_id = m.id
          and i.status = 'PENDING'
          and i.expires_at > now()
      )
    from public.church_memberships m
    join public.profiles p on p.id = m.user_id
    left join lateral (
      select
        dgm.d_group_id,
        g.name as d_group_name,
        array_agg(dgm.responsibility order by dgm.responsibility) as responsibilities
      from public.d_group_memberships dgm
      join public.d_groups g on g.id = dgm.d_group_id
      where dgm.church_membership_id = m.id
        and dgm.ended_at is null
      group by dgm.d_group_id, g.name
    ) cur on true
    where m.church_id = v_church
      and m.status = 'ACTIVE'
      and (not v_unplaced_only or cur.d_group_id is null)
    order by lower(p.full_name), m.id;
end;
$$;

comment on function public.list_placeable_members(uuid, uuid) is
  'Coordinator or the group''s Leader. ACTIVE members with their current D Group, responsibilities and pending-invitation flag; a Leader sees only unplaced members. No phone numbers.';


-- Read-only. The caller's one live invitation, if any.
create function public.get_my_pending_invitation()
returns table (
  invitation_id   uuid,
  d_group_id      uuid,
  d_group_name    text,
  responsibility  public.d_group_responsibility,
  invited_by_name text,
  created_at      timestamptz,
  expires_at      timestamptz
)
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

  return query
    select i.id, g.id, g.name, i.responsibility, p.full_name,
           i.created_at, i.expires_at
    from public.d_group_invitations i
    join public.church_memberships m on m.id = i.church_membership_id
    join public.d_groups g on g.id = i.d_group_id
    join public.profiles p on p.id = i.invited_by
    where m.user_id = v_uid
      and m.status = 'ACTIVE'
      and i.status = 'PENDING'
      and i.expires_at > now();
end;
$$;

comment on function public.get_my_pending_invitation() is
  'The caller''s live (PENDING, unexpired) D Group invitation: group, responsibility, inviter name and expiry.';


-- Read-only. The caller's group as a Discipler or Disciple sees it:
-- every active responsibility by name, with phone numbers only where
-- the caller may see them (Plan decision 8): their own Leader, their
-- own Discipler, and, for a Discipler, their assigned Disciples (RBAC
-- section 3, profiles: Discipler -> assigned Disciples). One row per
-- responsibility, so a Leader who is also a Discipler appears twice.
create function public.get_my_d_group_roster()
returns table (
  d_group_id            uuid,
  d_group_name          text,
  d_group_membership_id uuid,
  church_membership_id  uuid,
  full_name             text,
  responsibility        public.d_group_responsibility,
  phone                 text,
  is_me                 boolean,
  is_my_leader          boolean,
  is_my_discipler       boolean,
  is_my_disciple        boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := (select auth.uid());
  v_me    uuid;
  v_group uuid;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select dgm.church_membership_id, dgm.d_group_id into v_me, v_group
  from public.d_group_memberships dgm
  join public.church_memberships m on m.id = dgm.church_membership_id
  where m.user_id = v_uid
    and m.status = 'ACTIVE'
    and dgm.ended_at is null
  limit 1;

  if v_group is null then
    return;
  end if;

  return query
    with mine as (
      select dgm.id, dgm.responsibility
      from public.d_group_memberships dgm
      where dgm.church_membership_id = v_me
        and dgm.d_group_id = v_group
        and dgm.ended_at is null
    ),
    my_discipler as (
      select dr.church_membership_id
      from public.discipler_assignments a
      join public.d_group_memberships dr on dr.id = a.discipler_d_group_membership_id
      where a.ended_at is null
        and a.disciple_d_group_membership_id in (select mine.id from mine)
    ),
    my_disciples as (
      select dd.church_membership_id
      from public.discipler_assignments a
      join public.d_group_memberships dd on dd.id = a.disciple_d_group_membership_id
      where a.ended_at is null
        and dd.ended_at is null
        and a.discipler_d_group_membership_id in (select mine.id from mine)
    )
    select
      g.id,
      g.name,
      dgm.id,
      dgm.church_membership_id,
      p.full_name,
      dgm.responsibility,
      case
        when dgm.church_membership_id = v_me then p.phone
        when (dgm.responsibility = 'LEADER'
              and exists (select 1 from mine where mine.responsibility <> 'LEADER'))
          or dgm.church_membership_id in (select md.church_membership_id from my_discipler md)
          or dgm.church_membership_id in (select mds.church_membership_id from my_disciples mds)
          then p.phone
        else null
      end,
      dgm.church_membership_id = v_me,
      dgm.responsibility = 'LEADER' and dgm.church_membership_id <> v_me,
      dgm.church_membership_id in (select md.church_membership_id from my_discipler md),
      dgm.church_membership_id in (select mds.church_membership_id from my_disciples mds)
    from public.d_group_memberships dgm
    join public.d_groups g on g.id = dgm.d_group_id
    join public.church_memberships m on m.id = dgm.church_membership_id
    join public.profiles p on p.id = m.user_id
    where dgm.d_group_id = v_group
      and dgm.ended_at is null
    order by
      case dgm.responsibility
        when 'LEADER' then 0
        when 'DISCIPLER' then 1
        else 2
      end,
      lower(p.full_name);
end;
$$;

comment on function public.get_my_d_group_roster() is
  'The caller''s D Group roster by name, with phone numbers only for their own Leader, own Discipler and, for a Discipler, their assigned Disciples.';


do $$
declare
  v_fn text;
begin
  foreach v_fn in array array[
    'public.create_d_group(text, text, uuid)',
    'public.assign_d_group_leader(uuid, uuid)',
    'public.invite_to_d_group(uuid, uuid, public.d_group_responsibility)',
    'public.withdraw_d_group_invitation(uuid)',
    'public.respond_to_d_group_invitation(uuid, boolean)',
    'public.add_self_as_discipler(uuid)',
    'public.end_d_group_membership(uuid)',
    'public.set_discipler(uuid, uuid)',
    'public.list_placeable_members(uuid, uuid)',
    'public.get_my_pending_invitation()',
    'public.get_my_d_group_roster()'
  ]
  loop
    execute format('revoke execute on function %s from public, anon', v_fn);
    execute format('grant execute on function %s to authenticated, service_role', v_fn);
  end loop;
end
$$;


-- ============================================================
-- 6. ROW LEVEL SECURITY
-- ============================================================
--
-- SELECT only. There are no INSERT, UPDATE or DELETE policies and no
-- such grants; every write goes through section 5. Admin-only users
-- receive no D Group data (Plan decision 8): ADMIN appears in none of
-- these predicates.

-- ------------------------------------------------------------
-- d_groups
-- ------------------------------------------------------------
-- RBAC section 3: COORDINATOR all church groups; LEADER, DISCIPLER and
-- DISCIPLE own group. An invitee sees the group name only through
-- get_my_pending_invitation().

create policy d_groups_select_coordinator
  on public.d_groups
  for select
  to authenticated
  using (private.is_church_coordinator(church_id));

create policy d_groups_select_own_group
  on public.d_groups
  for select
  to authenticated
  using (private.has_active_responsibility_in(id));


-- ------------------------------------------------------------
-- d_group_memberships
-- ------------------------------------------------------------
-- Coordinator church-wide and the Leader their own group, history
-- included. A Discipler sees their group's active rows. A Disciple sees
-- their own rows, their Leader's row and their own Discipler's row.

create policy d_group_memberships_select_manager
  on public.d_group_memberships
  for select
  to authenticated
  using (private.can_manage_d_group_members(d_group_id));

create policy d_group_memberships_select_own
  on public.d_group_memberships
  for select
  to authenticated
  using (private.is_my_membership(church_membership_id));

create policy d_group_memberships_select_discipler_group
  on public.d_group_memberships
  for select
  to authenticated
  using (
    ended_at is null
    and private.has_active_responsibility_in(d_group_id, 'DISCIPLER')
  );

create policy d_group_memberships_select_my_leader_discipler
  on public.d_group_memberships
  for select
  to authenticated
  using (
    ended_at is null
    and responsibility in ('LEADER', 'DISCIPLER')
    and private.is_my_leader_or_discipler(church_membership_id)
  );


-- ------------------------------------------------------------
-- discipler_assignments
-- ------------------------------------------------------------
-- RBAC section 3: Coordinator church-wide, Leader own group, Discipler
-- own assignments, Disciple own active relationship.

create policy discipler_assignments_select_manager
  on public.discipler_assignments
  for select
  to authenticated
  using (private.can_manage_d_group_members(d_group_id));

create policy discipler_assignments_select_discipler
  on public.discipler_assignments
  for select
  to authenticated
  using (private.owns_d_group_membership(discipler_d_group_membership_id));

create policy discipler_assignments_select_disciple
  on public.discipler_assignments
  for select
  to authenticated
  using (
    ended_at is null
    and private.owns_d_group_membership(disciple_d_group_membership_id)
  );


-- ------------------------------------------------------------
-- d_group_invitations
-- ------------------------------------------------------------
-- Coordinator church-wide and the Leader their own group's, every
-- status (a decline is shown to the inviter). The invitee their own.

create policy d_group_invitations_select_manager
  on public.d_group_invitations
  for select
  to authenticated
  using (private.can_manage_d_group_members(d_group_id));

create policy d_group_invitations_select_invitee
  on public.d_group_invitations
  for select
  to authenticated
  using (private.is_my_membership(church_membership_id));


-- ------------------------------------------------------------
-- church_memberships and profiles
-- ------------------------------------------------------------
-- RBAC section 3: LEADER -> members of own D Group (and, here, people
-- invited to it); DISCIPLER -> assigned Disciples and own Leader;
-- DISCIPLE -> own Leader and own Discipler. Additive to the own-row
-- and Admin/Coordinator policies. Group mates beyond these are seen by
-- name only, through get_my_d_group_roster().

create policy church_memberships_select_ministry
  on public.church_memberships
  for select
  to authenticated
  using (private.can_view_membership_in_ministry(id));

create policy profiles_select_ministry
  on public.profiles
  for select
  to authenticated
  using (private.can_view_profile_in_ministry(id));
