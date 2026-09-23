-- ============================================================
-- DiscipleTrack - Migration 002: Auth / Profile Database Logic
-- ============================================================
--
-- Database logic required by the Auth + Profile vertical slice.
--
-- Scope of this migration:
--   - handle_new_user(): creates a profiles row from auth.users
--   - set_updated_at(): generic updated_at maintenance
--   - updated_at triggers on the 13 tables that carry the column
--
-- Deliberately NOT in this migration:
--   RLS policies (Migration 003), controlled operations / RPCs,
--   temporal overlap enforcement, same-church integrity,
--   participant validity, no-self-attendance, last-Coordinator
--   protection, occurred_at immutability, monitoring.
--
-- Those guard tables that no current feature touches. They arrive
-- with the slice that exercises them, so they land with tests.
--
-- References:
--   DC   = docs/database/DATABASE_CONSTRAINTS.md
--   RBAC = docs/security/RBAC_RLS_MATRIX.md
-- ============================================================


-- ============================================================
-- 1. PROFILE CREATION FROM AUTH
-- ============================================================
--
-- DC section 1:
--   - a profiles row is created automatically from auth.users
--     through a trusted database trigger, not by the client
--   - profiles.full_name is required and must never be blank
--   - registration supplies it through Supabase Auth user metadata
--   - the value is trimmed before use
--   - a missing or blank value is REJECTED
--   - the trigger must never invent a placeholder name
--
-- SECURITY DEFINER so the insert runs as the function owner and is
-- not blocked by RLS on profiles. search_path is emptied so every
-- reference must be schema-qualified, which prevents a malicious
-- search_path from redirecting them.
--
-- Raising here aborts the enclosing auth.users INSERT, so a
-- rejected signup leaves no orphaned auth row. DC section 1 records
-- that the exact observed behaviour was unverified; the integration
-- tests for this milestone confirm it.

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_full_name text;
begin
  v_full_name := trim(coalesce(new.raw_user_meta_data ->> 'full_name', ''));

  if v_full_name = '' then
    raise exception 'full_name is required in user metadata'
      using errcode = 'check_violation';
  end if;

  insert into public.profiles (id, full_name)
  values (new.id, v_full_name);

  return new;
end;
$$;

comment on function public.handle_new_user() is
  'Creates the profiles row for a new auth user. Rejects missing or blank full_name metadata rather than substituting a placeholder. See DATABASE_CONSTRAINTS.md section 1.';

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();


-- ============================================================
-- 2. UPDATED_AT MAINTENANCE
-- ============================================================
--
-- Migration 001 gives every updated_at column a default of now(),
-- which is correct on INSERT but goes stale on UPDATE. This keeps
-- it truthful regardless of write path.
--
-- Attached only to the 13 tables that actually carry an updated_at
-- column. The other 8 tables are append-only or lifecycle-tracked
-- (ended_at, voided_at, resolved_at) and have no update timestamp
-- by design.

create function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

comment on function public.set_updated_at() is
  'Sets updated_at to now() on UPDATE. Attached to every table carrying an updated_at column.';

create trigger set_updated_at before update on public.announcements
  for each row execute function public.set_updated_at();

create trigger set_updated_at before update on public.church_memberships
  for each row execute function public.set_updated_at();

create trigger set_updated_at before update on public.church_settings
  for each row execute function public.set_updated_at();

create trigger set_updated_at before update on public.churches
  for each row execute function public.set_updated_at();

create trigger set_updated_at before update on public.curricula
  for each row execute function public.set_updated_at();

create trigger set_updated_at before update on public.curriculum_lessons
  for each row execute function public.set_updated_at();

create trigger set_updated_at before update on public.d_group_gatherings
  for each row execute function public.set_updated_at();

create trigger set_updated_at before update on public.d_groups
  for each row execute function public.set_updated_at();

create trigger set_updated_at before update on public.disciple_lesson_progress
  for each row execute function public.set_updated_at();

create trigger set_updated_at before update on public.discipleship_meetings
  for each row execute function public.set_updated_at();

create trigger set_updated_at before update on public.follow_ups
  for each row execute function public.set_updated_at();

create trigger set_updated_at before update on public.gathering_attendance
  for each row execute function public.set_updated_at();

create trigger set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
