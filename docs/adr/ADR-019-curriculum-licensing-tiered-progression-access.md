# ADR-019: Curriculum Licensing Posture, Tiered Content and Progression-Gated Access

## Status

Accepted (2026-10-06, user decisions after the curriculum source analysis, `docs/curriculum/SOURCE_ANALYSIS.md`). Amended the same day (user): Leaders read the Disciple tier only; the no-journey rule is explicit; the metadata boundary and canonical titles are fixed (decisions 2 and 6).

Partially supersedes [ADR-010](ADR-010-lesson-content-delivery.md):
- decision 1, the repository Markdown as the source for publishing;
- decision 12, every ACTIVE member reads all lesson content.

ADR-010 decisions 2 to 11 and 13 remain accepted, as amended for the device copy (decision 7 below).

Takes over two expectations that the reserved ADR-013 (Workbook and Guide) was to settle:
- that answers are protected server-side;
- that Discipler (Guide) access is scoped to the relationship with the Disciple.

ADR-013 still owns the workbook: a person's own responses, and the Workbook and Guide experience.

Confirms the ten-lesson curriculum (user decision 2026-10-05) as authoritative. Twelve-lesson wording in earlier documents is historical.

## Context

The ministry's material is *Journey* by John and Cathy Honeycutt, a published third-party curriculum. The copies supplied are the Discipler's edition ("DISCIPLERS' COPY"), with every blank answered. They carry no licence notice.

The source is clear on three points:
- the Discipler holds the answers and gives them during the meeting;
- the disciple works only with the Discipler and "not in advance";
- the material has two audiences, the Disciple's workbook and the Discipler's guide (answers, Discipler notes, training modules).

ADR-010 assumed the opposite on all three:
- the lesson text kept as Markdown in the repository;
- the same content for every ACTIVE member;
- every lesson readable at any time.

The book also prescribes workflow that the ministry has deliberately decided differently (ADR-012, ADR-015, ADR-018):
- a Pastor co-signature at Lesson 5;
- church-leadership permission before each next lesson;
- approval to disciple only after Lesson 10;
- a Final Approval;
- same-gender and family pairing rules.

## Decision

### Licensing posture

1. **Digital reproduction is treated as unlicensed** until the ministry confirms explicit permission from the rights holder. Until then:
   - no substantial lesson text, answers, Discipler notes or module content is committed to the repository, published to Supabase or shipped in the app;
   - the source PDFs stay local and git-ignored (`docs/curriculum/source/`);
   - working analyses (`docs/curriculum/`) describe structure and quote only short phrases where a finding needs one.
2. **Only identifying metadata is published now:** lesson number and title, the lesson's theme, topic and section headings, scripture references and Training Module titles. Key Objective sentences, headline (banner) wording and all substantive lesson, workbook or guide wording are held back until reproduction permission is explicitly recorded (amended 2026-10-06). Canonical titles are the cover titles: Lesson 7 is "Spiritual Formation" and Lesson 9 is "Conversation"; the contents-page wording ("Spiritual Growth", "Words") is kept as the lesson theme.
3. **The architecture supports the full material later.** Once permission exists, the same structures carry the full content with no schema redesign. Publishing the full content then needs only an explicit decision that records the permission.

### Source and publishing (replaces ADR-010 decision 1)

4. The publishing source is a structured curriculum definition that holds only content the repository may contain, which at present is the metadata of decision 2. Full content, once licensed, is supplied to the trusted publishing tooling from outside the repository, unless the licence allows it to be committed. Publishing stays trusted tooling in the service-role context (ADR-010 decision 2). Supabase stays authoritative (ADR-010 decision 3).

### Two content tiers

5. **Each piece of content belongs to exactly one tier:**
   - **Disciple tier.** What the Disciple works through: the lesson's sections, statements with their blanks, discussion prompts and assignments.
   - **Discipler tier.** Answers, Discipler-only notes, and the Discipleship Training Modules' guide material.

   Answers are stored apart from the content they answer, so the database can withhold them by policy, not by client filtering.

### Who may read what (replaces ADR-010 decision 12)

6. **Read scope:**
   - **Lesson list** (number and title, `curriculum_lessons`): unchanged, every ACTIVE member of the church, including those not in a D Group.
   - **Disciple tier of lesson N:**
     - the person themselves, for lessons they have reached. Never a future lesson.
     - their current assigned Discipler, for the same lessons;
     - the Leader of their current D Group, for the same lessons, while the Disciple holds an active DISCIPLE responsibility in that group;
     - the Coordinator, for any lesson.
   - **Discipler tier of lesson N:**
     - the current assigned Discipler of a Disciple who has reached lesson N;
     - the Coordinator, for any lesson.
     - Never the Disciple, including for their own completed lessons.
     - **Never the Leader (least privilege, amended 2026-10-06).** Recording a meeting on a Discipler's behalf (Slice 5 fallback) does not by itself grant access to answers, Discipler notes or training content. A Leader who is also a Discipler reads the Discipler tier only through their own assigned Disciples. A future ministry policy may expand Leader access to this tier explicitly.
   - **Nobody else.** That includes an Admin without Coordinator, a member with no journey and no Disciples, and a Discipler for lessons none of their Disciples has reached.
   - **"Reached" is derived from progress, never stored.** A person has reached every lesson they have COMPLETED. They have also reached their current lesson (`private.eligible_lesson()`), but only while they hold an active DISCIPLE responsibility. An undo or reopen that moves the current lesson back narrows access at once.
   - **No journey, no curriculum.** Internal progression logic resolves a default current lesson (Lesson 1) for anyone, including someone who has never been a Disciple. That default grants nothing. Curriculum authorization always requires the relationship or responsibility named above: an active Disciple journey, a current assignment as Discipler, leadership of the Disciple's group, or the Coordinator role.
   - Authority follows the relationship, never the responsibility in general (ADR-012 decision 8). A Disciple who is also a Discipler reads the Disciple tier for their own reached lessons, and the Discipler tier for their Disciples' reached lessons.

### Device copy (amends ADR-010 decisions 8 and 9)

7. **Offline reading caches only what the server returned for that person**, including the Discipler tier for a Discipler. It stays display data, is cleared on sign-out, and is pruned to the current scope on every refresh, so access that has ended does not stay readable after the next sync. Offline reading never authorizes anything and never enables a write (ADR-010 decisions 10 and 11).

### Book workflow versus DiscipleTrack decisions

8. **Where the book's workflow conflicts with an accepted ADR, the ADR governs.** None of these is implemented:
   - Pastor or church-leadership approval per lesson or at Lesson 5;
   - "approval to disciple" after Lesson 10;
   - the Final Approval;
   - "Journey complete when you have your own disciple".

   Specifically:
   - lesson completion stays ADR-015 (the Discipler marks it), ADR-016 and ADR-017;
   - Discipler eligibility stays Lesson 5 (ADR-012);
   - appointment stays the Coordinator's (ADR-018).

   The discrepancies are recorded in `docs/curriculum/SOURCE_ANALYSIS.md`.
9. **Pairing guidance is recorded, not enforced.** The source's guidance is: men meet with men and women with women; the church leadership decides who meets with whom; close family members and best friends pair only with the Pastor's approval. This is recorded as future ministry-policy guidance. Pairing remains the Leader's or Coordinator's decision (ADR-018) with no gender or relationship rule.

### Deferred

10. **The workbook belongs to Slice 8 or a later pilot decision, under ADR-013:**
   - a person's responses to blanks;
   - verse writing;
   - homework answers;
   - the Daily in the Word notebook and reading plans;
   - memory verses;
   - self-ratings;
   - Training Module sign-offs.

   Reading content records nothing (ADR-010 decision 7).

## Alternatives Considered

**Publish the source text now and seek permission later.** Rejected. It distributes a third-party work without a confirmed right to do so.

**One read scope for all content, with answers hidden by the client.** Rejected. The client is untrusted (AGENTS.md). Answers must be withheld by the database.

**Gate every lesson behind Leader or Pastor permission, as the book prescribes.** Rejected by ADR-015: completion and progression follow the Discipler's marking only.

**Leave all lessons readable to everyone (ADR-010 as written).** Rejected. It contradicts the source's "not in advance" practice and would expose future material.

**Defer the tier and access architecture to Slice 8.** Rejected. The tier boundary and progression gate shape the schema. Building them now means licensed content can be added later without a redesign or a security retrofit.

## Consequences

- **Slice 7 builds:**
  - the content structures, with tiers and separately stored answers;
  - the progression-gated read operations and their RLS;
  - a metadata-only publication of the ten lessons;
  - a reader that shows what each person may read.
- **Documents updated in the same pass:**
  - RBAC_RLS_MATRIX: the "Read lesson content" row and its note, plus new rows for the two tiers;
  - BUSINESS_RULES BR-029a;
  - MVP_SPEC section 18;
  - ARCHITECTURE section 10a;
  - DATABASE_CONSTRAINTS section 0;
  - the DBML `curricula` note;
  - the ADR-013 reserved entry.
- **The DBML content tables** are added by the Slice 7 migration, as ADR-010 anticipated.
- **ADR-013**, when written, covers the workbook experience and responses only. The tier boundary and the read scope above are already decided.
