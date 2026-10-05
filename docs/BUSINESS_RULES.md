# DiscipleTrack Business Rules

*Document Status:* MVP Baseline  
*Last Updated:* October 2026

This document defines domain rules that DiscipleTrack must preserve
regardless of UI implementation.

Revision 2026-10-02: BR-029a (lesson content, ADR-010); BR-030, BR-032,
BR-032a, BR-033 and BR-033a (explicit lesson completion independent of
a fixed meeting count, ADR-011, decision B); BR-031a (recorded meeting
history may be viewed by month, decision A4); BR-027a (missed-meeting
wording, decision A9).

Revision 2026-10-05: D Group gatherings and gathering attendance removed
(ADR-014): BR-016 to BR-020, BR-025 and BR-026 withdrawn (headings kept,
numbering stable); BR-010, BR-021 to BR-024 rescoped to discipleship
meeting outcomes; BR-027 and BR-027a rewritten as one condition, one
source and one threshold (consecutive recorded absences); "missed
meetup" wording removed from BR-028, BR-030a, BR-031, BR-031a, BR-031b,
BR-034 and BR-044a; BR-034 and BR-039 lose the gathering concept (LEADER
and DISCIPLER follow-up branches have no MVP trigger); BR-035 factual
segmented progress, no percentages (decisions 8, 22); examples in
BR-053, BR-055 and BR-055a; BR-056 out-of-scope list. Discipler
eligibility and appointment (ADR-012): BR-010, BR-015 (Disciple and
Leader exclusion; Disciple and Discipler may coexist; no self-pairing),
BR-024 self-credit rationale, BR-036 (confirmed Lesson 5), BR-037
(appointment, not promotion), BR-053.

Revision 2026-10-05 (ADR-015): the Discipler marks a lesson completed
in one step, with no Leader confirmation. BR-030, BR-032, BR-032a,
BR-033, BR-033a, BR-034, BR-035, BR-036 and BR-053 revised (titles
changed, numbering stable): Leader and Coordinator fallback, a
time-bounded undo, Coordinator reopen to In Progress, Ready for
Completion no longer entered.

Revision 2026-10-05 (user decision, ninth): the curriculum has ten
lessons, not twelve. BR-029 retitled (numbering stable); examples in
BR-035 and BR-037.

---

## BR-001 — System Roles and D Group Responsibilities Are Separate

System/church roles:

- Admin
- Discipleship Coordinator
- Member

D Group responsibilities:

- D Group Leader
- Discipler
- Disciple

A D Group responsibility does not automatically grant unrelated
church-wide system authority.

---

## BR-002 — Multiple Types of Responsibility May Coexist

A person may hold a system responsibility and a D Group responsibility
at the same time.

Example:

System Role:
Coordinator

D Group Responsibility:
D Group Leader

Authorization must evaluate the relevant context.

---

## BR-003 — Privileged System Roles Cannot Be Self-Assigned

Users cannot assign themselves Admin or Coordinator access.

Privileged system roles require an authorized assignment process.

---

## BR-004 — D Group Responsibilities Cannot Be Self-Assigned

A Member cannot make themselves a D Group Leader or Discipler.

These responsibilities require an authorized ministry assignment.

---

## BR-005 — Church Membership Is Required

A user must belong to or be appropriately authorized for the church
before accessing protected church information.

Entering a church join code does not itself grant privileged access.

Membership may require approval.

---

## BR-006 — Registered Users Only for MVP

The MVP tracks active participants through registered DiscipleTrack
accounts.

Creating separate offline member records for people who have never
registered is outside the MVP.

---

## BR-007 — Church Data Isolation

Protected church information must not be accessible to unauthorized
users outside the church context.

Backend/database controls must enforce this rule.

---

## BR-008 — Admin Responsibility

Admin is primarily responsible for:

- system configuration
- accounts
- memberships
- privileged system roles
- access/security administration

Admin is not automatically a ministry-care role.

---

## BR-009 — Admin Does Not Automatically Access Ministry-Care Data

System administration privileges alone do not automatically grant access
to private follow-up notes or equivalent ministry-care information.

Additional ministry responsibility is required where appropriate.

---

## BR-010 — Coordinator Responsibility

The Coordinator oversees church-wide discipleship operations including:

- D Groups
- Leaders
- Disciplers
- Disciples
- assignments
- curriculum
- progress, including recorded discipleship meeting outcomes
- follow-ups
- Discipler appointment (ADR-012)

Gathering attendance oversight is withdrawn with D Group gatherings
(ADR-014).

---

## BR-011 — One Active D Group Leader

Each active D Group has one primary active D Group Leader.

A person may lead only one active D Group at a time.

Leadership changes must preserve meaningful history.

---

## BR-012 — One Active D Group for a Disciple

A Disciple belongs to only one active D Group at a time.

Transfers must preserve historical D Group membership.

---

## BR-013 — Multiple Disciplers per D Group

A D Group may contain multiple Disciplers.

Each Discipler operates only within authorized scope.

A person may hold active LEADER and DISCIPLER responsibilities at the
same time. A D Group Leader who personally disciples members must hold
the DISCIPLER responsibility in order to receive discipler assignments.

---

## BR-014 — One Primary Discipler per Disciple

A Disciple may have at most one active primary Discipler.

A Disciple may temporarily have no assigned Discipler.

A Discipler may be responsible for multiple Disciples.

Changes in assignment must preserve historical records.

---

## BR-015 — Disciple and Leader Are Mutually Exclusive Active Responsibilities

A person cannot simultaneously be an active Disciple and an active
D Group Leader. Only this pair is mutually exclusive.

DISCIPLE and DISCIPLER may coexist for the same person in one D Group:
a Disciple appointed as a Discipler continues their own journey as a
Disciple (BR-037) (ADR-012; enforced from Slice 6; until then Migration
006 still refuses DISCIPLE with DISCIPLER). LEADER and DISCIPLER may
also coexist, as described in BR-013. All of a person's active
responsibilities are in one D Group at a time.

Nobody is paired with themselves: the Discipler and the Disciple of a
discipler assignment belong to different church memberships (ADR-012,
enforced from Slice 6). Whether two people may disciple each other at
the same time (reciprocal pairing) is open (D7).

---

## BR-016 — D Group Gathering and Discipleship Meeting Are Different

Withdrawn (ADR-014). D Group gatherings are not part of the MVP;
attendance exists only as a discipleship meeting outcome, recorded
through Record Meeting (BR-031 to BR-031b).

---

## BR-017 — D Group Gatherings Have Flexible Scheduling

Withdrawn (ADR-014). Gatherings are not tracked. Discipleship meetings
are recorded, not scheduled (BR-031a).

---

## BR-018 — Gathering Attendance Includes D Group Participants

Withdrawn (ADR-014). Only the Disciples of a discipleship meeting
receive an outcome (BR-031b).

---

## BR-019 — Attendance Uniqueness

Withdrawn (ADR-014). The gathering form of this rule is gone. Each
expected Disciple has exactly one outcome per discipleship meeting
(BR-031b), enforced in the database (BR-055).

---

## BR-020 — Attendance Source of Truth

Withdrawn (ADR-014). Gathering attendance percentage, sessions attended,
sessions missed and the gathering consecutive-absence streak no longer
exist, and no attendance percentage is defined (decision 8). Recorded
meeting outcomes are authoritative; the consecutive recorded absence
streak is BR-027a and progress is BR-035.

---

## BR-021 — Attendance States

Attendance exists only as the outcome of a discipleship meeting
(ADR-014). Each expected Disciple receives one of these states:

- Present
- Absent
- Late
- Excused

Their effects on lesson credit and on the consecutive recorded absence
streak are in BR-031b.

---

## BR-022 — Late Is Credited

A Late outcome credits the meeting to the Disciple toward the lesson,
exactly as Present does (BR-030).

It breaks the consecutive recorded absence streak and never increments
it (BR-027a).

---

## BR-023 — Excused Breaks the Absence Streak

An Excused outcome is never an absence.

It is not credited toward the lesson, and it breaks the consecutive
recorded absence streak (BR-027a).

Example of recorded outcomes, oldest first:

Absent
Absent
Excused
Absent

results in a current streak of 1 consecutive recorded absence.

---

## BR-024 — Nobody Records Their Own Meeting Outcome

A person may view their own discipleship meeting history.

No person may create, modify or void their own official meeting
outcome. This applies in every role, including Coordinator, D Group
Leader and Discipler, not only to ordinary members.

A Disciple never records or changes their own meeting outcome. A
recorder is never a participant in a meeting they record (explicit
check from Slice 5), and nobody is paired with themselves (ADR-012,
enforced from Slice 6), so nobody can credit themselves.

Recording authority always means recording for other eligible members
within the recorder's authorized scope (BR-031).

---

## BR-025 — Attendance Recording Authorization

Withdrawn (ADR-014). There is no gathering attendance to record.
Discipleship meeting recording authority is BR-031, and voids are
BR-031c.

---

## BR-026 — Gathering Monitoring Uses Finalized Gatherings

Withdrawn (ADR-014). No gathering source exists. Monitoring uses
recorded discipleship meeting outcomes only (BR-027, BR-027a).

---

## BR-027 — One Monitoring Condition, One Source, One Threshold

The MVP monitors one condition, consecutive recorded absences
(`CONSECUTIVE_ABSENCE`), for Disciples only (ADR-014). Its only source is
the outcomes explicitly recorded in discipleship meetings (BR-027a).

The threshold is `church_settings.consecutive_absence_threshold`, with a
default of 3. It is configurable per church rather than hard-coded. No
other threshold is read by any monitoring rule.

Leaders and Disciplers have no automated monitoring in the MVP; their
participation is noticed through human oversight. A person who is both
a Disciple and a Discipler (BR-015) is monitored as a Disciple only.

---

## BR-027a — Consecutive Recorded Absences

A Disciple's consecutive recorded absence streak is built only from
outcomes explicitly recorded for that Disciple on recorded (not voided)
discipleship meetings, in chronological order.

- Absent increments the streak.
- Present or Late breaks the streak.
- Excused breaks the streak and is never an absence.

The streak runs across lesson boundaries and is scoped to the Disciple's
current Discipler assignment. A new Discipler starts with a fresh streak,
because they did not witness the earlier recorded absences.

Monitoring only sees meetings that were recorded. If meetings stop and
nothing is recorded, the Disciple's last recorded meeting date is how
leadership notices. That date is a displayed fact, never a condition. No
condition or follow-up is ever generated from elapsed time, inactivity
or the lack of a record (ADR-014 decision 4).

An absence exists only where a meeting was recorded with an ABSENT
outcome for that Disciple. No record is not an absence. An absence is
never inferred from elapsed time, inactivity, the lack of a record or an
empty calendar date. Wording follows the record: "2 recorded absences",
"2 consecutive recorded absences", "Last recorded meeting Sep 12".

---

## BR-028 — Monitoring Is Deterministic

Core absence monitoring (BR-027a) must use deterministic business
rules.

AI does not determine whether the absence threshold was reached.

---

## BR-029 — Curriculum Contains 10 Ordered Lessons

The church's MVP discipleship curriculum consists of 10 ordered lessons.

The curriculum is represented as data and must not be hard-coded into
Flutter UI/business logic.

---

## BR-029a — Lesson Content Is Delivered, Separately from Progress

DiscipleTrack delivers the published lesson material to every ACTIVE
member of the church (ADR-010). Supabase holds the authoritative
published content; the repository Markdown is its publishing source.

Reading is offline-first: once the curriculum has synced, lessons are
readable without a connection, with no per-lesson download.

Reading a lesson records nothing. It is not attendance, not progress and
not a completion signal. Offline reading never enables an offline write.

---

## BR-030 — Lesson Meetings Are Counted, Not Required

*Revised 2026-10-05 (ADR-015).*

A lesson is worked through in as many credited meetings as the material
takes. The number varies: four is common, around six happens. The
meeting count is factual history of the lesson; it is not what
completes the lesson (BR-032).

A meeting is credited to a Disciple only when that Disciple was Present
or Late. Absent and Excused are attendance outcomes; they never count
as lesson meetings and never indicate that material was covered, but
they remain visible in the Disciple's meeting history.

A meeting for another lesson does not count toward the current lesson.

There is no maximum number of meetings per lesson.

Whether a minimum number of credited meetings must exist before a
lesson can be marked completed is an open product decision
(ADR-011; ADR-015). Until it is decided, no rule may assume a fixed number.
Counts are shown as counts ("5 meetings recorded"), never as a fraction
of a target ("5 / 4").

---

## BR-030a — Lesson Progression Is Sequential

A Disciple may work through lesson N only when lesson N-1 is COMPLETED.

Lesson 1 is exempt.

Because a Discipleship Meeting records exactly one lesson, every
participant listed in that meeting, whatever their outcome, must be
eligible for that same lesson.

Disciples who are on different lessons therefore require separate
Discipleship Meeting records. This is an intentional ministry
constraint rather than a modelling limitation.

Sequential eligibility is enforced server-side. There is no Coordinator
sequencing override in the MVP.

A participant may only be listed in a meeting when that person was an
active Disciple of the meeting's D Group and was assigned to the
meeting's Discipler at the time the meeting occurred. A Disciple with no
assigned Discipler cannot receive progress credit, or have any meeting
outcome recorded, until an assignment exists.

---

## BR-031 — Discipler Records Discipleship Meetings

The responsible Discipler records each Discipleship Meeting afterwards,
with each expected Disciple's outcome, whether that outcome is Present,
Late, Absent or Excused. A meeting record shows each Disciple's recorded
outcome; it carries no "held" or "missed" label (ADR-014 decision 8).

A D Group Leader or the Coordinator may record on behalf of the
responsible Discipler as a fallback. The record shows who entered it.

The Disciple does not need to separately confirm each meeting in the MVP,
and cannot create or change their own official meeting record. There is
one authoritative record per meeting.

---

## BR-031a — Meetings Are Recorded, Not Scheduled

The Discipler and Disciple arrange their meetups themselves, outside the
app. DiscipleTrack records what actually happened. It is not a
scheduling or calendar system: it does not schedule, plan, invite to or
manage meetings, and no record exists before a meetup.

Viewing recorded meetings by month is not scheduling. A read-only
monthly view derived from the occurred_at of meetings already recorded
is allowed. It shows only recorded meetings and their outcomes. It
never shows a planned meeting, never offers to create one for a date,
and never marks a date without a record as missed.

A meeting at which a Disciple was Absent or Excused is recorded the same
way as any other, afterwards: the lesson, the date the meetup took place
or was arranged for, the Disciple(s) who were expected, and each
person's outcome. The date may not be in the future.

A meetup that both sides cancelled in advance is not recorded.

---

## BR-031b — Meeting Outcomes

Each expected Disciple receives one explicit outcome:

| Outcome | Counts toward lesson | Consecutive recorded absence streak (BR-027a) |
|---|---|---|
| Present | Yes | Breaks |
| Late | Yes | Breaks |
| Absent | No | Increments |
| Excused | No | Breaks; not an absence |

In a small-group meeting, each Disciple's outcome is independent. A
recorded meeting in which every outcome is Excused is not an absence for
anyone: it has no credited participation and breaks each Disciple's
streak (ADR-014 decision 8).

---

## BR-031c — Meeting Corrections

Recorded meetings and outcomes are not edited. An incorrect record is
voided and recorded again. Voided records stay in history and count for
nothing.

A Discipler may void a meeting, or a participant outcome, that they
recorded themselves, within their own Discipler responsibility. A D Group
Leader and the Coordinator retain oversight and fallback void authority.

Every void is audited and remains subject to Completed-lesson protection
(BR-033a).

---

## BR-032 — No Meeting Count Completes a Lesson

*Revised 2026-10-05 (ADR-015).*

Recording a meeting, of any ordinal, never makes a lesson Completed by
itself (ADR-011).

Lesson progression:

Not Started
→ In Progress, at the first credited meeting
→ Completed, when the Discipler marks the lesson completed (BR-033)
→ the next lesson in sequence becomes current, for every role

There is no intermediate "awaiting confirmation" state. Ready for
Completion remains in the schema but is no longer entered (ADR-015).
Meetings recorded after completion belong to the next lesson, which is
then the current lesson.

## BR-032a — The Discipler Decides When a Lesson Is Finished

*Revised 2026-10-05 (ADR-015).*

The Discipler conducting the lesson, normally the Disciple's current
assigned Discipler, decides when the lesson material has been covered.
That judgement is recorded by marking the lesson completed (BR-033); no
separate submission step exists.

A lesson can be marked completed only while it is In Progress, so it
has at least one credited meeting. Whether a larger minimum applies is
the open decision in BR-030. A Disciple never marks, undoes or reopens
their own lesson.

---

## BR-033 — The Discipler Marks a Lesson Completed

*Revised 2026-10-05 (ADR-015). Previously: D Group Leader Confirms
Lesson Completion.*

The Disciple's current assigned Discipler marks the lesson completed
("Mark Lesson 4 completed"). The lesson is Completed immediately and the
next lesson in sequence becomes current. There is no Leader
confirmation.

The Leader of the Disciple's current D Group and the Coordinator may
mark a lesson completed on the Discipler's behalf, as they may record
meetings on the Discipler's behalf. Without this fallback, a gap in the
Discipler relationship would block progression.

Marking completed requires that the lesson is the Disciple's current
lesson, that it is In Progress, and that its credited meetings meet the
lesson meeting policy minimum at that moment (BR-030). The completion
records who marked it and when, and is audited.

A completion may be undone by the current assigned Discipler, the
Leader of the Disciple's current D Group or the Coordinator, only while
both hold:

- it is the Disciple's latest Completed lesson (no later lesson is
  Completed); and
- no meeting has been recorded for the Disciple on the next lesson.

Undo returns the lesson to In Progress (or Not Started when it has no
credited meeting), clears the completion attribution and is audited
with the prior values. From Slice 6, the eligibility-lesson protection
for an appointed Discipler (BR-036, ADR-012) also applies to undo.

After that window, only the Coordinator can reopen a completed lesson
(BR-033a).

---

## BR-033a — Completed Lessons Are Protected

*Revised 2026-10-05 (ADR-015).*

A Completed lesson must not be silently invalidated.

A void never changes a Completed status. Voiding a meeting or
participation record that would leave a Completed lesson with fewer
credited meetings than marking completed needs (BR-033, and the open
minimum in BR-030) must be rejected. Voiding an Absent or Excused
outcome never affects progress.

Correcting such a case requires an explicit authorized reopen operation
first (Coordinator only, outside the undo window of BR-033). Reopening
returns the lesson to In Progress, or Not Started when no credited
meeting remains.

Progress that is not Completed recomputes only from credited presence:
a lesson with no credited meeting is Not Started. Recomputation never
makes a lesson Completed. The automatic withdrawal of a Ready for
Completion submission that a void leaves below the minimum is dormant,
because that state is no longer entered (ADR-015).

---

## BR-034 — Attendance and Discipleship Progress Are Separate

Two concepts are distinct:

- Discipleship meeting attendance (each Disciple's recorded outcome)
- Lesson progress

D Group gathering attendance no longer exists (ADR-014); attendance is
only a discipleship meeting outcome.

Discipleship meeting attendance and lesson progress share one record,
but only credited attendance (Present or Late) counts as a lesson
meeting. Absent and Excused outcomes are meeting history, not progress.
Lesson completion is a further step, separate from both: the Discipler
explicitly marks the lesson completed (BR-033; revised 2026-10-05,
ADR-015).

---

## BR-035 — Progress Source of Truth

Discipleship Meeting and lesson-completion records are authoritative.

Current-stage indicators and overall progress are derived from these
underlying records. They are presented as factual states ("Lesson 6 of
10", "5 of 10 completed", "Lesson 6 · 5 meetings recorded", "Last
recorded meeting Sep 25"), never as
rankings, comparisons between people or groups, consistency ratios,
performance percentages or evaluative labels such as "behind" or
"advanced" (decisions 8, 22).

Overall progress is a segmented view of the curriculum: one segment per
lesson, each completed, current or upcoming. Only a Completed lesson
counts as completed (revised 2026-10-05, ADR-015). The
number of recorded meetings never determines progress. The total comes
from the active curriculum, never from a literal.

---

## BR-036 — Completed Lesson 5 Creates Discipler Eligibility

*Revised 2026-10-05 (ADR-015).*

A Disciple becomes eligible to be appointed as a Discipler when Lesson 5
of the church's active curriculum is Completed, as marked by the
Discipler (ADR-012, ADR-015). In Progress does not count. Completion has
no second check, so the Coordinator's appointment decision (BR-037) is
the human check before anyone becomes a Discipler. Because progression is
sequential (BR-030a), Lessons 1 to 4 are then Completed as well.

Eligibility is derived from the completion record. It is never stored
and never changes anything by itself.

The eligibility lesson is defined in one place and is not hard-coded in
Flutter or repeated across rules. That place is the policy function
`private.discipler_eligibility_lesson()`, which returns 5 and is not configurable per church (D2,
decided 2026-10-05).

---

## BR-037 — Coordinator Appoints Disciplers

Appointment as a Discipler is an explicit Coordinator act on an eligible
Disciple (ADR-012). There is no acceptance workflow. The appointment is
attributed, audited and preserved as history.

Appointment adds a DISCIPLER responsibility in the same D Group as the
person's DISCIPLE responsibility. It does not end their DISCIPLE
responsibility, their own discipler assignment or their lesson
progress: they continue their own journey through the last lesson of
the curriculum (Lesson 10 in the MVP curriculum) under their own
Discipler (BR-015; enforced from Slice 6).

Eligibility, appointment and assignment are distinct facts. Eligibility
is derived (BR-036); appointment is an attributed record; assigning
Disciples to the new Discipler is a separate discipler assignment
(BR-014). Being eligible does not appoint, and being appointed does not
assign any Disciple.

---

## BR-038 — Follow-up Represents Intentional Care

A follow-up is not merely an alert.

It represents an intentional care workflow:

Concern Detected
→ Responsibility Assigned
→ Human Action
→ Outcome Recorded
→ Resolution

---

## BR-039 — Absence Follow-up Assignment

In the MVP, a follow-up is triggered only by the consecutive recorded
absence condition for a Disciple (BR-027, BR-027a). Gathering absences
are withdrawn as a source (ADR-014).

When that follow-up is created, responsibility is assigned using the
following chain, evaluated on distinct people:

Subject is a Disciple:
→ active primary Discipler
→ otherwise the D Group Leader
→ otherwise the Coordinator

The chain also defines branches for other subjects. They have no MVP
trigger (ADR-014) and are not built until a factual condition for those
subjects is approved:

Subject is a Discipler:
→ the D Group Leader
→ otherwise the Coordinator

Subject is a D Group Leader:
→ the Coordinator

A follow-up is never assigned to the person it concerns. Where one
person holds several responsibilities, the chain continues until a
different person is reached.

Because the chain terminates at the Coordinator, the church must
preserve at least one active Coordinator. The last active Coordinator
cannot be removed or deactivated until another exists.

Where several Coordinators exist, automatic routing selects the
longest-serving active Coordinator deterministically. A follow-up may
afterwards be reassigned through the normal reassignment workflow.

---

## BR-040 — Follow-up Oversight

A D Group Leader may oversee appropriate follow-ups within their D Group.

The Coordinator may oversee appropriate follow-ups across the
discipleship ministry.

---

## BR-041 — Follow-up Deduplication

Repeated monitoring must not create a duplicate follow-up for a
condition it has already handled.

Deduplication is episode-scoped. A detected condition represents one
absence episode and produces at most one follow-up, enforced structurally
so that retried operations remain idempotent without relying on
monitoring logic alone.

A later absence episode is a different condition and may create a new
follow-up even while an earlier follow-up remains unresolved. A person
may therefore have several open follow-ups, one per episode.

---

## BR-042 — Follow-up History Is Preserved

Resolving a follow-up must not delete it.

Resolved follow-ups remain part of the historical ministry-care record.

---

## BR-043 — Viewing Does Not Resolve a Follow-up

Opening or reading a follow-up does not mark it resolved.

Resolution requires an intentional completion action.

---

## BR-044 — Follow-ups May Become Overdue

An unresolved follow-up may have a due date, derived from the church's
configured follow-up due days.

If the due date passes while it remains unresolved, it becomes overdue.

Where no due-day setting is configured, a follow-up has no due date and
cannot become overdue.

The MVP does not require automatic multi-level escalation.

---

## BR-044a — Condition Resolution Does Not Resolve Care

When monitoring resolves an attention condition because a later recorded
outcome breaks the streak (BR-027a), the related follow-up is not
automatically closed.

The human care obligation remains until someone resolves it
deliberately, normally recording that the underlying condition has
already corrected itself.

Views should distinguish an open follow-up with an active condition from
an open follow-up whose condition has already resolved.

---

## BR-045 — Follow-up Notes Are Restricted Ministry Information

Follow-up information may be available to appropriately authorized:

- assigned Discipler
- D Group Leader
- Coordinator

The Disciple does not automatically see internal follow-up notes.

Admin does not automatically receive access solely through system
administration authority.

---

## BR-046 — Announcement Scope Is Explicit

MVP announcements have one of two scopes:

- Church
- D Group

Church announcements are visible according to church membership.

D Group announcements are visible only within the relevant D Group
context.

---

## BR-047 — Announcement Publishing Authority

The Coordinator may create church-wide ministry announcements.

A D Group Leader may create announcements for their own D Group.

The Coordinator may also create D Group announcements as ministry
oversight, for example where a D Group currently has no active Leader.
The Leader remains the normal author for their own D Group.

Disciplers and Disciples do not publish announcements in the MVP.

---

## BR-048 — Every Registered User Has a Profile

Every registered DiscipleTrack user has a profile.

Profile information shown to a viewer depends on authorization and
context.

---

## BR-049 — Profiles Do Not Bypass Authorization

The existence of a profile does not make all information about that
person publicly available.

Attendance, progress, assignments and ministry-care information must
respect authorization rules.

---

## BR-050 — Membership Status and Engagement Are Different

Administrative membership status and discipleship engagement are
different concepts.

A Member may remain administratively Active while showing declining
discipleship participation.

---

## BR-051 — Member Records Use Lifecycle States

Normal workflows should use appropriate states such as:

- Pending
- Active
- Inactive
- Transferred
- Archived

rather than casually deleting historical members.

A person has exactly one church membership record per church. A
returning member reactivates that record rather than receiving a second
one, so their attendance, discipleship progress and care history remain
continuous.

Transferred means the person transferred out of this church. Moving a
Disciple between D Groups is a different concept and does not change
church membership status.

Reactivating a membership does not restore previous D Group
responsibilities or assignments.

When a membership leaves Active, its D Group responsibilities and
discipler assignments end, active attention conditions where that person
is the subject are resolved, and open follow-ups assigned to that person
are reassigned so no care case is left with someone who no longer has
ministry access. Attendance, meetings, progress and resolved care
records are preserved as history.

---

## BR-052 — Historical Assignment Integrity

Changing:

- D Group
- D Group Leader
- Discipler
- responsibility
- membership status

must not unintentionally destroy historical records.

---

## BR-053 — Auditability

Important actions should retain enough information to identify who
performed them and when.

Examples include:

- role assignment
- D Group assignment
- Discipler assignment
- Discipleship Meeting recording, including each outcome
- meeting and participant voids
- lesson completion, undo and reopen (ADR-015)
- Discipler appointment (ADR-012)
- follow-up actions

---

## BR-054 — Client Is Not Trusted

Flutter is not the security boundary.

Sensitive permissions must be enforced by backend/database controls.

A modified client must not be capable of bypassing authorization simply
by issuing backend requests directly.

---

## BR-055 — Database Constraints Protect Important Invariants

Important invariants should be enforced in PostgreSQL where practical,
rather than relying entirely on client logic.

Examples include:

- one outcome per Disciple per discipleship meeting
- valid relationships
- referential integrity
- constrained state values

---

## BR-055a — Same-Church Integrity

A record must never relate information belonging to different churches.

Examples that must be rejected include a D Group membership referencing
a church membership from another church, a discipleship meeting
participant referencing a meeting outside the Disciple's church, and
lesson progress referencing another church's curriculum.

This must be enforced inside PostgreSQL. Ordinary foreign keys are used
where the relationship is naturally expressible; trusted database
functions or constraint triggers are used where it spans tables and
cannot be expressed cleanly.

Flutter and application code must not be the only place this rule
exists.

---

## BR-056 — MVP Scope Protection

Post-MVP functionality must not be introduced accidentally.

Features such as:

- QR attendance
- D Group gatherings and gathering or event attendance (ADR-014)
- AI insights
- SMS
- automated escalation
- chat
- advanced analytics

require an intentional future scope decision.