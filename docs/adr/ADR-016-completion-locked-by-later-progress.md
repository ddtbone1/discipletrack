# ADR-016: A Completion Is Locked Once Later Progress Exists; Reopen Is Database-Only

## Status

Accepted (2026-10-06, user decision).

Partially supersedes
[ADR-015](ADR-015-discipler-marks-lesson-completed.md) decision 6
("After the window, Coordinator reopen") and the statements listed under
"Superseded statements". ADR-015 decisions 1 to 5 and 7 to 9 remain
accepted, including the undo window and its two conditions.

## Context

ADR-015 decision 6 presented the Coordinator's
`reopen_lesson_completion()` as the way to correct a completed lesson
after the undo window closes. Reopen precondition 3
(DATABASE_CONSTRAINTS.md section 4, revised 2026-10-05) refuses reopening
while any later lesson is COMPLETED or has a RECORDED participant row in
a RECORDED meeting for the person. The undo window closes on exactly the
same conditions: a later completed lesson, or a recorded meeting on the
next lesson.

The two rules together mean reopen is refused whenever the undo window
has closed, and while the window is open the Coordinator can already
undo. Slice 5 step 7 verified this by test. The documents bridged the gap
by telling the Coordinator to void the conflicting later meetings first
and then reopen. That uses voiding, which exists to correct erroneous
records, to erase legitimate history so that an earlier record can be
changed.

## Decision

1. **Undo is the normal correction.** A recently completed lesson is
   corrected with `undo_lesson_completion()` while its window holds
   (ADR-015 decision 5, unchanged).
2. **Later progress locks the earlier completion.** Once legitimate
   progress exists in a later lesson, either a recorded later meeting or
   a later completed lesson, the earlier completion is historically
   locked. Nothing voids, moves, deletes or otherwise manipulates
   legitimate later history in order to unlock it.
3. **Void corrects erroneous records only.** Voiding a meeting or a
   participant is for a record that was genuinely wrong. It is never
   presented as a way to unlock an earlier completion. If a later
   meeting turns out to have been recorded in error, voiding it is a
   correction of that record. That the lock then lifts is a consequence
   of the correction, not its purpose.
4. **Reopen is a database-only exceptional recovery operation.**
   `reopen_lesson_completion()` stays, Coordinator-only, with its
   preconditions, locks and audit unchanged: `later_lesson_completed`,
   `later_lesson_has_meetings`, `eligibility_lesson_protected`. It is not
   exposed as a screen or action in the MVP.
5. **Deep correction is outside the MVP.** Correcting an earlier lesson
   after legitimate later progress exists is an exceptional workflow
   that the MVP does not provide (DATABASE_CONSTRAINTS.md section 4,
   "Out of scope", widened to name it).
6. **Refusals state the lock.** Messages say that the lesson is locked
   and why. They never suggest voiding or undoing later progress to get
   around a lock.

## Superseded statements

### ADR-015

| Section | Statement | Replaced by |
|---|---|---|
| Decision 6 | "After the window, Coordinator reopen. Only the Coordinator can reopen, through `reopen_lesson_completion()` ..." as the path for corrections after the window | Decisions 2, 4, 5: after the window the completion is locked; reopen is database-only; deep correction is outside the MVP. The resulting state (IN_PROGRESS or NOT_STARTED, never READY_FOR_COMPLETION) stands |
| Alternatives, "Undo at any time" | "Changing it then is a correction with consequences, which is the Coordinator's reopen with its preconditions." | Decision 2: changing it then is outside the MVP |
| Why | "the Coordinator's reopen covers later corrections" | Decisions 2, 5 |

### ADR-011

| Section | Statement | Replaced by |
|---|---|---|
| Decision 14 | "... is refused; reopening must come first." | Decision 1: undo comes first while its window holds; after that the completion is locked (decision 2) |

## Alternatives Considered

**Keep the void-first route.** Rejected by the product owner. It treats
legitimate meetings as obstacles, rewrites history that other records
depend on, and blurs what a void means in the audit trail.

**Remove `reopen_lesson_completion()` entirely.** Not adopted. The
operation is built, audited and protected by the same locks; it costs
nothing to keep as a recovery tool, and it covers a person who is no
longer an active member, whom undo does not reach.

**Relax the locks so reopen works after the window.** Rejected. It would
let an earlier lesson change underneath recorded later progress, which
is exactly what the locks prevent.

## Why

One correction path in normal use (undo), one meaning for void
(erroneous records), and a lock that keeps recorded history stable once
later progress depends on it. The reopen operation remains available to
the database as recovery without becoming a normal action.

## Consequences

- **Schema and operations:** no change. Migration
  `20261006000002_reopen_lesson_completion.sql` implements reopen with
  the locks and audit described here.
- **UI:** no Coordinator reopen action. Undo stays on the lesson card
  while its window holds. Refusal wording states the lock.
- **Tests:** `test/integration/lesson_reopen_test.dart` covers the locks,
  the audit, the eligibility protection, and that reopen is refused
  whenever the undo window has closed.
- **Documents updated in the same pass:** ADR-011 and ADR-015 status
  notes; ADR index; BUSINESS_RULES.md (BR-033, BR-033a and the scope summary);
  DATABASE_CONSTRAINTS.md section 4 (Lesson Completion, COMPLETED Is
  Protected, reopen precondition 3, Ordering, Out of scope);
  RBAC_RLS_MATRIX.md (role table note, sections 2b and 10);
  MVP_SPEC.md; ARCHITECTURE.md; UI_DESIGN_SYSTEM.md dated note; the
  Slice 5 plan.
