# ADR-020: Every D Group Leader Holds the Discipler Role

## Status

Accepted (2026-10-06, user decision after the Slice 7 walkthrough: "Leaders are also Disciplers").

Amends [ADR-018](ADR-018-direct-placement-initial-rollout.md) and BR-013: a Leader no longer *may* add themselves as Discipler; every active Leader *holds* the DISCIPLER responsibility in their group. Does not change [ADR-012](ADR-012-discipler-eligibility-concurrent-responsibilities.md): DISCIPLE still excludes LEADER, and DISCIPLE and DISCIPLER may coexist.

## Context

A D Group Leader in this ministry also disciples people. Until now the schema treated that as optional: a Leader held LEADER only, and became a Discipler through `add_self_as_discipler()` (discipler_basis `LEADER_SELF`, ADR-018) or by Coordinator recognition during the initial setup window.

That made a Leader's experience differ from a Discipler's in ways the ministry did not intend:
- a Leader without the role had no Journey destination and no Disciples;
- the Leader's screen (group management) and the Discipler's screen (the roster) were separate;
- the seeded Leader could not be paired with anyone.

## Decision

1. **The role comes with the leadership.** `create_d_group()` and `assign_d_group_leader()` give the new Leader an active DISCIPLER row in the group (discipler_basis `LEADER_SELF`), unless they already hold one.
2. **Invariant.** While a person holds an active LEADER row in a group, they hold an active DISCIPLER row in the same group. A deferred constraint trigger checks this at commit. Removal refuses the Leader. Leaving the church and archiving the group end both rows together.
3. **A replaced Leader stays a Discipler.** As before, they keep the DISCIPLER row and so stay in the group. Their pairings are not ended by the replacement.
4. **Backfill.** Existing Leaders without the role were given it by Migration 018, audited as `D_GROUP_MEMBER_ADDED` with `with_leadership: true`.
5. **`add_self_as_discipler()` remains** for compatibility and now always answers `already_discipler` for an active Leader. No client calls it.
6. **One interface.** A Leader uses the Discipler's screens (My D Group roster, Journey, My Disciples). The Leader's management controls are added on top, not on a separate destination.
7. **No new basis value.** `LEADER_SELF` is redefined as "the Leader's own Discipler role", to avoid adding an enum value inside a migration transaction.

## Consequences

- Every Leader can be paired immediately and records meetings as the assigned Discipler for their own Disciples. For other Disciples in the group they still record on the Discipler's behalf.
- Leaders now count among a group's Disciplers in role counts and pairing choices.
- BR-004 is clarified: the Leader's Discipler role is part of an authorized assignment (the leadership), not a self-assignment.
- Documents reconciled: BUSINESS_RULES BR-004, BR-013 and BR-015; DATABASE_CONSTRAINTS section 2; RBAC_RLS_MATRIX sections 1 and 10; the DBML note on `discipler_basis`.
