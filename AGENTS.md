# DiscipleTrack — Engineering Instructions

Instructions for anyone working in this repository, human or AI agent.

## Current phase

Implementation, in vertical slices. Completed: Slice 1 Auth + Profile (migrations 001 to 003); Slice 2 Church Join + Membership Approval + First Entry (migrations 004 and 005, bootstrap, seed); Slice 3 Ministry Structure (migration 006: D Groups with a Leader, placement by invitation, pairing, removal, role-scoped reads); Slice 4 Offline read-only (client only, no migration: a device snapshot of what the person may already see, view-only while offline). Planned: Slice 5 Journey / Meeting Progress (plan in `docs/plans/`; attendance exists only as a discipleship meeting outcome recorded through Record Meeting). Not started: Slices 6 to 11.

Roadmap (2026-10-05, eleven slices; re-checked before each slice): 5 Journey / Meeting Progress; 6 Discipler Progression (ADR-012); 7 Curriculum / Lesson Content (ADR-010); 8 Workbook / Guide (ADR-013, reserved); 9 Monitoring / Follow-ups (ADR-014: consecutive recorded absences only); 10 Announcements; 11 Reporting / Oversight. D Group gatherings and gathering attendance are removed from the MVP (ADR-014); there is no Gatherings / Attendance slice. Numbering is not fixed: if dependency analysis later shows a better order, the roadmap changes. Monitoring depends primarily on Slice 5 and may move ahead of Curriculum if ministry priorities justify it. UI refinement happens inside each slice; there is no separate redesign slice.

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
