# DiscipleTrack — Engineering Instructions

Instructions for anyone working in this repository, human or AI agent.

## Current phase

Implementation, in vertical slices. Completed: Slice 1 Auth + Profile (migrations 001 to 003); Slice 2 Church Join + Membership Approval + First Entry (migrations 004 and 005, bootstrap, seed); Slice 3 Ministry Structure (migration 006: D Groups with a Leader, placement by invitation, pairing, removal, role-scoped reads); Slice 4 Offline read-only (client only, no migration: a device snapshot of what the person may already see, view-only while offline); Slice 5 Journey / Meeting Progress (migrations 007 to 011: meetings recorded with an explicit outcome per Disciple, the Discipler marks a lesson completed with an undo window (ADR-015) and no meeting minimum (ADR-017), meeting and participant voids, a completion locked once later progress exists with reopen kept database-only (ADR-016), members' progress for the Leader and Coordinator; plan and delivery record in `docs/plans/slice-5-discipleship-meeting-progress.md`); Slice 6 D Group Assignment and Discipler Progression (migrations 012 to 016: direct placement with Needs setup (members count from the moment they are added), the initial setup window and Existing Discipler recognition, setup and pairing with concurrent Disciple and Discipler, Discipler eligibility and Coordinator appointment, appointment locks undo (ADR-018); plan and delivery record in `docs/plans/slice-6-d-group-assignment-discipler-progression.md`); Slice 7 Curriculum / Lesson Content (migrations 017 to 019: the ten Journey lessons published in two tiers, the Disciple tier gated by reached lessons and any Discipler reading all ten (ADR-019, amended), every Leader holds the Discipler role (ADR-020), lesson covers, fillable lessons saved on the device only (ADR-021); the converted lessons and covers are versioned in `supabase/curriculum/full/` and seeded by `db reset`, the source PDFs stay git-ignored; plan and delivery record in `docs/plans/slice-7-curriculum-lesson-content.md`). Next: Slice 8, not started. N1 is closed (ADR-017): meeting count never determines lesson completion.

Remaining roadmap (revised 2026-10-07; re-checked before each slice): 8 Workbook / Guide (ADR-013, reserved); 9 Monitoring / Follow-ups (ADR-014: consecutive recorded absences only); 10 Announcements; 11 Reporting / Oversight. Numbering is not fixed: if dependency analysis shows a better order, the roadmap changes. Monitoring depends only on Slice 5, which is complete, so it may move ahead of Slice 8 if ministry priorities justify it. Whether Slices 8 and 10 stay in the MVP, and how much of 11 is needed, is to be re-checked after a pilot with a real D Group. UI refinement happens inside each slice; there is no separate redesign slice. Removed from the MVP and not planned: D Group gatherings and gathering attendance (ADR-014), Leader confirmation of lessons (ADR-015), correction of a lesson after later progress exists (ADR-016), and any minimum number of meetings per lesson (ADR-017).

Applied migrations are immutable. Any schema change goes in a new migration.

The specification has been through audit and resolution passes, but treat it as reviewable rather than infallible. If you find a contradiction, report it instead of choosing a side. See the rules below.

Do not begin implementation without an explicit instruction to do so.

## Read order

Before writing anything, read in this order:

1. [README.md](README.md)
2. [docs/MVP_SPEC.md](docs/MVP_SPEC.md)
3. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
4. [docs/BUSINESS_RULES.md](docs/BUSINESS_RULES.md)
5. [docs/adr/](docs/adr/) — all of them
6. [docs/erd/discipletrack.dbml](docs/erd/discipletrack.dbml)
7. [docs/database/DATABASE_CONSTRAINTS.md](docs/database/DATABASE_CONSTRAINTS.md)
8. [docs/security/RBAC_RLS_MATRIX.md](docs/security/RBAC_RLS_MATRIX.md)
9. [docs/UI_DESIGN_SYSTEM.md](docs/UI_DESIGN_SYSTEM.md) before any UI work

Every slice plan runs the slice UX review in UI_DESIGN_SYSTEM.md section 69 before implementation, and its role walkthrough again before the slice is called done.

## Document authority

Authority is domain-specific, not a ranked override chain. See [ADR-008](docs/adr/ADR-008-documentation-precedence.md).

| Subject | Governing artifact |
|---|---|
| Architectural decisions and rationale | `docs/adr/` |
| Database structure | `docs/erd/discipletrack.dbml` |
| Database invariants and enforcement | `docs/database/DATABASE_CONSTRAINTS.md` |
| Authorization | `docs/security/RBAC_RLS_MATRIX.md` |
| Domain behaviour | `docs/BUSINESS_RULES.md` |
| MVP scope and workflows | `docs/MVP_SPEC.md` |
| Database rationale and examples | `docs/DATABASE_DESIGN.md` |
| UI and presentation | `docs/UI_DESIGN_SYSTEM.md` |

`DATABASE_DESIGN.md` is non-normative for schema. Do not implement a table from it.

## Rules

**Never silently contradict an ADR.** Either follow the accepted decision, or write a new ADR explaining why it is superseded. Do not quietly diverge.

**Never silently resolve a contradiction.** If two authoritative documents disagree, that means a decision was never made. Report it. Guessing turns a visible gap into an invisible one.

**Never put a business rule only in Flutter.** Flutter is an untrusted client. Sensitive permissions and important invariants belong in PostgreSQL, RLS and controlled database operations.

**Never delete history.** End, resolve, cancel, archive or void records instead. Queries distinguish active from historical.

**Do not store derived values** such as consecutive recorded absences, meeting count, lessons completed or Discipler eligibility as independent sources of truth. Definitions are in `DATABASE_CONSTRAINTS.md`.

**Do not introduce post-MVP scope.** The out-of-scope list in `MVP_SPEC.md` is deliberate.

**Do not add dependencies or infrastructure** without a concrete identified requirement.

## Identity levels

Three levels exist and must not be interchanged:

- `profiles.id` — who performed an action (`*_by`, `*_user_id`)
- `church_memberships.id` — a person's durable identity within a church, and ongoing responsibility
- `d_group_memberships.id` — relationships depending on contextual D Group responsibility

Discipleship progress and meeting participation key to `church_memberships.id` so they survive D Group transfer and Discipler reassignment. This is deliberate.

## Verification

```
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed .
```

Code is not correct merely because it compiles. Deterministic mechanisms are authoritative: the analyzer, tests, database constraints, RLS and CI.

## Testing expectations

- Unit tests for deterministic domain logic: consecutive recorded absences, lesson eligibility, follow-up assignment, Discipler eligibility
- Integration tests for repositories, constraints, authentication and RLS policies
- RLS policies must be explicitly tested, not assumed
