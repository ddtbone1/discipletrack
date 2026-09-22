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

## BR-024 — Members Cannot Modify Their Own Attendance

Members may view their own attendance history.

They cannot create, modify, or delete their own official attendance
records unless a future explicitly authorized workflow is introduced.

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

Completing all 12 lessons makes a Disciple eligible for Discipler review.

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

When an attendance-based follow-up is created:

If the Disciple has an active primary Discipler:
→ assign responsibility to that Discipler.

If no primary Discipler exists:
→ responsibility falls back to the D Group Leader.

---

## BR-040 — Follow-up Oversight

A D Group Leader may oversee appropriate follow-ups within their D Group.

The Coordinator may oversee appropriate follow-ups across the
discipleship ministry.

---

## BR-041 — Follow-up Deduplication

Repeated monitoring must not create unnecessary duplicate unresolved
follow-ups for the same person and equivalent active condition.

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

An unresolved follow-up may have a due date.

If the due date passes while it remains unresolved, it becomes overdue.

The MVP does not require automatic multi-level escalation.

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

- Active
- Inactive
- Transferred
- Archived

rather than casually deleting historical members.

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