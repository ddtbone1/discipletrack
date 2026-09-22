
# DiscipleTrack Architecture

## 1. Architecture Goal

DiscipleTrack should be engineered as a maintainable production mobile
application while keeping the MVP technically understandable.

The architecture prioritizes:

- clear separation of concerns
- security
- testability
- maintainability
- understandable business logic
- historical data integrity
- reliable authorization
- ability to evolve

The system should not introduce unnecessary infrastructure simply to
appear sophisticated.

---

## 2. High-Level Architecture

DiscipleTrack MVP uses:

Flutter Mobile Application
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

Business capabilities are logically separated without deploying each
domain as an independent microservice.

Initial domains include:

- Authentication
- Churches
- Membership
- D Groups
- D Group Assignments
- Curriculum
- Sessions
- Attendance
- Progress
- Monitoring
- Follow-ups
- Dashboard / Reporting

---

## 4. Domain Terminology

DiscipleTrack distinguishes between system/church authority and D Group
responsibility.

System/church roles include:

- Admin
- Discipleship Coordinator
- Member

D Group responsibilities include:

- D Group Leader
- Discipler
- Disciple

These should not be represented as one global role hierarchy.

For example:

A Member may become a Discipler within D Group A without receiving
church-wide administrative authority.

Authorization therefore depends on both:

- church/system role
- contextual D Group assignment

---

## 5. Ministry Hierarchy

Conceptually:

Church
└── D Groups
    └── D Group
        ├── D Group Leader
        ├── Disciplers
        └── Disciples

A D Group has one primary active D Group Leader.

A D Group can contain multiple Disciplers and Disciples.

The domain model must support determining who is responsible for whom.

---

## 6. Flutter Client

Flutter/Dart provides the Android and iOS client.

Flutter is responsible for:

- presentation
- navigation
- local UI state
- user interaction
- client validation
- device functionality
- communication with backend services

Flutter widgets must not contain core ministry business rules.

The mobile application is treated as an untrusted client for security
purposes.

---

## 7. State Management

Riverpod is the intended state-management and dependency-composition
solution.

Riverpod may coordinate:

- authentication state
- current church context
- current user/member information
- D Group state
- application workflows

Core business rules should remain independently testable rather than
being embedded inside UI providers.

---

## 8. Navigation

GoRouter is the intended navigation solution.

Navigation may depend on:

- authentication state
- onboarding state
- church membership state
- approval state
- system role
- D Group responsibility

Navigation restrictions are for application behavior and usability.

They do not replace backend authorization.

---

## 9. Role-Aware UI

The mobile application should adapt navigation and functionality to the
user's responsibilities.

Example Coordinator experience:

Home
D Groups
Members
Follow-ups
Curriculum
Profile

Example D Group Leader experience:

Home
My D Group
Sessions
Follow-ups
Progress
Profile

Example Discipler experience:

Home
My D Group
My Disciples
Follow-ups
Progress
Profile

Example Disciple experience:

Home
My D Group
My Progress
Profile

Exact navigation will be refined during UI design.

The UI must not assume that visibility equals authorization.

---

## 10. Backend

Supabase provides the MVP backend platform.

Capabilities include:

- authentication
- PostgreSQL
- Row Level Security
- storage
- database functions
- Edge Functions where justified
- scheduled/background processing where justified

PostgreSQL is the authoritative system of record.

Not every operation requires an Edge Function.

Use the simplest secure backend mechanism appropriate to the
requirement.

---

## 11. Data Access

Flutter presentation code should not contain arbitrary direct database
queries.

Conceptually:

Presentation
→ Application / Domain
→ Repository
→ Supabase/PostgreSQL

Repositories provide clear boundaries for backend/data operations.

This improves:

- testability
- separation of concerns
- consistent error handling
- maintainability
- reduced coupling to Supabase APIs

Do not create unnecessary abstraction layers solely for architectural
appearance.

---

## 12. Business Logic

Core business rules must be independently testable.

Examples:

- D Group assignment rules
- Leader responsibility
- attendance calculations
- consecutive absence detection
- follow-up eligibility
- duplicate follow-up prevention
- session finalization
- discipleship progression
- contextual authorization decisions

Business rules must not depend on widget rendering.

---

## 13. Authorization Model

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
Disciple Assignment

For example:

A Coordinator may view ministry-wide D Group information.

A D Group Leader may view their D Group.

A Discipler may view the Disciples assigned to their care.

A Disciple may view their own permitted information.

Being assigned responsibility in one D Group must not automatically grant
access to unrelated D Groups.

---

## 14. Database

PostgreSQL is the system of record.

Database design should use appropriate:

- primary keys
- foreign keys
- unique constraints
- check constraints
- indexes
- transactions
- Row Level Security

Historical assignments should be modeled explicitly where history matters.

Avoid storing only current relationships if doing so would destroy useful
ministry history.

Example:

Instead of only storing a current D Group ID directly on a Member,
D Group membership may require a historical relationship containing
joined/left dates and responsibility.

The final model will be determined during database design.

---

## 15. Derived Data

Authoritative events/records should be preserved.

Examples:

Attendance Records
→ Attendance Percentage

Lesson Progress Records
→ Overall Progress Percentage

Session History
→ Consecutive Absence Calculation

Follow-up Records
→ Unresolved Follow-up Count

Derived statistics should not unnecessarily replace their underlying
source records.

---

## 16. Authentication

Supabase Auth is used for authentication.

Authentication should persist securely across normal app restarts.

The application must handle:

- registration
- login
- session restoration
- token refresh
- logout
- invalid session
- revoked access
- temporary network failure

Authentication identifies the user.

Authorization determines what that user may access.

---

## 17. Row Level Security

PostgreSQL Row Level Security will enforce sensitive data access where
appropriate.

RLS design must consider:

- church isolation
- system roles
- D Group membership
- D Group leadership
- Discipler assignments
- ownership/context

RLS policies must be tested.

Flutter UI restrictions are not substitutes for RLS/backend controls.

---

## 18. Monitoring Architecture

Monitoring should use deterministic domain rules.

Conceptually:

Finalized Session
→ Attendance Records
→ Monitoring Logic
→ Attention Condition
→ Follow-up
→ Responsible Person
→ Resolution

Initial monitoring focuses on consecutive absences.

Future monitoring may include:

- attendance decline
- long-term inactivity
- stalled progress
- unresolved follow-ups

These future rules should not complicate the MVP unnecessarily.

---

## 19. Error Handling

Expected failures must be intentionally handled.

Examples:

- offline/network failure
- authentication failure
- authorization denied
- invalid membership
- validation errors
- duplicate attendance
- database constraint violations
- backend failures

User-facing errors should be understandable without exposing sensitive
internal information.

---

## 20. Testing

DiscipleTrack uses multiple testing levels.

### Unit Tests

Examples:

- absence calculations
- follow-up eligibility
- progress calculations
- domain rules

### Widget Tests

Important Flutter UI behavior.

### Integration Tests

Examples:

- repositories
- Supabase interaction
- PostgreSQL behavior
- RLS policies
- authentication flows

### End-to-End Tests

Critical workflows such as:

Login
→ Open D Group
→ Create Session
→ Record Attendance
→ Trigger Follow-up
→ Record Follow-up Action
→ Resolve Follow-up

AI-generated code is not considered verified merely because it compiles.

---

## 21. AI-Assisted Engineering

AI coding agents may assist with:

- implementation
- test generation
- edge-case discovery
- code review
- security review
- documentation
- refactoring

Agents must follow project requirements and business rules.

Deterministic tools remain quality gates:

- compiler
- formatter
- static analyzer
- tests
- database constraints
- RLS tests
- CI

---

## 22. Engineering Principle

DiscipleTrack should introduce technology because it solves a real
engineering requirement.

Do not introduce infrastructure such as:

- microservices
- Kafka
- RabbitMQ
- Kubernetes
- Redis
- complex distributed architecture

without an identified requirement.

The MVP should be professionally engineered without becoming
unnecessarily complex.