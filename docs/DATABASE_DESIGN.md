# DiscipleTrack Database Design

*Document Status:* Rationale — NOT NORMATIVE for schema structure  
*Last Updated:* September 2026

---

## 0. Authority of This Document

This document explains **why** the DiscipleTrack data model looks the way
it does. It is not the schema specification.

Authoritative artifacts:

- `docs/erd/discipletrack.dbml` — concrete schema structure
- `docs/database/DATABASE_CONSTRAINTS.md` — invariants and enforcement
- `docs/security/RBAC_RLS_MATRIX.md` — authorization

Where this document and the ERD appear to disagree about a column name,
type, enum value or relationship, the ERD is correct. Any field-level
detail that remains here is illustrative context for the reasoning, not
a specification. Do not implement a table from this document.

See ADR-008 for the full precedence model.

---

## 1. Purpose

This document records the design reasoning behind the PostgreSQL data
model for the DiscipleTrack MVP.

It translates the requirements from:

- MVP_SPEC.md
- ARCHITECTURE.md
- BUSINESS_RULES.md
- UI_DESIGN_SYSTEM.md

into persistent domain concepts and explains the trade-offs chosen.

The goals are to:

- model the real ministry workflow correctly
- preserve historical information
- enforce important business invariants
- support secure authorization
- avoid storing unnecessary derived data
- support future expansion without overengineering the MVP

---

# 2. Database Principles

## 2.1 PostgreSQL Is the Source of Truth

Persistent ministry information is stored in PostgreSQL.

Flutter must not be treated as the authoritative source for:

- roles
- assignments
- attendance
- lesson progress
- lesson completion
- follow-ups
- promotion
- permissions

---

## 2.2 Prefer Historical Records Over Overwriting

DiscipleTrack is a monitoring system.

Historical relationships matter.

When assignments change, the previous relationship should normally be
ended rather than overwritten or deleted.

Example:

Mark → James
January 10 – June 4

Peter → James
June 5 – Present

---

## 2.3 Derived Values Should Normally Be Calculated

Avoid storing values such as:

- attendance percentage
- sessions attended
- consecutive absence count
- total lessons completed
- overall discipleship percentage
- meeting count

as independent sources of truth.

These values should be derived from authoritative records.

They may later be cached if performance requires it.

---

## 2.4 Database Constraints Protect Invariants

Important rules should be protected through:

- foreign keys
- unique constraints
- partial unique indexes
- check constraints
- transactions
- RLS
- database functions where justified

The application UI alone is not sufficient protection.

---

# 3. Domain Areas

The database is divided conceptually into:

1. Identity & Church
2. D Groups & Assignments
3. D Group Gatherings & Attendance
4. Curriculum & Discipleship
5. Monitoring & Follow-ups
6. Announcements
7. Configuration & Audit

These are logical domains within one PostgreSQL database.

They are not separate microservices.

---

# 4. Identity & Church

## 4.1 auth.users

Provided by Supabase Auth.

Purpose:

Represents authentication identities.

DiscipleTrack does not duplicate passwords or authentication credentials
inside application tables.

Important relationship:

auth.users
    1
    │
    │
    1
profiles

---

## 4.2 profiles

Purpose:

Stores application-level information about a registered user.

Proposed fields:

- id UUID PK
- full_name TEXT
- phone TEXT nullable
- avatar_url TEXT nullable
- created_at TIMESTAMPTZ
- updated_at TIMESTAMPTZ

Relationship:

profiles.id
→ auth.users.id

The profile should not contain the user's D Group role, system role,
current attendance percentage, or lesson progress.

Those belong to their respective domains.

---

## 4.3 churches

Purpose:

Represents a church workspace.

Although MVP launches for one local church, church ownership remains
explicit in the database.

Proposed fields:

- id UUID PK
- name TEXT
- join_code TEXT
- join_code_updated_at TIMESTAMPTZ nullable
- status TEXT
- created_at TIMESTAMPTZ
- updated_at TIMESTAMPTZ

Possible status:

- ACTIVE
- ARCHIVED

The join code must not grant privileged system roles.

---

## 4.4 church_memberships

Purpose:

Represents a user's membership in a church.

Proposed fields:

- id UUID PK
- church_id UUID FK
- user_id UUID FK
- status TEXT
- joined_at TIMESTAMPTZ nullable
- approved_by UUID nullable
- approved_at TIMESTAMPTZ nullable
- created_at TIMESTAMPTZ
- updated_at TIMESTAMPTZ

Possible statuses:

- PENDING
- ACTIVE
- INACTIVE
- TRANSFERRED
- ARCHIVED

Constraint:

A user has exactly one membership record per church, enforced by a
unique constraint on church and user.

A returning member reactivates that record. A second record is never
created, so their attendance, discipleship progress and care history
remain one continuous journey.

See DATABASE_CONSTRAINTS.md for the status lifecycle and for what
TRANSFERRED means.

---

# 5. System Roles

## 5.1 church_role_assignments

Purpose:

Stores privileged church/system role assignments separately from D Group
responsibilities.

Roles:

- ADMIN
- COORDINATOR

Normal church membership does not require a MEMBER role row.

Being an active church member is represented by church_memberships.

Proposed fields:

- id UUID PK
- church_membership_id UUID FK
- role TEXT
- assigned_by UUID
- started_at TIMESTAMPTZ
- ended_at TIMESTAMPTZ nullable
- created_at TIMESTAMPTZ

This preserves role history.

Example:

Sarah
Coordinator
Jan 1 → Present

---

# 6. D Groups

## 6.1 d_groups

Purpose:

Represents a discipleship group.

Proposed fields:

- id UUID PK
- church_id UUID FK
- name TEXT
- description TEXT nullable
- status TEXT
- created_by UUID
- created_at TIMESTAMPTZ
- updated_at TIMESTAMPTZ
- archived_at TIMESTAMPTZ nullable

Possible status:

- ACTIVE
- INACTIVE
- ARCHIVED

A D Group does not require a fixed weekly meeting schedule.

Actual gatherings are recorded separately.

---

# 7. D Group Membership & Responsibility

## 7.1 d_group_memberships

Purpose:

Records a person's historical participation and responsibility inside a
D Group.

Proposed fields:

- id UUID PK
- d_group_id UUID FK
- church_membership_id UUID FK
- responsibility TEXT
- started_at TIMESTAMPTZ
- ended_at TIMESTAMPTZ nullable
- assigned_by UUID
- created_at TIMESTAMPTZ

Responsibilities:

- LEADER
- DISCIPLER
- DISCIPLE

Examples:

John
Young Adults A
LEADER

Mark
Young Adults A
DISCIPLER

James
Young Adults A
DISCIPLE

Historical records are ended rather than overwritten.

---

## 7.2 Active Assignment Constraints

The database should enforce, where practical:

### One active Leader per D Group

Only one:

responsibility = LEADER
AND ended_at IS NULL

per active D Group.

### One active D Group led per person

A person cannot be active LEADER of multiple D Groups.

### One active Disciple D Group

A person acting as a Disciple cannot have multiple active Disciple
memberships.

### Disciple / Discipler Mutual Exclusion

A person must not simultaneously have active:

DISCIPLE

and:

DISCIPLER

responsibilities.

Some of these invariants may require partial unique indexes or controlled
database functions rather than simple UNIQUE constraints.

---

# 8. Discipler Assignments

## 8.1 discipler_assignments

Purpose:

Represents direct care responsibility between a Discipler and Disciple.

This is separate from D Group membership.

Both sides are referenced at D Group membership level, because the
relationship depends on the contextual responsibility each person holds
inside that D Group. See the ERD for exact fields.

Rules:

- both people must belong to the same D Group
- discipler_membership must have DISCIPLER responsibility
- disciple_membership must have DISCIPLE responsibility
- one Disciple may have at most one active primary Discipler
- one Discipler may have multiple assigned Disciples
- assignment history must be preserved

---

# 9. D Group Gatherings

## 9.1 d_group_gatherings

Purpose:

Represents an actual gathering of the overall D Group.

This is separate from a Discipleship Meeting.

A gathering moves from DRAFT to either FINALIZED or CANCELLED, and both
of those are final states. See the ERD for fields and
DATABASE_CONSTRAINTS.md for the transition and state-consistency rules.

Only finalized gatherings participate in official attendance monitoring.

Cancellation exists so that a gathering which did not happen can be
closed out without deleting the record or leaving it misleadingly in
DRAFT. Attendance prepared while the gathering was DRAFT is kept as
history but never becomes official.

---

# 10. Attendance

## 10.1 gathering_attendance

Purpose:

Stores attendance for each participant at a D Group Gathering.

Proposed fields:

- id UUID PK
- gathering_id UUID FK
- church_membership_id UUID FK
- status TEXT
- recorded_by UUID
- recorded_at TIMESTAMPTZ
- updated_at TIMESTAMPTZ

Statuses:

- PRESENT
- ABSENT
- LATE
- EXCUSED

Constraint:

UNIQUE(gathering_id, church_membership_id)

This prevents duplicate attendance records for one person at one
gathering.

---

## 10.2 Attendance Semantics

For monitoring:

PRESENT
→ attended

LATE
→ attended

ABSENT
→ unexplained absence

EXCUSED
→ not an unexplained absence and breaks the absence streak

Attendance percentages and streaks are derived from these records.

---

# 11. Curriculum

## 11.1 curricula

Purpose:

Represents the church's discipleship curriculum.

The MVP has one active fixed curriculum.

Proposed fields:

- id UUID PK
- church_id UUID FK
- name TEXT
- description TEXT nullable
- status TEXT
- created_at TIMESTAMPTZ
- updated_at TIMESTAMPTZ

Possible statuses:

- ACTIVE
- INACTIVE
- ARCHIVED

The architecture allows curriculum data to exist independently from the
Flutter application.

---

## 11.2 curriculum_lessons

Purpose:

Represents the ordered lessons within a curriculum.

Proposed fields:

- id UUID PK
- curriculum_id UUID FK
- lesson_number INTEGER
- title TEXT
- description TEXT nullable
- required_meetings INTEGER
- created_at TIMESTAMPTZ
- updated_at TIMESTAMPTZ

For the MVP:

required_meetings = 4

Constraint:

UNIQUE(curriculum_id, lesson_number)

The active curriculum contains 12 lessons.

The number four should exist as curriculum/domain data rather than being
scattered as magic numbers throughout Flutter.

---

# 12. Discipleship Meetings

## 12.1 discipleship_meetings

Purpose:

Represents an actual one-on-one or small discipleship meeting.

See the ERD for fields, including the RECORDED/VOIDED status and its
void metadata.

A meeting has:

- one responsible Discipler
- one lesson
- one or more participating Disciples

The meeting itself does not contain a single disciple_id because the
meeting may involve a small group.

---

# 13. Discipleship Meeting Participants

## 13.1 discipleship_meeting_participants

Purpose:

Records exactly which Disciples participated in a Discipleship Meeting.

Participants are referenced at church membership level so that credited
progress survives D Group transfer and Discipler reassignment. See the
ERD for fields and uniqueness.

Participant validity is normative and is specified in
DATABASE_CONSTRAINTS.md section 4 as rules P1 to P3. In summary, a
counted participant must have been an active Disciple of the meeting's
D Group and assigned to the meeting's Discipler at the time the meeting
occurred. Only actual participants receive progress.

Example:

Meeting #105

Discipler:
Mark

Lesson:
Lesson 4

Participants:
James
Anna

This creates one meeting but contributes one Lesson 4 meeting toward
James and one toward Anna.

---

# 14. Independent Participant Progress

Progress belongs to each Disciple individually.

Example before a shared meeting:

James
Lesson 4
2 valid meetings

Anna
Lesson 4
1 valid meeting

Mark conducts one Lesson 4 meeting with both.

After:

James
3/4

Anna
2/4

The system must not assume all participants in a small group have equal
historical progress.

---

# 15. Lesson Progress

## 15.1 disciple_lesson_progress

Purpose:

Represents the lifecycle of a Disciple's progress through a specific
lesson.

Progress is keyed to church membership, not to the person's current
D Group assignment, so a Disciple's journey survives transfer,
reassignment and leadership change. This is the single most consequential
identity decision in the schema.

See the ERD for fields, statuses and uniqueness.

---

## 15.2 Progress State Transitions

Expected lifecycle:

NOT_STARTED
    ↓ first valid meeting

IN_PROGRESS
    ↓ required meeting count reached

READY_FOR_COMPLETION
    ↓ D Group Leader confirms

COMPLETED

Flutter must not arbitrarily skip required transitions.

---

# 16. Meeting Count

The current meeting count should be derived from:

discipleship_meeting_participants
JOIN discipleship_meetings

for:

- the Disciple
- the lesson
- valid meeting records

Example:

COUNT(valid Lesson 4 participation records) = 3

UI:

● ● ● ○
Meeting 3 of 4

Do not maintain an independent authoritative meeting_count field unless
future performance requirements justify a cache.

---

# 17. Lesson Completion

Lesson completion is represented through the progress record.

When the required number of meetings is reached:

status = READY_FOR_COMPLETION

The D Group Leader may then confirm the lesson.

Confirmation records:

- status = COMPLETED
- completed_at
- confirmed_by

This provides accountability for the completion decision.

---

# 18. Sequential Progression

The MVP curriculum is ordered.

Normally a Disciple progresses:

Lesson 1
→ Lesson 2
→ Lesson 3
→ ...
→ Lesson 12

The system prevents progression that bypasses required previous lesson
completion. Lesson N requires lesson N-1 COMPLETED, and lesson 1 is
exempt.

Enforcement happens inside record_discipleship_meeting(). It is an
order-dependent check across the curriculum and the participant's
progress, which makes it a controlled operation rather than a row
constraint, and lets the operation return a usable error.

Because a meeting records exactly one lesson, this also means every
counted participant in a meeting must be on that same lesson.

There is no Coordinator sequencing override in the MVP. A correction or
migration workflow is documented future scope.

---

# 19. Curriculum Completion

Curriculum completion is derived when all required lessons are completed.

Every lesson of the church's ACTIVE curriculum COMPLETED

→ Eligible for Discipler Review

The MVP curriculum holds twelve lessons, but that is seed data. No rule
hard-codes the count.

Eligibility itself should normally be derived rather than manually
entered.

---

# 20. Promotion

## 20.1 ministry_role_transitions

Purpose:

Records important ministry responsibility transitions such as
Disciple → Discipler.

The record also preserves the D Group context in which the transition
occurred. See the ERD for fields.

For Disciple → Discipler:

- every lesson of the church's active curriculum must be completed
- Coordinator approval is required

Promotion runs transactionally and must also end the promotee's active
discipler assignment where they are the Disciple, before ending the
DISCIPLE responsibility and creating the DISCIPLER responsibility.
Otherwise that assignment would survive while pointing at an ended
responsibility. See DATABASE_CONSTRAINTS.md for the full sequence.

Historical progress remains preserved.

---

# 21. Attention Conditions

## 21.1 attention_conditions

Purpose:

Represents a detected condition indicating that a member may require
human attention.

This separates:

"the system detected a concern"

from:

"someone followed up."

Proposed fields:

- id UUID PK
- church_membership_id UUID FK
- d_group_id UUID FK nullable
- condition_type TEXT
- status TEXT
- detected_at TIMESTAMPTZ
- resolved_at TIMESTAMPTZ nullable
- metadata JSONB nullable
- created_at TIMESTAMPTZ

Initial condition type:

- CONSECUTIVE_ABSENCE

Possible future types:

- NO_RECENT_ATTENDANCE
- STALLED_DISCIPLESHIP
- NO_ASSIGNED_DISCIPLER
- ATTENDANCE_DECLINE

Do not implement future condition types until intentionally scoped.

---

# 22. Attention Condition Status

Possible statuses:

- ACTIVE
- RESOLVED

An active equivalent condition should not repeatedly create duplicate
attention records every time monitoring executes.

---

# 23. Follow-ups

## 23.1 follow_ups

Purpose:

Represents a ministry-care case created because a person requires
attention.

The assignee is recorded at church membership level, because it
represents ongoing care responsibility within the church rather than a
completed action. See the ERD for fields, statuses and resolution
semantics.

"Overdue" should normally be derived:

status != RESOLVED
AND due_at < now()

rather than requiring an independently synchronized OVERDUE state.

---

# 24. Follow-up Assignment

Monitoring covers Leaders, Disciplers and Disciples, so the assignment
rule needs more than one rung. Responsibility is resolved through an
escalation chain that always lands on someone other than the person the
follow-up concerns, terminating at the Coordinator.

The exact chain is in BUSINESS_RULES.md BR-039 and
DATABASE_CONSTRAINTS.md section 7.

The assignment should reflect the responsible person at the time the
follow-up is created.

Later assignment changes must not silently rewrite historical
responsibility. Reassignment is deliberate and is recorded through
audit_events rather than additional columns.

---

# 25. Follow-up Actions

## 25.1 follow_up_actions

Purpose:

Stores individual care actions taken during a follow-up.

Proposed fields:

- id UUID PK
- follow_up_id UUID FK
- action_type TEXT
- note TEXT nullable
- performed_by UUID
- performed_at TIMESTAMPTZ
- created_at TIMESTAMPTZ

Possible action types:

- CONTACTED
- SENT_MESSAGE
- CALLED
- PERSONAL_CONVERSATION
- SCHEDULED_VISIT
- OTHER

Example:

Follow-up: James

Sep 16
SENT_MESSAGE

Sep 18
CALLED

Sep 20
PERSONAL_CONVERSATION

Follow-up actions form part of the historical care record.

---

# 26. Follow-up Deduplication

The monitoring process must not create multiple unresolved equivalent
follow-ups for the same active condition.

Example:

James already has an unresolved follow-up caused by the current
consecutive-absence condition.

Running monitoring again must not create another identical case.

This is enforced structurally with partial unique indexes on the active
attention condition and on the unresolved follow-up, so that retried
monitoring stays idempotent without depending on function logic alone.
See DATABASE_CONSTRAINTS.md for the exact indexes.

---

# 27. Announcements

## 27.1 announcements

Purpose:

Stores simple church-wide and D Group announcements.

Proposed fields:

- id UUID PK
- church_id UUID FK
- d_group_id UUID FK nullable
- author_id UUID
- scope TEXT
- title TEXT
- body TEXT
- created_at TIMESTAMPTZ
- updated_at TIMESTAMPTZ

Scopes:

- CHURCH
- D_GROUP

Rules:

CHURCH
→ d_group_id must be NULL

D_GROUP
→ d_group_id must be NOT NULL

Publishing authority:

CHURCH
→ Coordinator

D_GROUP
→ relevant D Group Leader

---

# 28. Church Settings

## 28.1 church_settings

Purpose:

Stores church-level configurable behavior.

Proposed fields:

- church_id UUID PK/FK
- consecutive_absence_threshold INTEGER
- follow_up_due_days INTEGER nullable
- created_at TIMESTAMPTZ
- updated_at TIMESTAMPTZ

Initial default:

consecutive_absence_threshold = 3

This prevents important business thresholds from being permanently
hard-coded into Flutter.

---

# 29. Audit Events

## 29.1 audit_events

Purpose:

Provides additional audit information for important system operations
where domain records alone are insufficient.

Possible fields:

- id UUID PK
- church_id UUID FK nullable
- actor_user_id UUID
- action TEXT
- entity_type TEXT
- entity_id UUID nullable
- metadata JSONB nullable
- created_at TIMESTAMPTZ

Do not duplicate every domain record into the audit table.

Domain records should already contain appropriate:

- created_by
- recorded_by
- approved_by
- confirmed_by
- timestamps

Audit events are supplemental.

---

# 30. Activity Timeline

The UI contains activity timelines.

This does not initially require an activity_timeline table.

Activity can be assembled from domain events such as:

- gathering attendance
- discipleship meetings
- lesson completion
- follow-up creation
- follow-up actions
- follow-up resolution
- assignment changes
- promotion

The activity timeline is a read model.

It is not an independent source of truth.

A PostgreSQL view or optimized read model may be introduced later if
query complexity or performance justifies it.

---

# 31. Primary Relationship Map

Conceptually:

auth.users
    │
    ▼
profiles
    │
    ▼
church_memberships
    │
    ├──────────────► church_role_assignments
    │
    ▼
churches
    │
    ├──────────────► church_settings
    │
    ├──────────────► curricula
    │                    │
    │                    ▼
    │              curriculum_lessons
    │
    ▼
d_groups
    │
    ├──────────────► d_group_memberships
    │                    │
    │                    ▼
    │              discipler_assignments
    │
    ├──────────────► d_group_gatherings
    │                    │
    │                    ▼
    │              gathering_attendance
    │
    └──────────────► discipleship_meetings
                         │
                         ▼
               discipleship_meeting_participants
                         │
                         ▼
               disciple_lesson_progress
            