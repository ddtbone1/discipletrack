# DiscipleTrack Business Rules

This document defines important domain rules that DiscipleTrack must preserve regardless of UI implementation.

Business rules will evolve as the system and real church workflow are refined.

---

## BR-001 — Privileged Role Assignment

Users cannot grant privileged roles to themselves.

Roles such as:

- Admin
- Coordinator
- Leader

must be assigned through an authorized process.

---

## BR-002 — Church Membership

A user must belong to or be appropriately authorized for a church before accessing that church's protected information.

Joining a church does not automatically grant privileged access.

A church may require membership approval before full access is granted.

---

## BR-003 — Church Data Isolation

Protected church data must not be accessible to users from unrelated churches.

Authorization must be enforced by backend/database controls rather than Flutter UI alone.

---

## BR-004 — Leader Access Scope

Being assigned the Leader role does not automatically grant access to every member.

A Leader's access should be limited according to their authorized group/member assignments.

---

## BR-005 — Historical Assignment Integrity

Changing a member's:

- group
- leader
- membership status

must not unintentionally destroy historical information.

Past attendance, progress, sessions, and follow-ups must remain historically meaningful.

---

## BR-006 — Curriculum Is Church Data

Church-specific curricula, stages, and lessons must not be hard-coded into Flutter.

Authorized users manage curriculum as church-owned data.

---

## BR-007 — Curriculum Structure

A curriculum contains ordered stages.

Stages contain ordered lessons.

Member progress must reference the relevant curriculum/lesson rather than storing only a general percentage.

---

## BR-008 — Attendance Uniqueness

A member can have at most one attendance record for a particular session.

The database should enforce this invariant where possible.

---

## BR-009 — Attendance Source of Truth

Individual attendance records are the authoritative attendance data.

Statistics such as:

- attendance percentage
- sessions attended
- sessions missed
- consecutive absences
- last attendance date

must be derived from appropriate underlying records or safely maintained derived data.

---

## BR-010 — Supported Attendance States

The MVP supports:

- Present
- Absent
- Late
- Excused

The exact statistical treatment of Late and Excused attendance must be explicitly defined before attendance analytics are finalized.

---

## BR-011 — Attendance and Progress Are Separate

Attending a discipleship session does not automatically mean a lesson has been completed.

Lesson progress must be recorded according to the discipleship workflow.

---

## BR-012 — Session Ownership

Attendance records must belong to a valid discipleship session.

Leaders may only manage sessions they are authorized to manage.

---

## BR-013 — Session Lifecycle

MVP sessions support at least:

- Draft
- Finalized

Finalization represents completion of the official session record.

Rules governing post-finalization edits must be explicitly controlled rather than allowing unrestricted historical modification.

---

## BR-014 — Consecutive Absence Monitoring

The system must be capable of determining consecutive absences from relevant finalized attendance records.

When the configured threshold is reached, the member becomes eligible for follow-up attention.

The threshold should not require changing application source code when church configuration is introduced.

---

## BR-015 — Deterministic Monitoring

Core monitoring conditions such as consecutive absence detection must use deterministic business rules.

AI must not be the source of truth for whether an attendance threshold was reached.

---

## BR-016 — Follow-up Responsibility

A follow-up must identify:

- the member requiring attention
- why follow-up is required
- who is responsible
- its current status
- relevant actions/history

This prevents ambiguous responsibility for member care.

---

## BR-017 — Follow-up Deduplication

The system must avoid creating unnecessary duplicate unresolved follow-ups for the same member and equivalent active condition.

Repeated monitoring must not create a new identical task every time the rule executes.

---

## BR-018 — Follow-up History

Resolving a follow-up must not delete it.

Resolved follow-ups remain part of the member's discipleship care history.

---

## BR-019 — Follow-up Resolution

A follow-up cannot be considered resolved merely because it was opened or viewed.

Resolution should represent an intentional completion of the follow-up workflow.

The exact required resolution information will be defined during feature design.

---

## BR-020 — Discipleship Progress

Member progress must be associated with specific curriculum lessons.

Basic MVP states are:

- Not Started
- In Progress
- Completed

Overall progress percentages are derived from the relevant lesson progress records.

---

## BR-021 — Membership Status vs Engagement

Administrative membership status and discipleship engagement should not be assumed to mean the same thing.

A person may remain an active church member while showing low discipleship participation.

Future monitoring may introduce engagement/health states separately.

---

## BR-022 — Auditability

Important actions should retain sufficient information to identify the responsible user and time of action where appropriate.

This particularly applies to:

- attendance changes
- role changes
- assignments
- progress updates
- follow-up actions

---

## BR-023 — No Destructive Historical Deletion

Operational deletion should not casually remove records required for ministry history or system integrity.

Where appropriate, records should use lifecycle states or archival behavior instead of destructive deletion.

Exact retention rules will be defined during database design.

---

## BR-024 — Client Is Not Trusted

Flutter client behavior must never be the sole enforcement mechanism for sensitive business permissions.

A modified or compromised client must not be able to bypass backend authorization simply by calling backend operations directly.

---

## BR-025 — MVP Scope Protection

Features explicitly classified as post-MVP should not be introduced during MVP implementation without an intentional scope decision.

This protects the project from uncontrolled feature expansion and allows the core discipleship workflow to be validated first.