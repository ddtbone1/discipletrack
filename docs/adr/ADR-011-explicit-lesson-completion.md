# ADR-011: Explicit Lesson Completion, Independent of a Fixed Meeting Count

## Status

Accepted (2026-10-02, decision B, from the Discipleship Director).

Partially supersedes [ADR-009](ADR-009-discipleship-meeting-attendance-monitoring.md):
the statement "Credited meetings may exceed required_meetings while a
lesson is READY_FOR_COMPLETION", and the count basis of COMPLETED
protection. Everything else in ADR-009, including meeting attendance
outcomes, the credit predicate, NO RECORD is not a missed meeting, and
role-specific monitoring, remains accepted.

Partially superseded (2026-10-05) by
[ADR-014](ADR-014-remove-d-group-gathering-attendance.md): "role-specific
monitoring" in the sentence above, and the Consequences statement
"CONSECUTIVE_MISSED_MEETINGS still counts recorded ABSENT outcomes only".
The condition is CONSECUTIVE_ABSENCE, counting explicitly recorded
ABSENT outcomes only. The rest of this ADR is unchanged.

One numeric rule is **not decided** by this ADR and is a blocking
product decision (see "Open decision"). The architecture below works
for every option.

## Context

The specification assumed every lesson takes exactly four credited
meetings. Reaching `required_meetings` credited meetings moved a lesson
to READY_FOR_COMPLETION automatically, and the Leader then confirmed it
(MVP_SPEC sections 18 and 20, BR-030, BR-032, DATABASE_CONSTRAINTS
section 4, ADR-009).

The Discipleship Director has corrected this. A lesson sometimes takes
around six meetings, sometimes fewer or more; it is finished when the
material has actually been covered. The meeting count is factual
history, not the definition of completion.

Two concepts had been fused:

- **meeting occurrence and attendance**: a meetup happened or was
  missed, and each Disciple was Present, Late, Absent or Excused;
- **lesson completion**: the lesson material has been covered and the
  Leader has confirmed it.

## Decision

### Meetings and completion are separate

1. Meetings are recorded against the Disciple's current lesson. The
   number of credited meetings is factual history.
2. Recording a meeting, of any ordinal, never changes the lesson's
   readiness or completion by itself. No count threshold moves a lesson
   to READY_FOR_COMPLETION.
3. The credit predicate is unchanged (ADR-009): a RECORDED participant,
   PRESENT or LATE, in a RECORDED meeting. PRESENT and LATE are
   meaningful participation in the lesson. ABSENT and EXCUSED are
   attendance outcomes; they never indicate that material was covered
   and never count as lesson meetings.
4. The meeting ordinal ("Meeting 3") stays derived from credited
   participations ordered by (occurred_at, meeting id). Uncredited rows
   have no ordinal.

### Progression

```
NOT_STARTED
    | first credited meeting                      (derived, automatic)
IN_PROGRESS
    | Discipler submits "We have finished covering this lesson"
READY_FOR_COMPLETION                              (explicit action)
    | D Group Leader confirms, in a confirmation dialog
COMPLETED                                         (explicit action)
    | the next lesson in sequence becomes current (derived)
```

5. **Submission.** The Discipler conducting the lesson, normally the
   Disciple's current assigned Discipler, explicitly submits that the
   lesson material is finished. Submission is a controlled operation,
   attributed (who, when) and audited.
6. **Fallback.** The existing fallback model is reused: the D Group
   Leader and the Coordinator may submit on behalf of the Discipler, as
   they may record on the Discipler's behalf. The Coordinator may
   confirm as ministry oversight, as before.
7. **Confirmation.** The current D Group Leader confirms completion; the
   Coordinator may confirm as oversight. Because a Leader cannot undo a
   confirmation (reopening is Coordinator-only), the client asks for
   explicit confirmation in a dialog (decision A7).
8. **Sequential eligibility** is unchanged: lesson N is eligible only
   when lesson N-1 is COMPLETED; lesson 1 is exempt.
9. **Meetings after submission.** Meetings may still be recorded while a
   lesson is READY_FOR_COMPLETION, as before. They add to the factual
   count and do not withdraw the submission.
10. **No hard maximum.** There is no upper limit on meetings per lesson
    and no database constraint enforcing one, unless the Director later
    states that a lesson must never exceed a given number. Exceeding a
    recommendation is never exceptional or invalid.
11. **Presentation.** Never "5 / 4 meetings". The count is shown as
    "5 meetings recorded", or, only where policy defines a
    recommendation, "5 meetings recorded · Typical: 4".

### The single policy point

12. Whether a minimum number of credited meetings must exist before a
    lesson can be submitted, and whether a recommended number is shown,
    is answered in **one place**: a meeting policy, resolved per lesson
    by one trusted database function. It yields two values:
    - `submission_minimum`: the credited-meeting count a lesson must
      have before it may be submitted. It is never below 1, because a
      lesson with no credited meeting is NOT_STARTED and no material has
      been covered with anyone.
    - `recommended_meetings`: a number shown for guidance only, or none.
13. Every rule that depends on a count reads the policy, never a literal
    and never `required_meetings` directly: submission, the
    READY_FOR_COMPLETION and COMPLETED void protections, reopening, and
    every UI line about meeting counts.

### Protections, re-derived

14. **COMPLETED is protected.** A void never changes a COMPLETED status,
    because status is no longer count-derived. A void that would leave a
    COMPLETED lesson with fewer credited meetings than
    `submission_minimum` is refused; reopening must come first. Voiding
    an uncredited (ABSENT or EXCUSED) participation never affects
    progress.
15. **READY_FOR_COMPLETION is not silently kept invalid.** A void that
    would leave a submitted lesson below `submission_minimum` withdraws
    the submission in the same transaction (IN_PROGRESS, or NOT_STARTED
    when no credited meeting remains). The void's audit metadata records
    the withdrawal.
16. **Reopening** (Coordinator only, unchanged preconditions) returns the
    lesson to READY_FOR_COMPLETION with the original submission
    retained, when the credited count still meets `submission_minimum`;
    otherwise to IN_PROGRESS or NOT_STARTED with the submission cleared.
    The prior confirmation stays recoverable through audit_events.
17. **Withdrawing a submission** is a controlled operation that returns
    READY_FOR_COMPLETION to IN_PROGRESS, clears the submission
    attribution and is audited. Who may withdraw is defined in
    RBAC_RLS_MATRIX.md.

## Open decision (blocking)

> Is there a minimum number of credited meetings required before a
> lesson can be marked finished, or is the number only recommended /
> completely flexible depending on when the lesson material is actually
> completed?

| Model | Meaning | `submission_minimum` | `recommended_meetings` | What `required_meetings` would become |
|---|---|---|---|---|
| A. Fully flexible | No minimum beyond one credited meeting | 1 | none | Unused for progression; removed later, or kept only as historical seed data |
| B. Minimum + flexible | At least N credited meetings before submission; more allowed | N (per lesson, or one church-wide value) | optional | Renamed or reinterpreted as `minimum_meetings` |
| C. Recommended only | Any count may be submitted; a typical count is shown | 1 | N | Renamed or reinterpreted as `recommended_meetings` |

The column `curriculum_lessons.required_meetings` (applied in Migration
001, seeded as 4 by Migration 004) is **not renamed or changed** by this
ADR. Until the decision, no rule may give it meaning beyond what the
policy function assigns.

## Alternatives Considered

**Replace `required_meetings = 4` with a maximum of 6.** Rejected. A
lesson's length depends on the material, not a ceiling, and a maximum
would refuse legitimate meetings.

**Keep automatic readiness at a count and let Disciplers "top up".**
Rejected. It keeps count-driven completion, the assumption the Director
corrected, and invites recording meetings to reach a number.

**Readiness from the reader** (the Disciple reaching the end of the
lesson text). Rejected. Reading is not covering material together, and
ADR-010 keeps reading separate from progress.

## Why

Completion is a ministry judgement about material covered, made by the
person who conducted the lessons and confirmed by the person accountable
for the group. Meeting records stay factual and unchanged. Putting the
only numeric rule behind one policy point lets the build proceed while
the ministry decides, and makes the eventual answer a contained change.

## Consequences

- Schema (DBML): `disciple_lesson_progress` gains submission
  attribution (`submitted_by`, profiles.id); `ready_at` becomes the time
  of submission instead of "the point the required count was reached".
  Introduced by a new migration in the Discipleship Meeting + Progress
  slice. `required_meetings` is unchanged pending the open decision.
- New controlled operations: submitting a lesson as finished and
  withdrawing a submission. `confirm_lesson_completion()`,
  `reopen_lesson_completion()` and both void operations change their
  preconditions as above.
- Progress recomputation after a record or void only moves
  NOT_STARTED and IN_PROGRESS by credited presence, withdraws a
  submission that falls below the minimum, and never touches COMPLETED.
- Monitoring is unaffected: CONSECUTIVE_MISSED_MEETINGS still counts
  recorded ABSENT outcomes only (ADR-009). A high meeting count is never
  an attention signal.
- UI: meeting progress is a count, not a fraction. Dots with empty
  "remaining" markers are withdrawn, because they presume a fixed total.
- Tests: every count-dependent test reads the policy values instead of
  a literal, and the policy itself has its own small test group, so the
  decision changes one function and one test group rather than the
  suite.
