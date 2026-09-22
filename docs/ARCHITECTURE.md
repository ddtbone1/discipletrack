# DiscipleTrack Architecture

## 1. Architecture Goal

DiscipleTrack should be engineered as a maintainable production application while keeping the MVP technically simple.

The architecture should prioritize:

- clear separation of concerns
- security
- testability
- maintainability
- understandable business logic
- reliable data
- ability to evolve

The project should not introduce complexity simply to appear sophisticated.

---

## 2. High-Level Architecture

DiscipleTrack MVP consists of:

Flutter Mobile Application
→ Application / Domain Logic
→ Repository / Data Access
→ Supabase
→ PostgreSQL

Supabase provides backend capabilities including:

- authentication
- PostgreSQL database
- Row Level Security
- storage
- database functions
- backend/Edge Functions where appropriate

---

## 3. Architecture Style

DiscipleTrack uses a modular monolithic architecture.

Business capabilities are separated into logical domains without deploying each domain as an independent microservice.

Initial domains include:

- Authentication
- Churches / Organizations
- Membership
- Groups
- Curriculum
- Sessions
- Attendance
- Progress
- Monitoring
- Follow-ups
- Dashboard / Reporting

Domain boundaries should be respected even though they belong to one application/system.

---

## 4. Mobile Client

Flutter and Dart are used for the Android and iOS application.

The Flutter application is responsible for:

- presentation
- navigation
- client-side state
- user interaction
- appropriate client-side validation
- communication with backend services
- local device functionality

Flutter widgets must not contain core business rules.

The mobile client must be treated as an untrusted client for security purposes.

---

## 5. State Management

Riverpod is the intended state-management and dependency-composition solution.

State management should coordinate application behavior without becoming the location for every business rule.

Core business logic should remain independently testable.

---

## 6. Navigation

GoRouter is the intended navigation solution.

Navigation must account for application state such as:

- authentication
- onboarding
- church membership
- membership approval
- appropriate role/access state

Navigation restrictions improve user experience but do not replace backend authorization.

---

## 7. Backend Platform

Supabase is the backend platform for the MVP.

PostgreSQL is the authoritative system of record.

Supabase capabilities may be used for:

- Auth
- PostgreSQL
- Row Level Security
- Storage
- Realtime where justified
- database functions
- Edge Functions where justified
- scheduled/background processing where required

Not every operation requires an Edge Function.

The simplest secure implementation appropriate to the business requirement should be preferred.

---

## 8. Data Access

Flutter presentation components should not contain arbitrary direct database operations.

Data access should occur through clearly defined repository/data-access boundaries.

Conceptually:

UI
→ Application/Domain Logic
→ Repository
→ Supabase/PostgreSQL

This improves:

- testability
- separation of concerns
- error handling
- maintainability
- ability to change backend implementation details

Abstraction should remain proportional to actual project complexity.

---

## 9. Business Logic

Core business rules must not depend on Flutter widgets.

Examples include:

- attendance calculations
- consecutive absence detection
- follow-up eligibility
- duplicate follow-up prevention
- session lifecycle rules
- discipleship progression
- permission-related domain rules

These rules should be independently testable.

---

## 10. Database

PostgreSQL is the system of record.

The database should use appropriate:

- primary keys
- foreign keys
- unique constraints
- check constraints
- indexes
- transactions
- Row Level Security

Database design should preserve meaningful historical information.

Derived values should not unnecessarily become authoritative stored state.

For example, individual attendance records are authoritative while attendance percentages are calculated from those records.

---

## 11. Database Changes

Database schema changes must eventually be represented by version-controlled migrations.

The project should not depend on undocumented manual production database modifications.

This allows the database structure to be:

- reproducible
- reviewable
- testable
- deployable across environments

---

## 12. Authentication

Supabase Auth is used for authentication.

Authentication sessions should persist securely across normal application restarts.

The application must correctly handle:

- initial authentication
- session restoration
- token/session refresh
- logout
- invalid sessions
- revoked access
- temporary network failures

Authentication answers:

"Who is this user?"

Authorization is treated separately.

---

## 13. Authorization

Authorization must be enforced on the backend/database side.

Authorization may depend on:

- authenticated user
- church membership
- role
- group assignment
- leader/member relationship
- ownership of a resource

PostgreSQL Row Level Security will be used where appropriate.

Example:

A Leader may be allowed to access members belonging to groups they lead.

Being a Leader must not automatically grant access to every church member.

Flutter may hide unauthorized functionality for usability, but client-side visibility is not considered a security mechanism.

---

## 14. Church Data Isolation

Church-owned information must be scoped appropriately.

Users from one church must not gain unauthorized access to another church's protected data.

The exact organization/church tenancy model will be defined during database design.

---

## 15. Error Handling

Expected failures should be handled intentionally.

Examples include:

- no network connection
- authentication failure
- session expiration
- authorization denied
- validation errors
- duplicate operations
- database constraint violations
- backend failure

Users should receive understandable feedback.

Internal implementation details and sensitive information should not be exposed through user-facing errors.

---

## 16. Testing

DiscipleTrack should use multiple levels of automated testing.

### Unit Tests

Used for isolated business logic such as:

- attendance calculations
- absence detection
- follow-up rules
- progression rules

### Widget Tests

Used for important Flutter UI/component behavior.

### Integration Tests

Used for interactions between:

- application services
- repositories
- Supabase
- PostgreSQL
- RLS/authorization

### End-to-End Tests

Used for critical workflows such as:

Login
→ Open Group
→ Create Session
→ Record Attendance
→ Trigger Follow-up
→ Resolve Follow-up

AI-generated implementation is not considered correct simply because it compiles.

---

## 17. CI/CD

The repository should eventually use automated quality gates.

Pull requests should run appropriate checks such as:

- formatting
- static analysis
- unit tests
- integration tests where applicable
- dependency/security checks where appropriate

Code should not be considered complete when required quality checks fail.

---

## 18. AI-Assisted Development

AI coding agents may assist with:

- implementation
- testing
- code review
- edge-case discovery
- documentation
- refactoring
- security review

Agents must follow the project's specifications, business rules, and architectural decisions.

AI output is not automatically trusted.

Deterministic tools such as:

- compilers
- static analyzers
- tests
- database constraints
- CI checks

remain authoritative quality gates.

---

## 19. Engineering Principle

DiscipleTrack should introduce technology because it solves an identified engineering problem.

Do not introduce technologies such as:

- microservices
- Kubernetes
- Kafka
- RabbitMQ
- Redis
- complex distributed infrastructure

unless actual system requirements justify them.

The MVP should remain simple enough to understand while still following strong engineering practices.