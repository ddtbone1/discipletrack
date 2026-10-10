> **Working plan, not an authoritative document.** Proposed scope for Vertical Slice 7. Governing decisions: ADR-010 as amended by ADR-019, ADR-012, ADR-015 to ADR-018. Source facts: `docs/curriculum/SOURCE_ANALYSIS.md`. Do not start implementation without an explicit instruction.

> Roadmap renumbered 2026-10-08: Slice 8 is now Platform roles and church provisioning (ADR-022), so later slice numbers in this document were shifted by one (Workbook / Guide 9, Monitoring / Follow-ups 10, Announcements 11, Reporting / Oversight 12). Nothing else was changed.

# Vertical Slice 7: Curriculum and Lesson Content

## Goal

Deliver the curriculum content architecture and a lesson reader that already enforces who may read what, populated with **identifying metadata only** (ADR-019 decisions 1 and 2). **Corrected 2026-10-06:** the lessons are now reproduced faithfully (see "Correction: faithful lesson content" below). When permission to reproduce *Journey* is confirmed, the full Disciple-tier text and the Discipler-tier answers can be published into the same structures. That later step needs no schema redesign and no security retrofit.

**Done means:**
- the ten lessons are published as metadata;
- every person reads only their permitted lessons and tiers, enforced by the database;
- the Journey and Disciple screens open the lesson reader;
- locked lessons explain themselves;
- reading works offline for what was synced and records nothing.

## Settled inputs (not reopened)

- Ten lessons; eligibility after Lesson 5 (ADR-012); completion by the Discipler (ADR-015, ADR-016, ADR-017).
- Licensing posture, the two tiers, progression-gated access, the device copy, the book-versus-ADR rule and pairing guidance not enforced (ADR-019).
- Workbook responses, verse writing, homework, Daily in the Word, memory verses, self-ratings and module sign-offs: Slice 9 under ADR-013, or later.
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

## Correction: faithful lesson content (2026-10-06, user)

Replaces the metadata-only reader direction (ADR-019 amended, decisions 11 to
15). Permission to reproduce is confirmed. Layout may change; content may not.

### 7.5 Representative lesson (Lesson 6, The Future)

- **Content model (Migration 019).** One canonical block sequence per lesson,
  in source order. New block types: `POINT` (a bulleted item, optionally led
  by a scripture reference), `FIGURE` (a chart or picture, with its labels),
  `SELF_CHECK` (the self-rating table), `SIGN_OFF` (date and signature
  lines), `ASSIGNMENT` (a numbered assignment) and `LIST`. Existing types
  keep their meaning: `PARAGRAPH`, `BANNER` (callouts), `DISCUSSION_PROMPTS`
  (Reflect & Transfer), `SCENARIO` (Water Cooler), `VERSE_WRITING`,
  `SECTION_HEADING`, `MODULE_HEADING`. A blank is written `[_]` inside the
  text, and the body carries `blanks` (the count). Answers, one per blank,
  live in `lesson_block_answers` (Discipler tier only); the trigger requires
  their count to equal `blanks`.
- **Converter** (`tool/curriculum/convert_lesson.dart`). Reads the source
  PDF with `pdftotext -raw -enc UTF-8`. Per page, it removes the page
  furniture (the repeated resource footer and "Lesson n page m"), takes the
  handwritten answer lines that follow the page marker, and parses the body
  into blocks. Answers are matched to blank-bearing lines in order. A small
  per-lesson hints file records only what the text layer cannot: callout
  lines, order corrections where the PDF's text order differs from its
  reading order, and the text of image-only areas (the lesson's cover page
  and section-title banners), transcribed and checked against the page image.
- **Verifier** (`tool/curriculum/verify_lesson.dart`). Checks, against the
  source: the word sequence of the converted lesson equals the source's
  (furniture excepted, callouts compared in place); every answer line is
  accounted for, in order; no answer text appears in a Disciple-tier block.
  It prints a report; conversion is accepted only when it passes.
- **Renderer.** One reader, two presentations: the Disciple view shows each
  blank as an empty line; the Discipler view shows the answer in the blank,
  marked as an answer. Verse-writing, self-check and sign-off areas are shown
  as in the book but not yet filled or saved (Slice 9).
- **Where the text lives.** Converted lessons and hints are kept in
  `supabase/curriculum/full/` (git-ignored). Publishing: `publish_curriculum`
  at level FULL with the licence reference (ADR-019 decision 11).
- **Verification before bulk conversion:** the verifier passes; a visual
  comparison of each page with the source; integration tests for answers and
  Discipler-only content with a synthetic FULL fixture (no source text in the
  repository); the user reviews Lesson 6 in the app.

### 7.6 All ten lessons

The same converter and verifier for Lessons 1 to 10, with a hints file each.
Published FULL once every lesson passes.

Delivered 2026-10-06:

- **Conversion:** all ten lessons pass `verify_lesson.dart` with no warning
  (every word, in order; every answer; one block per bullet). Published FULL
  locally: 1,072 blocks. Writing fields (date, signature, day, time, place)
  are `[~]`, always empty; the Lesson 5 stewardship wheel is a figure with its
  printed labels.
- **Access (user decision, ADR-019 decision 16):** any Discipler, every
  Leader included, reads all ten lessons in both tiers in any context. A
  Disciple reads completed lessons and the current one; the next opens when
  the current one is marked completed. Checked in the local database: Diana
  1 to 2, Paolo 1 to 6, Dino, Lea, Ramon and Rosa all ten in both tiers, Mara
  and Nina none, the Coordinator all.
- **Lesson list:** ten cards over the book's cover photos (`lesson_covers`,
  `build_covers.dart`; the source photos are Adobe CMYK JPEGs and are
  inverted on extraction), locked ones dimmed with a lock. A journey page
  (My Journey, Disciple detail) has one Lessons card into that list; the
  Lessons timeline and the Read Lesson button there are removed. Home keeps
  Read Lesson N for a Disciple.
- **Less is more:** the current lesson card shows one coloured line (state
  and last meeting) instead of a pill, a date line, a count heading and
  outcome pills; Disciple rows show the ring, the name and one line; Home's
  journey card shows the lesson, the bar and Read; the meeting fact pills
  under the calendar are gone, except a run of recorded absences on
  Disciple detail.
- **Tests:** 381 unit and widget, 290 integration (including covers and the
  Discipler-reads-all rule).

Follow-up, 2026-10-07 (user):

- **Fillable lessons (ADR-021):** in their own lesson a Disciple types into
  blanks, writing fields and verse lines and picks self-check ratings; saved
  on the phone only, per person and lesson, kept across sign-out. A
  Discipler's read stays answers-only.
- **Home:** the journey card is a swipeable carousel of the ten cover cards,
  starting on the current lesson, under one line of facts. The Read Lesson
  button is gone; the current card opens the reader.
- **Members tabs:** one fixed row; the active tab is lime text and a thin
  lime outline.
- **Empty meetings:** an illustration, one sentence and, for whoever may
  record, a "Record your first meeting" link.
- **Covers:** `build_covers.dart` prefers the ministry's images in
  `docs/curriculum/source/covers/lesson-01.jpg` to `lesson-10.jpg`
  (git-ignored), falling back to the PDF photo.
- **Content in the repository (2026-10-07):** the church publishes Journey,
  so `supabase/curriculum/full/` is versioned and seeded by `db reset`. The
  licence reference names the church as publisher. Lesson text is shown with
  references in bold text and green kept for answers only.

Follow-up 2, 2026-10-07 (user): every question answerable in the app
(ADR-021 decisions 6 to 8).

- **Structure:** `lesson_structure.dart` merges each assignment with its
  lines, splits lettered questions and choices, gives each item its answer
  kind, and turns the Daily in the Word charts (Lesson 2, 1st John; Lesson 3,
  Mark, 184 readings) into one row per reading with a date. All ten lessons
  still pass `verify_lesson.dart` word for word. One choice item (Lesson 1),
  one True/False (Lesson 4); the rest are blanks, written answers and tasks.
- **Check:** "Check my answers" at the end of a lesson (Migration 020).
- **Rosa:** her own lessons in the Disciple view, with "Show answers".
- **Lists:** chevrons centred; a lime progress ring around a Disciple's
  avatar on My D Group; inline links in the brand green, bold, no
  underline (lime in dark mode).

Follow-up 3, 2026-10-07 (user): profile and account.

- **Profile** in the reference's layout: avatar with a pencil badge, name,
  church and roles; Personal info (Edit), Ministry and Account cards;
  Sign out as a red text link.
- **Avatars (Migration 021):** twelve bundled CC0 illustrations (DiceBear
  Notionists), stored as "preset:n"; shown everywhere initials were.
  Photo uploads are left for a later decision (file storage, ADR).
- **Account:** Change password on its own page (current password first,
  then a new one meeting every rule, typed twice). Password rules, enforced by
  the auth server (`minimum_password_length = 8`, `password_requirements =
  "lower_upper_letters_digits_symbols"`) and shown as a live checklist on
  sign-up and change password; sign-up asks for the password twice. The
  sign-in email stays the one used at registration (user decision; no change
  of email in the app). The theme switch moved here.
- **D Group screens:** My D Group in clusters (overview with a donut of who
  the group is made of, Walking with you, Your Disciples, the rest by role);
  D Groups (Coordinator) with a church donut, the groups, then people
  waiting on the Coordinator, then the setup period. Charts are drawn in the
  app (`core/widgets/charts.dart`), no library.
- **Lessons:** a Leader, or a Discipler who is not a Disciple, reads lessons
  with answers and gets the Lessons carousel on Home.
- **Record a meeting** and the Journey history page restyled; tabs with a
  full-width line.

### Known limits

- Rosa, a Disciple who is also a Discipler, reads her own lessons ahead and
  with answers (ADR-019 decision 16, accepted).
- Lesson 10's cover is almost white, so its card reads mostly as the shade.
- Charts and pictures (for example Lesson 6's time chart) are images in the
  source. They are shown as figures with their caption and labels until image
  assets are supplied.

## Out of scope

- Workbook responses and every Slice 9 item.
- Lesson text and answers until licensed.
- Pairing policy.
- Book approvals (Pastor, per lesson, final).
- Monitoring, announcements and reporting.
- Curriculum editing in the app.

## Delivery record (2026-10-06)

Status: implemented, awaiting acceptance. Not committed.

**7.1 Database.** Migration 017 (`20261006000010_curriculum_content.sql`):
`curriculum_publications`, `lesson_content_blocks`, `lesson_block_answers`;
enums `curriculum_content_level`, `content_tier`, `lesson_block_type`;
integrity and immutability triggers; `private.has_reached_lesson()` and
`private.can_read_lesson_tier()`; `publish_curriculum()` (service role only),
`get_lesson_content()`, `list_lesson_access()`, `get_my_readable_content()`.
The content tables have RLS enabled, no client policy and no client grant.

**7.2 Metadata.** `supabase/curriculum/journey-metadata.json` (ten lessons,
cover titles canonical), generated `supabase/seed_curriculum.sql`, run by
`db reset` after `seed.sql`; `tool/publish_curriculum.ps1` for real projects.
No lesson wording, Key Objectives, banners or answers in the repository.

**7.3 App.** `lib/features/curriculum/`: domain model, repository, device
copy (`shared_preferences`, replaced on each refresh, cleared on sign-out),
providers with offline fallback, `LessonIndexPage`, `LessonReaderPage`,
`LessonLinks`. Entry points: "Open Lesson N" and "Read the lessons" under the
current-lesson card on My Journey and on a Disciple's detail; "Curriculum" on
the Coordinator's D Groups page. The plan's `ScriptureRefList` was not needed
as a separate component: references are a wrap of outlined `AppPill`s.

**7.4 Documents.** DBML section 11a, enums and refs; DATABASE_CONSTRAINTS
section 4 Lesson Content Publications and section 11 Reached Lessons (plus the
member-count note under Needs Setup); RBAC section 5 note and section 10
operations; `config/README.md` lesson content notes.

**Verification.**
- `flutter analyze`: no issues. `dart format`: no changes.
- Unit and widget: 360 passed, re-run after the walkthrough fixes.
  New: `test/unit/lesson_content_test.dart`
  (11), `test/unit/curriculum_definition_test.dart` (5),
  `test/widget/curriculum_pages_test.dart` (8).
- Integration: 285 passed, including `curriculum_content_test.dart` (15).

**Role walkthrough.** Emulator: Diana (lesson list, Lesson 2 reader), Dino
(Rosa's Lesson 6 with the Discipler group). Database, impersonating each seeded
account through `list_lesson_access()`:

| Account | Own lessons | Rosa's context | Tomas (other group) |
|---|---|---|---|
| Diana | 1, 2 Disciple tier | refused | refused |
| Paolo | 1 to 6 Disciple tier | refused | refused |
| Rosa | 1 to 6 Disciple tier | (self) | refused |
| Dino | none | 1 to 6 both tiers | refused |
| Lea | none | 1 to 6 Disciple tier | refused |
| Ramon | none | refused | 1 Disciple tier |
| Admin (Coordinator) | all, both tiers | all, both tiers | all, both tiers |
| Mara, Nina | none (no journey) | refused | refused |

Lea's `get_lesson_content()` of Rosa's Lesson 6 returns 6 blocks with no
Discipler tier; Dino's returns 7, including the Training Module heading.

**Findings.**
- UX, fixed: the lesson list repeated the title as the theme ("Salvation /
  Salvation"); the theme now shows only when it differs.
- VISUAL, fixed: the reader repeated "Lesson N" in a pill under the app bar
  title; the pill is removed.
- UX, fixed during 7.3: the journey link "All lessons" collided with the
  existing "All lessons" expander on My Journey; renamed "Read the lessons".
- VISUAL, open: the dock shows no active tab on lesson pages (they are reached
  from Journey or D Groups, not from a dock root).
- UX, fixed: a refused lesson read waited for Riverpod's automatic retries
  before the restricted state showed. The lesson providers no longer retry a
  refusal; the widget test now asserts it without settling.
- Not walked on the emulator: the Admin's Curriculum button, Lea's and Ramon's
  screens, and offline reading. Their access is verified in the database table
  above, and offline reading is covered by widget tests.

## Follow-up after the walkthrough (2026-10-06)

User feedback and decisions, implemented on top of Slice 7 (plan:
`cheeky-prancing-sunset`), still uncommitted.

- **Join Church flash after sign-in (BUG, fixed).** The session state read
  the membership left over from the signed-out period while the new user's
  membership loaded. A reload whose value belongs to another user now counts
  as pending (`session_state.dart`). Regression test:
  `test/unit/session_sign_in_test.dart`; it fails without the fix.
- **Welcome for the admin (fixed).** The founder's membership is created
  onboarded by `bootstrap_church()`; existing founders are backfilled
  (Migration 018).
- **Every Leader is a Discipler (ADR-020, Migration 018).** The role comes
  with the leadership and cannot end while they lead (deferred constraint
  trigger). Leaders share the Discipler's screens: the dock's D Group opens
  the My D Group roster, with "Manage members" for the Leader; Journey and My
  Disciples follow. "Add myself as Discipler" is gone. Seed: Lea disciples
  Felix; Tomas is now the unpaired Disciple.
- **Pills and coloured text (VISUAL).** Roles (Leader, Discipler, Disciple)
  are coloured text (`RoleBadge`, later small badges); pills are kept for states (Needs
  setup, Not paired, lesson states). Filter chips have no outline. Rule
  recorded in UI_DESIGN_SYSTEM section 39.
- **Lesson navigation.** "Read Lesson N" inside the current-lesson card
  (secondary; on Disciple detail below Record and Mark completed), a lime
  "Read Lesson N" on the Disciple's Home journey card, and an always-visible
  Lessons timeline on My Journey and Disciple detail (`LessonTimeline`, on
  `StepList`, which gained tappable and locked steps). The collapsed "All
  lessons" accordion and the underlined links are removed. Lesson pages keep
  Journey active in the dock. UI_DESIGN_SYSTEM section 61 updated.
- **Remembered sign-in.** The session already persists. The last email is
  remembered on the device and filled in; "Not you? Use another account"
  forgets it. The form is an autofill group, so the phone's password manager
  can save and fill the password. No biometric unlock (user decision).
- **Activity cards (VISUAL).** Journey and Recent activity cards are plain
  white with the state as a coloured bar on the inside left edge (lime for
  Present and completed, amber Late, red Absent, grey Excused), not a
  tinted fill.

**Verification of the follow-up.** `flutter analyze` clean; `dart format` no
changes; unit and widget 368 passed; integration 285 passed after a fresh
`db reset`. Emulator: no Join Church frame during sign-in (the splash shows
until the membership is loaded); Lea has Journey, the shared roster with
Manage members and Felix; Diana reads Lesson 2 from Home and sees the Lessons
timeline; a restart keeps the session. The admin's onboarding is set by the
bootstrap (checked in the database and `bootstrap_test`). The remembered email
is covered by widget tests, not walked on the emulator.

**Second UI pass (2026-10-06, user).** Sign-in drops "Not you?"; the email is
remembered and the password is left to the phone's password manager (no
password stored by the app, user decision). Manage members is lime. Member
rows: name, small borderless role badges (plus Needs setup or Eligible), and
one fact line with "Lesson n of 10" as coloured text; Set up, Pair and Change
are compact round icon buttons with tooltips; the overflow menu is the
horizontal "more" icon and opens a rounded menu; the filter chips are rounded.
Unit and widget tests (368) and the analyzer pass.

## 7.5 delivery record: representative lesson (2026-10-06)

Status: Lesson 6 converted, verified and readable in both presentations;
awaiting the user's review before 7.6 (all ten lessons). Not committed.

- **Migration 019** (`20261006000012_curriculum_full_content.sql`): block
  types POINT, FIGURE, SELF_CHECK, SIGN_OFF, ASSIGNMENT, LIST, HEADING; the
  `blanks` count and the one-answer-per-blank rule.
- **Tools** (`tool/curriculum/`): `lesson_source.dart` and
  `lesson_builder.dart` (the conversion), `convert_lesson.dart`,
  `verify_lesson.dart`, `build_definition.dart` (FULL definition and local
  publish SQL). Lesson files and hints live in the git-ignored
  `supabase/curriculum/full/`.
- **Verification of Lesson 6:** `verify_lesson.dart 6` PASS: 2,465 source
  words and 2,465 lesson words, none missing or added; 146 answer words in
  order; one POINT per bullet; relocations only where hinted (5 callouts,
  2 reading-order moves on the review page, the chart labels under
  assignment 3). 11 image-only blocks (section titles, Key Objectives,
  page banners, the module banner) were transcribed from the extracted
  banner images and checked visually.
- **Access, local database:** Rosa (Disciple) reads 64 blocks, none of the
  Discipler tier, no answers. Dino (her Discipler) reads 90 blocks, including
  the 26 of Module 2, with 37 answered blocks.
- **Tests:** converter unit tests (11, synthetic text), full-lesson widget
  tests (Disciple blanks, Discipler answers), curriculum integration tests
  (19, including Disciple/Discipler/Leader reads of a synthetic FULL lesson
  and the one-answer-per-blank refusal).
- **Known limits:** the time chart (page 4) and the assignment chart (page
  9) are vector drawings, not images; they show as figures with their labels
  (answers for the Discipler) until chart images are supplied. The cover
  page holds only the title and decorative topic words. Page footers and
  "Lesson n page m" are omitted as print furniture.
- **Licence reference:** the church publishes Journey itself (user,
  2026-10-07). The reference, used locally (publication version 3) and for a
  hosted project: "Journey is published by Liberty Bible Baptist Church -
  Gensan, which reproduces it in DiscipleTrack as its publisher (confirmed
  2026-10-07)."
