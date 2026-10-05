# DiscipleTrack Architecture Decision Records

Architecture Decision Records (ADRs) document important technical decisions made for DiscipleTrack.

ADRs explain why a decision exists so future developers and AI coding agents can understand the architectural intent before modifying the system.

## Status

- Accepted — Current architectural decision
- Superseded — Replaced by another ADR
- Partially superseded — Named statements replaced by a later ADR; the rest remains accepted. Both ADRs name the replaced statements.
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
| ADR-009 | Discipleship Meeting Attendance and Role-Specific Monitoring | Accepted; partially superseded by ADR-011 (lesson readiness), ADR-012 (promotion as a recalculation trigger) and ADR-014 (gatherings, gathering monitoring, the missed-meeting condition, two thresholds) |
| ADR-010 | Lesson Content Delivery and Offline-First Reading | Accepted |
| ADR-011 | Explicit Lesson Completion, Independent of a Fixed Meeting Count | Accepted; one numeric rule open (minimum meetings); partially superseded by ADR-014 (condition name, role-specific monitoring) and ADR-015 (Leader confirmation step, submission withdrawal, reopen result) |
| ADR-012 | Discipler Eligibility After Lesson 5 and Concurrent Disciple and Discipler Responsibilities | Accepted; D2 decided (policy function); the Slice 6 questions open; eligibility wording amended by ADR-015 |
| ADR-013 | Curriculum Workbook and Guide Modes | Reserved, not written (see Reserved numbers) |
| ADR-014 | Remove D Group Gathering Attendance from the MVP | Accepted |
| ADR-015 | The Discipler Marks a Lesson Completed, Without Leader Confirmation | Accepted |

ADR numbers are identifiers, not implementation order.

## Reserved numbers

A reserved number has no ADR file. It names a decision that is expected
but not yet made, so that nobody reads it as accepted. The status list
above has no "Proposed" status, so a reserved decision is recorded here
rather than as a file.

**ADR-013, Curriculum Workbook and Guide Modes** (reserved 2026-10-05,
user decision 17). To be written in or just before the Workbook / Guide
slice (Slice 8), after the real lesson material has been inspected. Not
part of Slice 5. Expected scope:

- one canonical lesson structure used by both modes
- Workbook Mode, for the person as a Disciple
- Guide Mode, for the person as the assigned Discipler
- Guide authorization scoped to the relationship with the Disciple, not to a responsibility in general
- Guide answers protected server-side
- the Disciple's personal responses stored separately from lesson content
- the assigned Discipler does not see private workbook responses by default
- the security implications of an offline curriculum copy

It is expected to partially supersede ADR-010 decision 12 (one read
scope for all lesson content) for the Guide tier. Open questions it
owns: D13 (exact Guide read scope) and D17 (offline workbook responses).

## Rule

When implementation requires changing an accepted architectural decision, do not silently violate the ADR.

Either:

1. Continue following the existing ADR, or
2. Create a new ADR explaining why the previous decision is being superseded.