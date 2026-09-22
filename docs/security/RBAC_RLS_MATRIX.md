# DiscipleTrack — RBAC & RLS Matrix

## Purpose

This document defines authorization for the DiscipleTrack MVP.

Two concepts must remain separate:

- *RBAC* — what a role is allowed to do.
- *RLS* — which records that user is allowed to access.

Authorization must be enforced by Supabase/PostgreSQL, not only by Flutter.

---

# 1. Role Model

## Church-Level Roles

### ADMIN

Responsible for technical/system administration.

Examples:

- Church configuration
- Church membership administration
- System-level role administration

ADMIN does not automatically receive access to sensitive discipleship care notes.

### COORDINATOR

Responsible for church-wide discipleship operations.

Examples:

- D Groups
- Leaders
- Disciplers
- Disciples
- Transfers
- Progress oversight
- Attendance oversight
- Follow-ups
- Promotions
- Church announcements

---

## D Group Responsibilities

### LEADER

Responsible for one assigned D Group.

Access is primarily scoped to members of that D Group.

### DISCIPLER

Responsible for assigned Disciples.

Access to sensitive disciple information is primarily scoped to their active assignments.

### DISCIPLE

Normal participant in the discipleship process.

Primarily accesses their own information.

---

# 2. General Access Matrix

| Capability | Admin | Coordinator | Leader | Discipler | Disciple |
|---|---|---|---|---|---|
| View own profile | Yes | Yes | Yes | Yes | Yes |
| Edit own profile | Yes | Yes | Yes | Yes | Yes |
| Manage church settings | Yes | No | No | No | No |
| Approve church membership | Yes | Yes | No | No | No |
| Manage church roles | Yes | No | No | No | No |
| View church members | Yes | Yes | Own D Group | Assigned Disciples | Self |
| Create/manage D Groups | No | Yes | No | No | No |
| Assign Leader | No | Yes | No | No | No |
| Assign Discipler | No | Yes | No | No | No |
| Assign Disciple to D Group | No | Yes | No | No | No |
| Assign Disciple to Discipler | No | Yes | No | No | No |
| Transfer Disciple | No | Yes | No | No | No |
| Promote Disciple | No | Yes | No | No | No |
| Create gathering | No | Yes | Own D Group | Own D Group | No |
| Record draft attendance | No | Yes | Own D Group | Own D Group | No |
| Finalize attendance | No | Yes | Own D Group | No | No |
| View attendance | Limited | Church-wide | Own D Group | Own D Group | Self |
| Log discipleship meeting | No | Yes | Own D Group | Assigned Disciples | No |
| View progress | Limited | Church-wide | Own D Group | Assigned Disciples | Self |
| Confirm lesson completion | No | Yes | Own D Group | No | No |
| View attention conditions | No | Church-wide | Own D Group | Assigned Disciples | Self summary |
| View internal follow-up notes | No | Church-wide | Own D Group | Assigned Follow-ups | No |
| Add follow-up action | No | Yes | Own D Group | Assigned Follow-ups | No |
| Resolve follow-up | No | Yes | Own D Group | Assigned Follow-ups | No |
| Create church announcement | No | Yes | No | No | No |
| Create D Group announcement | No | Yes | Own D Group | No | No |

---

# 3. Table-Level Access

## profiles

SELECT:

- User → own profile
- Coordinator → profiles required for church ministry operations
- Leader → members of own active D Group
- Discipler → assigned Disciples
- Admin → profiles required for system/member administration

UPDATE:

- User → own allowed profile fields

Sensitive role or membership changes must not be performed by updating profiles.

---

## churches

SELECT:

- Active church members → own church

UPDATE:

- ADMIN → allowed church configuration

Church management should use controlled operations where appropriate.

---

## church_memberships

SELECT:

- ADMIN → own church
- COORDINATOR → own church
- LEADER → members of own D Group
- DISCIPLER → assigned Disciples
- DISCIPLE → self

INSERT / UPDATE:

Membership approval and status transitions should use controlled operations.

Direct arbitrary client updates should not be allowed.

---

## church_role_assignments

SELECT:

- ADMIN → own church
- COORDINATOR → role information needed for ministry operation
- User → own roles where needed

WRITE:

- ADMIN only through controlled role-management operations.

---

## d_groups

SELECT:

- ADMIN → own church where required
- COORDINATOR → all church D Groups
- LEADER → own D Group
- DISCIPLER → own D Group
- DISCIPLE → own D Group

WRITE:

- COORDINATOR → controlled D Group management operations

---

## d_group_memberships

SELECT:

- COORDINATOR → church-wide
- LEADER → own D Group
- DISCIPLER → own D Group where required
- DISCIPLE → own membership and permitted group information

WRITE:

Use controlled operations for:

- assignment
- transfer
- responsibility change
- promotion

Do not allow arbitrary direct client mutation.

---

## discipler_assignments

SELECT:

- COORDINATOR → church-wide
- LEADER → own D Group
- DISCIPLER → own assignments
- DISCIPLE → own active Discipler relationship

WRITE:

Use controlled operations for assignment and reassignment.

---

# 4. Gathering & Attendance Access

## d_group_gatherings

SELECT:

- COORDINATOR → church-wide
- LEADER → own D Group
- DISCIPLER → own D Group
- DISCIPLE → own D Group

INSERT:

- COORDINATOR
- LEADER for own D Group
- DISCIPLER for own D Group

UPDATE:

- Appropriate authorized users while DRAFT
- Finalization through controlled operation

DELETE:

Avoid normal deletion.

Use lifecycle state where appropriate.

---

## gathering_attendance

SELECT:

- COORDINATOR → church-wide
- LEADER → own D Group
- DISCIPLER → own D Group
- DISCIPLE → own attendance

WRITE:

Draft attendance:

- COORDINATOR
- LEADER for own D Group
- DISCIPLER for own D Group

Finalized attendance correction:

- COORDINATOR
- LEADER for own D Group

Corrections must use controlled operations and audit logging.

---

# 5. Curriculum & Progress Access

## curricula

SELECT:

- Active church members

WRITE:

Curriculum mutation is not part of the normal MVP user workflow.

The MVP uses one fixed church curriculum.

---

## curriculum_lessons

SELECT:

- Active church members

WRITE:

Not part of normal MVP client operations.

---

## discipleship_meetings

SELECT:

- COORDINATOR → church-wide
- LEADER → own D Group
- DISCIPLER → meetings relevant to own assignments
- DISCIPLE → meetings in which they participated

INSERT:

- COORDINATOR
- LEADER for own D Group
- DISCIPLER for assigned Disciples

Meeting creation must pass server-side business validation.

VOID:

- COORDINATOR
- LEADER for own D Group where authorized

Voiding must be audited.

---

## discipleship_meeting_participants

SELECT:

Follow the visibility of the parent discipleship meeting.

WRITE:

Participant creation/voiding should occur through controlled meeting operations.

---

## disciple_lesson_progress

SELECT:

- COORDINATOR → church-wide
- LEADER → own D Group
- DISCIPLER → assigned Disciples
- DISCIPLE → self

WRITE:

Do not allow arbitrary client updates.

Progress transitions must be controlled by business operations.

Leader confirmation:

- LEADER → own D Group
- COORDINATOR → authorized oversight

---

## ministry_role_transitions

SELECT:

- COORDINATOR
- relevant LEADER
- affected user for appropriate personal history

INSERT:

Only through the controlled promotion transaction.

---

# 6. Monitoring & Follow-up Access

## attention_conditions

SELECT:

- COORDINATOR → church-wide
- LEADER → own D Group
- DISCIPLER → conditions relevant to assigned Disciples
- DISCIPLE → limited/self-facing summary only if exposed by the UI

WRITE:

System-controlled monitoring operations only.

Clients must not manually create monitoring conditions.

---

## follow_ups

SELECT:

- COORDINATOR → church-wide
- LEADER → own D Group
- DISCIPLER → assigned follow-ups
- DISCIPLE → no internal care-note access

WRITE:

Authorized:

- COORDINATOR
- relevant LEADER
- assigned DISCIPLER

Important transitions should use controlled operations.

---

## follow_up_actions

SELECT:

- COORDINATOR → church-wide
- LEADER → own D Group
- DISCIPLER → actions for assigned follow-ups

DISCIPLE:

- No access to internal follow-up notes.

INSERT:

- COORDINATOR
- relevant LEADER
- assigned DISCIPLER

Existing actions should normally remain immutable.

---

# 7. Announcements

## announcements

SELECT:

CHURCH announcement:

- active members of the church

D_GROUP announcement:

- active members of that D Group
- Coordinator

INSERT:

- COORDINATOR → CHURCH or D_GROUP
- LEADER → own D_GROUP only

UPDATE:

- Author where still authorized
- Coordinator where ministry oversight requires it

DELETE:

Prefer controlled removal rather than unrestricted deletion.

---

# 8. Church Settings

## church_settings

SELECT:

- ADMIN
- COORDINATOR where settings affect ministry behavior

UPDATE:

- ADMIN

Changes should be audited.

---

# 9. Audit Events

## audit_events

INSERT:

System-controlled operations.

Normal Flutter clients should not create arbitrary audit records.

SELECT:

Restrict to authorized administrative/oversight use.

Audit data must not become a way to bypass normal privacy restrictions.

---

# 10. Controlled Database Operations

The following should NOT be implemented as multiple independent Flutter writes.

Use transactional PostgreSQL functions / RPCs or equivalent trusted backend operations.

Recommended operations:

- request_join_church()
- approve_church_membership()
- assign_church_role()
- create_d_group()
- assign_d_group_leader()
- assign_disciple_to_group()
- assign_discipler()
- reassign_discipler()
- transfer_disciple()
- create_gathering()
- save_draft_attendance()
- finalize_gathering()
- correct_finalized_attendance()
- record_discipleship_meeting()
- void_discipleship_meeting()
- void_meeting_participant()
- confirm_lesson_completion()
- promote_disciple_to_discipler()
- add_follow_up_action()
- resolve_follow_up()
- reassign_follow_up()

Each operation must:

1. Authenticate the caller.
2. Determine church membership.
3. Verify role/responsibility.
4. Verify record scope.
5. Validate business rules.
6. Execute atomically where multiple writes are involved.
7. Create audit information when required.

---

# 11. Security Principles

## Least Privilege

Users receive only the access required for their ministry responsibility.

## Server-Side Enforcement

Flutter visibility is not security.

Hiding a button does not prevent an unauthorized database request.

## RLS Everywhere

All user-accessible domain tables should have Row Level Security enabled.

## Sensitive Ministry Information

Follow-up notes require stricter access than ordinary member information.

ADMIN status alone does not automatically grant access to pastoral/discipleship care notes.

## Historical Integrity

Important historical records should normally be ended, resolved, cancelled, or voided instead of physically deleted.

## Trusted State Transitions

Complex business transitions must execute through controlled server-side operations rather than arbitrary direct table updates.

---

# Core Authorization Rule

Church-level roles determine church-wide authority.

D Group responsibilities determine contextual ministry authority.

Assignments determine direct care responsibility.

RLS must evaluate all three when necessary.