# ADR-008: Documentation Precedence and Schema Source of Truth

## Status

Accepted

## Context

DiscipleTrack's repository documentation is intended to be the source of truth for human developers and for AI coding agents.

That only works if the documents agree, and if a reader knows which document governs when they do not.

The problem was concrete rather than theoretical. `DATABASE_DESIGN.md` and `docs/erd/discipletrack.dbml` both specified fields for the same tables. The ERD was frozen after the design document and was never reconciled back into it, so the two disagreed on six points, including whether discipleship progress and meeting participation are keyed to church membership or to D Group membership.

Nothing in the repository stated which one an implementer should follow.

## Decision

Authority is **domain-specific**. Each artifact is authoritative within its own subject and does not override another artifact outside it.

| Subject | Authoritative artifact |
|---|---|
| Architectural decisions and rationale | `docs/adr/` |
| Database structure | `docs/erd/discipletrack.dbml` |
| Database invariants and enforcement | `docs/database/DATABASE_CONSTRAINTS.md` |
| Authorization | `docs/security/RBAC_RLS_MATRIX.md` |
| Domain behaviour | `docs/BUSINESS_RULES.md` |
| MVP scope and workflows | `docs/MVP_SPEC.md` |
| Database rationale and examples | `docs/DATABASE_DESIGN.md` |
| UI and presentation | `docs/UI_DESIGN_SYSTEM.md` |

This is not a ranked override chain. ADRs are listed first because they explain intent, not because they outrank the specialised artifacts. An ADR is not a substitute for the DBML, the constraints document or the RBAC matrix, and must not be read as silently amending them.

`DATABASE_DESIGN.md` is explicitly non-normative for concrete schema structure. It records why the model looks the way it does. It must not act as a second field-level schema specification.

## Escalation Rule

If two authoritative artifacts genuinely contradict each other, do not silently pick one using the table above.

Report the contradiction for resolution.

This applies to AI coding agents in particular. A contradiction is a signal that a decision was never actually made, and guessing converts a visible gap into an invisible one.

## Why

Two hand-maintained copies of the same specification drift the moment one is revised. Assigning each subject exactly one home removes the duplication that caused the drift, without discarding the reasoning that makes the design understandable.

A strict linear hierarchy was considered and rejected. It would have implied that a sentence in an ADR could override a deliberate authorization decision in the RBAC matrix, which is not how these documents are written or reviewed.

## Consequences

Changing the schema means changing the DBML. A change described only in `DATABASE_DESIGN.md` has not happened.

Changing an accepted architectural decision still follows the rule in `docs/adr/README.md`: continue following the ADR, or write a new ADR superseding it. Do not silently violate it.

Contradictions are surfaced rather than resolved by whoever notices them first.
