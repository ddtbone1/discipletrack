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
- Changes: `WorkbookStore` and `Workbook` (client only), `workbookProvider`, fillable fields in `FullLessonView`. No table is added; Migration 020 adds only the read-only check (decision 7).

## Amendment: every question answerable in the app, and checking (2026-10-07)

User decisions of 2026-10-07: nothing in a lesson is answered on a separate piece of paper, no wording is changed, and a Disciple checks their blanks after answering a set.

6. **Each question gets the input its wording asks for.** The converter (`tool/curriculum/lesson_structure.dart`) keeps every word of the book and adds the answer kind each item needs:
   - **Blanks** stay inline fill-in items.
   - **Questions and written tasks** ("What…?", "Explain…", "Write…", lettered questions A. to K., a verse list to explain) get a written-answer field each.
   - **"(True or False)"** gets a True/False pick. Lettered statements under "Which…?" become a single choice.
   - **Tasks** ("Read…", "Memorize…") get a "Done" tick.
   - **Reading plans** (Daily in the Word) list each reading with its date to write.
   - **Water Cooler scenarios and Reflect & Transfer prompts** get an answer field each.
   - **Teaching text and instructions** stay as text.

   The book's own instruction ("on a separate piece of paper") is kept verbatim, because the wording is not changed; the field beneath it is where the answer goes. `verify_lesson.dart` still checks every word against the source.
7. **Checking blanks (Migration 020).** `check_lesson_answers()` compares what the reader wrote in a lesson's blanks with the book's answers. Matching ignores case, spacing and punctuation, and any accepted answer counts. It returns, per submitted blank, right or not and the book's answer. It answers only blanks the reader actually wrote in (an empty blank reveals nothing), only for a lesson whose Disciple tier the reader may read in their own context, and it stores nothing. Written answers, choices and True/False have no key in the book, so they are not checked; the Discipler goes over them at the meeting.
   - **This amends ADR-019 decision 6** ("never the Disciple" for answers) for blanks only. A Disciple sees a blank's answer after attempting it, as a Discipler would show it at the meeting. The full key, Discipler notes and training modules stay Discipler tier.
8. **A Disciple who is also a Discipler** reads their own lessons in the Disciple view (fillable, no answers) with a "Show answers" switch, because the database lets them read the answers (ADR-019 decision 16). With their Disciples they keep the Discipler view.
