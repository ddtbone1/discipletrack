# DiscipleTrack — Database Constraints

## Purpose

This document defines the important database invariants for the DiscipleTrack MVP.

The ERD defines the data structure.

This document defines the rules PostgreSQL must protect so invalid business states cannot be created even if the Flutter client contains a bug.

---

# 0. Bootstrap and Initial State

This section is the authoritative specification for provisioning a
church. Other documents reference it rather than restating it.

## Nature

Bootstrap is trusted deployment and setup tooling. It is not a runtime
controlled operation and is deliberately absent from the controlled
operations list in RBAC_RLS_MATRIX.md.

It is never reachable from Flutter. If implemented as a SQL function,
EXECUTE must be revoked from the anon and authenticated roles and it
must not be exposed through PostgREST. It runs in the migration or
service-role context.

## Inputs

- church_id (UUID, supplied by the caller)
- church name
- the initial trusted user's Supabase Auth user id
- optionally: join code, curriculum name, the twelve lesson titles

## Preconditions

- the auth identity already exists
- its profiles row already exists, created by the trigger described in
  section 1

## Records Created

All within one transaction:

1. churches — supplied id, name, join code, status ACTIVE
2. church_settings — consecutive_absence_threshold = 3, consecutive_missed_meeting_threshold = 3, follow_up_due_days = 7
3. church_memberships — the initial user, status ACTIVE
4. church_role_assignments — two active rows, ADMIN and COORDINATOR
5. curricula — church-owned, status ACTIVE
6. curriculum_lessons — twelve rows, lesson_number 1 through 12, required_meetings = 4
7. audit_events — CHURCH_BOOTSTRAPPED

Lesson rows are identification and ordering only. DiscipleTrack tracks
progress through the curriculum; it does not store or deliver lesson
content.

The initial user holds both ADMIN and COORDINATOR for the single-church
deployment. COORDINATOR is required because follow-up escalation
terminates there.

## Transaction Boundary

All seven steps succeed or none commit.

## Idempotency

Keyed on the supplied church_id.

If a church with that id already exists, verify the postconditions and
return without modifying anything.

Because the whole operation is one transaction, a failed prior run
leaves no partial state, so re-running is always safe.

## Postconditions

These are assertable and serve as the bootstrap test:

- exactly one ACTIVE church with the supplied id
- church_settings present, both thresholds 3, due days 7
- the initial user holds an ACTIVE membership
- that membership has an active ADMIN and an active COORDINATOR role
- exactly one ACTIVE curriculum for the church
- exactly twelve lessons, numbered 1 to 12, each with required_meetings = 4
- join_code is unique and meets the entropy rule in section 1

## Out of Scope

Runtime church creation and multi-church onboarding are future scope.

---

# 1. Identity and Church

## Rules

- profiles.id maps to the authenticated Supabase user.
- A profile row is created automatically from auth.users through a trusted database trigger, not by the client.
- Clients may not INSERT or DELETE profiles. They may UPDATE only explicitly permitted self-service fields.
- profiles.full_name is required and must never be blank.
- A user may only have one membership per church.
- churches.join_code must be unique.
- churches.join_code must have sufficient entropy to make guessing impractical. The exact alphabet and length are an implementation choice, deliberately deferred; the entropy requirement is not.
- Joining through a church code must never automatically grant ADMIN or COORDINATOR.
- Only ACTIVE church members may receive active church roles.
- The same church role cannot be active twice for the same member.
- Historical role assignments must be ended using ended_at, not deleted.
- The church must preserve at least one active COORDINATOR, because follow-up escalation terminates there and because the Coordinator is the fallback attendance recorder.

## Last Coordinator Protection

No operation may leave a church with zero active COORDINATOR role
assignments.

The last active Coordinator cannot be removed, demoted, or have their
membership deactivated until another active Coordinator exists.

Enforcement:

- assign_church_role() and any operation that ends a role assignment
  reject the change with a usable error
- constraint trigger on church_role_assignments as defence in depth
- membership status transitions are also blocked by the same rule, since
  a non-ACTIVE membership makes its roles ineffective

Bootstrap establishes this invariant by assigning COORDINATOR to the
initial user.

## Profile Creation and full_name

Registration collects the user's full name. The signup flow supplies it
through Supabase Auth user metadata, and the trusted trigger uses that
value when creating the profiles row.

Required behaviour:

- the value is trimmed before use
- a missing or blank value is rejected
- the trigger must never invent a placeholder name

CHECK on profiles:

length(trim(full_name)) > 0

The CHECK covers the update path as well as creation, because users may
edit their own full_name and must not be able to blank it.

Operational note: any user created outside the application, for example
through the Supabase dashboard or the admin API, must also supply
full_name in metadata.

The exact signup failure behaviour when metadata is missing depends on
Supabase trigger and transaction semantics that have not been verified
in this environment. The invariant above is authoritative; the observed
behaviour must be confirmed with integration tests during
implementation.

## Membership Lifecycle

A person has exactly one church_memberships row per church. A returning
member reactivates that row. A second row is never created, so their
attendance, discipleship progress and care history remain continuous.

Allowed transitions:

PENDING     → ACTIVE (approval) | ARCHIVED (rejection)
ACTIVE      → INACTIVE | TRANSFERRED | ARCHIVED
INACTIVE    → ACTIVE
TRANSFERRED → ACTIVE
ARCHIVED    → ACTIVE (reinstatement, controlled and audited)

TRANSFERRED means the person transferred out of this CHURCH.

Moving a Disciple between D Groups is a separate concept and must not
alter church_memberships.status.

Reactivation does not restore previous D Group responsibilities. Those
records live in d_group_memberships and are already ended.

## Effects of Leaving ACTIVE

When an ACTIVE membership becomes INACTIVE, TRANSFERRED or ARCHIVED, the
following execute in the same transaction as the status change:

- end active D Group responsibilities
- end active discipler assignments involving that membership, on either side
- resolve ACTIVE attention conditions where the person is the subject
- reassign open follow-ups where the person is the ASSIGNEE, using the
  escalation rules in section 7
- write audit information for the transition and for any reassignment

Deliberately untouched:

- attendance, discipleship meetings, lesson progress and resolved care
  records remain as history
- open follow-ups where the person is the SUBJECT remain open as care
  cases; the assignee may resolve them with ADMINISTRATIVE_CORRECTION

An actionable follow-up must never remain assigned to a membership that
no longer has ACTIVE ministry access.

Reactivation restores no previous D Group responsibility or assignment
automatically.

The Last Coordinator Protection above also applies here: a membership
holding the only active COORDINATOR role cannot leave ACTIVE.

## Constraints

UNIQUE:

- church_memberships(church_id, user_id)
- churches(join_code)

Partial unique index:

- Active church role per member and role where ended_at IS NULL

CHECK:

- church_role_assignments: ended_at IS NULL OR ended_at > started_at

Authorization:

- Role assignment/removal requires RLS and controlled database operations.
- Church lookup by join code is available only through a trusted controlled operation returning minimal confirmation information. Arbitrary client lookup of churches by join code is not permitted.
- Join-code lookup and join requests must be rate limited. The mechanism may be selected during implementation; the requirement is not optional.

---

# 2. D Groups and Assignments

## Rules

- A D Group may have only one active LEADER.
- A person may actively lead only one D Group.
- A DISCIPLE may belong to only one active D Group.
- A person cannot simultaneously have active DISCIPLE and DISCIPLER responsibilities.
- A person MAY simultaneously hold active LEADER and DISCIPLER responsibilities. A Leader who personally disciples members must hold the DISCIPLER responsibility in order to receive discipler assignments.
- A DISCIPLER may care for multiple Disciples.
- A DISCIPLE may have only one active primary Discipler.
- Discipler and Disciple assignments must belong to the same D Group.
- The Discipler assignment must reference a DISCIPLER responsibility.
- The Disciple assignment must reference a DISCIPLE responsibility.
- Transfers and reassignments preserve historical records.

## Partial Unique Indexes

Enforce:

- one active LEADER per D Group
- one active D Group leadership per person
- one active DISCIPLE D Group membership per person
- one active Discipler assignment per Disciple

## Temporal Integrity

CHECK:

- d_group_memberships: ended_at IS NULL OR ended_at > started_at
- discipler_assignments: ended_at IS NULL OR ended_at > started_at

Overlap prevention:

Ambiguous overlapping periods must be prevented for the same person,
D Group and responsibility.

This matters because attendance eligibility is resolved as of
gathering.starts_at. Overlapping periods would make "did this person
belong to the D Group at time T" undecidable, which in turn makes
eligibility and the finalization completeness check ambiguous.

## Responsibility Correctness

The requirement that discipler_assignments references a DISCIPLER on one
side and a DISCIPLE on the other spans two tables and is not cleanly
expressible with an ordinary foreign key.

Enforce it with a constraint trigger rather than denormalizing
responsibility onto discipler_assignments purely to enable a composite
foreign key. See section 10.

Activeness of the referenced responsibility (ended_at IS NULL) remains a
controlled-operation invariant.

## D Group Lifecycle

Allowed transitions, all Coordinator-controlled:

ACTIVE   → INACTIVE
ACTIVE   → ARCHIVED
INACTIVE → ACTIVE
INACTIVE → ARCHIVED
ARCHIVED → terminal in the MVP

INACTIVE prevents creation of new gatherings. Existing data is preserved
and remains visible to authorized roles.

ARCHIVED must be REJECTED while either of the following remains:

- any active DISCIPLE d_group_membership in the group
- any DRAFT gathering belonging to the group

The Coordinator must explicitly transfer or unassign disciples and
finalize or cancel draft gatherings first. Disciples are never
automatically transferred, because moving a person between D Groups is a
ministry decision that must stay explicit and auditable.

On successful archival, in one transaction:

- end remaining active LEADER and DISCIPLER responsibilities
- end remaining active discipler assignments in the group
- set archived_at
- write an audit event

Open follow-ups are left untouched. They are church-scoped care cases
and remain the assignee's responsibility.

## Controlled Operations

Use transactional database operations for:

- D Group transfer
- Discipler reassignment
- responsibility changes
- D Group lifecycle changes

A transfer must succeed completely or fail completely.

---

# 3. Gatherings and Attendance

## Rules

- One attendance record exists per member per gathering.
- Attendance may only be recorded for members belonging to the D Group at gathering.starts_at.
- All eligible members must have an attendance status before finalization.
- Only FINALIZED gatherings affect official attendance and monitoring.
- DRAFT gatherings do not count.
- CANCELLED gatherings do not count.
- ABSENT contributes to consecutive unexplained absence for LEADER and DISCIPLER responsibilities. Gathering attendance never creates an attention condition for a DISCIPLE responsibility; see section 6.
- PRESENT breaks the absence streak.
- LATE breaks the absence streak.
- EXCUSED breaks the absence streak.
- Backdated attendance calculations use starts_at, not record creation time.
- Finalized attendance corrections must be controlled and audited.
- A gathering may not be FINALIZED while starts_at is in the future.
- Attendance recorded while DRAFT is preserved when a gathering is cancelled, but excluded from metrics, monitoring and follow-up generation.
- No person may create or modify their own official attendance.

## No Self-Attendance

The person identified by gathering_attendance.recorded_by must never be
the person identified by gathering_attendance.church_membership_id.

This applies universally, to Coordinator, Leader and Discipler alike.
Recording authority always means recording for OTHER eligible members
within the recorder's authorized scope.

Without this rule, the same person who is monitored controls their own
status and can mark themselves EXCUSED indefinitely, which would
neutralise absence monitoring for exactly the Leaders and Disciplers
that section 7 escalates for.

The check spans gathering_attendance, church_memberships and profiles,
so it is not expressible as a row CHECK.

Enforcement:

- constraint trigger on gathering_attendance, INSERT and UPDATE, which
  holds regardless of write path
- rejection inside save_draft_attendance() and
  correct_finalized_attendance() so the caller receives a usable error

RLS alone is insufficient, because the controlled operations run with
elevated rights.

## Single Authorized Recorder

A D Group may have only one person with recording authority, for example
a Leader with no separate Discipler.

Resolution order for that Leader's own attendance:

1. another DISCIPLER in the same D Group, using existing draft
   attendance authority
2. otherwise the COORDINATOR, using existing church-wide authority

No new recorder role is introduced for the MVP.

Consequence: a D Group whose only authorized recorder is the Leader
cannot finalize a gathering until someone else records the Leader's
status, because finalization requires every eligible member to have a
status. This is an accepted workflow dependency.

## Chronological Ordering

Attendance and monitoring order gatherings by:

(starts_at, id)

The identifier tiebreak keeps ordering deterministic when two gatherings
share the same starts_at.

## Gathering Lifecycle

Allowed transitions:

DRAFT → FINALIZED
DRAFT → CANCELLED

FINALIZED and CANCELLED are terminal in the MVP.

Not permitted:

- FINALIZED → CANCELLED
- CANCELLED → DRAFT
- CANCELLED → FINALIZED

Retracting an already finalized gathering would silently withdraw
official attendance from monitoring. If that capability is ever
required, it must be designed as its own controlled operation with
explicit attendance and monitoring recalculation, not as ordinary
cancellation.

## Unique Constraint

gathering_attendance(gathering_id, church_membership_id)

## Gathering State Check

When:

status = DRAFT

Require:

- finalized_by IS NULL
- finalized_at IS NULL
- cancelled_by IS NULL
- cancelled_at IS NULL

When:

status = FINALIZED

Require:

- finalized_by IS NOT NULL
- finalized_at IS NOT NULL
- cancelled_by IS NULL
- cancelled_at IS NULL

When:

status = CANCELLED

Require:

- cancelled_by IS NOT NULL
- cancelled_at IS NOT NULL
- finalized_by IS NULL
- finalized_at IS NULL

---

# 4. Curriculum and Discipleship Progress

## Rules

- Lesson numbers are unique inside a curriculum.
- required_meetings must be greater than zero.
- Lessons progress sequentially.
- Previous lesson completion is required before progressing to the next lesson. Lesson 1 is exempt.
- Sequential eligibility is enforced server-side inside record_discipleship_meeting(). It is an order-dependent, multi-row check and belongs in a controlled operation rather than a row constraint.
- A meeting records exactly one lesson, so every RECORDED participant in that meeting, whatever their attendance outcome, must be eligible for that same lesson.
- Disciples on different lessons therefore require separate discipleship meeting records. This is an intentional ministry constraint.
- There is no Coordinator sequencing override in the MVP. A correction or migration workflow is documented future scope.
- A discipleship meeting record reports a meetup after the fact, held or missed. DiscipleTrack does not schedule meetings.
- Every participant row carries an explicit attendance_status. There is no default.
- Only credited participation counts toward progress. See Attendance Outcome and Credit below.
- An absence never increments progress.
- One Disciple may appear only once in a meeting.
- The first credited participation moves the lesson into IN_PROGRESS.
- Reaching the required credited meeting count moves it to READY_FOR_COMPLETION.
- Reaching the meeting requirement does NOT automatically complete the lesson.
- Legitimate meetings may still be recorded for a lesson that is READY_FOR_COMPLETION. The credited count may exceed required_meetings, is neither clamped nor discarded, and the status remains READY_FOR_COMPLETION.
- The current D Group Leader confirms completion. The Coordinator may confirm as an oversight or fallback capability, for example where a D Group has no active Leader. Coordinator confirmation is attributable through confirmed_by and audited.
- Progress belongs to church_membership_id and survives D Group transfers and Discipler reassignment.
- Curriculum progress percentage is derived, not stored.
- Completing every lesson of the church's ACTIVE curriculum creates promotion eligibility.
- Promotion to DISCIPLER requires Coordinator approval.

## One Active Curriculum

Eligibility and progression both depend on "the active curriculum" being
a singular, well-defined thing.

Partial unique index on curricula:

UNIQUE (church_id) WHERE status = 'ACTIVE'

PostgreSQL expresses this as a partial unique index rather than a table
constraint, because table-level UNIQUE constraints cannot carry a WHERE
clause.

The literal number 12 is seed data in section 0, not a rule. No rule
elsewhere may hard-code a lesson count.

## Unique Constraints

- curriculum_lessons(curriculum_id, lesson_number)
- discipleship_meeting_participants(meeting_id, church_membership_id)
- disciple_lesson_progress(church_membership_id, lesson_id)

## Check Constraint

required_meetings > 0

## Attendance Outcome and Credit

discipleship_meeting_participants.status is record validity only:
RECORDED or VOIDED. It was named COUNTED in ERD v2 and Migration 001;
the rename to RECORDED is applied by a new migration.

discipleship_meeting_participants.attendance_status is the outcome:

| Outcome | Progress | Missed-meeting streak |
|---|---|---|
| PRESENT | credited | breaks |
| LATE | credited | breaks |
| ABSENT | not credited | increments / continues |
| EXCUSED | not credited | breaks; not an absence |

A participation is credited only when all three hold:

- discipleship_meetings.status = RECORDED
- discipleship_meeting_participants.status = RECORDED
- attendance_status IN (PRESENT, LATE)

"Credited" is a derived predicate, not a stored state.

## Held and Missed Meetups

Held and missed are derived from participant outcomes, never stored:

- held meetup: a RECORDED meeting with at least one credited participant
- missed meetup: a RECORDED meeting with no credited participant

Without a scheduler, an expected participant is one the recorder lists
when recording the meetup. A meetup cancelled by agreement before it was
due is not recorded.

discipleship_meetings.occurred_at is when the meetup took place, or for
a missed meetup when it was arranged to take place.

occurred_at must not be in the future. Enforced inside
record_discipleship_meeting(), because a CHECK constraint cannot
reference now() deterministically.

## Participant Validity

"Active at T" means started_at <= T AND (ended_at IS NULL OR ended_at > T).

Every RECORDED participant, whatever the attendance outcome, must
satisfy all three rules, evaluated as of
the meeting's occurred_at rather than at insert time, so that legitimate
backdated entry validates against the relationships that actually
existed when the meeting happened:

P1 — the participant held an active d_group_memberships row with
     responsibility DISCIPLE at occurred_at

P2 — that row's d_group_id equals the meeting's d_group_id

P3 — an active discipler_assignments row existed at occurred_at linking
     the participant as disciple to the meeting's
     discipler_d_group_membership_id as discipler

Validating uncredited rows too means nobody can record an absence for a
Disciple who is not assigned to the meeting's Discipler or not on the
meeting's lesson.

Consequence: a Disciple with no assigned Discipler cannot receive
progress credit, or have a missed meetup recorded, until an assignment
exists. This is intentional. The
remedy is to make the assignment, which is an existing Coordinator
operation.

There is no self-crediting risk here, because DISCIPLE and DISCIPLER are
mutually exclusive, so a Discipler can never be a participant in their
own meeting.

Enforcement:

- primary: record_discipleship_meeting(), which can return a usable error
- defence in depth: constraint trigger on
  discipleship_meeting_participants, firing on INSERT

Only RECORDED participation is validated, at insert. VOIDED rows are
history and must remain valid after the underlying relationships end.
Because VOIDED is terminal, no row ever transitions back into RECORDED.

These rules are the concrete form of the abstract
"discipleship_meeting_participants vs meeting context" requirement in
section 10.

## occurred_at Is Immutable

discipleship_meetings.occurred_at may not be changed after creation.

Every participant validity check is evaluated as of occurred_at, so
editing it would silently invalidate checks already performed.

Corrections use void and re-record.

## Meeting Records Are Immutable

Apart from the RECORDED → VOIDED transition, and the void metadata it
sets, the following never change after creation:

- discipleship_meetings: d_group_id, discipler_d_group_membership_id,
  lesson_id, occurred_at, recorded_by
- discipleship_meeting_participants: meeting_id, church_membership_id,
  attendance_status

VOIDED is terminal for both meetings and participants.

An incorrect outcome is corrected by voiding the meeting and recording
it again with the correct outcomes. Because
UNIQUE (meeting_id, church_membership_id) includes VOIDED rows, a voided
participant is never re-added to the same meeting.

Voiding a participant row is for a person who should not have been
listed at all. Every void is audited and remains subject to COMPLETED
protection below. Void authority is defined in RBAC_RLS_MATRIX.md.

## Progress Timestamps

started_at
= occurred_at of the earliest credited participation for that lesson

ready_at
= the point at which the required credited meeting count is reached,
  according to the authoritative progression calculation

Both are recomputed when backdated participation changes the chronology.

## Voiding Rules

When a discipleship meeting is VOIDED:

- voided_by IS NOT NULL
- voided_at IS NOT NULL

When meeting participation is VOIDED:

- voided_by IS NOT NULL
- voided_at IS NOT NULL

Voided records remain historical but do not contribute to progress or
monitoring.

## COMPLETED Is Protected

An ordinary void must not retroactively invalidate a confirmed COMPLETED
lesson. Silently un-completing a lesson could withdraw promotion
eligibility from someone who has already been promoted.

A void that would reduce credited participation below
required_meetings for a COMPLETED lesson must be REJECTED.

Voiding an uncredited (ABSENT or EXCUSED) participation never affects
progress, so it is never rejected on these grounds. A lesson whose
credited count exceeds required_meetings may lose the surplus to a void
without rejection.

Correcting such a case requires the explicit controlled operation
reopen_lesson_completion() first. It is Coordinator-only for the MVP and
is audited.

For progress that is not COMPLETED:

- READY_FOR_COMPLETION may recompute back to IN_PROGRESS when credited participation falls below the requirement.
- Backdated credited participation may recompute progress chronology.

## reopen_lesson_completion()

Reopening never cascades. It is permitted only when it cannot invalidate
anything downstream.

Preconditions, all required, otherwise reject:

1. The caller holds an active COORDINATOR role on an ACTIVE membership
   in the lesson's church.
2. The target progress row exists and status = COMPLETED.
3. No lesson of the same curriculum with a higher lesson_number is
   COMPLETED for this church_membership_id.
4. No ministry_role_transitions row exists for this
   church_membership_id with to_responsibility = DISCIPLER.

Precondition 4 is not redundant. Precondition 3 already blocks lessons 1
through 11 for a fully completed Disciple, but the final lesson has no
higher lesson, so without 4 an already-promoted person's last lesson
could be un-completed.

Resulting state, derived from currently credited participation:

credited count >= required_meetings  → READY_FOR_COMPLETION, ready_at retained
0 < credited count < required        → IN_PROGRESS, ready_at NULL
credited count = 0                   → NOT_STARTED, ready_at NULL

In the normal case the void has not happened yet, so the result is
READY_FOR_COMPLETION. The other rows exist for determinism.

Also:

completed_at → NULL
confirmed_by → NULL
started_at   → unchanged
updated_at   → now()

An audit_events row records the action together with the prior
completed_at and confirmed_by, so the original confirmation remains
recoverable.

Promotion eligibility is derived from all lessons of the active
curriculum being COMPLETED, so reopening makes eligibility false
immediately. Precondition 4 guarantees no existing promotion is ever
invalidated.

Sequential progression stays consistent, because precondition 3
guarantees no later lesson is COMPLETED.

Ordering: reopen, then void, then normal recomputation. After reopening
the lesson is no longer COMPLETED, so the void rejection above no longer
applies.

Out of scope: historical correction of an early lesson for someone with
later completed lessons or an existing promotion. That is an exceptional
correction workflow and is not part of the MVP.

---

# 5. Promotion

## Rules

DISCIPLE → DISCIPLER requires:

- every lesson of the church's ACTIVE curriculum COMPLETED
- Coordinator authorization
- valid D Group context

Promotion is never automatic.

Promotion must execute transactionally:

1. Validate eligibility and authorization.
2. End any active discipler_assignment in which the promotee is the Disciple.
3. End active DISCIPLE responsibility.
4. Create DISCIPLER responsibility in the same D Group.
5. Record ministry_role_transitions.
6. Record audit information.

Either every operation succeeds or none are committed.

Step 2 exists because the promotee is normally the disciple side of an
active discipler assignment. Without it, that assignment would survive
while pointing at an ended D Group responsibility.

The promotee's follow-ups and attention conditions as subject are scoped
to church_membership_id and are deliberately left untouched.

---

# 6. Automated Monitoring

## MVP Conditions

Monitoring sources are role-specific (ADR-009). Each subject has exactly
one absence-condition stream for each responsibility they hold.

| Condition | Source | Subjects | Episode | Threshold |
|---|---|---|---|---|
| CONSECUTIVE_ABSENCE | FINALIZED D Group gathering attendance | LEADER, DISCIPLER | current D Group membership episode | church_settings.consecutive_absence_threshold |
| CONSECUTIVE_MISSED_MEETINGS | discipleship meeting participant outcomes | DISCIPLE | current discipler assignment | church_settings.consecutive_missed_meeting_threshold |

Default threshold for both: 3.

Real-world meaning:

- D Group gathering attendance is the participation of ministry workers
  and group members in the D Group gathering context.
- Discipleship meeting attendance is the participation and consistency
  of Disciples in their lesson-based discipleship meetings.

Gathering attendance never creates a CONSECUTIVE_ABSENCE condition for a
DISCIPLE responsibility. This keeps a Disciple to a single
absence-condition stream, driven by the concept that actually measures
their discipleship.

## Rules Common to Both Conditions

- Monitoring is evaluated server-side by controlled operations.
- Duplicate active conditions must not be created.
- Returning to attendance resolves the active condition.
- A later absence episode creates a new condition instead of reopening the previous one.
- Ending an episode resolves the ACTIVE condition belonging to it and starts a fresh streak.
- Corrections trigger recalculation.
- Monitoring operations must be idempotent.

## Gathering-Based Monitoring (CONSECUTIVE_ABSENCE)

- Considers FINALIZED gatherings only.
- Ignores DRAFT gatherings.
- Ignores CANCELLED gatherings.
- Uses chronological gathering time.
- Considers only gatherings at which the member held LEADER or DISCIPLER
  responsibility in that D Group at starts_at.
- Only ABSENT contributes to the unexplained absence streak.

Recalculation triggers:

- finalize_gathering()
- correct_finalized_attendance()
- the end of the member's LEADER or DISCIPLER D Group membership episode

## Meeting-Based Monitoring (CONSECUTIVE_MISSED_MEETINGS)

- Considers RECORDED participant rows in RECORDED meetings only.
- VOIDED meetings and VOIDED participants are ignored.
- Uses chronological meeting time, (occurred_at, meeting id).
- Considers only meetings held under the Disciple's current discipler
  assignment: meetings whose discipler_d_group_membership_id is that
  assignment's Discipler and whose occurred_at falls within the
  assignment period.
- Only ABSENT contributes to the streak. PRESENT, LATE and EXCUSED break it.
- The streak runs across lesson boundaries. Completing a lesson does not
  reset it.

Recalculation triggers:

- record_discipleship_meeting()
- void_discipleship_meeting()
- void_meeting_participant()
- reassign_discipler()
- transfer_disciple()
- promote_disciple_to_discipler()

## Episodes

Gathering-based monitoring is scoped to a D Group membership episode.
Meeting-based monitoring is scoped to a discipler assignment.

Both scopes exist for the same reason: a follow-up is assigned within a
specific ministry context, and carrying a streak across that boundary
would raise a case against a Leader or Discipler who never saw those
absences.

Any operation that ends an episode must, in the same transaction:

- resolve any ACTIVE attention condition belonging to that episode,
  setting resolved_at
- recompute the streak for the new episode, where one begins

For Disciples, the discipler assignment ends on Discipler reassignment,
D Group transfer and promotion. transfer_disciple() therefore resolves
an ACTIVE CONSECUTIVE_MISSED_MEETINGS condition as part of ending the
assignment. The new assignment's streak begins from that assignment's
own meetings. It never carries the previous streak forward.

Resolving the condition does not close its follow-up. The care case
remains open under the rules in section 7.

A later episode may produce a new condition and therefore a new
follow-up, which is why the uniqueness rule below stays keyed on
condition_type alone.

## Partial Unique Index

Prevent equivalent duplicate ACTIVE attention conditions for the same member/context:

UNIQUE (church_membership_id, condition_type) WHERE status = 'ACTIVE'

This makes idempotency structural rather than dependent on function logic.

d_group_id is deliberately NOT part of this index. A person cannot be in
two simultaneous episodes of the same condition type, and adding
d_group_id would permit two concurrent ACTIVE conditions of one type for
one person. Ending an episode resolves the old condition instead, which
is what keeps the index correct.

The index is keyed per condition_type, so a person who holds both a
monitored ministry responsibility and a DISCIPLE responsibility may hold
one ACTIVE condition of each type. Each belongs to a different
responsibility.

---

# 7. Follow-ups

## Rules

Monitoring covers LEADER, DISCIPLER and DISCIPLE responsibilities, from
role-specific sources defined in section 6. LEADER and DISCIPLER
subjects reach the chain through CONSECUTIVE_ABSENCE; DISCIPLE subjects
reach it through CONSECUTIVE_MISSED_MEETINGS.

When an attention condition requires care, assign responsibility using
the escalation chain, evaluated on distinct people:

Subject is DISCIPLE
1. active primary Discipler
2. otherwise D Group Leader
3. otherwise Coordinator

Subject is DISCIPLER
1. D Group Leader
2. otherwise Coordinator

Subject is LEADER
1. Coordinator

A follow-up is never assigned to its own subject. Where one person holds
several responsibilities, the chain continues until a different person
is reached.

The chain terminates at Coordinator, which is why the church must
preserve at least one active COORDINATOR.

## D Group Context on Conditions and Follow-ups

attention_conditions.d_group_id and follow_ups.d_group_id are nullable in
the schema but are always populated by MVP monitoring, because both MVP
conditions are derived from a specific D Group: CONSECUTIVE_ABSENCE from
the gathering's D Group, CONSECUTIVE_MISSED_MEETINGS from the meeting's
d_group_id.

Leader scoping depends on these columns, so a NULL would make a case
visible only to the Coordinator.

Nullability exists for future condition types that are not D Group
derived. Do not create MVP rows with a NULL d_group_id.

## Automatic Coordinator Routing

Where the chain falls through to Coordinator and the church has more
than one, automatic routing selects the active Coordinator whose active
church_role_assignment has the earliest started_at, tie-broken by a
stable identifier.

This is a deterministic selection rule for automatic routing only. It
does not create a PRIMARY_COORDINATOR role and requires no ERD field.

A follow-up may afterwards be reassigned through reassign_follow_up().

Round-robin and load-balanced assignment are out of MVP scope.

assignee_church_membership_id records the responsible person at
church-membership level. It is a responsibility field, not an actor
field.

Lifecycle:

REQUIRED → IN_PROGRESS → RESOLVED

The first actual follow-up action moves REQUIRED to IN_PROGRESS.

Resolving a follow-up does not automatically resolve its underlying attention condition.

The reverse also holds. When monitoring resolves the attention condition
because attendance or meetings resumed, the follow-up is NOT auto-closed. The human
care obligation remains until someone resolves it deliberately, normally
with resolution_type CONDITION_CORRECTED.

Queries and UI should distinguish:

- open follow-up with an ACTIVE condition
- open follow-up whose condition is already RESOLVED

Follow-up reassignment must be deliberate and auditable. Reassignment is
recorded through audit_events rather than additional columns.

## Episode Identity and Deduplication

An attention_condition represents one absence episode. A follow-up is
the care case for exactly one episode.

attention_condition_id is NOT NULL.

UNIQUE (attention_condition_id)

One detected condition therefore produces at most one follow-up.
Retrying creation for the same condition conflicts rather than creating
a second case, which is what makes monitoring idempotent.

A new episode creates a new condition and may create a new follow-up
even while an earlier follow-up remains unresolved. A person may
consequently have several simultaneously open follow-ups, one per
episode. This is intended, and oversight views must be designed for it.

reason_type is retained for read and query convenience. Monitoring must
keep it consistent with the originating condition's condition_type. This
is a controlled-operation invariant, since monitoring is the only
writer.

## Resolution Check

When:

status = RESOLVED

Require:

- resolved_at IS NOT NULL
- resolved_by IS NOT NULL
- resolution_type IS NOT NULL

Supported resolution types:

- CARE_COMPLETED
- CONDITION_CORRECTED
- ADMINISTRATIVE_CORRECTION

Overdue status is derived:

status != RESOLVED AND due_at < now()

It is not stored as another status.

## Due Dates

due_at is derived from church_settings.follow_up_due_days when the
follow-up is created.

When follow_up_due_days IS NULL, generated follow-ups have due_at NULL
and can never become overdue.

The bootstrap seeds follow_up_due_days = 7 so the overdue workflow is
exercised from the first deployment rather than being silently inert.

---

# 8. Announcements

## Scope Rules

When:

scope = CHURCH

Require:

d_group_id IS NULL

When:

scope = D_GROUP

Require:

d_group_id IS NOT NULL

## Authorization

RBAC_RLS_MATRIX.md is authoritative for announcement authorization. In
summary:

- Coordinator may create CHURCH announcements.
- Coordinator may also create D_GROUP announcements as ministry oversight.
- D Group Leader may create announcements for their own D Group.
- Disciples and Disciplers may view announcements available to them.

Authorization details are not duplicated here. Consult the matrix.

---

# 9. Audit Requirements

Important historical operations should generate audit events.

Examples:

- finalized attendance correction
- discipleship meeting void
- participant void
- follow-up reassignment
- administrative correction
- privileged settings changes

Domain tables remain the primary source of truth.

audit_events supplements domain history rather than replacing it.

---

# 10. Same-Church Integrity

## Rule

A row must never relate records belonging to different churches.

This is a first-class database invariant, not an application concern. It
must not rely on Flutter or on the calling layer alone.

## Why It Is Not Automatic

Most domain tables reach their church only indirectly. For example
disciple_lesson_progress pairs a church_membership_id with a lesson_id
whose church is reachable only through curriculum_lessons, curricula and
churches. An ordinary foreign key cannot see that both sides agree.

## Enforcement

Use ordinary foreign keys wherever the relationship is naturally
expressible.

Where a same-church relationship spans tables and cannot be expressed
cleanly with ordinary foreign keys, enforce it with trusted PostgreSQL
functions and/or constraint triggers.

## Relationships That Must Reject Cross-Church Rows

- d_group_memberships vs church_memberships
- gathering_attendance vs gathering / D Group
- discipleship_meeting_participants vs meeting context
- disciple_lesson_progress vs curriculum
- discipler_assignments participants
- attention_conditions
- follow_ups, including assignee_church_membership_id

## Deferred, Not Rejected

The MVP keeps the normalized ERD hierarchy. church_id is not duplicated
across domain tables purely to enable composite foreign keys.

Future multi-church scale may justify denormalized church_id and
composite tenant keys. That infrastructure is deferred, not rejected on
principle, and is not required for the one-local-church MVP.

---

# 11. Derived Metric Definitions

Derived values must have one authoritative definition so the client,
dashboards and monitoring cannot disagree.

Two attendance domains exist and their metrics are never combined:

- gathering attendance metrics, from gathering_attendance
- discipleship meeting metrics, from discipleship_meeting_participants

Lesson progress is a third, separate concept. It consumes only credited
meeting participation.

## Eligible Attendance

Eligible gatherings for a member are FINALIZED gatherings of D Groups in
which that member held an active d_group_membership at the gathering's
starts_at.

DRAFT and CANCELLED gatherings are never eligible.

## Attendance Metrics

sessions_attended
= count of PRESENT + LATE

sessions_missed
= count of ABSENT

sessions_excused
= count of EXCUSED

attendance_percentage
= sessions_attended / (sessions_attended + sessions_missed)

EXCUSED is therefore excluded from the denominator, consistent with the
rule that an excused absence is not an unexplained absence.

Returns NULL when the denominator is 0.

last_attendance_date
= starts_at of the latest FINALIZED gathering with PRESENT or LATE

## Attendance History and Transfers

Historical attendance metrics survive D Group transfer. Attendance is
anchored to church_membership_id and is never reset or discarded.

## Consecutive Absence Streak

Applies to LEADER and DISCIPLER responsibilities only.

Walk eligible gatherings at which the member held LEADER or DISCIPLER
responsibility, in descending (starts_at, id) order. Count leading
ABSENT records. Stop at the first PRESENT, LATE or EXCUSED.

Consecutive absence monitoring is scoped to the CURRENT D Group
membership episode.

Ending that episode therefore resets the current consecutive-absence
streak. Historical attendance itself is not reset.

The reason is that a follow-up is assigned within a D Group context.
Carrying a streak across an episode boundary would raise a case against
a Leader or Coordinator who never saw those absences.

Gathering attendance of a DISCIPLE responsibility is still recorded and
counted in the gathering attendance metrics above, but it never feeds
this streak.

## Credited Meetings

credited_meetings(member, lesson)
= count of credited participations for that lesson, as defined in
  section 4

The count may exceed required_meetings while the lesson is
READY_FOR_COMPLETION. It is not clamped.

meeting_ordinal
= position of a credited participation among that lesson's credited
  participations, ordered by (occurred_at, meeting id). Uncredited rows
  have no ordinal.

## Meeting Consistency Metrics

Computed over RECORDED participant rows in RECORDED meetings.

meetings_attended
= count of PRESENT + LATE

meetups_missed
= count of ABSENT

meetups_excused
= count of EXCUSED

meeting_consistency
= meetings_attended / (meetings_attended + meetups_missed)

EXCUSED is excluded from the denominator, matching the gathering
attendance definition. Returns NULL when the denominator is 0.

last_meeting_date
= occurred_at of the latest credited participation

Oversight views may show the time since last_meeting_date. It is
computed at read time and never stored.

Historical meeting metrics survive D Group transfer and Discipler
reassignment, because participation is anchored to church_membership_id.

## Consecutive Missed-Meeting Streak

Applies to DISCIPLE responsibilities only.

Walk RECORDED participant rows in RECORDED meetings under the Disciple's
CURRENT discipler assignment, in descending (occurred_at, meeting id)
order. Count leading ABSENT outcomes. Stop at the first PRESENT, LATE or
EXCUSED.

Ending the discipler assignment resets the streak. Historical meeting
outcomes are not reset.

The streak only reflects meetups that were recorded. A Discipler and
Disciple who stop meeting and record nothing produce no streak; that
situation is visible through last_meeting_date. An automated inactivity
condition is future scope (ADR-009).

---

# 12. Enforcement Strategy

DiscipleTrack uses multiple enforcement layers.

## Foreign Keys

Protect structural relationships.

## UNIQUE Constraints

Protect simple uniqueness rules.

## CHECK Constraints

Protect valid row-level states.

## Partial Unique Indexes

Protect active-state uniqueness.

Examples:

- one active Leader
- one active Discipler assignment
- one active attention condition

## Database Functions / Transactions

Protect multi-table business invariants.

Examples:

- transfer Disciple
- reassign Discipler
- finalize attendance
- cancel gathering
- correct finalized attendance
- record discipleship meeting, held or missed
- void discipleship meeting or participant
- confirm lesson
- reopen lesson completion
- promote Disciple
- resolve/recalculate monitoring conditions
- same-church validation where ordinary foreign keys cannot express it

## Row Level Security

Controls who may read or modify data.

Scoping predicates differ per domain and are defined in
RBAC_RLS_MATRIX.md section 2a. There is no universal "own D Group" join.

RLS does not replace business constraints.

## Deletion

No domain table has a client-reachable DELETE path in the MVP.

Every table that can become obsolete carries a lifecycle state instead:
ended_at, archived_at, cancelled_at, voided_at, resolved_at or a status
column.

Hard deletion is reserved for operator-level data removal, for example
honouring a deletion request, and is performed as an administrative task
outside the application rather than through a documented operation.

## Derived Queries

Used for information that should not be redundantly stored.

Examples:

- attendance percentage
- consecutive absence count
- lesson meeting count
- meeting consistency
- consecutive missed-meeting count
- held or missed meetup
- overall discipleship percentage
- promotion eligibility
- overdue follow-up state

## Flutter Validation

Flutter should provide immediate UX validation.

However, Flutter must never be the only enforcement layer for critical business rules.

---

# Engineering Principle

The database must protect important business invariants independently of the client.

Flutter controls the user experience.

PostgreSQL protects data integrity.

Supabase RLS protects authorization.

Controlled database operations protect complex state transitions.