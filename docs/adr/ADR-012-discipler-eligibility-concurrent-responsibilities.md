# ADR-012: Discipler Eligibility After Lesson 5 and Concurrent Disciple and Discipler Responsibilities

## Status

Accepted (2026-10-05, user decisions 16 and 21). Accepted before the
Slice 5 work that depends on the progression model (decision N9).

Partially supersedes
[ADR-009](ADR-009-discipleship-meeting-attendance-monitoring.md) for one
statement (see "Superseded statements"). No ADR established the
DISCIPLE and DISCIPLER exclusion or eligibility after every lesson, so
the rest of what this ADR replaces is in non-ADR governing documents,
listed below.

The database still enforces the old exclusion. Migration 006's
`d_group_membership_disciple_conflict` refuses any overlap of DISCIPLE
with DISCIPLER. Governing documents state the intended invariant with
the note "enforced from Slice 6" until the Slice 6 forward migration
lands.

## Context

The specification made DISCIPLE and DISCIPLER mutually exclusive,
placed Discipler eligibility at completion of every lesson of the active
curriculum, and described promotion as ending the Disciple's
responsibility and assignment. The ministry practice is different: a
Disciple who has completed Lesson 5 may begin discipling others while
continuing their own lessons under their own Discipler.

Facts that shape the decision:

- `discipler_assignments` already allows one Discipler to have many
  Disciples (Migration 001 indexes only the Disciple side) and one
  active Discipler per Disciple (`discipler_assignments_active_disciple_uidx`).
- The only database rule that forbids the combination is the
  DISCIPLE-versus-LEADER-or-DISCIPLER branch of
  `private.check_d_group_membership_integrity()` (Migration 006).
- `discipler_assignments_distinct_sides_check` compares row ids only. Once
  one person may hold both a DISCIPLE row and a DISCIPLER row, it would
  not stop that person being paired with themselves.
- The self-credit rationale (BR-024; DATABASE_CONSTRAINTS.md section 4)
  relied on the exclusion.
- AGENTS.md forbids storing promotion eligibility as an independent
  source of truth.

## Decision

1. **Eligibility.** A Disciple becomes eligible to be appointed as a
   Discipler when Lesson 5 of the active curriculum reaches confirmed
   COMPLETED. IN_PROGRESS and READY_FOR_COMPLETION do not count.
   Eligibility is derived, never stored, and never changes anything by
   itself. Sequential eligibility (ADR-011 decision 8) means Lesson 5
   COMPLETED implies Lessons 1 to 4 COMPLETED. The eligibility
   lesson number is defined in one policy function,
   `private.discipler_eligibility_lesson()`, returning 5; it is ministry
   policy, not a church setting (D2, decided 2026-10-05).
2. **Eligibility is not appointment.** The Coordinator appoints an
   eligible Disciple directly. There is no acceptance workflow.
   Appointment is attributed and audited and is preserved as history
   (ADR-006).
3. **Same D Group.** Appointment creates the DISCIPLER responsibility in
   the same D Group as the person's DISCIPLE responsibility. The rule
   that all of a person's responsibilities are in one D Group at a time
   is kept.
4. **The own journey continues.** Appointment does not end the person's
   DISCIPLE responsibility, their own discipler assignment or their
   lesson progress. They continue through Lesson 12 under their own
   Discipler.
5. **Concurrent responsibilities.** DISCIPLE and DISCIPLER may be held
   at the same time. DISCIPLE still excludes LEADER.
6. **No self-pairing.** The two sides of a discipler assignment must
   belong to different church memberships.
7. **Assignment cardinality is unchanged.** One Discipler may have
   several Disciples. A Disciple has at most one active Discipler unless
   that rule is separately changed.
8. **Authority follows the relationship.** Capabilities are decided for
   the pair (caller, person viewed), never from holding a responsibility
   in general. A person sees and acts on their own journey as a
   Disciple, and on their assigned Disciples' journeys as their
   Discipler (decision N7 applies this to progress reads).
9. **Reopen protection, narrowed (N9).** The documented precondition
   "refused when the person has already been promoted to DISCIPLER"
   would forbid correcting any of Lessons 6 to 12 for an appointed
   person who is still a Disciple. It is narrowed to: for an appointed
   person, the eligibility lesson and earlier lessons cannot be
   reopened; later lessons can, subject to the other preconditions.
10. **Slice ownership.** Slice 6 (Discipler Progression) owns the
    forward migration. It relaxes only the DISCIPLE-versus-DISCIPLER
    part of the exclusion, keeps DISCIPLE-versus-LEADER, adds the
    self-pairing prohibition to the assignment integrity check and to
    `set_discipler()`, keeps one active Discipler per Disciple, and adds
    the eligibility derivation and the appointment operation. Migration
    006 is not edited. Slice 5 adds no new reliance on the exclusion
    (Slice 5 plan section P).

## Open questions

Not decided by this ADR. Each is recorded with its proposed default in
the Slice 5 plan (sections M and Q).

- **D2 (decided 2026-10-05).** One policy function,
  `private.discipler_eligibility_lesson()`, not configurable; built in the
  Slice 5 migration and reused by Slice 6.
- **D7, reciprocal pairing.** May A disciple B while B disciples A?
  Proposed default: refuse. Open; if refused, Slice 6 adds the check.
- D5 (appointment before eligibility as an exception), D6 (Leader
  pairing authority for appointed Disciplers), D8 (appointment after the
  DISCIPLE responsibility ended), D9 (Coordinator self-appointment), D14
  (a Disciple-Discipler conducting a lesson they have not completed):
  owned by Slice 6.

## Superseded statements

### ADR-009

| Section | Statement | Replaced by |
|---|---|---|
| Consequences, meeting-based monitoring rule 5 | "and promotion" in "Recalculate after meeting recording, meeting or participant void, Discipler reassignment, D Group transfer and promotion." | Decision 4: appointment does not end the Disciple's assignment, so it is not an episode boundary |

### Non-ADR governing statements

Updated in the same documentation pass (2026-10-05):

| Document | Statement |
|---|---|
| BUSINESS_RULES.md | BR-015 (DISCIPLE and DISCIPLER mutually exclusive; "Promotion changes the person's active ministry responsibility"); BR-024 self-credit rationale resting on the exclusion; BR-036 (eligibility at every lesson); BR-037 (promotion) |
| MVP_SPEC.md | Section 7 "review members eligible for Discipler promotion"; section 9 exclusion; section 22 promotion pathway; section 34 steps on promotion |
| ARCHITECTURE.md | Section 6 core constraint "Disciple and Discipler responsibilities are not simultaneously active for the same person"; section 9 promotion model |
| DATABASE_CONSTRAINTS.md | Section 2 Rules and Responsibility Combinations ("DISCIPLE excludes both LEADER and DISCIPLER"); section 4 eligibility rule, self-credit rationale, COMPLETED protection rationale, reopen precondition 4 and its explanation; section 5 Promotion; section 6 promotion as a recalculation trigger and episode end; section 11 Active Discipleships "awaits promotion review"; section 12 function and derived lists |
| RBAC_RLS_MATRIX.md | Section 2 row "Promote Disciple"; section 5 `ministry_role_transitions`; section 10 `promote_disciple_to_discipler()` and the reopen refusal wording |
| discipletrack.dbml | `d_group_memberships` note (exclusion); `ministry_role_transitions` note (replacement on promotion); `disciple_lesson_progress` note (reopen) |
| UI_DESIGN_SYSTEM.md | Section 27 and section 64 eligibility rows |
| DATABASE_DESIGN.md (non-normative) | Mutual exclusion and promotion sections, marked historical |
| Slice 3 plan (working plan) | Decision 7, DISCIPLE / DISCIPLER part. Historical; not edited |

ADR-005's "Disciple promotion" as an example of a controlled operation
remains valid in principle; the operation is now Discipler appointment.
ADR-006's history question "When did they become a Discipler?" is
answered by the appointment record.

## Alternatives Considered

**Store eligibility** (a flag or an `eligible_at` column). Rejected.
AGENTS.md forbids storing promotion eligibility; it could drift after a
reopen. The "eligible since" date is the Lesson 5 `completed_at`.

**Promotion that ends the DISCIPLE responsibility.** Rejected by the
ministry: the person continues their own lessons.

**Appointment by invitation, with acceptance.** Rejected (decision 16:
no acceptance workflow). Invitation remains placement of an unplaced
member.

**Discipler responsibility in a different D Group from the person's
DISCIPLE responsibility.** Not adopted. It would need the one-group rule
relaxed and the roster, MinistryContext, D Group destination and Leader
scope reworked. It would need its own ADR.

**Keep the exclusion and eligibility after every lesson.** Rejected; it
does not match ministry practice.

## Why

Eligibility, appointment and assignment are three different facts, owned
by three different sources: a derived predicate, an attributed
appointment record with its responsibility row, and an assignment row.
Keeping them separate lets each be corrected and audited on its own.
Relaxing only the DISCIPLE-versus-DISCIPLER branch is the smallest change
that matches the ministry, and the explicit self-pairing rule replaces
the protection the exclusion used to give.

## Consequences

- Slice 6 migration (no SQL here): replace the membership integrity
  function (DISCIPLE conflicts with LEADER only); replace the assignment
  integrity function and `set_discipler()` (different church memberships
  on the two sides; reciprocal check only if D7 refuses it); add the
  eligibility derivation and the appointment operation; add read
  policies for appointment history; replace `reopen_lesson_completion()`
  if Slice 5 did not build the narrowed form.
- Tests: `ministry_integrity_test.dart` "DISCIPLE cannot coexist with
  DISCIPLER or LEADER" stays green until Slice 6, then is split
  (DISCIPLER half inverted, LEADER half kept). Self-pairing,
  multiple-Disciple and independent-progress cases are added in Slice 6.
- Slice 5 is forward compatible: explicit "a recorder is never a
  participant" check, relationship-scoped helpers, a relationship-aware
  Journey whose two-tab state is reachable from Slice 6.
- Monitoring: a person who is both a Disciple and a Discipler is
  monitored as a Disciple only (ADR-014).
