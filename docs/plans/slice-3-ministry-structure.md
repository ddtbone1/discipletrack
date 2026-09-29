> **Working plan, not an authoritative document.** Approved scope and decisions for the next vertical slice. Where it differs from the governing documents listed in AGENTS.md, those documents are amended as part of the slice (see decision 12 and implementation step 7). Do not start implementation without an explicit instruction.
# Vertical Slice 3 (trimmed): Ministry Structure

## Context

Every ACTIVE member is still unplaced. The future Discipleship Meeting + Progress slice needs three things that don't exist yet:
- a DISCIPLE row in a D Group;
- a DISCIPLER row in the same group;
- an active discipler assignment linking the two (DC §4, P1 to P3).

This slice delivers exactly that, and only that:
- groups with a Leader;
- confirmed placement by invitation;
- pairing;
- removal;
- role-scoped views.

It was trimmed on 2026-09-24 to keep the MVP lean. The deferred items are listed in section H.

Verified baseline:
- HEAD is `3f3ba76`; the tree is clean and synced.
- Migrations 001 to 005 are applied and unchanged.
- The D Group tables exist from Migration 001, but nothing is enforced on them yet: no policies, RPCs or triggers, and the default grants are still wide open.
- `tool/run_on_emulator.ps1` has an uncommitted fix: the `-gpu host` flag is removed and the login hint is updated. It will be committed with this slice.

---

## 0. Fixes from manual testing (do these first)

### 0.1 Re-registering an existing email (bug, security)

**Observed (2026-09-24).**
- `ddotbone1@gmail.com` was registered on Sep 23 but never verified.
- Signing up with it again sent a fresh code for the *same* account, and the flow continued to verification and the church join. No duplicate row was created.

**Verified by test.**
- Re-registering an **unverified** email keeps the **first** password and name. The new password is silently ignored.
- Result: the real owner's password doesn't work, and if a stranger pre-registered the address they would know the password of the account the owner then verifies.
- A **verified** email is already refused by Supabase with `user_already_exists`.

**Required behaviour (user).** Sign-up must stop on the page with "An account with this email already exists", whether or not the existing account was verified.

**Fix:**
- **Detection, in `lib/features/auth/data/auth_repository.dart`, `signUp`:**
  - When the response has no session, compare the two server timestamps on the returned user, `created_at` and `confirmation_sent_at`.
  - A brand-new account has them milliseconds apart. An older, unverified account has `created_at` well before the fresh `confirmation_sent_at`.
  - If the gap is more than about 10 seconds, return `SignUpAlreadyRegistered`.
  - Both timestamps come from the server, so the client clock doesn't matter.
  - The existing `user_already_exists` / `email_exists` mapping stays.
- **Sign-up page, `lib/features/auth/presentation/sign_up_page.dart`:**
  - On `SignUpAlreadyRegistered`, stay on the page. Do not set `pendingVerificationProvider` and do not navigate to verification.
  - Show "An account with this email already exists. Sign in instead." next to a Sign in link.
  - The existing notice path is reused; only its wording and the unverified case change.
- **The genuine owner still gets through.** Signing in with the original password already returns `email_not_confirmed` and routes to the verify page, so an abandoned registration can still be completed.
- **Tests:**
  - **Unit:** the timestamp detection, both new and existing cases.
  - **Widget:** sign-up stays on the page with the message and does not navigate.
  - **Integration** (`email_verification_test.dart`): re-registering an unverified email is reported as already registered, and the original password still signs in to reach verification.

**Known limits (documented, not fixed here):**
- Supabase still emails a code on the repeat attempt. It can't be suppressed client-side, and it's harmless because the page says the email is taken.
- If a stranger pre-registered someone's address with their own password, the owner needs a **password reset** to recover the account. There is no reset flow yet; it's a small follow-up item for a later slice.

### 0.2 Brief "cannot find" message after login and after joining a church (pending reproduction)

A message flashes for about 0.5 s after signing in and after joining a church. The user could not read it and will capture it next time.

Candidates:
- "We couldn't find a church with that code" (Join church);
- "We could not find your profile" (Profile / Edit profile);
- the router's generic "Page Not Found" screen.

**No change until it is reproduced.** Then add a widget or router test that fails before the fix.

---

## A. Decisions (user, 2026-09-24)

1. **Approval is membership-only.** Approving a registration chooses no group and no role.
2. **The Coordinator creates each group with its Leader**, as a direct appointment. The Leader can be replaced but never left empty. A replaced Leader becomes unplaced, unless they are also a Discipler in that group.
3. **Joining a group needs the member's acceptance.**
   - The Leader (for their own group) or the Coordinator (for any group) invites an **unplaced** ACTIVE member as Disciple or Discipler.
   - The member accepts or declines once.
   - A member can hold only one pending invitation at a time.
   - A decline is shown to the inviter, who may re-invite.
   - An invitation expires after 14 days.
   - The inviter or the Coordinator may withdraw a pending invitation.
   - The Coordinator sees every invitation, but a Leader's invitations are not held for approval.
4. **Pairing is direct.** The Leader or Coordinator pairs, re-pairs or unpairs a Disciple with a Discipler. There is no limit on how many Disciples one Discipler has.
5. **Removal is direct.** The Leader or Coordinator removes a Discipler or Disciple, who becomes unplaced. Removing a Discipler unpairs their Disciples.
6. **Disciplers cannot invite or pair.** Members cannot request to join or leave a group themselves.
7. **Responsibility combinations:**
   - all of a person's active responsibilities are in one group;
   - LEADER + DISCIPLER in the same group is allowed, and a Leader may add themselves as Discipler directly;
   - DISCIPLE excludes both LEADER and DISCIPLER;
   - the Coordinator may hold a group role like anyone else.
8. **Visibility:**
   - Discipler and Disciple see their group mates **by name**;
   - phone numbers are visible only for a person's own Leader and own Discipler;
   - Admin-only users see no D Group data.
9. **Eligibility** is the inviter's choice for now.
10. **Group names** are unique per church, ignoring case.
11. **Church role management is deferred.** The bootstrap account is already Admin + Coordinator.
12. **Lighter documentation rule** (applies from this slice on):
    - **Every slice updates:**
      - the **DBML** when structure changes;
      - the **RBAC matrix** when authorization changes;
      - **DC** only for new invariants.
    - **BR, MVP and UI documents** are reconciled in batches at milestones, not every slice.
    - **No ADR** unless an architectural decision changes.
13. **Testing cadence:**
    - web is the daily loop;
    - a short Android smoke test at slice boundaries, preferably on a USB phone;
    - no emulator steps in this slice's verification.

**Timeline from registration to role:**
1. Register and verify email.
2. Enter the church code (status: Pending).
3. Approval, after which the person is a Member with no group.
4. Either:
   - the Coordinator appoints them Leader of a new group; or
   - they are invited as Disciple or Discipler, accept, and are placed.
5. A Disciple is paired with a Discipler.

## B. Roles in this slice

| Action | Coordinator | Leader (own group) | Discipler | Disciple | Invitee |
|---|---|---|---|---|---|
| Create group with Leader, replace Leader | Yes | No | No | No | No |
| Invite unplaced member (Disciple/Discipler), withdraw | Yes | Yes | No | No | No |
| Accept / decline | | | | | Own only |
| Add self as Discipler | if Leader of that group | Yes | | | |
| Pair / re-pair / unpair | Yes | Yes | No | No | No |
| Remove Discipler or Disciple | Yes | Yes | No | No | No |
| View group | Church-wide | Full detail | Roster by name + own Disciples | Roster by name + own Leader/Discipler | Invitation summary only |

- Every capability requires the caller's own membership to be ACTIVE (RBAC §1a).
- Responsibilities live only in `d_group_memberships`.
- `ministry_role_transitions` is not written; it is reserved for promotion later.

## C. Database: one new migration

**File:** `supabase/migrations/20260927000001_ministry_structure.sql`. It is edited locally with `db reset` until the slice is committed.

**Grants.**
- Revoke everything from `anon` on:
  - `d_groups`
  - `d_group_memberships`
  - `discipler_assignments`
  - `ministry_role_transitions`
  - `audit_events`
  - `d_group_invitations`
- Revoke INSERT, UPDATE, DELETE and TRUNCATE from `authenticated` on the same tables, plus `church_role_assignments`.
- Only SELECT under RLS remains.

**New table `d_group_invitations`** (added to the DBML first):

| Column | Notes |
|---|---|
| `id` | |
| `d_group_id` | |
| `church_membership_id` | the invitee |
| `responsibility` | CHECK in DISCIPLER, DISCIPLE |
| `status` | new enum `d_group_invitation_status`: PENDING, ACCEPTED, DECLINED, WITHDRAWN, EXPIRED |
| `invited_by` | |
| `created_at` | |
| `expires_at` | `created_at` + 14 days |
| `responded_at` | |
| `resulting_d_group_membership_id` | set when accepted |

Constraints on the table:
- partial unique `(church_membership_id) WHERE status = 'PENDING'`;
- state CHECKs.

Expiry is lazy, with no scheduler:
- An overdue PENDING invitation is treated as expired.
- It is marked EXPIRED by any operation that touches it.

**Constraints on existing tables.**
- `d_groups`:
  - CHECK that the name is not blank;
  - partial unique `(church_id, lower(trim(name))) WHERE status <> 'ARCHIVED'`.
- `d_group_memberships`: partial unique `(church_membership_id, d_group_id, responsibility) WHERE ended_at IS NULL`.
- `discipler_assignments`: CHECK that the two membership ids differ.

**Integrity triggers.** Defence in depth; they apply to every writer.
- `d_group_memberships`:
  - same church as the group;
  - no overlapping periods;
  - DISCIPLE/DISCIPLER exclusion;
  - the combination rules in decision 7.
- `discipler_assignments`:
  - the discipler side is a DISCIPLER row;
  - the disciple side is a DISCIPLE row;
  - both are in the same group as the assignment.
- `d_group_invitations`: same church as the invitee.

**Helpers.** Schema `private`, SECURITY DEFINER, STABLE, `search_path ''`.
- `is_church_coordinator(church_id)`
- `leads_d_group(group)`
- `can_manage_d_group_members(group)`: Coordinator or that group's Leader
- `is_unplaced(membership)`
- `has_active_responsibility_in(group)`
- `is_assigned_discipler_of(membership)`
- `is_my_leader_or_discipler(membership)`

**RPCs.** Schema `public`, SECURITY DEFINER, `search_path ''`. Each one:
- revokes EXECUTE from PUBLIC and anon;
- checks authority first;
- requires ACTIVE target memberships;
- locks rows before changing them;
- uses `now()` timestamps;
- writes one audit event.

| Operation | Who | Behaviour | Audit |
|---|---|---|---|
| `create_d_group(name, description, leader_membership)` | Coordinator | Creates the group and its LEADER row. The Leader must be unplaced. | `D_GROUP_CREATED` |
| `assign_d_group_leader(group, membership)` | Coordinator | Replaces the Leader in one transaction. | `D_GROUP_LEADER_ASSIGNED` |
| `invite_to_d_group(group, membership, responsibility)` | Coordinator/Leader | PENDING invitation. The invitee must be unplaced with no pending invitation. | `D_GROUP_INVITATION_SENT` |
| `withdraw_d_group_invitation(invitation)` | Coordinator, or the inviter while Leader | PENDING → WITHDRAWN. | `D_GROUP_INVITATION_WITHDRAWN` |
| `respond_to_d_group_invitation(invitation, accept)` | Invitee | **Accept:** re-checks the invitee is unplaced, creates the D Group membership and sets it on the invitation. **Decline:** marks the invitation DECLINED. **Expired:** refused with PT409. | `D_GROUP_INVITATION_ACCEPTED` / `_DECLINED` |
| `add_self_as_discipler(group)` | Leader of that group | Creates a DISCIPLER row for the caller directly. | `D_GROUP_MEMBER_ADDED` |
| `end_d_group_membership(dgm)` | Coordinator/Leader | Ends a DISCIPLER or DISCIPLE row and its assignments on either side. LEADER rows are refused. | `D_GROUP_MEMBER_ENDED` |
| `set_discipler(disciple_dgm, discipler_dgm or null)` | Coordinator/Leader | One operation that pairs, re-pairs (ends the old assignment, creates the new one) or unpairs (null). This replaces the three documented names; RBAC §10 is updated accordingly. | `DISCIPLER_ASSIGNED` / `_REASSIGNED` / `_UNASSIGNED` |
| `list_placeable_members(group)` | Coordinator/Leader | Read-only: names, current group, role and pending flag, with no phone numbers. A Leader sees only unplaced members. | none |
| `get_my_pending_invitation()` | Invitee | Read-only: group, role, inviter and expiry. | none |
| `get_my_d_group_roster()` | Discipler/Disciple | Read-only: the group's names, plus phone numbers for the caller's own Leader and Discipler only. | none |

**RLS (read-only policies).**

| Table | Coordinator | Leader | Discipler | Disciple | Invitee |
|---|---|---|---|---|---|
| `d_groups` | church-wide | own group | own group | own group | none |
| `d_group_memberships` | church-wide incl. history | own group incl. history | own group's active rows | own rows + Leader row + own Discipler's row | none |
| `discipler_assignments` | church-wide | own group | own assignments | own active assignment | none |
| `d_group_invitations` | church-wide | own group's | none | none | own |
| `profiles` / `church_memberships` | (existing policy) | members of own group | assigned Disciples + own Leader | own Leader and Discipler | none |

**Monitoring hook.** Resolving the missed-meeting condition on unpair, re-pair and removal is left to the meeting slice. Each affected RPC carries a comment marking where that step goes.

## D. Flutter

**New `lib/features/ministry/`:**
- **domain:**
  - `d_group.dart`
  - `d_group_member.dart`
  - `discipler_assignment.dart`
  - `d_group_invitation.dart` (expiry derived from `expires_at`)
  - `ministry_context.dart` (the caller's role, group, Leader, Discipler and pending invitation)
  - `member_option.dart`
- **data:** `ministry_repository.dart`: reads through embeds with FK hints, plus the RPCs.
- **application:**
  - `ministry_providers.dart`:
    - `myMinistryContextProvider`
    - `myPendingInvitationProvider`
    - `dGroupsProvider`
    - `dGroupDetailProvider(groupId)`
    - `placeableMembersProvider(groupId)`
  - `ministry_structure_controller.dart`: the in-flight pattern from `MembershipReviewController`, invalidating affected providers on success.
  - `invitation_response_controller.dart`
- **presentation:**
  - `d_groups_page.dart` (Coordinator list plus New group)
  - `d_group_form_page.dart` (name, description, Leader picker)
  - `d_group_detail_page.dart`, shared by Coordinator and Leader. Sections:
    - Leader, with Change Leader for the Coordinator only;
    - Disciplers with their Disciples, plus "Add myself as Discipler" for the Leader;
    - Disciples with their pairing state and actions;
    - Pending invitations, with Withdraw;
    - Invite member.
  - `member_picker_page.dart`
  - `invite_role_sheet.dart`
  - `pair_sheet.dart`
  - `my_group_page.dart`: the roster for Discipler and Disciple; a Discipler also sees an "Your Disciples" section
  - `invitation_card.dart`
- **Shared:** `lib/core/supabase/postgrest_failure.dart`, extracted from `MembershipRepository.codeOf`. `MembershipFailure`'s API is unchanged.

**Modified:**
- **`lib/app/router.dart` and `routes.dart`:**
  - routes `/groups`, `/groups/new`, `/groups/:groupId`, `/groups/:groupId/invite`, `/my-group`;
  - `redirectFor` matches `GoRouterState.fullPath` patterns;
  - the `active` allow set is extended.
- **`home_page.dart`:** entries instead of a dock:
  - **Coordinator:** D Groups row (group count, unplaced count).
  - **Leader:** My D Group row.
  - **Discipler / Disciple:** My Group card (Leader, Discipler, "Not paired yet").
  - **Invitee:** the invitation card with Accept / Decline.
  - **Unplaced member:** a "Not placed in a D Group yet" notice.
- **`app.dart`:** the resume hook also refreshes the invitation and ministry context.
- **Auth-link restyle:** a small `AppTextLink` in `lib/core/widgets/`, used on the sign-in, sign-up and verify-email screens for all text links.
- **`lib/previews/page_preview.dart`.**

## E. Seed

Five accounts, all ACTIVE, onboarding complete, password `dev-password-123`:
- `leader@discipletrack.local`
- `discipler@discipletrack.local`
- `disciple1@discipletrack.local`
- `disciple2@discipletrack.local`
- `member@discipletrack.local`

The structure is built through the real RPCs by impersonating each account with `request.jwt.claims`:
1. The Coordinator creates "Young Adults A" with the Leader.
2. The Leader invites the Discipler and both Disciples, and each accepts.
3. disciple1 is paired with the Discipler.
4. `member@` is left with a pending invitation, to test the accept flow manually.

The accounts are listed in `config/README.md`.

## F. Tests (focused)

**Integration.** `test_env.dart` gains helpers and FK-safe cleanup in this order:
1. assignments
2. invitations
3. D Group memberships
4. groups
5. audit rows
6. memberships
7. profiles

| File | Covers |
|---|---|
| `ministry_structure_test.dart` | create with Leader; Leader replacement keeps history; invitation lifecycle (accept, decline, re-invite, withdraw, one pending, expiry, placed-meanwhile refusal); pairing, re-pairing and unpairing; removal unpairs Disciples; audit rows written |
| `ministry_security_test.dart` | the negatives listed below |
| `ministry_integrity_test.dart` | service-role writes that break a trigger rule are rejected: two groups, DISCIPLE+DISCIPLER, cross-group pair, cross-church |

Negatives in `ministry_security_test.dart`:
- another church's Coordinator cannot see or act;
- a Leader cannot act on another group, invite an already-placed member, or perform Coordinator-only actions;
- a Discipler cannot invite or pair, and cannot read an unrelated Disciple;
- a Disciple reads group mates by name only and cannot read their profile rows;
- an ordinary member and an Admin-only user are refused every operation;
- anon is denied;
- direct client writes are refused;
- a caller whose own membership is INACTIVE has no authority;
- an invitation cannot be answered by anyone other than the invitee.

**Unit tests:**
- `redirectFor` patterns;
- invitation expiry derivation;
- domain `fromMap`;
- picker eligibility reasons.

**Widget tests:**
- group detail as Coordinator versus Leader, checking which actions show;
- invitation card accept and decline;
- picker;
- My Group for Discipler and Disciple;
- Home entries per role;
- `AppTextLink` on the auth screens.

## G. Implementation order

Each step lands its migration, Flutter and tests together.

1. Groundwork:
   - fix 0.1 (existing-email registration), with its tests, committed on its own before the slice work;
   - test cleanup helpers;
   - `postgrest_failure.dart` extraction;
   - pattern-based `redirectFor`;
   - `AppTextLink` auth restyle.

   Existing tests must stay green.
2. Migration: grants, invitations table, constraints, triggers and helpers, with the integrity tests.
3. Create a group with its Leader and replace a Leader: D Groups list, form and detail page.
4. Invitations: invite, withdraw, respond and expiry; picker, invite sheet, invitation card and pending section.
5. Pairing and removal: `set_discipler`, `end_d_group_membership` and `add_self_as_discipler`; detail actions and the pair sheet.
6. Role views: read policies, the roster RPC, My Group and Home entries; the security tests.
7. Seed, the DBML/RBAC/DC updates, full test suites, format and analyze, then a manual web walkthrough (section I).

## H. Deferred (explicitly out of this slice)

| Deferred item | Stopgap until then |
|---|---|
| Group edit and status (inactive, archive) | Groups stay ACTIVE; a name typo is fixed later |
| Transfer between groups | Remove the member, then invite them from the new group; history is preserved |
| Dock navigation | Home entries; the dock comes with the meeting slice, when Progress becomes a destination |
| Profile Responsibility / D Group rows | The Home card carries the same facts |
| ADR-010 | Covered by the lighter documentation rule |
| Church role management | Bootstrap already provides the first Coordinator |
| Promotion | Needs lesson completion, which comes later |
| Membership deactivation effects | A departing Leader will need a replacement first when that slice is built |
| Android emulator verification | Smoke test on a USB phone at the slice boundary |

## I. Verification

1. **Automated:** `flutter analyze`, `dart format --output=none --set-exit-if-changed .`, `flutter test` and the integration suite (`--dart-define-from-file=config/test.json test/integration`, with the service key set) all pass.
2. **Migrations:** 001 to 005 are byte-identical to HEAD.
3. **Manual on web:**
   - Run `npx supabase db reset`.
   - Run `flutter run -d chrome --web-port 8080 --dart-define-from-file=config/local.json`.
   - Walk through, each role in a separate browser profile:
     - **Coordinator:** create a group with a Leader, invite, change the Leader.
     - **Leader:** invite, pair, re-pair, remove; confirm there are no Coordinator actions.
     - **`member@`:** accept the pending invitation; Home changes accordingly.
     - **Discipler and disciple1:** My Group shows the right people and phone numbers.
     - **Deep link:** open `/groups` as the Leader; the page is refused or empty.

## K. Next slice after this one: Offline read-only access (planned, not part of Slice 3)

**Slice order:** Slice 3 (Ministry Structure), then **Slice 4 (Offline read-only)**, then Discipleship Meeting + Progress.

**Decisions (user, 2026-09-24):**
- **Platforms.** DiscipleTrack is a **mobile app** for Android and iOS. Web is a development and testing tool only and needs no offline support.
  - iOS builds and tests need a Mac (Xcode) or a cloud build service; this is not possible from the current Windows machine. How iOS gets built must be decided before release.
- **Offline is view-only.** The app opens and shows the last saved information. Every action that changes data is disabled with "You're offline".
  - Nothing is queued for later, which keeps this inside MVP scope (MVP §33 excludes offline synchronization).
  - Meetings can still be recorded later with their real date, once back online.
- **What is saved on the device:** the snapshot covers what the person is already allowed to see:
  - their own profile, membership and church name;
  - their roles;
  - their group, Leader, Discipler and group-mate names;
  - the phone numbers visible to them.
  It is cleared on sign-out.

**Approach (to be detailed when this slice is planned):**
- **Storage.** `shared_preferences` is already installed, because Supabase uses it for the session, so there is no new dependency. It holds one snapshot per signed-in user id.
  - The snapshot is written after each successful load of profile, membership, church, roles and ministry context.
- **Opening offline.**
  - When the restored session's live load fails with a network error and a snapshot exists, the session state resolves from the snapshot and the app shows an "offline" banner.
  - No snapshot (a first launch offline, or a new device): the splash shows "You're offline. Connect to sign in."
- **Detecting the connection.** Failed requests mark the app offline; there is no connectivity package. A periodic retry, app resume or Try again goes back online and refreshes the snapshot.
- **The database stays authoritative.** Snapshot data is for display only and never authorizes anything.
- **Tests:**
  - **Unit:** snapshot read and write, and resolving the session from the snapshot.
  - **Widget:** offline banner, disabled actions, and the no-snapshot message.
  - **Manual:** airplane mode on an Android phone.

## J. What this gives the Meeting + Progress slice

- **P1 and P2:** DISCIPLE rows in a specific group, created only through accepted invitations.
- **P3:** active assignments to DISCIPLER rows in the same group.
- **Lesson confirmation:** every group has an active Leader, which `confirm_lesson_completion()` needs.
- **Episode boundaries:** assignments end correctly on unpair, re-pair and removal, and each affected RPC marks the monitoring hook.
- **RLS scopes:** "own group", "assigned Disciples" and "own Discipler" exist as tested helpers.
- **Test data:** seeded accounts for every role.
