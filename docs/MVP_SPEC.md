# DiscipleTrack MVP Specification

## 1. Product Overview

*DiscipleTrack* is a mobile-first discipleship, attendance, and member
growth monitoring system for churches.

DiscipleTrack is not intended to be only an attendance tracker.

Its primary purpose is to help a church understand:

- Who is participating in discipleship?
- Who is responsible for discipling whom?
- Who is progressing through the discipleship process?
- Who is becoming inactive?
- Who needs follow-up?
- Who is responsible for that follow-up?
- Has appropriate discipleship care actually happened?

The system should help prevent disciples from quietly becoming inactive
without their Discipler, D Group Leader, or Discipleship Coordinator
noticing and responding.

---

## 2. Core Ministry Structure

DiscipleTrack models the church's discipleship ministry using D Groups.

Conceptually:

Church
└── D Groups
    ├── D Group A
    │   ├── D Group Leader
    │   ├── Disciplers
    │   └── Disciples
    │
    ├── D Group B
    │   ├── D Group Leader
    │   ├── Disciplers
    │   └── Disciples
    │
    └── D Group C
        ├── D Group Leader
        ├── Disciplers
        └── Disciples

A D Group represents an active discipleship community within a church.

Each active D Group has one primary D Group Leader.

A D Group may contain multiple Disciplers and multiple Disciples.

The exact relationship between individual Disciplers and the Disciples
they personally care for will be finalized during domain/database design.

---

## 3. System Roles vs D Group Responsibilities

DiscipleTrack distinguishes between church/system authority and
responsibility inside a D Group.

### System / Church Roles

- Admin
- Discipleship Coordinator
- Member

### D Group Responsibilities

- D Group Leader
- Discipler
- Disciple

These concepts must not be treated as identical.

For example, a church Member may be assigned as a Discipler inside a
specific D Group without receiving church-wide administrative authority.

Likewise, becoming a D Group Leader does not automatically make the
person an Admin or Discipleship Coordinator.

---

## 4. MVP Goal

The MVP must support one complete discipleship workflow:

Church Setup
→ User Registration
→ Church Membership Approval
→ D Group Creation
→ D Group Leader Assignment
→ Discipler / Disciple Assignment
→ Curriculum Setup
→ D Group Session
→ Attendance
→ Discipleship Progress
→ Attendance Monitoring
→ Follow-up
→ Ministry Oversight

The MVP is successful when a church can manage its basic D Group
discipleship workflow and identify disciples requiring attention without
depending on spreadsheets for its core monitoring process.

---

## 5. Platform

DiscipleTrack MVP is a mobile application.

Supported platforms:

- Android
- iOS

Primary client technology:

- Flutter
- Dart

A separate web administration application is not part of the MVP.

---

## 6. Admin

The Admin is responsible primarily for system administration and access.

Typical responsibilities include:

- configure church information
- manage user accounts
- manage church memberships
- approve membership registrations where authorized
- assign or revoke privileged system roles
- manage Admin and Coordinator access
- disable or revoke account access
- manage system-level church settings
- access appropriate audit/security information

An Admin may technically have broad system access, but routine
discipleship operations should normally be performed by the
Discipleship Coordinator.

The Admin should not need to manage everyday attendance or follow-ups.

---

## 7. Discipleship Coordinator

The Discipleship Coordinator is responsible for church-wide discipleship
operations.

Typical responsibilities include:

- oversee all D Groups
- create and manage D Groups
- assign D Group Leaders
- oversee Disciplers and Disciples
- manage D Group membership assignments
- manage discipleship curriculum
- review D Group sessions
- monitor attendance
- monitor discipleship progress
- identify disciples requiring attention
- review unresolved follow-ups
- oversee follow-up accountability
- reassign responsibilities when appropriate
- view ministry-level dashboard information

The Coordinator is an operational ministry role rather than primarily a
technical/system administration role.

---

## 8. D Group Leader

A D Group Leader is responsible for a specific D Group.

Typical responsibilities include:

- view their D Group
- view the Disciplers and Disciples within their authorized D Group
- oversee D Group sessions
- create/manage sessions where permitted
- record or review attendance
- monitor discipleship progress
- monitor disciples requiring attention
- oversee follow-up work within the D Group
- record appropriate notes/actions

Being a D Group Leader does not automatically grant access to unrelated
D Groups.

---

## 9. Discipler

A Discipler is a church Member who has discipleship responsibility within
a D Group.

A Discipler may:

- view their D Group
- view disciples they are authorized to care for
- view appropriate discipleship progress
- participate in attendance/session workflows where permitted
- receive follow-up responsibilities
- record follow-up actions and notes
- monitor the disciples assigned to their care

A Discipler is not automatically a church-wide privileged system user.

Authorization should depend on their actual D Group and disciple
assignments.

---

## 10. Disciple

A Disciple participates in the discipleship process.

A Disciple may:

- access their own account
- view appropriate personal profile information
- view their D Group
- view their discipleship progress
- view appropriate curriculum information
- view appropriate session/group information

A Disciple cannot assign themselves as:

- Admin
- Coordinator
- D Group Leader
- Discipler

Such responsibilities require an authorized assignment process.

---

## 11. Church Onboarding

A church is initially created by an authorized Admin.

Users must join a specific church.

Intended joining methods include:

- church invitation code
- invitation link
- QR invitation

The MVP may initially implement a short church invitation code while
keeping the architecture compatible with invitation links and QR
invitations later.

Normal registration does not grant privileged access.

A typical flow is:

Install DiscipleTrack
→ Register
→ Enter Church Code
→ Confirm Church
→ Request Membership
→ Approval
→ Enter Church Workspace

Privileged responsibilities must be assigned by authorized users.

---

## 12. Persistent Authentication

DiscipleTrack must behave like a modern mobile application.

### First Use

Open App
→ Register/Login
→ Join Church
→ Complete Required Onboarding
→ Enter App

### Normal App Open

Open App
→ Restore Existing Session
→ Enter App

Users should not repeatedly log in whenever the application starts.

Re-authentication may occur when:

- the user logs out
- the session can no longer be refreshed
- access has been revoked
- another security condition requires authentication

Push notification/device registration will be introduced when
notification functionality is implemented.

---

## 13. Member Management

A church Member represents a person belonging to the church workspace.

Basic information may include:

- full name
- contact information
- date joined
- age group
- baptism status
- membership status

Discipleship information may include:

- D Group
- D Group responsibility
- assigned Discipler where applicable
- curriculum
- current discipleship stage
- progress
- attendance history
- follow-up history

Historical ministry information should remain meaningful when
assignments change.

---

## 14. D Group Management

Authorized users can create and manage D Groups.

A D Group may contain:

- name
- primary D Group Leader
- Disciplers
- Disciples
- meeting schedule
- meeting location
- status

Each active D Group should have one primary D Group Leader.

D Group membership and responsibility should be represented in a way
that allows historical assignments to be preserved.

---

## 15. Discipleship Curriculum

Church-specific discipleship curriculum must not be hard-coded into
Flutter.

Authorized users can configure curriculum through DiscipleTrack.

Basic structure:

Curriculum
→ Stage
→ Lesson

Example:

Foundation
- Salvation
- Prayer
- Bible Study
- Christian Living

Spiritual Growth
- Faith
- Stewardship
- Service

Leadership
- Leadership Training
- Mentoring
- Small Group Leadership

The application provides the curriculum engine.

The church provides and manages its actual discipleship content.

---

## 16. Session Management

D Group sessions represent actual discipleship meetings.

A session may include:

- D Group
- date/time
- topic
- optional curriculum lesson
- notes
- status

MVP lifecycle:

Draft
→ Finalized

A finalized session represents an official completed D Group session.

Only appropriately authorized users may manage sessions for a D Group.

---

## 17. Attendance

Attendance is recorded against D Group sessions.

Supported MVP attendance states:

- Present
- Absent
- Late
- Excused

The system must:

- prevent duplicate attendance for the same person/session
- preserve attendance history
- identify who recorded relevant changes where appropriate
- calculate attendance information from underlying records
- support attendance-pattern monitoring

Individual attendance records are the source of truth.

Attendance percentages are derived information.

---

## 18. Discipleship Progress

Progress is separate from attendance.

MVP lesson states:

- Not Started
- In Progress
- Completed

Attending a session does not automatically complete a lesson.

Progress must relate the Disciple to the appropriate curriculum lesson.

The system should be able to determine the Disciple's overall progress
from underlying lesson-progress records.

---

## 19. Follow-up Monitoring

Follow-up is a core DiscipleTrack capability.

A follow-up represents intentional discipleship care required because
a Disciple needs attention.

A follow-up should identify:

- Disciple
- reason
- responsible person
- D Group
- status
- priority where applicable
- creation date
- actions/notes
- resolution

Basic lifecycle:

Required
→ In Progress
→ Resolved

Follow-up responsibility should normally be assigned to the appropriate
Discipler or D Group Leader according to ministry rules.

The Coordinator can oversee unresolved follow-ups across the ministry.

Resolved follow-ups remain part of the historical record.

---

## 20. Attendance Monitoring

The MVP must support deterministic attendance monitoring.

At minimum:

Repeated consecutive absence
→ Disciple Requires Attention
→ Follow-up Required

Example:

Present
Present
Absent
Absent
Absent

When the configured threshold is reached, the system identifies the
Disciple as requiring attention.

Monitoring must avoid generating duplicate unresolved follow-ups for the
same equivalent condition.

AI must not determine whether basic attendance rules have been triggered.

---

## 21. Ministry Oversight

The dashboard should prioritize actionable ministry information.

Coordinator-level information may include:

- active D Groups
- active Disciples
- active Disciplers
- D Group attendance
- Disciples requiring attention
- unresolved follow-ups
- Disciples without appropriate assignments
- D Groups requiring attention

D Group Leaders should receive information scoped to their D Group.

Disciplers should receive information scoped to the Disciples for whom
they are responsible.

The dashboard should answer:

- Who needs attention?
- Who is responsible for them?
- Has follow-up happened?
- Which D Groups are struggling?
- Are Disciples progressing?

---

## 22. Security

DiscipleTrack must enforce:

- authentication
- church isolation
- role-based authorization
- D Group-based authorization
- assignment-based authorization
- backend/database-side authorization
- input validation
- database integrity constraints

Flutter is not a trusted authorization boundary.

Hiding a screen or button does not constitute security.

---

## 23. Out of Scope for MVP

The following are intentionally postponed:

- QR attendance
- automated push notifications
- SMS
- email automation
- AI-generated ministry insights
- predictive inactivity scoring
- event management
- advanced reporting
- full offline synchronization
- web administration portal
- social/community functionality
- complex multi-church administration
- microservices
- distributed infrastructure

---

## 24. MVP Success Scenario

The MVP must support this scenario:

1. Admin creates/configures the church workspace.
2. A user registers and joins the church.
3. Membership is approved.
4. Coordinator creates a D Group.
5. Coordinator assigns a D Group Leader.
6. Disciplers and Disciples are assigned to the D Group.
7. Curriculum is configured.
8. An authorized user creates a D Group session.
9. Attendance is recorded.
10. Discipleship progress is recorded.
11. A Disciple reaches the consecutive-absence threshold.
12. DiscipleTrack identifies that Disciple as requiring attention.
13. A responsible Discipler or D Group Leader receives the follow-up.
14. Follow-up actions are recorded.
15. The follow-up is resolved.
16. The D Group Leader and Coordinator can see the appropriate outcome.

This is the primary MVP acceptance workflow.