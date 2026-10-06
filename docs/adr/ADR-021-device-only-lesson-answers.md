# ADR-021: A Disciple's Lesson Answers Stay on Their Device (Before the Workbook)

## Status

Accepted (2026-10-07, user decision: "Fillable, kept on device").

Partially anticipates ADR-013 (Curriculum Workbook and Guide Modes, reserved). It does not write ADR-013 and decides none of its server questions. It narrows ADR-019 decision 13 ("blanks are shown, not filled") for the Disciple's own reading.

## Context

The lessons are now reproduced in full (ADR-019 amendment). A Disciple reading their own lesson sees the book's blanks, writing fields, verse lines and self-check ratings as empty lines. The user asked that Disciples be able to answer them.

Saving answers on the server is the workbook (Slice 8, ADR-013). That needs decisions that have not been made: who may read a Disciple's answers (their Discipler? the Leader?), how answers sync and resolve conflicts, how long they are kept, and whether Slice 8 stays in the MVP after the pilot.

## Decision

1. **Fillable in the Disciple's own lesson only.** When a person reads their own lesson and the database returned no Discipler tier (a Disciple's read), blanks, writing fields (date, signature, day, time, place), verse writing and self-check ratings are fillable. A Discipler's read shows the book's answers instead and is not fillable.
2. **Saved on the device only.** Answers are stored in the device's preferences, one entry per person and lesson (`workbook.v1.<userId>.<lessonId>`), as they type. Nothing is sent to the server, so nothing about them is readable by anyone else and no RLS, schema or migration is involved.
3. **Kept across sign-out, separated by person.** The answers belong to the person who wrote them, so sign-out does not clear them. They are keyed by user, so someone else signing in on the same device does not see them.
4. **Never progress.** Answers never mark a lesson completed, count as a meeting, or change any journey state (ADR-011, ADR-015).
5. **Said on screen.** The reader states "Saved on this phone only", so nobody assumes their Discipler can see the answers or that they follow them to another phone.

## Consequences

- Reinstalling the app, clearing its data or changing phones loses the answers. This is accepted until Slice 8.
- The Discipler cannot see the Disciple's answers. Reviewing answers together stays in person, as in the printed book.
- Slice 8 can migrate device answers to the server: the per-block keys (`b0`, `f0`, `v`, `s0`) map onto a future response table.
- Changes: `WorkbookStore` and `Workbook` (client only), `workbookProvider`, fillable fields in `FullLessonView`. No database change.
