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

## Member Without a D Group

An ACTIVE church member who holds no D Group responsibility is a valid
state, not a separate stored role. Every newly approved user begins here.

Such a member may:

- view and update allowed fields of their own profile
- view their own church membership
- view their church
- view CHURCH-scope announcements
- read the fixed curriculum

They may not access D Group attendance, discipleship progress, attention
conditions, follow-ups or D Group announcements until the relevant
relationship exists.

---

# 1a. Membership Status Gating

Authorization depends on membership status as well as role and
responsibility. This predicate is defined once here and applies
everywhere.

Wherever a policy in this document refers to a church member, it means:

church_memberships.status = 'ACTIVE'

Status effects:

PENDING
→ may access only the minimum onboarding state required: their own
  pending membership row and the id, name and status of the church they
  requested
→ no other church data, no announcements, no curriculum, no member
  visibility

ACTIVE
→ normal access according to role, responsibility and assignment

INACTIVE / TRANSFERRED / ARCHIVED
→ no protected church access
→ their historical records remain in the database and remain visible to
  appropriately authorized ministry roles

Privileged roles require an ACTIVE membership to be effective. A church
role assignment attached to a non-ACTIVE membership grants nothing.

---

# 2. General Access Matrix

"Member" below means an ACTIVE church member who currently holds no
D Group responsibility. This is a valid state, not a stored role.

| Capability | Admin | Coordinator | Leader | Discipler | Disciple | Member |
|---|---|---|---|---|---|---|
| View own profile | Yes | Yes | Yes | Yes | Yes | Yes |
| Edit own profile | Yes | Yes | Yes | Yes | Yes | Yes |
| View own church membership | Yes | Yes | Yes | Yes | Yes | Yes |
| View own church | Yes | Yes | Yes | Yes | Yes | Yes |
| Read curriculum | Yes | Yes | Yes | Yes | Yes | Yes |
| Manage church configuration | Yes | No | No | No | No | No |
| Manage ministry settings | No | Yes | No | No | No | No |
| Approve church membership | Yes | Yes | No | No | No | No |
| Manage church roles | Yes | No | No | No | No | No |
| View church members | Yes | Yes | Own D Group | Assigned Disciples | Self | Self |
| Create/manage D Groups | No | Yes | No | No | No | No |
| Assign Leader | No | Yes | No | No | No | No |
| Assign Discipler | No | Yes | No | No | No | No |
| Assign Disciple to D Group | No | Yes | No | No | No | No |
| Assign Disciple to Discipler | No | Yes | No | No | No | No |
| Transfer Disciple | No | Yes | No | No | No | No |
| Promote Disciple | No | Yes | No | No | No | No |
| Create gathering | No | Yes | Own D Group | No | No | No |
| Record draft attendance | No | Others church-wide | Others in own D Group | Others in own D Group | No | No |
| Finalize attendance | No | Yes | Own D Group | No | No | No |
| Cancel gathering | No | Yes | Own D Group | No | No | No |
| View attendance | No | Church-wide | Own D Group | Own D Group | Self | No |
| Record discipleship meeting, held or missed | No | Fallback | Fallback, own D Group | Assigned Disciples | No | No |
| Void discipleship meeting or participant | No | Yes | Own D Group | Self-recorded | No | No |
| View discipleship meeting history | No | Church-wide | Own D Group | Own Discipler meetings | Self | No |
| View progress | No | Church-wide | Own D Group | Assigned Disciples | Self | No |
| Confirm lesson completion | No | Oversight | Own D Group | No | No | No |
| Reopen lesson completion | No | Yes | No | No | No | No |
| View attention conditions | No | Church-wide | Own D Group | Assigned Disciples | Self summary | No |
| View internal follow-up notes | No | Church-wide | Own D Group | Assigned Follow-ups | No | No |
| Add follow-up action | No | Yes | Own D Group | Assigned Follow-ups | No | No |
| Resolve follow-up | No | Yes | Own D Group | Assigned Follow-ups | No | No |
| Create church announcement | No | Yes | No | No | No | No |
| View church announcement | Yes | Yes | Yes | Yes | Yes | Yes |
| Create D Group announcement | No | Oversight | Own D Group | No | No | No |
| View D Group announcement | No | Church-wide | Own D Group | Own D Group | Own D Group | No |

Notes on specific cells:

*Manage church configuration* covers church identity, join code and
system-level configuration. *Manage ministry settings* covers
church_settings values that govern ministry behaviour, currently
consecutive_absence_threshold, consecutive_missed_meeting_threshold and
follow_up_due_days. Ministry setting
changes are audited. ADMIN retains read access to church_settings where
operationally necessary.

*Record discipleship meeting* covers held meetups and missed meetups,
including each participant's attendance outcome. The Discipler is the
normal recorder. COORDINATOR and LEADER may record on behalf of the
responsible Discipler as a fallback; recorded_by shows who entered it.
DiscipleTrack does not schedule meetings, so there is no capability to
create a meeting before it happens.

*Void discipleship meeting or participant* shows "Self-recorded" for
DISCIPLER: a Discipler may void a meeting, or a participant outcome,
whose recorded_by is themselves and whose
discipler_d_group_membership_id is their own active DISCIPLER
membership. LEADER and COORDINATOR retain oversight and fallback void
authority. Every void is audited and remains subject to COMPLETED
protection. Corrections are void and re-record; meeting and outcome
history is never edited.

*View discipleship meeting history* shows "Self" for DISCIPLE: a
Disciple sees the meetings in which they are a participant, including
their own missed-meetup outcomes. No Disciple may record, confirm or
change their own meeting outcome.

*Confirm lesson completion* and *Create D Group announcement* show
"Oversight" for COORDINATOR. The D Group Leader is the normal authority
in both cases. Coordinator capability exists as a ministry-oversight
fallback, for example where a D Group currently has no active Leader.
Coordinator lesson confirmation is attributable through confirmed_by and
is audited.

ADMIN has no attendance or discipleship progress access. Administering
the system does not confer ministry-care access. Where the same person
needs both, assign COORDINATOR separately.

DISCIPLER may record draft attendance for their own D Group but may not
create or cancel the gathering itself.

No person may record or correct their own attendance, in any role. Where
a D Group's only authorized recorder is the Leader, another DISCIPLER in
that D Group or the COORDINATOR records the Leader's status. See
DATABASE_CONSTRAINTS.md section 3.

---

# 2a. Scoping Predicates

"Own D Group" is not one predicate. Each domain is anchored to whatever
that record actually belongs to, because the domains have different
historical semantics. Implementations must use the predicate named here
rather than inventing a universal join.

## Current-membership scope

The member currently holds an active d_group_membership in the viewer's
D Group.

Used where the record describes the person's ongoing journey and the
viewer needs it to carry out current discipleship responsibility.

Applies to: disciple_lesson_progress.

A transfer therefore does not hide or reset prior lesson progress from
the member's new Leader or Discipler. Progress belongs to the person's
church journey.

## Gathering-anchored scope

The record's gathering belongs to the viewer's D Group.

Used where the record describes an event that happened inside a specific
D Group.

Applies to: d_group_gatherings, gathering_attendance.

Historical attendance stays with the D Group in which it occurred. A new
D Group does not automatically gain access to detailed historical
attendance rows from a member's previous group merely because that
member transferred, and a former Leader retains access to the gatherings
their own group held.

Aggregate attendance metrics defined in DATABASE_CONSTRAINTS.md section
11 span a member's whole history. Where a current Leader or Discipler
needs those aggregates, they are served through a trusted read path that
returns aggregates without exposing another D Group's row-level detail.

## Meeting-context scope

The meeting's d_group_id is the viewer's D Group, or the meeting's
discipler_d_group_membership_id is the viewer's own.

Used where the record describes work done in a particular ministry
context.

Applies to: discipleship_meetings, discipleship_meeting_participants.

Historical meetings stay associated with the D Group and Discipler under
which they occurred. They are not reinterpreted through the member's
current D Group.

## Care-responsibility scope

The viewer is the assignee, the Leader of the case's D Group, or the
Coordinator.

Applies to: attention_conditions, follow_ups, follow_up_actions.

Follows current care responsibility as established by the assignment and
escalation rules, not by historical group membership.

## Coordinator

COORDINATOR retains church-wide ministry visibility across all of the
above, as documented per table below.

---

# 3. Table-Level Access

## profiles

SELECT:

- User → own profile
- Coordinator → profiles required for church ministry operations
- Leader → members of own active D Group
- Discipler → assigned Disciples
- Admin → profiles required for system/member administration

Implemented so far: own profile, and for ADMIN and COORDINATOR the
profiles of anyone holding a membership row (any status) in a church
they administer, which is what the membership-request list needs.
Leader and Discipler scopes arrive with the D Group slice.

INSERT:

- Not permitted for clients. A profile row is created automatically from auth.users through a trusted database trigger.

UPDATE:

- User → own allowed profile fields, currently full_name, phone and avatar_url
- profiles.id is immutable
- full_name may be corrected but not blanked

DELETE:

- Not permitted for clients.

Sensitive role or membership changes must not be performed by updating profiles.

---

## churches

SELECT:

- Active church members → own church
- PENDING members → own requested church (section 1a: id, name, status)

Column-level: authenticated may SELECT only id, name and status.
join_code is not readable by any client role, and `select=*` is refused.
anon holds no grant.

Lookup by join code is NOT available as a direct client SELECT. An
unapproved user must use lookup_church_by_join_code(), a trusted
controlled operation returning only minimal confirmation information.

UPDATE:

- ADMIN → allowed church configuration

Join code regeneration uses regenerate_join_code(), an audited
ADMIN-only controlled operation.

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

Implemented: request_join_church() (INSERT as PENDING),
approve_church_membership(), reject_church_membership() and
complete_onboarding(). Clients hold no INSERT or UPDATE policy on the
table. The pending-request list for approvers is a plain SELECT under
the ADMIN / COORDINATOR own-church scope, embedding the applicant's
profile through the user_id foreign key.

---

## church_role_assignments

SELECT:

- ADMIN → own church
- COORDINATOR → role information needed for ministry operation
- User → own roles where needed (implemented: own active and ended
  roles, so the client can show approver entry points; authority is
  still decided server-side on every operation)

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

Lifecycle (ACTIVE / INACTIVE / ARCHIVED) is Coordinator-controlled
through set_d_group_status(). ARCHIVED is rejected while active DISCIPLE
memberships or DRAFT gatherings remain. See DATABASE_CONSTRAINTS.md
section 2.

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

DISCIPLER may not create gatherings. Disciplers record draft attendance
for gatherings created by the Leader or Coordinator. Because scheduling
is ad hoc and gatherings may be recorded after the fact, this blocks
nothing operationally.

UPDATE:

- Appropriate authorized users while DRAFT
- Finalization through controlled operation
- Cancellation through controlled operation

CANCEL:

- COORDINATOR → church-wide
- LEADER → own D Group
- DISCIPLER → no

Only a DRAFT gathering may be cancelled. FINALIZED is terminal.

DELETE:

Avoid normal deletion.

Use lifecycle state where appropriate. CANCELLED exists for exactly this
purpose.

---

## gathering_attendance

Scope: gathering-anchored (section 2a).

SELECT:

- COORDINATOR → church-wide
- LEADER → attendance for gatherings of own D Group
- DISCIPLER → attendance for gatherings of own D Group
- DISCIPLE → own attendance

WRITE:

Draft attendance:

- COORDINATOR
- LEADER for own D Group
- DISCIPLER for own D Group

Finalized attendance correction:

- COORDINATOR
- LEADER for own D Group

In every case the authority applies to OTHER eligible members. Nobody
may write their own attendance row. This is enforced in the database,
not only in the controlled operation.

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

Scope: meeting-context (section 2a).

SELECT:

- COORDINATOR → church-wide
- LEADER → meetings whose d_group_id is own D Group
- DISCIPLER → meetings recorded under own D Group membership
- DISCIPLE → meetings in which they are a participant, whatever the
  outcome, so a Disciple sees their own missed meetups

INSERT (record_discipleship_meeting(), held or missed):

- DISCIPLER for assigned Disciples, the normal recorder
- LEADER for own D Group, as fallback on behalf of the responsible
  Discipler
- COORDINATOR, as fallback on behalf of the responsible Discipler

Meeting creation must pass server-side business validation.

VOID:

- COORDINATOR
- LEADER for own D Group where authorized
- DISCIPLER for meetings they recorded themselves (recorded_by = self)
  under their own active DISCIPLER membership

Voiding must be audited and is subject to COMPLETED protection.

UPDATE:

No other update path. Meeting context and participant outcomes are
immutable; corrections are void and re-record.

notes are shared meeting notes and are visible to every viewer of the
meeting, including participating Disciples. Pastoral care observations
belong in follow_up_actions.

---

## discipleship_meeting_participants

SELECT:

Follow the visibility of the parent discipleship meeting.

WRITE:

Participant creation, including the attendance outcome, occurs only
through record_discipleship_meeting().

Participant voiding occurs only through void_meeting_participant(), with
the same void authority as the parent meeting, including DISCIPLER
self-recorded voids.

---

## disciple_lesson_progress

Scope: current-membership (section 2a).

SELECT:

- COORDINATOR → church-wide
- LEADER → members currently in own D Group, full progress history
- DISCIPLER → currently assigned Disciples, full progress history
- DISCIPLE → self

WRITE:

Do not allow arbitrary client updates.

Progress transitions must be controlled by business operations.

Leader confirmation:

- LEADER → own D Group, the normal authority
- COORDINATOR → oversight/fallback, for example where a D Group has no active Leader

Coordinator confirmation is attributable through confirmed_by and is
audited.

Reopening a COMPLETED lesson:

- COORDINATOR only, through reopen_lesson_completion(), audited

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

Scope: care-responsibility (section 2a).

SELECT:

- COORDINATOR → church-wide
- LEADER → conditions scoped to own D Group
- DISCIPLER → conditions relevant to currently assigned Disciples
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

"Assigned" means follow_ups.assignee_church_membership_id matches the
requesting user's own church membership. The assignee is recorded at
church-membership level because it represents ongoing care
responsibility within the church rather than a completed action.

WRITE:

Authorized:

- COORDINATOR
- relevant LEADER
- assigned DISCIPLER

Important transitions should use controlled operations.

Reassignment uses reassign_follow_up() and is audited through
audit_events.

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

church_settings holds ministry configuration, currently
consecutive_absence_threshold, consecutive_missed_meeting_threshold and
follow_up_due_days.

SELECT:

- COORDINATOR
- ADMIN where operationally necessary

UPDATE:

- COORDINATOR

The Coordinator owns ministry configuration because these values govern
the follow-up workload they are accountable for. System and church
configuration such as church identity and the join code remains ADMIN.

Changes must be audited.

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

Church provisioning is deliberately absent from this list. Bootstrap is
trusted deployment tooling, not a runtime operation, and is specified in
DATABASE_CONSTRAINTS.md section 0.

Recommended operations:

- lookup_church_by_join_code()
- request_join_church()
- approve_church_membership()
- reject_church_membership()
- complete_onboarding()
- assign_church_role()
- regenerate_join_code()
- create_d_group()
- set_d_group_status()
- assign_d_group_leader()
- assign_disciple_to_group()
- assign_discipler()
- reassign_discipler()
- transfer_disciple()
- create_gathering()
- save_draft_attendance()
- finalize_gathering()
- cancel_gathering()
- correct_finalized_attendance()
- record_discipleship_meeting()
- void_discipleship_meeting()
- void_meeting_participant()
- confirm_lesson_completion()
- reopen_lesson_completion()
- promote_disciple_to_discipler()
- add_follow_up_action()
- resolve_follow_up()
- reassign_follow_up()

Operation notes:

lookup_church_by_join_code()
→ SECURITY DEFINER
→ requires an authenticated caller
→ returns only minimal church confirmation information (id and name)
→ rate limited; a miss returns an empty result rather than raising
  (DATABASE_CONSTRAINTS.md section 1, Join Code Format and Rate Limiting)

request_join_church()
→ takes the church identifier returned by the prior lookup, together
  with the join code, which must resolve to that church
→ creates a PENDING membership; returns REQUESTED, ALREADY_PENDING,
  ALREADY_ACTIVE, NOT_REQUESTABLE or INVALID_CODE
→ rate limited
→ writes no role and no D Group responsibility

reject_church_membership()
→ ADMIN or COORDINATOR of the same church, own membership ACTIVE
→ PENDING → ARCHIVED, audited as MEMBERSHIP_REJECTED
→ approved_by / approved_at stay NULL

complete_onboarding()
→ the caller's own ACTIVE membership only
→ sets onboarding_completed_at once; idempotent

cancel_gathering()
→ verifies COORDINATOR or own-D-Group LEADER authority
→ requires status DRAFT
→ sets CANCELLED, cancelled_by, cancelled_at
→ preserves existing draft attendance
→ needs no monitoring recalculation, because a DRAFT gathering never
  contributed to official monitoring

finalize_gathering()
→ resolves eligibility as of starts_at
→ rejects a future starts_at
→ triggers monitoring recalculation

save_draft_attendance() / correct_finalized_attendance()
→ resolves eligibility as of starts_at
→ rejects any attempt to write the caller's own attendance row

record_discipleship_meeting()
→ records a held or missed meetup after the fact; there is no
  scheduling operation
→ requires an explicit attendance_status for every participant
→ rejects an occurred_at in the future
→ enforces sequential lesson eligibility
→ requires every RECORDED participant, whatever the outcome, to be
  eligible for the meeting's lesson
→ validates participant rules P1 to P3 as of occurred_at
→ accepts additional meetings for a lesson that is READY_FOR_COMPLETION
→ occurred_at is immutable after creation; corrections use void and
  re-record
→ triggers CONSECUTIVE_MISSED_MEETINGS recalculation

void_discipleship_meeting() / void_meeting_participant()
→ COORDINATOR, own-D-Group LEADER, or the DISCIPLER who recorded it
  under their own active DISCIPLER membership
→ reject any void that would reduce credited participation below
  required_meetings for a COMPLETED lesson
→ audited
→ trigger CONSECUTIVE_MISSED_MEETINGS recalculation

reopen_lesson_completion()
→ COORDINATOR only for the MVP
→ audited
→ required before correcting a COMPLETED lesson
→ rejected when any later lesson is COMPLETED for the same membership
→ rejected when the person has already been promoted to DISCIPLER
→ never cascades; see DATABASE_CONSTRAINTS.md section 4

promote_disciple_to_discipler()
→ six steps, including ending the promotee's active discipler assignment
  where they are the Disciple

regenerate_join_code()
→ ADMIN only
→ audited

assign_church_role() and any role-ending operation
→ reject any change leaving the church with zero active COORDINATOR

set_d_group_status()
→ COORDINATOR only
→ ARCHIVED rejected while active DISCIPLE memberships or DRAFT
  gatherings remain
→ on archival, ends remaining LEADER/DISCIPLER responsibilities and
  active discipler assignments, sets archived_at, audits

transfer_disciple()
→ closes the old D Group episode and ends the discipler assignment
→ resolves the ACTIVE CONSECUTIVE_MISSED_MEETINGS condition belonging
  to the ended assignment
→ the next assignment's missed-meeting streak never carries the
  previous streak forward

reassign_discipler() and promote_disciple_to_discipler()
→ end the Disciple's discipler assignment
→ resolve the ACTIVE CONSECUTIVE_MISSED_MEETINGS condition belonging to
  the ended assignment

approve_church_membership()
→ ADMIN or COORDINATOR of the same church, own membership ACTIVE
→ PENDING → ACTIVE; sets approved_by, approved_at and joined_at
  (first activation only); audited as MEMBERSHIP_APPROVED
→ never the caller's own row

approve_church_membership() and membership status transitions
→ apply the effects listed in DATABASE_CONSTRAINTS.md section 1,
  including reassigning open follow-ups where the departing person is
  the assignee

Monitoring and follow-up creation
→ uses role-specific sources: gathering attendance for LEADER and
  DISCIPLER subjects (CONSECUTIVE_ABSENCE), meeting outcomes for
  DISCIPLE subjects (CONSECUTIVE_MISSED_MEETINGS)
→ never creates a gathering-based condition for a DISCIPLE
  responsibility
→ applies the escalation chain
→ never assigns a follow-up to its own subject
→ evaluates distinct people when one person holds several
  responsibilities

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