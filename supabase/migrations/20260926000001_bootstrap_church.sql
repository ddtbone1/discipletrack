-- ============================================================
-- DiscipleTrack - Migration 004: Church Bootstrap
-- ============================================================
--
-- Implements DATABASE_CONSTRAINTS.md section 0 (Bootstrap and
-- Initial State) as trusted database tooling.
--
-- Scope of this migration:
--   - church_settings.consecutive_missed_meeting_threshold, which the
--     ERD already defines and bootstrap is required to set
--   - the `private` schema: database objects that must never be
--     reachable through PostgREST (the API exposes only `public`
--     and `graphql_public`)
--   - private.generate_join_code(): cryptographically random codes
--     in the fixed join-code format
--   - private.bootstrap_church(): the seven records of DC section 0
--     in one transaction, idempotent on the supplied church id
--   - private.assert_bootstrap_postconditions(): the assertable
--     postconditions, used by the function and by tests
--
-- Bootstrap is deliberately absent from the controlled-operations
-- list in RBAC_RLS_MATRIX.md. It runs in the migration or
-- service-role context only: EXECUTE is revoked from anon and
-- authenticated, and the `private` schema keeps it out of the API
-- entirely. Locally it is invoked by supabase/seed.sql; on a hosted
-- project by tool/bootstrap_church.ps1 over psql.
--
-- Join-code format (DC section 1 leaves alphabet and length to the
-- implementation; the entropy requirement is not optional):
--
--   ^[A-HJ-NP-Z2-9]{10}$
--
--   32 characters, excluding I, O, 0 and 1 so codes can be read
--   aloud and typed without ambiguity. 32^10 is roughly 1.1e15
--   possibilities, which together with the per-user rate limit in
--   Migration 005 makes guessing impractical.
--
-- Migrations 001 to 003 are not modified.
--
-- References:
--   DC   = docs/database/DATABASE_CONSTRAINTS.md
--   ERD  = docs/erd/discipletrack.dbml
--   RBAC = docs/security/RBAC_RLS_MATRIX.md
-- ============================================================


-- ============================================================
-- 1. CHURCH SETTINGS: MISSED-MEETING THRESHOLD
-- ============================================================
--
-- ERD table 20 and DC section 0 both specify this column. Migration
-- 001 predates the Discipleship Meeting Attendance revision
-- (ADR-009), so it is added here, where bootstrap first needs it.
-- Nothing else from that revision is implemented in this migration.

alter table public.church_settings
  add column consecutive_missed_meeting_threshold integer not null default 3;

comment on column public.church_settings.consecutive_missed_meeting_threshold is
  'Consecutive ABSENT discipleship meetup outcomes that raise CONSECUTIVE_MISSED_MEETINGS for a Disciple. Default 3. See DATABASE_CONSTRAINTS.md section 6 and ADR-009.';


-- ============================================================
-- 2. PRIVATE SCHEMA
-- ============================================================
--
-- PostgREST serves only the schemas listed in supabase/config.toml
-- [api].schemas. Objects here can be referenced by RLS policies and
-- by public functions, but have no API endpoint.
--
-- authenticated receives USAGE because later policies call helper
-- functions in this schema while evaluating as that role. USAGE
-- alone grants nothing on the objects; each one is granted or
-- revoked explicitly. anon receives nothing.

create schema private;

comment on schema private is
  'Trusted database objects with no PostgREST endpoint: bootstrap, RLS helpers, rate-limit state.';

revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;


-- ============================================================
-- 3. JOIN-CODE GENERATION
-- ============================================================
--
-- 256 is divisible by 32, so mapping each random byte modulo 32
-- onto the alphabet introduces no bias.

create function private.generate_join_code()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_bytes bytea := extensions.gen_random_bytes(10);
  v_code text := '';
begin
  for i in 0..9 loop
    v_code := v_code || substr(v_alphabet, (get_byte(v_bytes, i) % 32) + 1, 1);
  end loop;
  return v_code;
end;
$$;

comment on function private.generate_join_code() is
  'Cryptographically random 10-character join code from the alphabet A-H J-N P-Z 2-9. See DATABASE_CONSTRAINTS.md section 1.';

revoke execute on function private.generate_join_code() from public, anon, authenticated;
grant execute on function private.generate_join_code() to service_role;


-- ============================================================
-- 4. BOOTSTRAP POSTCONDITIONS
-- ============================================================
--
-- DC section 0, Postconditions. Raises on the first failure so a
-- caller sees exactly which invariant is not met. Also serves as
-- the bootstrap test.

create function private.assert_bootstrap_postconditions(
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

  if (
    select count(distinct r.role)
    from public.church_role_assignments r
    where r.church_membership_id = v_membership_id
      and r.ended_at is null
      and r.role in ('ADMIN', 'COORDINATOR')
  ) <> 2 then
    raise exception 'bootstrap: initial user must hold active ADMIN and COORDINATOR roles';
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
      and l.lesson_number between 1 and 12
      and l.required_meetings = 4
  ) <> 12 then
    raise exception 'bootstrap: twelve lessons numbered 1 to 12 with required_meetings = 4 are required';
  end if;
end;
$$;

comment on function private.assert_bootstrap_postconditions(uuid, uuid) is
  'Raises unless the DC section 0 bootstrap postconditions hold for the church and its initial user.';

revoke execute on function private.assert_bootstrap_postconditions(uuid, uuid)
  from public, anon, authenticated;
grant execute on function private.assert_bootstrap_postconditions(uuid, uuid)
  to service_role;


-- ============================================================
-- 5. BOOTSTRAP
-- ============================================================
--
-- DC section 0:
--
--   Inputs        church_id (caller-supplied), church name, the
--                 initial trusted user's auth id; optionally join
--                 code, curriculum name, the twelve lesson titles
--   Preconditions the auth identity and its profiles row exist
--   Records       1. churches            2. church_settings
--                 3. church_memberships  4. church_role_assignments
--                 5. curricula           6. curriculum_lessons
--                 7. audit_events CHURCH_BOOTSTRAPPED
--   Transaction   all seven succeed or none commit
--   Idempotency   keyed on church_id; an existing church is verified
--                 against the postconditions and returned unchanged
--
-- The initial membership carries joined_at but no approved_by /
-- approved_at: bootstrap is a trusted provisioning step, not an
-- approval by a person. Those two columns are written only by
-- approve_church_membership().
--
-- The initial user holds both ADMIN and COORDINATOR. COORDINATOR is
-- required because follow-up escalation terminates there and the
-- Last Coordinator Protection (DC section 1) needs one to exist.

create function private.bootstrap_church(
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
    array(select 'Lesson ' || g::text from generate_series(1, 12) as g)
  );
  if coalesce(array_length(v_titles, 1), 0) <> 12 then
    raise exception 'bootstrap: exactly twelve lesson titles are required';
  end if;

  -- 1. churches
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

  -- 3. church_memberships
  insert into public.church_memberships (church_id, user_id, status, joined_at)
  values (p_church_id, p_initial_user_id, 'ACTIVE', now())
  returning id into v_membership_id;

  -- 4. church_role_assignments
  insert into public.church_role_assignments
    (church_membership_id, role, assigned_by, started_at)
  values
    (v_membership_id, 'ADMIN', p_initial_user_id, now()),
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
  from generate_series(1, 12) as g;

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

comment on function private.bootstrap_church(uuid, text, uuid, text, text, text[]) is
  'Provisions a church workspace per DATABASE_CONSTRAINTS.md section 0. Trusted tooling only; never reachable from the client.';

revoke execute on function private.bootstrap_church(uuid, text, uuid, text, text, text[])
  from public, anon, authenticated;
grant execute on function private.bootstrap_church(uuid, text, uuid, text, text, text[])
  to service_role;
