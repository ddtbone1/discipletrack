# ADR-015: The Discipler Marks a Lesson Completed, Without Leader Confirmation

## Status

Accepted (2026-10-05, user decision "fourth").

Decision 3's count precondition ("credited meetings are at least
`submission_minimum`") and the count basis of decision 8 are superseded
by [ADR-017](ADR-017-no-minimum-meetings.md) (2026-10-06): no minimum
number of meetings; the current lesson may be completed whatever its
count, and a void never changes a completed lesson. The open N1 decision
mentioned below is closed.

Decision 6 ("After the window, Coordinator reopen") and the reopen
statements in "Alternatives Considered" and "Why" are partially
superseded by
[ADR-016](ADR-016-completion-locked-by-later-progress.md) (2026-10-06):
after the window the completion is locked by later progress, and
`reopen_lesson_completion()` is a database-only recovery operation with
no MVP action. Decisions 1 to 5 and 7 to 9 remain accepted.

Partially supersedes
[ADR-011](ADR-011-explicit-lesson-completion.md) for the Leader
confirmation step, listed under "Superseded statements". ADR-011's
separation of meetings from completion (decisions 1 to 4 and 8), the
absence of a hard maximum and the count presentation (decisions 10 and
11), the single policy point (decisions 12 and 13), COMPLETED protection
(decision 14) and the open decision on a minimum number of credited
meetings (N1) remain accepted.

Amends the wording of
[ADR-012](ADR-012-discipler-eligibility-concurrent-responsibilities.md)
decision 1 ("confirmed COMPLETED" becomes "COMPLETED"). The eligibility
rule itself is unchanged.

## Context

ADR-011 made completion a two-step act: the Discipler submitted a lesson
as finished (READY_FOR_COMPLETION), and the current D Group Leader then
confirmed it (COMPLETED). Only the Coordinator could reopen a confirmed
lesson.

The product owner has reversed the confirmation step. The Discipler who
conducts the lessons is the person who knows whether the material has
been covered. A second confirmation by the Leader added a waiting state
in normal use, a Leader work queue ("Awaiting confirmation"), and a
dependency on every group having an active Leader, without adding
information the Discipler did not already have.

Migration 001 is applied and immutable. It defines the
`lesson_progress_status` enum with READY_FOR_COMPLETION and the
`disciple_lesson_progress` columns `ready_at`, `completed_at` and
`confirmed_by`. The Slice 5 migration adds `submitted_by` and the
Progress State Check, which requires `started_at`, `ready_at`,
`submitted_by`, `completed_at` and `confirmed_by` for COMPLETED.

## Decision

1. **One explicit step by the Discipler.** The Disciple's current
   assigned Discipler marks the lesson completed ("Mark Lesson n
   completed"). The lesson is COMPLETED immediately, and the next lesson
   in sequence becomes current for every role. There is no Leader
   confirmation and no "awaiting confirmation" state in normal use.
2. **Fallback.** The Leader of the Disciple's current D Group and the
   Coordinator may mark the lesson completed on the Discipler's behalf,
   the same fallback model as recording a meeting. Nobody ever marks
   their own lesson completed (the self rule is unchanged).
3. **Preconditions.** The lesson is the Disciple's eligible (current)
   lesson; its status is IN_PROGRESS; and its credited meetings are at
   least `submission_minimum` from the lesson meeting policy, evaluated
   at the moment of marking completed. The open N1 decision (ADR-011)
   still decides that value. The meeting count never completes a lesson
   automatically.
4. **Storage, no schema change.** The existing columns are reused. On
   marking completed: status COMPLETED, `completed_at = now()`,
   `confirmed_by` = the profile that marked it, `ready_at =
   completed_at`, and `submitted_by` = the same profile. The Progress
   State Check, which requires all five fields for COMPLETED, is
   unchanged. READY_FOR_COMPLETION stays in the enum (Migration 001 is
   immutable), but no operation enters it.
5. **Undo, within a window.** `undo_lesson_completion()` may be called by
   the current assigned Discipler, the Leader of the Disciple's current
   D Group, or the Coordinator, only while both hold:
   - (a) the lesson is the person's latest COMPLETED lesson (no later
     lesson is COMPLETED); and
   - (b) no meeting has been recorded on the next lesson (no RECORDED
     participant row for the person in a RECORDED meeting for the next
     lesson).

   Undo returns the lesson to IN_PROGRESS, or NOT_STARTED when it has no
   credited meeting; clears `ready_at`, `submitted_by`, `completed_at`
   and `confirmed_by`; and is audited with the prior values. The self
   rule applies. From Slice 6, when appointments exist, the narrowed
   eligibility-lesson protection for an appointed person (ADR-012
   decision 9, reopen precondition 4) also applies to undo.
6. **After the window, Coordinator reopen.** Only the Coordinator can
   reopen, through `reopen_lesson_completion()`, with its unchanged
   preconditions (DATABASE_CONSTRAINTS.md section 4, preconditions 1 to
   4). The resulting state changes: reopen returns the lesson to
   IN_PROGRESS, or NOT_STARTED when no credited meeting remains, never to
   READY_FOR_COMPLETION.
7. **Withdrawn operations.** `withdraw_lesson_submission()` and
   `confirm_lesson_completion()` are no longer planned.
   `submit_lesson_finished()` is replaced by `complete_lesson()`. The
   Leader's "Awaiting confirmation" section and the "lessons awaiting
   your confirmation" Home tile are withdrawn.
8. **Voids.** COMPLETED protection is unchanged: a void that would leave
   a COMPLETED lesson below `submission_minimum` is refused (ADR-011
   decision 14). The READY_FOR_COMPLETION auto-withdrawal rule (ADR-011
   decision 15) is dormant, because nothing enters that state. It is
   kept in the documents so that any row found in that state is still
   handled deterministically.
9. **Discipler eligibility.** Lesson 5 COMPLETED still creates
   eligibility (ADR-012). "Confirmed COMPLETED" becomes "COMPLETED":
   completion is now the Discipler's explicit judgement, and the
   Coordinator's appointment decision remains the human check before
   anyone becomes a Discipler.

## Superseded statements

### ADR-011

| Section | Statement | Replaced by |
|---|---|---|
| Progression diagram | "Discipler submits ... READY_FOR_COMPLETION (explicit action)" and "D Group Leader confirms, in a confirmation dialog ... COMPLETED (explicit action)" | Decisions 1, 4: IN_PROGRESS, then the Discipler marks the lesson completed, then COMPLETED |
| Decision 5 | "explicitly submits that the lesson material is finished" (the word "submits" and the intermediate state) | Decision 1: the Discipler marks the lesson completed |
| Decision 6 | "The Coordinator may confirm as ministry oversight, as before." | Decision 2: the Leader and the Coordinator may mark completed as fallback |
| Decision 7 | Confirmation by the current D Group Leader, with the Coordinator as oversight | Decisions 1, 5: no confirmation; an undo window replaces the protective dialog |
| Decision 9 | Meetings after submission, while READY_FOR_COMPLETION | Decision 4: the state is not entered. Recording targets the current lesson, which after completion is the next lesson |
| Decision 15 | READY_FOR_COMPLETION auto-withdrawal on void | Decision 8: dormant, kept for determinism |
| Decision 16 | Reopening returns the lesson to READY_FOR_COMPLETION with the original submission retained | Decision 6: IN_PROGRESS or NOT_STARTED |
| Decision 17 | Withdrawing a submission | Decisions 5, 7: withdrawn; undo replaces it |
| Consequences | "New controlled operations: submitting a lesson as finished and withdrawing a submission. `confirm_lesson_completion()` ..." | Decision 7: `complete_lesson()`, `undo_lesson_completion()`; `reopen_lesson_completion()` and the void operations keep their preconditions |

ADR-011's "Why" ("confirmed by the person accountable for the group")
no longer describes the process; the rest of that paragraph stands.

### ADR-012

Decision 1, "confirmed COMPLETED", and "IN_PROGRESS and
READY_FOR_COMPLETION do not count": read as "COMPLETED (marked by the
Discipler, ADR-015)". IN_PROGRESS does not count; READY_FOR_COMPLETION is
no longer entered.

## Alternatives Considered

**Keep Leader confirmation (ADR-011).** Rejected by the product owner. It
creates a waiting state in normal use and a Leader work queue, and it
depends on every group having an active Leader, while the Discipler
already holds the relevant knowledge.

**The Discipler completes, and the Leader is only notified.** Not
adopted. Automated push-notification workflows are outside the MVP
(MVP_SPEC.md section 33), and an unread notice gives no assurance. The Leader sees completions in the group's progress lines
and can act as fallback.

**Coordinator-only undo.** Rejected. It would route every honest
mistake, such as a tap on the wrong Disciple, to the Coordinator, though
the Discipler noticed it seconds later and nothing depends on it yet.

**Undo at any time.** Rejected. Once a later lesson is completed or a
meeting is recorded on the next lesson, other history depends on the
completion. Changing it then is a correction with consequences, which is
the Coordinator's reopen with its preconditions.

## Why

Completion is a ministry judgement about material covered, and the
person who conducted the lessons makes it. A single explicit step keeps
completion separate from meeting counts (ADR-011) without adding a
waiting state. The undo window covers mistakes noticed before anything
depends on the completion, and the Coordinator's reopen covers later
corrections. Reusing existing columns avoids a schema change and keeps
the Progress State Check intact.

## Consequences

- **Schema:** no change. READY_FOR_COMPLETION remains a dormant enum
  value. For a completion, `ready_at` equals `completed_at` and
  `submitted_by` equals `confirmed_by`. Column comments added by the
  Slice 5 migration that describe submission and confirmation may be
  corrected by a later forward migration; this is not required for
  correctness.
- **Operations:** `complete_lesson(p_membership_id, p_lesson_id)` and
  `undo_lesson_completion(p_membership_id, p_lesson_id)`, audited as
  LESSON_COMPLETED and LESSON_COMPLETION_UNDONE, replace `submit_lesson_finished()`, `withdraw_lesson_submission()` and
  `confirm_lesson_completion()`. `reopen_lesson_completion()` keeps its
  preconditions and changes its resulting state. Void operations keep
  COMPLETED protection.
- **UI:** the lesson card offers "Mark Lesson n completed" to the
  Discipler, and to the Leader and Coordinator as fallback, with a short
  undo available while the window holds. The Leader's "Awaiting
  confirmation" section, the Leader Home tile and every "awaiting
  confirmation" label are withdrawn.
- **Tests:** completion, fallback, self-refusal and precondition tests
  target `complete_lesson()`; undo tests cover both window conditions,
  the resulting state, the cleared columns and the audit row; reopen
  tests expect IN_PROGRESS or NOT_STARTED; tests for withdrawal and
  confirmation are removed.
- **Eligibility risk and mitigation:** with no second person checking
  completion, a Discipler alone can bring a Disciple to Lesson 5
  COMPLETED. Eligibility still changes nothing by itself (ADR-012
  decision 1); the Coordinator's appointment decision is the human check
  before anyone becomes a Discipler, and every completion is attributed
  and audited.
- **Documents updated in the same pass:** ADR-011 and ADR-012 status
  notes; ADR index; BUSINESS_RULES.md (BR-030, BR-032, BR-032a, BR-033,
  BR-033a, BR-034, BR-035, BR-036, BR-053); DATABASE_CONSTRAINTS.md
  sections 4, 5, 11 and 12; RBAC_RLS_MATRIX.md sections 2, 2b, 5 and
  10; MVP_SPEC.md sections 8 to 10, 18 to 22, 29 and 34;
  ARCHITECTURE.md sections 8, 9, 19 and 30; DATABASE_DESIGN.md sections
  15.2, 17 and 19; the DBML header, the `lesson_progress_status` enum,
  the `curriculum_lessons`, `disciple_lesson_progress` and
  `ministry_role_transitions` notes; a dated note at the top of
  UI_DESIGN_SYSTEM.md, whose body still describes Leader confirmation
  and is overridden by that note until the document is revisited; the
  Slice 5 plan (section T).
