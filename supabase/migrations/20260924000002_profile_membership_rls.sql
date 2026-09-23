-- ============================================================
-- DiscipleTrack - Migration 003: Profile / Membership RLS
-- ============================================================
--
-- Row Level Security for the Auth + Profile vertical slice ONLY.
--
-- Migration 001 enabled RLS on all 21 tables with zero policies,
-- so everything is currently deny-by-default. This migration opens
-- the minimum required for a user to see and edit their own
-- profile and read their own church membership.
--
-- The complete matrix in RBAC_RLS_MATRIX.md is NOT implemented
-- here. The other 19 tables stay closed, and the other role scopes
-- on these two tables arrive with the slices that need them.
--
-- PostgreSQL ORs permissive policies together, so adding
-- COORDINATOR / LEADER / DISCIPLER scopes later is purely
-- additive. Nothing written here has to be rewritten.
--
-- auth.uid() is wrapped in a scalar subquery so PostgreSQL
-- evaluates it once per statement rather than once per row.
--
-- References:
--   RBAC = docs/security/RBAC_RLS_MATRIX.md
--   DC   = docs/database/DATABASE_CONSTRAINTS.md
-- ============================================================


-- ============================================================
-- 1. PROFILES
-- ============================================================
--
-- RBAC section 3, profiles:
--
--   SELECT  User -> own profile
--   INSERT  Not permitted for clients. The row is created by the
--           trusted trigger in Migration 002.
--   UPDATE  User -> own allowed fields, currently full_name,
--           phone and avatar_url. profiles.id is immutable.
--   DELETE  Not permitted for clients.
--
-- Only the "own profile" scope is implemented now. Coordinator,
-- Leader, Discipler and Admin read scopes arrive with the features
-- that need them.

create policy profiles_select_own
  on public.profiles
  for select
  to authenticated
  using (id = (select auth.uid()));

create policy profiles_update_own
  on public.profiles
  for update
  to authenticated
  using      (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- No INSERT policy: clients may never create a profile directly.
-- No DELETE policy: DC section 12, no client-reachable DELETE path.


-- ------------------------------------------------------------
-- Column-level UPDATE restriction
-- ------------------------------------------------------------
--
-- RLS is row-level and cannot express "only these columns".
-- Column privileges are the only PostgreSQL mechanism that
-- implements the RBAC rule above, so the broad UPDATE grant is
-- replaced with a narrow one.
--
-- This also makes profiles.id immutable in practice and prevents a
-- client from forging created_at or updated_at.

revoke update on public.profiles from authenticated;

grant update (full_name, phone, avatar_url)
  on public.profiles
  to authenticated;


-- ============================================================
-- 2. CHURCH MEMBERSHIPS
-- ============================================================
--
-- RBAC section 3, church_memberships:
--
--   SELECT  ADMIN       -> own church
--           COORDINATOR -> own church
--           LEADER      -> members of own D Group
--           DISCIPLER   -> assigned Disciples
--           DISCIPLE    -> self
--
-- Only the "self" scope is implemented now. It exists so the
-- router can branch on real membership state instead of a
-- hardcoded value.
--
-- church_memberships.user_id references profiles.id, which is the
-- same UUID as auth.users.id, so comparing it to auth.uid() is
-- correct.
--
-- RBAC section 1a: a PENDING member may see their own pending
-- membership row. This policy deliberately does not filter on
-- status, because the client must be able to distinguish PENDING
-- from ACTIVE from no membership at all in order to route.
--
-- INSERT and UPDATE remain closed. Membership creation and status
-- transitions are controlled operations, not client writes.

create policy church_memberships_select_own
  on public.church_memberships
  for select
  to authenticated
  using (user_id = (select auth.uid()));
