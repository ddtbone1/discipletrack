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
→ D Group Gatherings
→ Attendance
→ Discipleship Meetings
→ Lesson Progress
→ Follow-up
→ Ministry Oversight

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

The Coordinator is a ministry operations role rather than primarily a
technical administration role.

---

## 8. D Group Leader

A D Group Leader is responsible for one active D Group.

Responsibilities include:

- view their D Group
- view Disciplers and Disciples within their D Group
- create/manage D Group gatherings
- record/review attendance
- oversee discipleship progress
- review lesson completion eligibility
- confirm lesson completion
- monitor members requiring attention
- oversee follow-ups within their D Group
- create D Group announcements

A D Group Leader does not automatically have access to unrelated D Groups.

---

## 9. Discipler

A Discipler is responsible for individually assigned Disciples within
their D Group.

A Discipler may:

- view their D Group
- view their assigned Disciples
- record authorized D Group attendance
- conduct and record discipleship meetings
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
- view their attendance history
- view their discipleship journey
- view completed lessons
- view their current lesson and meeting progress
- view appropriate announcements

A Disciple cannot:

- modify their own attendance
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

The join code may be regenerated by an authorized Admin.

Entering the correct join code does not automatically grant privileged
access.

New users initially join as normal church Members.

Privileged roles and D Group responsibilities are assigned separately.

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
→ Finalized

Finalized gatherings become part of the official attendance history.

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

Authorized D Group Leaders and Disciplers may record attendance.

The Coordinator may oversee/correct attendance according to permissions.

Members may view their own attendance history but cannot modify it.

The system must:

- prevent duplicate attendance for the same person and gathering
- preserve attendance history
- record relevant audit information
- calculate statistics from underlying attendance records

Individual attendance records are the source of truth.

---

## 17. Consecutive Absence Monitoring

The MVP monitors finalized D Group attendance for consecutive absences.

Default rule:

3 consecutive unexplained absences
→ Member Requires Attention
→ Follow-up Required

The threshold should be configurable rather than permanently hard-coded.

Example:

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

Each lesson requires four discipleship meetings specifically working
through that lesson.

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

The schedule is flexible and depends on participant availability.

The Discipler records the meeting after it occurs.

A meeting record should contain appropriate information such as:

- Disciple
- Discipler
- lesson
- meeting sequence/progress
- date/time
- appropriate notes
- recorded by
- recorded at

The exact schema will be determined during database design.

---

## 20. Lesson Completion

Each lesson requires four recorded Discipleship Meetings.

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

The D Group Leader reviews and confirms completion.

The Disciple does not need to separately confirm each meeting in the MVP.

---

## 21. Discipleship Journey

A Disciple's profile should clearly communicate their progress.

Examples:

- lessons completed
- current lesson
- current meeting count
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
→ Complete all 12 lessons
→ Eligible for Discipler Review
→ Coordinator Review
→ Promotion
→ Discipler

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

Disciple reaches absence threshold
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

---

## 24. Follow-up Assignment

When an attendance-based follow-up is created:

Assigned primary Discipler exists
→ Assign follow-up to Discipler

No assigned primary Discipler
→ Assign/fallback to D Group Leader

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

Visible to:
- members of that D Group

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
- attendance
- D Group
- Discipler
- announcements

### Discipler

Focus on:

- assigned Disciples
- discipleship progress
- members requiring attention
- follow-ups
- recent activity
- D Group announcements

### D Group Leader

Focus on:

- D Group health
- Disciplers
- Disciples
- attendance
- lessons awaiting completion confirmation
- follow-ups
- members requiring attention

### Coordinator

Focus on:

- D Groups
- ministry attendance
- discipleship progress
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

- Active
- Inactive
- Transferred
- Archived

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
- private messaging/chat
- announcement comments/reactions
- complex multi-church administration
- microservices
- distributed infrastructure

---

## 34. MVP Success Scenario

The MVP must support this end-to-end scenario:

1. The church workspace is configured.
2. A user installs DiscipleTrack and registers.
3. The user enters the church join code.
4. Membership is approved.
5. The Coordinator assigns the Member to a D Group.
6. The Coordinator assigns a primary Discipler.
7. The D Group holds a gathering.
8. Attendance is recorded and finalized.
9. The Discipler meets the Disciple for a curriculum lesson.
10. The Discipler records each discipleship meeting.
11. Four meetings make the lesson ready for completion.
12. The D Group Leader confirms lesson completion.
13. The Disciple continues through the 12-lesson curriculum.
14. Attendance monitoring detects repeated unexplained absences.
15. A follow-up is assigned to the appropriate responsible person.
16. Follow-up actions are recorded.
17. The follow-up is resolved.
18. Leadership can see the appropriate ministry outcome.
19. After all 12 lessons are completed, the Disciple becomes eligible
    for Discipler review.
20. The Coordinator may approve promotion to Discipler.

This is the primary acceptance workflow for the DiscipleTrack MVP.