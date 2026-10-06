> **Working plan, not an authoritative document.** Proposed scope for Vertical Slice 7. Governing decisions: ADR-010 as amended by ADR-019, ADR-012, ADR-015 to ADR-018. Source facts: `docs/curriculum/SOURCE_ANALYSIS.md`. Do not start implementation without an explicit instruction.

# Vertical Slice 7: Curriculum and Lesson Content

## Goal

Deliver the curriculum content architecture and a lesson reader that already enforces who may read what, populated with **identifying metadata only** (ADR-019 decisions 1 and 2). When permission to reproduce *Journey* is confirmed, the full Disciple-tier text and the Discipler-tier answers can be published into the same structures. That later step needs no schema redesign and no security retrofit.

**Done means:**
- the ten lessons are published as metadata;
- every person reads only their permitted lessons and tiers, enforced by the database;
- the Journey and Disciple screens open the lesson reader;
- locked lessons explain themselves;
- reading works offline for what was synced and records nothing.

## Settled inputs (not reopened)

- Ten lessons; eligibility after Lesson 5 (ADR-012); completion by the Discipler (ADR-015, ADR-016, ADR-017).
- Licensing posture, the two tiers, progression-gated access, the device copy, the book-versus-ADR rule and pairing guidance not enforced (ADR-019).
- Workbook responses, verse writing, homework, Daily in the Word, memory verses, self-ratings and module sign-offs: Slice 8 under ADR-013, or later.
- No new dock destination. No new dependency.

## Access rule as implemented

"Reached" (derived, never stored) is defined per person:
- every lesson they have COMPLETED;
- their current lesson (`private.eligible_lesson()`), but only while they hold an active DISCIPLE responsibility.

So a member with no journey has reached nothing: the default Lesson 1 that `eligible_lesson()` resolves for anyone grants no access (ADR-019 decision 6, "no journey, no curriculum"). A Disciple removed from their group keeps their completed lessons and loses their current one.

| Reader | Disciple tier of lesson N | Discipler tier of lesson N |
|---|---|---|
| The person themselves | lessons they have reached | never |
| Their current assigned Discipler | lessons the Disciple has reached | lessons the Disciple has reached |
| Leader of the Disciple's current group (Disciple active there) | lessons the Disciple has reached | never (least privilege; recording on a Discipler's behalf grants no answers) |
| Coordinator | any lesson | any lesson |
| Anyone else (Admin without Coordinator, Pending, other church, past Discipler) | nothing | nothing |

The lesson list (number and title) stays readable by every ACTIVE member, as today.

## Phases

### 7.1 Content model, publishing and access (database)

**Migration `…_curriculum_content.sql`** (DBML first):

| Table | Purpose |
|---|---|
| `curriculum_publications` | One row per publication of a curriculum, with `version`, `content_level` (`METADATA`, `FULL`), `licence_reference`, `published_at`, `superseded_at`. CHECK: `FULL` requires a `licence_reference`, so ADR-019 decision 3 is enforced, not remembered. Partial unique index: one current publication per curriculum. Rows are never deleted; republishing supersedes. |
| `lesson_content_blocks` | Ordered blocks of a lesson in one publication: `lesson_id`, `ordinal`, `section_label`, `block_type`, `tier` (`DISCIPLE`, `DISCIPLER`), `body jsonb`. Block types cover the source structure: lesson theme, topic list, section heading, key objective, banner, paragraph, scripture reference, fill-in statement, discussion prompts, scenario, verse writing, assignments, module heading, Discipler note. Each type's required body keys are checked. |
| `lesson_block_answers` | Answers kept apart from the blocks they answer (ADR-019 decision 5): one row per fill-in block, with accepted answers per blank (alternatives allowed). Always Discipler tier. Empty in this slice. |

- **Separate from progress.** Content keys to `curriculum_lessons.id`. No column that progress or meetings read is touched (ADR-010 decision 6).
- **Grants and RLS.** Clients get no table grants on the three tables, and RLS is enabled with no client policies. Reads go only through the operations below, so the tier and progression rules live in one place.
- **Helpers** (SECURITY DEFINER, STABLE):
  - `private.has_reached_lesson(membership, lesson)`;
  - `private.can_read_lesson_tier(lesson, tier, for_membership)`, which combines the table above with the Slice 5 relationship helpers (`is_assigned_discipler_of`, `leads_current_group_of_disciple`, `is_church_coordinator`).
- **Publishing**, trusted tooling only, executable by `service_role`:
  - `public.publish_curriculum(church, definition jsonb, content_level, licence_reference)`;
  - it validates exactly ten lessons matching `curriculum_lessons` 1 to 10, supersedes the current publication, inserts blocks (and answers when `FULL`), and audits as `CURRICULUM_PUBLISHED`.
  - It also sets `curriculum_lessons.title` from the definition. The title is identification, not content, and updating it changes no row that progress or meetings key on.
- **Reads:**
  - `get_lesson_content(lesson, for_membership default null)` returns the blocks the caller may read for that lesson, with answers only where the Discipler tier is allowed. It refuses with a reason (`lesson_not_reached`, `not_authorized`) and never leaks existence.
  - `list_lesson_access(for_membership default null)` returns, per lesson, whether the caller may read each tier. The reader index uses it to show locks.
  - `get_my_readable_content()` returns everything the caller may read now, with the publication version, for the device copy.

**Tests** (integration, RLS-explicit):
- each row of the access table, positive and negative;
- the Disciple never receives answers or Discipler blocks, even for completed lessons;
- an undo of the current lesson narrows access immediately;
- a stale or ended assignment gives nothing;
- a Leader of another group gives nothing;
- Admin-only, Pending, other church and anon get nothing;
- unknown ids reveal nothing;
- direct table SELECT is refused for every role;
- `FULL` without a licence reference is refused;
- one current publication per curriculum, and a republish keeps history;
- the publish operation is refused for `authenticated`.

### 7.2 The ten lessons as metadata

- **Definition file** (committed, metadata only), `supabase/curriculum/journey-metadata.json`, per lesson:
  - number and title. The canonical title is the cover title: Lesson 7 is "Spiritual Formation" and Lesson 9 is "Conversation";
  - theme and topic headings from the contents page. Lesson 7's theme is "Spiritual Growth" and Lesson 9's is "Words";
  - section labels and titles;
  - scripture references per section;
  - Training Module number and title, as Discipler-tier blocks.
  
  Held back until reproduction permission is recorded (ADR-019 decision 2): Key Objective sentences, banner wording, body text, fill-in statements, answers and module content.
- **Seed:** the local church publishes the definition through `publish_curriculum`, so lesson titles become real (this closes the Slice 5 finding "Lesson 1 / Lesson 1").
- **Bootstrap:** `tool/bootstrap_church.ps1` publishes the same definition after bootstrapping a real church. A separate `tool/publish_curriculum.ps1` handles later republishing.
- **Tests:** a unit test validates the definition file (ten lessons, ordered sections, known block types, no `answers` key at `METADATA`). An integration test checks that the seed's publication matches it.

### 7.3 Lesson reader and entry points (app)

- **Domain:** `LessonContent` (blocks by section), `LessonAccess` (per lesson: Disciple tier, Discipler tier, reached), and a `ContentBlock` per block type. Unknown block types render nothing, so a later full publication cannot break an older app.
- **Reader page** (`/lessons/:lessonId`, optional `?for=<membershipId>` when a Discipler, Leader or Coordinator reads in the context of a Disciple), a Reading archetype (UI_DESIGN_SYSTEM section 60):
  - lesson number, title and theme;
  - topics;
  - sections in order, with their scripture references;
  - for the Discipler tier (assigned Discipler and Coordinator only), the module headings, under a clearly labelled "For the Discipler" group;
  - while only metadata is published, one quiet line: "The full lesson is in your printed Journey book."
  
  It has no action buttons. Reading records nothing.
- **Lesson index** (`/lessons`, optional `?for=`): all ten lessons. Reached ones open; future ones are shown with a lock and "Opens when you reach this lesson". A Coordinator sees all of them open.
- **Entry points:**
  - **Journey, current lesson card:** the reserved "Open lesson" action, and "All lessons" to the index.
  - **Disciple detail** (Discipler, Leader, Coordinator): "Open Lesson N", in that Disciple's context.
  - **Coordinator:** a "Curriculum" row on the D Groups page, to the index.
- **Offline:**
  - `get_my_readable_content()` is stored per user next to the Slice 4 snapshot, in `shared_preferences`. That is enough for metadata. Full content may later need a different store, which that decision would weigh.
  - The copy is pruned to the latest response, cleared on sign-out, and display-only.
- **Tests:**
  - widget: reader per tier; locked lesson; Discipler-only group hidden from a Disciple; offline shows the cached copy and refuses nothing it never had;
  - unit: block parsing, unknown block types ignored, cache pruning.

### 7.4 Integration, documents and walkthrough

- **DBML and DC:** the three tables and the publication invariants.
- **RBAC:** section 5 and section 10 (operations).
- **Accounts table:** `config/README.md` per role.
- **Full regression;** migrations 001 to 016 unchanged.
- **Role walkthrough on the emulator** (UI_DESIGN_SYSTEM section 69), with findings classified as BUG, UX, VISUAL or FUTURE SLICE:
  - Disciple below Lesson 5;
  - Paolo (completed Lesson 5);
  - Rosa (both roles);
  - Dino (Discipler);
  - Lea (Leader);
  - Ramon (other group);
  - Admin (Coordinator);
  - Mara (no journey).

## UX review (UI_DESIGN_SYSTEM section 69)

1. **Domain:** reading the lesson in the meeting, when the Discipler leads it and the Disciple follows. The app shows the lesson's outline. It does not replace the printed book while the text is unlicensed.
2. **Roles and states:**
   - Disciple, at any lesson, plus no-journey;
   - Discipler, including one who is also a Disciple;
   - Leader;
   - Coordinator;
   - Admin-only and Pending, who get nothing;
   - offline.
3. **Information:** see the access table. The Discipler tier is never shown to a Disciple, and its existence is not hinted at.
4. **Actions:** none. Reading is passive. Navigation only.
5. **Derived values:** "reached" (defined above; to be added to DC section 11).
6. **States:**
   - loading;
   - locked: "Opens when you reach this lesson";
   - refused: restricted empty state;
   - offline with a copy, or offline without one ("Connect once to download your lessons");
   - metadata-only: the printed-book line.
7. **Patterns:** a single reading column, section headings and grouped scripture references; no tabs and no steppers.
8. **Navigation:** reached from existing screens; nothing earns a dock slot.
9. **Components:** reuse `SectionHeading`, `AppCard`, `AppPill` (outlined lock) and `EmptyState`. New: `ScriptureRefList` and `LessonIndexRow`.
10. **Cross-role:**
    - the Disciple sees their lesson;
    - the Discipler sees the same lesson plus the Discipler group, in their Disciple's context;
    - the Leader sees the Disciple tier for their group's active Disciples, never the Discipler group;
    - the Coordinator sees everything.

## Decisions (resolved 2026-10-06, user)

1. **Lesson titles:** cover titles are canonical (Lesson 7 "Spiritual Formation", Lesson 9 "Conversation"). The contents wording ("Spiritual Growth", "Words") is kept as the theme.
2. **Metadata set:** titles, themes, topic and section headings, scripture references and Training Module titles. Key Objectives, banners and all substantive wording are held back.
3. **Leader access:** the Disciple tier only, for active Disciples of the Leader's group. The Discipler tier is for the current assigned Discipler and the Coordinator.
4. **No journey, no curriculum:** confirmed explicitly.

## Out of scope

- Workbook responses and every Slice 8 item.
- Lesson text and answers until licensed.
- Pairing policy.
- Book approvals (Pastor, per lesson, final).
- Monitoring, announcements and reporting.
- Curriculum editing in the app.
