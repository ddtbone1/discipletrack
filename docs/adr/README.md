# DiscipleTrack Architecture Decision Records

Architecture Decision Records (ADRs) document important technical decisions made for DiscipleTrack.

ADRs explain why a decision exists so future developers and AI coding agents can understand the architectural intent before modifying the system.

## Status

- Accepted — Current architectural decision
- Superseded — Replaced by another ADR
- Deprecated — No longer recommended

## ADR Index

| ADR | Decision | Status |
|---|---|---|
| ADR-001 | Flutter Mobile Client | Accepted |
| ADR-002 | Supabase Backend | Accepted |
| ADR-003 | PostgreSQL as Domain Source of Truth | Accepted |
| ADR-004 | RBAC and Row Level Security | Accepted |
| ADR-005 | Controlled Database Operations | Accepted |
| ADR-006 | Historical Record Strategy | Accepted |
| ADR-007 | Server-Side Monitoring | Superseded by ADR-009 |
| ADR-008 | Documentation Precedence and Schema Source of Truth | Accepted |
| ADR-009 | Discipleship Meeting Attendance and Role-Specific Monitoring | Accepted |

## Rule

When implementation requires changing an accepted architectural decision, do not silently violate the ADR.

Either:

1. Continue following the existing ADR, or
2. Create a new ADR explaining why the previous decision is being superseded.