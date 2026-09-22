# DiscipleTrack Business Rules

*Document Status:* MVP Baseline  
*Last Updated:* September 2026

This document defines domain rules that DiscipleTrack must preserve
regardless of UI implementation.

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
- attendance oversight
- progress
- follow-ups
- promotion review

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

## BR-015 — Disciple and Discipler Are Mutually Exclusive Active Responsibilities

A person cannot simultaneously be an active Disciple and active
Discipler.

Only this pair is mutually exclusive. LEADER and DISCIPLER may coexist
for the same person, as described in BR-013.

Promotion changes the person's active ministry responsibility while
preserving historical discipleship records.

---

## BR-016 — D Group Gathering and Discipleship Meeting Are Different

A D Group Gathering represents the overall group's meeting.

A Discipleship Meeting represents lesson work between a Discipler and
assigned Disciple(s).

They must remain distinct domain concepts.

---

## BR-017 — D Group Gatherings Have Flexible Scheduling

D Groups are not required to maintain a fixed recurring meeting schedule.

Each actual gathering records its own date/time.

---

## BR-018 — Gathering Attendance Includes D Group Participants

Attendance may be recorded for:

- D Group Leader
- Disciplers
- Disciples

according to their active participation in the D Group.

---

## BR-019 — Attendance Uniqueness

A person can have at most one attendance record for a particular
D Group Gathering.

This invariant should be enforced at the database level.

---

## BR-020 — Attendance Source of Truth

Individual attendance records are authoritative.

Derived information includes:

- attendance percentage
- sessions attended
- sessions missed
- consecutive absences
- last attendance date

Each of these has exactly one authoritative definition, recorded in
DATABASE_CONSTRAINTS.md under Derived Metric Definitions. Excused
attendance is excluded from the attendance-percentage denominator.

Historical attendance metrics survive D Group transfer. The current
consecutive-absence streak is scoped to the current D Group membership
episode and resets on transfer, while the underlying attendance history
is never reset or discarded.

---

## BR-021 — Attendance States

MVP attendance states are:

- Present
- Absent
- Late
- Excused

---

## BR-022 — Late Counts as Attended

Late attendance counts as attendance for consecutive-absence monitoring.

It must not increment an absence streak.

---

## BR-023 — Excused Breaks the Absence Streak

An Excused attendance state does not count as an unexplained absence.

It resets/breaks the consecutive unexplained absence streak.

Example:

Absent
Absent
Excused
Absent

results in a current consecutive unexplained absence streak of 1.

---

## BR-024 — Nobody Modifies Their Own Attendance

A person may view their own attendance history.

No person may create, modify or delete their own official attendance
record. This applies in every role, including Coordinator, D Group
Leader and Discipler, not only to ordinary members.

Recording authority always means recording for other eligible members
within the recorder's authorized scope.

Where a D Group's only authorized recorder is its Leader, another
Discipler in that D Group or the Coordinator records the Leader's
attendance. No additional recorder role exists in the MVP.

---

## BR-025 — Attendance Recording Authorization

Authorized D Group Leaders and Disciplers may record D Group attendance.

The Coordinator may oversee/correct attendance according to defined
permissions.

Exact edit/finalization permissions will be enforced by the authorization
model.

---

## BR-026 — Monitoring Uses Finalized Gatherings

Attendance monitoring should use finalized official D Group Gathering
records.

Draft/incomplete gatherings must not incorrectly trigger follow-ups.

---

## BR-027 — Consecutive Absence Monitoring

The MVP monitors consecutive unexplained absences.

The initial/default threshold is 3.

The threshold should be configurable rather than permanently hard-coded.

---

## BR-028 — Monitoring Is Deterministic

Core attendance monitoring must use deterministic business rules.

AI does not determine whether the absence threshold was reached.

---

## BR-029 — Curriculum Contains 12 Ordered Lessons

The church's MVP discipleship curriculum consists of 12 ordered lessons.

The curriculum is represented as data and must not be hard-coded into
Flutter UI/business logic.

---

## BR-030 — Each Lesson Requires Four Discipleship Meetings

Each lesson requires four recorded meetings specifically working through
that lesson.

A meeting for another lesson does not count toward the current lesson's
four-meeting requirement.

---

## BR-030a — Lesson Progression Is Sequential

A Disciple may work through lesson N only when lesson N-1 is COMPLETED.

Lesson 1 is exempt.

Because a Discipleship Meeting records exactly one lesson, every counted
participant in that meeting must be eligible for that same lesson.

Disciples who are on different lessons therefore require separate
Discipleship Meeting records. This is an intentional ministry
constraint rather than a modelling limitation.

Sequential eligibility is enforced server-side. There is no Coordinator
sequencing override in the MVP.

A meeting only credits a participant when that person was an active
Disciple of the meeting's D Group and was assigned to the meeting's
Discipler at the time the meeting occurred. A Disciple with no assigned
Discipler cannot receive progress credit until an assignment exists.

---

## BR-031 — Discipler Records Discipleship Meetings

The responsible Discipler records each completed Discipleship Meeting.

The Disciple does not need to separately confirm each meeting in the MVP.

---

## BR-032 — Four Meetings Do Not Automatically Complete a Lesson

When the fourth required meeting is recorded:

Lesson
→ Ready for Completion

The lesson does not automatically become Completed.

---

## BR-033 — D Group Leader Confirms Lesson Completion

The relevant D Group Leader reviews a lesson that has reached 4/4 and
confirms completion.

Only after confirmation is the lesson considered Completed.

The Coordinator may also confirm completion as a ministry-oversight
fallback, for example where a D Group currently has no active Leader.
Without this, a leadership gap would block progression for every
Disciple in that group. Coordinator confirmation is attributable through
confirmed_by and is audited.

---

## BR-033a — Completed Lessons Are Protected

A confirmed Completed lesson must not be silently invalidated.

Voiding a meeting or participation record that would reduce valid
counted meetings below the requirement for a Completed lesson must be
rejected.

Correcting such a case requires an explicit authorized reopen operation
first.

Progress that has not been confirmed may recompute freely. A lesson at
Ready for Completion may return to In Progress when valid meeting count
falls below the requirement.

---

## BR-034 — Attendance and Discipleship Progress Are Separate

D Group attendance and lesson progress represent different concepts.

A Disciple may miss a D Group Gathering while continuing individual
Discipleship Meetings.

Likewise, attending a D Group Gathering does not count as one of the
four required lesson meetings unless explicitly represented as a valid
Discipleship Meeting under the discipleship workflow.

---

## BR-035 — Progress Source of Truth

Discipleship Meeting and lesson-completion records are authoritative.

Overall progress percentages and current-stage indicators are derived
from these underlying records.

---

## BR-036 — Curriculum Completion Creates Promotion Eligibility

Completing every lesson of the church's active curriculum makes a
Disciple eligible for Discipler review.

The MVP curriculum contains twelve lessons, but that count is seed data
rather than a rule. Eligibility is evaluated against the active
curriculum, never against a hard-coded number.

It does not automatically promote them.

---

## BR-037 — Coordinator Approves Discipler Promotion

Promotion from Disciple to Discipler requires an explicit Coordinator
decision.

The system must preserve the person's completed discipleship history
after promotion.

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

## BR-039 — Attendance Follow-up Assignment

Absence monitoring applies to Leaders, Disciplers and Disciples alike.
All three may reach the absence threshold.

When an attendance-based follow-up is created, responsibility is
assigned using the following chain, evaluated on distinct people:

Subject is a Disciple:
→ active primary Discipler
→ otherwise the D Group Leader
→ otherwise the Coordinator

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

When monitoring resolves an attention condition because the person has
resumed attending, the related follow-up is not automatically closed.

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
- attendance changes
- Discipleship Meeting creation
- lesson confirmation
- promotion
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

- attendance uniqueness
- valid relationships
- referential integrity
- constrained state values

---

## BR-055a — Same-Church Integrity

A record must never relate information belonging to different churches.

Examples that must be rejected include a D Group membership referencing
a church membership from another church, attendance referencing a
gathering outside the member's church, and lesson progress referencing
another church's curriculum.

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
- AI insights
- SMS
- automated escalation
- chat
- advanced analytics

require an intentional future scope decision.