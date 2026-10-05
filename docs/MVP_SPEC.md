# DiscipleTrack MVP Specification

*Document Status:* MVP Baseline  
*Last Updated:* October 2026 (revision 2026-10-02: lesson content, ADR-010; explicit lesson completion, ADR-011; monthly meeting history; see sections 9, 10, 18 to 21, 33 and 34)  
*Revision 2026-10-05:* D Group gatherings and gathering attendance removed; attendance exists only as a discipleship meeting outcome; one monitoring condition, consecutive recorded absences, for Disciples only; missed-meeting and inactivity conditions withdrawn (ADR-014). Discipler eligibility after confirmed Lesson 5, direct appointment, concurrent Disciple and Discipler responsibilities (ADR-012). Relationship-scoped Discipler progress visibility (N7); relationship-aware Journey (N8); factual 12-segment progress and no percentages (decisions 8, 22); read-only monthly meeting indicator (decisions 10, 11); "lessons completed this month" recorded as a candidate Reporting metric only (decision 9). Sections changed: 1, 2, 7 to 10, 15 and 16 (withdrawn, headings kept), 17, 19 to 24, 28 to 30, 32 to 34. Section 34 steps renumbered (simple numbered list; gathering steps removed, appointment steps rewritten).

---

## 1. Product Overview

*DiscipleTrack* is a mobile-first discipleship and member growth
monitoring system for churches. Attendance in DiscipleTrack is the
outcome of a discipleship meeting, recorded through Record Meeting; there
is no separate group, church-wide or event attendance (ADR-014).

DiscipleTrack is not intended to be an attendance tracker.

Its primary purpose is to help church leaders understand:

- Who is participating?
- Who is progressing through discipleship?
- Who is responsible for discipling whom?
- Who is becoming inactive?
- Who needs follow-up?
- Who is responsible for that follow-up?
- Has appropriate discipleship care actually happened?
- Who has completed the discipleship pathway and may be ready for greater
  responsibility?

The system should help prevent members from quietly becoming inactive
without their Discipler, D Group Leader, or Discipleship Coordinator
noticing and responding.

In the MVP, automated monitoring serves this purpose for Disciples only,
through explicitly recorded discipleship meeting outcomes (section 17).
Leaders and Disciplers have no automated monitoring in the MVP; their
participation is noticed through human oversight (ADR-014).

---

## 2. MVP Scope

The initial MVP is designed for *one local church*.

The architecture should avoid unnecessary assumptions that would make
future expansion to additional churches difficult, but complex
multi-church administration is not part of the MVP.

The MVP must support the complete core workflow:

Church Setup
→ User Registration
→ Church Membership Approval
→ D Group Assignment
→ Discipler Assignment
→ Discipleship Meetings, each recorded with every Disciple's outcome
→ Lesson Progress
→ Consecutive Recorded Absence Monitoring
→ Follow-up
→ Ministry Oversight

Attendance exists only as a discipleship meeting outcome, recorded
through Record Meeting: Journey, the selected discipleship, the current
lesson, Record Meeting, then each Disciple's outcome. D Group gatherings
and gathering attendance are not part of the MVP (ADR-014). There is no
D Group, church-wide or event attendance, no attendance dashboard or
percentage, and no Attendance navigation destination.

Leaders and Disciplers have no automated monitoring in the MVP
(ADR-014).

---

## 3. Platform

DiscipleTrack MVP is a mobile application.

Supported platforms:

- Android
- iOS

Primary technologies:

- Flutter
- Dart

A separate web administration portal is not part of the MVP.

---

## 4. Ministry Structure

DiscipleTrack models the church's discipleship ministry through D Groups.

Conceptually:

Church
└── D Groups
    └── D Group
        ├── D Group Leader
        ├── Disciplers
        │   └── Assigned Disciples
        └── Disciples

Each active D Group has:

- one primary D Group Leader
- zero or more Disciplers
- zero or more Disciples

A D Group Leader may lead only one active D Group at a time.

A Disciple belongs to only one active D Group at a time.

Each Disciple may have one active primary Discipler.

A Disciple may temporarily have no Discipler while waiting for assignment
or reassignment.

A Discipler may be responsible for multiple Disciples.

---

## 5. System Roles vs D Group Responsibilities

DiscipleTrack distinguishes between system/church authority and D Group
responsibility.

### System / Church Roles

- Admin
- Discipleship Coordinator
- Member

### D Group Responsibilities

- D Group Leader
- Discipler
- Disciple

These are separate concepts.

For example, a person may simultaneously be:

System Role:
Discipleship Coordinator

D Group Responsibility:
D Group Leader

This does not create a single combined global role.

D Group responsibility must not automatically grant unrelated
church-wide system authority.

---

## 6. Admin

The Admin is primarily responsible for system and access administration.

Responsibilities include:

- configure church/system information
- manage user accounts
- manage church memberships
- approve membership registrations where permitted
- assign or revoke privileged system roles
- manage Admin and Coordinator access
- disable or revoke account access
- manage system-level configuration
- access appropriate security/audit information

Admin is not intended to be the primary operator of everyday
discipleship workflows.

Admin access does not automatically imply access to private ministry-care
information.

---

## 7. Discipleship Coordinator

The Discipleship Coordinator is responsible for ministry-wide
discipleship operations.

Responsibilities include:

- oversee all D Groups
- create and manage D Groups
- assign D Group Leaders
- assign Disciplers
- assign Disciples to D Groups
- assign Disciples to Disciplers
- manage the discipleship curriculum
- review discipleship progress
- review members requiring attention
- oversee follow-ups
- review overdue follow-ups
- review members eligible for Discipler appointment, and appoint them
  (ADR-012)
- view ministry-level dashboard information
- create church-wide announcements
- manage ministry settings: the consecutive recorded absences threshold
  (one threshold, ADR-014) and follow-up due days

Church and system configuration, including the join code, remains with
the Admin. Ministry settings belong to the Coordinator because they
govern the follow-up workload the Coordinator is accountable for.

The Coordinator is a ministry operations role rather than primarily a
technical administration role.

---

## 8. D Group Leader

A D Group Leader is responsible for one active D Group.

Responsibilities include:

- view their D Group
- view Disciplers and Disciples within their D Group
- oversee discipleship progress and recorded meeting history
- review lesson completion eligibility
- confirm lesson completion
- monitor members requiring attention
- oversee follow-ups within their D Group
- create D Group announcements

The Leader's role in discipleship meetings is oversight. The Discipler
and Disciple arrange and record their own meetings. A Leader may record a
meeting on behalf of a Discipler as a fallback, but this is not the
normal workflow.

A D Group Leader does not automatically have access to unrelated D Groups.

---

## 9. Discipler

A Discipler is responsible for individually assigned Disciples within
their D Group.

A Discipler may:

- view their D Group
- view their assigned Disciples
- conduct discipleship meetings and record each one through Record
  Meeting, with every Disciple's outcome
- submit a lesson as finished when its material has been covered
- void meetings and outcomes they recorded themselves
- view the detailed lesson progress of their own currently assigned
  Disciples only (N7)
- receive follow-up responsibilities
- record follow-up actions and notes
- monitor the Disciples assigned to their care

A Discipler may have several Disciples.

A Discipler is not automatically a church-wide privileged system user.

A Discipler may also be a Disciple continuing their own journey: the
DISCIPLE and DISCIPLER responsibilities may be held at the same time, in
the same D Group (ADR-012; enforced from Slice 6; until then Migration
006 still refuses DISCIPLE with DISCIPLER). A person is never paired
with themselves (ADR-012, enforced from Slice 6). DISCIPLE still
excludes D Group Leader.

---

## 10. Disciple

A Disciple participates in the church's discipleship pathway.

A Disciple may:

- access their own profile
- view their D Group
- view their D Group Leader
- view their assigned Discipler
- view their discipleship journey
- view completed lessons
- view their current lesson and meeting progress
- view their own recorded meeting history, with their recorded outcome
  for each meeting, and a read-only monthly meeting indicator (section
  21)
- read the lesson material, also offline once it has synced
- view appropriate announcements

A Disciple cannot:

- record or change their own discipleship meeting outcomes
- mark their own lesson finished or complete
- appoint themselves as a Discipler
- assign themselves to a D Group
- assign themselves a Discipler
- access private follow-up/leadership notes

---

## 11. Registration and Church Joining

Users must install DiscipleTrack and create their own account before they
can be tracked as active participants in the MVP.

The MVP does not require creating offline member profiles for people who
have not registered.

Joining flow:

Install DiscipleTrack
→ Register/Login
→ Enter Church Join Code
→ Confirm Church
→ Request Membership
→ Approval
→ Enter Church Workspace

The church uses a reusable join code.

The join code may be regenerated by an authorized Admin through an
audited controlled operation.

Entering the correct join code does not automatically grant privileged
access.

Church confirmation and membership requests both run through trusted
controlled operations. The application cannot look up churches by join
code directly, the caller must already be authenticated, and both
operations are rate limited.

New users initially join as normal church Members.

A member awaiting approval can see only the minimum onboarding state,
including their own pending membership.

An approved member who has not yet been assigned to a D Group is a valid
and expected state. They can see their own profile, their membership,
their church, church-wide announcements and the curriculum. D Group
information becomes available when the relevant assignment exists.

Privileged roles and D Group responsibilities are assigned separately.

Registration collects the user's full name, which is required.

The initial church workspace, its join code, its settings, its
curriculum and its first privileged user are created by a trusted
deployment/bootstrap process rather than through the application. That
process is specified in DATABASE_CONSTRAINTS.md section 0.

---

## 12. Persistent Authentication

DiscipleTrack should behave like a modern mobile application.

### First Use

Open App
→ Register/Login
→ Verify Email
→ Join Church
→ Complete Onboarding
→ Enter App

Verify Email confirms ownership of the address with the code Supabase
Auth sends; no session exists until then. It is separate from the church
join code, which identifies the church.

Complete Onboarding is the one-time first-entry welcome shown when a
membership first becomes ACTIVE. Completing it is recorded on the
membership itself (church_memberships.onboarding_completed_at), so a
reinstall or another device never shows it again. It is distinct from
the splash screen, which appears on every launch while the session is
restored.

### Normal Subsequent Use

Open App
→ Restore Existing Session
→ Enter App

Users should not repeatedly log in whenever the application starts.

Re-authentication may be required when:

- the user logs out
- the session cannot be refreshed
- account access is revoked
- another security condition requires authentication

---

## 13. D Group Assignment

D Group membership is controlled by authorized ministry leadership.

The Coordinator manages D Group structure and assignments.

A Member does not freely assign themselves to a D Group.

A Disciple belongs to only one active D Group at a time.

Changes in D Group assignment must preserve meaningful history.

---

## 14. Discipler Assignment

Each active Disciple may have one primary Discipler.

A Discipler may care for multiple Disciples.

A Disciple must not have multiple active primary Disciplers at the same
time.

A Disciple may temporarily have no assigned Discipler while waiting for
assignment.

Discipler assignment is controlled by authorized ministry leadership.

Historical Discipler assignments must be preserved.

---

## 15. D Group Gatherings

Withdrawn (ADR-014). D Group gatherings are removed from the MVP; group,
church-wide and event attendance are out of scope (section 33).

---

## 16. D Group Attendance

Withdrawn (ADR-014). Attendance exists only as a discipleship meeting
outcome, recorded through Record Meeting (section 19).

---

## 17. Consecutive Recorded Absence Monitoring

The MVP has one monitoring condition, for Disciples only (ADR-014):

| Condition | Source | Subjects | Threshold |
|---|---|---|---|
| Consecutive recorded absences (CONSECUTIVE_ABSENCE) | Absent outcomes explicitly recorded on discipleship meetings | Disciples | one configurable threshold, default 3 |

Default rule:

3 consecutive recorded absences
→ Member Requires Attention
→ Follow-up Required

The threshold is configurable by the Coordinator rather than
permanently hard-coded. There is one threshold.

The streak counts the Disciple's explicitly recorded Absent outcomes, in
the order the meetings took place, under the current Discipler
assignment and across lesson boundaries. Present and Late break it.
Excused is not an absence and breaks it. A new Discipler starts with a
fresh streak. Voided meetings and voided outcomes do not count.

Monitoring uses only facts DiscipleTrack explicitly records. No record
is not an absence and not a missed meeting. No condition or follow-up
is ever generated from elapsed time, inactivity or the lack of a record,
and attendance is never inferred from missing data. When meetings stop
and nothing is recorded, leadership sees the Disciple's last recorded
meeting date in oversight views, for example "Last recorded meeting
Sep 28". That date is a displayed fact, never a condition. The
automated missed-meeting condition and an automated inactivity
condition are withdrawn, not deferred (ADR-014).

A person who is both a Disciple and a Discipler (ADR-012) is monitored
as a Disciple only. Leaders and Disciplers have no automated monitoring
in the MVP.

Example:

Absent
→ 1 consecutive recorded absence

Absent
→ 2 consecutive recorded absences

Excused
→ streak reset

Absent
→ 1 consecutive recorded absence

Monitoring must avoid creating duplicate unresolved follow-ups for the
same equivalent condition.

---

## 18. Discipleship Curriculum

The church uses one fixed discipleship curriculum consisting of
12 ordered lessons.

The curriculum must be represented as data rather than hard-coded into
Flutter.

Each lesson is worked through in as many credited discipleship meetings
as its material takes. Four is common and around six happens; the
number is not fixed (ADR-011). A lesson is finished when the Discipler
says its material has been covered, not when a count is reached.

Conceptually:

Curriculum
└── Lesson 1
    ├── Meeting 1
    ├── Meeting 2
    ├── ...
    └── Meeting n, then "finished" submitted by the Discipler

...

└── Lesson 12

Whether a minimum number of credited meetings applies before a lesson
can be submitted as finished is an open product decision (section 20).
The existing required_meetings value, seeded as four, is kept unchanged
until that decision.

Lesson names and content are church-owned curriculum data. DiscipleTrack
delivers the lesson material in the app (ADR-010): it originates as
Markdown, is published into Supabase, and is readable offline once it
has synced, without a per-lesson download. Reading never records
progress, and offline reading never allows an offline change.

---

## 19. Discipleship Meetings

It is normally a one-on-one or small discipleship meeting involving a
Discipler and their assigned Disciple(s).

Each Discipleship Meeting works through a specific curriculum lesson.

Because a meeting records exactly one lesson, every participant listed
in that meeting must be working on that same lesson. Disciples who are
on different lessons require separate meeting records.

Discipleship meeting attendance is each Disciple's recorded outcome in
their lesson-based discipleship meetings. It is the only attendance in
the MVP (ADR-014), and it is recorded only through Record Meeting:
Journey, the selected discipleship, the current lesson, Record Meeting,
then each Disciple's outcome.

DiscipleTrack does not schedule meetings. The Discipler and Disciple
arrange their meetings themselves, outside the app, and the Discipler
records what actually happened afterwards. The primary Discipler action
is Record Meeting, not "add attendance". Nothing is inferred when no
meeting is recorded (section 17).

A recorded meeting contains:

- the Discipler
- the lesson
- the date/time it took place, or was arranged to take place
- each expected Disciple, with an outcome
- shared meeting notes, optionally
- recorded by / recorded at

Outcomes per Disciple:

| Outcome | Counts toward lesson | Consecutive recorded absence streak |
|---|---|---|
| Present | Yes | Breaks |
| Late | Yes | Breaks |
| Absent | No | Increments |
| Excused | No | Breaks; not an absence |

Every meeting is recorded the same way, with each Disciple's outcome.
Example: the Discipler and Juan agree to meet on Wednesday and Juan does
not come. Afterwards the Discipler records the Lesson 1 meeting for
Wednesday with Juan's outcome Absent. Juan's progress does not change,
and the meeting appears in his meeting history with his recorded
outcome. A recorded meeting in which every outcome is Excused is not an
absence; it credits no participation and breaks the streak (ADR-014).

Example history for one lesson:

Lesson 1
Sep 3     Present   counted
Sep 10    Present   counted
Sep 17    Absent    not counted
Sep 24    Present   counted
Oct 1     Present   counted
Oct 8     Late      counted

→ the Discipler submits Lesson 1 as finished
→ Ready for Completion

In a small-group meeting, each Disciple's outcome is independent.

The date may not be in the future. A meeting both sides cancelled in
advance is not recorded.

Recorded meetings are not edited. A mistake is corrected by voiding the
record and recording it again. The Discipler may void meetings and
outcomes they recorded themselves. The D Group Leader and the
Coordinator retain oversight and fallback void authority. Every void is
audited, and a void may not undo a Completed lesson without the reopen
step in section 20.

The Discipler is the normal recorder. The D Group Leader or Coordinator
may record on behalf of the Discipler as a fallback.

The Disciple does not record or confirm their own meetings. There is one
authoritative record per meeting.

---

## 20. Lesson Completion

Meeting occurrence and lesson completion are separate (ADR-011).
Meetings record what happened; completion records that the material was
covered and confirmed.

Progress:

Not Started
→ In Progress (first credited meeting)
→ the Discipler submits: "We have finished covering this lesson"
→ Ready for Completion
→ D Group Leader confirmation
→ Completed
→ the next lesson becomes current

No meeting count moves a lesson to Ready for Completion, and recording a
meeting never completes a lesson. Present and Late meetings count as
lesson meetings. Absent and Excused are attendance outcomes and never
indicate that material was covered.

Meeting counts are shown as counts, for example "5 meetings recorded",
never "5 / 4". Where a typical number is defined it may be shown beside
the count, "5 meetings recorded · Typical: 4"; more meetings than typical
is never exceptional. There is no maximum.

Open product decision, still blocked and blocking for lesson completion
(ADR-011; decision 23): "Is there a minimum number of credited meetings
required before a lesson can be marked finished, or is the number only
recommended / completely flexible depending on when the lesson material
is actually completed?" The options are A, no minimum; B, a minimum
number of credited meetings; C, a recommended number only. In every
case the meeting count never completes a lesson automatically: the
Discipler explicitly indicates that the lesson is fully covered, and the
approved confirmation workflow (Leader confirmation) determines
Completed. Until it is answered, a lesson can be submitted once it has
at least one credited meeting, and the rule is held in one policy point
so the answer is a contained change.

The Discipler conducting the lesson normally submits it. The D Group
Leader or the Coordinator may submit on the Discipler's behalf as a
fallback. A submission may be withdrawn while the lesson awaits
confirmation.

Meetings may continue while the lesson awaits confirmation. They are
recorded and credited to the same lesson and do not withdraw the
submission.

The D Group Leader reviews and confirms completion. The app asks the
Leader to confirm explicitly, because a confirmed lesson can be
reopened only by the Coordinator.

The Coordinator may confirm as a ministry-oversight fallback, for
example where a D Group currently has no active Leader. The Leader
remains the normal authority, and every confirmation records who
confirmed it.

Lessons are worked through in order. A Disciple may begin lesson N only
once lesson N-1 is completed. Lesson 1 is exempt.

A completed lesson is protected. A meeting correction never un-completes
it. Correcting a meeting record that would leave a completed lesson
with fewer credited meetings than a submission needs requires an
explicit authorized reopen step first.

The Disciple does not need to separately confirm each meeting in the MVP.

---

## 21. Discipleship Journey

A Disciple's journey should clearly and factually communicate their
progress:

- lessons completed, for example "5 of 12 completed"
- current lesson, for example "Lesson 6 of 12" or "Lesson 6 awaiting
  confirmation"
- current meeting count, shown as a count
- recorded meeting history, with the Disciple's recorded outcome for
  each meeting
- a read-only monthly meeting indicator
- completion status

Progress is shown as a factual 12-segment visualization (decision 22):

Lesson 6 of 12
✓ ✓ ✓ ✓ ✓ ● ○ ○ ○ ○ ○ ○
5 of 12 completed

A segment is completed (✓) only when its lesson is confirmed Completed.
Ready for Completion does not count; it is shown as "Lesson 6 awaiting
confirmation". The current lesson is ● and upcoming lessons are ○. The
total comes from the active curriculum, never a fixed literal. The
meeting count does not determine progress. There are no percentages and
no evaluative labels (decision 8).

The monthly meeting indicator is read-only and historical, derived from
the dates of recorded discipleship meetings (decisions 10, 11). It
answers "When did this discipleship actually meet?". Days without a
recorded meeting are plain, with no warning. It has no manual events, no
scheduling and no gathering attendance, and there is no Leader
group-wide calendar.

The journey has one home, the Journey destination, and it follows the
person's relationships rather than a role mode (N8):

- a Disciple only: Journey shows My Journey, with no tab bar
- a Disciple who is also the assigned Discipler of at least one
  Disciple: Journey shows two tabs, My Journey and My Disciples
- a Discipler only: Journey shows My Disciples directly

My Journey is the journey in which the user is the Disciple. My
Disciples lists the Disciples for whom the user is the assigned
Discipler; selecting one opens that Disciple's journey and monthly
meeting indicator. Tabs appear only when both relationships exist, and
there is no global role-mode switch. Which tab opens first when both
exist is open (D11; proposed default My Journey, remembered per device).

Home and Profile show a short summary derived from the same
relationships and link to Journey. The D Group Leader and the
Coordinator see the same journey inside Disciple detail. Detailed
progress is visible to the Disciple themself, their currently assigned
Discipler only (N7), the Leader of their current D Group and the
Coordinator.

States are factual. The journey never compares a Disciple with others,
ranks people or groups, or labels anyone as ahead or behind.

Progress is derived from underlying lesson and meeting records rather
than being the sole authoritative record.

---

## 22. Discipler Appointment

Eligibility never makes a Disciple a Discipler automatically (ADR-012).

The basic pathway is:

Disciple
→ Lesson 5 of the active curriculum confirmed Completed
→ Eligible for Discipler appointment (derived)
→ Coordinator appoints
→ Disciples assigned
→ the person's own journey continues through Lesson 12

Eligibility is derived from confirmed Completed of Lesson 5. In
Progress and Ready for Completion do not count. Eligibility is never
stored and never changes anything by itself.

Eligibility is not appointment. The Coordinator appoints an eligible
Disciple directly; there is no acceptance workflow. Appointment is
attributed and audited, and creates a Discipler responsibility in the
same D Group as the person's Disciple responsibility.

Appointment does not end the person's Disciple responsibility, their own
Discipler assignment or their lesson progress. They continue through
Lesson 12 under their own Discipler while discipling others (ADR-012;
enforced from Slice 6; until then Migration 006 still refuses DISCIPLE
with DISCIPLER). Slice 6 (Discipler Progression) builds appointment.

Historical discipleship progress remains preserved.

D2 is decided: the eligibility lesson comes from one policy function
(`private.discipler_eligibility_lesson()`), not a church setting. Open decisions, listed
and not decided here: D5, D6, D7 (reciprocal pairing: may A
disciple B while B disciples A), D8, D9 and D14. See ADR-012.

---

## 23. Follow-ups

A follow-up represents intentional care after a member requires
attention.

Example:

Disciple reaches the consecutive recorded absences threshold
→ Follow-up created
→ Responsible person contacts/checks on Disciple
→ Action recorded
→ Outcome recorded
→ Follow-up resolved

Possible actions include:

- contacted
- sent message
- called
- personal conversation
- scheduled visit
- other appropriate action

A follow-up should identify:

- person requiring attention
- reason
- D Group
- responsible person
- status
- created date
- due date where applicable
- actions/notes
- resolution

Basic lifecycle:

Required
→ In Progress
→ Resolved

Detection and care have independent lifecycles. If a later recorded
outcome breaks the streak, the detected condition resolves but the follow-up does not
close by itself. Someone still records what care happened and closes it
deliberately.

---

## 24. Follow-up Assignment

In the MVP, monitoring applies to Disciples only, through consecutive
recorded absences (section 17, ADR-014).

When a monitoring-based follow-up is created, responsibility is
assigned using this chain, always resolving to a different person than
the one the follow-up concerns:

Disciple (triggered by consecutive recorded absences)
→ assigned primary Discipler
→ otherwise D Group Leader
→ otherwise Coordinator

The chain also defines branches for a Discipler subject (D Group Leader,
otherwise Coordinator) and a D Group Leader subject (Coordinator). These
branches have no MVP trigger (ADR-014); they are kept as architecture
and are not built until a factual condition for those subjects is
approved.

Where one person holds several responsibilities, the chain continues
until a different person is reached.

Because the chain ends at the Coordinator, the church always keeps at
least one active Coordinator.

The D Group Leader can oversee follow-ups within their D Group.

The Coordinator can oversee follow-ups across the ministry.

---

## 25. Overdue Follow-ups

The MVP does not require complex automatic escalation.

A follow-up may have a due date.

When the due date passes without resolution:

Open Follow-up
→ Overdue

Overdue follow-ups should be visible to the appropriate D Group Leader
and Coordinator.

Automated multi-level escalation and push reminders are post-MVP features.

---

## 26. Follow-up Privacy

Follow-up notes are ministry-care information.

For the MVP, appropriate follow-up information may be visible to:

- assigned Discipler
- relevant D Group Leader
- Discipleship Coordinator

The Disciple does not automatically see internal follow-up notes.

Admin does not automatically receive access merely because they
administer the system.

More granular confidential-note visibility may be introduced later if
required.

---

## 27. Announcements

The MVP supports simple announcements.

Two scopes are supported:

### Church Announcement

Created by:
- Discipleship Coordinator

Visible to:
- appropriate church members

### D Group Announcement

Created by:
- D Group Leader
- Discipleship Coordinator, as ministry oversight

Visible to:
- members of that D Group
- Discipleship Coordinator

Announcements should remain simple.

The MVP does not require:

- comments
- reactions
- chat
- channels
- read receipts
- complex audience builders

---

## 28. Member Profiles

Every registered user has a profile.

Profiles should be informative rather than acting only as contact
information pages.

Depending on authorization, a profile may communicate:

- identity
- system/ministry responsibility
- D Group
- D Group Leader
- assigned Discipler
- assigned Disciples
- recorded discipleship meeting outcomes, for example "2 consecutive
  recorded absences" or "Last recorded meeting Sep 28"
- discipleship progress, for example "5 of 12 lessons completed"
- current lesson
- recent activity
- relevant follow-up information

The information displayed depends on who is viewing the profile and is
derived from the relationship between the viewer and the person viewed
(N7, N8). There is no attendance or progress percentage (decision 8).

Users should not gain access to sensitive information simply because a
profile UI exists.

---

## 29. Dashboard / Home

Home should provide actionable, role-relevant information. What Home
shows is derived from the person's current relationships (a Disciple, an
assigned Discipler, a Leader, the Coordinator), not from a role-mode
switch. A person who is both a Disciple and a Discipler sees both
summaries, each linking to Journey (N8). Home shows factual counts and
dates, never percentages (decision 8).

### Disciple

Focus on:

- current lesson, for example "Lesson 6 of 12"
- meeting progress
- journey summary, for example "5 of 12 completed", linking to My
  Journey
- recorded meeting history
- D Group
- Discipler
- announcements

### Discipler

Action-oriented. Focus on:

- assigned Disciples, each with current lesson and meeting progress
- Record Meeting
- members requiring attention
- follow-ups
- recent activity
- D Group announcements

### D Group Leader

Oversight-oriented, not an attendance-entry workspace. Focus on:

- D Group health
- discipleship progress per Disciple
- recorded meeting facts: last recorded meeting, consecutive recorded
  absences
- Disciplers and the last recorded meeting of each of their Disciples
- lessons submitted as finished and awaiting completion confirmation
- members requiring attention
- follow-ups
- recent discipleship activity

### Coordinator

Focus on:

- D Groups
- discipleship progress and last recorded meeting dates
- members requiring attention
- unresolved/overdue follow-ups
- unassigned members
- members eligible for Discipler appointment (ADR-012)
- ministry-wide announcements

"Lessons completed this month" is a candidate Reporting / Oversight
metric only, not defined and not governing (decision 9). Before it is
adopted it needs a precise definition; which timestamp or event counts
(likely lessons reaching confirmed Completed in the month, that is
their completion time); church time zone semantics; a privacy review
(RBAC_RLS_MATRIX.md section 2b); and small-population suppression before
broad member visibility. It is owned by Slice 11, Reporting / Oversight,
and does not block Slice 5.

The same application should use a consistent design system while
prioritizing different information according to responsibility.

---

## 30. Member Lifecycle

Normal member records should not be casually deleted.

Possible lifecycle states include:

- Pending
- Active
- Inactive
- Transferred
- Archived

A person keeps one membership record per church for their whole history
with that church. Someone who leaves and returns reactivates the same
record rather than starting a new one, so their meeting history,
progress and care history stay continuous.

Transferred means the person transferred out of this church. Moving a
Disciple between D Groups is a separate concept and does not change
their church membership status.

Reactivating a membership does not restore previous D Group
responsibilities. Those are assigned again through the normal ministry
workflow.

Administrative membership status must remain distinct from discipleship
engagement.

A person may remain an active church member while their discipleship
participation is declining.

---

## 31. Security

The MVP must enforce:

- authentication
- church isolation
- system-role authorization
- D Group authorization
- assignment-based authorization
- backend/database-side authorization
- input validation
- database integrity constraints

Flutter is an untrusted client.

Hiding a button or screen is not sufficient authorization.

---

## 32. Auditability

Important actions should retain enough information to determine:

- what happened
- who performed it
- when it happened

Important examples include:

- role changes
- D Group assignments
- Discipler assignments
- discipleship meeting records and voids, including each Disciple's
  recorded outcome
- lesson completion
- Discipler appointment (ADR-012)
- follow-up actions

---

## 33. Out of Scope for MVP

The following are intentionally postponed:

- QR attendance
- automated push-notification workflows
- SMS
- email automation
- AI-generated ministry insights
- predictive inactivity scoring
- automatic multi-level follow-up escalation
- event management
- D Group gatherings and gathering or event attendance tracking
  (ADR-014); attendance exists only as a discipleship meeting outcome
- automated missed-meeting or inactivity conditions: monitoring never
  infers anything from elapsed time or the lack of a record (ADR-014)
- advanced reporting
- full offline synchronization (a read-only device copy of what the
  person may already see, and offline lesson reading under ADR-010, are
  not synchronization: nothing is written offline)
- web administration portal
- meeting scheduling or calendar functionality, meaning scheduling,
  planning, invitations or calendar management of meetings. A read-only
  monthly view of meetings already recorded, derived from their dates,
  is not calendar functionality and is in scope.
- meeting photo attachments (a possible additive future capability;
  would add a separate attachment table and file storage without
  changing meeting records)
- private messaging/chat
- announcement comments/reactions
- complex multi-church administration
- microservices
- distributed infrastructure

---

## 34. MVP Success Scenario

The MVP must support this end-to-end scenario:

1. The church workspace is provisioned by the trusted bootstrap process
   specified in DATABASE_CONSTRAINTS.md section 0.
2. A user installs DiscipleTrack and registers.
3. The user enters the church join code.
4. Membership is approved.
5. The Coordinator assigns the Member to a D Group.
6. The Coordinator assigns a primary Discipler.
7. The Discipler meets the Disciple for a curriculum lesson.
8. The Discipler records each discipleship meeting through Record
   Meeting, with the Disciple's outcome.
9. When the lesson material has been covered, the Discipler submits the
   lesson as finished, making it ready for completion.
10. The D Group Leader confirms lesson completion.
11. The Disciple continues through the 12-lesson curriculum.
12. Monitoring detects consecutive recorded absences for a Disciple.
13. A follow-up is assigned to the appropriate responsible person.
14. Follow-up actions are recorded.
15. The follow-up is resolved.
16. Leadership can see the appropriate ministry outcome.
17. Once Lesson 5 is confirmed Completed, the Disciple is eligible for
    Discipler appointment (derived, ADR-012).
18. The Coordinator may appoint the Disciple as a Discipler in the same
    D Group; Disciples are assigned to them.
19. The person continues their own journey through Lesson 12.

This is the primary acceptance workflow for the DiscipleTrack MVP.