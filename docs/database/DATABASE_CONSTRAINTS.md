# DiscipleTrack — Database Constraints

## Purpose

This document defines the important database invariants for the DiscipleTrack MVP.

The ERD defines the data structure.

This document defines the rules PostgreSQL must protect so invalid business states cannot be created even if the Flutter client contains a bug.

Revision 2026-10-02: lesson content delivery (ADR-010, section 0); explicit lesson completion independent of a fixed meeting count, with one open numeric rule (ADR-011, section 4); Active Discipleships and the missed-meeting wording (section 11).

Revision 2026-10-05: D Group gatherings and gathering attendance removed from the MVP (ADR-014): section 3 withdrawn and reduced to a deprecated-schema note; gathering clauses removed from section 1 (last-Coordinator reasons), section 2 (Temporal Integrity rationale, D Group Lifecycle), section 7, sections 9 and 10 (examples), section 11 (gathering metrics) and section 12 (function and derived lists). Section 0: `consecutive_absence_threshold` redefined, `consecutive_missed_meeting_threshold` dormant. Section 6: one condition, CONSECUTIVE_ABSENCE, from explicitly recorded ABSENT discipleship meeting outcomes, one threshold; the missed-meeting condition is withdrawn. Section 4: outcome table column renamed, "Held and Missed Meetups" withdrawn and replaced (resolves the all-EXCUSED contradiction). Discipler eligibility after confirmed Lesson 5 and concurrent DISCIPLE and DISCIPLER responsibilities (ADR-012): section 2 Rules and Responsibility Combinations, section 4 eligibility, self-credit rationale and reopen precondition 4, section 5 rewritten as Discipler Appointment, section 6 triggers and episodes, section 11 Active Discipleships and Discipler eligibility. Percentages removed from section 11 and 12 (decision 8); "lessons completed this month" recorded as a candidate, non-governing metric (decision 9).

Revision 2026-10-05 (ADR-015): the Discipler marks a lesson completed in one step, with no Leader confirmation. Section 4: "Lesson Submission" replaced by "Lesson Completion" (complete_lesson(), column reuse, undo_lesson_completion() and its window); Progress State Check and Progress Timestamps notes; the READY_FOR_COMPLETION void rule dormant; reopen_lesson_completion() returns to IN_PROGRESS or NOT_STARTED. Sections 5, 11 and 12: "confirmed COMPLETED" wording and the operation list.

Revision 2026-10-06 (ADR-016): a completion is locked once legitimate progress exists in a later lesson (a recorded later meeting or a later completed lesson). Section 4: Lesson Completion's closing paragraph, COMPLETED Is Protected (correction path), reopen_lesson_completion() (database-level recovery only, no MVP action; precondition 3 no longer tells the Coordinator to void later meetings first; Ordering replaced; Out of scope widened). Undo is the normal correction; void corrects only erroneous records and is never a way to unlock a completion.

Revision 2026-10-06 (ADR-017, N1 closed): there is no minimum number of meetings; meeting count never determines completion. Section 0 (required_meetings note), section 4 (Lesson Meeting Policy withdrawn and replaced by No Meeting Minimum; Lesson Completion preconditions; Progress Timestamps; COMPLETED Is Protected: a void never changes a COMPLETED lesson and is no longer refused to protect it), section 11 (count presentation).

Revision 2026-10-05 (user decision, ninth): the curriculum has ten lessons, not twelve. Section 0: ten lesson rows and postconditions, and the Slice 5 migration's replacement of the bootstrap functions; examples in sections 4, 5, 11 and 12.

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

Implementation: private.bootstrap_church() in Migration 004, in the
`private` schema so PostgREST never serves it, with EXECUTE revoked from
anon and authenticated. private.assert_bootstrap_postconditions() checks
the postconditions below and is the bootstrap test. Locally,
supabase/seed.sql creates the initial auth user and calls the function
during `supabase db reset`; on a hosted project tool/bootstrap_church.ps1
does the same over the admin API and psql.

## Inputs

- church_id (UUID, supplied by the caller)
- church name
- the initial trusted user's Supabase Auth user id
- optionally: join code, curriculum name, the ten lesson titles

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
6. curriculum_lessons — ten rows, lesson_number 1 through 10, required_meetings = 4
7. audit_events — CHURCH_BOOTSTRAPPED

Lesson rows are identification and ordering only. Lesson content is not
part of bootstrap: it is published separately by trusted tooling under
ADR-010, which supersedes the earlier statement that DiscipleTrack does
not store or deliver lesson content.

The two thresholds in step 2 (ADR-014 decisions 12 and 13):

- consecutive_absence_threshold (Migration 001) is retained and
  redefined: the number of consecutive explicitly recorded ABSENT
  discipleship meeting outcomes, within the current discipler
  assignment, that raises CONSECUTIVE_ABSENCE for a Disciple (section
  6). It has no structural tie to the deprecated gathering tables.
- consecutive_missed_meeting_threshold (Migration 004) is dormant. It
  has no owner and no rule reads it; its database comment still names
  the withdrawn missed-meeting condition. It is still inserted by
  private.bootstrap_church() and asserted equal to 3 by
  private.assert_bootstrap_postconditions(). Dropping it requires
  replacing both functions in the same forward migration and updating
  test/integration/bootstrap_test.dart. It is not dropped now.

required_meetings = 4 is the value bootstrap seeds (Migration 004). It
drives nothing (ADR-011, ADR-017): no function reads it and clients are
denied it. It is legacy data, not a completion rule.

The curriculum has ten lessons (user decision 2026-10-05). Migration
004 seeded and asserted twelve; it is applied and unchanged. The Slice 5
migration (20261002000001_discipleship_meeting_progress.sql, section 11)
replaces private.bootstrap_church() and
private.assert_bootstrap_postconditions() with the lesson count changed
to ten and nothing else, so required_meetings is still seeded as 4. It
also removes Lessons 11 and 12 from existing ACTIVE curricula only when
no meeting or progress row references them; otherwise the migration
stops.

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
- church_settings present, both thresholds 3 (one of them dormant, see
  above), due days 7
- the initial user holds an ACTIVE membership
- that membership has an active ADMIN and an active COORDINATOR role
- exactly one ACTIVE curriculum for the church
- exactly ten lessons, numbered 1 to 10, each with required_meetings = 4
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
- churches.join_code must have sufficient entropy to make guessing impractical. The alphabet and length are fixed under Join Code Format below.
- Joining through a church code must never automatically grant ADMIN or COORDINATOR.
- Only ACTIVE church members may receive active church roles.
- The same church role cannot be active twice for the same member.
- Historical role assignments must be ended using ended_at, not deleted.
- The church must preserve at least one active COORDINATOR, because follow-up escalation terminates there. (The former second reason, the Coordinator as fallback gathering attendance recorder, is withdrawn with gatherings, ADR-014.)

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
discipleship meeting history, discipleship progress and care history
remain continuous.

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

- discipleship meetings and their recorded outcomes, lesson progress
  and resolved care records remain as history
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
- Join-code lookup and join requests must be rate limited. The mechanism is defined under Join Code Format and Rate Limiting below; the requirement is not optional.

## Join Code Format and Rate Limiting

Format:

^[A-HJ-NP-Z2-9]{10}$

Ten characters from a 32-symbol alphabet that excludes I, O, 0 and 1,
so a code can be read aloud and typed without ambiguity. 32^10 is about
1.1e15 possibilities. Enforced by CHECK on churches.join_code. Codes are
generated by private.generate_join_code() from a cryptographic source;
a code supplied to bootstrap or regeneration is validated against the
same pattern.

Normalisation: lookup and request uppercase the input and strip
whitespace and hyphens, and nothing else.

join_code is never readable by a client. Column-level SELECT on
churches for authenticated covers id, name and status only; anon has
no grant. The code is compared inside the controlled operations.

Rate limit, per authenticated user, recorded in
private.join_code_attempts:

- 5 attempts of any kind per 10 minutes
- 3 join requests per hour

A refused call raises PT429 before anything is written. Attempts are
counted from committed rows, so a guessable failure (a code that
matches nothing) is RETURNED as an empty result or an INVALID_CODE
outcome rather than raised; raising would roll back the attempt row and
give unlimited guesses. The log keys on the auth user id without a
foreign key, so it never blocks account deletion, and rows older than
24 hours are pruned on each call.

## Membership Request, Approval and Rejection

request_join_church(church_id, join_code) requires the code to resolve
to that ACTIVE church. The code is the shared secret; the id only
confirms the church the person saw and accepted, so a leaked church id
cannot bypass the code. Outcomes are returned, not raised: REQUESTED,
ALREADY_PENDING, ALREADY_ACTIVE, NOT_REQUESTABLE (an INACTIVE,
TRANSFERRED or ARCHIVED row exists; only controlled reactivation or
reinstatement may leave those states) and INVALID_CODE. Nothing but a
PENDING membership row is ever written: no role, no D Group
responsibility.

approve_church_membership() and reject_church_membership() require the
caller to hold an active ADMIN or COORDINATOR role on an ACTIVE
membership in the target's church (RBAC sections 1a and 2). The target
must be PENDING. Both are audited as MEMBERSHIP_APPROVED and
MEMBERSHIP_REJECTED.

Field semantics:

- created_at is the request time.
- joined_at is the first time the membership became ACTIVE and is never
  overwritten afterwards (coalesce on approval and on any later
  reactivation).
- approved_by and approved_at are written only by approval. They stay
  NULL on rejection and on the bootstrap membership, which is
  provisioned rather than approved.

Rejection is PENDING → ARCHIVED per the lifecycle above. ARCHIVED →
ACTIVE reinstatement is a separate controlled operation that belongs to
the member-management workflow and is not part of the join slice. A
rejected applicant therefore cannot request again from the app.

## First-Entry Onboarding

church_memberships.onboarding_completed_at records the one-time
first-entry welcome. It is NULL until the member, with an ACTIVE
membership, completes the welcome through complete_onboarding(), which
is idempotent and keeps the original timestamp. It is server-backed so
a reinstall or another device never replays the welcome, and it is not
reset by reactivation. Clients have no direct write path to it.

## PENDING Visibility

A PENDING member may read their own membership row and the id, name and
status of the church they requested. That is the minimum onboarding
state (RBAC section 1a). No other church data is visible until ACTIVE.

---

# 2. D Groups and Assignments

## Rules

- A D Group may have only one active LEADER.
- A person may actively lead only one D Group.
- A DISCIPLE may belong to only one active D Group.
- A person cannot simultaneously have active DISCIPLE and LEADER responsibilities.
- A person MAY simultaneously hold active DISCIPLE and DISCIPLER responsibilities, in the same D Group (ADR-012; enforced from Slice 6; until then Migration 006 still refuses DISCIPLE with DISCIPLER).
- The two sides of a discipler assignment belong to different church memberships: nobody is paired with themselves (ADR-012; enforced from Slice 6).
- Whether reciprocal pairing (A disciples B while B disciples A) is allowed is open (D7). It is not decided here.
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

This matters because discipleship meeting participant validity is
resolved as of discipleship_meetings.occurred_at (section 4,
Participant Validity), and monitoring episodes are bounded by the
discipler assignment period (section 6). Overlapping periods would make
"did this person hold this responsibility, or this assignment, at time
T" undecidable, which in turn makes participant validity and the
monitoring episode ambiguous. (The earlier rationale anchored on
gathering starts_at and the gathering finalization check, withdrawn
with gatherings, ADR-014.)

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

INACTIVE: existing data is preserved and remains visible to authorized
roles.

Note (ADR-014): INACTIVE previously "prevents creation of new
gatherings". With gatherings removed that clause is withdrawn, and this
section states no other restriction for INACTIVE. Migration 006 already
refuses assign_d_group_leader(), invite_to_d_group(),
respond_to_d_group_invitation() and add_self_as_discipler() for a group
that is not ACTIVE (d_group_not_active), but that behaviour is not
documented as a rule here, and whether an INACTIVE group may record
discipleship meetings or change pairings is not defined. This is an open
gap, not a decision; no replacement rule is invented here.

ARCHIVED must be REJECTED while any active DISCIPLE d_group_membership
remains in the group. (The second condition, "any DRAFT gathering
belonging to the group", is withdrawn with gatherings, ADR-014.)

The Coordinator must explicitly transfer or unassign disciples first.
Disciples are never
automatically transferred, because moving a person between D Groups is a
ministry decision that must stay explicit and auditable.

On successful archival, in one transaction:

- end remaining active LEADER and DISCIPLER responsibilities
- end remaining active discipler assignments in the group
- set archived_at
- write an audit event

Open follow-ups are left untouched. They are church-scoped care cases
and remain the assignee's responsibility.

## Responsibility Combinations

Added in Vertical Slice 3 (Migration 006), enforced by the
d_group_memberships integrity trigger for every writer:

- At any moment, all of a person's responsibilities are in one D Group.
  A person cannot be a Discipler in one group and a Disciple or Leader
  in another.
- DISCIPLE excludes LEADER, for overlapping periods, not only active
  rows.
- DISCIPLE with DISCIPLER in the same group is allowed (ADR-012;
  enforced from Slice 6; until then Migration 006 still refuses
  DISCIPLE with DISCIPLER through d_group_membership_disciple_conflict).
- LEADER with DISCIPLER in the same group is allowed.
- A d_group_memberships row and its D Group belong to the same church.
- One active row per person, group and responsibility (partial unique
  index WHERE ended_at IS NULL).

"Unplaced" means an ACTIVE member with no active D Group
responsibility.

## Leader Presence

Every D Group has an active LEADER from the moment it exists.
create_d_group() creates the group and its LEADER row in one
transaction, assign_d_group_leader() replaces the Leader in one
transaction, and end_d_group_membership() refuses LEADER rows. A
replaced Leader keeps any DISCIPLER row they hold in the group;
otherwise they become unplaced.

The Leader of a new group must be unplaced. A replacement Leader must
be unplaced or hold nothing but a DISCIPLER row in that same group.

Departure of the Leader's membership from ACTIVE is not handled yet;
see section 1, Effects of Leaving ACTIVE.

## Group Names

d_groups.name is not blank and is unique within the church ignoring
case and surrounding spaces, among groups that are not ARCHIVED
(partial unique index on (church_id, lower(trim(name)))).

## Placement by Invitation

DISCIPLER and DISCIPLE responsibilities are created only by an
accepted invitation (d_group_invitations), or for a Leader adding
themselves as Discipler, by add_self_as_discipler().

- The invitee is an unplaced ACTIVE member of the group's church with
  no PENDING invitation. Both conditions are re-checked on acceptance.
- A member holds at most one PENDING invitation (partial unique index).
- An invitation is answered once. Status moves PENDING → ACCEPTED,
  DECLINED, WITHDRAWN or EXPIRED and never back. The state CHECK ties
  responded_at and resulting_d_group_membership_id to the status.
- An invitation expires 14 days after it was sent. Expiry is lazy: a
  PENDING row past expires_at is treated as EXPIRED by every operation
  and read, and is marked EXPIRED (responded_at = expires_at) by the
  next successful write that touches it. An operation that refuses an
  expired invitation cannot persist the mark, because the refusal rolls
  the transaction back.
- An invitation and its invitee belong to the same church (integrity
  trigger).

## Discipler Assignments

In addition to Responsibility Correctness above: the two sides of an
assignment differ (CHECK), and a Disciple's assignment periods never
overlap (integrity trigger).

The CHECK (discipler_assignments_distinct_sides_check, Migration 006)
compares d_group_memberships row ids only. Once DISCIPLE and DISCIPLER
may coexist, it no longer prevents a person from being paired with
themselves, so the two sides must also belong to different church
memberships (ADR-012; enforced from Slice 6 in the assignment
integrity check and set_discipler()). Reciprocal pairing is open (D7). Removing a Discipler or Disciple from the
group ends every active assignment on either side in the same
transaction.

## Controlled Operations

Use transactional database operations for:

- D Group transfer
- Discipler reassignment
- responsibility changes
- D Group lifecycle changes

A transfer must succeed completely or fail completely.

Implemented in Migration 006: create_d_group(),
assign_d_group_leader(), invite_to_d_group(),
withdraw_d_group_invitation(), respond_to_d_group_invitation(),
add_self_as_discipler(), end_d_group_membership() and set_discipler().
Each locks the affected person's church_memberships row before
changing their D Group rows, so concurrent operations on one person
serialise. Transfer between groups is not built; the stopgap is
removal followed by a new invitation, which keeps history.

---

# 3. Gatherings and Attendance

Withdrawn (ADR-014). D Group gatherings and gathering attendance are
removed from the MVP entirely. Attendance exists only as the outcome of
a discipleship meeting, recorded through Record Meeting; its rules are
in section 4 (Attendance Outcome and Credit) and its monitoring in
section 6. The section number is kept so references stay stable.

## Deprecated Schema

The applied migrations still contain the gathering objects. They are
deprecated: no MVP owner (ADR-014); retained in applied migrations; to
be locked down by forward migration. No RPC, policy, seed row or
Flutter code reads or writes them.

Objects:

- tables d_group_gatherings and gathering_attendance (Migration 001),
  with their CHECK and UNIQUE constraints
- enum gathering_status (DRAFT, FINALIZED, CANCELLED) (Migration 001)
- set_updated_at triggers on both tables (Migration 002)

attendance_status is not deprecated: discipleship meeting participants
use all four values (ADR-014 decision 11).

Security issue: both tables have RLS enabled with zero policies, and
they still hold Supabase's default grants (ALL to anon and
authenticated), because no later migration narrowed them (Migration
006 narrowed grants only on the ministry tables). RLS deny-by-default
is their only protection; a single permissive policy added by mistake
would open them.

Lifecycle (ADR-014 decision 14), safest first:

1. Lock down at the earliest approved migration step, expected to be
   the Slice 5 migration's grant step: revoke all privileges on both
   tables from anon and authenticated, keep RLS enabled, add no policy.
   Security-only; removes no object and no data; reversible.
2. Deprecate: governing documents mark the objects deprecated; a
   forward migration may also update their database comments.
3. Drop, only after a separate explicit decision: gathering_attendance,
   then d_group_gatherings (their triggers go with them), then
   gathering_status, in a forward migration that first verifies both
   tables are empty and refuses otherwise.

The former rules of this section (attendance eligibility at
starts_at, finalization, No Self-Attendance, Single Authorized
Recorder, gathering ordering, Gathering Lifecycle and Gathering State
Check) describe no MVP behaviour. The CHECK and UNIQUE constraints
that implement some of them remain in Migration 001 until the objects
are dropped.

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
- A discipleship meeting record reports a meetup after the fact, with each listed Disciple's recorded outcome. DiscipleTrack does not schedule meetings. (The words "held or missed" are withdrawn, ADR-014 decision 8.)
- Every participant row carries an explicit attendance_status. There is no default.
- Only credited participation counts toward progress. See Attendance Outcome and Credit below.
- An absence never increments progress.
- One Disciple may appear only once in a meeting.
- A Disciple's eligible lesson is the lowest-numbered lesson of the ACTIVE curriculum that is not COMPLETED. Meetings are recorded only against it, so a meeting for an already COMPLETED lesson is refused (Slice 5 decision 2).
- The first credited participation moves the lesson into IN_PROGRESS.
- No meeting count moves a lesson to COMPLETED (ADR-011). A lesson becomes COMPLETED only when it is explicitly marked completed (ADR-015). See Lesson Completion below.
- Recording a meeting, of any ordinal, never completes a lesson.
- READY_FOR_COMPLETION remains in the lesson_progress_status enum (Migration 001) but no operation enters it (ADR-015). There is no maximum number of meetings per lesson.
- The Disciple's current assigned Discipler marks the lesson completed. The Leader of the Disciple's current D Group and the Coordinator may mark it completed as fallback, for example where the Disciple has no active Discipler. There is no Leader confirmation (ADR-015). Completion is attributable through confirmed_by and submitted_by and is audited.
- Progress belongs to church_membership_id and survives D Group transfers and Discipler reassignment.
- Curriculum progress is derived, not stored, and is expressed as a count of COMPLETED lessons against the active curriculum's lesson total ("5 of 10 completed"), never as a percentage (decision 8).
- COMPLETED of Lesson 5 of the church's ACTIVE curriculum (marked by the Discipler, ADR-015) creates Discipler eligibility. IN_PROGRESS does not count. Eligibility is derived, never stored and never automatic. The eligibility lesson number comes from `private.discipler_eligibility_lesson()` (D2, ADR-012). This replaces eligibility at completion of every lesson.
- Eligibility is not appointment. Discipler appointment is a Coordinator operation (section 5).

## One Active Curriculum

Eligibility and progression both depend on "the active curriculum" being
a singular, well-defined thing.

Partial unique index on curricula:

UNIQUE (church_id) WHERE status = 'ACTIVE'

PostgreSQL expresses this as a partial unique index rather than a table
constraint, because table-level UNIQUE constraints cannot carry a WHERE
clause.

The literal number 10 is seed data in section 0, not a rule. No rule
elsewhere may hard-code a lesson count.

## Unique Constraints

- curriculum_lessons(curriculum_id, lesson_number)
- discipleship_meeting_participants(meeting_id, church_membership_id)
- disciple_lesson_progress(church_membership_id, lesson_id)

## Check Constraint

required_meetings > 0 (Migration 001; legacy, unread, see No Meeting
Minimum)

## No Meeting Minimum

ADR-017 (2026-10-06) closes N1: there is no minimum number of meetings.
Meeting count does not determine lesson completion. The authorized
Discipler decides when the Disciple has completed the lesson, based on
the actual discipleship process (Lesson Completion).

- A lesson never completes, and never advances, because of a count.
- A lesson is never kept from completion because of a count: zero, one
  or any number of credited participations.
- Outcomes and counts remain factual history, displayed and summarised,
  and usable by monitoring rules where separately approved.
- No rule reads required_meetings, and no client reads it at all. No
  rule defines a maximum.

As built: Migration 011 (20261006000004) drops the placeholder
`private.lesson_meeting_policy()` (formerly submission_minimum 1,
recommended_meetings NULL) and every rule that read it. The former
Lesson Meeting Policy section, its models A, B and C and its
submission_minimum and recommended_meetings values are withdrawn.

## Attendance Outcome and Credit

discipleship_meeting_participants.status is record validity only:
RECORDED or VOIDED. It was named COUNTED in ERD v2 and Migration 001;
the rename to RECORDED is applied by a new migration.

discipleship_meeting_participants.attendance_status is the outcome:

| Outcome | Progress | Consecutive recorded absence streak |
|---|---|---|
| PRESENT | credited | breaks |
| LATE | credited | breaks |
| ABSENT | not credited | increments / continues |
| EXCUSED | not credited | breaks; not an absence |

The third column was "Missed-meeting streak"; it is the consecutive
recorded absence streak of section 6 (ADR-014 decision 6). The effects
are unchanged.

A participation is credited only when all three hold:

- discipleship_meetings.status = RECORDED
- discipleship_meeting_participants.status = RECORDED
- attendance_status IN (PRESENT, LATE)

"Credited" is a derived predicate, not a stored state.

## Held and Missed Meetups

Withdrawn (ADR-014 decision 8). The derived labels "held meetup" and
"missed meetup" are no longer domain terms. A meeting record shows each
listed Disciple's recorded outcome; nothing is derived about the meeting
as a whole beyond that.

This resolves a contradiction. The withdrawn definition made a RECORDED
meeting with no credited participant a "missed meetup", which included a
meeting where every outcome is EXCUSED. BUSINESS_RULES.md BR-027a and
ARCHITECTURE.md section 7 treat EXCUSED as never an absence. The rule
now is: a recorded meeting in which every outcome is EXCUSED is not a
missed meeting and not an absence. It has no credited participation and
breaks the consecutive recorded absence streak (section 6).

Absence monitoring uses only explicitly recorded ABSENT outcomes
(BR-027a). NO RECORD is not ABSENT and is not a missed meeting.

Without a scheduler, an expected participant is one the recorder lists
when recording the meetup. A meetup cancelled by agreement before it was
due is not recorded.

discipleship_meetings.occurred_at is when the meetup took place or, where
no listed Disciple attended, when it was arranged to take place.

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
progress credit, or have any outcome recorded, until an assignment
exists. This is intentional. The
remedy is to make the assignment, which is an existing Coordinator
operation.

There is no self-crediting risk here: a recorder is never a participant
in a meeting they record (explicit check from Slice 5), and nobody is
paired with themselves (ADR-012, enforced from Slice 6). The earlier
rationale, that DISCIPLE and DISCIPLER are mutually exclusive, no longer
holds once they may coexist (ADR-012).

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

## Lesson Completion

Revised 2026-10-05 (ADR-015). This section was "Lesson Submission",
followed by Leader confirmation. The confirmation step is withdrawn.

COMPLETED is entered only through the controlled operation
complete_lesson(p_membership_id, p_lesson_id), in which the caller marks the lesson completed
("Mark Lesson 4 completed"). There is no intermediate state.

Preconditions, all required, otherwise reject:

1. The caller holds completion authority for this Disciple
   (RBAC_RLS_MATRIX.md section 5): normally the Disciple's current
   assigned Discipler; the Leader of the Disciple's current D Group or
   the Coordinator as fallback.
   Refusal: not_authorized.
2. The caller is not the Disciple. Refusal: cannot_act_on_own_lesson
   (checked before authority).
3. The lesson is the Disciple's eligible (current) lesson, NOT_STARTED
   or IN_PROGRESS. Refusal: lesson_not_eligible. No meeting count is
   required (No Meeting Minimum, ADR-017); the former refusals
   lesson_not_in_progress and below_submission_minimum are withdrawn.

Effect, reusing the existing columns (no schema change):

status       → COMPLETED
completed_at → now()
confirmed_by → the caller
ready_at     → completed_at
submitted_by → the caller
started_at   → unchanged, or completed_at when no credited
               participation exists (Progress Timestamps)
updated_at   → now()

The action is audited as LESSON_COMPLETED. The next lesson in sequence
becomes the eligible lesson by derivation; the operation returns the
lesson and the next lesson.

Undoing a completion is a separate controlled operation,
undo_lesson_completion(p_membership_id, p_lesson_id). Preconditions, all
required, otherwise reject:

1. The caller is the Disciple's current assigned Discipler, the Leader
   of the Disciple's current D Group, or the Coordinator
   (RBAC_RLS_MATRIX.md section 5). Refusal: not_authorized.
2. The caller is not the Disciple. Refusal: cannot_act_on_own_lesson
   (checked before authority).
3. The target progress row has status COMPLETED, and no lesson of the
   same curriculum with a higher lesson_number is COMPLETED for this
   church_membership_id (it is the latest COMPLETED lesson). Refusals:
   lesson_not_completed, later_lesson_completed.
4. No RECORDED participant row for this church_membership_id exists in
   a RECORDED discipleship meeting for the next lesson in sequence.
   Refusal: next_lesson_started.
5. From Slice 6: reopen precondition 4 below (the eligibility lesson
   of an appointed person) applies to undo as well.

Effect: IN_PROGRESS, or NOT_STARTED when no credited participation
remains; ready_at, submitted_by, completed_at and confirmed_by → NULL;
started_at unchanged (NULL when NOT_STARTED); updated_at → now(). An
audit_events row (LESSON_COMPLETION_UNDONE) records the prior values.

After the undo window (preconditions 3 and 4) has closed, the
completion is locked by later progress (ADR-016). No MVP operation
changes it; reopen_lesson_completion() below refuses it for the same
reasons and exists only as database-level recovery.

## Progress State Check

disciple_lesson_progress fields must agree with its status:

| Status | Required fields |
|---|---|
| NOT_STARTED | started_at, ready_at, submitted_by, completed_at, confirmed_by all NULL |
| IN_PROGRESS | started_at set; the rest NULL |
| READY_FOR_COMPLETION | started_at, ready_at, submitted_by set; completed_at, confirmed_by NULL |
| COMPLETED | all five set |

Enforced by a CHECK constraint in the Slice 5 migration. The check is
unchanged by ADR-015. No operation enters READY_FOR_COMPLETION any more;
its row stays in the check because the enum value exists (Migration
001). complete_lesson() sets all five fields, so COMPLETED rows satisfy
the check without a separate submission step.

## Progress Timestamps

started_at
= occurred_at of the earliest credited participation for that lesson.
  Recomputed when backdated participation changes the chronology. A
  lesson marked completed with no credited participation gets
  started_at = completed_at (it was taken up no later than it was
  completed), because the Progress State Check requires started_at for
  COMPLETED (ADR-017). Undo and reopen recompute it.

ready_at
= for a completion, equal to completed_at (ADR-015; Lesson Completion).
  It is an action time, not derived from meetings, and is not
  recomputed by later meetings or voids.

completed_at
= when the lesson was marked completed.

submitted_by and confirmed_by
= for a completion, both the profile that marked it completed.

## Voiding Rules

When a discipleship meeting is VOIDED:

- voided_by IS NOT NULL
- voided_at IS NOT NULL

When meeting participation is VOIDED:

- voided_by IS NOT NULL
- voided_at IS NOT NULL

Voided records remain historical but do not contribute to progress or
monitoring.

As built (Migration 008, 20261006000001): void_discipleship_meeting()
sets only the meeting row VOIDED (participant rows are not modified);
void_meeting_participant() sets only that row VOIDED and refuses the
meeting's last RECORDED participant (void_meeting_instead). Neither may
void the caller's own outcome (cannot_void_own_meeting). Both recompute
the credited people's progress, never touch COMPLETED, and are audited
(DISCIPLESHIP_MEETING_VOIDED, MEETING_PARTICIPANT_VOIDED).

## COMPLETED Is Protected

An ordinary void must not retroactively invalidate a COMPLETED lesson.
Silently un-completing a lesson could withdraw Discipler eligibility
from someone who has already been appointed as a Discipler (ADR-012),
and would silently change the progress the Journey shows.

A void never changes a COMPLETED status: completion is an explicit
judgement, not a count, so recomputation never touches COMPLETED rows.

Voiding meeting history never implicitly undoes or changes an
explicitly COMPLETED lesson (ADR-017). A void on a COMPLETED lesson is
allowed under the usual void authority, whatever it leaves of the
lesson's credited participations, and the lesson stays COMPLETED with
its completion attribution. No count is preserved, because completion
does not rest on a count. The former lesson_completed_protected refusal
is withdrawn (Migration 011).

A COMPLETED lesson changes only through undo_lesson_completion() while
its window holds (Lesson Completion), or the database-only
reopen_lesson_completion() below (ADR-016). A void is only ever the
correction of an erroneous record; it is never used to unlock a
completion.

For progress that is not COMPLETED:

- READY_FOR_COMPLETION is not entered by any operation (ADR-015). With no minimum (ADR-017) there is nothing to fall below, so a row found in that state keeps it; only its started_at is refreshed.
- IN_PROGRESS returns to NOT_STARTED when no credited participation remains.
- Backdated credited participation may recompute started_at.
- No recomputation ever sets READY_FOR_COMPLETION or COMPLETED.

## reopen_lesson_completion()

A Coordinator-only, database-level recovery operation (ADR-016). It is
not an action in the MVP app: the normal correction of a recently
completed lesson is undo_lesson_completion(), and a completion is locked
once legitimate progress exists in a later lesson.

Reopening never cascades. It is permitted only when it cannot invalidate
anything downstream.

Preconditions, all required, otherwise reject:

1. The caller holds an active COORDINATOR role on an ACTIVE membership
   in the lesson's church.
2. The target progress row exists and status = COMPLETED.
3. No lesson of the same curriculum with a higher lesson_number is
   COMPLETED for this church_membership_id, and none has a RECORDED
   participant row in a RECORDED meeting for this church_membership_id,
   whatever the outcome (revised 2026-10-05, user decision). A later
   recorded meeting or a later completed lesson locks the earlier lesson
   (ADR-016). Reopening never moves, voids or deletes later history, and
   nothing voids, moves or deletes legitimate later history in order to
   reopen. Refusal reasons: later_lesson_completed,
   later_lesson_has_meetings. This keeps sequential progression intact:
   at most one lesson is ever current. These are the conditions that
   close the undo window, so reopen never applies once that window has
   closed.
4. If a ministry_role_transitions row exists for this
   church_membership_id with to_responsibility = DISCIPLER (the person
   has been appointed as a Discipler), the target lesson is not the
   eligibility lesson (Lesson 5) or an earlier lesson. Later lessons
   may be reopened, subject to preconditions 1 to 3 (ADR-012 decision
   9, N9).

Precondition 4 was previously "no such row exists", which refused every
reopen for an appointed person. Under ADR-012 an appointed person
usually continues as a Disciple through Lesson 10, so that form would
forbid correcting any of Lessons 6 to 10. The narrowed form protects
exactly what the appointment rests on: the eligibility lesson. Earlier
lessons are already covered by precondition 3 once the eligibility
lesson is COMPLETED, so precondition 4 adds the eligibility lesson
itself. Slice 5 builds the narrowed form, reading the eligibility lesson
from `private.discipler_eligibility_lesson()` (D2, decided 2026-10-05).

Resulting state (revised 2026-10-05, ADR-015). Reopening never returns
the lesson to READY_FOR_COMPLETION:

credited count > 0  → IN_PROGRESS
credited count = 0  → NOT_STARTED

A COMPLETED lesson keeps at least one credited meeting (COMPLETED Is
Protected), so the result is normally IN_PROGRESS. The lesson can then be marked completed again through
complete_lesson() once it is finished.

Also:

ready_at     → NULL
submitted_by → NULL
completed_at → NULL
confirmed_by → NULL
started_at   → unchanged (NULL when NOT_STARTED)
updated_at   → now()

An audit_events row records the action together with the prior
ready_at, submitted_by, completed_at and confirmed_by, so the original
completion remains recoverable.

Discipler eligibility is derived from COMPLETED of the
eligibility lesson (ADR-012), so reopening that lesson makes
eligibility false immediately. Precondition 4 guarantees no existing
appointment is ever invalidated: for an appointed person the
eligibility lesson cannot be reopened, and reopening a later lesson
does not affect eligibility.

Sequential progression stays consistent, because precondition 3
guarantees no later lesson is COMPLETED or has any recorded meeting, so
the reopened lesson is the only current lesson.

Correction path (ADR-016): undo the completion while its window holds;
then, if a meeting on that lesson was recorded in error, void it as a
correction of that record. After undoing (or a recovery reopen) the
lesson is no longer COMPLETED, so the void rejection above no longer
applies. Legitimate later meetings are never voided to unlock an earlier
lesson.

Out of scope (ADR-016): historical correction of a lesson once
legitimate later progress exists for the person (a recorded meeting on a
later lesson, or a later completed lesson), or of the eligibility lesson
or an earlier lesson for someone with an existing Discipler appointment.
That is an exceptional correction workflow and is not part of the MVP.

---

# 5. Discipler Appointment

Rewritten 2026-10-05 (ADR-012). This section was "Promotion", which
ended the person's DISCIPLE responsibility and their own discipler
assignment. Appointment ends neither. The table name
ministry_role_transitions is kept; a row now records the appointment.

Enforced from Slice 6. Until Slice 6's forward migration, Migration
006 refuses DISCIPLE with DISCIPLER (d_group_membership_disciple_conflict),
so no appointment can exist.

## Rules

- Eligibility is derived from COMPLETED (ADR-015) of the eligibility
  lesson (Lesson 5) of the church's ACTIVE curriculum (section 4,
  section 11). It is never stored and never changes anything by itself.
- Eligibility is not appointment. The Coordinator appoints directly.
  There is no acceptance workflow.
- Appointment is never automatic.

## Preconditions

All required, otherwise reject:

1. The caller holds an active COORDINATOR role on an ACTIVE membership
   in the target's church, and the target is not the caller's own
   membership. Self-appointment is open (D9); this precondition stands
   until D9 is decided.
2. The target church membership is ACTIVE.
3. The target holds an active DISCIPLE d_group_memberships row.
4. The target is eligible (Discipler eligibility, section 11).
5. The target holds no active DISCIPLER d_group_memberships row.

## Effects

In one transaction; either every step succeeds or none is committed:

1. Create a DISCIPLER d_group_memberships row in the same D Group as
   the target's DISCIPLE row (ADR-012 decision 3; all of a person's
   responsibilities stay in one D Group).
2. Record the appointment in ministry_role_transitions (from DISCIPLE,
   to DISCIPLER, that D Group, the approving Coordinator and time).
3. Leave the DISCIPLE row, the person's own discipler assignment and
   their lesson progress unchanged. They continue through Lesson 10
   under their own Discipler (ADR-012 decision 4).
4. Record audit information.

The appointee's follow-ups and attention conditions as subject are
scoped to church_membership_id and are untouched. Appointment is not a
monitoring episode boundary (section 6). A person who is both a
Disciple and a Discipler is monitored as a Disciple only (ADR-014).

## Open Items

Not decided here (ADR-012; owned by Slice 6):

- D2 is decided (2026-10-05): the eligibility lesson comes from
  `private.discipler_eligibility_lesson()`, not configurable.
- D5: whether appointment before eligibility is allowed as an
  exception.
- D8: whether appointment is allowed after the person's DISCIPLE
  responsibility has ended.
- D9: whether a Coordinator may appoint themselves.

---

# 6. Automated Monitoring

## MVP Condition

Revised 2026-10-05 (ADR-014). Monitoring uses only facts DiscipleTrack
explicitly records. There is one condition, from one source, with one
threshold:

| Condition | Source | Subjects | Episode | Threshold |
|---|---|---|---|---|
| CONSECUTIVE_ABSENCE | ABSENT outcomes on RECORDED participant rows of RECORDED discipleship meetings | DISCIPLE | current discipler assignment | church_settings.consecutive_absence_threshold |

Default threshold: 3 (section 0; Migration 004 asserts it). Whether the
MVP default should stay 3 is open (ADR-014 Consequences).

The enum value CONSECUTIVE_ABSENCE in attention_condition_type and
follow_up_reason (Migration 001) keeps its name and now carries this
meaning. It is not renamed, and CONSECUTIVE_MISSED_MEETINGS is not
added (ADR-014 decision 7). The user-facing label is "consecutive
recorded absences", for example "2 consecutive recorded absences".

Withdrawn (ADR-014):

- the CONSECUTIVE_ABSENCE row sourced from FINALIZED D Group gathering
  attendance for LEADER and DISCIPLER subjects, together with the
  D Group membership episode;
- the automated missed-meeting condition (planned as
  CONSECUTIVE_MISSED_MEETINGS with its own threshold). It is withdrawn,
  not deferred. church_settings.consecutive_missed_meeting_threshold is
  dormant (section 0).

Consequence: Leaders and Disciplers have no automated monitoring in the
MVP; their participation is noticed through human oversight. A person
who is both a Disciple and a Discipler (ADR-012) is monitored as a
Disciple only.

## Monitoring Rules

- Monitoring is evaluated server-side by controlled operations.
- Duplicate active conditions must not be created.
- A recorded outcome that breaks the streak (PRESENT, LATE or EXCUSED)
  resolves the active condition.
- A later absence episode creates a new condition instead of reopening the previous one.
- Ending an episode resolves the ACTIVE condition belonging to it and starts a fresh streak.
- Corrections trigger recalculation.
- Monitoring operations must be idempotent.
- No condition is ever generated from elapsed time, inactivity or the
  lack of a record (ADR-014 decisions 3 and 4).

## CONSECUTIVE_ABSENCE

- Considers RECORDED participant rows in RECORDED meetings only.
- VOIDED meetings and VOIDED participants are ignored.
- Uses chronological meeting time, (occurred_at, meeting id).
- Considers only meetings held under the Disciple's current discipler
  assignment: meetings whose discipler_d_group_membership_id is that
  assignment's Discipler and whose occurred_at falls within the
  assignment period.
- Only an explicitly recorded ABSENT outcome increments the streak.
  PRESENT and LATE break it. EXCUSED breaks it and is never an absence
  (BR-027a).
- The streak runs across lesson boundaries. Completing a lesson does not
  reset it.
- NO RECORD is not ABSENT. Elapsed time, inactivity, the absence of a
  record and an empty calendar date are never an absence and never
  contribute to the streak (ADR-014). Attendance is never inferred from
  missing data.
- Neither the number of meetings a lesson has taken nor a count above a
  recommendation is ever a monitoring input (ADR-011).

Recalculation triggers:

- record_discipleship_meeting()
- void_discipleship_meeting()
- void_meeting_participant()
- set_discipler() (re-pair or unpair) and end_d_group_membership(),
  which replaced reassign_discipler() in Vertical Slice 3
- transfer_disciple()

Discipler appointment is not a trigger: it does not end the Disciple's
own assignment (ADR-012, which supersedes "and promotion" in ADR-009).
No gathering operation is a trigger (ADR-014).

## Episodes

Monitoring is scoped to a discipler assignment. The D Group membership
episode, used only by gathering-based monitoring, is withdrawn
(ADR-014).

The scope exists because a follow-up is assigned within a specific
ministry context, and carrying a streak across that boundary would
raise a case against a Discipler who never saw those absences.

Any operation that ends an episode must, in the same transaction:

- resolve any ACTIVE attention condition belonging to that episode,
  setting resolved_at
- recompute the streak for the new episode, where one begins

For Disciples, the discipler assignment ends on Discipler reassignment
and D Group transfer. Discipler appointment does not end it (ADR-012).
transfer_disciple() therefore resolves an ACTIVE CONSECUTIVE_ABSENCE
condition as part of ending the assignment. The new assignment's streak
begins from that assignment's own meetings. It never carries the
previous streak forward.

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

With one MVP condition type, a person holds at most one ACTIVE
condition. A person who is both a Disciple and a Discipler is monitored
as a Disciple only, so their DISCIPLER responsibility adds no second
condition (ADR-012, ADR-014).

---

# 7. Follow-ups

## Rules

In the MVP, follow-ups are triggered only by CONSECUTIVE_ABSENCE
(section 6), whose subject is always a DISCIPLE responsibility
(ADR-014 decision 9). Every gathering-derived input is removed. No
replacement trigger is invented.

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

The DISCIPLER and LEADER subject branches have no MVP trigger
(ADR-014); they are not built until a factual condition for those
subjects is approved. They are kept as architecture. Whether to remove
them from the documents instead is open (ADR-014 Consequences).

A follow-up is never assigned to its own subject. Where one person holds
several responsibilities, the chain continues until a different person
is reached.

The chain terminates at Coordinator, which is why the church must
preserve at least one active COORDINATOR.

## D Group Context on Conditions and Follow-ups

attention_conditions.d_group_id and follow_ups.d_group_id are nullable in
the schema but are always populated by MVP monitoring, because the MVP
condition is derived from a specific D Group: CONSECUTIVE_ABSENCE from
the d_group_id of the discipleship meetings that form the streak.
(The gathering's D Group as a source is withdrawn, ADR-014.)

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
because a later recorded outcome broke the streak, the follow-up is NOT auto-closed. The human
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

- lesson completion undo and reopening
- Discipler appointment
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
- discipleship_meetings vs D Group, Discipler and lesson (replaces
  "gathering_attendance vs gathering / D Group", withdrawn with
  gatherings, ADR-014; it follows directly from the rule above)
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

Attendance exists only as a discipleship meeting outcome (ADR-014).
There is one attendance domain, discipleship meeting outcomes from
discipleship_meeting_participants. The gathering attendance domain and
its subsections (Eligible Attendance, Attendance Metrics with
attendance_percentage and last_attendance_date, Attendance History and
Transfers, and the gathering Consecutive Absence Streak for LEADER and
DISCIPLER responsibilities) are withdrawn with gatherings.

Lesson progress is a separate concept. It consumes only credited
meeting participation and COMPLETED lesson status.

No derived value is a percentage or ratio of performance or progress
(decision 8). Progress and meeting facts are stated as counts and
dates: "5 of 10 lessons completed", "Lesson 6 current", "2
consecutive recorded absences", "Last
recorded meeting Sep 28".

## Credited Meetings

credited_meetings(member, lesson)
= count of credited participations for that lesson, as defined in
  section 4

The count has no upper limit and is never clamped. It is presented as a
count ("5 meetings recorded"), never as a fraction of a target
("5 / 4"), and never beside a typical or recommended number (ADR-017).
It is a fact, not a progression gate.

meeting_ordinal
= position of a credited participation among that lesson's credited
  participations, ordered by (occurred_at, meeting id). Uncredited rows
  have no ordinal.

## Meeting Facts

Revised 2026-10-05: this subsection was "Meeting Consistency Metrics".
The meeting_consistency ratio is removed (decision 8); no consistency
ratio or percentage is defined or shown. The remaining figures are
counts and dates.

Computed over RECORDED participant rows in RECORDED meetings.

meetings_attended
= count of PRESENT + LATE

recorded_absences (formerly meetups_missed)
= count of ABSENT

excused (formerly meetups_excused)
= count of EXCUSED

last_recorded_meeting_date (formerly last_meeting_date)
= occurred_at of the latest RECORDED participant row in a RECORDED
  meeting, whatever the attendance outcome (PRESENT, LATE, ABSENT or
  EXCUSED). Decided 2026-10-05 (Slice 5 decision S6): "Last recorded
  meeting" in the UI means this value. A latest credited or counted
  meeting, if ever needed, is a separate figure with its own name and
  never reuses this one.

Wording rule for these figures: recorded_absences counts explicitly
recorded ABSENT outcomes and is presented as "recorded absences" ("2
recorded absences"). Time without a record is presented as a date
("Last recorded meeting Sep 12", "No meeting recorded yet"), never as
missed meetings or as absences.

Oversight views may show the time since last_recorded_meeting_date. It
is computed at read time and never stored, and it is never a condition
(ADR-014 decision 4).

Historical meeting facts survive D Group transfer and Discipler
reassignment, because participation is anchored to church_membership_id.

## Consecutive Recorded Absences

Revised 2026-10-05: this subsection was "Consecutive Missed-Meeting
Streak" (ADR-014).

consecutive_recorded_absences applies to DISCIPLE responsibilities
only.

Walk RECORDED participant rows in RECORDED meetings under the Disciple's
CURRENT discipler assignment, in descending (occurred_at, meeting id)
order. Count leading ABSENT outcomes. Stop at the first PRESENT, LATE or
EXCUSED.

This is the streak CONSECUTIVE_ABSENCE compares with
church_settings.consecutive_absence_threshold (section 6).

Ending the discipler assignment resets the streak. Historical meeting
outcomes are not reset. Discipler appointment does not end the
assignment (ADR-012).

The streak only reflects meetups that were recorded. A Discipler and
Disciple who stop meeting and record nothing produce no streak; that
situation is visible through last_recorded_meeting_date. An automated
inactivity condition is withdrawn, not future scope (ADR-014 decision
4).

## Discipler Eligibility

Added 2026-10-05 (ADR-012).

discipler_eligible(member)
= true when the member's progress row for the eligibility lesson
  (Lesson 5) of the church's ACTIVE curriculum has status COMPLETED

IN_PROGRESS does not count, and READY_FOR_COMPLETION is no longer entered (ADR-015). Sequential
eligibility (section 4) means this implies the earlier lessons are
COMPLETED, so the one test is sufficient. The eligibility lesson
number comes from `private.discipler_eligibility_lesson()` (D2); no rule hard-codes it elsewhere.

"Eligible since" is that lesson's completed_at. Eligibility is derived
at read time and never stored, so an undo or a reopen (section 4) withdraws it
immediately. It never appoints anyone by itself (section 5).

## Active Discipleships

Definition (decision A3, verified against the schema):

An active discipleship is a discipler_assignments row that is active
now (started_at <= now() and ended_at IS NULL), whose disciple side is
an active DISCIPLE d_group_memberships row of an ACTIVE church
membership.

active_discipleships(scope)
= count of such rows within the scope: one Discipler's assignments, one
  D Group, or the church

A Disciple who is placed but not paired is not in an active
discipleship, although their journey and progress exist. Lesson state
and Discipler appointment do not enter the definition: a Disciple who
is eligible for, or has received, a Discipler appointment continues
their own journey and is still in an active discipleship until the
assignment ends (ADR-012). (Previously "awaits promotion review".)

Derived at read time, never stored. Who may see which scope is defined
in RBAC_RLS_MATRIX.md section 2b.

## Candidate: Lessons Completed This Month

Not defined and not governing (decision 9). Recorded here only as a
candidate Reporting / Oversight metric, owned by Slice 11. It does not
block Slice 5. Before adoption it needs:

- a precise definition;
- which timestamp or event counts (likely lessons reaching
  COMPLETED in the month, that is completed_at);
- church time zone semantics for "this month";
- a privacy review (RBAC_RLS_MATRIX.md section 2b);
- small-population suppression before broad member visibility.

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
- record discipleship meeting, with each Disciple's outcome
- void discipleship meeting or participant
- mark lesson completed, undo a lesson completion (ADR-015)
- reopen lesson completion
- appoint Discipler (ADR-012; Slice 6)
- resolve/recalculate monitoring conditions
- same-church validation where ordinary foreign keys cannot express it

Removed 2026-10-05: finalize attendance, cancel gathering and correct
finalized attendance (ADR-014); promote Disciple, now appoint Discipler
(ADR-012).

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

- lesson meeting count
- recorded absences and last recorded meeting date
- consecutive recorded absences
- lessons completed ("5 of 10 completed")
- active discipleships
- Discipler eligibility
- overdue follow-up state

Removed 2026-10-05: attendance percentage and the gathering
consecutive absence count (ADR-014); meeting consistency and overall
discipleship percentage (decision 8); held or missed meetup (ADR-014
decision 8); promotion eligibility, now Discipler eligibility
(ADR-012).

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