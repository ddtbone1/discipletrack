-- ============================================================
-- DiscipleTrack - Migration 001: Base Schema
-- ============================================================
--
-- Translates docs/erd/discipletrack.dbml into the initial
-- PostgreSQL schema.
--
-- Scope of this migration:
--   enums, tables, primary keys, ordinary foreign keys,
--   approved UNIQUE constraints, declarative CHECK constraints
--   that are already fully specified, approved indexes
--   (including partial unique indexes), and RLS enabled with
--   zero policies.
--
-- Deliberately NOT in this migration:
--   constraint triggers, the auth.users -> profiles trigger,
--   updated_at maintenance, temporal-overlap exclusion,
--   controlled operations / RPCs, RLS policies, monitoring,
--   bootstrap seed data.
--
-- Conventions applied here:
--   - DBML `varchar` (unbounded) becomes PostgreSQL `text`.
--   - UUID primary keys default to gen_random_uuid(). A
--     caller-supplied id still wins; the default applies only
--     when no id is given. profiles.id and
--     church_settings.church_id are excluded, because they are
--     derived from auth.users.id and churches.id respectively.
--   - created_at / updated_at default to now(). Domain
--     timestamps (started_at, occurred_at, detected_at,
--     recorded_at, performed_at, approved_at, starts_at) have
--     no default and are supplied by the writer.
--   - Every foreign key uses ON DELETE NO ACTION. No domain
--     table has a client-reachable DELETE path, and account
--     deletion has not been designed as an application
--     workflow, so nothing may cascade through history.
--
-- References:
--   ERD  = docs/erd/discipletrack.dbml
--   DC   = docs/database/DATABASE_CONSTRAINTS.md
-- ============================================================


-- ============================================================
-- ENUMS
-- ============================================================

create type church_status as enum ('ACTIVE', 'ARCHIVED');

create type membership_status as enum (
  'PENDING', 'ACTIVE', 'INACTIVE', 'TRANSFERRED', 'ARCHIVED'
);

create type church_role as enum ('ADMIN', 'COORDINATOR');

create type d_group_status as enum ('ACTIVE', 'INACTIVE', 'ARCHIVED');

create type d_group_responsibility as enum ('LEADER', 'DISCIPLER', 'DISCIPLE');

create type gathering_status as enum ('DRAFT', 'FINALIZED', 'CANCELLED');

create type attendance_status as enum ('PRESENT', 'ABSENT', 'LATE', 'EXCUSED');

create type curriculum_status as enum ('ACTIVE', 'INACTIVE', 'ARCHIVED');

create type discipleship_meeting_status as enum ('RECORDED', 'VOIDED');

create type meeting_participation_status as enum ('COUNTED', 'VOIDED');

create type lesson_progress_status as enum (
  'NOT_STARTED', 'IN_PROGRESS', 'READY_FOR_COMPLETION', 'COMPLETED'
);

create type attention_condition_status as enum ('ACTIVE', 'RESOLVED');

create type attention_condition_type as enum ('CONSECUTIVE_ABSENCE');

create type follow_up_status as enum ('REQUIRED', 'IN_PROGRESS', 'RESOLVED');

create type follow_up_reason as enum ('CONSECUTIVE_ABSENCE');

create type follow_up_action_type as enum (
  'CONTACTED', 'SENT_MESSAGE', 'CALLED',
  'PERSONAL_CONVERSATION', 'SCHEDULED_VISIT', 'OTHER'
);

create type follow_up_resolution_type as enum (
  'CARE_COMPLETED', 'CONDITION_CORRECTED', 'ADMINISTRATIVE_CORRECTION'
);

create type announcement_scope as enum ('CHURCH', 'D_GROUP');


-- ============================================================
-- 1. IDENTITY
-- ============================================================

-- profiles.id is the Supabase auth user id. Rows are created by a
-- trusted trigger in Migration 002, never by a client.
create table profiles (
  id          uuid        not null,
  full_name   text        not null,
  phone       text,
  avatar_url  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  constraint profiles_pkey primary key (id),
  constraint profiles_id_fkey foreign key (id)
    references auth.users (id) on delete no action,

  -- DC section 1: full_name is required and must never be blank.
  -- Covers the self-service update path as well as creation.
  constraint profiles_full_name_not_blank_check
    check (length(trim(full_name)) > 0)
);


-- ============================================================
-- 2. CHURCH
-- ============================================================

create table churches (
  id                    uuid          not null default gen_random_uuid(),
  name                  text          not null,
  join_code             text          not null,
  join_code_updated_at  timestamptz,
  status                church_status not null default 'ACTIVE',
  created_at            timestamptz   not null default now(),
  updated_at            timestamptz   not null default now(),

  constraint churches_pkey primary key (id),
  constraint churches_join_code_key unique (join_code)
);


-- ============================================================
-- 20. CHURCH SETTINGS
-- ============================================================
--
-- Declared here so foreign key ordering stays linear.
-- follow_up_due_days is nullable with no database default;
-- bootstrap supplies 7.

create table church_settings (
  church_id                     uuid        not null,
  consecutive_absence_threshold integer     not null default 3,
  follow_up_due_days            integer,
  created_at                    timestamptz not null default now(),
  updated_at                    timestamptz not null default now(),

  constraint church_settings_pkey primary key (church_id),
  constraint church_settings_church_id_fkey foreign key (church_id)
    references churches (id) on delete no action
);


-- ============================================================
-- 3. CHURCH MEMBERSHIP
-- ============================================================

create table church_memberships (
  id           uuid              not null default gen_random_uuid(),
  church_id    uuid              not null,
  user_id      uuid              not null,
  status       membership_status not null default 'PENDING',
  joined_at    timestamptz,
  approved_by  uuid,
  approved_at  timestamptz,
  created_at   timestamptz       not null default now(),
  updated_at   timestamptz       not null default now(),

  constraint church_memberships_pkey primary key (id),
  constraint church_memberships_church_id_fkey foreign key (church_id)
    references churches (id) on delete no action,
  constraint church_memberships_user_id_fkey foreign key (user_id)
    references profiles (id) on delete no action,
  constraint church_memberships_approved_by_fkey foreign key (approved_by)
    references profiles (id) on delete no action,

  -- DC section 1: one membership per person per church. A returning
  -- member reactivates this row so their history stays continuous.
  constraint church_memberships_church_user_key unique (church_id, user_id)
);


-- ============================================================
-- 4. SYSTEM / CHURCH ROLES
-- ============================================================

create table church_role_assignments (
  id                    uuid        not null default gen_random_uuid(),
  church_membership_id  uuid        not null,
  role                  church_role not null,
  assigned_by           uuid        not null,
  started_at            timestamptz not null,
  ended_at              timestamptz,
  created_at            timestamptz not null default now(),

  constraint church_role_assignments_pkey primary key (id),
  constraint church_role_assignments_membership_fkey
    foreign key (church_membership_id)
    references church_memberships (id) on delete no action,
  constraint church_role_assignments_assigned_by_fkey foreign key (assigned_by)
    references profiles (id) on delete no action,

  -- DC section 1
  constraint church_role_assignments_period_check
    check (ended_at is null or ended_at > started_at)
);


-- ============================================================
-- 5. D GROUPS
-- ============================================================

create table d_groups (
  id           uuid           not null default gen_random_uuid(),
  church_id    uuid           not null,
  name         text           not null,
  description  text,
  status       d_group_status not null default 'ACTIVE',
  created_by   uuid           not null,
  created_at   timestamptz    not null default now(),
  updated_at   timestamptz    not null default now(),
  archived_at  timestamptz,

  constraint d_groups_pkey primary key (id),
  constraint d_groups_church_id_fkey foreign key (church_id)
    references churches (id) on delete no action,
  constraint d_groups_created_by_fkey foreign key (created_by)
    references profiles (id) on delete no action
);


-- ============================================================
-- 6. D GROUP MEMBERSHIP / RESPONSIBILITY
-- ============================================================

create table d_group_memberships (
  id                    uuid                   not null default gen_random_uuid(),
  d_group_id            uuid                   not null,
  church_membership_id  uuid                   not null,
  responsibility        d_group_responsibility not null,
  started_at            timestamptz            not null,
  ended_at              timestamptz,
  assigned_by           uuid                   not null,
  created_at            timestamptz            not null default now(),

  constraint d_group_memberships_pkey primary key (id),
  constraint d_group_memberships_d_group_id_fkey foreign key (d_group_id)
    references d_groups (id) on delete no action,
  constraint d_group_memberships_membership_fkey
    foreign key (church_membership_id)
    references church_memberships (id) on delete no action,
  constraint d_group_memberships_assigned_by_fkey foreign key (assigned_by)
    references profiles (id) on delete no action,

  -- DC section 2
  constraint d_group_memberships_period_check
    check (ended_at is null or ended_at > started_at)
);


-- ============================================================
-- 7. DISCIPLER -> DISCIPLE ASSIGNMENT
-- ============================================================
--
-- That the discipler side holds DISCIPLER and the disciple side holds
-- DISCIPLE spans two tables and is enforced by a constraint trigger in
-- Migration 002. See DC section 2, Responsibility Correctness.

create table discipler_assignments (
  id                               uuid        not null default gen_random_uuid(),
  d_group_id                       uuid        not null,
  discipler_d_group_membership_id  uuid        not null,
  disciple_d_group_membership_id   uuid        not null,
  assigned_by                      uuid        not null,
  started_at                       timestamptz not null,
  ended_at                         timestamptz,
  created_at                       timestamptz not null default now(),

  constraint discipler_assignments_pkey primary key (id),
  constraint discipler_assignments_d_group_id_fkey foreign key (d_group_id)
    references d_groups (id) on delete no action,
  constraint discipler_assignments_discipler_fkey
    foreign key (discipler_d_group_membership_id)
    references d_group_memberships (id) on delete no action,
  constraint discipler_assignments_disciple_fkey
    foreign key (disciple_d_group_membership_id)
    references d_group_memberships (id) on delete no action,
  constraint discipler_assignments_assigned_by_fkey foreign key (assigned_by)
    references profiles (id) on delete no action,

  -- DC section 2
  constraint discipler_assignments_period_check
    check (ended_at is null or ended_at > started_at)
);


-- ============================================================
-- 8. D GROUP GATHERINGS
-- ============================================================

create table d_group_gatherings (
  id            uuid             not null default gen_random_uuid(),
  d_group_id    uuid             not null,
  title         text,
  topic         text,
  notes         text,
  starts_at     timestamptz      not null,
  status        gathering_status not null default 'DRAFT',
  created_by    uuid             not null,
  finalized_by  uuid,
  finalized_at  timestamptz,
  cancelled_by  uuid,
  cancelled_at  timestamptz,
  created_at    timestamptz      not null default now(),
  updated_at    timestamptz      not null default now(),

  constraint d_group_gatherings_pkey primary key (id),
  constraint d_group_gatherings_d_group_id_fkey foreign key (d_group_id)
    references d_groups (id) on delete no action,
  constraint d_group_gatherings_created_by_fkey foreign key (created_by)
    references profiles (id) on delete no action,
  constraint d_group_gatherings_finalized_by_fkey foreign key (finalized_by)
    references profiles (id) on delete no action,
  constraint d_group_gatherings_cancelled_by_fkey foreign key (cancelled_by)
    references profiles (id) on delete no action,

  -- DC section 3, Gathering State Check. Allowed transitions
  -- (DRAFT -> FINALIZED, DRAFT -> CANCELLED) are enforced by the
  -- controlled operations, not here.
  constraint d_group_gatherings_status_state_check check (
    (status = 'DRAFT'
      and finalized_by is null and finalized_at is null
      and cancelled_by is null and cancelled_at is null)
    or
    (status = 'FINALIZED'
      and finalized_by is not null and finalized_at is not null
      and cancelled_by is null and cancelled_at is null)
    or
    (status = 'CANCELLED'
      and cancelled_by is not null and cancelled_at is not null
      and finalized_by is null and finalized_at is null)
  )
);


-- ============================================================
-- 9. GATHERING ATTENDANCE
-- ============================================================
--
-- The no-self-attendance rule (recorded_by must never identify the
-- same person as church_membership_id) spans three tables and is
-- enforced by a constraint trigger in Migration 002. See DC section 3.

create table gathering_attendance (
  id                    uuid              not null default gen_random_uuid(),
  gathering_id          uuid              not null,
  church_membership_id  uuid              not null,
  status                attendance_status not null,
  recorded_by           uuid              not null,
  recorded_at           timestamptz       not null,
  updated_at            timestamptz       not null default now(),

  constraint gathering_attendance_pkey primary key (id),
  constraint gathering_attendance_gathering_id_fkey foreign key (gathering_id)
    references d_group_gatherings (id) on delete no action,
  constraint gathering_attendance_membership_fkey
    foreign key (church_membership_id)
    references church_memberships (id) on delete no action,
  constraint gathering_attendance_recorded_by_fkey foreign key (recorded_by)
    references profiles (id) on delete no action,

  -- DC section 3: one attendance record per member per gathering.
  constraint gathering_attendance_gathering_membership_key
    unique (gathering_id, church_membership_id)
);


-- ============================================================
-- 10. CURRICULUM
-- ============================================================

create table curricula (
  id           uuid              not null default gen_random_uuid(),
  church_id    uuid              not null,
  name         text              not null,
  description  text,
  status       curriculum_status not null default 'ACTIVE',
  created_at   timestamptz       not null default now(),
  updated_at   timestamptz       not null default now(),

  constraint curricula_pkey primary key (id),
  constraint curricula_church_id_fkey foreign key (church_id)
    references churches (id) on delete no action
);


-- ============================================================
-- 11. CURRICULUM LESSONS
-- ============================================================

create table curriculum_lessons (
  id                 uuid        not null default gen_random_uuid(),
  curriculum_id      uuid        not null,
  lesson_number      integer     not null,
  title              text        not null,
  description        text,
  required_meetings  integer     not null default 4,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),

  constraint curriculum_lessons_pkey primary key (id),
  constraint curriculum_lessons_curriculum_id_fkey foreign key (curriculum_id)
    references curricula (id) on delete no action,

  -- DC section 4
  constraint curriculum_lessons_curriculum_number_key
    unique (curriculum_id, lesson_number),
  constraint curriculum_lessons_required_meetings_check
    check (required_meetings > 0)
);


-- ============================================================
-- 12. DISCIPLESHIP MEETINGS
-- ============================================================
--
-- occurred_at immutability is enforced by a trigger in Migration 002.
-- Sequential lesson eligibility belongs to
-- record_discipleship_meeting(). See DC section 4.

create table discipleship_meetings (
  id                               uuid                        not null default gen_random_uuid(),
  d_group_id                       uuid                        not null,
  discipler_d_group_membership_id  uuid                        not null,
  lesson_id                        uuid                        not null,
  occurred_at                      timestamptz                 not null,
  status                           discipleship_meeting_status not null default 'RECORDED',
  notes                            text,
  recorded_by                      uuid                        not null,
  voided_by                        uuid,
  voided_at                        timestamptz,
  created_at                       timestamptz                 not null default now(),
  updated_at                       timestamptz                 not null default now(),

  constraint discipleship_meetings_pkey primary key (id),
  constraint discipleship_meetings_d_group_id_fkey foreign key (d_group_id)
    references d_groups (id) on delete no action,
  constraint discipleship_meetings_discipler_fkey
    foreign key (discipler_d_group_membership_id)
    references d_group_memberships (id) on delete no action,
  constraint discipleship_meetings_lesson_id_fkey foreign key (lesson_id)
    references curriculum_lessons (id) on delete no action,
  constraint discipleship_meetings_recorded_by_fkey foreign key (recorded_by)
    references profiles (id) on delete no action,
  constraint discipleship_meetings_voided_by_fkey foreign key (voided_by)
    references profiles (id) on delete no action,

  -- DC section 4, Voiding Rules. Only the specified direction is
  -- implemented; the converse is not stated by the specification.
  constraint discipleship_meetings_voided_state_check
    check (
      status <> 'VOIDED'
      or (voided_by is not null and voided_at is not null)
    )
);


-- ============================================================
-- 13. DISCIPLESHIP MEETING PARTICIPANTS
-- ============================================================
--
-- Participant validity rules P1 to P3, evaluated as of the meeting's
-- occurred_at, are enforced by a constraint trigger in Migration 002
-- and inside record_discipleship_meeting(). See DC section 4.
--
-- Constraint names are abbreviated to "dmp_" because the table name
-- plus column names would exceed the 63-byte identifier limit.

create table discipleship_meeting_participants (
  id                    uuid                         not null default gen_random_uuid(),
  meeting_id            uuid                         not null,
  church_membership_id  uuid                         not null,
  status                meeting_participation_status not null default 'COUNTED',
  voided_by             uuid,
  voided_at             timestamptz,
  created_at            timestamptz                  not null default now(),

  constraint discipleship_meeting_participants_pkey primary key (id),
  constraint dmp_meeting_id_fkey foreign key (meeting_id)
    references discipleship_meetings (id) on delete no action,
  constraint dmp_membership_fkey foreign key (church_membership_id)
    references church_memberships (id) on delete no action,
  constraint dmp_voided_by_fkey foreign key (voided_by)
    references profiles (id) on delete no action,

  -- DC section 4: one Disciple may appear only once in a meeting.
  constraint dmp_meeting_membership_key unique (meeting_id, church_membership_id),

  -- DC section 4, Voiding Rules. Only the specified direction.
  constraint dmp_voided_state_check
    check (
      status <> 'VOIDED'
      or (voided_by is not null and voided_at is not null)
    )
);


-- ============================================================
-- 14. DISCIPLE LESSON PROGRESS
-- ============================================================
--
-- Progress keys to church_membership_id so it survives D Group
-- transfer and Discipler reassignment. Meeting counts, sequential
-- progression and COMPLETED protection are computed and enforced by
-- controlled operations. See DC section 4.

create table disciple_lesson_progress (
  id                    uuid                   not null default gen_random_uuid(),
  church_membership_id  uuid                   not null,
  lesson_id             uuid                   not null,
  status                lesson_progress_status not null default 'NOT_STARTED',
  started_at            timestamptz,
  ready_at              timestamptz,
  completed_at          timestamptz,
  confirmed_by          uuid,
  created_at            timestamptz            not null default now(),
  updated_at            timestamptz            not null default now(),

  constraint disciple_lesson_progress_pkey primary key (id),
  constraint disciple_lesson_progress_membership_fkey
    foreign key (church_membership_id)
    references church_memberships (id) on delete no action,
  constraint disciple_lesson_progress_lesson_id_fkey foreign key (lesson_id)
    references curriculum_lessons (id) on delete no action,
  constraint disciple_lesson_progress_confirmed_by_fkey foreign key (confirmed_by)
    references profiles (id) on delete no action,

  -- DC section 4
  constraint disciple_lesson_progress_membership_lesson_key
    unique (church_membership_id, lesson_id)
);


-- ============================================================
-- 15. MINISTRY ROLE TRANSITIONS
-- ============================================================

create table ministry_role_transitions (
  id                    uuid                   not null default gen_random_uuid(),
  church_membership_id  uuid                   not null,
  d_group_id            uuid                   not null,
  from_responsibility   d_group_responsibility not null,
  to_responsibility     d_group_responsibility not null,
  approved_by           uuid                   not null,
  approved_at           timestamptz            not null,
  notes                 text,
  created_at            timestamptz            not null default now(),

  constraint ministry_role_transitions_pkey primary key (id),
  constraint ministry_role_transitions_membership_fkey
    foreign key (church_membership_id)
    references church_memberships (id) on delete no action,
  constraint ministry_role_transitions_d_group_id_fkey foreign key (d_group_id)
    references d_groups (id) on delete no action,
  constraint ministry_role_transitions_approved_by_fkey foreign key (approved_by)
    references profiles (id) on delete no action
);


-- ============================================================
-- 16. ATTENTION CONDITIONS
-- ============================================================
--
-- d_group_id is nullable for future condition types that are not
-- D Group derived. MVP monitoring always populates it. See DC
-- section 7, D Group Context on Conditions and Follow-ups.

create table attention_conditions (
  id                    uuid                       not null default gen_random_uuid(),
  church_membership_id  uuid                       not null,
  d_group_id            uuid,
  condition_type        attention_condition_type   not null,
  status                attention_condition_status not null default 'ACTIVE',
  detected_at           timestamptz                not null,
  resolved_at           timestamptz,
  metadata              jsonb,
  created_at            timestamptz                not null default now(),

  constraint attention_conditions_pkey primary key (id),
  constraint attention_conditions_membership_fkey
    foreign key (church_membership_id)
    references church_memberships (id) on delete no action,
  constraint attention_conditions_d_group_id_fkey foreign key (d_group_id)
    references d_groups (id) on delete no action
);


-- ============================================================
-- 17. FOLLOW-UPS
-- ============================================================
--
-- assignee_church_membership_id is a responsibility field, not an
-- actor field, so it references church_memberships.id.

create table follow_ups (
  id                             uuid             not null default gen_random_uuid(),
  attention_condition_id         uuid             not null,
  church_membership_id           uuid             not null,
  d_group_id                     uuid,
  assignee_church_membership_id  uuid             not null,
  reason_type                    follow_up_reason not null,
  status                         follow_up_status not null default 'REQUIRED',
  due_at                         timestamptz,
  resolved_at                    timestamptz,
  resolved_by                    uuid,
  resolution_type                follow_up_resolution_type,
  resolution_note                text,
  created_at                     timestamptz      not null default now(),
  updated_at                     timestamptz      not null default now(),

  constraint follow_ups_pkey primary key (id),
  constraint follow_ups_attention_condition_id_fkey
    foreign key (attention_condition_id)
    references attention_conditions (id) on delete no action,
  constraint follow_ups_membership_fkey foreign key (church_membership_id)
    references church_memberships (id) on delete no action,
  constraint follow_ups_d_group_id_fkey foreign key (d_group_id)
    references d_groups (id) on delete no action,
  constraint follow_ups_assignee_fkey foreign key (assignee_church_membership_id)
    references church_memberships (id) on delete no action,
  constraint follow_ups_resolved_by_fkey foreign key (resolved_by)
    references profiles (id) on delete no action,

  -- DC section 7, Episode Identity and Deduplication. One detected
  -- condition produces at most one follow-up, which is what makes
  -- monitoring structurally idempotent rather than dependent on
  -- function logic.
  constraint follow_ups_attention_condition_id_key unique (attention_condition_id),

  -- DC section 7, Resolution Check. Only the specified direction.
  constraint follow_ups_resolved_state_check
    check (
      status <> 'RESOLVED'
      or (resolved_at is not null
          and resolved_by is not null
          and resolution_type is not null)
    )
);


-- ============================================================
-- 18. FOLLOW-UP ACTIONS
-- ============================================================

create table follow_up_actions (
  id            uuid                  not null default gen_random_uuid(),
  follow_up_id  uuid                  not null,
  action_type   follow_up_action_type not null,
  note          text,
  performed_by  uuid                  not null,
  performed_at  timestamptz           not null,
  created_at    timestamptz           not null default now(),

  constraint follow_up_actions_pkey primary key (id),
  constraint follow_up_actions_follow_up_id_fkey foreign key (follow_up_id)
    references follow_ups (id) on delete no action,
  constraint follow_up_actions_performed_by_fkey foreign key (performed_by)
    references profiles (id) on delete no action
);


-- ============================================================
-- 19. ANNOUNCEMENTS
-- ============================================================

create table announcements (
  id          uuid               not null default gen_random_uuid(),
  church_id   uuid               not null,
  d_group_id  uuid,
  author_id   uuid               not null,
  scope       announcement_scope not null,
  title       text               not null,
  body        text               not null,
  created_at  timestamptz        not null default now(),
  updated_at  timestamptz        not null default now(),

  constraint announcements_pkey primary key (id),
  constraint announcements_church_id_fkey foreign key (church_id)
    references churches (id) on delete no action,
  constraint announcements_d_group_id_fkey foreign key (d_group_id)
    references d_groups (id) on delete no action,
  constraint announcements_author_id_fkey foreign key (author_id)
    references profiles (id) on delete no action,

  -- DC section 8, Scope Rules
  constraint announcements_scope_check check (
    (scope = 'CHURCH' and d_group_id is null)
    or
    (scope = 'D_GROUP' and d_group_id is not null)
  )
);


-- ============================================================
-- 21. AUDIT EVENTS
-- ============================================================

create table audit_events (
  id             uuid        not null default gen_random_uuid(),
  church_id      uuid,
  actor_user_id  uuid        not null,
  action         text        not null,
  entity_type    text        not null,
  entity_id      uuid,
  metadata       jsonb,
  created_at     timestamptz not null default now(),

  constraint audit_events_pkey primary key (id),
  constraint audit_events_church_id_fkey foreign key (church_id)
    references churches (id) on delete no action,
  constraint audit_events_actor_user_id_fkey foreign key (actor_user_id)
    references profiles (id) on delete no action
);


-- ============================================================
-- PARTIAL UNIQUE INDEXES
-- ============================================================
--
-- These protect active-state uniqueness. A table-level UNIQUE
-- constraint cannot carry a WHERE clause, so each is an index.

-- DC section 1: the same church role cannot be active twice for the
-- same member.
create unique index church_role_assignments_active_role_uidx
  on church_role_assignments (church_membership_id, role)
  where ended_at is null;

-- DC section 2: one active LEADER per D Group.
create unique index d_group_memberships_active_leader_uidx
  on d_group_memberships (d_group_id)
  where responsibility = 'LEADER'::d_group_responsibility
    and ended_at is null;

-- DC section 2: a person may actively lead only one D Group.
create unique index d_group_memberships_active_leadership_uidx
  on d_group_memberships (church_membership_id)
  where responsibility = 'LEADER'::d_group_responsibility
    and ended_at is null;

-- DC section 2: a DISCIPLE may belong to only one active D Group.
create unique index d_group_memberships_active_disciple_uidx
  on d_group_memberships (church_membership_id)
  where responsibility = 'DISCIPLE'::d_group_responsibility
    and ended_at is null;

-- DC section 2: a DISCIPLE may have only one active primary Discipler.
create unique index discipler_assignments_active_disciple_uidx
  on discipler_assignments (disciple_d_group_membership_id)
  where ended_at is null;

-- DC section 4: a church has at most one ACTIVE curriculum.
create unique index curricula_active_per_church_uidx
  on curricula (church_id)
  where status = 'ACTIVE'::curriculum_status;

-- DC section 6: no duplicate ACTIVE condition of the same type for the
-- same member. d_group_id is deliberately excluded, because a person
-- cannot be in two simultaneous absence episodes and including it
-- would permit two concurrent ACTIVE conditions for one person.
create unique index attention_conditions_active_per_member_uidx
  on attention_conditions (church_membership_id, condition_type)
  where status = 'ACTIVE'::attention_condition_status;


-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
--
-- RLS is enabled on every application table with ZERO policies, so
-- application access is deny-by-default until the dedicated RLS
-- migration. The Data API roles (anon, authenticated) do not own
-- these tables and do not bypass RLS; service_role does, which is
-- the intended Supabase model for trusted server-side work.
--
-- Policies are defined per docs/security/RBAC_RLS_MATRIX.md in a
-- later migration. This migration adds none.

alter table profiles                          enable row level security;
alter table churches                          enable row level security;
alter table church_settings                   enable row level security;
alter table church_memberships                enable row level security;
alter table church_role_assignments           enable row level security;
alter table d_groups                          enable row level security;
alter table d_group_memberships               enable row level security;
alter table discipler_assignments             enable row level security;
alter table d_group_gatherings                enable row level security;
alter table gathering_attendance              enable row level security;
alter table curricula                         enable row level security;
alter table curriculum_lessons                enable row level security;
alter table discipleship_meetings             enable row level security;
alter table discipleship_meeting_participants enable row level security;
alter table disciple_lesson_progress          enable row level security;
alter table ministry_role_transitions         enable row level security;
alter table attention_conditions              enable row level security;
alter table follow_ups                        enable row level security;
alter table follow_up_actions                 enable row level security;
alter table announcements                     enable row level security;
alter table audit_events                      enable row level security;
