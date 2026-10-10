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
| ADR-004 | RBAC and Row Level Security | Accepted; amended by ADR-022 (church ADMIN retired; the separation applies to the platform Super Admin) |
| ADR-005 | Controlled Database Operations | Accepted |
| ADR-006 | Historical Record Strategy | Accepted |
| ADR-007 | Server-Side Monitoring | Superseded by ADR-009 |
| ADR-008 | Documentation Precedence and Schema Source of Truth | Accepted |
| ADR-009 | Discipleship Meeting Attendance and Role-Specific Monitoring | Accepted; partially superseded by ADR-011 (lesson readiness), ADR-012 (promotion as a recalculation trigger) and ADR-014 (gatherings, gathering monitoring, the missed-meeting condition, two thresholds) |
| ADR-010 | Lesson Content Delivery and Offline-First Reading | Accepted; partially superseded by ADR-019 (publishing source, read scope; device copy amended); read scope further narrowed by ADR-023 |
| ADR-011 | Explicit Lesson Completion, Independent of a Fixed Meeting Count | Accepted; partially superseded by ADR-014 (condition name, role-specific monitoring), ADR-015 (Leader confirmation step, submission withdrawal, reopen result), ADR-016 (decision 14, "reopening must come first") and ADR-017 (the meeting policy and N1, closed: no minimum) |
| ADR-012 | Discipler Eligibility After Lesson 5 and Concurrent Disciple and Discipler Responsibilities | Accepted; D2 decided (policy function); eligibility wording amended by ADR-015; the Slice 6 questions decided and decision 9 extended to undo by ADR-018 |
| ADR-013 | Curriculum Workbook and Guide Modes | Reserved, not written (see Reserved numbers) |
| ADR-014 | Remove D Group Gathering Attendance from the MVP | Accepted |
| ADR-015 | The Discipler Marks a Lesson Completed, Without Leader Confirmation | Accepted; partially superseded by ADR-016 (reopen after the undo window) and ADR-017 (count precondition) |
| ADR-016 | A Completion Is Locked Once Later Progress Exists; Reopen Is Database-Only | Accepted |
| ADR-017 | No Minimum Meetings; Meeting Count Is Never a Progression Gate | Accepted (closes N1) |
| ADR-018 | Direct D Group Placement, Needs Setup, and Initial Rollout Recognition of Disciplers | Accepted (supersedes Slice 3 placement by invitation); Leader self-add replaced by ADR-020 |
| ADR-019 | Curriculum Licensing Posture, Tiered Content and Progression-Gated Access | Accepted; decision 16 (any Discipler reads every lesson) superseded by ADR-023 |
| ADR-020 | Every D Group Leader Holds the Discipler Role | Accepted; amends ADR-018 |
| ADR-021 | A Disciple's Lesson Answers Stay on Their Device (Before the Workbook) | Accepted; anticipates ADR-013 without writing it; amended 2026-10-07 (answer kinds, checking blanks; amends ADR-019 decision 6 for blanks); decision 8 (own-context "Show answers") superseded by ADR-023 |
| ADR-022 | Platform Super Admin, Separate from the Church Coordinator | Accepted; retires church ADMIN; amends ADR-004; amended 2026-10-08 after the Phase 1 review (Coordinator reads the join code, one church per person as an MVP limitation, invariant verified) |
| ADR-023 | Curriculum Access Follows the Relationship, Not the Discipler Role | Accepted; supersedes ADR-019 decision 16 and ADR-021 decision 8; amended 2026-10-08 after the Phase 1 review (Coordinator full access, My Journey distinct, access never affects progression); decisions 2 and 3 amended for the own context by ADR-024 |
| ADR-024 | A Discipler Reads the Whole Book in Their Own Context | Accepted; amends ADR-023 decisions 2 and 3 (own context only) |

ADR numbers are identifiers, not implementation order.

## Reserved numbers

A reserved number has no ADR file. It names a decision that is expected
but not yet made, so that nobody reads it as accepted. The status list
above has no "Proposed" status, so a reserved decision is recorded here
rather than as a file.

**ADR-013, Curriculum Workbook and Guide Modes** (reserved 2026-10-05,
user decision 17). To be written in or just before the Workbook / Guide
slice (Slice 9 since the 2026-10-08 renumbering; Slice 8 before it), after the real lesson material has been inspected. Not
part of Slice 5. Expected scope:

- one canonical lesson structure used by both modes
- Workbook Mode, for the person as a Disciple
- Guide Mode, for the person as the assigned Discipler
- Guide authorization scoped to the relationship with the Disciple, not to a responsibility in general
- Guide answers protected server-side
- the Disciple's personal responses stored separately from lesson content
- the assigned Discipler does not see private workbook responses by default
- the security implications of an offline curriculum copy

ADR-019 (2026-10-06) has already decided the tier boundary, that answers
are protected server-side, and the relationship-scoped Discipler read
scope (widened by ADR-019 decision 16, restored to the relationship by
ADR-023 on 2026-10-08); ADR-013 covers the workbook experience and personal responses only. The
open question it owns is D17 (offline workbook responses). D13 (exact Guide read scope) was
decided by ADR-019 decision 6.

## Rule

When implementation requires changing an accepted architectural decision, do not silently violate the ADR.

Either:

1. Continue following the existing ADR, or
2. Create a new ADR explaining why the previous decision is being superseded.