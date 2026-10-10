# ADR-023: Curriculum Access Follows the Relationship, Not the Discipler Role

## Status

Accepted (2026-10-08, user decisions for Slice 8: "own journey only"; "all ten lessons" in an assigned Disciple's context; "Disciple tier, reached" for a Leader with another Discipler's Disciple). Amended the same day (Phase 1 review): the Coordinator keeps full access, My Journey stays distinct from curriculum oversight, and access never affects progression (decisions 9 to 11). Decisions 2 and 3 amended for the own context by [ADR-024](ADR-024-discipler-own-complete-lessons.md) (2026-10-08, Phase 4): a Discipler, every Leader included, reads all ten lessons, both tiers, in their own context.

Supersedes [ADR-019](ADR-019-curriculum-licensing-tiered-progression-access.md) decision 16 ("Any Discipler reads all ten lessons, both tiers, with answers"). Decision 16 stays in ADR-019 as history, marked superseded. Supersedes [ADR-021](ADR-021-device-only-lesson-answers.md) decision 8 (the own-context "Show answers" switch), which rested on decision 16. ADR-019 decisions 5, 7, 11 to 15 and 17, and the Disciple part of decision 6, stand. ADR-020 is unchanged: every Leader still holds DISCIPLER.

## Context

ADR-019 decision 16 (2026-10-06) gave every person holding an active DISCIPLER responsibility anywhere in the church every lesson in both tiers, in any context. Migration 019 implements it: `private.can_read_lesson_tier()` returns true for `private.is_discipler_in_church()` before it looks at whose context the read is in.

That is a role-wide grant. ADR-012 decision 8 and RBAC section 5 say authority follows the relationship, never the responsibility in general. It also has two known effects:
- a person who is both a Disciple and a Discipler (Rosa in the seed) reads their own future lessons, with answers;
- a Discipler with no Disciples reads the whole Discipler's Copy.

The Slice 8 audit flagged the conflict (plan B6). The user decided to narrow access to the relationship.

## Decision

1. **The context decides.** Every lesson read is for a context person: the reader themselves (own context), or another member (that person's context). The tiers a reader may open are decided for the pair (reader, context person), never from a responsibility held in general.

2. **The rule.** "Reached" keeps its ADR-019 decision 6 meaning: every COMPLETED lesson, plus the current lesson while the person holds an active DISCIPLE responsibility. It is derived, never stored.

   | Reader | Own context | Context of a currently assigned Disciple | Context of another Disciple of the group they lead | Any other person |
   |---|---|---|---|---|
   | Disciple (and anyone, in their own context) | Disciple tier of own reached lessons | n/a | n/a | refused |
   | Discipler | own journey only: Disciple tier of own reached lessons; nothing without a journey | **all ten lessons, both tiers** | n/a | refused |
   | Leader (holds DISCIPLER, ADR-020) | own journey only; a Leader is never a Disciple, so at most their completed lessons | all ten, both tiers (as that Disciple's Discipler) | **Disciple tier of that Disciple's reached lessons**, while the Disciple holds an active DISCIPLE row in the Leader's current group; never the Discipler tier | refused |
   | Coordinator | all ten, both tiers | all ten, both tiers | all ten, both tiers | all ten, both tiers, for any member of the church |
   | Super Admin without COORDINATOR, Member without a group, Needs setup, PENDING, any member of a non-ACTIVE church | nothing | n/a | n/a | refused |

   - Access in a Disciple's context lasts while the assignment, or the Leader's leadership of that Disciple's group, is current. It ends at once with re-pairing, unpairing, removal or transfer.
   - The lesson list (numbers and titles) and the covers stay readable by every ACTIVE member of an ACTIVE church, locked lessons included.

3. **The two cases that exist today:**
   - **A Discipler with no Disciples** reads only their own journey: the Disciple tier of their reached lessons, or nothing if they have never been a Disciple. They gain the full Discipler's Copy, in that Disciple's context, as soon as a Disciple is paired with them.
   - **A member who is both a Disciple and a Discipler** (Rosa: Lessons 1 to 5 completed, Lesson 6 current) reads, in her own context, the Disciple tier of Lessons 1 to 6, fillable and without answers, like any Disciple. In the context of each Disciple paired with her, she reads all ten lessons in both tiers. She has none paired yet, so today she reads only her own journey.

4. **Why all ten lessons in an assigned Disciple's context.** A Discipler prepares ahead of the Disciple and teaches from the Discipler's Copy (decision 16's reason). Tying it to the relationship keeps that preparation and drops the role-wide grant.

5. **Why the Leader gets only the Disciple tier for others' Disciples.** It restores ADR-019 decision 6's least privilege. Recording a meeting or marking a lesson completed on the Discipler's behalf (fallback) needs no answers.

6. **The device copy follows the same rule.** `get_my_readable_content()` returns the union of the reader's contexts. Each lesson's open tiers are recorded per context, and the reader applies the context it is opened in, offline included. Discipler-tier content held for a Disciple is never shown in the reader's own context. The copy is still pruned to the current scope on every refresh (ADR-019 decision 7).

7. **Answer checking is unchanged.** `check_lesson_answers()` (ADR-021 decision 7) already requires the Disciple tier in the reader's own context.

8. **Enforced in the database.** `private.can_read_lesson_tier()` drops the `private.is_discipler_in_church()` branch. A Discipler reads both tiers of any lesson only when the context person is their currently assigned Disciple. A Leader reads the Disciple tier of reached lessons for a Disciple of their current group. `list_lesson_access()` keeps refusing a context person outside the reader's scope.

## Amendment: the Coordinator and progression (Phase 1 review, 2026-10-08)

User decision of 2026-10-08, after the Phase 1 review.

9. **The Coordinator keeps full curriculum access**: all ten lessons, both tiers, in their own context and in any member's. This is the one own-context exception to decision 2. It is deliberate: the Coordinator oversees the curriculum for the whole church.

10. **My Journey stays distinct from curriculum oversight.** A Coordinator who is also a Disciple has two separate places:
    - **My Journey** is their own journey, presented exactly as for any Disciple. Its lesson states (completed, current, locked) come from their own progression, never from what they may read. A lesson opened from My Journey opens in the Disciple view of their own journey: fillable, without the book's answers.
    - **Curriculum** (from D Groups, Curriculum) is the Coordinator's oversight view: all ten lessons with both tiers.

    The database returns both tiers to the Coordinator in either place. Which view is shown is presentation and grants nothing.

11. **Curriculum access never affects lesson progression**, for any role. Opening or reading a lesson, in any tier or context, records nothing:
    - it never makes a lesson current, reached or completed;
    - it never counts as a meeting;
    - it never changes eligibility.

    Access is derived from progression and relationships, never the reverse (ADR-010 decision 7, ADR-011, ADR-015).

## Alternatives Considered

**Keep decision 16 (the role-wide grant).** Rejected by the user. It is not relationship-scoped, and it shows a Disciple-Discipler their own future lessons with answers.

**Full copy in own context while the person has at least one Disciple.** Rejected. Own-context access would still come from having some relationship, not from this one, and Rosa would still read her own lessons ahead.

**Reached lessons only in an assigned Disciple's context.** Rejected. The Discipler could not prepare ahead.

## Consequences

- Narrows what Disciplers and Leaders can read in their own context. Today: all ten lessons, both tiers. After: their own journey.
- **App effects, built in Slice 8 phase 3:**
  - **Leader's Home carousel:** today it shows all ten lessons open for a Leader without a journey (`LessonCarousel(journey: null)`). After the change, every card in own context would be locked, so a reader without a journey gets no own-context carousel. Lessons are opened from a Disciple (My Disciples, then the Disciple, then their lessons).
  - **Lesson list:** in own context, the reader's own journey (locks included). In a Disciple's context, the access of decision 2.
  - **Coordinator's My Journey** (decision 10): lesson states from their own journey; lessons opened from it in the Disciple view, fillable. Curriculum keeps the full book with answers.
  - **Reader:** the own-context "Show answers" switch goes. Own context returns no Discipler tier except to the Coordinator, so a Disciple-Discipler's own lessons are fillable with no answers (ADR-021 decision 1). In a Disciple's context the Discipler view stays.
- `config/README` "What to look at" changes: Dino, Grace, Lea and Ramon open all ten lessons from their Disciples' detail only. Rosa reads her own Lessons 1 to 6, Disciple tier.
- Tests: the narrowed rule per row of decision 2, the two cases of decision 3, the end of access on re-pairing, and the device copy's per-context tiers.
- Documents reconciled: ADR-019 (decision 16 marked superseded), ADR-021 decision 8, RBAC_RLS_MATRIX section 2 lesson rows and sections 5 and 10, BUSINESS_RULES BR-029a, MVP_SPEC section 18, ARCHITECTURE section 10a, config/README.
