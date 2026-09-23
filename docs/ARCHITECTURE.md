# DiscipleTrack Architecture

*Document Status:* MVP Baseline  
*Last Updated:* September 2026

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
- D Group Gatherings
- Gathering Attendance
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
- Disciple and Discipler responsibilities are not simultaneously active
  for the same person

Historical assignments should be preserved.

---

## 7. Separate Meeting Domains

DiscipleTrack contains two distinct meeting concepts.

### D Group Gathering

Purpose:

- overall group gathering
- group participation of ministry workers and group members
- absence monitoring for D Group Leaders and Disciplers

Typical participants:

- D Group Leader
- Disciplers
- Disciples

Gatherings are secondary to the core discipleship workflow. They do not
drive lesson progress, and gathering attendance never creates an
attention condition for a Disciple.

### Discipleship Meeting

Purpose:

- work through a specific curriculum lesson
- record individual discipleship progression
- record Disciple attendance and consistency, including missed meetups
- absence monitoring for Disciples

Typical participants:

- Discipler
- assigned Disciple or small set of assigned Disciples

The Discipler and Disciple arrange meetups themselves. DiscipleTrack
records what happened afterwards and does not schedule meetings. A
missed meetup is a recorded meeting whose participants were Absent or
Excused; only Present or Late participation is credited toward the
lesson.

These concepts must not be merged simply because both are meetings.

Their lifecycle, permissions, data and business meaning differ.

---

## 8. Curriculum Progress Model

The church curriculum contains 12 ordered lessons.

Each lesson requires four credited Discipleship Meetings. The number is
the lesson's required_meetings data, seeded as four.

Conceptually:

Lesson
→ Meeting 1       Present   credited
→ Meeting 2       Present   credited
→ Missed meetup   Absent    not credited
→ Meeting 3       Late      credited
→ Meeting 4       Present   credited
→ Ready for Completion
→ Leader Confirmation
→ Completed

The four meetings are specifically meetings working through that lesson.
Missed meetups stay in the Disciple's history as consistency information
but never advance progress. Additional meetings recorded while the lesson
awaits confirmation are credited and not clamped.

Reaching four meetings does not automatically complete the lesson.

The D Group Leader performs final completion confirmation.

---

## 9. Promotion Model

Completing every lesson of the church's active curriculum creates
eligibility for Discipler review.

Conceptually:

Active Curriculum Completed
→ Eligible for Review
→ Coordinator Decision
→ Discipler Responsibility

Promotion is an explicit ministry action rather than an automatic
database side effect.

Historical Disciple progress must remain available after promotion.

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
- gathering attendance
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
- meeting consistency
- members needing attention
- completion approvals
- follow-ups
- gathering attendance, as secondary information

### Coordinator

- ministry-wide D Groups
- progress and meeting consistency
- members needing attention
- follow-ups
- assignments
- promotion eligibility
- gathering attendance, as secondary information

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

A member/session attendance combination should not be duplicated merely
because Flutter accidentally submits the operation twice.

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
- attendance
- discipleship meetings
- lesson completion
- follow-ups
- promotion history

The database should distinguish current state from historical events
where appropriate.

---

## 19. Derived Data

Underlying records are authoritative.

Examples:

Attendance Records
→ Attendance Percentage

Gathering History
→ Consecutive Absence Streak (Leaders and Disciplers)

Discipleship Meetings
→ Meeting 3/4

Meeting Participant Outcomes
→ Meeting Consistency, Last Meeting Date
→ Consecutive Missed-Meeting Streak (Disciples)

Lesson Completion Records
→ Curriculum Progress

Follow-ups
→ Open/Overdue Counts

Derived values may be cached later for performance if justified, but
their authoritative source must remain clear.

---

## 20. Monitoring Architecture

Core monitoring is deterministic.

Monitoring sources are role-specific (ADR-009).

Disciples:

Recorded Discipleship Meeting
→ Participant Outcomes
→ Missed-Meeting Rule
→ Attention Condition (CONSECUTIVE_MISSED_MEETINGS)
→ Follow-up
→ Responsible Person
→ Actions
→ Resolution

D Group Leaders and Disciplers:

Finalized D Group Gathering
→ Attendance Records
→ Absence Rule
→ Attention Condition (CONSECUTIVE_ABSENCE)
→ Follow-up
→ Responsible Person
→ Actions
→ Resolution

Gathering attendance never creates a condition for a Disciple.

Initial rules:

Configured consecutive threshold for each source
(default 3)
→ Follow-up eligibility

Monitoring only sees recorded meetups. Oversight views surface each
Disciple's last meeting date, derived at read time, so that meetings
which stop without being recorded are still visible.

AI is not the source of truth for deterministic attendance conditions.

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
- attendance
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
- promotion eligibility

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
→ Discipleship Meetings with missed meetups
→ Missed-Meeting Condition
→ Follow-up

and:

Discipleship Meeting
→ 4/4
→ Leader Confirmation
→ Lesson Completion

and:

D Group Gathering
→ Attendance
→ Leader or Discipler Absence Condition
→ Follow-up

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
