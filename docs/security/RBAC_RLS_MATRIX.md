# DiscipleTrack — RBAC & RLS Matrix

## Purpose

This document defines authorization for the DiscipleTrack MVP.

Two concepts must remain separate:

- *RBAC* — what a role is allowed to do.
- *RLS* — which records that user is allowed to access.

Authorization must be enforced by Supabase/PostgreSQL, not only by Flutter.

Revision 2026-10-02: lesson content read (ADR-010); lesson submission and its withdrawal (ADR-011); Discipler progress read widened to the whole D Group and Disciple participant rows limited to their own (Slice 5 decisions 13 and 12); aggregate reads and Active Discipleships (section 2b, decision A3).

Revision 2026-10-05: D Group gatherings and gathering attendance removed
(ADR-014): section 1 role examples, section 2 gathering rows and notes
(consolidated withdrawal note), section 2a gathering-anchored scope and
aggregate attendance read path, section 3 d_groups archive precondition,
section 4 rewritten as deprecated schema with the open-grant security
issue, section 8 thresholds, section 10 gathering operations and
monitoring sources. Monitoring uses one condition, CONSECUTIVE_ABSENCE
(consecutive recorded absences), from discipleship meeting outcomes
only (ADR-014); "held or missed meetup" wording withdrawn. Discipler
progress read narrowed to own currently assigned Disciples (N7),
reversing the 2026-10-02 widening to the whole D Group (Slice 5
decision 13): section 2 row and note, section 5. Promotion replaced by
Discipler appointment (ADR-012, from Slice 6): section 2 row, section 5
`ministry_role_transitions`, section 10; reopen refusal narrowed.
Relationship-scoped capability principle (section 5). Candidate
"lessons completed this month" aggregate (section 2b, decision 9).

Revision 2026-10-05 (ADR-015): the Discipler marks a lesson completed
with no Leader confirmation. Section 2 rows and notes, section 5
`disciple_lesson_progress` WRITE and section 10 operations: complete_lesson()
and undo_lesson_completion() replace submission, withdrawal and
confirmation; reopen (Coordinator only) returns to IN_PROGRESS. The open
question whether submission and confirmation must be made by different
people no longer arises.

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
- Follow-ups
- Discipler appointments (ADR-012; from Slice 6)
- Church announcements

Gathering "attendance oversight" is withdrawn (ADR-014). Attendance
exists only as a discipleship meeting outcome, overseen through
progress and meeting history.

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

They may not access discipleship meeting records, discipleship
progress, attention conditions, follow-ups or D Group announcements
until the relevant relationship exists. (The former "D Group
attendance" item referred to gathering attendance, withdrawn by
ADR-014.)

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
| Read lesson content | Yes | Yes | Yes | Yes | Yes | Yes |
| Manage church configuration | Yes | No | No | No | No | No |
| Manage ministry settings | No | Yes | No | No | No | No |
| Approve church membership | Yes | Yes | No | No | No | No |
| Manage church roles | Yes | No | No | No | No | No |
| View church members | Yes | Yes | Own D Group | Assigned Disciples, own Leader | Self, own Leader and Discipler | Self |
| View D Group roster by name | No | Church-wide | Own D Group | Own D Group | Own D Group | No |
| Create/manage D Groups | No | Yes | No | No | No | No |
| Assign Leader | No | Yes | No | No | No | No |
| Invite to D Group as Discipler or Disciple | No | Yes | Own D Group | No | No | No |
| Accept or decline a D Group invitation | Own | Own | Own | Own | Own | Own |
| Add self as Discipler | No | If Leader | Own D Group | No | No | No |
| Assign Disciple to Discipler | No | Yes | Own D Group | No | No | No |
| Remove Discipler or Disciple from D Group | No | Yes | Own D Group | No | No | No |
| Transfer Disciple | No | Yes | No | No | No | No |
| Appoint eligible Disciple as Discipler (ADR-012; from Slice 6) | No | Yes | No | No | No | No |
| Record discipleship meeting, with each Disciple's attendance outcome | No | Fallback | Fallback, own D Group | Assigned Disciples | No | No |
| Void discipleship meeting or participant | No | Yes | Own D Group | Self-recorded | No | No |
| View discipleship meeting history | No | Church-wide | Own D Group | Own Discipler meetings | Self (own participant rows) | No |
| View progress | No | Church-wide | Own D Group | Own currently assigned Disciples (N7) | Self | No |
| View active discipleships (section 2b) | No | Church-wide | Own D Group | Own assignments | No | No |
| Mark lesson completed (ADR-015) | No | Fallback | Fallback, own D Group | Assigned Disciples | No | No |
| Undo lesson completion, within the undo window (ADR-015) | No | Yes | Own D Group | Assigned Disciples | No | No |
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

*Withdrawn gathering rows (ADR-014).* The rows Create gathering, Record
draft attendance, Finalize attendance, Cancel gathering and View
attendance, and their notes (Discipler draft attendance, no
self-attendance on a gathering, the Leader-only-recorder resolution),
are withdrawn. D Group gatherings and gathering attendance are not part
of the MVP. Attendance exists only as a discipleship meeting outcome,
recorded under *Record discipleship meeting* and read under *View
discipleship meeting history*. There is no D Group, church-wide or
event attendance capability. The deprecated gathering tables are
covered in section 4.

*Appoint eligible Disciple as Discipler* (ADR-012) replaces *Promote
Disciple*. The COORDINATOR appoints directly; there is no acceptance
workflow. Eligibility (COMPLETED of Lesson 5 of the active curriculum,
marked by the Discipler, ADR-015) is derived, never stored and never automatic, and is not
appointment. Appointment creates a DISCIPLER responsibility in the same
D Group and does not end the person's DISCIPLE responsibility, their own
discipler assignment or their progress. Built in Slice 6; until then
Migration 006 still refuses DISCIPLE with DISCIPLER.

*D Group placement* (Vertical Slice 3, Plan decisions 2 to 8). The
former single "Assign Discipler" and "Assign Disciple to D Group" rows
are replaced by confirmed placement: a COORDINATOR (any group in the
church) or the group's LEADER invites an unplaced ACTIVE member as
DISCIPLER or DISCIPLE, and the member accepts or declines. Nobody is
placed without their own acceptance, and a member cannot request to
join or leave a group. LEADER is never invited; it is a direct
COORDINATOR appointment, made when the group is created and changed
only by replacement. The LEADER of a group also pairs, re-pairs,
unpairs and removes its Disciplers and Disciples directly; a
DISCIPLER can do none of these. A COORDINATOR may hold a D Group
responsibility like anyone else, and gains Leader-only actions such as
*Add self as Discipler* only by being that group's Leader.

*View church members* and *View D Group roster by name*. A Discipler
or Disciple sees everyone in their group by name only, through
get_my_d_group_roster(). Profile rows, and therefore phone numbers,
are readable only for the people in the *View church members* cell:
for a Discipler their assigned Disciples and their own Leader, for a
Disciple their own Leader and their own Discipler. ADMIN without
COORDINATOR sees no D Group data.

*Manage church configuration* covers church identity, join code and
system-level configuration. *Manage ministry settings* covers
church_settings values that govern ministry behaviour, currently
consecutive_absence_threshold (redefined, ADR-014),
consecutive_missed_meeting_threshold (dormant, ADR-014) and
follow_up_due_days (section 8). Ministry setting
changes are audited. ADMIN retains read access to church_settings where
operationally necessary.

*Record discipleship meeting* covers recording a discipleship meeting
after the fact, including each participant's explicitly recorded
attendance outcome (PRESENT, ABSENT, LATE or EXCUSED). This is the only
attendance capability in the MVP (ADR-014). The "held" and "missed"
meetup labels are withdrawn; a meeting record shows each Disciple's
recorded outcome. The Discipler is the
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
Disciple sees the meetings in which they are a participant, whatever
their recorded outcome, and only their own participant row
and outcome. In a small-group meeting they never see another Disciple's
outcome (Slice 5 decision 12). No Disciple may record, confirm or
change their own meeting outcome. For DISCIPLER the cell stays "Own
Discipler meetings"; whether a Discipler may also read the meeting
records of Disciples assigned to another Discipler in their group is
an open decision (section 2a, Meeting-context scope).

*View progress* shows "Own currently assigned Disciples" for DISCIPLER
(N7): a Discipler reads detailed lesson progress only of the Disciples
currently assigned to them. This reverses the 2026-10-02 widening to
every Disciple in the D Group (Slice 5 decision 13). Recording, voiding,
marking completed, undoing a completion and meeting-record detail are likewise limited to their own
assigned Disciples. Each capability is decided for the pair (caller,
person viewed), not from holding a responsibility in general (ADR-012
decision 8): a person who is both a Disciple and a Discipler (ADR-012;
from Slice 6) reads their own progress as "Self" and their assigned
Disciples' progress as their Discipler, and nothing more.

*Mark lesson completed* (ADR-015, replacing *Submit lesson as finished*,
*Withdraw lesson submission* and *Confirm lesson completion*) is the
Discipler's judgement that the lesson material has been covered. It sets
COMPLETED in one step; there is no Leader confirmation. The normal
caller is the Disciple's current assigned Discipler. LEADER (own D
Group) and COORDINATOR may mark it completed on the Discipler's behalf
as a fallback, mirroring fallback recording; confirmed_by and
submitted_by show who marked it. Nobody marks a lesson completed in
which they are the Disciple.

*Undo lesson completion* is allowed to the Disciple's current assigned
Discipler, the Leader of the Disciple's current D Group and the
COORDINATOR, only while the lesson is the person's latest COMPLETED
lesson and no meeting has been recorded for them on the next lesson
(DATABASE_CONSTRAINTS.md section 4, Lesson Completion). After that
window only the COORDINATOR can reopen. Every undo is audited.

*Create D Group announcement* shows "Oversight" for COORDINATOR. The D
Group Leader is the normal authority. Coordinator capability exists as a
ministry-oversight fallback, for example where a D Group currently has
no active Leader.

ADMIN has no access to discipleship meeting outcomes (attendance) or
discipleship progress. Administering the system does not confer
ministry-care access. Where the same person needs both, assign
COORDINATOR separately.

No person may record their own meeting outcome, in any role: a recorder
is never a participant in a meeting they record (explicit check from
Slice 5), and nobody is paired with themselves (ADR-012, enforced from
Slice 6).

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

Applies to: disciple_lesson_progress, for LEADER. For DISCIPLER the
predicate is narrower (N7): the member is currently assigned to the
viewer through an active discipler assignment. Being in the same D Group
is not enough.

A transfer or reassignment therefore does not hide or reset prior lesson
progress from the member's new Leader or new assigned Discipler.
Progress belongs to the person's church journey.

## Gathering-anchored scope

Withdrawn (ADR-014). It existed only for d_group_gatherings and
gathering_attendance, which have no MVP owner (section 4). The aggregate
attendance read path that accompanied it is withdrawn with it; no
attendance percentage or attendance aggregate is defined.

## Meeting-context scope

The meeting's d_group_id is the viewer's D Group, or the meeting's
discipler_d_group_membership_id is the viewer's own.

Used where the record describes work done in a particular ministry
context.

Applies to: discipleship_meetings, discipleship_meeting_participants.

Historical meetings stay associated with the D Group and Discipler under
which they occurred. They are not reinterpreted through the member's
current D Group.

Unresolved contradiction (reported, not resolved): read literally, the
"d_group_id is the viewer's D Group" branch lets every DISCIPLER read
every meeting in their group, while section 2 ("Own Discipler
meetings") and section 5 ("meetings recorded under own D Group
membership") limit a DISCIPLER to their own. Until it is decided,
implementations follow sections 2 and 5 for DISCIPLER; the group branch
applies to LEADER.

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

# 2b. Aggregate Reads

Aggregates are derived at read time (DATABASE_CONSTRAINTS.md section 11)
and served through trusted read functions. A role sees an aggregate only
over records it may already read; an aggregate is never a way around a
row-level rule.

Active Discipleships (DATABASE_CONSTRAINTS.md section 11):

| Viewer | Scope |
|---|---|
| COORDINATOR | church-wide, and per D Group |
| LEADER | own D Group |
| DISCIPLER | their own active assignments |
| DISCIPLE | none as an aggregate; their own journey shows whether they are paired |
| Member without a D Group | none |
| ADMIN without COORDINATOR | none (ADR-004) |

Being ADMIN never grants church-wide ministry progress or discipleship
aggregates.

Church-wide discipleship aggregates shown to every role (for example a
church total on every member's Home) are not granted. They require a
separate privacy review first, because a single church has small groups
in which a count can identify a person ("1 Disciple on Lesson 2").

Progress aggregates are factual counts and states only. No aggregate
ranks or compares people, Disciplers or D Groups, and no aggregate is a
percentage, ratio or consistency score (decision 8).

Candidate aggregate, not granted (decision 9): "lessons completed this
month". It is a candidate Reporting / Oversight metric owned by Slice 11,
not a defined or governing metric. Before any role is granted it, it
needs a precise definition (likely lessons reaching COMPLETED
with completed_at in the month), the church time zone semantics for
"month", a privacy review under this section, and small-population
suppression before any broad member visibility. It does not block
Slice 5.

---

# 3. Table-Level Access

## profiles

SELECT:

- User → own profile
- Coordinator → profiles required for church ministry operations
- Leader → members of own active D Group
- Discipler → assigned Disciples
- Admin → profiles required for system/member administration

Implemented: own profile; for ADMIN and COORDINATOR the profiles of
anyone holding a membership row (any status) in a church they
administer, which is what the membership-request list needs; and,
since Migration 006, the ministry scope
(private.can_view_profile_in_ministry): a LEADER sees the people with
an active responsibility in their group and the people invited to it;
a DISCIPLER sees their assigned Disciples and their own Leader; a
DISCIPLE sees their own Leader and their own Discipler. Other group
mates are visible by name only, through get_my_d_group_roster().

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
- LEADER → members of own D Group, and people invited to it
- DISCIPLER → assigned Disciples, own Leader
- DISCIPLE → self, own Leader and own Discipler

The LEADER, DISCIPLER and DISCIPLE scopes are implemented by
church_memberships_select_ministry (Migration 006), with the same
predicate as the profiles ministry scope.

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

Migration 006 revokes INSERT, UPDATE, DELETE and TRUNCATE from
authenticated, so no client write path exists until role management
is built.

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
memberships remain. See DATABASE_CONSTRAINTS.md section 2. (The former
"or DRAFT gatherings" clause is withdrawn, ADR-014.)

Implemented (Migration 006): COORDINATOR church-wide; LEADER,
DISCIPLER and DISCIPLE own group (any active responsibility in it).
ADMIN without COORDINATOR has no scope. Writes: create_d_group() and
assign_d_group_leader(); set_d_group_status() is not built yet.
Clients hold SELECT only; anon holds nothing.

---

## d_group_memberships

SELECT:

- COORDINATOR → church-wide
- LEADER → own D Group
- DISCIPLER → own D Group where required
- DISCIPLE → own membership and permitted group information

Implemented (Migration 006): COORDINATOR church-wide and LEADER own
group, history included; DISCIPLER the active rows of their group;
DISCIPLE their own rows, their Leader's active row and their own
Discipler's active row. Everyone sees their own rows.

WRITE:

Use controlled operations for:

- assignment
- transfer
- responsibility change
- Discipler appointment (ADR-012; from Slice 6)

Do not allow arbitrary direct client mutation.

Implemented: create_d_group(), assign_d_group_leader(),
respond_to_d_group_invitation(), add_self_as_discipler() and
end_d_group_membership(). Clients hold SELECT only.

---

## discipler_assignments

SELECT:

- COORDINATOR → church-wide
- LEADER → own D Group
- DISCIPLER → own assignments
- DISCIPLE → own active Discipler relationship

WRITE:

Use controlled operations for assignment and reassignment.

Implemented (Migration 006): the SELECT scopes above as written;
writes through set_discipler() and end_d_group_membership() only.

---

## d_group_invitations

Added by Migration 006.

SELECT:

- COORDINATOR → church-wide, every status
- LEADER → own D Group's, every status (a decline is shown to the
  inviter, who may invite again)
- Invitee → own
- DISCIPLER, DISCIPLE, ADMIN without COORDINATOR → none

The invitee reads their live invitation, with the group name and
inviter name, through get_my_pending_invitation(); they have no
d_groups scope before accepting.

WRITE:

- invite_to_d_group() → COORDINATOR, or the group's LEADER
- withdraw_d_group_invitation() → COORDINATOR, or the inviter while
  they are the group's LEADER
- respond_to_d_group_invitation() → the invitee only, own membership
  ACTIVE

Clients hold SELECT only; anon holds nothing.

---

# 4. Gathering & Attendance Access

Deprecated (ADR-014). D Group gatherings and gathering attendance are
not part of the MVP. Attendance exists only as a discipleship meeting
outcome (section 5, discipleship_meeting_participants). This section
keeps its number and now records the security status of the unused
schema.

## d_group_gatherings, gathering_attendance

Status: deprecated, no MVP owner (ADR-014); retained in applied
migrations (Migration 001 creates the tables and the gathering_status
enum; Migration 002 adds their set_updated_at triggers). No RPC,
policy, seed row or Flutter code reads or writes them.

Current database state:

- RLS is enabled on both tables with zero policies, so every client
  read and write is denied by default.
- Supabase's default grants are still in place: ALL to anon and
  authenticated. No migration narrowed them; Migration 006 narrowed
  only its own ministry tables.

This is a documented security issue. RLS deny-by-default is the only
protection, and one permissive policy added by mistake would open both
tables to anon and authenticated clients. Unused tables must not stay
broadly accessible.

Required treatment (ADR-014 decision 14):

1. Lock down by forward migration: revoke all privileges on both tables
   from anon and authenticated, keep RLS enabled. Expected in the
   Slice 5 migration's grant step. Security only; removes no object or
   data and is reversible.
2. Deprecate: recorded here, in DATABASE_CONSTRAINTS.md and in the DBML;
   a forward migration may also update the table comments.
3. Drop: only after a separate explicit decision, in a forward migration
   that first verifies both tables are empty.

No SELECT, INSERT, UPDATE or DELETE policy will be added for any role.
The former role scopes, draft and finalized attendance write rules and
cancellation rules of this section are withdrawn (ADR-014).

---

# 5. Curriculum & Progress Access

## curricula

SELECT:

- Active church members

WRITE:

Curriculum mutation is not part of the normal MVP user workflow.

The MVP uses one fixed church curriculum.

Lesson content (ADR-010): the published lesson content table, added by
the Curriculum / Lesson Content slice, has the same SELECT scope as
curriculum_lessons (ACTIVE church members, never PENDING) and no client
write path. Publishing is trusted tooling in the service-role context.
A device copy of the content is display data only and authorizes
nothing.

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
- DISCIPLE → meetings in which they are a participant, whatever their
  recorded outcome, including meetings where they were recorded ABSENT

INSERT (record_discipleship_meeting(), with each participant's explicit
attendance outcome; the only attendance write path in the MVP, ADR-014):

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

Follow the visibility of the parent discipleship meeting, except that a
DISCIPLE sees only their own participant rows (Slice 5 decision 12).

WRITE:

Participant creation, including the attendance outcome, occurs only
through record_discipleship_meeting().

Participant voiding occurs only through void_meeting_participant(), with
the same void authority as the parent meeting, including DISCIPLER
self-recorded voids.

---

## disciple_lesson_progress

Scope: current-membership for LEADER; current assignment for DISCIPLER
(section 2a).

SELECT:

- COORDINATOR → church-wide
- LEADER → members currently in own D Group, full progress history
- DISCIPLER → own currently assigned Disciples only, full progress
  history (N7; reverses Slice 5 decision 13)
- DISCIPLE → self

Capabilities are relationship-scoped: each read or action is decided
for the pair (caller, person viewed), never from holding a
responsibility in general (ADR-012 decision 8, N7). A person who is
both a Disciple and a Discipler (ADR-012; from Slice 6) reads their own
progress as DISCIPLE and their assigned Disciples' progress as
DISCIPLER, and no other Disciple's progress in the group.

WRITE:

Do not allow arbitrary client updates.

Progress transitions must be controlled by business operations.

Marking a lesson completed (ADR-015), through complete_lesson():

- DISCIPLER → the Disciple's current assigned Discipler, the normal
  caller
- LEADER → own D Group, fallback on behalf of the Discipler
- COORDINATOR → fallback on behalf of the Discipler

There is no Leader confirmation. Submission as finished, its withdrawal
and Leader confirmation (ADR-011) are withdrawn.

Undoing a completion, through undo_lesson_completion(), only within the
undo window (latest COMPLETED lesson; no meeting recorded on the next
lesson; DATABASE_CONSTRAINTS.md section 4):

- DISCIPLER → the Disciple's current assigned Discipler
- LEADER → own D Group
- COORDINATOR

Completion and undo are attributable (confirmed_by and submitted_by;
audit_events with the prior values) and audited.

No caller ever marks completed, undoes or reopens a lesson in which they
are the Disciple.

Reopening a COMPLETED lesson after the undo window:

- COORDINATOR only, through reopen_lesson_completion(), audited

---

## ministry_role_transitions

The table name is kept; a row is now the Discipler appointment record
(ADR-012). Appointment does not end the person's DISCIPLE row.

SELECT:

- COORDINATOR
- relevant LEADER
- affected user for appropriate personal history

Not built: the table has RLS enabled and no policy; Slice 6 adds the
read policies.

INSERT:

Only through the controlled Discipler appointment operation (ADR-012;
from Slice 6). No client write path.

---

# 6. Monitoring & Follow-up Access

## attention_conditions

Scope: care-responsibility (section 2a).

The only MVP condition is CONSECUTIVE_ABSENCE, shown to users as
"consecutive recorded absences": consecutive explicitly recorded ABSENT
discipleship meeting outcomes for a DISCIPLE subject (ADR-014). The same
value is the only follow_up_reason (follow_ups below). No condition is
raised from elapsed time, inactivity or a missing record.

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

The only MVP trigger is a CONSECUTIVE_ABSENCE condition on a DISCIPLE
subject (reason_type CONSECUTIVE_ABSENCE; ADR-014). The LEADER and
DISCIPLER subject branches of the escalation chain have no MVP trigger
and are not built until a factual condition for those subjects is
approved.

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

consecutive_absence_threshold is redefined (ADR-014 decision 12): the
number of consecutive explicitly recorded ABSENT discipleship meeting
outcomes, within the current discipler assignment, that raises
CONSECUTIVE_ABSENCE for a Disciple. Default 3. It no longer refers to
gathering attendance.

consecutive_missed_meeting_threshold is dormant (ADR-014 decision 13):
no rule reads it, because the missed-meeting condition it was added for
is withdrawn. It is retained, not dropped, and changing it has no
effect.

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
- invite_to_d_group()
- withdraw_d_group_invitation()
- respond_to_d_group_invitation()
- add_self_as_discipler()
- end_d_group_membership()
- set_discipler()
- transfer_disciple()
- record_discipleship_meeting()
- void_discipleship_meeting()
- void_meeting_participant()
- complete_lesson(p_membership_id, p_lesson_id) (ADR-015; replaces submit_lesson_finished())
- undo_lesson_completion(p_membership_id, p_lesson_id) (ADR-015)
- reopen_lesson_completion()
- Discipler appointment operation (ADR-012; from Slice 6; replaces
  promote_disciple_to_discipler(); name fixed by Slice 6)
- add_follow_up_action()
- resolve_follow_up()
- reassign_follow_up()

The gathering operations create_gathering(), save_draft_attendance(),
finalize_gathering(), cancel_gathering() and
correct_finalized_attendance() are withdrawn with their notes (ADR-014).
None was built, and none will be.

withdraw_lesson_submission() and confirm_lesson_completion() are no
longer planned, and submit_lesson_finished() is replaced by
complete_lesson() (ADR-015).

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

record_discipleship_meeting()
→ records a discipleship meeting after the fact; there is no
  scheduling operation
→ requires an explicit attendance_status for every participant; this
  is the only attendance write path (ADR-014)
→ the recorder is never a participant in the meeting they record
  (explicit check from Slice 5)
→ rejects an occurred_at in the future
→ enforces sequential lesson eligibility
→ requires every RECORDED participant, whatever the outcome, to be
  eligible for the meeting's lesson
→ validates participant rules P1 to P3 as of occurred_at
→ never changes completion (ADR-011, ADR-015)
→ occurred_at is immutable after creation; corrections use void and
  re-record
→ triggers CONSECUTIVE_ABSENCE recalculation (from the monitoring
  slice on; ADR-014)

void_discipleship_meeting() / void_meeting_participant()
→ COORDINATOR, own-D-Group LEADER, or the DISCIPLER who recorded it
  under their own active DISCIPLER membership
→ reject any void that would leave a COMPLETED lesson below the meeting
  policy's submission_minimum credited participations
→ dormant (ADR-015): withdraw, in the same transaction, a
  READY_FOR_COMPLETION submission that the void leaves below
  submission_minimum; no operation enters that state any more
→ audited
→ trigger CONSECUTIVE_ABSENCE recalculation (from the monitoring
  slice on; ADR-014)

complete_lesson(p_membership_id, p_lesson_id) (ADR-015)
→ the Disciple's current assigned DISCIPLER; own-D-Group LEADER or
  COORDINATOR as fallback
→ never the Disciple themselves
→ requires the Disciple's eligible lesson, status IN_PROGRESS and
  credited participations >= submission_minimum at that moment
→ sets COMPLETED, completed_at = now(), confirmed_by = caller,
  ready_at = completed_at, submitted_by = caller; audited as
  LESSON_COMPLETED
→ refusals: cannot_act_on_own_lesson, not_authorized, lesson_not_eligible,
  lesson_not_in_progress, below_submission_minimum
→ the next lesson becomes current by derivation

undo_lesson_completion(p_membership_id, p_lesson_id) (ADR-015)
→ the Disciple's current assigned DISCIPLER, own-D-Group LEADER or
  COORDINATOR
→ never the Disciple themselves
→ requires COMPLETED, no later lesson COMPLETED, and no RECORDED
  participant row for the person in a RECORDED meeting for the next
  lesson
→ from Slice 6, the eligibility-lesson refusal for an appointed person
  (as for reopen) also applies
→ returns to IN_PROGRESS (NOT_STARTED when no credited participation
  remains); clears ready_at, submitted_by, completed_at and
  confirmed_by; audited as LESSON_COMPLETION_UNDONE with the prior values
→ refusals: cannot_act_on_own_lesson, not_authorized, lesson_not_completed,
  later_lesson_completed, next_lesson_started

reopen_lesson_completion()
→ COORDINATOR only for the MVP
→ audited
→ required before correcting a COMPLETED lesson
→ rejected when any later lesson is COMPLETED for the same membership
→ for a person appointed as Discipler, rejected for the eligibility
  lesson (Lesson 5) and earlier lessons; later lessons may be reopened,
  subject to the other preconditions (ADR-012 decision 9, N9; the
  eligibility lesson comes from `private.discipler_eligibility_lesson()`, D2). This replaces "rejected when
  the person has already been promoted to DISCIPLER".
→ returns to IN_PROGRESS, or NOT_STARTED when no credited participation
  remains; never to READY_FOR_COMPLETION (ADR-015)
→ never cascades; see DATABASE_CONSTRAINTS.md section 4

Discipler appointment (ADR-012; from Slice 6; replaces
promote_disciple_to_discipler())
→ COORDINATOR only; no acceptance workflow
→ requires derived eligibility: Lesson 5 of the active curriculum at
  COMPLETED (ADR-015; never stored)
→ creates a DISCIPLER responsibility in the same D Group as the
  person's DISCIPLE responsibility, and the appointment record in
  ministry_role_transitions
→ does not end the person's DISCIPLE responsibility, their own discipler
  assignment or their lesson progress
→ is not a monitoring recalculation trigger or episode boundary
→ attributed and audited
→ until the Slice 6 forward migration, Migration 006 still refuses
  DISCIPLE with DISCIPLER

regenerate_join_code()
→ ADMIN only
→ audited

assign_church_role() and any role-ending operation
→ reject any change leaving the church with zero active COORDINATOR

create_d_group()
→ COORDINATOR only
→ creates the group and its LEADER row together; the Leader must be an
  unplaced ACTIVE member of the church
→ audited as D_GROUP_CREATED

assign_d_group_leader()
→ COORDINATOR only
→ ends the current LEADER row and creates the new one in one
  transaction; the new Leader is unplaced or already a DISCIPLER in the
  same group
→ audited as D_GROUP_LEADER_ASSIGNED

invite_to_d_group() / withdraw_d_group_invitation() /
respond_to_d_group_invitation()
→ placement by confirmed invitation; see section 3, d_group_invitations
→ the invitee must be unplaced with no pending invitation, and is
  re-checked on accept
→ an expired invitation is refused on response; withdrawing one that
  has lapsed reports EXPIRED
→ audited as D_GROUP_INVITATION_SENT / _WITHDRAWN / _ACCEPTED /
  _DECLINED

add_self_as_discipler()
→ the group's LEADER only, for themselves
→ audited as D_GROUP_MEMBER_ADDED

end_d_group_membership()
→ COORDINATOR or the group's LEADER
→ ends a DISCIPLER or DISCIPLE row and every active assignment on
  either side of it; LEADER rows are refused (replace instead)
→ audited as D_GROUP_MEMBER_ENDED

set_discipler()
→ COORDINATOR or the group's LEADER
→ one operation pairs, re-pairs (ends the old assignment, creates the
  new one) or, with a null Discipler, unpairs; replaces the
  assign_discipler() / reassign_discipler() names listed before
  Vertical Slice 3
→ audited as DISCIPLER_ASSIGNED / _REASSIGNED / _UNASSIGNED
→ CONSECUTIVE_ABSENCE resolution on an ended assignment arrives with
  the monitoring slice; the function marks the place (ADR-014)

list_placeable_members() / get_my_pending_invitation() /
get_my_d_group_roster()
→ read-only SECURITY DEFINER reads
→ list_placeable_members(): COORDINATOR (every ACTIVE member with
  placement) or the group's LEADER (unplaced members only); names and
  placement, never phone numbers
→ get_my_d_group_roster(): the caller's group by name, with phone
  numbers only for their own Leader, own Discipler and, for a
  Discipler, assigned Disciples

set_d_group_status()
→ COORDINATOR only
→ ARCHIVED rejected while active DISCIPLE memberships remain (the DRAFT
  gathering clause is withdrawn, ADR-014)
→ on archival, ends remaining LEADER/DISCIPLER responsibilities and
  active discipler assignments, sets archived_at, audits

transfer_disciple()
→ closes the old D Group episode and ends the discipler assignment
→ resolves the ACTIVE CONSECUTIVE_ABSENCE condition belonging to the
  ended assignment
→ the next assignment's consecutive recorded absence streak never
  carries the previous streak forward

set_discipler() (re-pair or unpair) and end_d_group_membership()
→ end the Disciple's discipler assignment
→ resolve the ACTIVE CONSECUTIVE_ABSENCE condition belonging to the
  ended assignment
→ Discipler appointment is not in this list: it ends no assignment
  (ADR-012)

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
→ uses one source: explicitly recorded discipleship meeting outcomes
  (ADR-014)
→ one condition, CONSECUTIVE_ABSENCE ("consecutive recorded absences"):
  N consecutive ABSENT outcomes on RECORDED participant rows of
  RECORDED discipleship meetings, for a DISCIPLE subject, within the
  current discipler assignment episode, in order of (occurred_at,
  meeting id), across lesson boundaries; ABSENT increments, PRESENT and
  LATE break, EXCUSED breaks and is never an absence (BR-027a);
  N = church_settings.consecutive_absence_threshold
→ never raises a condition from elapsed time, inactivity or a missing
  record; no record is not ABSENT
→ applies the Disciple escalation chain (Discipler, then Leader, then
  Coordinator); the LEADER and DISCIPLER subject branches have no MVP
  trigger
→ never assigns a follow-up to its own subject
→ a person who is both a Disciple and a Discipler (ADR-012) is
  monitored as a Disciple only

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