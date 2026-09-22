# DiscipleTrack — Database Constraints

## Purpose

This document defines the important database invariants for the DiscipleTrack MVP.

The ERD defines the data structure.

This document defines the rules PostgreSQL must protect so invalid business states cannot be created even if the Flutter client contains a bug.

---

# 1. Identity and Church

## Rules

- profiles.id maps to the authenticated Supabase user.
- A user may only have one membership per church.
- churches.join_code must be unique.
- Joining through a church code must never automatically grant ADMIN or COORDINATOR.
- Only ACTIVE church members may receive active church roles.
- The same church role cannot be active twice for the same member.
- Historical role assignments must be ended using ended_at, not deleted.

## Constraints

UNIQUE:

- church_memberships(church_id, user_id)
- churches(join_code)

Partial unique index:

- Active church role per member and role where ended_at IS NULL

Authorization:

- Role assignment/removal requires RLS and controlled database operations.

---

# 2. D Groups and Assignments

## Rules

- A D Group may have only one active LEADER.
- A person may actively lead only one D Group.
- A DISCIPLE may belong to only one active D Group.
- A person cannot simultaneously have active DISCIPLE and DISCIPLER responsibilities.
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

## Controlled Operations

Use transactional database operations for:

- D Group transfer
- Discipler reassignment
- responsibility changes

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
- ABSENT contributes to consecutive unexplained absence.
- PRESENT breaks the absence streak.
- LATE breaks the absence streak.
- EXCUSED breaks the absence streak.
- Backdated attendance calculations use starts_at, not record creation time.
- Finalized attendance corrections must be controlled and audited.

## Unique Constraint

gathering_attendance(gathering_id, church_membership_id)

## Gathering State Check

When:

status = FINALIZED

Require:

- finalized_by IS NOT NULL
- finalized_at IS NOT NULL

Otherwise finalization fields should remain NULL.

---

# 4. Curriculum and Discipleship Progress

## Rules

- Lesson numbers are unique inside a curriculum.
- required_meetings must be greater than zero.
- Lessons progress sequentially.
- Previous lesson completion is required before progressing to the next lesson.
- Only RECORDED meetings count.
- Only COUNTED participation counts.
- One Disciple may appear only once in a meeting.
- The first valid meeting moves the lesson into IN_PROGRESS.
- Reaching the required meeting count moves it to READY_FOR_COMPLETION.
- Reaching the meeting requirement does NOT automatically complete the lesson.
- The current D Group Leader confirms completion.
- Progress belongs to church_membership_id and survives D Group transfers and Discipler reassignment.
- Curriculum progress percentage is derived, not stored.
- Completing all 12 lessons creates promotion eligibility.
- Promotion to DISCIPLER requires Coordinator approval.

## Unique Constraints

- curriculum_lessons(curriculum_id, lesson_number)
- discipleship_meeting_participants(meeting_id, church_membership_id)
- disciple_lesson_progress(church_membership_id, lesson_id)

## Check Constraint

required_meetings > 0

## Voiding Rules

When a discipleship meeting is VOIDED:

- voided_by IS NOT NULL
- voided_at IS NOT NULL

When meeting participation is VOIDED:

- voided_by IS NOT NULL
- voided_at IS NOT NULL

Voided records remain historical but do not contribute to progress.

---

# 5. Promotion

## Rules

DISCIPLE → DISCIPLER requires:

- all 12 curriculum lessons COMPLETED
- Coordinator authorization
- valid D Group context

Promotion is never automatic.

Promotion must execute transactionally:

1. Validate eligibility.
2. End active DISCIPLE responsibility.
3. Create DISCIPLER responsibility.
4. Record ministry_role_transitions.

Either every operation succeeds or none are committed.

---

# 6. Automated Monitoring

## MVP Condition

CONSECUTIVE_ABSENCE

Default threshold:

3

The threshold comes from church_settings.

## Rules

- Monitoring considers FINALIZED gatherings only.
- Monitoring ignores DRAFT gatherings.
- Monitoring ignores CANCELLED gatherings.
- Monitoring uses chronological gathering time.
- Only ABSENT contributes to the unexplained absence streak.
- Duplicate active conditions must not be created.
- Returning to attendance resolves the active condition.
- A later absence episode creates a new condition instead of reopening the previous one.
- Attendance corrections trigger recalculation.
- Monitoring operations must be idempotent.

## Partial Unique Index

Prevent equivalent duplicate ACTIVE attention conditions for the same member/context.

---

# 7. Follow-ups

## Rules

When an attention condition requires care:

1. Assign to the Disciple's active primary Discipler when available.
2. Otherwise assign to the D Group Leader.

Lifecycle:

REQUIRED → IN_PROGRESS → RESOLVED

The first actual follow-up action moves REQUIRED to IN_PROGRESS.

Resolving a follow-up does not automatically resolve its underlying attention condition.

Follow-up reassignment must be deliberate and auditable.

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

- Coordinator may create church announcements.
- D Group Leader may create announcements for their own D Group.
- Disciples and Disciplers may view announcements available to them.
- Authorization is enforced through RLS.

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

# 10. Enforcement Strategy

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
- correct finalized attendance
- log discipleship meeting
- confirm lesson
- promote Disciple
- resolve/recalculate monitoring conditions

## Row Level Security

Controls who may read or modify data.

RLS does not replace business constraints.

## Derived Queries

Used for information that should not be redundantly stored.

Examples:

- attendance percentage
- consecutive absence count
- lesson meeting count
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