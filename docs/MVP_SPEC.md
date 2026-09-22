# DiscipleTrack MVP Specification

## 1. Product Overview

*DiscipleTrack* is a mobile-first discipleship, attendance, and member growth monitoring system for churches.

DiscipleTrack is not intended to be only an attendance tracker.

Its primary purpose is to help church leaders understand:

- Who is participating?
- Who is progressing through discipleship?
- Who is becoming inactive?
- Who needs follow-up?
- Who is responsible for that follow-up?
- Has appropriate discipleship care actually happened?

The system should help prevent members from quietly becoming inactive without leaders noticing or responding.

---

## 2. MVP Goal

The MVP must support one complete discipleship workflow:

Church Setup
→ Member Registration
→ Church Membership Approval
→ Group Assignment
→ Leader Assignment
→ Discipleship Curriculum
→ Session
→ Attendance
→ Discipleship Progress
→ Follow-up
→ Basic Ministry Dashboard

The goal of the MVP is to prove that DiscipleTrack can support the church's core discipleship monitoring workflow before advanced features are introduced.

---

## 3. Platform

DiscipleTrack MVP is a mobile application.

Supported platforms:

- Android
- iOS

Primary client technology:

- Flutter
- Dart

A separate web administration application is not part of the MVP.

---

## 4. User Roles

The MVP contains four primary roles:

- Admin
- Discipleship Coordinator
- Leader / Mentor
- Member / Disciple

### Admin

Responsible for church-level system administration.

An Admin can:

- manage church information
- manage church memberships
- manage users and roles
- manage discipleship groups
- manage leaders
- manage curriculum
- view church-wide information

### Discipleship Coordinator

Responsible for the church's discipleship operations.

A Coordinator can:

- manage members
- manage groups
- assign members to groups
- assign leaders
- manage discipleship curriculum
- review attendance
- review discipleship progress
- manage and review follow-ups
- view ministry-level dashboard information

### Leader / Mentor

Responsible for assigned groups and disciples.

A Leader can:

- view authorized groups
- view assigned members
- create sessions for authorized groups
- record attendance
- record discipleship progress
- receive follow-up responsibilities
- record follow-up actions and notes

Being a Leader does not automatically grant access to every member in the church.

### Member / Disciple

A Member can:

- access their own account
- view appropriate personal information
- view their assigned group
- view their discipleship progress
- view appropriate session/group information

Members cannot grant themselves additional roles or permissions.

---

## 5. Church Onboarding

A church is initially created by an authorized Admin.

Users must be able to join the correct church rather than registering into a global unscoped account.

The intended onboarding mechanisms are:

- church invitation code
- invitation link
- QR invitation

The MVP may initially implement a church invitation code while keeping the architecture compatible with invitation links and QR invitations later.

A normal registration does not grant privileged roles.

New users join as Members and may require approval from an authorized church user.

Roles such as:

- Admin
- Coordinator
- Leader

must be assigned or invited by an authorized user.

---

## 6. Authentication

DiscipleTrack must support persistent authentication.

### First Use

Open App
→ Register or Login
→ Join Church
→ Complete Required Onboarding
→ Enter App

### Normal Subsequent Use

Open App
→ Restore Existing Session
→ Enter App

Users should not have to repeatedly log in every time the application opens.

Re-authentication may be required when:

- the user explicitly logs out
- the authentication session cannot be refreshed
- account access has been revoked
- another security condition requires authentication

---

## 7. Member Management

Authorized users can manage disciple/member profiles.

Basic MVP member information may include:

- full name
- contact information
- church membership
- date joined
- age group
- baptism status
- membership status

Discipleship-related information includes:

- assigned group
- assigned leader/mentor
- current discipleship stage
- curriculum progress
- attendance history
- follow-up history

Historical ministry information should not be destroyed simply because a member changes group, leader, or status.

---

## 8. Discipleship Groups

Authorized users can create and manage discipleship groups.

A group may contain:

- group name
- leader
- assistant leader where applicable
- members
- meeting schedule
- meeting location
- group status

Members can be assigned to groups.

The system should preserve meaningful membership history when a member moves between groups.

---

## 9. Discipleship Curriculum

Church-specific discipleship curriculum must not be hard-coded into the Flutter application.

Authorized Admins and Coordinators can configure curriculum through the system.

The basic structure is:

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

The application provides the curriculum management and progress-tracking engine.

The actual church curriculum is stored as church-owned data.

---

## 10. Session Management

Leaders can create discipleship sessions for groups they are authorized to manage.

A session includes:

- group
- date and time
- topic
- optional curriculum lesson
- notes
- status

The MVP should support a simple session lifecycle:

Draft
→ Finalized

A finalized session represents an official completed session record.

Attendance editing rules around finalized sessions will be defined by the business rules.

---

## 11. Attendance

Authorized Leaders can record attendance for applicable members.

Supported MVP attendance states:

- Present
- Absent
- Late
- Excused

The system must:

- prevent duplicate attendance for the same member and session
- preserve attendance history
- record relevant audit information
- calculate attendance statistics from attendance records
- support monitoring of attendance patterns

Individual attendance records are the source of truth.

Attendance percentages and statistics are derived information.

---

## 12. Discipleship Progress

Discipleship progress must be tracked separately from attendance.

Basic lesson progress states:

- Not Started
- In Progress
- Completed

Attending a session does not automatically mean that a member completed the associated lesson.

Progress must be associated with the relevant:

- member
- curriculum
- stage
- lesson

The system should be able to determine a member's current discipleship progress from these records.

---

## 13. Follow-up Monitoring

Follow-up monitoring is a core DiscipleTrack capability.

A follow-up represents a situation where a member requires intentional attention from a Leader or Coordinator.

A follow-up should contain:

- member
- reason
- responsible user
- status
- priority where applicable
- date created
- actions/notes
- resolution information

Basic lifecycle:

Required
→ In Progress
→ Resolved

Resolved follow-ups must remain available as historical records.

---

## 14. Attendance Monitoring

The MVP must support deterministic monitoring of attendance patterns.

At minimum, the system should detect consecutive absences.

Example:

Present
→ Present
→ Absent
→ Absent
→ Absent

Once the configured absence threshold is reached, the member should be identified as requiring attention.

The monitoring process must avoid creating unnecessary duplicate unresolved follow-ups for the same condition.

Monitoring rules must be deterministic business logic.

AI is not responsible for determining core attendance facts or deciding whether the fundamental MVP attendance rule has been triggered.

---

## 15. Dashboard

The MVP dashboard should prioritize actionable ministry information.

Basic information may include:

- total active members
- active groups
- recent attendance rate
- members requiring follow-up
- unresolved follow-ups
- members without group assignments
- members without leader assignments

The dashboard should answer questions such as:

- Who currently needs attention?
- Which follow-ups remain unresolved?
- Are members participating?
- Are members properly assigned?

Advanced analytics are outside the MVP.

---

## 16. Security

The MVP must enforce:

- authentication
- church data isolation
- role-based authorization
- assignment/group-based authorization where necessary
- backend/database-side authorization
- input validation
- database integrity constraints

The mobile application must not be treated as a trusted security boundary.

Hiding a button or screen in Flutter is not sufficient authorization.

A user manipulating the client must not be able to bypass server/database access controls.

---

## 17. Auditability

Important operations should retain enough information to determine:

- what happened
- when it happened
- who performed the action

This is especially relevant to:

- attendance
- role changes
- group/leader assignments
- discipleship progress
- follow-ups

The exact audit implementation will be determined during database design.

---

## 18. Out of Scope for MVP

The following are intentionally postponed:

- QR attendance
- automated push notifications
- SMS notifications
- email automation
- AI-generated ministry insights
- predictive inactivity scoring
- event management
- advanced reporting
- full offline synchronization
- web administration portal
- social/community features
- complex multi-church administration
- microservices
- distributed infrastructure

These features may be introduced incrementally after the core workflow is proven.

---

## 19. MVP Success Scenario

The MVP must successfully support this end-to-end scenario:

1. An Admin creates/configures a church.
2. A Member registers and joins that church.
3. An authorized user approves the membership.
4. A Coordinator assigns the Member to a discipleship group.
5. A Leader is assigned responsibility for the group/member.
6. An authorized user configures a discipleship curriculum.
7. The Leader creates a group session.
8. The Leader records attendance.
9. The Leader records relevant discipleship progress.
10. Repeated absence triggers the attendance monitoring rule.
11. A follow-up becomes visible to the responsible Leader.
12. The Leader records follow-up actions.
13. The follow-up is resolved.
14. The Coordinator can see relevant ministry information on the dashboard.

This is the primary acceptance scenario for the DiscipleTrack MVP.