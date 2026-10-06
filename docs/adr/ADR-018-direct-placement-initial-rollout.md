# ADR-018: Direct D Group Placement, Needs Setup, and Initial Rollout Recognition of Disciplers

## Status

Accepted (2026-10-06, user decisions for Slice 6).

Decides the Slice 6 questions ADR-012 left open (D5, D6, D7, D8, D9 and D14). Extends ADR-012 decision 9 from reopen to undo. Supersedes the Slice 3 rule "placement by confirmed invitation", which no ADR established; it was carried by RBAC_RLS_MATRIX.md section 2 ("Nobody is placed without their own acceptance") and DATABASE_CONSTRAINTS.md section 2 ("Placement by Invitation").

## Context

Slice 3 placed people in a D Group by invitation: a Leader or the Coordinator invited an unplaced member as Disciple or Discipler, and the member accepted. Membership of a group and responsibility within it were the same row (`d_group_memberships`). "Eligibility is the inviter's choice for now" (Slice 3 decision 9) let a Leader make anyone a Discipler, with no end date.

For the rollout, the ministry wants this order of work:
1. a Leader gathers approved members into their group directly;
2. the Leader decides each person's part;
3. people who already disciple others in the church are recognized as such;
4. later Disciplers come only from Lesson 5 and the Coordinator's appointment (ADR-012).

The unbounded invitation-as-Discipler path would let the rollout shortcut outlive the rollout.

The one-group-per-person rule was enforced by an integrity trigger and row locks. The ministry asked for a guarantee that holds even when two Leaders add the same person at the same moment.

## Decision

1. **Direct placement.** The Coordinator (any group in the church) or the group's Leader adds approved, ACTIVE members who are in no D Group. There is no acceptance step. Invitations are retired: pending ones are withdrawn, the table is kept as history, and the operations are removed.
2. **Placement is separate from responsibility.** `d_group_placements` records that a person is in a group. `d_group_memberships` keeps recording their responsibilities.
   - A partial unique index allows one active placement per person, so concurrent adds cannot both succeed.
   - An active responsibility requires an active placement in the same group.
3. **Needs setup.** A placement with no active responsibility is the derived state "Needs setup". It is never stored. The person sees their group's name and their Leader's name, nothing more.
4. **Setup.** The Coordinator or the group's Leader sets a placed member up as a Disciple, or as an Existing Discipler. A person may hold both (ADR-012 decision 5); DISCIPLE still excludes LEADER.
5. **Initial setup window.** Each church has an initial setup period (`church_settings.initial_setup_closed_at`, open while null). The Coordinator closes it and may reopen it, and both actions are audited.
   - While it is open, a member may be recognized as an Existing Discipler at setup.
   - Once it is closed, the database refuses that, and DISCIPLER comes only from appointment.
   - A Leader adding themselves as Discipler is not bounded by the window: a Leader can never be a Disciple, so the Lesson 5 path does not exist for them.
6. **DISCIPLER provenance.** Every DISCIPLER row records why it exists in `discipler_basis`: `INITIAL_ROLLOUT`, `LEADER_SELF` or `APPOINTMENT`.
   - `ministry_role_transitions` remains the appointment record only.
   - A rollout recognition therefore never counts as an appointment, in particular for the reopen and undo protections.
7. **Removal** takes a person out of the group: every assignment on either side ends, then every responsibility, then the placement. History is kept, and the Leader is changed only by replacement.
8. **Open ADR-012 items, decided:**
   - D5: no appointment before eligibility.
   - D6: the Leader keeps pairing authority for appointed Disciplers.
   - D7: reciprocal pairing is refused.
   - D8: no appointment once the DISCIPLE row has ended. The person is re-added and set up as a Disciple; their progress survives because it is keyed to `church_memberships.id`.
   - D9: a Coordinator cannot appoint themselves.
   - D14: a Disciple who is also a Discipler may record lessons they have not completed themselves. This is not enforced.
9. **Appointment locks undo.** Once a person is appointed, their eligibility lesson and earlier lessons can be neither undone nor reopened (`eligibility_lesson_protected`). This extends ADR-012 decision 9, which covered reopening only, so that "appointed" is always backed by a completed eligibility lesson.

## Alternatives Considered

**Keep invitation and acceptance.** Rejected by the ministry. Setup is the Leader's job, and an unanswered invitation leaves a person in limbo.

**A fourth responsibility value, such as `MEMBER`, instead of a placements table.** Rejected. It cannot enforce one active group per person with an index, because a person has several rows. It would also put a non-responsibility into the responsibility enum that every Slice 5 query reads.

**Record rollout recognition in `ministry_role_transitions` with a `source` column.** Rejected. Slice 5's reopen protection treats any transition row to DISCIPLER as an appointment, so recognition would have quietly widened that protection.

**Let the Leader recognize Existing Disciplers indefinitely, distinguished only in audit.** Rejected. It leaves the loophole open.

**Only the Coordinator recognizes Existing Disciplers.** Not chosen. During rollout the Leader knows their own group. The window bounds the Leader's recognition instead.

**Allow undo after appointment, and let the appointment stand.** Rejected. A Discipler could then hold an appointment whose eligibility lesson is no longer completed.

## Consequences

- **Migrations:**
  - 012: placements, direct placement and removal, invitations retired;
  - 013: setup, the window, the relaxed exclusion, no self-pairing or reciprocal pairing, `discipler_basis`;
  - 014: eligibility derivation, appointment, candidates;
  - 015: appointment locks undo, and the journey offers no Undo there.
  - 016: the roster carries the group's member count, which includes people who still need setup.
  - Migrations 001 to 011 are unchanged.
- **Unplaced** now means no active placement.
- **Roster reads:** the Leader's member scope covers everyone placed in their group, including people who still need setup. Disciplers and Disciples do not see people who still need setup on the roster.
- **Monitoring:** appointment is still not an episode boundary (ADR-012); removal ends assignments, as before.
