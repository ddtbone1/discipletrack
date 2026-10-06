# ADR-017: No Minimum Meetings; Meeting Count Is Never a Progression Gate

## Status

Accepted (2026-10-06, user decision). Closes N1.

Partially supersedes
[ADR-011](ADR-011-explicit-lesson-completion.md) decisions 11 (the
"Typical" presentation), 12 and 13 (the single meeting policy and its
values), the count basis of decision 14, decision 15, the count condition
of decision 16, and the "Open decision (blocking)" section (N1); and
[ADR-015](ADR-015-discipler-marks-lesson-completed.md) decision 3 (the
count precondition) and the count basis of decision 8. Everything else in
those ADRs, and all of
[ADR-016](ADR-016-completion-locked-by-later-progress.md), remains
accepted.

## Context

ADR-011 separated completion from meeting counts but left one numeric
question open (N1): must a minimum number of credited meetings exist
before a lesson may be completed? Until it was answered, the database used
a placeholder policy, `private.lesson_meeting_policy()`, returning a floor
of one credited meeting (`submission_minimum = 1`) and no recommended
number. Completion required the lesson to be IN_PROGRESS with at least
that many credited meetings, and a void that would leave a COMPLETED
lesson below the floor was refused (`lesson_completed_protected`).

## Decision

1. **Meeting count does not determine lesson completion.** The
   authorized Discipler decides when the Disciple has completed the
   lesson, based on the actual discipleship process.
2. **No minimum.** A lesson may be marked completed with zero, one or
   any number of credited meetings. There is no `submission_minimum`, no
   placeholder floor and no replacement threshold.
3. **No automatic completion.** A lesson never completes, and never
   advances progression, because of a meeting count.
4. **Counts stay factual.** Present, Late, Absent and Excused outcomes and
   meeting counts remain history: displayed, summarised, and usable by
   monitoring rules where those are separately approved. They are not a
   progression gate. No "typical" or recommended number is shown.
5. **Completion is unchanged otherwise.** It stays an explicit,
   authorised domain action: the assigned Discipler, with the Leader and
   the Coordinator on the Discipler's behalf; never one's own lesson;
   completion immediately makes the next lesson current. Only the current
   lesson can be completed, from NOT_STARTED as well as IN_PROGRESS.
6. **A void never implicitly changes a completed lesson.** Voiding a
   meeting or a participant never undoes, reopens or otherwise changes an
   explicitly COMPLETED lesson; recomputation from meeting history never
   downgrades COMPLETED. With no minimum to preserve, the refusal that
   protected a completed lesson's last credited meeting is removed. A
   completed lesson changes only through the correction mechanisms of
   ADR-016 (Undo while its window holds; the database-only Reopen).
7. **The legacy `required_meetings` column** stays unread by every
   database function and denied to clients. It is not reintroduced as a
   completion rule.

## Superseded statements

| ADR | Statement | Replaced by |
|---|---|---|
| ADR-011 decision 11 | "or, only where policy defines a recommendation, '5 meetings recorded · Typical: 4'" | Decision 4: the count only |
| ADR-011 decisions 12, 13 | The single meeting policy (`submission_minimum`, never below 1; `recommended_meetings`) read by every count rule | Decisions 2, 4: no policy; no count rule exists |
| ADR-011 decision 14 | "A void that would leave a COMPLETED lesson with fewer credited meetings than `submission_minimum` is refused" | Decision 6: such a void is allowed and leaves the lesson COMPLETED |
| ADR-011 decision 15 | READY_FOR_COMPLETION auto-withdrawal below the minimum (already dormant) | Decision 2: no minimum; a row found in that state keeps it |
| ADR-011 decision 16 | "when the credited count still meets `submission_minimum`" | ADR-015 decision 6 already returns IN_PROGRESS or NOT_STARTED; no count condition |
| ADR-011 "Open decision (blocking)" | N1 and models A, B, C | Closed by decisions 1 to 3 |
| ADR-015 decision 3 | "its status is IN_PROGRESS; and its credited meetings are at least `submission_minimum`" | Decisions 2, 5: the current lesson, from NOT_STARTED or IN_PROGRESS, with no count |
| ADR-015 decision 8 | "a void that would leave a COMPLETED lesson below `submission_minimum` is refused" | Decision 6 |

## Alternatives Considered

**Keep a floor of one credited meeting.** Rejected by the product owner:
the Discipler, not a count, judges whether the material was covered.

**Keep the void refusal to protect COMPLETED.** Rejected. Recomputation
already never touches COMPLETED, so the refusal protected only the
minimum it was built for; with no minimum it would block legitimate
corrections of erroneous records for no reason.

**Replace the floor with a recommended number.** Not adopted (decision 4).

## Why

Completion is a ministry judgement, recorded explicitly by the person
accountable for it. Counts describe what happened; they never decide
progress. One invariant, "a void never implicitly changes a completed
lesson", replaces a numeric protection that only existed for the
placeholder.

## Consequences

- **Forward migration** `20261006000004_no_minimum_meetings.sql`
  (Migration 011): drops `private.lesson_meeting_policy()` and
  `private.assert_void_keeps_completed()`; replaces `complete_lesson()`,
  `recompute_lesson_progress()`, `get_disciple_journey()` (columns
  `submission_minimum` and `recommended_meetings` removed) and both void
  operations. Applied Migrations 007 and 008 are not edited.
- **Refusal codes no longer raised:** `below_submission_minimum`,
  `lesson_not_in_progress` (completion), `lesson_completed_protected`
  (voids).
- **Timestamps:** the Progress State Check is unchanged; a lesson
  completed with no credited meeting gets `started_at = completed_at`.
- **App:** no minimum, no "Typical" line; "Mark Lesson n completed" is
  offered on the current lesson to whoever may complete it, whatever the
  count.
- **Documents updated in the same pass:** ADR-011 and ADR-015 status
  notes; ADR index; BUSINESS_RULES.md (BR-030, BR-033, BR-033a and the
  revision header); DATABASE_CONSTRAINTS.md section 4 (Lesson Meeting
  Policy, Lesson Completion, COMPLETED Is Protected, Progress Timestamps)
  and section 11; RBAC_RLS_MATRIX.md section 10; the DBML notes;
  MVP_SPEC.md; ARCHITECTURE.md; DATABASE_DESIGN.md; AGENTS.md; the Slice 5
  plan.
