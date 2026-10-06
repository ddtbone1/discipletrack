> **Working plan, not an authoritative document.** Scope and decisions for Vertical Slice 6. Where it differs from the governing documents listed in AGENTS.md, those documents are amended in phase 6.4, and ADR-018 records the architectural change. Approved for implementation 2026-10-06.

# Vertical Slice 6: D Group Assignment and Discipler Progression

## Context

Slice 3 built D Groups with a Leader, placement by invitation (the member accepts), pairing, removal and role-scoped reads. Slice 5 built the journey, lesson completion and `private.discipler_eligibility_lesson()`. ADR-012 assigned the Discipler appointment and the relaxation of the DISCIPLE / DISCIPLER exclusion to this slice.

Slice 6 delivers the operational workflow:

approved member → Leader adds them to the D Group → Needs setup → Leader sets up their responsibility → paired → journey → Lesson 5 completed → eligible → Coordinator appoints → Disciple and Discipler at once.

Two ways to hold DISCIPLER stay separate and auditable:

- **Initial rollout:** someone who already disciples in the church is recognized as an Existing Discipler during setup. They don't have to replay Lessons 1 to 5.
- **Future progression:** a Disciple who completed Lesson 5 is eligible, and only the Coordinator appoints them.

## Decisions (user, 2026-10-06)

1. **Direct placement replaces invitations.** The Coordinator (any group) or the group's Leader adds approved, ACTIVE, ungrouped members directly. Invitation and acceptance are retired: the migration withdraws pending invitations, the table is kept as history, and the invitation operations are dropped. This supersedes the Slice 3 decision 3 rule as carried by RBAC section 2 ("Nobody is placed without their own acceptance") and DC "Placement by Invitation".
2. **Rollout window.** Each church has an initial setup window, recorded in `church_settings`, which the Coordinator closes and may reopen. Both actions are audited. While it is open, the Leader (or the Coordinator) may set a member up as an Existing Discipler. Once it is closed, the database refuses that, and the only path to DISCIPLER is Lesson 5 followed by Coordinator appointment. A Leader adding themselves as Discipler is not bounded by the window: a Leader can never be a Disciple (BR-015), so the Lesson 5 path doesn't exist for them, and the Coordinator already chose them.
3. **ADR-012 open items (proposed defaults accepted):**
   - D5: no appointment before eligibility.
   - D6: the Leader keeps pairing authority for appointed Disciplers.
   - D7: reciprocal pairing is refused (A disciples B while B disciples A).
   - D8: no appointment after the DISCIPLE row has ended. The person is re-added and set up as a Disciple; their progress survives because it is keyed to `church_memberships.id`.
   - D9: a Coordinator cannot appoint themselves.
   - D14: a Disciple-Discipler may record lessons they haven't completed. This is not enforced.

### Defaults stated, not asked

- A replaced Leader with no other responsibility leaves the group, as today.
- A Needs-setup person sees their group's name and their Leader's name only. They don't see the roster, and their Leader's phone number is not shown.
- Removal takes a person out of the group: it ends their placement, every responsibility and every assignment on either side. The LEADER is refused and is changed by replacement instead.
- Add Members is all or nothing. If one selected person was placed elsewhere meanwhile, nobody is added, the list refreshes and the screen says so.

## Model

- **New table `d_group_placements`:** a person is in a group from `started_at` to `ended_at`. A partial unique index on `church_membership_id WHERE ended_at IS NULL` enforces one active group per person as a declarative constraint, so concurrent adds by two Leaders cannot both succeed.
- **Responsibility rows** (`d_group_memberships`) require an active placement of the same person in the same group. An active placement cannot end while responsibilities remain.
- **"Needs setup"** means an active placement with no active responsibility. It is derived and never stored. "Unplaced" now means no active placement.
- **Provenance of DISCIPLER:** every DISCIPLER row carries `d_group_memberships.discipler_basis`, which is one of `INITIAL_ROLLOUT`, `LEADER_SELF` or `APPOINTMENT`. A CHECK makes it required on DISCIPLER rows and absent on all others.
  - `ministry_role_transitions` stays the appointment record only, exactly as the DBML documents it.
  - This was changed during 6.2 from the first draft, which put a `source` column on `ministry_role_transitions`. Slice 5's `reopen_lesson_completion()` treats any transition row to DISCIPLER as an appointment (ADR-012 decision 9). A rollout recognition row would therefore have quietly widened that protection, and Slice 5 is not to be edited.
  - Existing DISCIPLER rows were backfilled: `LEADER_SELF` where the holder led the group when the row started, `INITIAL_ROLLOUT` otherwise.
- **Eligibility** stays derived from the Lesson `private.discipler_eligibility_lesson()` progress being COMPLETED (BR-036). Nothing is stored.

## Phases

### 6.1 Group Membership and Leader Management

- **Database** (migration `20261006000005_d_group_placements.sql`):
  - the placements table, unique index, integrity triggers and backfill from active responsibility rows;
  - `is_unplaced` redefined on placements;
  - `create_d_group` and `assign_d_group_leader` write placements;
  - `list_addable_members(group)` and `add_members_to_d_group(group, ids[])`;
  - `remove_from_d_group(placement)`;
  - pending invitations withdrawn, and the invitation operations and `end_d_group_membership` dropped;
  - the Leader's read scope and the roster follow placements;
  - RLS on placements.
- **App:**
  - a pushed route `/groups/:groupId/add-members` with search, a lazy list, multi-select, a sticky add bar, and loading, empty, offline and refusal states;
  - the invitation screens, the Home invitation card and the invitations section are removed;
  - D Group detail lists Needs-setup members;
  - Home and My Group explain Needs setup to the member themselves.
- **Tests:**
  - concurrent adds from two Leaders: exactly one succeeds;
  - service-role duplicate placement is refused;
  - authority negatives: another group, Discipler, Disciple, member, Admin-only, other church, inactive caller;
  - unknown ids give the same refusal as no authority;
  - the list excludes placed people;
  - audit rows.

### 6.2 Responsibility Setup and Pairing

- **Database** (migration `20261006000006_responsibility_setup.sql`):
  - `church_settings.initial_setup_closed_at`, plus `set_initial_setup_open(church, open)` for the Coordinator;
  - `set_up_member(placement, responsibility)` taking DISCIPLE or DISCIPLER (Existing Discipler). Existing Discipler is refused when the window is closed and is recorded as `discipler_basis` INITIAL_ROLLOUT on the row; it writes no transition row;
  - the membership integrity function is replaced: DISCIPLE now conflicts with LEADER only (ADR-012 decision 5);
  - the assignment integrity function and `set_discipler()` are replaced: no self-pairing across church memberships, and no reciprocal pairing (D7).
- **App:**
  - D Group detail becomes one list with filter chips: All, Disciples, Disciplers, Needs setup;
  - compact rows with an outlined responsibility pill and the pairing;
  - a setup sheet and the existing pair sheet;
  - a Coordinator control for the rollout window on the D Groups page.
- **Tests:**
  - setup authority, and refusal of a duplicate setup;
  - Existing Discipler refused after the window closes;
  - self-pairing, reciprocal, cross-group and cross-church pairing;
  - pairing someone without the responsibility;
  - ended rows;
  - re-pairing;
  - Discipler visibility still limited to assigned Disciples;
  - the Slice 3 integrity test split (DISCIPLER half inverted, LEADER half kept).

### 6.3 Discipler Eligibility and Appointment

- **Database** (migration `20261006000007_discipler_appointment.sql`):
  - `private.is_discipler_eligible(membership)`;
  - `appoint_discipler(membership)`, implementing DC section 5 preconditions 1 to 5 plus D5, D8 and D9, with an `APPOINTMENT` transition and audit;
  - eligibility and appointment exposed in the group read for the Coordinator and the Leader.
- **App:**
  - an outlined "Eligible" pill, distinct from "Discipler";
  - a Coordinator-only "Appoint as Discipler" action with confirmation;
  - the Leader sees eligibility but gets no action.
- **Tests:**
  - refused below Lesson 5, allowed after;
  - eligibility doesn't appoint anyone by itself;
  - only the Coordinator can appoint, and not themselves;
  - the person's DISCIPLE row, assignment and progress are untouched;
  - an ended DISCIPLE row is refused;
  - rollout recognition and appointment stay distinguishable;
  - the narrowed reopen precondition now fires for an appointed person.

### 6.4 Integration, UX and Closure

- The seed covers every walkthrough state through real operations.
- ADR-018 is written, and the DBML, RBAC and DC are updated.
- The full regression suite runs.
- A role walkthrough on the emulator, with findings classified as BUG, UX, VISUAL or FUTURE SLICE.

## UX review (UI_DESIGN_SYSTEM section 69)

1. **Domain:** MVP placement and responsibility setup, and the Discipler pathway. The real event is the Leader gathering their group and the Coordinator recognizing a new Discipler. The app records these decisions; it doesn't schedule anything.
2. **Roles affected:**
   - Coordinator: oversight, appointment, the rollout window;
   - Leader: add, set up, pair, remove;
   - Discipler and Disciple: the roster gains nothing new;
   - Needs-setup member: a new state;
   - ungrouped member;
   - Pending and Admin-only users: no change.
3. **Information:**
   - Leader: own group's members, their responsibility, pairing and eligibility;
   - Coordinator: church-wide;
   - Discipler: assigned Disciples only, unchanged from N7.
4. **Actions:**

   | Action | Who | Frequency | Reversibility |
   |---|---|---|---|
   | Add members | Leader or Coordinator | Weekly at rollout, rare after | Remove |
   | Set up | Leader or Coordinator | Once per person | Remove and re-add |
   | Pair | Leader or Coordinator | Occasional | Re-pair |
   | Appoint | Coordinator | Rare | No undo in the MVP; it needs confirmation |
   | Close window | Coordinator | Once | Reopen, audited |

5. **Derived values:**
   - Needs setup, defined in DC section 11 (added);
   - eligibility, already defined in DC section 11.
6. **States:**
   - loading;
   - empty: "Everyone in the church is already in a D Group";
   - offline: view-only, actions explain themselves;
   - refused;
   - Needs setup: "Your Leader will set up your role".
7. **Patterns:**
   - a pushed full-screen multi-select for Add Members, because there are about 200 members;
   - sheets for setup and pairing;
   - a confirmation dialog for appointment and removal;
   - filter chips instead of tabs.
8. **Navigation:** no new dock destination. Everything is reached from D Group detail.
9. **Cross-role effects:**
   - an added member disappears from every other group's Add list;
   - an appointed person appears under Disciplers and keeps their Journey.

## Out of scope

Curriculum content, Workbook, monitoring and follow-ups, announcements, reporting, transfer between groups, revoking an appointment, a Leader Home members summary, and a general redesign.

## Delivery record

### 6.1 and 6.2 done (2026-10-06)

- **Migrations:** `20261006000005_d_group_placements.sql` and `20261006000006_responsibility_setup.sql` (later in the slice: 007 appointment, 008 undo lock, 009 member count). 6.1 and 6.2 reached their regression boundary together: once invitations were retired, the setup operation was the only way to create Disciples, and the seed and the Slice 5 fixtures depend on Disciples existing.
- **Tests:**
  - new: `responsibility_setup_test.dart`;
  - rewritten: `ministry_structure_test`, `ministry_security_test`, `ministry_integrity_test` and `ministry_repository_test`;
  - two Slice 5 tests moved from `end_d_group_membership` to `remove_from_d_group` with the same intent;
  - all unit, widget and integration suites pass, including the concurrent-add test.
- **App:**
  - Add Members route;
  - D Group workspace with filter chips;
  - setup sheet;
  - pair sheet limited to valid Disciplers;
  - setup-period card on D Groups;
  - Needs-setup notice on Home and My Group;
  - invitation screens removed.
- **Outside the slice, at the user's request (2026-10-06):**
  - Recent activity shows each event as its own thin, view-only card, tinted by attendance state, with the timeline rail outside the cards;
  - grey-tone `AppPill`s are no longer filled: an outline with ordinary text, and only the icon takes the colour.

### 6.3 and 6.4 done (2026-10-06)

- **6.3:**
  - Migration `20261006000007_discipler_appointment.sql`: eligibility derived from `private.discipler_eligibility_lesson()`, `appoint_discipler()`, `list_discipler_candidates()`, and read policies on `ministry_role_transitions`.
  - **User decision (2026-10-06): appointment locks undo.** Migration `20261006000008_appointment_locks_undo.sql` refuses undo of the eligibility lesson and earlier for an appointed person, and `get_disciple_journey` stops offering it. ADR-018 decision 9.
  - The app shows an Eligible pill and line on the D Group page, a Coordinator-only Appoint action in the row menu, and an Eligible to disciple review list on D Groups. The app copy never says "5"; it says "eligible since <date>".
- **6.4:**
  - Seed: Mara ungrouped, Nina in Needs setup, Paolo eligible, Rosa appointed (Disciple and Discipler), and Men of Faith with Ramon and Tomas. All built through the real operations.
  - Docs: ADR-018 written; DBML, RBAC, DC, ADR-012, BR, MVP, ARCHITECTURE, UI_DESIGN_SYSTEM and AGENTS.md reconciled.
- **Role walkthrough on the Android emulator:**
  - Leader: add, set up, pair with an appointed Discipler.
  - Coordinator: review eligibility, appoint, the setup period card.
  - Needs-setup member: Home notice.
  - Disciple and Discipler (Rosa): Home, both Journey tabs, Recent activity cards.
- **Findings:**
  - BUG, fixed: bottom sheets (setup, pair, and the Slice 5 journey-history and choose-Disciple sheets) opened under the floating dock. They now open on the root navigator.
  - UX, fixed: the eligibility line was truncated and is now shortened. After setup, the page switches to the filter where the person now appears instead of an empty Needs setup list.
  - VISUAL, fixed: the selected filter chip was hard to see (now an ink fill); the Set up and Pair actions had no visible fill (now light lime). Grey attendance-summary pills keep their meaning in a coloured icon (`AppPill.iconTone`).
  - UX, fixed at acceptance (user, 2026-10-06): the Leader Home and D Groups card member counts now include people who still need setup. Membership and responsibility are separate, so being added makes someone a member. Migration `20261006000009_group_member_count.sql` adds `d_group_member_count` to `get_my_d_group_roster()`, and the group cards count placements. Disciple and Discipler counts stay responsibility-specific.
  - FUTURE SLICE: none raised.
