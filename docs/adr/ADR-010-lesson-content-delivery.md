# ADR-010: Lesson Content Delivery and Offline-First Reading

## Status

Accepted (2026-10-02, decision A2).

Implementation belongs to the Curriculum / Lesson Content vertical
slice. The concrete content structure is deliberately left open until
the real lesson material has been inspected (see Consequences).

Curriculum size revised to ten lessons (user decision 2026-10-05);
references to twelve lessons below are historical.

Partially superseded by
[ADR-019](ADR-019-curriculum-licensing-tiered-progression-access.md)
(2026-10-06): decision 1 (repository Markdown as the publishing
source) and decision 12 (one read scope for all content). Decisions 8
and 9 are amended: the device caches only what the server returned for
the person and is pruned on refresh. Until permission to reproduce the
source curriculum is confirmed, only identifying metadata is published.

## Context

Until this decision the specification stated that DiscipleTrack tracks
progress through the curriculum but "does not store or deliver lesson
content" (DBML `curricula` note; DATABASE_CONSTRAINTS.md section 0).
Lesson rows were identification and ordering only.

The ministry wants Disciples, Disciplers and Leaders to read the twelve
lessons inside the app. Disciplers and Disciples often meet where the
connection is poor, so reading must keep working without a connection
once the material has been received.

Two existing boundaries are affected:

- **Product and data scope.** Storing and delivering lesson material is
  new scope. MVP_SPEC section 18 already allowed that "lesson
  names/content may be managed as church-owned curriculum data", but the
  DBML and DATABASE_CONSTRAINTS excluded it.
- **Offline scope.** Vertical Slice 4 approved a narrow, view-only device
  snapshot (own profile, membership, church name, roles, group names and
  permitted phone numbers; Slice 3 plan section K). Lesson material is a
  different and larger kind of local data. MVP_SPEC section 33 excludes
  full offline synchronization.

No lesson Markdown exists in the repository at the time of this
decision.

## Decision

### Source, publishing and authority

1. The twelve lessons originate as maintainable Markdown files kept in
   the repository. The repository files are the **source for
   publishing**. They are not the runtime source of truth.
2. A trusted import/publishing process converts the source into the
   **published curriculum content** stored in Supabase/PostgreSQL. Like
   bootstrap (DATABASE_CONSTRAINTS.md section 0), publishing is trusted
   tooling run in the service-role or migration context. It is not a
   Flutter operation and has no client write path.
3. The published content in Supabase is **authoritative**. Flutter
   renders what Supabase serves.
4. Bundling the material inside the app as its only source is not
   adopted. It may be reconsidered only if later analysis justifies it,
   for example as a first-launch fallback.

### Separation from business state

5. Lesson content is kept separate from meeting records, attendance,
   lesson progress, completion and monitoring state. Content belongs to
   a lesson; it never belongs to a person.
6. Content is stored outside `curriculum_lessons` columns that progress
   depends on, so publishing new content never modifies a row that
   meetings or progress reference. Progress, meetings and completion
   continue to key to `curriculum_lessons.id` and never to a content
   version.
7. Reading a lesson records nothing. Opening, scrolling or finishing a
   lesson in the reader is not progress, not attendance and not a
   completion signal. Lesson completion follows ADR-011.

### Offline-first reading

8. Reading is offline-first. After the published curriculum has synced
   to the device once, every lesson the person may read is readable
   without a connection. There is no manual per-lesson download step.
9. The device keeps the last synced published curriculum. When online,
   the client refreshes it when the published version changes.
10. Offline reading does **not** imply offline writes. Every write stays
    server-authoritative and online-only, as in Slice 4. Nothing is
    queued. A read-only content cache is not the "full offline
    synchronization" that MVP_SPEC section 33 excludes.
11. The local copy is display data only. It never authorizes anything,
    and a refusal from the server is never masked by cached content.

### Who may read

12. Lesson content follows the existing curriculum read scope
    (RBAC_RLS_MATRIX.md sections 1, 1a, 2 and 5): every ACTIVE member of
    the church, including a member without a D Group and an Admin
    without Coordinator. PENDING and non-ACTIVE memberships read no
    curriculum and receive no content.
13. Lesson content contains no personal or ministry-care data, so ADR-004
    (Admin has no ministry-care access) is not affected.

## Alternatives Considered

**Keep "no lesson content".** Rejected by the ministry: material is
needed during meetings.

**Supabase Storage files.** Not chosen as the default. Files would need
their own access rules beside RLS and a second publishing path. It
remains an option for images, if the real material contains them.

**Bundle Markdown in the app only.** Rejected as the only source. Every
content correction would need an app release, and Supabase would no
longer be authoritative.

**Manual per-lesson download.** Rejected. It adds a chore and fails
exactly when the person is offline and forgot to download.

**Content columns on `curriculum_lessons`.** Not recommended. Content
edits would touch the rows that progress and meetings reference.

## Why

Disciples and Disciplers need the material where they meet. Keeping the
published content in PostgreSQL keeps one authoritative copy under the
same church isolation and RLS as the rest of the curriculum, while the
repository Markdown stays reviewable and maintainable. Offline-first
reading removes a chore without weakening server authority, because no
write ever depends on the cache.

## Consequences

- DBML: the `curricula` note no longer says the app does not store or
  deliver lesson content. A content structure (expected: a separate
  table keyed to `curriculum_lessons.id`, with a published version and
  publication time) is added to the DBML by the Curriculum / Lesson
  Content slice, **after** the real Markdown has been inspected. It is
  not specified now, to avoid over-structuring material nobody has seen.
- DATABASE_CONSTRAINTS section 0: lesson rows remain identification and
  ordering; content is published separately under this ADR.
- RBAC_RLS_MATRIX section 5: content SELECT follows `curriculum_lessons`;
  no client write path.
- Offline scope grows beyond the Slice 4 snapshot by exactly one item:
  the published lesson content. Progress, meetings and other ministry
  data are not added to the device by this ADR.
- A Markdown renderer is a new Flutter dependency. Under AGENTS.md it is
  approved in the content slice, against the real material, not before.
- Storage for the local copy (`shared_preferences`, already installed,
  or a file in the app's documents directory) is chosen in the content
  slice after measuring the material. Images in the material would
  favour files.
- The local copy is cleared on sign-out, like the Slice 4 snapshot.
- Open points for the content slice: whether images or other media
  exist; how a lesson is split (sections, headings); how a published
  version is identified; whether a content change invalidates nothing
  (expected) or needs a notice to readers.
