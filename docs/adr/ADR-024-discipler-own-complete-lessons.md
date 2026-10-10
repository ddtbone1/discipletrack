# ADR-024: A Discipler Reads the Whole Book in Their Own Context

## Status

Accepted (2026-10-08; confirmed in the Slice 8 Phase 4 review). User decisions during the Slice 8 Phase 4 walkthrough: "Leader and Discipler should be able to have their own complete unlocked lessons. This differs to lessons on Disciples'"; both tiers, with answers; every Leader and appointed Discipler, from appointment; a Discipler who is also a Disciple keeps their journey gated, with the whole book in a separate view.

Amends [ADR-023](ADR-023-relationship-scoped-curriculum-access.md) decisions 2 and 3 for the reader's own context only. Restores, for the own context, the reason of [ADR-019](ADR-019-curriculum-licensing-tiered-progression-access.md) decision 16, which stays superseded for every other context. ADR-023 decisions 1 and 4 to 11 stand, and so does its amendment. ADR-020 is unchanged: every Leader holds DISCIPLER, so every Leader is covered.

## Context

ADR-023 decision 2 limited a Discipler or Leader, in their own context, to their own journey. A Leader is never a Disciple, so a Leader read nothing there. Phase 3 therefore removed the Leader's Lessons carousel from Home: their lessons opened only from a Disciple paired with them.

On the device, in the Phase 4 walkthrough, the user found the Leader's Home without any lessons. A Discipler prepares and teaches from the Discipler's Copy, also before the first Disciple is paired, and needs the book as their own, not through one Disciple. ADR-023 decision 4 already gave that reason for the assigned-Disciple context.

## Decision

1. **Own context, for a Discipler.** A person holding an active DISCIPLER responsibility in their church reads all ten lessons, both tiers, with answers, in their own context. That includes every Leader (ADR-020). The grant starts at appointment, before any Disciple is paired. It ends with the DISCIPLER row: removal, transfer or the end of the responsibility closes it at once.

2. **Own context, for everyone else.** Unchanged from ADR-023: the Disciple tier of their own reached lessons. A Member without a group, a Needs-setup member, a PENDING member and any member of a non-ACTIVE church read nothing.

3. **Other contexts.** Unchanged from ADR-023 decision 2. In a currently assigned Disciple's context, all ten lessons, both tiers. In the context of another Disciple of the group they lead, the Leader reads the Disciple tier of that Disciple's reached lessons, never answers. Anyone else is refused.

4. **A Discipler who is also a Disciple** (Rosa in the seed) may read every lesson in their own context. Their journey is unchanged:
   - Progression is recorded only by their own Discipler (ADR-015), in the database.
   - My Journey and the lesson list in the own view present only their own reached lessons, without answers, as they already do for the Coordinator (ADR-023 decision 10).
   - The whole book is a separate view: the Lessons section on Home and the whole-book list, titled "Lessons" for a Discipler ("Curriculum" is the Coordinator's name for the same view). That separation is presentation. Reading ahead records nothing (ADR-023 decision 11).

5. **The lesson list and covers** stay readable by every ACTIVE member of an ACTIVE church (ADR-023 decision 2).

6. **Enforced in the database.** `private.can_read_lesson_tier()` (Migration 027) returns true in the own context when the caller's membership holds an active DISCIPLER row. Every lesson read calls it:
   - `get_lesson_content()`;
   - `list_lesson_access()`;
   - `get_my_readable_content()`, so the device copy follows;
   - `check_lesson_answers()`.

   The church status gate stays first. No client-callable function is added.

7. **App.** Home shows a Lessons section, the ten covers from Lesson 1, for every appointed Discipler. Each lesson opens in the whole-book view with answers, and See all opens the whole-book list, titled "Lessons". A Discipler who is also a Disciple sees it under Your journey. The Disciple-context reading from a Disciple's page is unchanged.

## Alternatives Considered

- **Keep ADR-023 decision 2** (lessons only through a Disciple). Rejected by the user: a Leader's Home had no lessons, and a new Discipler could not prepare before the first pairing.
- **Disciple tier only in the own context.** Rejected: a Discipler teaches from the answers and notes (ADR-023 decision 4).
- **Only while a Disciple is paired.** Rejected: preparation starts at appointment.
- **A separate database context for the Discipler view of someone who is also a Disciple.** Not adopted. The reader may read the whole book either way, so a second context would add four function signatures and a device-copy context without protecting anything. Progression, the only thing the journey gate guards, is already enforced by `complete_lesson()`.

## Consequences

- Rosa's case in ADR-023 decision 3 changes. In her own context she now reads all ten lessons, both tiers. Her My Journey still shows Lessons 1 to 6 open and 7 to 10 locked, without answers.
- A Discipler with no Disciples reads the whole Discipler's Copy again. ADR-023 had listed that as an effect of the old role-wide grant. It is now intended, limited to the own context, and ends with the responsibility.
- The device copy of every Discipler holds both tiers of all ten lessons for their own context.
- The least privilege of ADR-023 decision 5 still holds for the Leader in another Discipler's Disciple's context: no answers there.
- Integration tests: `relationship_curriculum_test.dart` and `curriculum_content_test.dart` cover the Discipler, the Leader, the Disciple-Discipler and a plain Disciple in their own context.
