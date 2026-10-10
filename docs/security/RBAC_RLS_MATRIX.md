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

Revision 2026-10-06 (ADR-016): after the undo window a completion is
locked by later progress. reopen_lesson_completion() stays COORDINATOR
only, as a database-level recovery operation with no MVP action; its
locks and audit are unchanged. Section 2 row and note, section 5
`disciple_lesson_progress`, section 10.

Revision 2026-10-06 (ADR-018, Slice 6, Migrations 012 to 015): placement
by invitation retired and replaced by direct placement
(d_group_placements) with the derived "Needs setup" state; setup of a
responsibility, the initial setup window and Existing Discipler
recognition; Discipler appointment and candidates built; an appointment
also locks undo of the eligibility lesson and earlier. Section 1
Needs-setup member, section 2 rows and notes, section 3
`profiles`, `church_memberships`, `d_groups`, `d_group_placements`,
`d_group_memberships`, `discipler_assignments`, `d_group_invitations`
(historical), section 5 `ministry_role_transitions`, section 10.

Revision 2026-10-06 (ADR-020, Migration 018): every D Group Leader
holds DISCIPLER in their group, granted with the leadership. Section 10
`add_self_as_discipler()`.

Revision 2026-10-06 (ADR-019, Slice 7, Migration 017): lesson content
implemented. Section 5 `curricula` note names the content tables (no
client policy or grant) and the controlled reads; section 10 adds
publish_curriculum() and the three content reads.

Revision 2026-10-08 (ADR-022, ADR-023, Slice 8, documented before
implementation, then built as Migrations 022 to 026; the "as built" notes
below name the Slice 8 migrations where they changed a rule): a platform-level Super Admin
in `platform_roles`, independent of church membership; the church-level
ADMIN role retired; approval, rejection and the reading of the church's
memberships and their profiles COORDINATOR-only; church provisioning,
join code regeneration, Coordinator assignment and replacement, and
church status by the Super Admin through controlled operations; church
status SUSPENDED; the effective-membership predicate requires an ACTIVE
church; one church per person. Curriculum access narrowed from the
Discipler role to the relationship (ADR-023, superseding ADR-019
decision 16); a Discipler's own context reopened to the whole book by
ADR-024 (Phase 4, Migration 027). Sections 1, 1a, 2 (Admin column replaced by Super Admin;
lesson rows corrected), 2b, 3 (profiles, churches, church_memberships,
church_role_assignments, the new platform_roles, and the ADMIN mentions
in d_groups, d_group_placements and d_group_invitations), 5, 8, 9, 10,
11 and the Core Authorization Rule. Amended the same day after the
Phase 1 review: the Coordinator views and copies their own church's
join code (section 2 row, section 3 churches, section 10
get_church_join_code()); the Coordinator's full curriculum access, My
Journey distinct, reading never affects progression (sections 2 and 5);
the Coordinator invariant's church row lock (section 10).

---

# 1. Role Model

Three levels, each stored separately, none implying another (ADR-022):

| Level | Stored in | Roles |
|---|---|---|
| Platform | platform_roles | SUPER_ADMIN |
| Church | church_role_assignments, on an ACTIVE membership in an ACTIVE church | COORDINATOR |
| D Group | d_group_memberships | LEADER, DISCIPLER, DISCIPLE |

## Platform-Level Role

### SUPER_ADMIN

Responsible for the platform: creating churches together with their
first Coordinator, regenerating join codes, assigning, replacing and
ending Coordinators, and setting church status.

- Stored in platform_roles, keyed to profiles.id, independent of any
  church membership. Read only from that table, never from a JWT claim,
  profile field, user metadata or operation parameter.
- Granted and ended only by service-role tooling
  (private.grant_platform_role(), tool/grant_super_admin.ps1) and the
  local seed. There is no client write path.
- Sees per church only its name, status, join code, creation date,
  aggregate counts (members by status, D Groups, Coordinators) and the
  full name and sign-in email of its active Coordinators. Nothing else
  about any member, and no ministry data (ADR-022 decision 5).
- Never assigns themselves as Coordinator (ADR-022 decision 6). A Super
  Admin who also holds COORDINATOR in a church holds it through a
  separate, audited assignment, and has that church's Coordinator access
  through that row only.

## Church-Level Roles

### ADMIN (retired)

Retired by ADR-022 on 2026-10-08. The enum value remains; no operation
grants it, the database refuses an active ADMIN row, and every former
row is ended and audited. It grants nothing. Its only built power,
approval, is the Coordinator's; its unbuilt ones (church configuration,
church roles) are the Super Admin's platform operations.

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
- Discipler appointments (ADR-012)
- The church's initial setup period (ADR-018)
- Membership approval and rejection, and the church's member list
  (COORDINATOR only since ADR-022)
- The church's join code, to view and share, read-only (ADR-022
  decision 10a); generating or regenerating it is the Super Admin's
- Church announcements

A church never has an ACTIVE status without at least one active
COORDINATOR (ADR-022 decision 11; DATABASE_CONSTRAINTS.md section 1).

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
- read the curriculum's lesson list and covers; no lesson content
  without a journey or a relationship (ADR-019 decision 6, ADR-023)

They may not access discipleship meeting records, discipleship
progress, attention conditions, follow-ups or D Group announcements
until the relevant relationship exists. (The former "D Group
attendance" item referred to gathering attendance, withdrawn by
ADR-014.)

A member placed in a D Group who holds no responsibility there yet is
in the derived "Needs setup" state (ADR-018, DATABASE_CONSTRAINTS.md
section 11). In addition to the above, they may read their group's
row (its name) and, through get_my_d_group_roster(), their Leader's
name only: no roster and no phone number.

---

# 1a. Membership Status Gating

Authorization depends on membership status as well as role and
responsibility. This predicate is defined once here and applies
everywhere.

Wherever a policy in this document refers to a church member, it means:

church_memberships.status = 'ACTIVE' and churches.status = 'ACTIVE'

The church condition is added by ADR-022 (2026-10-08). Every role
helper and policy relies on this one predicate, so a role, a D Group
responsibility or an assignment grants nothing while the church is
SUSPENDED or ARCHIVED.

Membership status effects:

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

Church status effects (ADR-022 decision 14, which has the full table):

ACTIVE
→ normal access according to the membership status above

SUSPENDED (reversible) and ARCHIVED (final)
→ a PENDING or ACTIVE member may read their own profile and account,
  their own membership row and the church's id, name and status, and
  nothing else of the church: no members, roster, D Groups, meetings,
  progress, lesson list, lesson content, covers, avatars or settings
→ no write to church data by anyone, the COORDINATOR included; every
  controlled operation refuses with its usual PT403 not_authorized (or not found); the app reads the church status to explain it (Migration 025)
→ lookup_church_by_join_code() finds nothing and request_join_church()
  answers INVALID_CODE, so the status is not revealed
→ PENDING requests stay PENDING and cannot be approved or rejected
→ the Super Admin keeps only the platform operations ADR-022 allows
  for that status (section 10)

Profiles and accounts are platform-level: sign-in, the session and
editing one's own profile are unaffected by church status.

---

# 2. General Access Matrix

"Member" below means an ACTIVE church member who currently holds no
D Group responsibility. This is a valid state, not a stored role.

"Super Admin" means a person holding the platform SUPER_ADMIN role and
no church role. A Super Admin who is also a church member has, in
addition, the column of whatever they hold in that church. Every church
column assumes an ACTIVE church (section 1a).

| Capability | Super Admin | Coordinator | Leader | Discipler | Disciple | Member |
|---|---|---|---|---|---|---|
| View own profile | Yes | Yes | Yes | Yes | Yes | Yes |
| Edit own profile | Yes | Yes | Yes | Yes | Yes | Yes |
| View own church membership | No membership | Yes | Yes | Yes | Yes | Yes |
| View own church | No membership | Yes | Yes | Yes | Yes | Yes |
| Read curriculum (lesson list and covers) | No | Yes | Yes | Yes | Yes | Yes |
| Read lesson content, Disciple tier (ADR-019, ADR-023, ADR-024) | No | Any lesson, any context | Own context: all ten. Own assigned Disciples: all ten. Other active Disciples of own D Group: their reached lessons | Own context: all ten. Currently assigned Disciples: all ten | Own reached lessons | No |
| Read lesson content, Discipler tier: answers, notes, modules (ADR-019, ADR-023, ADR-024) | No | Any lesson, any context | Own context: all ten. Own assigned Disciples: all ten. Never for others' Disciples | Own context: all ten. Currently assigned Disciples: all ten | No | No |
| Create church, with its Coordinator (ADR-022) | Yes | No | No | No | No | No |
| Regenerate join code (ADR-022) | Yes, ACTIVE or SUSPENDED church | No | No | No | No | No |
| View and copy own church's join code, read-only (ADR-022 decision 10a) | Yes, every church (list_churches()) | Own church, while ACTIVE | No | No | No | No |
| Set church status (ADR-022) | Yes; ARCHIVED is final | No | No | No | No | No |
| Assign, replace or end a Coordinator (ADR-022) | Yes, never themselves; never leaving an ACTIVE church without one | No | No | No | No | No |
| View platform overview: churches, counts, Coordinators' name and email | Yes | No | No | No | No | No |
| View platform audit events | Yes | No | No | No | No | No |
| Manage ministry settings | No | Yes | No | No | No | No |
| Approve or reject church membership | No | Yes | No | No | No | No |
| View church members | Counts only; Coordinators' name and email | Yes | Own D Group | Assigned Disciples, own Leader | Self, own Leader and Discipler | Self |
| View D Group roster by name | No | Church-wide | Own D Group | Own D Group | Own D Group | No |
| Create/manage D Groups | No | Yes | No | No | No | No |
| Assign Leader | No | Yes | No | No | No | No |
| Add members to D Group | No | Yes | Own D Group | No | No | No |
| Set up member responsibility (Disciple) | No | Yes | Own D Group | No | No | No |
| Recognize Existing Discipler (setup window) | No | Yes | Own D Group | No | No | No |
| Open or close the initial setup period | No | Yes | No | No | No | No |
| Add self as Discipler | No | If Leader | Own D Group | No | No | No |
| Assign Disciple to Discipler | No | Yes | Own D Group | No | No | No |
| Remove member from D Group (not the Leader) | No | Yes | Own D Group | No | No | No |
| Transfer Disciple | No | Yes | No | No | No | No |
| View Discipler candidates | No | Church-wide | Own D Group | No | No | No |
| Appoint eligible Disciple as Discipler (ADR-012) | No | Yes | No | No | No | No |
| Record discipleship meeting, with each Disciple's attendance outcome | No | Fallback | Fallback, own D Group | Assigned Disciples | No | No |
| Void discipleship meeting or participant | No | Yes | Own D Group | Self-recorded | No | No |
| View discipleship meeting history | No | Church-wide | Own D Group | Own Discipler meetings | Self (own participant rows) | No |
| View progress | No | Church-wide | Own D Group | Own currently assigned Disciples (N7) | Self | No |
| View active discipleships (section 2b) | No | Church-wide | Own D Group | Own assignments | No | No |
| Mark lesson completed (ADR-015) | No | Fallback | Fallback, own D Group | Assigned Disciples | No | No |
| Undo lesson completion, within the undo window (ADR-015) | No | Yes | Own D Group | Assigned Disciples | No | No |
| Reopen lesson completion (database-level recovery only, no MVP action; ADR-016) | No | Yes | No | No | No | No |
| View attention conditions | No | Church-wide | Own D Group | Assigned Disciples | Self summary | No |
| View internal follow-up notes | No | Church-wide | Own D Group | Assigned Follow-ups | No | No |
| Add follow-up action | No | Yes | Own D Group | Assigned Follow-ups | No | No |
| Resolve follow-up | No | Yes | Own D Group | Assigned Follow-ups | No | No |
| Create church announcement | No | Yes | No | No | No | No |
| View church announcement | No | Yes | Yes | Yes | Yes | Yes |
| Create D Group announcement | No | Oversight | Own D Group | No | No | No |
| View D Group announcement | No | Church-wide | Own D Group | Own D Group | Own D Group | No |

Notes on specific cells:

*Super Admin* (ADR-022). The rows "Manage church configuration" and
"Manage church roles", held by the retired church ADMIN and never
built, are replaced by the five platform rows above. Every platform
capability is a SECURITY DEFINER operation (section 10) that returns
only the listed fields; no table policy is broadened for the Super
Admin, and the Super Admin column is "No" for every ministry row. Any
future exception (support, recovery) needs its own justified, audited
operation.

*Approve or reject church membership* is COORDINATOR-only since
ADR-022; ADMIN shared it before. It is refused while the church is not
ACTIVE.

*Read lesson content* (ADR-023, superseding ADR-019 decision 16; own
context amended by ADR-024). A reader holding an active DISCIPLER row,
every Leader included (ADR-020), opens all ten lessons in both tiers in
their own context, from appointment until the responsibility ends.
Anyone else's own context opens only their own journey: the Disciple
tier of the lessons they have reached (COMPLETED, plus the current lesson
while they hold an active DISCIPLE row). A Discipler who is also a
Disciple keeps My Journey as their own journey, like the Coordinator
below; their progression is recorded only by their Discipler. In the
context of a currently assigned Disciple, the
Discipler, a Leader among them, opens all ten lessons in both tiers. A
Leader opens the Disciple tier of the reached lessons of the other
active Disciples of the group they currently lead, never their Discipler
tier. The COORDINATOR opens everything, in any context, their own
included (ADR-023 decision 9). Access in another person's context ends
with the assignment or the leadership.

The Coordinator's access is oversight. A Coordinator who is also a
Disciple keeps My Journey as their own journey: lesson states from their
progression, lessons opened in the Disciple view. The full book is in
Curriculum (ADR-023 decision 10). For every role, reading never affects
progression: it never makes a lesson current, reached or completed, and
never counts as a meeting (ADR-023 decision 11).

*View and copy own church's join code* (ADR-022 decision 10a, Phase 1
review). The church's active COORDINATOR reads the current code through
get_church_join_code(), read-only, only while the church is ACTIVE.
Nobody else in the church reads it, and only the Super Admin generates
or regenerates it.

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
discipler assignment or their progress. Built by Migration 014
(appoint_discipler()). Appointment is refused before eligibility (D5),
once the person's DISCIPLE row has ended (D8) and for the COORDINATOR
themselves (D9) (ADR-018). *View Discipler candidates* lists eligible
Disciples who are not Disciplers: for one group to its LEADER or the
COORDINATOR, church-wide to the COORDINATOR. The LEADER sees
eligibility but does not appoint.

*D Group placement* (ADR-018, superseding the Vertical Slice 3
invitation and acceptance rule). A COORDINATOR (any group in the
church) or the group's LEADER adds ACTIVE members who are in no D Group
directly; there is no acceptance step, and a member cannot request to
join or leave a group. A person added this way needs setup until the
COORDINATOR or the group's LEADER sets them up as a Disciple, or, while
the church's initial setup period is open, recognizes them as an
Existing Discipler. Only the COORDINATOR closes or reopens that period.
LEADER is never added this way; it is a direct COORDINATOR appointment,
made when the group is created and changed only by replacement. The
LEADER of a group also pairs, re-pairs, unpairs and removes its members
directly, and keeps pairing authority for appointed Disciplers (D6); a
DISCIPLER can do none of these. A COORDINATOR may hold a D Group
responsibility like anyone else, and gains Leader-only actions such as
*Add self as Discipler* only by being that group's Leader.

*View church members* and *View D Group roster by name*. A Discipler
or Disciple sees everyone in their group by name only, through
get_my_d_group_roster(). Profile rows, and therefore phone numbers,
are readable only for the people in the *View church members* cell:
for a Discipler their assigned Disciples and their own Leader, for a
Disciple their own Leader and their own Discipler. A Super Admin
without COORDINATOR sees no D Group data.

Church identity, the join code and church status are platform
operations of the Super Admin (ADR-022), replacing the former *Manage
church configuration* row. *Manage ministry settings* covers
church_settings values that govern ministry behaviour, currently
consecutive_absence_threshold (redefined, ADR-014),
consecutive_missed_meeting_threshold (dormant, ADR-014) and
follow_up_due_days (section 8). Ministry setting
changes are audited. The Super Admin has no access to church_settings.

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
decision 8): a person who is both a Disciple and a Discipler (ADR-012)
reads their own progress as "Self" and their assigned
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
window the completion is locked by later progress (ADR-016): no role
corrects it in the MVP, and no one voids legitimate later meetings to
unlock it. Once the person has been appointed as a Discipler, undo is
also refused for the eligibility lesson and earlier lessons (ADR-018
decision 9). Every undo is audited.

*Reopen lesson completion* is a COORDINATOR-only database-level recovery
capability, not an action in the app (ADR-016). It is refused while any
later lesson is COMPLETED or has a recorded meeting for the person.

*Create D Group announcement* shows "Oversight" for COORDINATOR. The D
Group Leader is the normal authority. Coordinator capability exists as a
ministry-oversight fallback, for example where a D Group currently has
no active Leader.

The Super Admin has no access to discipleship meeting outcomes
(attendance), discipleship progress or any other ministry data (ADR-004
as amended, ADR-022). Administering the platform does not confer
ministry-care access. Where the same person needs both, COORDINATOR is
assigned separately, by another Super Admin or trusted tooling, never by
themselves.

No person may record their own meeting outcome, in any role: a recorder
is never a participant in a meeting they record (explicit check from
Slice 5), and nobody is paired with themselves (ADR-012, enforced
since Migration 013).

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
| Super Admin without COORDINATOR | none (ADR-004, ADR-022) |

Being Super Admin never grants church-wide ministry progress or
discipleship aggregates. The platform overview (section 10,
list_churches()) carries only membership and structure counts per
church: members by membership status, D Groups and Coordinators. These
are not discipleship aggregates and describe no person.

Church-wide discipleship aggregates shown to every role (for example a
church total on every member's Home) are not granted. They require a
separate privacy review first, because a single church has small groups
in which a count can identify a person ("1 Disciple on Lesson 2").

Progress aggregates are factual counts and states only. No aggregate
ranks or compares people, Disciplers or D Groups, and no aggregate is a
percentage, ratio or consistency score (decision 8).

Candidate aggregate, not granted (decision 9): "lessons completed this
month". It is a candidate Reporting / Oversight metric owned by Slice 12,
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
- Super Admin → none through this table. The full name and sign-in
  email of each church's active Coordinators, and of the account a
  Coordinator email resolves to, are returned only by the platform
  operations (section 10)

Implemented: own profile; for the COORDINATOR the profiles of anyone
holding a membership row (any status) in their church, which is what
the membership-request list needs (ADMIN shared this until ADR-022;
Slice 8 narrows private.can_view_profile_as_church_admin() to
COORDINATOR); and,
since Migration 006, the ministry scope
(private.can_view_profile_in_ministry): a LEADER sees everyone actively
placed in their group, including people who still need setup
(private.leads_group_of_membership, on placements since Migration 012;
the Migration 006 invitee clause is removed); a DISCIPLER sees their
assigned Disciples and their own Leader; a DISCIPLE sees their own
Leader and their own Discipler. Other group
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
- PENDING or ACTIVE members of a SUSPENDED or ARCHIVED church → own
  church's id, name and status, so the app can explain the state
  (section 1a)
- Super Admin → no table policy; churches are listed through
  list_churches() (section 10)

Column-level: authenticated may SELECT only id, name and status.
join_code is not readable by any client role, and `select=*` is refused.
anon holds no grant. The Super Admin reads a church's join code only
through list_churches(), and the church's active COORDINATOR reads their
own church's code only through get_church_join_code() (ADR-022 decision
10a); no column grant is opened for either.

Lookup by join code is NOT available as a direct client SELECT. An
unapproved user must use lookup_church_by_join_code(), a trusted
controlled operation returning only minimal confirmation information,
for ACTIVE churches only.

INSERT / UPDATE:

- No client policy or grant. Churches are created by create_church()
  (Super Admin) or by trusted bootstrap tooling; the join code changes
  only through regenerate_join_code() and the status only through
  set_church_status(), both Super Admin and audited (ADR-022).

---

## church_memberships

SELECT:

- COORDINATOR → own church (ADMIN shared this until ADR-022)
- Super Admin → none; counts only, through list_churches()
- LEADER → everyone actively placed in own D Group, including people
  who still need setup
- DISCIPLER → assigned Disciples, own Leader
- DISCIPLE → self, own Leader and own Discipler

The LEADER, DISCIPLER and DISCIPLE scopes are implemented by
church_memberships_select_ministry (Migration 006), with the same
predicate as the profiles ministry scope. The LEADER scope follows
placements since Migration 012.

INSERT / UPDATE:

Membership approval and status transitions should use controlled operations.

Direct arbitrary client updates should not be allowed.

Implemented: request_join_church() (INSERT as PENDING),
approve_church_membership(), reject_church_membership() and
complete_onboarding(). Clients hold no INSERT or UPDATE policy on the
table. The pending-request list for approvers is a plain SELECT under
the COORDINATOR own-church scope (ADMIN / COORDINATOR until ADR-022),
embedding the applicant's profile through the user_id foreign key.

Slice 8 (ADR-022) adds: create_church(), assign_church_coordinator()
and replace_church_coordinator() create or reactivate the Coordinator's
membership as ACTIVE with onboarding complete (Super Admin). One church
per person: a person holds membership rows in at most one church,
enforced by a unique key on user_id.

---

## church_role_assignments

SELECT:

- COORDINATOR → role information needed for ministry operation
- Super Admin → none through this table; the Coordinators of each
  church through list_churches()
- User → own roles where needed (implemented: own active and ended
  roles, so the client can show approver entry points; authority is
  still decided server-side on every operation)

WRITE:

- Super Admin only, through create_church(), assign_church_coordinator(),
  replace_church_coordinator() and end_church_coordinator() (ADR-022),
  and trusted bootstrap tooling. COORDINATOR is the only role written;
  an active ADMIN row is refused by the database.

Migration 006 revokes INSERT, UPDATE, DELETE and TRUNCATE from
authenticated, so no client write path exists; the Slice 8 operations
write as SECURITY DEFINER.

---

## platform_roles

Added by Slice 8 (ADR-022). Identity level: profiles.id.

SELECT:

- User → own rows (active and ended), so the client can show the
  Platform area; authority is still decided server-side by
  private.is_super_admin() on every operation
- Nobody else, a Super Admin included: there is no list of Super
  Admins in the app

INSERT / UPDATE / DELETE:

- No client policy and no grant to anon or authenticated, so no
  client write path exists.
- private.grant_platform_role() and private.end_platform_role(),
  service_role only, run by tool/grant_super_admin.ps1 and the local
  seed. Audited as PLATFORM_ROLE_GRANTED / PLATFORM_ROLE_ENDED.
- Rows are ended (ended_at, ended_by), never deleted.

private.is_super_admin() reads this table only, for (select auth.uid()).
Changing local state, routes, profile fields, user metadata or an RPC
parameter cannot grant it.

---

## d_groups

SELECT:

- Super Admin → none (ADR-022)
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
A Super Admin without COORDINATOR has no scope (the retired ADMIN had none either). Writes: create_d_group() and
assign_d_group_leader(); set_d_group_status() is not built yet.
Clients hold SELECT only; anon holds nothing.

Since Migration 012, a person actively placed in a group can read its
row whether or not they hold a responsibility there (policy
d_groups_select_placed), so a member who needs setup sees their group's
name.

---

## d_group_placements

Added by Migration 012 (ADR-018).

SELECT:

- COORDINATOR → church-wide, history included
- LEADER → own D Group's, history included
- Person → own placements
- Anyone else, including a Super Admin without COORDINATOR → none

Implemented by d_group_placements_select_manager
(private.can_manage_d_group_members) and d_group_placements_select_own.

WRITE:

- add_members_to_d_group() → COORDINATOR, or the group's LEADER
- remove_from_d_group() → COORDINATOR, or the group's LEADER; the
  LEADER's own placement is refused
- create_d_group() and assign_d_group_leader() → COORDINATOR, for the
  Leader's placement

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
- Discipler appointment (ADR-012)

Do not allow arbitrary direct client mutation.

Implemented: create_d_group(), assign_d_group_leader(),
set_up_member() (Migration 013), add_self_as_discipler(),
appoint_discipler() (Migration 014) and remove_from_d_group()
(Migration 012). respond_to_d_group_invitation() and
end_d_group_membership() were dropped by Migration 012. Clients hold
SELECT only.

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
writes through set_discipler() and remove_from_d_group() (Migration
012, replacing end_d_group_membership()) only.

---

## d_group_invitations

Added by Migration 006. Historical since Migration 012 (ADR-018):
pending rows were withdrawn, invite_to_d_group(),
withdraw_d_group_invitation(), respond_to_d_group_invitation() and
get_my_pending_invitation() were dropped, and no operation writes the
table. The SELECT policies below still apply to the history; the WRITE
list records what Migration 006 allowed.

SELECT:

- COORDINATOR → church-wide, every status
- LEADER → own D Group's, every status (a decline is shown to the
  inviter, who may invite again)
- Invitee → own
- DISCIPLER, DISCIPLE, Super Admin without COORDINATOR → none

Until Migration 012 the invitee read their live invitation, with the
group name and inviter name, through get_my_pending_invitation(), now
dropped.

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

Lesson content (ADR-010; scope replaced by ADR-019 decision 6, widened
by ADR-019 decision 16 on 2026-10-06, and narrowed to the relationship
by ADR-023 on 2026-10-08): the lesson list (curriculum_lessons) and the
covers stay readable by ACTIVE members of an ACTIVE church. Lesson
content is tiered, and each read is decided for the pair (reader,
context person):
- own context, for a reader holding an active DISCIPLER row, every
  LEADER included: all ten lessons in both tiers (ADR-024), from
  appointment until the responsibility ends; My Journey still presents
  their own journey when they are also a Disciple
- own context, for everyone else: the Disciple tier of the reader's own
  reached lessons; never the Discipler tier (the COORDINATOR excepted,
  below)
- context of a currently assigned Disciple: the Discipler, a Leader
  among them, reads all ten lessons in both tiers
- context of another active Disciple of the group the reader currently
  leads: the LEADER reads the Disciple tier of that Disciple's reached
  lessons, never the Discipler tier (recording or completing on a
  Discipler's behalf grants no answers)
- the COORDINATOR: both tiers of any lesson, in any context, their own
  included (ADR-023 decision 9); as oversight, never through My Journey,
  which presents the Coordinator's own journey like any Disciple's
  (decision 10)
- reading never affects progression for any role (decision 11)
- "reached": lessons COMPLETED, plus the current lesson only while the
  person holds an active DISCIPLE responsibility; a default Lesson 1
  resolved for someone with no journey grants nothing
- nobody else, including a Super Admin without COORDINATOR, a member
  without a journey and a Discipler without Disciples (who reads only
  their own journey)
There is no client write path. Publishing is trusted tooling in the service-role context.
Implemented in Migration 017: curriculum_publications,
lesson_content_blocks and lesson_block_answers have RLS enabled, no
client policy and no grant to anon or authenticated. Clients read only
through get_lesson_content(), list_lesson_access() and
get_my_readable_content() (section 10).
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
both a Disciple and a Discipler (ADR-012) reads their own
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

Once the person has been appointed (a ministry_role_transitions row to
DISCIPLER), undo of the eligibility lesson and earlier lessons is
refused for every caller (eligibility_lesson_protected, Migration 015,
ADR-018 decision 9). Initial rollout recognition writes no transition
row and locks nothing.

Completion and undo are attributable (confirmed_by and submitted_by;
audit_events with the prior values) and audited.

No caller ever marks completed, undoes or reopens a lesson in which they
are the Disciple.

Reopening a COMPLETED lesson (ADR-016):

- COORDINATOR only, through reopen_lesson_completion(), audited
- a database-level recovery operation, not an MVP action
- refused while any later lesson is COMPLETED or has a recorded meeting
  for the person, so it never applies once the undo window has closed

---

## ministry_role_transitions

The table name is kept; a row is now the Discipler appointment record
(ADR-012). Appointment does not end the person's DISCIPLE row.

SELECT:

- COORDINATOR
- relevant LEADER
- affected user for appropriate personal history

Implemented (Migration 014): ministry_role_transitions_select_manager
gives the COORDINATOR church-wide and the group's LEADER their own
group (private.can_manage_d_group_members);
ministry_role_transitions_select_own gives the person their own rows.

INSERT:

Only through appoint_discipler() (Migration 014). No client write
grants. Initial rollout recognition and a Leader adding themselves
write no row here (ADR-018 decision 6).

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

initial_setup_closed_at (Migration 013, ADR-018) records when the
COORDINATOR closed the church's initial setup period (NULL while open).
It is changed only through set_initial_setup_open() (COORDINATOR,
audited); any ACTIVE member reads the period's state through
get_initial_setup_status().

SELECT:

- COORDINATOR
- Super Admin → none (ADR-022)

UPDATE:

- COORDINATOR

The Coordinator owns ministry configuration because these values govern
the follow-up workload they are accountable for. Church identity, the
join code and church status are platform operations of the Super Admin
(ADR-022). create_church() inserts the settings row with the bootstrap
defaults.

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

Super Admin (ADR-022): platform events only, through
list_platform_audit(): PLATFORM_ROLE_GRANTED, PLATFORM_ROLE_ENDED,
CHURCH_CREATED, JOIN_CODE_REGENERATED, COORDINATOR_ASSIGNED,
COORDINATOR_REPLACED, COORDINATOR_ENDED, CHURCH_STATUS_CHANGED and
CHURCH_ROLE_ENDED with reason admin_retired. The operation returns the
action, the time, the church and the actor's name; metadata names no
member other than a Coordinator. Church ministry events are never
returned to the Super Admin.

---

# 10. Controlled Database Operations

The following should NOT be implemented as multiple independent Flutter writes.

Use transactional PostgreSQL functions / RPCs or equivalent trusted backend operations.

Bootstrap stays trusted deployment tooling, not a runtime operation,
specified in DATABASE_CONSTRAINTS.md section 0. In-app church
provisioning by the Super Admin (ADR-022, Slice 8) is a runtime
controlled operation and is listed below.

Recommended operations:

- lookup_church_by_join_code()
- request_join_church()
- approve_church_membership()
- reject_church_membership()
- complete_onboarding()
- create_church() (ADR-022)
- preview_coordinator_account() (ADR-022)
- assign_church_coordinator() (ADR-022; replaces the planned assign_church_role())
- replace_church_coordinator() (ADR-022)
- end_church_coordinator() (ADR-022)
- regenerate_join_code() (ADR-022)
- set_church_status() (ADR-022)
- list_churches() (ADR-022)
- list_platform_audit() (ADR-022)
- get_church_join_code() (ADR-022 decision 10a; the Coordinator)
- private.grant_platform_role() / private.end_platform_role() (service role only; ADR-022)
- create_d_group()
- set_d_group_status()
- assign_d_group_leader()
- list_addable_members() (ADR-018)
- add_members_to_d_group() (ADR-018)
- remove_from_d_group() (ADR-018; replaces end_d_group_membership())
- set_up_member() (ADR-018)
- set_initial_setup_open() (ADR-018)
- get_initial_setup_status() (ADR-018)
- add_self_as_discipler()
- set_discipler()
- transfer_disciple()
- record_discipleship_meeting()
- void_discipleship_meeting()
- void_meeting_participant()
- complete_lesson(p_membership_id, p_lesson_id) (ADR-015; replaces submit_lesson_finished())
- undo_lesson_completion(p_membership_id, p_lesson_id) (ADR-015)
- reopen_lesson_completion()
- appoint_discipler() (ADR-012; replaces promote_disciple_to_discipler())
- list_discipler_candidates() (ADR-018)
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

invite_to_d_group(), withdraw_d_group_invitation(),
respond_to_d_group_invitation(), get_my_pending_invitation() and
end_d_group_membership() were built by Migration 006 and dropped by
Migration 012 with placement by invitation (ADR-018).

Operation notes:

lookup_church_by_join_code()
→ SECURITY DEFINER
→ requires an authenticated caller
→ returns only minimal church confirmation information (id and name)
→ ACTIVE churches only; a SUSPENDED or ARCHIVED church is a miss
→ rate limited; a miss returns an empty result rather than raising
  (DATABASE_CONSTRAINTS.md section 1, Join Code Format and Rate Limiting)

request_join_church()
→ takes the church identifier returned by the prior lookup, together
  with the join code, which must resolve to that ACTIVE church
→ creates a PENDING membership; returns REQUESTED, ALREADY_PENDING,
  ALREADY_ACTIVE, NOT_REQUESTABLE, INVALID_CODE or, from Slice 8,
  IN_ANOTHER_CHURCH (the caller holds a membership row in another
  church; one church per person, ADR-022 decision 9)
→ rate limited
→ writes no role and no D Group responsibility

reject_church_membership()
→ COORDINATOR of the same church, own membership ACTIVE, church ACTIVE
  (ADMIN or COORDINATOR until ADR-022)
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
→ never changes a COMPLETED lesson: recomputation leaves COMPLETED as
  it is, so no void is refused to protect it (ADR-017; the earlier
  lesson_completed_protected refusal is withdrawn)
→ audited
→ trigger CONSECUTIVE_ABSENCE recalculation (from the monitoring
  slice on; ADR-014)
→ never the caller's own outcome, in any role (cannot_void_own_meeting)
→ as built: Migration 008 (20261006000001); a meeting outside the
  caller's view is reported as not found; get_meeting_history() returns
  can_void_meeting and can_void_participant for the caller, and the app
  shows void actions only from them

list_group_progress(p_d_group_id) (Slice 5 step 8)
→ the Leader of that D Group, or a COORDINATOR of its church
→ refused for everyone else, a DISCIPLER of that group included (N7:
  a Discipler reads only their own assigned Disciples, through
  list_disciple_progress())
→ derived figures only; as built: Migration 010 (20261006000003)

complete_lesson(p_membership_id, p_lesson_id) (ADR-015)
→ the Disciple's current assigned DISCIPLER; own-D-Group LEADER or
  COORDINATOR as fallback
→ never the Disciple themselves
→ requires the Disciple's eligible (current) lesson only, NOT_STARTED or
  IN_PROGRESS; no meeting count is required (ADR-017)
→ sets COMPLETED, completed_at = now(), confirmed_by = caller,
  ready_at = completed_at, submitted_by = caller, started_at kept or,
  with no credited meeting, = completed_at; audited as LESSON_COMPLETED
  with the credited count as a fact
→ refusals: cannot_act_on_own_lesson, not_authorized, lesson_not_found,
  lesson_not_eligible (lesson_not_in_progress and below_submission_minimum
  are withdrawn by ADR-017)
→ the next lesson becomes current by derivation

undo_lesson_completion(p_membership_id, p_lesson_id) (ADR-015)
→ the Disciple's current assigned DISCIPLER, own-D-Group LEADER or
  COORDINATOR
→ never the Disciple themselves
→ requires COMPLETED, no later lesson COMPLETED, and no RECORDED
  participant row for the person in a RECORDED meeting for the next
  lesson
→ for a person appointed as Discipler, refused for the eligibility
  lesson and earlier lessons, as for reopen (ADR-018 decision 9;
  Migration 015); get_disciple_journey() reports can_undo false for them
→ returns to IN_PROGRESS (NOT_STARTED when no credited participation
  remains); clears ready_at, submitted_by, completed_at and
  confirmed_by; audited as LESSON_COMPLETION_UNDONE with the prior values
→ refusals: cannot_act_on_own_lesson, not_authorized, lesson_not_completed,
  later_lesson_completed, next_lesson_started,
  eligibility_lesson_protected

reopen_lesson_completion()
→ COORDINATOR only; a database-level recovery operation with no MVP
  action (ADR-016)
→ audited as LESSON_COMPLETION_REOPENED with the prior completion
→ never the caller's own lesson (cannot_act_on_own_lesson)
→ rejected when any later lesson is COMPLETED for the same membership
  (later_lesson_completed)
→ rejected when any later lesson has a RECORDED participant row for the
  person in a RECORDED meeting, whatever the outcome
  (later_lesson_has_meetings). Legitimate later history is never voided,
  moved or deleted to get past this refusal
→ for a person appointed as Discipler, rejected for the eligibility
  lesson (Lesson 5) and earlier lessons; later lessons may be reopened,
  subject to the other preconditions (ADR-012 decision 9, N9; the
  eligibility lesson comes from `private.discipler_eligibility_lesson()`, D2). This replaces "rejected when
  the person has already been promoted to DISCIPLER".
→ returns to IN_PROGRESS, or NOT_STARTED when no credited participation
  remains; never to READY_FOR_COMPLETION (ADR-015)
→ never cascades; see DATABASE_CONSTRAINTS.md section 4

appoint_discipler(p_membership_id) (ADR-012; replaces
promote_disciple_to_discipler(); Migration 014)
→ COORDINATOR of the person's church only, never for themselves
  (cannot_appoint_self, D9); no acceptance workflow
→ requires derived eligibility: Lesson 5 of the active curriculum at
  COMPLETED (ADR-015; never stored; not_eligible before it, D5)
→ requires an ACTIVE membership, an active DISCIPLE row in an ACTIVE
  group (not_an_active_disciple once it has ended, D8) and no active
  DISCIPLER row (already_discipler)
→ creates a DISCIPLER responsibility with discipler_basis APPOINTMENT
  in the same D Group as the person's DISCIPLE responsibility, and the
  appointment record in ministry_role_transitions
→ does not end the person's DISCIPLE responsibility, their own discipler
  assignment or their lesson progress
→ is not a monitoring recalculation trigger or episode boundary
→ attributed and audited as DISCIPLER_APPOINTED

list_discipler_candidates(p_d_group_id, p_church_id) (Migration 014)
→ read-only; eligible Disciples who are not Disciplers, with the date
  they became eligible
→ for one group: its LEADER or the COORDINATOR; church-wide (no
  group): the COORDINATOR
→ eligibility is not appointment

Platform operations (ADR-022, Slice 8). All are SECURITY DEFINER with
search_path '', executable by authenticated, check
private.is_super_admin() first and raise PT403 not_authorized otherwise,
before reading anything, and write their audit event with church_id
set where a church is concerned.

create_church(p_name, p_coordinator_email)
→ creates, in one transaction: the church (ACTIVE) with a join code from
  private.generate_join_code(), its church_settings with the bootstrap
  defaults, its ACTIVE curriculum and ten lesson rows, the Coordinator's
  ACTIVE membership (onboarding complete, approved_by NULL) and their
  COORDINATOR row
→ the email must belong to a registered account with a confirmed email
  that holds no membership in any church (account_not_found,
  email_not_confirmed, member_of_another_church); never the caller
  (cannot_assign_self)
→ returns the church id and join code; audited as CHURCH_CREATED and
  COORDINATOR_ASSIGNED
→ lesson content is published separately by trusted tooling, under the
  church's own licence reference (ADR-019 decision 11)

preview_coordinator_account(p_church_id, p_email)
→ read-only; the confirmation step before create, assign or replace
→ returns whether a registered, confirmed account exists for the email,
  its full name, and whether it belongs to this church already, to
  another church, or to none; nothing else about the person

assign_church_coordinator(p_church_id, p_email)
→ church ACTIVE or SUSPENDED; adds a Coordinator
→ the account as for create_church(), or already a member of this
  church: their membership is created or reactivated as ACTIVE, from any
  status, with onboarding complete (coalesce) and joined_at kept
  (coalesce); COORDINATOR granted (already_coordinator if held)
→ audited as COORDINATOR_ASSIGNED, with the membership's prior status
  when it was reactivated

replace_church_coordinator(p_church_id, p_current_membership_id, p_email)
→ church ACTIVE or SUSPENDED; ends the current COORDINATOR row and
  grants the new one in the same transaction, so the church is never
  without a Coordinator (ADR-022 decision 12)
→ the replaced person stays an ACTIVE member; their D Group
  responsibilities are untouched
→ audited as COORDINATOR_REPLACED

end_church_coordinator(p_church_id, p_membership_id)
→ church ACTIVE or SUSPENDED; ends one of several Coordinators
→ refused when it would leave the church with none (last_coordinator).
  The deferred invariant enforces this for an ACTIVE church at commit;
  the operation refuses it for a SUSPENDED church too, so that
  reactivation never meets a church without one
→ audited as COORDINATOR_ENDED

regenerate_join_code(p_church_id)
→ church ACTIVE or SUSPENDED
→ a new code from private.generate_join_code(), retried on a unique
  collision; sets join_code_updated_at; the old code stops matching at
  once; PENDING requests made with it stay PENDING
→ returns the new code; audited as JOIN_CODE_REGENERATED with no code
  value in the metadata

set_church_status(p_church_id, p_status)
→ ACTIVE ↔ SUSPENDED; ACTIVE or SUSPENDED → ARCHIVED; ARCHIVED is final
  (church_archived); a no-op change is refused (status_unchanged)
→ to ACTIVE requires an active Coordinator (enforced at commit)
→ changes no membership, role, group or progress row
→ audited as CHURCH_STATUS_CHANGED with the old and new status

list_churches()
→ read-only; per church: id, name, status, join code, created_at,
  member counts by membership status, D Group count, and the id, full
  name and sign-in email of each active Coordinator; nothing else

list_platform_audit(p_church_id default null, p_before default null)
→ read-only; platform events only (section 9), newest first, paged

private.grant_platform_role(p_user_id, p_role) / private.end_platform_role(p_user_id, p_role)
→ service_role only; never executable by anon or authenticated
→ grant is idempotent while an active row exists; end sets ended_at and
  ended_by; audited as PLATFORM_ROLE_GRANTED / PLATFORM_ROLE_ENDED with
  church_id NULL

get_church_join_code(p_church_id) (ADR-022 decision 10a)
→ not a platform operation: the caller must be an active COORDINATOR
  of that church, on an ACTIVE membership, with the church ACTIVE;
  PT403 not_authorized otherwise, including for a Super Admin without
  COORDINATOR (who uses list_churches()) and for every other role
→ read-only; returns the current join code and join_code_updated_at;
  writes nothing and is not audited (a read)
→ the Coordinator has no operation that generates or changes the code

Role-ending operations, membership status transitions and church status
changes
→ never leave an ACTIVE church without an active COORDINATOR on an
  ACTIVE membership; enforced at commit by deferred constraint triggers
  (DATABASE_CONSTRAINTS.md section 1, Coordinator Invariant), which lock
  the church row before counting so concurrent changes cannot both pass
→ every operation that changes a Coordinator, a Coordinator's
  membership status or a church's status takes the same church row lock
  first

create_d_group()
→ COORDINATOR only
→ creates the group, its LEADER row and the Leader's placement
  together; the Leader must be an unplaced ACTIVE member of the church
→ audited as D_GROUP_CREATED

assign_d_group_leader()
→ COORDINATOR only
→ ends the current LEADER row and creates the new one in one
  transaction; the new Leader is unplaced, or placed in this group
  holding no responsibility other than DISCIPLER (leader_not_eligible
  otherwise)
→ the replaced Leader leaves the group (placement ended) unless they
  also hold a DISCIPLER row there
→ audited as D_GROUP_LEADER_ASSIGNED

list_addable_members(p_d_group_id) (Migration 012)
→ read-only; COORDINATOR or the group's LEADER
→ ACTIVE members of the group's church with no active placement; names
  only, never phone numbers

add_members_to_d_group(p_d_group_id, p_membership_ids) (Migration 012)
→ COORDINATOR (any group in the church) or the group's LEADER; the
  group must be ACTIVE
→ places ACTIVE members of the church who have no active placement;
  no acceptance step; they hold no responsibility until set up (Needs
  setup)
→ all or nothing: if any chosen person is not ACTIVE or is already
  placed, nobody is added (member_not_active, member_already_placed);
  at most 100 per call (too_many_members)
→ audited as D_GROUP_MEMBER_PLACED, one event per person

remove_from_d_group(p_d_group_placement_id) (Migration 012; replaces
end_d_group_membership())
→ COORDINATOR or the group's LEADER; unknown and not-yours are refused
  alike
→ ends every active discipler assignment on either side of the
  person's rows, then every responsibility they hold in the group, then
  the placement
→ the LEADER is refused (leader_cannot_be_removed); replace instead
→ audited as D_GROUP_MEMBER_REMOVED

set_up_member(p_d_group_placement_id, p_responsibility) (Migration 013)
→ COORDINATOR or the group's LEADER; active placement, ACTIVE group
  and ACTIVE member
→ DISCIPLE: refused for the group's Leader (leader_cannot_be_disciple)
  or when already a Disciple
→ DISCIPLER: recognition as an Existing Discipler, only while the
  church's initial setup period is open (initial_setup_closed
  otherwise); recorded with discipler_basis INITIAL_ROLLOUT and no
  ministry_role_transitions row
→ also adds a second responsibility to a person already set up
→ audited as D_GROUP_MEMBER_SET_UP

set_initial_setup_open(p_church_id, p_open) (Migration 013)
→ COORDINATOR only
→ closes or reopens the initial setup period
  (church_settings.initial_setup_closed_at)
→ audited as INITIAL_SETUP_CLOSED / INITIAL_SETUP_REOPENED

get_initial_setup_status(p_church_id) (Migration 013)
→ read-only; any ACTIVE member of the church

add_self_as_discipler()
→ the group's LEADER only, for themselves
→ since ADR-020 every active Leader already holds DISCIPLER (granted by
  create_d_group() and assign_d_group_leader(), discipler_basis
  LEADER_SELF), so it answers already_discipler; kept for compatibility
  and called by no client

set_discipler()
→ COORDINATOR or the group's LEADER, who keeps pairing authority for
  appointed Disciplers (D6)
→ one operation pairs, re-pairs (ends the old assignment, creates the
  new one) or, with a null Discipler, unpairs; replaces the
  assign_discipler() / reassign_discipler() names listed before
  Vertical Slice 3
→ refuses pairing a person with themselves (cannot_pair_with_self) and
  a reciprocal pair (reciprocal_pairing, D7)
→ audited as DISCIPLER_ASSIGNED / _REASSIGNED / _UNASSIGNED
→ CONSECUTIVE_ABSENCE resolution on an ended assignment arrives with
  the monitoring slice; the function marks the place (ADR-014)

list_placeable_members() / get_my_d_group_roster()
→ read-only SECURITY DEFINER reads
→ list_placeable_members(): COORDINATOR (every ACTIVE member with
  placement) or the group's LEADER (unplaced members only); names and
  placement, never phone numbers; recreated by Migration 012 on
  placements, without has_pending_invitation
→ get_my_d_group_roster(): the caller's group by name, with phone
  numbers only for their own Leader, own Discipler and, for a
  Discipler, assigned Disciples; a caller who needs setup gets only
  their Leader's row, without phone number (Migration 012)
  and every row carries d_group_member_count, everyone placed in the
  group including people who still need setup, as a count only, no
  names (Migration 016)
→ get_my_pending_invitation() was dropped by Migration 012

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

set_discipler() (re-pair or unpair) and remove_from_d_group()
→ end the Disciple's discipler assignment
→ resolve the ACTIVE CONSECUTIVE_ABSENCE condition belonging to the
  ended assignment
→ Discipler appointment is not in this list: it ends no assignment
  (ADR-012)

approve_church_membership()
→ COORDINATOR of the same church, own membership ACTIVE, church ACTIVE
  (ADMIN or COORDINATOR until ADR-022)
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

publish_curriculum() (Migration 017, ADR-019)
→ service_role only; no client grant. Trusted tooling
  (tool/publish_curriculum.ps1, and the local seed) calls it
→ supersedes the current publication and writes the new one with its
  blocks and answers in one transaction; sets curriculum_lessons.title;
  audited as CURRICULUM_PUBLISHED
→ FULL is refused without a licence reference; a METADATA publication
  refuses any block type outside the metadata set

get_lesson_content(), list_lesson_access(), get_my_readable_content()
(Migration 017, ADR-019)
→ ACTIVE member of the lesson's church; the only client reads of
  lesson content (the content tables have no client policy or grant)
→ every block is checked with private.can_read_lesson_tier(). As built
  (Migration 019, ADR-019 decision 16): the Coordinator both tiers of
  any lesson; any active Discipler of the church (every Leader, ADR-020)
  both tiers of any lesson, in any context; the person themselves the
  Disciple tier of reached lessons; nobody else. From Slice 8 (ADR-023)
  the Discipler branch is removed: the Coordinator both tiers of any
  lesson in any context; in own context the Disciple tier of the
  reader's reached lessons; for a currently assigned Disciple all ten
  lessons in both tiers; for another active Disciple of the group the
  reader leads the Disciple tier of that Disciple's reached lessons;
  nobody else, and nothing while the church is not ACTIVE. From Slice 8
  Phase 4 (ADR-024, Migration 027) the own context of a reader holding
  an active DISCIPLER row, every Leader included, opens both tiers of
  every lesson
→ get_my_readable_content() returns the union of what the reader may
  read across their contexts (own, each currently assigned Disciple, each
  active Disciple of a group they lead), unchanged in shape. The open
  tiers of one context come from list_lesson_access(p_for_membership_id),
  which the device copy stores per context so the reader applies the
  context it is opened in (ADR-023 decision 6; Migration 026)
→ get_lesson_content() refuses with PT403 not_authorized when the caller
  may read neither tier; answers are returned only with the Discipler
  tier
→ list_lesson_access() refuses PT403 for a person outside the caller's
  scope, and otherwise returns every lesson with the tiers open to the
  caller, so a locked lesson is shown, never its content
→ get_my_readable_content() returns everything the caller may read now,
  for the device copy; the app replaces the copy on each refresh and
  clears it on sign-out

get_church_avatars() (Migration 021)
→ an ACTIVE member; returns the avatar key of each ACTIVE member of their
  own church who chose one; nothing else about the person
→ profiles.avatar_url is written only by the person (profiles_update_own)

check_lesson_answers() (Migration 020, ADR-021 decision 7)
→ any caller who may read the lesson's Disciple tier in their own context
  (private.can_read_lesson_tier(lesson, 'DISCIPLE', null)); PT403 otherwise
→ returns, only for blanks the caller wrote in, whether each is right and
  the book's answer; blanks of Disciple-tier blocks of the current
  publication only; nothing is stored

get_lesson_covers(), set_lesson_cover() (Migration 019, ADR-019
decision 17)
→ get_lesson_covers(): any ACTIVE member, the covers of their church's
  lessons, open and locked alike (no lesson content)
→ set_lesson_cover(): service_role only (tool/curriculum/build_covers.dart)
→ lesson_covers has RLS enabled and no client grant

Each operation must:

1. Authenticate the caller.
2. Determine church membership, and that the church is ACTIVE (a platform operation determines the platform role instead).
3. Verify role/responsibility.
4. Verify record scope.
5. Validate business rules.
6. Execute atomically where multiple writes are involved.
7. Create audit information when required.

Mandatory review item for every new or changed operation, policy or
helper (ADR-022, AGENTS.md): step 2's church condition. Authority over
church data is decided through the gated caller helpers (Migration 025),
or with private.church_is_active() where the caller is identified inline.
A suspended or archived church then refuses with the usual PT403
not_authorized, or returns nothing; there is no separate status code. The
app learns the status from the church's own row: id, name and status stay
readable by its PENDING and ACTIVE members (section 3, churches). Each new
client-callable function is classified in the registry sweep
(test/integration/church_status_test.dart), which fails when one is
missing.

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

Super Admin status alone grants no access to pastoral or discipleship care notes, or to any other ministry data (ADR-022).

## Historical Integrity

Important historical records should normally be ended, resolved, cancelled, or voided instead of physically deleted.

## Trusted State Transitions

Complex business transitions must execute through controlled server-side operations rather than arbitrary direct table updates.

---

# Core Authorization Rule

The platform role determines authority over churches as such, never over ministry data.

Church-level roles determine church-wide authority.

D Group responsibilities determine contextual ministry authority.

Assignments determine direct care responsibility.

RLS must evaluate all three when necessary.