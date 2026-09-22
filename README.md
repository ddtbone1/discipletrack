# DiscipleTrack

A mobile-first discipleship, attendance and member growth monitoring system for churches.

DiscipleTrack is not an attendance tracker. It exists to answer questions a spreadsheet cannot: who is progressing through discipleship, who is responsible for discipling whom, who is quietly becoming inactive, who is responsible for responding, and whether that care actually happened.

The system is designed so that a member cannot disengage without a named person noticing and being accountable for following up.

## Status

Pre-implementation. The repository currently contains the engineering specification and a default Flutter scaffold. Application code, database migrations, RLS policies and RPCs have not been written.

## Platform

- Flutter / Dart
- Android and iOS
- Supabase (Auth, PostgreSQL, Row Level Security, database functions)

The MVP targets one local church. A web administration portal is out of scope.

## Documentation

`/docs` is the source of truth for both human developers and AI coding agents. Read it before writing code.

| Document | Subject |
|---|---|
| [docs/MVP_SPEC.md](docs/MVP_SPEC.md) | Product scope, roles, workflows, acceptance scenario |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System architecture and engineering principles |
| [docs/BUSINESS_RULES.md](docs/BUSINESS_RULES.md) | Numbered domain rules the system must preserve |
| [docs/erd/discipletrack.dbml](docs/erd/discipletrack.dbml) | Normative database schema |
| [docs/database/DATABASE_CONSTRAINTS.md](docs/database/DATABASE_CONSTRAINTS.md) | Database invariants and how each is enforced |
| [docs/security/RBAC_RLS_MATRIX.md](docs/security/RBAC_RLS_MATRIX.md) | Authorization model and controlled operations |
| [docs/DATABASE_DESIGN.md](docs/DATABASE_DESIGN.md) | Design rationale (non-normative for schema) |
| [docs/UI_DESIGN_SYSTEM.md](docs/UI_DESIGN_SYSTEM.md) | Visual and interaction principles |
| [docs/adr/](docs/adr/) | Architecture Decision Records |

## Document authority

Authority is domain-specific. Each artifact governs its own subject and does not override another outside it. The full model is in [ADR-008](docs/adr/ADR-008-documentation-precedence.md).

The two rules that matter most:

- The DBML is authoritative for schema structure. A schema change described only in `DATABASE_DESIGN.md` has not happened.
- If two authoritative documents genuinely contradict each other, report it. Do not resolve it silently.

## Engineering principles

- PostgreSQL is the source of truth. Flutter is an untrusted client.
- Hiding a button is not authorization.
- Preserve history. End, resolve, cancel or void records rather than deleting them.
- Derive values such as attendance percentage and absence streaks rather than storing them.
- Introduce technology because it solves an identified requirement, not to appear sophisticated.

See [AGENTS.md](AGENTS.md) for working instructions.
