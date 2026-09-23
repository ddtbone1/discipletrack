# DiscipleTrack MVP Specification

*Document Status:* MVP Baseline  
*Last Updated:* September 2026

---

## 1. Product Overview

*DiscipleTrack* is a mobile-first discipleship, attendance, and member
growth monitoring system for churches.

DiscipleTrack is not intended to be only an attendance tracker.

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
→ Discipleship Meetings, held or missed
→ Lesson Progress
→ Discipleship Consistency Monitoring
→ Follow-up
→ Ministry Oversight

D Group Gatherings and gathering attendance are also part of the MVP.
They are secondary to the discipleship workflow above: they record group
participation and monitor Leaders and Disciplers, but they do not drive
lesson progress or Disciple monitoring.

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
- oversee D Group gatherings
- review attendance
- review discipleship progress
- review members requiring attention
- oversee follow-ups
- review overdue follow-ups
- review members eligible for Discipler promotion
- view ministry-level dashboard information
- create church-wide announcements
- manage ministry settings such as the consecutive absence threshold,
  the consecutive missed-meeting threshold and follow-up due days

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
- oversee discipleship progress and meeting consistency
- create/manage D Group gatherings
- record/review gathering attendance
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
- conduct and record discipleship meetings, including missed meetups
- void meetings and outcomes they recorded themselves
- record authorized D Group gathering attendance
- view their Disciples' lesson progress
- receive follow-up responsibilities
- record follow-up actions and notes
- monitor the Disciples assigned to their care

A Discipler is not automatically a church-wide privileged system user.

A person cannot simultaneously hold active Disciple and Discipler
responsibilities.

---

## 10. Disciple

A Disciple participates in the church's discipleship pathway.

A Disciple may:

- access their own profile
- view their D Group
- view their D Group Leader
- view their assigned Discipler
- view their gathering attendance history
- view their discipleship journey
- view completed lessons
- view their current lesson and meeting progress
- view their own meeting history, including missed meetups
- view appropriate announcements

A Disciple cannot:

- modify their own attendance
- record or change their own discipleship meeting outcomes
- mark their own lesson complete
- promote themselves
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
→ Join Church
→ Complete Onboarding
→ Enter App

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

A D Group Gathering is a meeting involving the overall D Group.

It is separate from a Discipleship Meeting.

Gathering attendance is the participation of ministry workers and group
members in the D Group gathering context. Gatherings are secondary to
the core discipleship workflow and do not affect lesson progress.

D Group Gatherings do not require a fixed recurring schedule.

Gatherings are created based on the actual date/time arranged by the
group.

A gathering may include:

- D Group
- date/time
- topic/title
- notes
- status
- attendance

MVP lifecycle:

Draft
├── → Finalized
└── → Cancelled

Finalized gatherings become part of the official attendance history.

Cancelled represents a gathering that did not occur. It is excluded from
attendance statistics, monitoring and follow-up generation.

Only a Draft gathering may be finalized or cancelled. Both Finalized and
Cancelled are final states in the MVP. Retracting an already finalized
gathering is not ordinary cancellation and would require its own
controlled operation.

Attendance entered while a gathering was Draft is preserved if the
gathering is later cancelled, but it never becomes official.

Authorized D Group Leaders may cancel gatherings for their own D Group.
The Coordinator may cancel across the ministry. Disciplers may not
create or cancel gatherings.

---

## 16. D Group Attendance

Attendance is recorded for participants of the D Group, including where
applicable:

- D Group Leader
- Disciplers
- Disciples

Supported attendance states:

- Present
- Absent
- Late
- Excused

Late counts as attended for absence monitoring.

Excused does not count as an unexplained absence and breaks a consecutive
absence streak.

Authorized D Group Leaders and Disciplers may record attendance for
other members of their D Group.

The Coordinator may oversee/correct attendance according to permissions.

Nobody records their own attendance, in any role. Where a D Group's only
authorized recorder is its Leader, another Discipler in that group or
the Coordinator records the Leader's status. A gathering cannot be
finalized until every eligible member has a status, so that step must
happen first.

Members may view their own attendance history but cannot modify it.

The system must:

- prevent duplicate attendance for the same person and gathering
- preserve attendance history
- record relevant audit information
- calculate statistics from underlying attendance records

Individual attendance records are the source of truth.

---

## 17. Consecutive Absence Monitoring

Monitoring sources are role-specific:

| Who | Monitored through | Condition |
|---|---|---|
| D Group Leaders and Disciplers | finalized D Group gathering attendance | Consecutive Absence |
| Disciples | discipleship meeting outcomes | Consecutive Missed Meetings |

Gathering attendance never raises a condition for a Disciple, so a
Disciple has one absence-condition stream rather than two.

Default rule for each:

3 consecutive unexplained absences
→ Member Requires Attention
→ Follow-up Required

Each threshold is configurable separately rather than permanently
hard-coded.

The Disciple streak counts Absent meetup outcomes under the current
Discipler assignment. Present and Late break it. Excused is not an
absence and breaks it. A new Discipler starts with a fresh streak.

Monitoring only sees what was recorded. When meetings stop and nothing
is recorded, leadership notices through the Disciple's last meeting
date. An automated inactivity condition is future scope.

Example, which applies to both streaks:

Absent
→ streak 1

Absent
→ streak 2

Excused
→ streak reset

Absent
→ streak 1

Late and Present are considered attended for absence monitoring.

Monitoring must avoid creating duplicate unresolved follow-ups for the
same equivalent condition.

---

## 18. Discipleship Curriculum

The church uses one fixed discipleship curriculum consisting of
12 ordered lessons.

The curriculum must be represented as data rather than hard-coded into
Flutter.

Each lesson requires four credited discipleship meetings specifically
working through that lesson. The requirement is data
(required_meetings), seeded as four.

Conceptually:

Curriculum
└── Lesson 1
    ├── Meeting 1
    ├── Meeting 2
    ├── Meeting 3
    └── Meeting 4

...

└── Lesson 12
    ├── Meeting 1
    ├── Meeting 2
    ├── Meeting 3
    └── Meeting 4

Lesson names/content may be managed as church-owned curriculum data.

---

## 19. Discipleship Meetings

A Discipleship Meeting is separate from a D Group Gathering.

It is normally a one-on-one or small discipleship meeting involving a
Discipler and their assigned Disciple(s).

Each Discipleship Meeting works through a specific curriculum lesson.

Because a meeting records exactly one lesson, every participant listed
in that meeting must be working on that same lesson. Disciples who are
on different lessons require separate meeting records.

Discipleship meeting attendance is the participation and consistency of
Disciples in their lesson-based discipleship meetings. It is the primary
discipleship consistency signal.

DiscipleTrack does not schedule meetings. The Discipler and Disciple
arrange their meetups themselves, outside the app, and the Discipler
records what actually happened afterwards. The primary Discipler action
is Record Meeting, not "add attendance".

A recorded meeting contains:

- the Discipler
- the lesson
- the date/time it took place, or was arranged to take place
- each expected Disciple, with an outcome
- shared meeting notes, optionally
- recorded by / recorded at

Outcomes per Disciple:

| Outcome | Counts toward lesson | Missed-meeting streak |
|---|---|---|
| Present | Yes | Breaks |
| Late | Yes | Breaks |
| Absent | No | Increments |
| Excused | No | Breaks; not an absence |

A missed meetup is recorded the same way as a held one. Example: the
Discipler and Juan agree to meet on Wednesday and Juan does not come.
Afterwards the Discipler records the Lesson 1 meetup for Wednesday with
Juan marked Absent. Juan's progress does not change, and the missed
meetup appears in his meeting history.

Example history for one lesson:

Lesson 1
Meeting 1       Present   counted
Meeting 2       Present   counted
Missed meetup   Absent    not counted
Meeting 3       Present   counted
Meeting 4       Present   counted

→ Ready for Completion

In a small-group meeting, each Disciple's outcome is independent.

The date may not be in the future. A meetup both sides cancelled in
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

Each lesson requires four credited Discipleship Meetings. Missed meetups
do not count.

Progress:

Meeting 1/4
→ Meeting 2/4
→ Meeting 3/4
→ Meeting 4/4
→ Ready for Completion
→ D Group Leader Confirmation
→ Completed

Reaching 4/4 meetings does not automatically complete the lesson.

At 4/4, the lesson becomes eligible/ready for completion.

Meetings may continue while the lesson awaits confirmation. Additional
legitimate meetings are recorded and credited to the same lesson, so a
lesson may show, for example, five credited meetings against a
requirement of four. They are not clamped or discarded, and the lesson
remains Ready for Completion until confirmed.

The D Group Leader reviews and confirms completion.

The Coordinator may confirm as a ministry-oversight fallback, for
example where a D Group currently has no active Leader. The Leader
remains the normal authority, and every confirmation records who
confirmed it.

Lessons are worked through in order. A Disciple may begin lesson N only
once lesson N-1 is completed. Lesson 1 is exempt.

A completed lesson is protected. Correcting a meeting record that would
drop a completed lesson below its requirement needs an explicit
authorized reopen step first.

The Disciple does not need to separately confirm each meeting in the MVP.

---

## 21. Discipleship Journey

A Disciple's profile should clearly communicate their progress.

Examples:

- lessons completed
- current lesson
- current meeting count
- meeting history, including missed meetups
- overall progress
- completion status

Example:

Lesson 1 — Completed
Lesson 2 — Completed
Lesson 3 — Meeting 3/4
Lesson 4 — Not Started

Overall progress is derived from underlying lesson/meeting records rather
than being the sole authoritative record.

---

## 22. Disciple-to-Discipler Promotion

Completing the discipleship curriculum does not automatically make a
Disciple a Discipler.

The basic pathway is:

Disciple
→ Complete every lesson of the active curriculum
→ Eligible for Discipler Review
→ Coordinator Review
→ Promotion
→ Discipler

The MVP curriculum contains twelve lessons, but eligibility is evaluated
against the church's active curriculum rather than a fixed number.

Curriculum completion is an eligibility requirement.

The Coordinator makes the actual promotion decision.

Once promoted, the person's active D Group responsibility changes
according to the approved ministry workflow.

Historical discipleship progress remains preserved.

---

## 23. Follow-ups

A follow-up represents intentional care after a member requires
attention.

Example:

Disciple reaches the missed-meeting threshold
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

Detection and care have independent lifecycles. If the person resumes
attending, the detected condition resolves but the follow-up does not
close by itself. Someone still records what care happened and closes it
deliberately.

---

## 24. Follow-up Assignment

Monitoring applies to D Group Leaders, Disciplers and Disciples, through
the role-specific sources in section 17.

When a monitoring-based follow-up is created, responsibility is
assigned using this chain, always resolving to a different person than
the one the follow-up concerns:

Disciple
→ assigned primary Discipler
→ otherwise D Group Leader
→ otherwise Coordinator

Discipler
→ D Group Leader
→ otherwise Coordinator

D Group Leader
→ Coordinator

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
- attendance information
- discipleship progress
- current lesson
- recent activity
- relevant follow-up information

The information displayed depends on who is viewing the profile.

Users should not gain access to sensitive information simply because a
profile UI exists.

---

## 29. Dashboard / Home

Home should provide actionable, role-relevant information.

### Disciple

Focus on:

- current lesson
- meeting progress
- overall journey
- meeting history
- gathering attendance, as secondary information
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
- meeting consistency: last meeting, missed meetups
- Disciplers and how recently their Disciples met
- lessons awaiting completion confirmation
- members requiring attention
- follow-ups
- recent discipleship activity
- D Group gathering attendance, as secondary information

### Coordinator

Focus on:

- D Groups
- discipleship progress and meeting consistency
- members requiring attention
- ministry gathering attendance, as secondary information
- unresolved/overdue follow-ups
- unassigned members
- promotion eligibility
- ministry-wide announcements

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
record rather than starting a new one, so their attendance, progress and
care history stay continuous.

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
- attendance changes
- discipleship meeting records
- lesson completion
- promotion
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
- advanced reporting
- full offline synchronization
- web administration portal
- meeting scheduling or calendar functionality
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
7. The D Group holds a gathering.
8. Gathering attendance is recorded and finalized.
9. The Discipler meets the Disciple for a curriculum lesson.
10. The Discipler records each discipleship meeting, including any
    missed meetup.
11. Four credited meetings make the lesson ready for completion.
12. The D Group Leader confirms lesson completion.
13. The Disciple continues through the 12-lesson curriculum.
14. Monitoring detects repeated missed meetups for a Disciple, or
    repeated gathering absences for a Leader or Discipler.
15. A follow-up is assigned to the appropriate responsible person.
16. Follow-up actions are recorded.
17. The follow-up is resolved.
18. Leadership can see the appropriate ministry outcome.
19. After every lesson of the active curriculum is completed, twelve in
    the MVP, the Disciple becomes eligible for Discipler review.
20. The Coordinator may approve promotion to Discipler.

This is the primary acceptance workflow for the DiscipleTrack MVP.