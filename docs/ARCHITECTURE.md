# DiscipleTrack Architecture

*Document Status:* MVP Baseline  
*Last Updated:* October 2026 (revision 2026-10-02: sections 8, 10a, 19 and 30, for ADR-010 and ADR-011)

Revision 2026-10-05: D Group gatherings and gathering attendance removed
(ADR-014) from sections 3, 7, 14, 17, 18, 19, 20 and 30; one monitoring
condition, CONSECUTIVE_ABSENCE from recorded discipleship meeting
outcomes, in sections 19, 20 and 30; "missed meetup" wording and meeting
consistency removed from sections 7, 8, 14 and 19 (decision 8); section 6
core constraints and section 9 Discipler Appointment Model (ADR-012);
sections 14, 18 and 30 promotion wording; sections 20 and 23 attendance
wording.

Revision 2026-10-05 (ADR-015): the Discipler marks a lesson completed
with no Leader confirmation; sections 8, 9, 19 and 30.

Revision 2026-10-05 (user decision, ninth): the curriculum has ten
lessons, not twelve; sections 8, 9 and 19.

Revision 2026-10-06 (ADR-018): sections 6 and 9, for Slice 6 as built.

---

## 1. Architecture Goal

DiscipleTrack should be engineered as a maintainable production mobile
application while keeping the MVP technically understandable.

The architecture prioritizes:

- separation of concerns
- security
- testability
- maintainability
- explicit business rules
- historical data integrity
- reliable authorization
- observability/debuggability
- ability to evolve

The project should not introduce infrastructure merely to appear
technically sophisticated.

---

## 2. High-Level Architecture

DiscipleTrack MVP uses:

Flutter Mobile Application
→ Presentation
→ Application / Domain Logic
→ Repository / Data Access
→ Supabase
→ PostgreSQL

Primary technologies:

- Flutter
- Dart
- Riverpod
- GoRouter
- Supabase
- PostgreSQL
- Supabase Auth
- PostgreSQL Row Level Security

---

## 3. Architecture Style

DiscipleTrack uses a modular monolithic architecture.

Business capabilities are separated logically without deploying each
domain as an independent microservice.

Initial domains include:

- Authentication
- Church / Membership
- D Groups
- D Group Assignments
- Curriculum
- Discipleship Meetings and Meeting Attendance
- Progress
- Monitoring
- Follow-ups
- Announcements
- Profiles
- Dashboard / Reporting

Domain boundaries should remain understandable even though they operate
within one application/backend.

D Group Gatherings and Gathering Attendance are withdrawn as domains
(ADR-014). Their applied tables remain in Migrations 001 and 002 as
deprecated objects with no MVP owner.

---

## 4. Single-Church MVP With Future Expansion

The initial product targets one local church.

The domain/database design should still use explicit church ownership
where appropriate rather than assuming all records globally belong to
one permanent church.

This provides a reasonable future path toward supporting additional
churches without implementing complex multi-tenant administration in the
MVP.

Do not build unnecessary multi-tenant infrastructure before it is needed.

Same-church integrity is nevertheless a database invariant today. A row
must never relate records belonging to different churches. The MVP keeps
the normalized hierarchy and enforces this with ordinary foreign keys
where expressible, and with trusted database functions or constraint
triggers where the relationship spans tables. church_id is not
duplicated across domain tables purely to enable composite foreign keys.

Denormalized tenant keys are deferred, not rejected on principle. They
may be justified by future multi-church scale.

---

## 5. Domain Terminology

DiscipleTrack separates system/church roles from contextual D Group
responsibilities.

### System Roles

- Admin
- Discipleship Coordinator
- Member

### D Group Responsibilities

- D Group Leader
- Discipler
- Disciple

Authorization therefore cannot be represented by one simple global role
field.

A user may have a system responsibility and a separate D Group
responsibility.

Example:

System:
Coordinator

D Group:
Leader of D Group A

---

## 6. Ministry Responsibility Model

Conceptually:

Church
└── D Group
    ├── D Group Leader
    ├── Disciplers
    │   └── Assigned Disciples
    └── Disciples

Core constraints include:

- one primary active D Group Leader per active D Group
- one active D Group per Disciple
- one active primary Discipler per Disciple at most
- one Discipler may care for multiple Disciples
- one Leader may lead only one active D Group
- Disciple and Leader responsibilities are not simultaneously active for
  the same person
- Disciple and Discipler responsibilities may be held at the same time,
  in the same D Group (ADR-012; enforced since Migration 013)
- nobody is paired with themselves: the two sides of a discipler
  assignment are different church memberships (ADR-012), and no two
  people disciple each other at the same time (ADR-018)
- a person is in at most one D Group at a time (d_group_placements,
  ADR-018); they are added directly, with no acceptance step

Historical assignments should be preserved.

---

## 7. Discipleship Meetings

DiscipleTrack has one meeting concept: the discipleship meeting. D Group
gatherings are not tracked (ADR-014), and attendance exists only as a
discipleship meeting outcome.

### Discipleship Meeting

Purpose:

- work through a specific curriculum lesson
- record individual discipleship progression
- record each expected Disciple's outcome (Present, Late, Absent or
  Excused)
- absence monitoring for Disciples, from explicitly recorded ABSENT
  outcomes

Typical participants:

- Discipler
- assigned Disciple or small set of assigned Disciples

The Discipler and Disciple arrange meetups themselves. DiscipleTrack
records what happened afterwards and does not schedule meetings. Only
Present or Late participation is credited toward the lesson. A meeting
record shows each Disciple's recorded outcome; there is no derived
"held" or "missed" label (ADR-014 decision 8). A recorded meeting in
which every outcome is Excused is not an absence for anyone: it has no
credited participation and breaks each Disciple's consecutive recorded
absence streak (BR-027a). No record is not an absence.

---

## 8. Curriculum Progress Model

The church curriculum contains 10 ordered lessons.

Meeting occurrence and lesson completion are separate concerns
(ADR-011). A lesson takes as many credited meetings as its material
needs; the count is factual history and never completes a lesson.

Conceptually:

Lesson
→ Meeting 1       Present   credited
→ Meeting 2       Present   credited
→ Meeting         Absent    not credited
→ Meeting 3       Late      credited
→ ...             (as many as the material takes)
→ Discipler marks the lesson completed       → Completed (ADR-015)
→ next lesson becomes current

There is no Leader confirmation (ADR-015). The Leader and the
Coordinator may mark a lesson completed as fallback. A completion can be
undone while it is the latest and no meeting has been recorded on the
next lesson; after that the completion is locked by later progress
(ADR-016). The Coordinator's reopen is database-level recovery with no
app action.

Absent and Excused outcomes stay in the Disciple's meeting history but
never count as lesson meetings. There is no maximum.

No rule depends on a meeting count (ADR-017): there is no minimum
before marking completed and no typical number. Counts are factual
history; neither the client nor the database encodes a progression
threshold.

Lesson content is a separate concern again (ADR-010). It is read, never
written by the client, and reading it never changes progress.

---

## 9. Discipler Appointment Model

Completion of Lesson 5 of the active curriculum, marked by the
Discipler (ADR-015), makes a Disciple eligible to be appointed as a
Discipler (ADR-012). In Progress does not count. The eligibility lesson is
defined in one place, the policy function `private.discipler_eligibility_lesson()` (D2, decided
2026-10-05), never in Flutter.

Conceptually:

Lesson 5 Completed (marked by the Discipler)
→ Eligible (derived, never stored)
→ Coordinator appoints (no acceptance workflow; attributed and audited)
→ DISCIPLER responsibility added in the same D Group
→ Disciples assigned separately (discipler assignments)

Eligibility, appointment and assignment are three distinct facts: a
derived predicate, an attributed appointment record with its
responsibility row, and an assignment row.

Appointment is an explicit ministry action rather than an automatic
database side effect. It does not end the person's DISCIPLE
responsibility, their own discipler assignment or their progress; they
continue their own journey through Lesson 10. Slice 6 built this
(Migrations 013 and 014; ADR-012 decision 10, ADR-018).

---

## 10. Flutter Client

Flutter/Dart provides the Android and iOS application.

Flutter is responsible for:

- presentation
- navigation
- local UI state
- user interaction
- appropriate client validation
- device functionality
- backend communication

Flutter widgets must not contain core business rules.

The mobile application is an untrusted client for security purposes.

---

## 10a. Offline Read-Only Access and Lesson Content

Offline is view-only (Vertical Slice 4). The app keeps a device copy of
what the person may already see and shows it while offline. Every write
is disabled offline and nothing is queued, so this is not offline
synchronization (MVP section 33).

Two kinds of device data exist:

- the session snapshot (Slice 4): own profile, membership, church name,
  roles, group names and the phone numbers visible to the person;
- the published lesson content (ADR-010), from the Curriculum / Lesson
  Content slice: only the tiers and lessons the server allows that
  person (ADR-019), synced once, readable offline, refreshed when the
  published version changes, and pruned to the current scope on every
  refresh.

Supabase stays authoritative for both. Device data is display data,
never authorizes anything, is cleared on sign-out, and never masks a
refusal from the server. Ministry records such as meetings, progress and
attention states are not part of the device copy unless a later slice
decides so explicitly.

---

## 11. Presentation Architecture

Pages should consume application/domain behavior rather than directly
implementing business decisions.

Conceptually:

UI / Widget
→ Controller / Application State
→ Use Case / Domain Logic where needed
→ Repository
→ Backend

The exact number of layers should remain proportional to complexity.

Do not introduce empty abstraction layers merely to imitate enterprise
architecture.

---

## 12. State Management

Riverpod is the intended state-management and dependency-composition
solution.

It may coordinate:

- authentication
- current church context
- current user/profile
- D Group context
- loading/error states
- feature workflows

Core domain rules should remain independently testable.

---

## 13. Navigation

GoRouter is the intended navigation solution.

Navigation may depend on:

- authentication
- onboarding
- membership approval
- system role
- D Group responsibility

Navigation is role/context aware.

Client navigation restrictions improve usability but do not constitute
authorization.

---

## 14. Role-Aware User Experience

The same visual system should provide different information priorities
according to responsibility.

Examples:

### Disciple

- journey
- current lesson
- meeting progress and meeting history
- D Group
- announcements

### Discipler

Action-oriented:

- assigned Disciples
- Record Meeting
- progress
- follow-ups
- attention states
- D Group context

### D Group Leader

Oversight-oriented, not an attendance-entry workspace:

- D Group health
- discipleship progress
- recorded meeting outcomes and last recorded meeting dates
- members needing attention
- completion approvals
- follow-ups

### Coordinator

- ministry-wide D Groups
- progress and recorded meeting history
- members needing attention
- follow-ups
- assignments
- Discipler eligibility and appointment (ADR-012)

No role sees gathering attendance; it is not tracked (ADR-014).

Role-aware presentation does not replace backend authorization.

---

## 15. Backend

Supabase provides the MVP backend platform.

Capabilities may include:

- Supabase Auth
- PostgreSQL
- Row Level Security
- Storage
- database functions
- Edge Functions where justified
- scheduled/background operations where justified

PostgreSQL is the authoritative system of record.

Not every operation requires an Edge Function.

Use the simplest secure backend mechanism that correctly implements the
requirement.

---

## 16. Data Access

Presentation components should not contain arbitrary direct Supabase
queries.

Preferred direction:

Presentation
→ Application / Domain
→ Repository
→ Supabase/PostgreSQL

Repositories provide a controlled data-access boundary.

Benefits include:

- testability
- consistent error handling
- reduced backend coupling
- separation of concerns
- easier mocking/fakes during testing

---

## 17. Database

PostgreSQL is the system of record.

Database design should use appropriate:

- primary keys
- foreign keys
- unique constraints
- check constraints
- indexes
- transactions
- Row Level Security

Important invariants should be enforced at the strongest practical layer.

For example:

A Disciple's outcome for a discipleship meeting should not be duplicated
merely because Flutter accidentally submits the operation twice.

Some invariants span several tables and cannot be expressed as ordinary
constraints. Those use constraint triggers or trusted database
functions. DATABASE_CONSTRAINTS.md is the authoritative record of which
mechanism protects which invariant.

---

## 18. Historical Data

DiscipleTrack is a historical monitoring system.

Important history should not be lost when current assignments change.

Examples include:

- previous D Group membership
- previous Discipler assignment
- previous leadership assignment
- discipleship meetings and their recorded outcomes
- lesson completion
- follow-ups
- Discipler appointment history

The database should distinguish current state from historical events
where appropriate.

---

## 19. Derived Data

Underlying records are authoritative.

Examples:

Discipleship Meetings
→ Lesson meeting count ("5 meetings recorded"), meeting ordinal

Discipler assignments
→ Active Discipleships

Meeting Participant Outcomes
→ Last Recorded Meeting Date
→ Consecutive Recorded Absence Streak (Disciples)

Lesson Completion Records
→ Curriculum Progress ("Lesson 6 of 10", "5 of 10 completed")
→ Discipler Eligibility (Lesson 5 COMPLETED, ADR-012, ADR-015)

No attendance percentage, gathering streak or meeting-consistency ratio
is derived (ADR-014, decision 8).

Follow-ups
→ Open/Overdue Counts

Derived values may be cached later for performance if justified, but
their authoritative source must remain clear.

---

## 20. Monitoring Architecture

Core monitoring is deterministic.

Monitoring has one condition, one source and one threshold (ADR-014),
and uses only explicitly recorded facts.

Disciples:

Recorded Discipleship Meeting
→ Recorded Participant Outcomes
→ Consecutive Recorded Absence Rule (BR-027a)
→ Attention Condition (CONSECUTIVE_ABSENCE)
→ Follow-up
→ Responsible Person
→ Actions
→ Resolution

Initial rule:

`church_settings.consecutive_absence_threshold` (default 3)
consecutive recorded ABSENT outcomes within the current discipler
assignment
→ Follow-up eligibility

D Group Leaders and Disciplers have no automated monitoring in the MVP;
their participation is noticed through human oversight. A person who is
both a Disciple and a Discipler is monitored as a Disciple only. The
LEADER and DISCIPLER branches of the follow-up chain have no MVP trigger
(ADR-014) and are not built until a factual condition for those subjects
is approved.

Monitoring only sees recorded meetings. No record is not an absence,
and no condition is ever generated from elapsed time, inactivity or the
lack of a record. Oversight views surface each Disciple's last recorded
meeting date, derived at read time, as a displayed fact, never a
condition, so that meetings which stop without being recorded are still
visible.

AI is not the source of truth for deterministic absence conditions.

---

## 21. Follow-up Architecture

Follow-up closes the loop between detection and human care.

Conceptually:

Detect Concern
→ Assign Responsibility
→ Human Action
→ Record Outcome
→ Resolve

Primary assignment:

Disciple's Primary Discipler

Fallback:

D Group Leader

Oversight:

D Group Leader
→ D Group scope

Coordinator
→ Ministry scope

The MVP supports overdue state but does not require complex automatic
escalation.

---

## 22. Announcement Architecture

Announcements use only two MVP scopes:

- Church
- D Group

Church-wide announcements are ministry communication managed by the
Coordinator.

D Group announcements are managed by the relevant D Group Leader.

Announcements are intentionally not a messaging/social platform.

---

## 23. Profile Architecture

Every registered user has a profile.

A profile combines identity with authorized ministry context.

Depending on viewer permissions, it may expose:

- D Group
- responsibility
- Discipler
- assigned Disciples
- recorded discipleship meeting outcomes
- progress
- recent activity
- follow-up information

Profile queries and UI must respect contextual authorization.

---

## 24. Authentication

Supabase Auth provides authentication.

The mobile application should restore authenticated sessions across
normal application restarts.

The application must handle:

- registration
- login
- session restoration
- token refresh
- logout
- invalid session
- revoked access
- temporary connectivity failure

Authentication answers:

"Who is this user?"

Authorization answers:

"What may this user access or modify?"

---

## 25. Authorization

Authorization is contextual.

Access may depend on:

Authenticated User
+
Church Membership
+
System Role
+
D Group Membership
+
D Group Responsibility
+
Discipler-to-Disciple Assignment
+
Resource Context

Examples:

- Coordinator may access authorized ministry-wide information.
- D Group Leader may access authorized information for their D Group.
- Discipler may access authorized information for assigned Disciples.
- Disciple may access their own permitted information.

Role alone is not always sufficient.

---

## 26. Admin and Ministry Data

Admin privileges are primarily system/access privileges.

Admin should not automatically gain access to private ministry-care
information solely because the user administers the system.

If a person requires both system administration and ministry oversight,
the appropriate separate responsibilities can be assigned.

This follows least-privilege design.

---

## 27. Row Level Security

PostgreSQL Row Level Security should enforce sensitive access where
appropriate.

Policies must account for:

- church ownership
- membership
- system roles
- D Group membership
- D Group responsibility
- Discipler assignments
- resource ownership/context

RLS policies must be explicitly tested.

Flutter UI restrictions are not substitutes for backend authorization.

---

## 28. Database Migrations

Persistent database schema changes must be version-controlled through
migrations.

The production schema should not depend on undocumented manual dashboard
changes.

Migrations provide:

- reproducibility
- reviewability
- environment consistency
- deployment history

Initial church provisioning is deployment-time seed work rather than a
runtime operation. It is specified in DATABASE_CONSTRAINTS.md section 0
and is never reachable from the Flutter client.

---

## 29. Error Handling

Expected failures must be handled intentionally.

Examples:

- network unavailable
- authentication failure
- session expiration
- authorization denied
- invalid assignment
- validation failure
- duplicate operation
- database constraint violation
- backend failure

User-facing errors should be understandable without exposing sensitive
internal details.

---

## 30. Testing Strategy

DiscipleTrack should use multiple testing levels.

### Unit Tests

For deterministic domain logic such as:

- absence streak calculation
- lesson meeting eligibility
- follow-up eligibility
- progression rules
- Discipler eligibility (Lesson 5 COMPLETED, ADR-012, ADR-015)

### Widget Tests

For important Flutter component behavior.

### Integration Tests

For:

- repositories
- Supabase integration
- PostgreSQL constraints
- authentication
- RLS policies
- cross-feature workflows

### End-to-End Tests

For critical journeys such as:

Register
→ Join Church
→ Assignment
→ Discipleship Meetings with recorded Absent outcomes
→ Consecutive Recorded Absence Condition (CONSECUTIVE_ABSENCE)
→ Follow-up

and:

Discipleship Meetings
→ Discipler marks the lesson completed (ADR-015)
→ Lesson Completion

The gathering journey (D Group Gathering, Attendance, Leader or
Discipler Absence Condition, Follow-up) is withdrawn (ADR-014).

AI-generated implementation is not considered correct merely because it
compiles.

---

## 31. CI/CD Direction

The repository should eventually enforce automated quality gates.

Relevant checks include:

- formatting
- static analysis
- unit tests
- integration tests where practical
- migration validation
- dependency/security checks where appropriate

Required failing checks should prevent code from being considered
complete.

---

## 32. AI-Assisted Engineering

AI agents may assist with:

- implementation
- testing
- edge-case discovery
- code review
- documentation
- refactoring
- security review

Agents must follow the project's documented requirements and
architectural decisions.

AI output is not inherently trusted.

Deterministic quality mechanisms remain authoritative:

- compiler
- analyzer
- tests
- database constraints
- RLS
- CI

---

## 33. Engineering Principle

DiscipleTrack should introduce technology because it solves an identified
engineering requirement.

Do not introduce technologies such as:

- microservices
- Kubernetes
- Kafka
- RabbitMQ
- Redis
- complex distributed infrastructure

without a concrete need.

Professional engineering means choosing appropriate complexity, not
maximum complexity.
