# ADR-022: Platform Super Admin, Separate from the Church Coordinator

## Status

Accepted (2026-10-08, user decisions for Slice 8, "Platform roles and church provisioning"). Amended the same day after the Phase 1 review: the Coordinator reads the join code (decision 10a), one church per person is recorded as an MVP limitation (decision 9), and the Coordinator invariant is verified against the order of writes (decision 11).

Amends [ADR-004](ADR-004-authorization-rls.md): the church-level ADMIN role is retired, and the separation of technical from ministry-care authority now applies to the platform Super Admin. Does not change [ADR-020](ADR-020-leader-holds-discipler.md) or any D Group responsibility.

## Context

Until now there was one church-scoped privileged role besides COORDINATOR: ADMIN, a row in `church_role_assignments` on a church membership. An audit of `main` at `73a66c9` found:
- ADMIN granted exactly three things, all through `private.is_church_admin_or_coordinator()` (Migration 005): approving and rejecting membership requests, reading the church's memberships, and reading those people's profiles. COORDINATOR already had all three.
- The ADMIN capabilities in RBAC section 2, "Manage church configuration" and "Manage church roles", were never built.
- Churches were created only by trusted tooling (`private.bootstrap_church()`, service role), which granted the founder both ADMIN and COORDINATOR.
- There was no join-code regeneration, no church status change, and no way to grant or replace a Coordinator.

The ministry needs a platform operator who creates churches and hands each one to its Coordinator, without that operator inheriting any ministry data. A church-scoped role cannot be that operator: it needs a membership in some church and ties platform authority to it.

## Decision

### Roles

1. **Three levels, kept separate.**

   | Level | Stored in | Roles |
   |---|---|---|
   | Platform | `platform_roles` | SUPER_ADMIN |
   | Church | `church_role_assignments`, on an ACTIVE membership | COORDINATOR |
   | D Group | `d_group_memberships` | LEADER, DISCIPLER, DISCIPLE |

   Each authority comes from its own row. Super Admin never implies Coordinator, and Coordinator never implies Super Admin.

2. **Church ADMIN is retired.** No operation grants it again, and the database refuses an active ADMIN row. Existing active rows are ended, never deleted, with one audit event each (`CHURCH_ROLE_ENDED`, reason `admin_retired`). The `ADMIN` enum value stays, because removing an enum value from an applied type is not worth the risk.

3. **Approval moves to the Coordinator alone.** Approving and rejecting memberships, and reading the church's memberships and their profiles, become COORDINATOR-only. Every person who held ADMIN in the seed also holds COORDINATOR, so no working capability is lost.

4. **Super Admin is platform-level.** It is a row in `platform_roles` keyed to `profiles.id`, independent of any church membership. It is never read from a JWT claim, a profile field, user metadata or an operation parameter. There is no client write path. The first Super Admin is granted only by service-role tooling (`tool/grant_super_admin.ps1`) and by the local seed. Revoking is the same tooling.

5. **No inherited ministry access.** A Super Admin sees, per church, only:
   - the church's name, status, join code and creation date;
   - aggregate counts (members by status, D Groups, Coordinators);
   - the full name and sign-in email of its active Coordinators.

   They see no other member identity and no ministry-private data: no memberships, profiles, D Groups, rosters, meetings, outcomes, journeys, progress, lesson content, answers, follow-ups or workbook data. These reads are SECURITY DEFINER operations that return only these fields; no table policy is broadened. The Coordinators' name and email are the one exception (user decision 2026-10-08): the Super Admin appointed those people and must tell them apart to replace one. Any future exception needs its own justified, audited operation.

6. **A Super Admin never assigns themselves.** Assigning oneself as Coordinator is refused (BR-003), because it would turn platform authority into ministry access without a second person. A Super Admin who needs to be a church's Coordinator is assigned by another Super Admin or by trusted tooling, and is then audited like anyone else.

### Provisioning

7. **A church is created with its Coordinator, atomically** (user decision 2026-10-08). `create_church(name, coordinator email)` does all of this in one transaction:
   - creates the church (ACTIVE), its settings and its curriculum rows;
   - generates its join code server-side;
   - creates the Coordinator's ACTIVE membership, with onboarding marked complete;
   - grants COORDINATOR.

   No church ever exists without a Coordinator. Lesson content for a new church is published separately by trusted tooling, under that church's own licence reference (ADR-019 decision 11).

8. **A Coordinator is assigned by the email of a registered account**, with an explicit confirmation step:
   - A preview returns the account's full name and whether it already belongs to this church. The Super Admin confirms the person by name before the change.
   - The account must exist and have a confirmed email.
   - The membership is created, or reactivated from any status, as ACTIVE with onboarding complete. It is provisioned, not approved, so `approved_by` stays null.
   - No invitation email is sent; that would be email automation, out of MVP scope.

9. **One church per person** (user decision 2026-10-08). An account holds membership rows in at most one church, enforced by the database. A join request from a person who belongs to another church is refused, and so is an assignment of them as Coordinator. Moving a person between churches is post-MVP.

   This is an **intentional MVP limitation**, not a domain rule (Phase 1 review, 2026-10-08). Supporting people in more than one church later needs:
   - a forward migration that drops the unique key on `church_memberships(user_id)`;
   - a rule for which church a session acts in, and a way to switch;
   - session state per church in the app, which today loads exactly one membership.

   No other table assumes one church per person. Every domain record already keys to `church_memberships.id`, which stays church-scoped.

10. **Join code regeneration** replaces the code with a new one from `private.generate_join_code()`. The unique constraint holds, and a collision is retried. The old code stops matching at once. Requests made with the old code stay PENDING. Audited as `JOIN_CODE_REGENERATED`, with no code value in the metadata. Only the Super Admin generates or regenerates a code.

10a. **The Coordinator reads their church's join code** (Phase 1 review, 2026-10-08). The church's active Coordinator may view and copy their own church's current code, read-only, through `get_church_join_code()`, so they can share it with the church. The rules:
   - only while the church is ACTIVE;
   - nobody else in the church can read it;
   - no column grant on `churches.join_code` is opened;
   - no Coordinator operation changes the code.

   The app shows it on a Church information page (UI_DESIGN_SYSTEM section 70).

### Coordinator invariant

11. **An ACTIVE church always has an active Coordinator, at every commit.** An active Coordinator is an active COORDINATOR row on an ACTIVE membership of that church. The database enforces this with deferred constraint triggers, checked at commit. They fire on:
    - `churches`: insert, and a status change to ACTIVE;
    - `church_role_assignments`: insert, end and update;
    - `church_memberships`: status change.

    The operations check the same rule first, to return a usable refusal (`last_coordinator`).

    **Verified against the order of writes** (Phase 1 review, 2026-10-08). A deferred trigger runs at commit and sees the transaction's final state. So `create_church()` and bootstrap may insert the ACTIVE church first and the membership and COORDINATOR row afterwards: the check finds the Coordinator at commit and passes. A transaction that commits an ACTIVE church without one is rejected (`church_requires_coordinator`, SQLSTATE 23514), and so is one that ends or deactivates the last Coordinator. That includes a single direct write by trusted tooling, which commits on its own. Migration 018 uses the same pattern for ADR-020 (the Leader's row, then the DISCIPLER row), and `ministry_structure_test.dart` shows both outcomes in this stack. Three requirements on the implementation, which the precedent did not need:
    - **Re-read state, not the row.** The check re-reads the church's current status and Coordinators, not the values of the row that fired it.
    - **Every affected church.** It checks each church affected, including the old one when a membership's `church_id` changes.
    - **Lock the church row.** It locks the church row before counting, so two concurrent transactions that each end a different Coordinator cannot both pass (write skew). The second waits, then sees the first's commit and is rejected.
12. **Replacing a Coordinator is one operation**, `replace_church_coordinator(church, current, new email)`: it ends the current COORDINATOR row and grants the new one in the same transaction, so the invariant is never broken in between. Adding a second Coordinator and ending one of several are separate operations; ending the last is refused.

### Church status

13. **Statuses are ACTIVE, SUSPENDED and ARCHIVED.** `SUSPENDED` is a new enum value, added in its own migration. Allowed transitions:
    - ACTIVE → SUSPENDED and SUSPENDED → ACTIVE;
    - ACTIVE → ARCHIVED and SUSPENDED → ARCHIVED.

    ARCHIVED is final in the app. Activating a church requires an active Coordinator (decision 11). Every change is audited as `CHURCH_STATUS_CHANGED`, with the old and new status.

14. **What each status means:**

    | | ACTIVE | SUSPENDED | ARCHIVED |
    |---|---|---|---|
    | Sign-in and session | normal | normal: authentication is platform-level, so sign-in works and the session persists | as SUSPENDED |
    | App state (PENDING or ACTIVE member) | as today | **church unavailable**: a screen naming the church and saying it is unavailable for now, with Profile, account and sign-out | church unavailable, worded as closed |
    | Own profile and account | yes | yes: read and edit own profile, account settings, sign out | yes |
    | Own membership row; church id, name, status | yes | yes, read only, so the app can explain the state | yes |
    | Any other church data (members, roster, D Groups, meetings, progress, lesson list, lesson content, covers, avatars, settings) | per role | none, for every role, the Coordinator included | none |
    | Writes (Coordinator, Leaders, Disciplers, members) | per role | none: every controlled operation refuses with its usual authorization refusal (PT403 `not_authorized`, or not found), and reads return nothing (as built, Migration 025) | none |
    | Join-code lookup and join request | normal | finds nothing; a request answers INVALID_CODE, so suspension is not revealed | as SUSPENDED |
    | Pending requests | approved or rejected by the Coordinator | stay PENDING; cannot be approved or rejected; the applicant sees church unavailable, told their request is kept | stay PENDING as history |
    | Device copies (session snapshot, lesson copy) | as today | cleared at the next online refresh, because the server's scope is now empty (ADR-019 decision 7). Until the device is online it shows the last copy, view-only, as any offline copy. Answers saved on the device (ADR-021) belong to the person and stay | as SUSPENDED |
    | Super Admin | counts, code, Coordinators, status | change status, regenerate the code, assign, replace or end a Coordinator (never the last one) | listing only: no status change, regeneration or Coordinator change |
    | Reactivation | | SUSPENDED → ACTIVE with an active Coordinator restores everything exactly as it was. Nothing changes during suspension except the Super Admin's own changes. No rule in the MVP depends on elapsed time: the undo window, the setup period and eligibility are all derived from records | none in the app |

    - A person whose only membership is in a suspended or archived church stays on the church unavailable screen. With one church per person (decision 9), the app offers no other church to join.
    - A Super Admin who is also a member of a non-ACTIVE church sees the same screen, with the Platform entry still available.
    - A membership that is itself INACTIVE, TRANSFERRED or ARCHIVED keeps resolving to no access, whatever the church's status.

15. **Enforcement is in the database.** The effective-membership predicate (RBAC section 1a) becomes "an ACTIVE membership in an ACTIVE church". Every role helper and every policy relies on it, so a suspended church's data is unreadable and unwritable whatever the client does. The app's church unavailable state is presentation only.

### Startup

16. A signed-in Super Admin with no church membership resolves to a new platform state and opens the Platform area, never Join Church or Welcome. Resolution waits for the platform role as well as the profile and membership, so the splash covers the whole load and nothing flashes. A Super Admin who is also a member resolves by their membership, as today, and reaches the Platform area from Profile.

## Alternatives Considered

**Reuse church ADMIN as the platform role.** Rejected. ADMIN needs a church membership and ties platform authority to one church.

**Super Admin with read access to everything, for support.** Rejected. Platform authority would carry ministry-private data. Exceptions get their own audited operation instead.

**Create the church first, assign the Coordinator after.** Rejected (user decision). An ACTIVE church would exist for a moment, or as a normal state, without a Coordinator.

**Invite the Coordinator by email.** Rejected for the MVP: email automation is out of scope (MVP_SPEC section 33).

**Mark suspended members' memberships INACTIVE.** Rejected. It would end D Group responsibilities and pairings (DATABASE_CONSTRAINTS section 1) and make suspension irreversible in practice.

## Consequences

- New table `platform_roles` and enum `platform_role`; the `SUSPENDED` value of `church_status`; a unique key on `church_memberships(user_id)`; a check that no active ADMIN row exists; the Coordinator invariant triggers.
- `private.bootstrap_church()` grants COORDINATOR only, and its postconditions change to match.
- New controlled operations: `create_church()`, `preview_coordinator_account()`, `assign_church_coordinator()`, `replace_church_coordinator()`, `end_church_coordinator()`, `regenerate_join_code()`, `set_church_status()`, `list_churches()`, `list_platform_audit()`, `get_church_join_code()` (the Coordinator, decision 10a), and the service-role `private.grant_platform_role()` / `private.end_platform_role()`.
- The app gains a platform state, a church unavailable state and a small Platform area. Approval is gated by COORDINATOR only.
- The seed adds `superadmin@discipletrack.local`, with no church membership. Dev Admin stays the church's Coordinator only.
- Documents reconciled: RBAC_RLS_MATRIX sections 1, 1a, 2, 2b, 3 (with the new platform_roles), 8 to 11 and the Core Authorization Rule; DATABASE_CONSTRAINTS sections 0, 1, 9 and 12; the DBML; MVP_SPEC sections 2, 3, 5 to 7, 11, 12, 26 and 31 to 34; ARCHITECTURE sections 4, 5, 10a, 14 and 24 to 26; BUSINESS_RULES BR-001, BR-003, BR-005, BR-008, BR-009, BR-045 and new BR-005a to BR-005c; DATABASE_DESIGN sections 4.3 and 5; UI_DESIGN_SYSTEM header note, sections 22, 61, 62 and 69, and the new section 70 (Platform area, Church information, church unavailable); config/README; ADR-001, ADR-004, ADR-010.
