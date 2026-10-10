# Slice 8 plan: Platform roles and church provisioning

> **Working plan, not an authoritative document.** The governing documents
> (ADR-022, ADR-023, RBAC_RLS_MATRIX, DATABASE_CONSTRAINTS, the DBML,
> MVP_SPEC, BUSINESS_RULES, UI_DESIGN_SYSTEM section 70) carry the rules this
> plan implements. Where they and this plan differ, they govern and the
> difference is a defect in this plan.

Status: **decided 2026-10-08.**
- **Phase 1, decisions and documents: done 2026-10-08.** ADR-022 and ADR-023 are written and the documents are reconciled (section H).
- **Phase 1 review: reconciled 2026-10-08.** Four decisions (M18 to M21), applied to the plan and the documents.
- **Phase 2, database: implemented 2026-10-08, uncommitted, awaiting review.** Delivery record in section P.
- **Phase 3, app: implemented 2026-10-08, uncommitted, awaiting review.** Delivery record in section Q.
- **Phase 4 (walkthrough and close): not started.** Waits for review of phase 3.

Written 2026-10-08 from an audit of `main` at `73a66c9` (Slice 7 complete). Revised the same day: the user's locked decisions and answers replace the proposals (section M).

The slice:
- separates a platform-level **Super Admin** from the church-level **Coordinator**;
- makes church creation, join codes, the Coordinator and church status Super Admin operations;
- keeps every ministry operation with the Coordinator;
- never lets the platform role inherit ministry data;
- narrows curriculum access from the Discipler role to the relationship.

---

## A. Current-state findings

### A1. Roles in the database

- `church_role` enum: `ADMIN`, `COORDINATOR` (base schema). Both are rows in `church_role_assignments`, attached to a `church_memberships` row, so both are **church-scoped**. There is no platform-level role today.
- A role grants something only on an ACTIVE membership (RBAC section 1a).
- No app operation grants or ends a church role. The only writer is the trusted bootstrap.

### A2. Church creation and join codes

- Churches are created only by `private.bootstrap_church()`. It is executable by `service_role` alone and runs from `supabase/seed.sql` locally and from `tool/bootstrap_church.ps1` (psql) on a hosted project. There is no public or in-app create path.
- `churches.join_code` is `unique`. It is generated server-side by `private.generate_join_code()` (10 characters, `[A-HJ-NP-Z2-9]`), with `join_code_updated_at`. There is no regeneration operation.
- `lookup_church_by_join_code()` and `request_join_church()` match the current column and `status = 'ACTIVE'`. Replacing the value invalidates the old code with no extra mechanism.
- **No client can read a join code**, not even the Coordinator. The founder got it from tooling.
- `church_status` is `ACTIVE`, `ARCHIVED`. No operation changes a church's status, and there is no `SUSPENDED`.
- The bootstrap (latest body in Migration 018, `20261006000011_leader_discipler_and_founder.sql`) creates:
  - the church and its settings;
  - the founder's ACTIVE membership, onboarding completed;
  - **both `ADMIN` and `COORDINATOR`** for the founder.

  `private.assert_bootstrap_postconditions()` checks this.

### A3. Where ADMIN is honoured in the database

ADMIN grants exactly three things, all through `private.is_church_admin_or_coordinator()` (Migration 005):
1. `approve_church_membership()` and `reject_church_membership()`;
2. the `church_memberships_select_church_admin` policy (the church's memberships, PENDING included);
3. `private.can_view_profile_as_church_admin()` (those people's profiles).

Every other privileged operation uses `private.is_church_coordinator()`, which checks `COORDINATOR` only.

### A4. Where ADMIN is honoured in the app

- `canReviewMembershipsProvider` = `ADMIN` or `COORDINATOR`: the Requests tile on Home and Pending members.
- `isCoordinatorProvider` = `COORDINATOR`: the D Groups dock item, Home's church figures, D Groups, New group, Assign Leader, Eligible to disciple, the setup period, Curriculum.
- Otherwise `ChurchRole.admin` appears only in previews and the offline snapshot.

### A5. Startup and session

`SessionState` (`unknown`, `signedOut`, `noMembership`, `pending`, `activeFirstEntry`, `active`, `noAccess`) is resolved before routing; the router shows the splash while `unknown`. Slice 7 already fixed three things:
- the Join Church flash after sign-in;
- the founder seeing Welcome;
- persistent sessions and the remembered email.

What remains:
- **Every state assumes a church membership.** A Super Admin with no membership would resolve to `noMembership` and see Join Church.
- **No state for an unavailable church.**
- `fetchMyMembership()` uses `maybeSingle()` on the caller's rows. A person with rows in two churches would fail to load.

### A6. Curriculum access

Migration 019 (ADR-019 decision 16): `private.can_read_lesson_tier()` returns true for `private.is_discipler_in_church()` before looking at the context. Any active Discipler, every Leader included, reads all ten lessons in both tiers, in any context.

App effects of today's rule:
- `LessonCarousel(journey: null)` shows all ten lessons open to a Discipler without a journey.
- The reader shows a "Show answers" switch to a Disciple-Discipler in their own context.

### A7. Seed

`admin@discipletrack.local` (Dev Admin) is the founder: ADMIN and COORDINATOR of Liberty Bible Baptist Church - Gensan, in no D Group.

### A8. Found during reconciliation

- DATABASE_CONSTRAINTS section 1 described "Last Coordinator Protection" with a constraint trigger as defence in depth. **It was never built.** No migration has a Coordinator trigger, and no operation ended a role, so the gap had no effect until now.
- RBAC section 5 still described the pre-decision-16 lesson rule while section 10 described decision 16. Section 2 described neither (B7).
- The root README still said "Next: Slice 6". It is corrected.
- One membership per person was an app assumption only (`maybeSingle()`); nothing in the database enforced it.

---

## B. Conflicts and risks, with their resolution

| # | Finding | Resolution |
|---|---|---|
| B1 | Church ADMIN and a platform Super Admin are different things; reusing ADMIN ties platform authority to one church | `platform_roles`, ADMIN retired (ADR-022 decisions 1, 2) |
| B2 | ADMIN may approve memberships | Approval COORDINATOR-only (decision 3) |
| B3 | RBAC "Manage church configuration / roles" for ADMIN, never built | Replaced by five Super Admin rows (RBAC section 2) |
| B4 | Bootstrap postconditions require ADMIN and COORDINATOR | COORDINATOR only, no active ADMIN (DC section 0) |
| B5 | A Super Admin without membership would land on Join Church | `SessionState.platform` (section F) |
| B6 | ADR-019 decision 16 conflicts with relationship scoping | Superseded by ADR-023 (user decision) |
| B7 | RBAC section 2 lesson rows stale | Rewritten with section 5 and 10 (ADR-023) |
| B8 | No way to grant or replace a Coordinator | Assign, replace and end operations (section E) |
| B9 | `SUSPENDED` undefined | Defined (ADR-022 decision 14; section C3) |
| B10 | A platform role is new privileged state; any client path would be an escalation | No client write path; table-only check (D3) |
| B11 | Existing data; applied migrations immutable | Forward migrations with verifying backfills (section J) |
| B12 | Decision 9 (no member identities) versus decisions 4 and 6 (identify the person to assign or replace) | One exception: the active Coordinators' name and email, and the confirm-step name (user decision) |
| B13 | Decision 6 (never without a Coordinator) versus create-then-assign | Church created with its Coordinator atomically (user decision) |
| B14 | Several churches plus Coordinator-by-email make two-church accounts reachable | One church per person, enforced (user decision) |
| B15 | A Super Admin assigning themselves Coordinator would bypass decision 9 | Refused, `cannot_assign_self` (ADR-022 decision 6, BR-003) |
| B16 | Last-Coordinator trigger documented but not built (A8) | Built now as the deferred Coordinator invariant |
| B17 | No client can read the join code, so the Coordinator cannot share it (A2) | The Coordinator reads it, read-only, through `get_church_join_code()`; only the Super Admin generates it (M18) |
| B18 | A deferred count check is open to write skew: two concurrent ends of two Coordinators could both pass | The check and the operations lock the church row before counting (C4, M21) |

---

## C. Role and data model (decided)

### C1. Three levels, kept separate

```
PLATFORM   platform_roles           SUPER_ADMIN          (no church)
CHURCH     church_role_assignments  COORDINATOR          (ACTIVE membership, ACTIVE church)
D GROUP    d_group_memberships      LEADER, DISCIPLER, DISCIPLE
```

- **Super Admin.** A `platform_roles` row keyed to `profiles.id`, independent of any membership.
- **Coordinator.** As today. A church that is ACTIVE always has one.
- **Church ADMIN is retired.** The enum value stays. Existing rows are ended and audited. CHECK `church_role_assignments_admin_retired` keeps an active one from existing.
- **Separate authorities.** One person may hold Super Admin and, separately, COORDINATOR in a church, but never by assigning themselves.

### C2. `platform_roles`

| Column | Notes |
|---|---|
| `id` uuid pk | |
| `user_id` uuid, fk `profiles.id` | |
| `role` `platform_role` (`SUPER_ADMIN`) | |
| `granted_by` uuid, fk `profiles.id`, nullable | null for a tooling grant |
| `started_at`, `ended_at` timestamptz | ended, never deleted |
| `ended_by` uuid, fk `profiles.id`, nullable | null for a tooling end |
| `created_at` timestamptz | |

Constraints and access:
- one active row per (`user_id`, `role`), as a partial unique index;
- `ended_at > started_at`;
- RLS on: a person selects only their own rows;
- no client grant;
- written only by `private.grant_platform_role()` / `private.end_platform_role()`, `service_role` only.

### C3. Church status (ADR-022 decisions 13 and 14)

Transitions: ACTIVE ↔ SUSPENDED; ACTIVE or SUSPENDED → ARCHIVED; ARCHIVED is final. A trigger refuses any other change. Activation requires an active Coordinator (C4).

| | SUSPENDED | ARCHIVED |
|---|---|---|
| Sign-in, session | unaffected (authentication is platform-level) | unaffected |
| App state, PENDING or ACTIVE member | church unavailable (UI section 70) | church unavailable, worded as closed |
| Own profile and account | yes | yes |
| Own membership row; church id, name, status | read only | read only |
| Other church data, every role, the Coordinator included | none | none |
| Writes | none (PT403 `not_authorized`, as built) | none |
| Join code | lookup finds nothing; request answers INVALID_CODE | same |
| Pending requests | stay PENDING; approval and rejection refused | stay PENDING, as history |
| Device copies | cleared at the next online refresh (empty scope); until then the last copy, view-only. Device-only answers (ADR-021) kept | same |
| Super Admin | status, regenerate code, assign, replace or end a Coordinator (never the last) | listing only |
| Reactivation | to ACTIVE with a Coordinator restores everything exactly: no other row changes, and no MVP rule depends on elapsed time | none in the app |

A person whose only membership is in a suspended or archived church stays on the church unavailable screen. With one church per person, there is no other church to join.

Two further cases:
- A Super Admin who is also such a member gets the same screen, with the Platform row.
- A membership that is itself INACTIVE, TRANSFERRED or ARCHIVED stays `noAccess`.

### C4. Coordinator invariant (ADR-022 decisions 11 and 12)

An ACTIVE church has an active COORDINATOR row on an ACTIVE membership, at every commit. Enforcement:
- **Deferred constraint triggers** on:
  - `churches`: insert, and status to ACTIVE;
  - `church_role_assignments`: insert, update and delete;
  - `church_memberships`: status update.
- **Operations check first** and refuse with `last_coordinator`.
- **Replacement is one operation.**
- **SUSPENDED churches:** `end_church_coordinator()` refuses to end the last Coordinator of a suspended church too.

**Verification (M21).** Full text in DATABASE_CONSTRAINTS section 1, Coordinator Invariant.
- **Atomic creation is permitted.** A DEFERRABLE INITIALLY DEFERRED constraint trigger runs at commit and re-reads the final state. `create_church()` and bootstrap can therefore insert the ACTIVE church before its membership and COORDINATOR row, and the check passes.
- **The precedent works.** Migration 018 does the same for ADR-020 (LEADER row, then DISCIPLER row), and `ministry_structure_test.dart` passes against it.
- **Committed violations are rejected.** Any commit that leaves an ACTIVE church without an active Coordinator raises `church_requires_coordinator` (23514) and rolls back. That covers:
  - an ACTIVE church inserted alone;
  - the last role ended;
  - the last Coordinator's membership deactivated;
  - activation without a Coordinator;
  - a single trusted direct write.
- **Requirements the precedent did not need:**
  - re-read the church's current state, not the firing row's values;
  - check every affected church, the old one included;
  - lock the church row (`FOR UPDATE`) before counting, against write skew between concurrent changes;
  - the operations take the same lock first.
- **`SET CONSTRAINTS ... IMMEDIATE`** can only refuse more. Disabling triggers needs the table owner or a superuser, which is outside every app and tooling path.
- **Not run live.** The local stack was not running. The phase 2 tests in K make this executable.

### C5. One church per person (ADR-022 decision 9)

The rule is UNIQUE `church_memberships(user_id)`. `request_join_church()` gains the outcome `IN_ANOTHER_CHURCH`, and the Coordinator operations refuse `member_of_another_church`.

Consequence: a rejected applicant, or a person who has left, cannot join a different church in the MVP.

**An intentional MVP limitation (M20)**, not a domain invariant. Multi-church membership later needs:
- a forward migration dropping the unique key;
- a rule for which church a session acts in, and a church switcher;
- per-church session state in the app (today `fetchMyMembership()` loads one row).

No other constraint or table depends on it: domain records key to the church-scoped `church_memberships.id`.

---

## D. Authorisation and RLS model (decided)

### D1. Helpers

- **New: `private.is_super_admin()`.** Checks for an active `SUPER_ADMIN` row for `(select auth.uid())`. It reads the table only.
- **New: `private.church_is_active(church_id)`.**
- **Changed: the effective-membership predicate** (RBAC section 1a) becomes "ACTIVE membership **and** ACTIVE church". It is added to:
  - every role helper: `is_church_coordinator`, `is_church_admin_or_coordinator`, `is_my_membership`, the ministry-scope helpers, `can_read_lesson_tier`;
  - every policy and SECURITY DEFINER function that checks an ACTIVE membership. The audit counts 68 such checks in 16 migrations. The phase 2 migration redefines each; a registry test (K) fails if a client-callable function has no suspended-church case.
- **Exceptions to that predicate:**
  - `church_memberships_select_own` and `churches_select_own_church` keep returning the person's own row and the church's id, name and status whatever the church status, so the app can explain the state.
  - Profiles stay platform-level.
- **Changed: `private.is_church_admin_or_coordinator()`** is redefined as COORDINATOR only. Every caller stays correct, and `can_view_profile_as_church_admin()` follows it.

### D2. What the Super Admin reaches

| Super Admin may (controlled operations only) | Super Admin may not (no policy, no grant) |
|---|---|
| list churches: name, status, join code, created date, member counts by status, D Group count | memberships, profiles of members |
| the active Coordinators' id, full name, email | D Groups, rosters, pairings |
| preview an account by email (exists, confirmed, name, which church) | meetings, outcomes, journeys, progress |
| create a church with its Coordinator | lesson list, content, answers, covers |
| regenerate a join code | approve or reject membership |
| assign, replace, end a Coordinator (never self) | follow-ups, notes, announcements, settings |
| set church status | church ministry audit events |
| read platform audit events | |

No table policy is broadened. Any future exception gets its own justified, audited operation.

### D2a. The Coordinator's join code read (M18)

`get_church_join_code(p_church_id)`:
- returns the current code and `join_code_updated_at`;
- only to an active COORDINATOR of that church, on an ACTIVE membership, while the church is ACTIVE; `PT403` for everyone else, a Super Admin without COORDINATOR included;
- read-only and not audited (a read);
- opens no column grant on `churches.join_code`;
- comes with no Coordinator operation that changes the code.

### D3. Escalation and isolation guarantees

- No client write grant or policy on `platform_roles`. `grant_platform_role()` is not executable by `authenticated`.
- No JWT claim, profile field, user metadata or RPC parameter is consulted for the platform role.
- Every platform operation checks `is_super_admin()` first and raises `PT403` before reading anything.
- Coordinator scope stays bound to `church_id` through the membership, now also to the church's status.

---

## E. Provisioning operations (decided)

All operations are SECURITY DEFINER, `search_path = ''`, executable by `authenticated`, gated by `is_super_admin()` and audited. Full contracts are in RBAC section 10.

| Operation | Does | Audit |
|---|---|---|
| `create_church(p_name, p_coordinator_email)` | church ACTIVE, settings, curriculum and ten lesson rows, generated code, the Coordinator's ACTIVE onboarded membership and COORDINATOR, in one transaction; returns id and code | `CHURCH_CREATED`, `COORDINATOR_ASSIGNED` |
| `preview_coordinator_account(p_church_id, p_email)` | the confirm step: exists, confirmed, full name, and member of this church, another church or none | none (read) |
| `assign_church_coordinator(p_church_id, p_email)` | adds a Coordinator; creates or reactivates the membership ACTIVE, onboarding coalesced, `approved_by` untouched | `COORDINATOR_ASSIGNED` |
| `replace_church_coordinator(p_church_id, p_current_membership_id, p_email)` | ends one, grants the other, one transaction | `COORDINATOR_REPLACED` |
| `end_church_coordinator(p_church_id, p_membership_id)` | ends one of several; never the last | `COORDINATOR_ENDED` |
| `regenerate_join_code(p_church_id)` | new code, collision retried, `join_code_updated_at`; ACTIVE or SUSPENDED | `JOIN_CODE_REGENERATED` (no code value) |
| `set_church_status(p_church_id, p_status)` | the C3 transitions; changes nothing else | `CHURCH_STATUS_CHANGED` |
| `list_churches()` | D2 fields | none |
| `list_platform_audit(p_church_id, p_before)` | platform events, paged | none |
| `get_church_join_code(p_church_id)` | **the church's Coordinator, not the Super Admin** (D2a): current code, read-only | none (read) |
| `private.grant_platform_role()` / `private.end_platform_role()` | service role only | `PLATFORM_ROLE_GRANTED` / `_ENDED`, `church_id` null |

Refusals: `not_authorized`, `account_not_found`, `email_not_confirmed`, `member_of_another_church`, `cannot_assign_self`, `already_coordinator`, `last_coordinator`, `church_archived`, `status_unchanged`, `church_not_found`.

The flow:
1. The Super Admin creates the church with its Coordinator, after the confirm step.
2. The code is shown to the Super Admin. The Coordinator finds it under Profile, Church information (M18).
3. The church shares it, and members request to join.
4. The Coordinator approves.

Two more pieces:
- **Bootstrap.** `private.bootstrap_church()` is redefined to grant COORDINATOR only. Its postconditions also assert no active ADMIN and no membership elsewhere.
- **Lesson content for a new church** is published separately by `tool/publish_curriculum.ps1` under that church's licence reference (ADR-019 decision 11). Until then its lessons are titles only.

---

## F. Auth and startup routing

1. **`SessionState.platform`.** A signed-in Super Admin with **no** church membership routes to `/platform`, never to Join Church or Welcome. Resolution waits for `myPlatformRolesProvider`, as well as the profile and membership, so `unknown` covers the whole load.
2. **`SessionState.churchUnavailable`.** A PENDING or ACTIVE membership whose church is SUSPENDED or ARCHIVED shows one screen (UI section 70). The church's status comes from the existing `churches` read, now including `status`.
3. **A Super Admin who is also a member** resolves by membership. Profile shows a "Platform" row, which also appears on the church unavailable screen.
4. **A provisioned Coordinator** is ACTIVE with onboarding complete, so they see no Join Church and no Welcome.
5. **`IN_ANOTHER_CHURCH`** is mapped on Join Church.
6. **Kept under test:** the Join Church flash fix, the founder's Welcome fix, persistent sessions, logout clearing the session and the device copies.

---

## G. Curriculum: relationship-scoped access (ADR-023, decided)

| Reader | Own context | Currently assigned Disciple | Other Disciple of the group they lead | Anyone else |
|---|---|---|---|---|
| Disciple / anyone | Disciple tier, own reached lessons | n/a | n/a | refused |
| Discipler | own journey only; nothing without a journey | all ten, both tiers | n/a | refused |
| Leader (holds DISCIPLER) | own journey only (at most completed lessons) | all ten, both tiers | Disciple tier, that Disciple's reached lessons | refused |
| Coordinator | all ten, both tiers | all ten, both tiers | all ten, both tiers | any member: all ten, both tiers |
| Super Admin, no group, Needs setup, PENDING, non-ACTIVE church | nothing | | | refused |

The two cases that exist today:
- **A Discipler with no Disciples** reads only their own journey. Pairing opens the whole book in that Disciple's context.
- **Rosa (Disciple and appointed Discipler)** reads, in her own context, Lessons 1 to 6, Disciple tier, fillable, without answers. She has no paired Disciple yet. Once paired, she reads all ten, both tiers, in that Disciple's context.

**The Coordinator (M19, ADR-023 decisions 9 to 11):**
- keeps all ten lessons, both tiers, in their own context too: the one own-context exception, as curriculum oversight;
- **My Journey stays distinct.** For a Coordinator who is also a Disciple, its states come from their progression, and lessons open in the Disciple view (fillable, no answers). The full book is in Curriculum.
- **For every role, reading never affects progression.** It never makes a lesson current, reached or completed, never counts as a meeting, and never changes eligibility.

Database: drop the `is_discipler_in_church()` branch of `can_read_lesson_tier()`, and add the assigned-Disciple branch (all ten, both tiers) ahead of the reached-lesson check. `get_my_readable_content()` returns open tiers per context.

App effects, all in phase 3:
- **Leader's Home carousel.** No own-context carousel for a reader without a journey (`LessonCarousel(journey: null)` goes). Their lessons open from a Disciple: My Disciples, then the Disciple, then their lessons.
- **Lesson list.** In own context, the own journey with locks. In a Disciple's context, that context's access.
- **Reader.** The own-context "Show answers" switch is removed (ADR-021 decision 8 superseded). Own-context reads are fillable Disciple views. The Coordinator still reads answers.
- **Device copy.** Tiers are stored per context. Offline, the reader applies the context it is opened in.
- **Coordinator's My Journey.** Lesson states from the journey, never from `list_lesson_access()`. Lessons opened from My Journey are the Disciple view. Curriculum keeps the Discipler view.

---

## H. Documents changed (phase 1, done)

| Document | Change |
|---|---|
| **ADR-022** (new) | Platform Super Admin; church ADMIN retired; approval Coordinator-only; provisioning; one church per person; Coordinator invariant; status semantics; startup |
| **ADR-023** (new) | Relationship-scoped curriculum; supersedes ADR-019 decision 16 and ADR-021 decision 8 |
| ADR index | Both added; ADR-004, ADR-010, ADR-019 and ADR-021 statuses; ADR-013 slice number |
| ADR-004 | Role list (platform, church); the separation paragraph now names the Super Admin, the old wording noted |
| ADR-010 | Note: scope narrowed by ADR-023; ADMIN retired |
| ADR-019 | Status note; decision 16 marked superseded and kept as history; Admin wording; slice numbers |
| ADR-021 | Status; decision 8 superseded; slice numbers |
| ADR-001 | Role list |
| RBAC_RLS_MATRIX | Revision; sections 1 (three levels, SUPER_ADMIN, ADMIN retired), 1a (church status), 2 (Super Admin column, five platform rows, approval Coordinator-only, lesson rows fixed, notes), 2b, 3 (profiles, churches, church_memberships, church_role_assignments, new platform_roles, ADMIN mentions), 5, 8, 9, 10 (all platform operations), 11, Core Authorization Rule |
| DATABASE_CONSTRAINTS | Revision; section 0 (COORDINATOR only, postconditions, runtime creation); section 1 (rules, Coordinator Invariant, Church Status, Coordinator Provisioning, Platform Roles, constraints, regeneration, approval, IN_ANOTHER_CHURCH, onboarding); sections 9, 11 and 12 |
| DBML | Revision; `church_status.SUSPENDED`; `church_role.ADMIN` retired; `platform_role`, `platform_roles` and refs; `church_memberships(user_id)` unique; churches, roles and audit notes |
| MVP_SPEC | Revision; sections 2, 3, 5, 6 (Super Admin), 7, 11 (provisioning, no public creation, status), 12, 18, 26, 31 to 34 |
| ARCHITECTURE | Revision; sections 4, 5, 10a, 14, 24, 25, 26 |
| BUSINESS_RULES | Revision; BR-001, BR-003, BR-005, BR-008, BR-009, BR-029a, BR-045; new BR-005a, BR-005b, BR-005c |
| DATABASE_DESIGN | Revision; sections 4.3 and 5 (5.2 platform_roles rationale) |
| UI_DESIGN_SYSTEM | Header note; sections 22, 61, 62, 69; new section 70 (Platform area, church unavailable, refusal copy) |
| config/README | Seed cast (Super Admin, Dev Admin Coordinator only), lesson walkthrough by relationship, grant tool; flagged as post-Slice-8 |
| README | Status and roadmap brought up to date |
| AGENTS.md | Current phase, roadmap 8 to 12 |
| Slice 5 and 7 plans, SOURCE_ANALYSIS | Slice numbers shifted, with a dated note |

**Phase 1 review amendments (2026-10-08, M18 to M21):**

| Document | Change |
|---|---|
| ADR-022 | Status; decision 9 (MVP limitation and what lifting it needs); decision 10 (Super Admin only regenerates); new decision 10a (Coordinator reads the code); decision 11 (verification and trigger requirements); consequences |
| ADR-023 | Status; new decisions 9 to 11 (Coordinator full access, My Journey distinct, access never affects progression); app effects |
| ADR index | ADR-022 and ADR-023 amendments noted |
| RBAC_RLS_MATRIX | Revision; section 1 Coordinator list; section 2 new row "View and copy own church's join code" and notes; section 3 churches; section 5 Coordinator and progression; section 10 `get_church_join_code()` and the church row lock |
| DATABASE_CONSTRAINTS | Revision; Rules (limitation); Join Code Format (two controlled readers); Coordinator Invariant (trigger requirements, verification); section 11 (one-way dependency) |
| DBML | churches note (code readers); church_memberships note (limitation) |
| MVP_SPEC | Section 7 (Coordinator views the code), section 11 (flow, limitation), section 18 (Coordinator, My Journey, progression), section 33 |
| BUSINESS_RULES | BR-005a (only the Super Admin generates; the Coordinator views), BR-005c (limitation), BR-029a |
| ARCHITECTURE | Section 4 (limitation and what lifting it needs), section 14 (Coordinator) |
| UI_DESIGN_SYSTEM | Header note; section 70 retitled, with Church information (Coordinator) and the Coordinator's My Journey and Curriculum |
| config/README | Dev Admin row: Church information |

---

## I. Slice placement (decided)

A dedicated Slice 8 comes before the Workbook. The roadmap is now:

| Slice | Subject |
|---|---|
| 8 | Platform roles and church provisioning |
| 9 | Workbook / Guide |
| 10 | Monitoring / Follow-ups |
| 11 | Announcements |
| 12 | Reporting / Oversight |

Why now:
- every later slice adds data that authorisation must protect;
- approval, the gate to every church, changes owner;
- the change is mostly additive.

---

## J. Migration and backfill strategy

Applied migrations stay untouched. Migration 021 is the last applied, so this slice adds Migrations 022 to 026.

1. **022 `..._church_status_suspended.sql`.** `ALTER TYPE church_status ADD VALUE 'SUSPENDED'`, alone.
2. **023 `..._platform_roles.sql`.**
   - `platform_role`, `platform_roles`, RLS, `is_super_admin()`, `grant_platform_role()` and `end_platform_role()`.
   - End every active ADMIN row (`ended_at = now()`), with one `CHURCH_ROLE_ENDED` event each (reason `admin_retired`; actor the row's `assigned_by`, as in Migration 018). Then add the CHECK `church_role_assignments_admin_retired`.
   - An ADMIN without COORDINATOR (none in the seed) is listed in the migration notice for an operator.
   - Redefine `is_church_admin_or_coordinator()` as COORDINATOR only.
   - Verify that no user holds membership rows in two churches, and stop if one does. Then add UNIQUE `church_memberships(user_id)`.
   - Verify the Coordinator invariant for every ACTIVE church, and stop if it fails. Then create the deferred triggers (with C4's requirements: re-read state, every affected church, church row lock) and the church status transition trigger.
   - Redefine `bootstrap_church()` and its postconditions.
3. **024 `..._church_provisioning.sql`.**
   - The section E operations, each taking the church row lock first where it changes a Coordinator or a status.
   - `get_church_join_code()` (D2a).
   - `request_join_church()` with `IN_ANOTHER_CHURCH`.
4. **025 `..._church_status_gating.sql`.**
   - `church_is_active()`.
   - The effective-membership predicate added to every helper, policy and function (D1).
   - Every write operation refuses through the gated helpers (PT403 `not_authorized`; deviation D1 in section P).
5. **026 `..._relationship_scoped_curriculum.sql`.**
   - `can_read_lesson_tier()` per ADR-023.
   - `get_my_readable_content()` with per-context tiers.
   - `private.is_discipler_in_church()` is dropped if unused.

Then the seed and tooling:
6. **Seed.** `superadmin@discipletrack.local` (Dev Super Admin, no membership), granted through `private.grant_platform_role()`. Dev Admin stays the church's Coordinator only.
7. **Tool.** `tool/grant_super_admin.ps1`, grant and end, psql in the service-role context.
8. **Hosted projects.** Run the migrations, then the grant tool for the operator's registered account.

Rollback and reversibility: everything is additive, except the ended ADMIN rows and the narrowed lesson rule. History is kept, so both can be reversed by a forward migration.

---

## K. Test plan

### Integration, on the real local stack

Platform role:
- a member cannot insert, update or delete `platform_roles`, or read another person's row;
- no profile field, user metadata or RPC parameter grants it;
- `grant_platform_role()` is refused for `authenticated`;
- the tool's grant and end work and are audited.

Provisioning:
- `create_church` succeeds for a Super Admin only. A Coordinator, Leader, Discipler, member and anon are refused (`PT403` / `PT401`).
- It creates everything of section E in one transaction, and a forced failure leaves nothing.
- It refuses an unknown email, an unconfirmed email, a member of another church and the caller themselves.
- `preview_coordinator_account` returns only the listed fields.
- `regenerate_join_code` is Super Admin only. Afterwards the old code finds nothing and `request_join_church` refuses it, the new code works, and an earlier request stays PENDING. A forced collision is retried. No code value appears in the audit.

Atomic replacement and the invariant at commit:
- `replace_church_coordinator` leaves exactly one active Coordinator, and the replaced person stays an ACTIVE member with their D Group rows intact.
- In one transaction, ending the only Coordinator and committing fails at commit. Ending it, then granting another before commit, succeeds (deferred).
- Each of these fails at commit on an ACTIVE church: setting the Coordinator's membership INACTIVE; inserting an ACTIVE church without a Coordinator; activating a SUSPENDED church whose Coordinator was ended by service role.
- `end_church_coordinator` refuses the last Coordinator, for ACTIVE and SUSPENDED churches alike.
- M21, with service-role direct writes, each its own transaction, as in `ministry_structure_test.dart`:
  - `create_church` (church first, Coordinator after) commits;
  - a direct insert of an ACTIVE church with no Coordinator fails with `church_requires_coordinator`;
  - a direct update ending the only COORDINATOR row fails;
  - a direct update setting the only Coordinator's membership INACTIVE fails;
  - a direct update of a SUSPENDED church with no Coordinator to ACTIVE fails;
  - none of the rejected writes leaves any row changed.
- **Concurrency (B18).** A church with two Coordinators gets `end_church_coordinator` for each fired concurrently, repeated 20 times. Each round ends with exactly one active Coordinator: one call succeeds and the other is refused (`last_coordinator` or `church_requires_coordinator`).

Coordinator join code (M18):
- `get_church_join_code` returns the current code to the church's active Coordinator;
- it is refused for a Leader, Discipler, Disciple, member, PENDING applicant, a Coordinator of another church, a Super Admin without COORDINATOR, and anon;
- it is refused while the church is SUSPENDED or ARCHIVED;
- after regeneration it returns the new code;
- the Coordinator has no write path to the code: a direct update of `churches.join_code` is refused, and no RPC takes a code;
- `select join_code` on `churches` is still refused for every client.

ADMIN retired:
- every former ADMIN row is ended and audited;
- inserting an active ADMIN row is refused by the CHECK;
- bootstrap postconditions hold (COORDINATOR only).

Approval:
- the Coordinator may approve and reject;
- a former ADMIN without COORDINATOR may not, and neither may a Super Admin without COORDINATOR;
- a Coordinator of church A cannot act in church B.

Super Admin isolation:
- without a church role, a Super Admin reads no memberships, profiles, D Groups, rosters, meetings, journeys, progress, lesson list, content, answers, covers, settings or ministry audit events (each refused or empty);
- `list_churches` returns only the D2 fields;
- `list_platform_audit` returns platform events only.

Church status:
- each allowed transition works; ARCHIVED → anything is refused; a no-op is refused;
- a status change writes no other row;
- for a SUSPENDED church and an ARCHIVED one, a member of each role (Coordinator, Leader, Discipler, Disciple, member, PENDING):
  - can sign in;
  - reads their own profile, membership and church id, name and status;
  - reads nothing else;
  - every write operation refuses (PT403 `not_authorized` or not found);
- lookup finds nothing and a request answers INVALID_CODE;
- approval of a PENDING row is refused;
- SUSPENDED → ACTIVE restores identical reads (a snapshot before and after compares equal);
- **Registry test:** every client-callable function in `public` is listed with its suspended-church expectation, and the test fails when a new function lacks one.

One church per person:
- `request_join_church` answers `IN_ANOTHER_CHURCH`;
- assignment refuses `member_of_another_church`;
- the unique key holds.

Narrowed curriculum (ADR-023): one test per row of the section G table, plus:
- a Discipler with no Disciples opens nothing beyond their own journey;
- Rosa: own context gives Lessons 1 to 6, Disciple tier, no answers; once paired, the Disciple's context gives all ten, both tiers;
- a Leader with another Discipler's Disciple gets that Disciple's reached lessons, Disciple tier only;
- re-pairing, unpairing, removal and transfer end access at once;
- `get_my_readable_content` follows the new rule, and `list_lesson_access(context)` reports tiers per context (deviation D2);
- `check_lesson_answers` is unchanged;
- the Coordinator reads all ten lessons, both tiers, in their own context and in any member's (M19);
- **progression is unaffected (M19).** A Coordinator who is a Disciple, and a Disciple-Discipler, read every lesson open to them in every context. Afterwards `disciple_lesson_progress`, meetings, `get_disciple_journey()` (current lesson, completed lessons, eligibility) and `audit_events` are unchanged.

Audit: every provisioning operation writes its event.

### Unit and widget

- `resolveSessionState`:
  - a Super Admin without membership resolves to `platform`; with a membership, to the normal states;
  - a PENDING or ACTIVE membership in a non-ACTIVE church resolves to `churchUnavailable`; INACTIVE stays `noAccess`;
  - the state stays `unknown` while platform roles load (no Join Church flash, no Welcome).
- A returning ACTIVE member restores to Home. A valid persisted session restores. Logout clears it and the device copies.
- The church unavailable state clears the device copies at the next online refresh and keeps the device answers.
- The Requests tile and Pending members are gated by COORDINATOR only.
- Platform area: churches list; create with the confirm sheet; regenerate (dialog); add, replace and remove Coordinator; status dialogs; refusal copy; offline "needs a connection".
- Curriculum:
  - no own-context carousel without a journey;
  - the lesson list in own and Disciple context;
  - no "Show answers" switch in own context;
  - the reader applies the context offline.
- Leader keeps the Discipler experience plus Leader controls; the existing tests stay green.
- Church information:
  - the Coordinator sees the code with Copy and no regenerate action;
  - another role on the route gets the restricted state with no code;
  - offline it says "needs a connection";
  - the Pending members empty state links to it.
- Coordinator's My Journey: card states follow the journey, not the access list, and a lesson opens in the Disciple view. Curriculum opens the Discipler view.

---

## L. Implementation phases

1. **Decisions and documents. Done 2026-10-08.** Section M settled, ADR-022 and ADR-023 written, documents reconciled (section H), roadmap renumbered, UX review written (section N).
2. **Database.** Section J's migrations, the seed, the grant tool and K's integration tests.
3. **App.**
   - `SessionState.platform` and `churchUnavailable`, with routing;
   - `myPlatformRolesProvider`;
   - approval gated by COORDINATOR; `ChurchRole.admin` removed from gating;
   - the Platform area (UI section 70) and the Profile Platform row;
   - Church information for the Coordinator (UI section 70), with its Profile row and the Pending members link;
   - the Coordinator's My Journey kept on progression (section G);
   - `IN_ANOTHER_CHURCH` on Join Church;
   - the curriculum app effects (section G);
   - unit and widget tests.
4. **Walkthrough and close.**
   - The role walkthrough (UI section 69) as Super Admin with and without a membership, Coordinator, Leader, Discipler, Disciple-Discipler (Rosa), Disciple, pending member, and a member of a suspended church;
   - full suites;
   - the delivery record here;
   - AGENTS.md updated.

---

## Current Admin capability → target role

| Current capability (where) | Today gated by | Target | Note |
|---|---|---|---|
| Approve / reject membership (Pending members; `approve_`/`reject_church_membership`) | ADMIN or COORDINATOR | **Coordinator** | ADMIN loses it; refused while the church is not ACTIVE |
| Requests tile on Home | ADMIN or COORDINATOR | **Coordinator** | |
| Read the church's memberships and their profiles (policies) | ADMIN or COORDINATOR | **Coordinator** | |
| Church overview figures | COORDINATOR | Coordinator | unchanged |
| D Groups list, New group, Assign Leader | COORDINATOR | Coordinator | unchanged |
| Add members, set up, pair, remove, transfer | COORDINATOR (and Leader) | Coordinator | unchanged |
| Eligible to disciple, Appoint Discipler | COORDINATOR | Coordinator | unchanged |
| Initial setup period open / close | COORDINATOR | Coordinator | unchanged |
| Progress, meetings, record / void / complete as fallback | COORDINATOR | Coordinator | unchanged |
| Curriculum (all lessons, both tiers) | COORDINATOR | Coordinator | unchanged |
| "Manage church configuration" (RBAC, not built) | ADMIN | **Super Admin** | join code, status |
| "Manage church roles" (RBAC, not built) | ADMIN | **Super Admin** | assign, replace, end Coordinator |
| Create church (`bootstrap_church`, service role) | trusted tooling | **Super Admin** (in app, with its Coordinator) + tooling kept | |
| Join code generation | bootstrap | **Super Admin** | regeneration is new |
| Church status | none | **Super Admin** | new, with SUSPENDED |
| Platform audit | none | **Super Admin** | new |

Nothing the current Admin account does in the app is a platform operation; its whole dashboard is the Coordinator's.

---

## M. Decisions (locked 2026-10-08)

Replaces the proposed decisions M1 to M7.

User's locked decisions:
1. **Placement:** a dedicated Slice 8 before the Workbook; roadmap renumbered 9 to 12.
2. **ADMIN retired:**
   - no operation grants it again;
   - existing rows are ended, never deleted, each audited;
   - the enum value stays;
   - approval, rejection and reading the church's memberships and profiles become COORDINATOR-only.
3. **Super Admin is platform-level,** in `platform_roles`, with no client write path. The first Super Admin is granted only by service-role tooling and the seed.
4. **Coordinators are assigned by email:**
   - the email of an already registered account;
   - an explicit confirmation step;
   - the membership is created or reactivated ACTIVE, with onboarding complete.
5. **Church statuses:** ACTIVE, SUSPENDED (new enum value, in its own migration), ARCHIVED.
6. **Coordinator invariant:** an ACTIVE church is never without an active Coordinator, not even for an instant. Replacement is atomic, and the database enforces the invariant at commit.
7. **Curriculum:** Discipler access narrowed to the relationship, through a new ADR (ADR-023) that supersedes ADR-019 decision 16 and keeps its history.
8. **Seed:** a separate `superadmin@discipletrack.local` with no membership; Dev Admin stays Coordinator only.
9. **Super Admin visibility:** aggregate counts per church, never member identities or ministry-private data. Any future exception needs its own justified, audited operation.

Answers to the questions raised during reconciliation (2026-10-08):

10. **Curriculum, own context:** own journey only, for Disciplers and Leaders too. This changes today's access, and the user approved it.
11. **Curriculum, an assigned Disciple's context:** all ten lessons, both tiers.
12. **Curriculum, a Leader with another Discipler's Disciple:** Disciple tier, reached lessons.
13. **Exception to decision 9:** the Super Admin sees the active Coordinators' full name and sign-in email, and the confirm step shows the name of the account an email belongs to. Nothing else about any member.
14. **Church creation:** the church is created together with its Coordinator, atomically (`create_church(name, email)`).
15. **One church per person:** enforced in the database, with `IN_ANOTHER_CHURCH` and `member_of_another_church`.

Settled by the existing rules, recorded so they are not reopened:

16. **No self-assignment:** a Super Admin cannot assign themselves as Coordinator (BR-003).
17. **Suspension:** changes no membership or ministry row, and pending requests stay pending.

Phase 1 review decisions (2026-10-08):

18. **The Coordinator may view and copy their own church's join code**, read-only. Only the Super Admin generates or regenerates it. RBAC row, `get_church_join_code()`, and the Church information UI requirement (UI section 70).
19. **The Coordinator keeps full curriculum access**, all ten lessons and both tiers, in their own context too. My Journey stays distinct from curriculum oversight, and curriculum access never affects lesson progression (ADR-023 decisions 9 to 11).
20. **One church per person is an intentional MVP limitation.** Future multi-church support requires a migration (ADR-022 decision 9).
21. **The deferred Coordinator invariant is verified** to permit atomic church creation with Coordinator assignment, and to reject any committed ACTIVE church without an active Coordinator (C4). The verification added the church row lock against write skew (B18).

---

## N. Slice UX review (UI_DESIGN_SYSTEM section 69)

1. **Domain and workflow.** Church setup (MVP section 2, step one) and membership approval. The real events are a church starting on DiscipleTrack, its Coordinator changing, and a church pausing or closing.
2. **Roles.**
   - Super Admin without a church, and with one;
   - Coordinator: sole approver, provisioned without a welcome;
   - Leader and Discipler: the curriculum narrows;
   - Disciple: unchanged; Rosa loses her own-view answers;
   - Member without a group, and Pending: unchanged in an ACTIVE church;
   - a member of a suspended or archived church;
   - the former ADMIN: no change in the seed, since the person is also Coordinator.
3. **Real-world flow.** The pastor or ministry asks the platform operator for a workspace. The operator creates it with the agreed Coordinator, who must have registered first, and passes on the code. The app records the event; it sends no invitation.
4. **Information per role** (RBAC sections 1a, 2, 3, 5, 10).
   - Super Admin: churches, counts, codes and Coordinators; never member or ministry data.
   - Suspended member: own profile and the church's name only.
5. **Actions.**

   | Action | RBAC row | Frequency | Reversible | Affects |
   |---|---|---|---|---|
   | Create church | Create church | rare | archive only | the new Coordinator |
   | Regenerate code | Regenerate join code | rare | no (a new code) | everyone holding the old code |
   | Replace Coordinator | Assign, replace or end a Coordinator | rare | by replacing again | the whole church |
   | Suspend | Set church status | rare | yes | every member |
   | Archive | Set church status | rare | no | every member |
   | Copy join code (Coordinator) | View and copy own church's join code | occasional | n/a (read) | people the Coordinator shares it with |

   Each needs a confirmation (section 60, Settings / Administration).
6. **Derived values.** Member counts by status and D Group counts are counts at read time (DC section 11). Nothing is editable.
7. **States.**
   - loading: splash until the platform role resolves;
   - empty churches list: "No churches yet…";
   - offline: Platform "needs a connection";
   - restricted: church unavailable;
   - action errors: UI section 70 refusal table;
   - success: a snackbar naming the change.
8. **Patterns.** Grouped rows; a confirmation sheet for create, assign and replace, justified because it names the person; dialogs for regenerate, suspend and archive.
9. **Pages and navigation.**
   - Churches is a destination for a Super Admin without a church. Church detail is pushed from it.
   - For a member-Super Admin, Platform is a Profile row and earns no dock slot.
   - Church information is a Coordinator Profile row (settings class), also linked from the Pending members empty state.
   - Church unavailable is a single page.
   - Nothing duplicates a destination. For a Coordinator who is a Disciple, My Journey and Curriculum stay two places with two purposes (own journey, oversight).
10. **Components.** Reused: list rows, status pills (the existing pill), dialogs, bottom sheets, the activity timeline. New: none beyond the pages.
11. **Cross-role effects.**
    - The Coordinator is the only one with the Requests tile.
    - Disciplers and Leaders lose the own-view lesson carousel and answers; lessons open from a Disciple.
    - Members of a suspended church see one screen.
12. **Chore and ranking tests.** Nothing ranks churches or people. Counts are factual. No screen exists to look busy.
13. **Contradictions.** Reported and resolved by user decision: B12 to B15. Remaining: see section O.
14. **Implementation order.**
    1. session states and routing;
    2. approval gating;
    3. curriculum effects;
    4. Platform area pages;
    5. church unavailable.

---

## O. Open items (not blocking phase 2 unless noted)

Resolved by the Phase 1 review: the Coordinator's join code (M18), the Coordinator's own-context access (M19), and the single-church limitation (M20).

1. **Time-based rules during suspension.** None exist in the MVP. Slice 10 (follow-up due dates) must define what suspension does to them (DC section 1, Church Status).
2. **Lesson content for a second church** needs its own licence reference (ADR-019 decision 11). Until it is published, that church has titles only.
3. **The invariant verification is analytical** (C4, M21). The local stack was not running. Phase 2's tests in K are the executable proof, including the concurrency test.

---

## P. Phase 2 delivery record (2026-10-08)

Database only. No Flutter code, no UI. Uncommitted.

### Migrations

| # | File | Contents |
|---|---|---|
| 022 | `20261008000001_church_status_suspended.sql` | `church_status` gains `SUSPENDED`, alone in its file |
| 023 | `20261008000002_platform_roles.sql` | `platform_role`, `platform_roles` (RLS, own-row SELECT, no client write), `is_super_admin()`, service-role `grant_platform_role()` / `end_platform_role()`; ADMIN retirement (every active row ended, one `CHURCH_ROLE_ENDED` each, ADMIN-only holders reported), then CHECK `church_role_assignments_admin_retired`; `is_church_admin_or_coordinator()` COORDINATOR only; one church per person (verified, then UNIQUE `church_memberships(user_id)`); the Coordinator invariant (verified, then three deferred constraint triggers that lock the church row); the church status transition trigger; bootstrap and its postconditions COORDINATOR only |
| 024 | `20261008000003_church_provisioning.sql` | `create_church()`, `preview_coordinator_account()`, `assign_church_coordinator()`, `replace_church_coordinator()`, `end_church_coordinator()`, `regenerate_join_code()`, `set_church_status()`, `list_churches()`, `list_platform_audit()`, the Coordinator's `get_church_join_code()`, and `request_join_church()` with `IN_ANOTHER_CHURCH` |
| 025 | `20261008000004_church_status_gating.sql` | `church_is_active()`; the nine caller helpers require an ACTIVE church; the five operations that identify the caller inline (`get_church_avatars`, `get_lesson_covers`, `get_my_d_group_roster`, `list_disciple_progress`, `complete_onboarding`) redefined with the same condition. Generated from their latest definitions, one asserted change each |
| 026 | `20261008000005_relationship_scoped_curriculum.sql` | `can_read_lesson_tier()` per ADR-023; `is_discipler_in_church()` dropped |

Also: `supabase/seed.sql` (Dev Super Admin, `superadmin@discipletrack.local`, granted through `grant_platform_role()`), `tool/grant_super_admin.ps1`.

### Verification run

All runs used the documented workflow (`npx supabase db reset`, then `flutter test --dart-define-from-file=config/test.json test/integration`).

- **Baseline before any change:** 293 of 293 integration tests passed.
- **After Phase 2, on a fresh reset:** 325 of 325 integration tests passed.
- **Upgrade path:**
  - procedure: reset to Migration 021 without the seed, bootstrap the old way (ADMIN and COORDINATOR), add an ADMIN-only member, then `supabase migration up`;
  - result: both ADMIN rows ended and audited (`also_coordinator` true and false), COORDINATOR kept, the CHECK, the unique key and the three triggers present, and the bootstrap's idempotent re-run passes the new postconditions.
- **Analyzer and format:** `flutter analyze` reports no issues, and the `dart format` check is clean.
- **Unit and widget:** 399 passed, 1 failed (`curriculum_definition_test`: the generated seed matches the definition).
  - The failure is a CRLF difference from `core.autocrlf=true` on this checkout, in files this phase did not touch.
  - It is not caused by Slice 8, and the baseline did not run unit tests.

New integration tests:
- `platform_roles_test.dart`: escalation, provisioning, Coordinators, the invariant at commit through direct writes, concurrency at operation and trigger level, join codes, one church per person, Super Admin isolation.
- `church_status_test.dart`: suspended and archived semantics; reactivation restores every read exactly; a registry sweep that classifies every PostgREST function and calls each as the suspended church's Coordinator.
- `relationship_curriculum_test.dart`: Rosa, the Leader as Discipler and with others' Disciples, re-pairing, the Coordinator, progression unaffected.

Existing tests changed for the decisions:
- the test support creates churches SUSPENDED, then activates them with their Coordinator, and archives before teardown;
- former-Admin fixtures insert ended ADMIN rows;
- the bootstrap and approval expectations are COORDINATOR only;
- the five decision-16 curriculum assertions now follow ADR-023;
- the `required_meetings` function list includes `create_church`;
- one approval test uses a second Coordinator, because the only one can no longer be deactivated.

### Deviations from the plan

- **D1. No `church_not_active` code.** Gating lives in the shared caller helpers. Operations refuse with their existing PT403 `not_authorized` (or not found), and reads return nothing. A distinct code would have meant redefining about 40 functions, or adding a PostgREST pre-request hook. The app learns the status from the `churches` row it can still read. ADR-022, RBAC section 1a and DATABASE_CONSTRAINTS are updated to the as-built behaviour.
- **D2. `get_my_readable_content()` keeps its shape.** The new `can_read_lesson_tier()` makes its union correct without a change. Per-context tiers come from `list_lesson_access(p_for_membership_id)`, which phase 3 stores per context. RBAC section 10 is updated.

### Remaining risks

- **Restrictive gating depends on the helpers.** A future operation that identifies the caller inline, instead of through a helper, must add the church condition itself. The registry sweep fails for any unclassified function, but a classified function with a new inline check would still need a test.
- **The concurrency proof** uses `SET CONSTRAINTS ALL IMMEDIATE` to force the interleaving deterministically. Without it, the deferred check runs at commit, where the same lock applies. The commit-time race itself is covered by the operation-level test (10 rounds), not by a forced interleaving.
- **Trusted tooling can still disable triggers** (table owner). That is outside every app path.
- **The hosted upgrade** stops if any user holds memberships in two churches, or if an ACTIVE church lacks a Coordinator. Both were checked locally; neither exists in the seed.

### Phase 2 review cleanup (2026-10-08)

1. **Refusals.** The existing authorization refusals are kept (D1 accepted); there is no `church_not_active` code. The app resolves the church's status through the church row its members can still read.
2. **Status lookup verified.** A new `church_status_test.dart` case covers SUSPENDED and ARCHIVED. In each, the Coordinator, an ACTIVE member and a PENDING applicant:
   - read exactly their church's id, name and status;
   - cannot read the join code, by column or by `select=*`;
   - see only their own membership row, their own profile and their own roles;
   - see no curricula, lessons or D Groups.

   An INACTIVE membership still sees no church, as before Slice 8.
3. **`curriculum_definition_test`.** The CRLF cause is confirmed: `git ls-files --eol` shows both files as `i/lf w/crlf` under `core.autocrlf=true`. The generator's template is LF and the embedded JSON was CRLF, so the comparison could never match on Windows.
   - **Fix:** `curriculumSeedSql()` normalizes the definition to LF, so its output is the same on every platform, and the test compares the committed file with LF line endings. Any other difference still fails.
   - **Verified:** the generated SQL equals the committed blob byte for byte and contains no CR.
   - No curriculum content was changed.
4. **Mandatory review item.** Church-status gating is documented in AGENTS.md (Rules), RBAC section 10 and DATABASE_CONSTRAINTS section 1 (Church Status). The registry sweep is kept, and new client functions must be added to it.
5. **Reruns:**
   - unit and widget: 400 of 400 passed;
   - integration on a fresh `db reset`: 326 of 326 passed, then 326 of 326 again on a second run;
   - `flutter analyze`: no issues; format check: clean.

   The first rerun had found a flaw in a new test: a global church count raced with test files running in parallel. It now counts by name.

---

## Q. Phase 3 delivery record (2026-10-08)

Flutter app only. No migration or seed change; no Phase 2 contract defect found (the app repositories were checked against the real stack). Uncommitted.

### What changed

| Area | Files | Change |
|---|---|---|
| Domain | `membership/domain/church_membership.dart` | `ChurchStatus`; `ChurchSummary.status` (a lookup row is ACTIVE); `ChurchJoinCode`; `ChurchRole.admin` kept for parsing only |
| Platform | `features/platform/` (domain, data, application, presentation) | `PlatformRole`, `PlatformAccess`, `PlatformChurch`, `CoordinatorRef`, `AccountPreview`, `PlatformEvent`, `PlatformFailure` (refusal sentences from UI section 70); `PlatformRepository` over the Migration 024 operations; `myPlatformAccessProvider` (offline from the snapshot), `isSuperAdminProvider`, `platformChurchesProvider`, `platformEventsProvider`; pages Churches, New church, Church detail, and the shared confirm-the-person sheet |
| Session and routing | `session_state.dart`, `router.dart`, `routes.dart`, `dock_shell.dart`, `app.dart` | `SessionState.platform` and `churchUnavailable`; resolution waits for the platform role and the church's status; Platform routes for a Super Admin from any resolved state; platform dock (Churches, Profile); church and platform role re-read on resume |
| Church access gate | `membership_providers.dart` (`hasChurchAccessProvider`), ministry, discipleship, curriculum, membership review providers | Every church read requires an ACTIVE membership in an ACTIVE church; roles empty otherwise; `canReviewMemberships` is COORDINATOR only |
| Coordinator | `church_info_page.dart`, `join_code_card.dart`, `membership_repository.dart` (`fetchJoinCode`), Profile, Pending members | Church information with the read-only code and Copy; Profile "Administration" card (Church information, Platform); Pending members' empty state links to it |
| Church unavailable | `church_unavailable_page.dart`, offline snapshot and sync, curriculum cache `clear()` | One screen with Profile, Try again, Sign out (and Platform for a Super Admin); the snapshot keeps the status and drops roles and roster; the lesson copy and covers are cleared on a live unavailable answer |
| Joining | `membership_repository.dart`, `join_church_controller.dart` | `IN_ANOTHER_CHURCH` outcome and its sentence |
| Curriculum (ADR-023) | `lesson_reader_page.dart`, `lesson_index_page.dart`, `lesson_carousel.dart`, `journey_blocks.dart`, `d_groups_page.dart`, `journey.dart`, `lesson_content.dart`, `curriculum_repository.dart`, `curriculum_providers.dart` | Own view always the Disciple view (fillable, no answers), the "Show answers" switch removed; Curriculum (`/lessons?view=curriculum`) shows both tiers; the carousel and the own lesson list open only lessons the journey has reached; no Home carousel for a Discipler without a journey; device copy version 2 with lesson access per Disciple context, read offline through the opened context |

### Tests

- New:
  - `test/unit/platform_session_test.dart` (24);
  - `test/widget/platform_pages_test.dart` (17);
  - `test/widget/curriculum_relationship_test.dart` (6);
  - a Join Church `IN_ANOTHER_CHURCH` case;
  - `test/integration/platform_repository_test.dart` (4, the app repositories against the real stack).
- Updated:
  - fakes: the platform role override, a platform fake, the join code read, per-context access;
  - two session tests, which now supply the church and the platform role;
  - the Home Admin case: the retired role grants nothing.
- Results:
  - `flutter analyze`: no issues; `dart format` check: clean;
  - unit and widget: 449 of 449 passed;
  - integration on a fresh `db reset`: 330 of 330 passed.

### Deviations

- Platform activity is a plain list (`InfoGroup`) rather than the journey `ActivityTimeline`, whose events are lesson-specific.
- The app was not launched for a visual pass; that is the phase 4 walkthrough.

### Remaining risks

- **A suspension made while the app is open** is noticed on resume, on reconnect or with Try again. Until then the server already refuses every read and write (PT403 or empty), so screens show refusals or empty states, never data.
- **A device that has not been online since the suspension** shows its last snapshot, view-only, as ADR-022 accepts. Once a live answer arrives, the snapshot and lesson copy are cleared.
- **Older device copies are replaced.** Device copies of version 1 are ignored. Offline before the first online refresh after the update, lessons say they are not downloaded yet.
- **Platform reads stay live.** The Platform area keeps no device copy; offline it shows its "needs a connection" state.

## R. Phase 4 delivery record (2026-10-08)

Walkthrough on the Android emulator (AVD `discipletrack`, 1080x2424, debug build) against the local stack, with the seed accounts and three walkthrough accounts created through the local auth admin API (`walk.coord`, `walk.next`, `walk.third`). Uncommitted.

During the walkthrough the user asked for three changes. Each is recorded below, with its documents:
- the button colours on Church detail;
- New church as a stepper of pages instead of a sheet;
- every Discipler and Leader reading the whole book in their own context (ADR-024, Migration 027).

The last one changed an approved rule and the database, so it was confirmed with the user first.

### Automated tests (final, after the Phase 4 review fixes)

- `flutter analyze`: no issues. `dart format` check: clean.
- Unit and widget: 456 of 456 passed.
- Integration, in an isolated stack (a copy of `supabase/` with its own project id `discipletrack-iso` and ports 55xxx; the emulator's stack on 54xxx and its data were left untouched):
  - **Fresh:** `db reset` applied Migrations 001 to 027 and the seed. 331 of 331 passed.
  - **Upgrade:** `db reset --version 20261008000005` (to Migration 026), then `migration up` applied 027 alone. 331 of 331 passed.
  - **Upgrade effect on the seed** (`list_lesson_access()`, own context):

    | Account | Before 027 | After 027 |
    |---|---|---|
    | Leader (Lea) | nothing | all ten, both tiers |
    | Rosa (Disciple-Discipler) | Disciple tier of 1 to 6 | all ten, both tiers |
    | A plain Disciple | Disciple tier of reached lessons | unchanged |
    | Coordinator | everything | unchanged |
  - The SQL helper of the integration tests runs `docker exec` against `SUPABASE_DB_CONTAINER` (default `supabase_db_discipletrack`). The isolated runs set it to `supabase_db_discipletrack-iso`. A first attempt without it sent one `grant_platform_role()` call to the emulator's database. That call raised and wrote nothing: the platform roles there are still the one seeded row.
- The emulator's stack had Migration 027 by `migration up` earlier; its suite also passed there (331).
- New or changed tests:
  - New church stepper: the full path through four pages, the blank name, a refused email at step 2, the confirm step without a draft, and back from the created page.
  - Archive dialog action in the error colour.
  - Home Lessons for a Discipler without a journey, and for a Disciple-Discipler.
  - `LessonCarousel.book()`; the whole-book list titled "Lessons" for a Discipler; a journey and the book on one page each open on their own start.
  - Own-context access for a Discipler, a Leader, a Disciple-Discipler and a plain Disciple (`relationship_curriculum_test.dart`, `curriculum_content_test.dart`).

### Manual tests actually performed on the device

- **Launch and session:**
  - The app launches.
  - The session is restored after close and reopen, after a rebuild and relaunch, and after a force stop and cold start.
  - Signing out and in again works.
- **Startup routing:**
  - Super Admin goes to Churches.
  - Rosa (Disciple) goes to Home with her journey carousel (Lesson 6 Now, 7 and 8 locked) and no Administration card on Profile.
  - Walk Replacement (Coordinator of a new church) goes to Home with Church overview.
  - A member of a suspended church goes to Church unavailable.
- **Super Admin:**
  - Churches list with counts and Coordinator.
  - New church stepper, end to end twice (Walk Grace Church, Walk Hope Church): the step indicator, "Not this person" keeping the email, and the created page with the join code.
  - Back from the created page returns to Churches (after the fix below).
  - Earlier, the sheet version's blank-name error and the "No DiscipleTrack account uses that email" refusal.
  - Church detail: counts, join code and Copy.
  - Regenerate: Cancel keeps the code; Change code replaces it and shows "Join code changed".
  - Replace Coordinator:
    - an account of another church is refused ("That person already belongs to another church.");
    - the confirmation names both people;
    - the replaced person stays a member (2 members).
  - The overflow of the only Coordinator offers Replace only.
  - Suspend, with its dialog; the status action changes to Reactivate.
  - Archive, with its dialog; the archived church shows no actions and the archived note.
  - The activity list shows every change, by "Dev Super Admin".
- **Suspended church, as its Coordinator:**
  - The unavailable page on sign-in.
  - Profile is reachable from it, without Church information.
  - After reactivation, Try again goes to Home.
  - On resume after a suspension made while the app was in the background, the unavailable page.
  - On a cold start while suspended, the unavailable page.

### Device checks after the Phase 4 review (latest build installed)

- **ADR-024, Leader:** Lea's Home has Lessons between the D Group card and Your Disciples. Lesson 1 opens with the answers filled in.
- **ADR-024, Discipler:** Dino's Home has Lessons. See all opens the list titled "Lessons" with all ten open, and Lesson 10 opens.
- **ADR-024, Disciple-Discipler:** Rosa's Home shows Your journey opening on "Lesson 6 · Now" with Lesson 7 locked, and Lessons, apart from it, from Lesson 1 with all ten open.
- **Coordinator:**
  - Walk Pending, a new account whose join request was made through `request_join_church()`, shows on Requests (1).
  - Approve takes it off the list, and the database shows the membership ACTIVE. Liberty's count rose to 16.
  - The empty state's "Share your church's join code" opens Church information: the church, the code with Copy, and "Only the DiscipleTrack administrator can change this code". Profile's Administration card offers it too.
- **Archived church, as its member:** Walk Third sees "This church is closed", with its records kept, and Profile, Try again and Sign out.
- **Reactivate by tapping:** with Walk Grace Church suspended, Reactivate church opened its dialog. Reactivate restored Suspend and Archive and logged "Church reactivated".
- **Sign out:** a red text action at the end of Profile, apart from the rows above it, with no confirmation (review decision 1).

### Tests blocked or not performed

- **Offline copies on the device** (airplane mode). Not performed. Covered by the offline and curriculum widget tests.
- **Dark mode, other screen sizes, and font scaling.** Not performed.
- **Lessons 2 to 9 opened one by one** for a Discipler. Not performed; the list showed all open, and Lessons 1 and 10 were opened.
- The emulator ran slowly for part of the session; one capture stalled and one password went in truncated. Both were retried; no result depends on them.

### Bugs discovered and fixed

| Bug | Fix |
|---|---|
| InfoRow values ended where the label ended, not at the right edge | `info_group.dart`: label and value spread across the row |
| The theme toggle on Churches was clipped at the right | page padding on the action |
| The confirm-the-person sheet opened under the dock | `useRootNavigator: true`; bottom padding includes the safe area |
| The blank-name error stayed after typing | cleared on change |
| Back from the created church re-entered step 1 of a finished stepper | the created page moved out of `/platform/new` to `/platform/created` |
| With two carousels on Home, Rosa's journey opened on Lesson 1 instead of her current Lesson 6: both carousels kept their page in the same PageStorage slot | `PageController(keepPage: false)`, and a widget test |

### Changes at the user's request

| Request | Change | Documents |
|---|---|---|
| Button colours should say what each action does, less is more | AppButton `caution` and `destructive`. Suspend is caution, Reactivate is primary, Archive is destructive, Regenerate is secondary. Remove and the Archive dialog action are in `error` (`showConfirmDialog(destructive:)`) | UI section 40, section 70, component table |
| New church as a stepper of separate pages with an indicator at the top, not a sheet | `StepIndicator`, then three pages (Name, Coordinator, Confirm) and a created page, with a shared draft | UI sections 60 and 70 |
| Lessons on the Leader's Home; Leaders and Disciplers have their own complete unlocked lessons | ADR-024, Migration 027 (own context: a DISCIPLER row opens all ten, both tiers). Home Lessons section for every appointed Discipler (`LessonCarousel.book()`, opened in the whole-book view with answers; its list titled Lessons). A Disciple-Discipler keeps My Journey gated | ADR-024; ADR-023 status; ADR index; RBAC sections 2 and 5 and the as-built note; BUSINESS_RULES; DATABASE_CONSTRAINTS (Reached Lessons); MVP_SPEC; ARCHITECTURE; UI summary, component table and the My Journey and Curriculum subsection; AGENTS.md |

A Disciples' lessons section on Home (one Disciple's lessons, chosen by name) was built first and then removed when the user chose own lessons only.

### Phase 4 review decisions (2026-10-08)

1. **Sign out:** no confirmation, kept as an out-of-the-way text action at the end of Profile. Recorded in UI_DESIGN_SYSTEM, component consolidation.
2. **Add and Replace Coordinator keep their confirmation sheets.** UI_DESIGN_SYSTEM now permits a confirmation sheet for a sensitive identity or role operation that must name the account first (component consolidation and section 60). The earlier "No confirmation sheets" contradiction is resolved.
3. **The whole-book list is "Lessons"** for a Discipler or Leader. "Curriculum" stays the Coordinator's title (`LessonIndexPage`; UI summary, component table, My Journey and Curriculum subsection; ADR-024).
4. **ADR-024 accepted.** Its status records the review.

Documents reconciled in this round:
- UI_DESIGN_SYSTEM: component consolidation, section 60, summary, component table, subsection.
- ADR-024.
- `config/README.md`: its stale "before implementation" note is replaced, and the seed table has the ADR-024 behaviour for Lea, Dino and Rosa.
- RBAC_RLS_MATRIX: the revision note no longer says the as-built notes describe Migrations 001 to 021.

### Still open (for review, not changed)

- **Section titles inside an InfoGroup ("Counts", "Activity") sit a few pixels further in** than SectionHeading titles ("Coordinators", "Status") on the same page.

### Remaining risks

- **A Disciple-Discipler's journey gate is presentation.** The database lets them read every lesson in their own context. My Journey and the own lesson list show only their reached lessons, as for the Coordinator (ADR-023 decision 10). Their progression is still recorded only by their Discipler, in the database.
- **Every Discipler's device copy holds both tiers of all ten lessons**, answers included.
- **No integration test ends a DISCIPLER responsibility** and checks that the own-context grant closes. The rule reads the active row directly.
- **The integration suite reaches the database two ways:** the API URL from the define file, and `docker exec` on `SUPABASE_DB_CONTAINER`. Both must point at the same stack, or tests mix data across stacks.
- **`assets/brand/login_icon.png` shows as modified in the working tree** and has since before this session. It is protected and must not be included in the commit.
