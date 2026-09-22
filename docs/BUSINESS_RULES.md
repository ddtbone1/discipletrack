# DiscipleTrack Business Rules

This document defines important domain rules that DiscipleTrack must
preserve regardless of UI or implementation details.

These rules will evolve as the church workflow is refined.

---

## BR-001 — System Roles and D Group Responsibilities Are Different

DiscipleTrack distinguishes between system/church roles and contextual
D Group responsibilities.

System/church roles:

- Admin
- Discipleship Coordinator
- Member

D Group responsibilities:

- D Group Leader
- Discipler
- Disciple

A D Group responsibility must not automatically grant unrelated
church-wide system authority.

---

## BR-002 — Privileged System Role Assignment

Users cannot grant privileged system roles to themselves.

Admin and Discipleship Coordinator access must be assigned through an
authorized process.

---

## BR-003 — D Group Responsibility Assignment

A Member cannot arbitrarily make themselves a:

- D Group Leader
- Discipler

These responsibilities must be assigned through an authorized ministry
workflow.

---

## BR-004 — Church Membership

A user must belong to or be appropriately authorized for a church before
accessing that church's protected information.

Joining a church does not automatically grant privileged access.

Membership may require approval.

---

## BR-005 — Church Data Isolation

Protected information belonging to one church must not be accessible to
unauthorized users from another church.

Backend/database authorization must enforce this rule.

---

## BR-006 — Admin Responsibility

Admin is primarily responsible for:

- church/system configuration
- accounts
- memberships
- privileged system roles
- access/security administration

Admin is not intended to be the primary operator of everyday discipleship
workflows.

---

## BR-007 — Coordinator Responsibility

The Discipleship Coordinator is responsible for ministry-wide
discipleship operations.

This includes oversight of:

- D Groups
- D Group Leaders
- Disciplers
- Disciples
- curriculum
- attendance
- progress
- follow-ups

---

## BR-008 — D Group Leader Scope

A D Group Leader is responsible for their assigned D Group.

Being a D Group Leader does not automatically grant access to unrelated
D Groups.

---

## BR-009 — One Primary D Group Leader

Each active D Group should have one primary active D Group Leader.

Changes in leadership should preserve meaningful leadership history.

---

## BR-010 — Multiple Disciplers

A D Group may contain multiple Disciplers.

Disciplers operate within the scope of their authorized D Group and
disciple assignments.

---

## BR-011 — Multiple Disciples

A D Group may contain multiple Disciples.

Disciple membership should preserve meaningful assignment history.

---

## BR-012 — Discipler-to-Disciple Responsibility

The system must eventually be able to determine which Discipler is
responsible for which Disciple when individual responsibility is used.

The exact cardinality and reassignment rules will be finalized during
database/domain design.

---

## BR-013 — Historical Assignment Integrity

Changing a person's:

- D Group
- D Group responsibility
- D Group Leader
- Discipler
- membership status

must not unintentionally destroy historical ministry records.

---

## BR-014 — Curriculum Is Church-Owned Data

Church-specific curricula, stages, and lessons must not be hard-coded
into Flutter.

They are configurable church-owned data.

---

## BR-015 — Curriculum Structure

A curriculum contains ordered stages.

Stages contain ordered lessons.

Progress should reference actual curriculum/lesson records.

---

## BR-016 — Attendance Uniqueness

A person can have at most one attendance record for a particular
session.

This should be enforced at the database level where possible.

---

## BR-017 — Attendance Source of Truth

Individual attendance records are authoritative.

Values such as:

- attendance percentage
- sessions attended
- sessions missed
- consecutive absences
- last attendance

are derived from underlying records or safely maintained derived data.

---

## BR-018 — Attendance States

MVP attendance states are:

- Present
- Absent
- Late
- Excused

The statistical treatment of Late and Excused must be explicitly
defined before attendance analytics are finalized.

---

## BR-019 — Attendance and Progress Are Separate

Attending a D Group session does not automatically complete a
discipleship lesson.

Lesson progress is managed separately.

---

## BR-020 — Session Authorization

Only appropriately authorized users may create or modify sessions for a
D Group.

Authorization depends on the user's church and D Group responsibilities.

---

## BR-021 — Session Lifecycle

MVP sessions support:

- Draft
- Finalized

A finalized session represents an official completed session record.

Post-finalization modification must be controlled rather than
unrestricted.

---

## BR-022 — Monitoring Uses Finalized Data

Attendance monitoring should operate using appropriate finalized session
data.

Draft/incomplete session records should not incorrectly trigger
discipleship follow-ups.

---

## BR-023 — Consecutive Absence Monitoring

DiscipleTrack must be capable of determining consecutive absences from
relevant attendance history.

When the configured threshold is reached, the Disciple becomes eligible
for follow-up attention.

---

## BR-024 — Deterministic Monitoring

Core monitoring rules must be deterministic.

AI must not determine whether basic attendance conditions occurred.

---

## BR-025 — Follow-up Responsibility

A follow-up must identify:

- Disciple
- reason
- D Group/context
- responsible person
- status
- actions/history

Responsibility should be explicit rather than assumed.

---

## BR-026 — Follow-up Assignment

Where an individual Discipler is responsible for a Disciple, follow-up
should normally be assignable to that Discipler.

A D Group Leader must be able to oversee relevant D Group follow-ups.

A Coordinator must be able to oversee ministry-wide follow-ups.

Exact escalation rules will be defined during follow-up feature design.

---

## BR-027 — Follow-up Deduplication

Repeated monitoring must not generate unnecessary duplicate unresolved
follow-ups for the same Disciple and equivalent active condition.

---

## BR-028 — Follow-up History

Resolved follow-ups must remain part of the Disciple's historical care
record.

Resolving a follow-up must not delete it.

---

## BR-029 — Follow-up Resolution

Viewing a follow-up does not resolve it.

Resolution requires an intentional completion of the follow-up workflow.

Required resolution information will be finalized during feature design.

---

## BR-030 — Progress Source of Truth

Progress should be represented using individual lesson-progress records.

Overall percentages and stages are derived from those records where
appropriate.

---

## BR-031 — Membership Status and Engagement Are Different

Administrative church membership and discipleship engagement are
different concepts.

A church Member may remain administratively active while their
discipleship participation is declining.

Future engagement/health monitoring must preserve this distinction.

---

## BR-032 — Contextual Authorization

Authorization may depend on:

- authenticated user
- church membership
- system role
- D Group membership
- D Group responsibility
- Disciple assignment

Role alone is not always sufficient.

---

## BR-033 — Client Is Not Trusted

Flutter must not be the sole enforcement mechanism for sensitive access.

A modified client must not be capable of bypassing backend authorization.

---

## BR-034 — Auditability

Important actions should retain appropriate information about:

- what occurred
- who performed it
- when it occurred

Particularly important actions include:

- role changes
- D Group assignments
- attendance changes
- progress changes
- follow-up actions

---

## BR-035 — Historical Records Should Not Be Casually Deleted

Records required for meaningful discipleship history should not be
destructively deleted during normal workflows.

Archival/lifecycle approaches should be used where appropriate.

Exact retention rules will be defined during database design.

---

## BR-036 — MVP Scope Protection

Post-MVP functionality must not be introduced accidentally during MVP
development.

Features should be added through intentional scope decisions after the
core discipleship workflow is stable.