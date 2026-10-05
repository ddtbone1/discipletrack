> **Working plan, not an authoritative document.** Final proposed scope and decisions for Vertical Slice 5, reissued 2026-10-02 after the documentation revision for ADR-010, ADR-011 and the UX architecture (UI_DESIGN_SYSTEM sections 58 to 69). The governing documents listed in AGENTS.md already carry the rules this plan implements; where this plan and they differ, they govern and the difference is a defect in this plan. Do not start implementation without an explicit instruction. One product decision blocks completion of the slice (N1, section M); section C shows exactly where it plugs in. A second decision, D2, is required before step 7 (section Q). Amended 2026-10-05 (first) for the confirmed Discipler progression rules: see section P. Amended 2026-10-05 (second) after the user's decisions of that date: ADR-012 (Discipler eligibility after Lesson 5 and concurrent Disciple and Discipler responsibilities) and ADR-014 (D Group gathering attendance removed from the MVP) are accepted, N7, N8 and N9 are approved, and the governing documents now carry those rules (revision 2026-10-05). The database still enforces the DISCIPLE / DISCIPLER exclusion until the Slice 6 migration; the documents mark that invariant "enforced from Slice 6". Gathering removal: section R. Open D decisions, classified: section Q. **Approved for implementation 2026-10-05 (third):** the documentation is accepted; D2 is answered (one policy function, not configurable); the consecutive recorded absence threshold is 3; the Leader and Discipler follow-up branches stay inactive (Slice 9 owns them); N1 remains open and gates only the dependent part of step 7. See section S. **Amended 2026-10-05 (fourth):** the Discipler marks a lesson completed with no Leader confirmation (ADR-015), and meeting history becomes a month calendar; this supersedes the submission, withdrawal and confirmation parts of earlier sections. See section T.

# Vertical Slice 5: Journey / Meeting Progress (Discipleship Meeting + Progress)

## Context

This slice delivers the core loop in MVP section 2: **record a meeting against the current lesson, with each Disciple's attendance outcome → factual meeting history → the Discipler submits the lesson as finished → the Leader confirms → the next lesson becomes current.** Monitoring is not part of it. Attendance exists only as the outcome recorded in Record Meeting (ADR-014); there is no gathering, no gathering attendance and no Attendance destination.

Slice 3 left in place what this slice depends on: DISCIPLE rows created by accepted invitations; active `discipler_assignments` to DISCIPLER rows in the same group (P1 to P3); an active Leader in every group; tested scoping helpers; `MONITORING HOOK` comments where assignments end. Slice 4 left the offline snapshot and banner.

Verified baseline (HEAD `d9d7265`):

- Migrations 001 to 006 are committed and immutable.
- `curricula`, `curriculum_lessons`, `discipleship_meetings`, `discipleship_meeting_participants`, `disciple_lesson_progress` and `attention_conditions` exist from Migration 001 with no policies, RPCs or triggers, and still hold Supabase's default grants. So do the deprecated gathering tables `d_group_gatherings` and `gathering_attendance` (RLS enabled, zero policies; ADR-014).
- Migration 004 seeds one ACTIVE curriculum of 12 lessons, each with `required_meetings = 4`, and sets both `church_settings.consecutive_absence_threshold` and `church_settings.consecutive_missed_meeting_threshold` to 3 (asserted by `private.assert_bootstrap_postconditions()`). Under ADR-014 the first is the threshold for consecutive recorded absences and the second is dormant. Neither is read in this slice.
- No lesson Markdown exists in the repository. This slice uses lesson identity, number, title and order only.

Changes from the ERD and ADRs still missing from the database:

| Change | Current DB | Required |
|---|---|---|
| `meeting_participation_status` value | `COUNTED` (also the column default) | renamed `RECORDED` (ADR-009) |
| `discipleship_meeting_participants.attendance_status` | absent | `NOT NULL`, no default (ADR-009) |
| `disciple_lesson_progress.submitted_by` | absent | `uuid` → `profiles.id` (ADR-011) |
| `disciple_lesson_progress` state CHECK | absent | DC section 4, Progress State Check |
| `attention_condition_type`, `follow_up_reason` | `CONSECUTIVE_ABSENCE` only | **no change**. The planned `CONSECUTIVE_MISSED_MEETINGS` value is withdrawn; `CONSECUTIVE_ABSENCE` now means consecutive explicitly recorded ABSENT discipleship outcomes (ADR-014 decisions 6, 7) |
| Grants on `d_group_gatherings`, `gathering_attendance` | Supabase defaults (ALL to `anon` and `authenticated`) | revoked from both (ADR-014 decision 14, lock-down; security-only, section R) |

Migration 001 comments say `occurred_at` immutability and P1 to P3 are enforced "in Migration 002"; Migration 002 deferred both. They land here, and the new file's header says so.

### What this slice does not need from later slices (decision F)

Slice 5 is correct without the lesson reader: submission is the Discipler's judgement about material covered together, wherever that material currently lives. Nothing from the Curriculum / Lesson Content slice has to move earlier. The only cross-slice touch is the Disciple Home's future "Read Lesson n" primary action, which stays absent until that slice.

---

## P. Discipler progression model: impact on this slice (2026-10-05)

**Confirmed rules (user, 2026-10-05), summarised.** A Disciple becomes *eligible* to be a Discipler when Lesson 5 reaches confirmed COMPLETED (IN_PROGRESS and READY_FOR_COMPLETION do not count). Eligibility never promotes. The Coordinator *appoints* an eligible Disciple as Discipler, then Disciples are *assigned*. Eligibility, appointment and assignment are three different facts. An appointed Discipler stays a Disciple and continues Lessons 6 to 12 under their own Discipler, so DISCIPLE and DISCIPLER are no longer mutually exclusive. One Discipler may have several Disciples. Journey is relationship-aware: My Journey (where I am the Disciple) and My Disciples (where I am the assigned Discipler), shown only when the relationship exists, with no global mode switch. Lesson material later opens in Workbook mode from My Journey and in Guide mode from My Disciples. Authority comes from the relationship with the person being viewed, never from holding a responsibility in general. Journey progress is factual and segmented (12 segments, completed, current, upcoming), derived from confirmed lesson states only.

**Dependency.** Eligibility needs confirmed completion, which this slice creates. Nothing in this slice needs eligibility, appointment or concurrent responsibilities. The rules are owned by **Slice 6, Discipler Progression**, directly after this one (roadmap decision 2 of 2026-10-05). Workbook and Guide modes depend on lesson content (ADR-010) and on data that does not exist yet (Guide answers, workbook responses); they belong to Slice 7 (Curriculum / Lesson Content) and Slice 8 (Workbook / Guide, ADR-013 reserved), never to this slice.

**Governing documents and database.** ADR-012 is accepted (decisions 16 and 21) and the governing documents were amended on 2026-10-05: BR-015, BR-036, BR-037, MVP sections 9 and 22, ARCHITECTURE sections 6 and 9, DC sections 2, 4 and 5, the DBML notes and RBAC section 10 state the new rules, with "enforced from Slice 6" where the database still differs. The database still differs in one place: Migration 006's `d_group_membership_disciple_conflict` refuses any overlap of DISCIPLE with DISCIPLER, and its test stays green in this slice. Slice 6's forward migration relaxes only that branch, keeps DISCIPLE versus LEADER, adds the self-pairing prohibition and keeps one active Discipler per Disciple. Migration 006 is not edited.

**What this slice does not do.**

- It does not relax the DISCIPLE / DISCIPLER exclusion. The exclusion stays enforced by Migration 006 and its tests stay green. Relaxing it needs a replacement integrity function, a self-pairing guard and an appointment operation, which together are the progression slice's migration.
- It does not compute, store or show Discipler eligibility, and adds no appointment or "Eligible for Discipler" list. Section I lists them as deferred.
- It does not change who assigns Disciples (`set_discipler()` is unchanged).
- It does not add Workbook or Guide modes, workbook responses, Guide answers or a "Continue Lesson" action.
- It does not add a church-wide motivation figure to Home (RBAC section 2b, lines 383 to 388, requires a privacy review first).

**What this slice does so the progression slice is additive, not a rework.**

1. **No new reliance on the exclusion.** The participant integrity trigger and `record_discipleship_meeting()` refuse, explicitly, a participant whose church membership is the same as the meeting's Discipler row's church membership (`cannot_record_own_meeting`). DC section 4 and BR-024 used to rely on the exclusion for this; since 2026-10-05 they state the explicit check (ADR-012), which keeps the rule true once the exclusion is relaxed. It implements the documented rule ("never self", RBAC section 5), not a new rule.
2. **Relationship-scoped helpers.** Every authority helper takes the target person and tests the caller's relationship with that person (`is_current_discipler_of(membership)`, `leads_current_group_of_disciple(membership)`), never "the caller holds DISCIPLER somewhere". Courtesy flags in `get_disciple_journey()` are computed per (caller, target). A caller who is both somebody's Disciple and somebody else's Discipler then gets no flags on their own journey and full Discipler flags on their Disciple's journey, with no extra code.
3. **The self rules are per lesson owner, not per role.** `cannot_act_on_own_lesson` compares the target membership with the caller's membership, so it holds for any combination of responsibilities.
4. **Reopen precondition 4** is built in its narrowed form (ADR-012 decision 9; N9 approved): for a person with an appointment record, the eligibility lesson and earlier lessons cannot be reopened; later lessons can, subject to preconditions 1 to 3. No appointment exists until Slice 6, so it never fires in this slice. The eligibility lesson must come from one policy point, not a literal 5, so **D2 must be answered before step 7** (section Q). If D2 is still open at step 7, the documented fallback is to stop and ask; the plan does not hard-code 5.
5. **Progress reads carry what segmented progress needs.** `get_disciple_journey()` already returns one row per lesson, from which the client derives the total (lesson count of the ACTIVE curriculum, never a literal 12), the completed count (confirmed COMPLETED only) and the current lesson; `list_disciple_progress()` returns `lessons_total` and `lessons_completed` per row so the compact form in My Disciples and in Leader and Coordinator scopes needs no extra call. READY_FOR_COMPLETION is never counted as completed.
6. **My Disciples is a list from the start** (one Discipler, several Disciples; Slice 3 decision 4; Migration 001 has no uniqueness on the Discipler side of `discipler_assignments`).
7. **Journey as one destination with relationship-derived views** (decision 20; N8 approved). In this slice's data only the single-view states are reachable (the exclusion still holds); the two-tab state is covered by unit and widget tests with constructed state, so Slice 6 only has to make it reachable.
8. **Presentation composes from relationships**, not from a role switch: Home, Profile and Journey each add a block per relationship the person has (MinistryContext already exposes `isDisciple`, `isDiscipler` and `myDisciples` additively).

**Decision 13 reversed (N7 approved, user decision 19).** A Discipler reads detailed progress only of their own currently assigned Disciples. The earlier group-wide read is withdrawn; RBAC sections 2 and 5 were amended with it. Every helper decides for the pair (caller, person viewed).

---

## A. Decisions

User decisions of 2026-10-02 are marked ✔. The rest follow from them and from the governing documents.

1. ✔ **One record per meetup, after the fact; no scheduling.** Each Disciple's outcome (Present, Late, Absent, Excused) is recorded explicitly. There is no "held" or "missed" label; a record shows each recorded outcome (ADR-014 decision 8). Record Meeting owns the attendance outcome; there is no other attendance path.
2. ✔ **Eligibility.** A Disciple's eligible lesson is the lowest-numbered lesson of the ACTIVE curriculum that is not COMPLETED; recording against a COMPLETED lesson is refused (DC section 4).
3. **Who records.** The Discipler for their own assigned Disciples; the Leader for any Discipler row in their group, and the Coordinator for any group, as fallback; `recorded_by` shows who entered it. Participants are validated against P1 to P3 as of `occurred_at`.
4. ✔ **No self-recording, self-submission or self-confirmation as a Disciple**, for anyone holding DISCIPLE, a Coordinator included.
5. **Void semantics.** Voiding a meeting does not cascade to participant rows; meeting status alone removes credit. Voiding the last RECORDED participant of a meeting is refused (`void_meeting_instead`), so a RECORDED meeting always has at least one RECORDED participant.
6. ✔ **Explicit completion (ADR-011).** No meeting count moves a lesson to READY_FOR_COMPLETION. The Discipler submits ("We have finished covering this lesson"); the Leader confirms in a dialog (decision A7). Recording continues while a lesson awaits confirmation.
7. ✔ **No monitoring in this slice.** No `CONSECUTIVE_ABSENCE` condition is created or resolved; `attention_conditions` gets no policies. The factual figures "recorded absences" and "consecutive recorded absences" are shown; no condition is implied. A recorded absence is only an explicitly recorded ABSENT outcome; EXCUSED is never an absence; no record is never an absence (ADR-014 decisions 3 to 8). The automated missed-meeting condition is withdrawn, not deferred.
8. **Episode boundaries** are not needed while monitoring is deferred. The `MONITORING HOOK` comments stay.
9. ✔ **Navigation (A5, A6, A10).** Disciple: Home, Progress, D Group, Profile. Discipler: Home, Disciples, D Group, Profile. Leader: Home, D Group, Profile, plus Disciples when they also disciple. Coordinator: Home, D Groups, Profile, plus Disciples when they also disciple. Admin only: Home, Profile. "My Group" is renamed "D Group". Membership requests leave the dock and become a Home attention tile. There is **no Leader Members tab**; "Members" is a section of D Group detail. (This replaces the earlier decision 9, "Leader gets a Members tab".) **Amended by N8 (approved 2026-10-05):** Progress and Disciples are one **Journey** destination whose views are derived from relationships (decision 20). Disciple: Home, Journey, D Group, Profile. Discipler: Home, Journey, D Group, Profile. Leader: Home, D Group, Profile, plus Journey when they also disciple. Coordinator: Home, D Groups, Profile, plus Journey when they also disciple or are a Disciple. Admin only: Home, Profile. No Attendance destination (ADR-014). UI_DESIGN_SYSTEM sections 21, 22, 60, 61 and 63 and MVP section 21 carry this since 2026-10-05.
10. **Offline.** Every new write is disabled offline and explains itself on tap. Progress is not added to the Slice 4 snapshot.
11. **Out of scope:** everything in the Discipler progression model owned by Slice 6 (eligibility derivation and display, appointment, concurrent Disciple and Discipler responsibilities in the database, the self-pairing check, the Coordinator's eligible list; section P), Curriculum, Workbook and Guide work (Slices 7 and 8), monitoring and follow-ups (Slice 9), meeting photos, scheduling, a Coordinator sequencing override, reasons on voids, the lesson reader, church-wide aggregates for non-Coordinators, "lessons completed this month" (candidate Reporting metric, Slice 11). Removed from the MVP rather than deferred (ADR-014): D Group gatherings, gathering attendance, an automated missed-meeting or inactivity condition.
12. ✔ **Co-participant privacy.** A Disciple sees only their own participant row and outcome (RBAC section 5).
13. ✔ **Discipler progress scope (N7, user decision 19; reverses the 2026-10-02 form of this decision).** A Discipler sees the detailed progress of their own currently assigned Disciples only, as with recording, voiding, submitting and meeting-record detail (RBAC sections 2 and 5). A Discipler may have several assigned Disciples. Leader: current group members. Coordinator: church-wide. Disciple: self.
14. ✔ **Seed backdating** by trusted direct update, so sample meetings carry realistic past dates.
15. **Who submits and withdraws** follows RBAC section 5: the current assigned Discipler normally submits; Leader and Coordinator may submit as fallback. Withdrawal by the assigned Discipler, the Leader ("Return to Discipler") or the Coordinator is the documented proposed default (N3).
16. **Same person submits and confirms** is allowed until N4 is decided, because a Leader who also disciples does both in normal work (BR-013).
17. **Reopen result** follows DC section 4: back to READY_FOR_COMPLETION with the original submission when the meetings still support it.
18. **Active Discipleships** (DC section 11; RBAC section 2b) appears as a Coordinator Home figure only; Leader and Discipler see the equivalent facts inside their own scope ("5 paired"). No church-wide figure for other roles.
19. **Monthly meeting indicator (A4; user decisions 10 and 11)** is in scope as a read-only history derived from recorded discipleship meeting dates. Disciple: Journey, My Journey, monthly indicator. Discipler: Journey, My Disciples, select the Disciple, monthly indicator. Leader and Coordinator reach it only inside one Disciple's detail. No manual events, no scheduling, no gathering attendance, no group-wide calendar. The UI_DESIGN_SYSTEM section 20 week strip is removed.
20. **Relationship-derived Journey views** (N8 approved; user decision 20; rules 2C to 2E of 2026-10-05). From the caller's MinistryContext (Slice 3 roster, already in the Slice 4 snapshot): *own journey* = an active DISCIPLE row; *Disciples* = active assignments where the caller's active DISCIPLER row is the Discipler side; *appointed* = an active DISCIPLER row. Journey is offered when the caller has an own journey or is appointed. Own journey and at least one Disciple: two tabs, My Journey and My Disciples. Own journey only, appointed or not: My Journey, no tab bar, and when appointed with no Disciple yet a one-line note instead of an empty tab. Disciples only: My Disciples directly. Appointed, no own journey, no Disciples: the My Disciples empty state as the whole view. No mode switch anywhere. Presentation only; every read is authorized by the server per target person.
21. **Factual segmented journey progress** (user rules 2I, 2J). One component, full and compact: one segment per lesson of the ACTIVE curriculum (completed ✓, current ●, upcoming ○), with the line "Lesson 6 of 12 · 5 lessons completed · Lesson 6 current", or "· Lesson 6 awaiting confirmation" when submitted. Only confirmed COMPLETED lessons count; READY_FOR_COMPLETION is shown as the current lesson awaiting confirmation, never as a completed segment. No percentage, no comparison, no "ahead" or "behind". The total comes from the curriculum, never a literal (BR-036). This is a factual-state presentation of BR-035, not new data. Example: "Lesson 6 of 12 / ✓ ✓ ✓ ✓ ✓ ● ○ ○ ○ ○ ○ ○ / 5 of 12 completed" (user decision 22). The meeting count never determines progress.
22. **Flexible meeting count, no automatic completion (user decision 23).** Whatever N1 decides (A no minimum, B a minimum of credited meetings, C a recommended number only), no meeting count ever completes a lesson or makes it READY_FOR_COMPLETION. The Discipler explicitly indicates the lesson is fully covered; the Leader's confirmation makes it COMPLETED.
23. **Home and Profile derive from relationships**, not from a role: a block per relationship the person has (own journey, Disciples, Leader tiles, Coordinator tiles). The architecture accepts a person who is both a Disciple and a Discipler (Slice 6) with no further change.
24. **No percentage or ratio anywhere** (user decision 8): no consistency percentage or ratio, no attendance percentage, no overall discipleship percentage. Factual lines only ("5 of 12 lessons completed", "2 consecutive recorded absences", "Last recorded meeting Sep 28").

## B. Roles in this slice

| Action | Coordinator | Leader (own group) | Discipler | Disciple |
|---|---|---|---|---|
| Read curriculum (identity, title, order) | Yes | Yes | Yes | Yes (also Member and Admin) |
| Record meeting, with each Disciple's outcome | Fallback, any group | Fallback, any Discipler in group | Own assigned Disciples | No |
| Void meeting / participant | Yes | Meetings of own group | Self-recorded under own active DISCIPLER row | No |
| Submit lesson as finished | Fallback | Fallback | Own assigned Disciples | No |
| Withdraw submission | Yes | Yes ("Return to Discipler") | Own assigned Disciples | No |
| Confirm lesson completion | Oversight | Disciples currently in own group | No | No |
| Reopen completion | Yes | No | No | No |
| View progress (journey) | Church-wide | Current group members | Own currently assigned Disciples (N7) | Self |
| View meeting history and month view | Church-wide | Meetings of own group | Meetings under own DISCIPLER row(s) (others: Contradiction O1) | Own participant rows |
| Active Discipleships figure | Church-wide | (facts in own group) | (facts for own) | No |

All authority requires the caller's own membership to be ACTIVE (RBAC section 1a). ADMIN without COORDINATOR has no meeting or progress access (ADR-004).

---

## C. The meeting-count policy point (blocker N1)

**The open question (verbatim):** "Is there a minimum number of credited meetings required before a lesson can be marked finished, or is the number only recommended / completely flexible depending on when the lesson material is actually completed?"

**Where it plugs in.** One private function, `private.lesson_meeting_policy(lesson_id)`, returning `submission_minimum int` (never below 1) and `recommended_meetings int` (nullable). Nothing else in SQL or Flutter encodes a number or reads `required_meetings`.

| Consumer | Reads |
|---|---|
| `submit_lesson_finished()` precondition | `submission_minimum` |
| `confirm_lesson_completion()` re-check | `submission_minimum` |
| void protection, COMPLETED (refuse) | `submission_minimum` |
| void effect, READY_FOR_COMPLETION (auto-withdraw) | `submission_minimum` |
| `reopen_lesson_completion()` resulting state | `submission_minimum` |
| `get_disciple_journey()` output | both values, passed through |
| Flutter `MeetingCount` ("· Typical: n") | `recommended_meetings`, shown only when not null |
| Flutter submit refusal message | `submission_minimum` from the error detail |

**Function body by model** (filled in once N1 is answered):

| Model | `submission_minimum` | `recommended_meetings` | `required_meetings` follow-up (later migration) |
|---|---|---|---|
| A, fully flexible | 1 | null | retire, or leave as unused seed data |
| B, minimum + flexible | the decided N (`required_meetings`, or a church-wide setting) | optional | rename or reinterpret as `minimum_meetings` |
| C, recommended only | 1 | the decided N | rename or reinterpret as `recommended_meetings` |

**Invariant in every model (user decision 23):** the count never completes a lesson. Submission is the Discipler's explicit statement that the material is fully covered; confirmation by the Leader makes it COMPLETED.

**What can be built before N1.** Everything in this plan. Until the answer, the function returns the floor every model shares (`submission_minimum = 1`, `recommended_meetings = null`). That is a placeholder, not a choice of Model A: the slice is **not complete** until N1 is answered and the body, its test group and the refusal wording are final (step 7 gate, section J). If N1 is answered before Migration 2 is committed, the body goes straight into it; otherwise a later migration replaces the function (and renames `required_meetings` if the answer calls for it).

---

## D. Database: one new migration

The separate enum migration planned earlier (`20261002000001_meeting_enums.sql`, adding `CONSECUTIVE_MISSED_MEETINGS`) is **no longer needed**: its only content was the value ADR-014 withdraws, and nothing else in this slice adds an enum value. The remaining rename of `meeting_participation_status` `COUNTED` → `RECORDED` uses `RENAME VALUE`, which is allowed inside the migration's transaction. Filename is a proposal; no SQL is written in this plan.

1. `supabase/migrations/20261002000001_discipleship_meeting_progress.sql`: everything below. ("Migration 2" in older text of this plan means this file.)

**Schema.**

- Rename `meeting_participation_status` `COUNTED` → `RECORDED`; column default follows.
- Guard that `discipleship_meeting_participants` is empty, then add `attendance_status attendance_status NOT NULL` with no default.
- Add `disciple_lesson_progress.submitted_by uuid` → `profiles.id`.
- Progress State Check (DC section 4): NOT_STARTED all null; IN_PROGRESS `started_at` only; READY_FOR_COMPLETION `started_at`, `ready_at`, `submitted_by`; COMPLETED all five.
- `required_meetings` is untouched.
- Indexes: `discipleship_meetings (discipler_d_group_membership_id, occurred_at, id)`, `(d_group_id, occurred_at)`, `(lesson_id)`; `discipleship_meeting_participants (church_membership_id)`.

**Grants.** Revoke all from `anon`, and INSERT, UPDATE, DELETE, TRUNCATE from `authenticated`, on the curriculum, meeting, progress, condition and follow-up tables. Only SELECT under RLS remains; `follow_ups` and `follow_up_actions` keep zero policies.

**Gathering lock-down (forward-migration treatment of ADR-014, decision 14 step 1; security-only).** In the same grant step, revoke **all** privileges on `d_group_gatherings` and `gathering_attendance` from `anon` and `authenticated`. RLS stays enabled, no policy is added, no object, trigger, enum or column is altered or dropped, and no data changes. This step belongs here because this migration already narrows Supabase default grants; it does not implement any gathering behaviour. Deprecation comments and any drop are out of scope (ADR-014 decision 14 steps 2 and 3).

**Integrity triggers** (constraint triggers, SECURITY DEFINER, schema `private`, as in 006):

| Table | Rules |
|---|---|
| `discipleship_meetings` INSERT | Discipler row is DISCIPLER of `d_group_id` and active at `occurred_at`; the lesson's curriculum belongs to the group's church |
| `discipleship_meetings` UPDATE | context columns and `created_at` immutable; RECORDED → VOIDED only, setting void metadata; VOIDED terminal |
| `discipleship_meeting_participants` INSERT | if RECORDED: P1 to P3 as of the meeting's `occurred_at`; same church; parent RECORDED; the participant's church membership is not the church membership of the meeting's Discipler row (explicit, not inferred from the DISCIPLE / DISCIPLER exclusion; section P item 1) |
| `discipleship_meeting_participants` UPDATE | `meeting_id`, `church_membership_id`, `attendance_status` immutable; RECORDED → VOIDED only |
| `disciple_lesson_progress` | lesson's church equals the membership's church |

**Policy and helpers** (`private`, SECURITY DEFINER, STABLE):

- `lesson_meeting_policy(lesson)`: section C.
- `is_active_member_of(church)`; `current_disciple_row(membership)`; `leads_current_group_of_disciple(membership)`; `is_current_discipler_of(membership)`.
- `can_view_progress_of(membership)`: Coordinator; Leader of the current group; `is_current_discipler_of(membership)` (N7; no group-wide Discipler branch); self.
- `discipler_eligibility_lesson(curriculum)`: the single policy point for the eligibility lesson, used by the narrowed reopen precondition 4 (ADR-012 decision 9). Its form depends on D2 (section Q); it is the only place the number 5 may appear.
- Every helper above tests the caller's relationship with the target membership, never "the caller holds a responsibility" in general (section P item 2).
- `can_view_meeting(meeting)` and `can_view_participant(row)`: RBAC sections 2a and 5, with Disciples limited to their own row.
- `can_void_meeting(meeting)`: Coordinator; Leader of `d_group_id`; recorder who owns that still-active Discipler row.
- `can_submit_for(membership)`, `can_withdraw_for(membership)`, `can_confirm_for(membership)`: RBAC section 5; never self.
- `credited_count(membership, lesson)`; `eligible_lesson(membership)`.

**Internal worker** (`private`, VOLATILE): `recompute_lesson_progress(membership, lesson)`. Creates the row lazily; leaves COMPLETED untouched; sets NOT_STARTED/IN_PROGRESS by credited presence and recomputes `started_at`; withdraws a READY_FOR_COMPLETION submission that falls below `submission_minimum` (clearing `ready_at`, `submitted_by`) and reports that it did; never sets READY_FOR_COMPLETION or COMPLETED.

**RPCs** (`public`, SECURITY DEFINER). Each checks authority first, locks participant memberships in id order, uses `now()` and writes one audit event.

| Operation | Who | Behaviour | Audit |
|---|---|---|---|
| `record_discipleship_meeting(discipler_dgm, lesson, occurred_at, participants jsonb, notes)` | Discipler (own row) / Leader / Coordinator | Derives `d_group_id`. Validates: not in the future; participants non-empty, distinct, explicit outcomes; Discipler row active at `occurred_at`; lesson in the ACTIVE curriculum; participants ACTIVE and not the caller; P1 to P3; every participant's eligible lesson is this lesson. Inserts, then recomputes each participant. Never changes readiness or completion. Accepted while READY_FOR_COMPLETION. | `DISCIPLESHIP_MEETING_RECORDED` |
| `void_discipleship_meeting(meeting)` | `can_void_meeting` | Must be RECORDED. Refused (`lesson_completed_protected`) if a credited participant's COMPLETED lesson would fall below `submission_minimum`. Sets VOIDED, recomputes; auto-withdrawals listed in audit metadata. | `DISCIPLESHIP_MEETING_VOIDED` |
| `void_meeting_participant(participant)` | `can_void_meeting(parent)` | Parent and row RECORDED; last RECORDED participant refused; same protection and auto-withdrawal. | `MEETING_PARTICIPANT_VOIDED` |
| `submit_lesson_finished(membership, lesson)` | `can_submit_for` | Lesson is the eligible lesson, IN_PROGRESS, credited ≥ `submission_minimum`. Sets READY_FOR_COMPLETION, `ready_at = now()`, `submitted_by`. | `LESSON_SUBMITTED_FINISHED` |
| `withdraw_lesson_submission(membership, lesson)` | `can_withdraw_for` | Requires READY_FOR_COMPLETION. Back to IN_PROGRESS; clears `ready_at`, `submitted_by`; prior values in audit. | `LESSON_SUBMISSION_WITHDRAWN` |
| `confirm_lesson_completion(membership, lesson)` | `can_confirm_for` | Requires READY_FOR_COMPLETION and credited ≥ `submission_minimum`; never self. Sets COMPLETED, `completed_at`, `confirmed_by`. | `LESSON_COMPLETION_CONFIRMED` |
| `reopen_lesson_completion(membership, lesson)` | Coordinator only | DC section 4 preconditions 1 to 4, precondition 4 in the narrowed form (ADR-012 decision 9, N9: for an appointed person, refused for the eligibility lesson and earlier; never fires before Slice 6). Resulting state from `submission_minimum`; clears `completed_at`, `confirmed_by`; prior values in audit. | `LESSON_COMPLETION_REOPENED` |
| `get_disciple_journey(membership)` | `can_view_progress_of` | One row per lesson: number, title, status, credited count, `submission_minimum`, `recommended_meetings`, `started_at`, `ready_at`, submitter name, `completed_at`, confirmer name, `is_current`, `is_locked`, and courtesy flags `can_record`, `can_submit`, `can_withdraw`, `can_confirm`, `can_reopen`, computed for the (caller, target) relationship. Journey totals (`lessons_total`, `lessons_completed`, current lesson) are derived from these rows in the client, with COMPLETED only counted. | none |
| `get_meeting_history(membership, from default null, to default null)` | per-row meeting visibility | Date, lesson, own outcome (Disciple) or outcomes, counted or not, ordinal, recorder, shared notes, statuses, `can_void`. No held or missed label (ADR-014 decision 8). The range serves the monthly indicator. | none |
| `get_disciple_meeting_summary(membership)` (was `get_disciple_consistency`) | `can_view_progress_of` | `meetings_attended`, `recorded_absences`, `excused`, `last_recorded_meeting_date`, `consecutive_recorded_absences` (factual, no condition). No ratio or percentage (decision A11, user decision 8). | none |
| `list_disciple_progress(d_group default null)` | Leader/Coordinator for a group; null = the caller's own assigned Disciples (N7; a Discipler never passes a group) | Per Disciple: name, Discipler, current lesson number, `lessons_total`, `lessons_completed` (COMPLETED only), credited count, status, submitter, last meeting, recorded absences, `is_assigned_to_me`. | none |
| `get_progress_summary()` | any ACTIVE caller, scoped per RBAC section 2b | Counts for Home: lessons awaiting the caller's confirmation; own Disciples; for Coordinator, Active Discipleships and pending requests. | none |

**Errors** follow the 006 convention:

| Code | Reasons |
|---|---|
| PT400 | `participants_required`, `duplicate_participant`, `invalid_attendance_status` |
| PT401 | `authentication_required` |
| PT403 | `not_authorized` |
| PT404 | `lesson_not_found`, `meeting_not_found`, `participant_not_found`, `progress_not_found` |
| PT409 | `occurred_at_in_future`, `discipler_not_active_at_occurred_at`, `lesson_not_in_active_curriculum`, `member_not_active`, `cannot_record_own_meeting`, `participant_not_assigned_at_occurred_at`, `lesson_not_eligible`, `meeting_not_recorded`, `participant_not_recorded`, `void_meeting_instead`, `lesson_completed_protected`, `lesson_not_in_progress`, `below_submission_minimum`, `lesson_not_submitted`, `cannot_act_on_own_lesson`, `lesson_not_completed`, `later_lesson_completed`, `eligibility_lesson_protected` (was `already_promoted`; ADR-012) |

**RLS (read-only policies).**

| Table | Coordinator | Leader | Discipler | Disciple | Member / Admin only |
|---|---|---|---|---|---|
| `curricula`, `curriculum_lessons` | own church | own church | own church | own church | own church when ACTIVE |
| `discipleship_meetings` | church-wide | own group | under own DISCIPLER row(s) | where a participant | none |
| `discipleship_meeting_participants` | via `can_view_meeting` | same | same | own rows only | none |
| `disciple_lesson_progress` | church-wide | current group members | own currently assigned Disciples (N7) | self | none |
| `d_group_gatherings`, `gathering_attendance` (deprecated, ADR-014) | none; no grants | none | none | none | none |
| `attention_conditions`, `follow_ups`, `follow_up_actions` | none | none | none | none | none |

---

## E. Flutter

### E1. Shared groundwork first (UI_DESIGN_SYSTEM section 67)

- **Move to `lib/core/widgets/`** from `lib/features/ministry/presentation/ministry_ui.dart`: `SectionHeading`, `PersonRow`, `dividedRows`, `confirmAction` (renamed `showConfirmDialog`), and `MinistryFormat.shortDate` into a core formatting file.
- **One confirmation pattern.** `pending_members_page.dart` uses the shared dialog instead of its own `showDialog`. No confirmation sheets anywhere.
- **One `EmptyState`** (title, body, optional authorised action, restricted variant) replaces `_NotAvailable`, `_NoGroups`, `_CoordinatorOnly`, `_EmptyRequests`, `_NotPlaced` and `_NotPlacedCard`.
- **`ErrorState` takes a subject** ("your D Group") and fixed wording: "We couldn't load {subject}. Check your connection and try again." It no longer accepts a message string. The seven places that pass `e.toString()` are fixed:

  | File | Subject |
  |---|---|
  | `lib/features/membership_review/presentation/pending_members_page.dart` | "membership requests" |
  | `lib/features/ministry/presentation/d_groups_page.dart` | "your church's D Groups" |
  | `lib/features/ministry/presentation/d_group_detail_page.dart` | "this D Group" |
  | `lib/features/ministry/presentation/member_picker_page.dart` | "the people you can invite" |
  | `lib/features/ministry/presentation/my_group_page.dart` | "your D Group" |
  | `lib/features/profile/presentation/edit_profile_page.dart` | "your profile" |
  | `lib/features/profile/presentation/profile_page.dart` | "your profile" |

  Known repository failures keep their mapped sentence where the page shows one inline; unknown exceptions never reach the screen as text.
- **Offline affordance.** `AppButton` and `AppTextLink` with `requiresConnection` stay tappable while offline and show "You're offline. Connect to {action}." (the action phrase is a parameter) instead of doing nothing.
- **`StatTile`** gains an optional text value and supporting line.
- **Dock (`dock_shell.dart`).** "My Group" → "D Group"; Requests removed from the dock; one Journey item per decisions 9 and 20 (N8; offered when the caller has an own journey or an active DISCIPLER row); never more than five items. The dock is computed from MinistryContext flags additively, never from a single "role".
- **Home.** Requests tile ("{n} people waiting to join") for Admin and Coordinator, opening `/members/pending`.

### E2. New `lib/features/discipleship/`

- **domain:** `CurriculumLesson`; `AttendanceOutcome` (display and the counting hint only; credit is derived by the database); `MeetingPolicy` (`submissionMinimum`, `recommendedMeetings?`); `LessonProgress` with `LessonState` (locked, notStarted, inProgress, submitted, completed) and one display rule (`5 meetings recorded`, `· Typical: n` only when present, never a fraction); `DiscipleJourney` (with derived `lessonsTotal`, `lessonsCompleted` counting COMPLETED only, and `currentLesson`); `MeetingSummary` (factual counts; was `MeetingConsistency`); `MeetingHistoryEntry`; `DiscipleProgressSummary`; `ProgressSummary`; `MeetingDraft`; `JourneyViews` (decision 20: a pure function from MinistryContext to `myJourneyOnly`, `myDisciplesOnly`, `both`, or none, plus the "appointed, no Disciple yet" note flag).
- **data:** `DiscipleshipRepository` with `DiscipleshipFailure` mapping every reason in section D to the wording in section F.
- **application:** `myJourneyProvider`, `journeyProvider(id)`, `meetingSummaryProvider(id)`, `meetingHistoryProvider(id, range)`, `myDisciplesProvider`, `groupProgressProvider(groupId)`, `progressSummaryProvider`; controllers `RecordMeetingController`, `LessonSubmissionController` (submit, withdraw), `LessonReviewController` (confirm, reopen), `MeetingVoidController`.
- **presentation:** `progress_page`, `my_disciples_page`, `disciple_detail_page`, `record_meeting_page`, `meeting_month_page`, a `choose_disciple_sheet`, and the domain components `MeetingCount`, `LessonStatusLine`, `LessonTimeline` (on `StepList`, extended with submitted and locked), `DiscipleProgressRow`, `MeetingHistoryRow`, `OutcomeSelector`, `MonthMeetingView`, `JourneyProgressBar` (decision 21; full and compact, one segment per curriculum lesson, the factual line beneath, semantics label in words). A `journey_page` hosts `progress_page` (My Journey) and `my_disciples_page` (My Disciples) as its bodies, with a tab bar only in the `both` state; the two pages are unchanged otherwise. Lesson material (Workbook and Guide) is not part of these pages; the lesson card leaves a slot for a future "Open lesson" action and nothing else.

### E3. Modified

- **`routes.dart`, `router.dart`:** `/progress`, `/disciples`, `/disciples/:membershipId`, `/disciples/:membershipId/record`, `/disciples/:membershipId/month`. `/journey` (N8) (view derived per decision 20; `?view=mine|disciples` selects a tab only in the `both` state and is ignored otherwise) replaces `/progress` and `/disciples`; `/disciples/:membershipId` and its children stay, because a Disciple's journey is opened from a relationship, not from the dock.
- **`d_group_detail_page.dart`:** Leader view leads with **Awaiting confirmation**; a **Members** section with a `DiscipleProgressRow` per Disciple; Invite a member moves from the lime primary to a secondary action (decision A8). Coordinator view keeps Invite as its primary.
- **`home_page.dart`:** per relationship, section F (blocks compose; no role switch).
- **`profile_page.dart`:** the responsibility line lists every responsibility held ("Disciple · Discipler", from MinistryContext; already additive). A person with an own journey sees one journey summary (compact `JourneyProgressBar` and its line) linking to the journey; a person with Disciples sees one ministry line ("Currently discipling Anna Cruz and Ben Lim", or "Currently discipling 3 people") linking to My Disciples. Summaries only; no second journey (UI section 63). Another person's profile follows viewer authorization as today.
- **`my_group_page.dart`, `home_page.dart` copy:** "Your Leader pairs Disciples with you" becomes "Your Leader or the Coordinator pairs Disciples with you", matching RBAC section 2 ("Assign Disciple to Discipler": Coordinator and own-group Leader).
- **`app.dart`:** the resume hook also invalidates discipleship providers.
- **Previews:** the new pages and components.

---

## F. UX (UI_DESIGN_SYSTEM sections 58 to 69)

Functionality first; the visual standard is UI_DESIGN_SYSTEM section 57 (grey page, white soft-shadow cards, pill fields with floating labels, one lime pill primary, bold title with a grey supporting line, back arrow on pushed pages). Every screen states its purpose in one line, explains its empty state, never shows raw errors, keeps the form on error, and shows success in one snackbar.

### F1. Slice UX review (section 69, before implementation)

1. **Workflow:** MVP section 2 "Discipleship Meetings with recorded outcomes → Lesson Progress"; BR-030 to BR-035.
2. **Roles and states:** Disciple, Discipler, Leader, Leader who also disciples, Coordinator (also as Leader or Discipler), Admin only, Member without a group, Pending.
3. **Real-world flow:** the pair agree a time outside the app and meet (or one does not come); afterwards the Discipler records it; when the material is covered, the Discipler marks the lesson finished; the Leader confirms when they next review. The app never plans or reminds.
4. **Information:** section B and RBAC sections 2, 2a, 2b, 5; never shown: other Disciples' outcomes to a Disciple, other Disciplers' meeting rows to a Discipler (O1), the progress of a Disciple not assigned to them to a Discipler (N7), anything ministry-related to Admin only.
5. **Actions:** section B. Record: weekly, correctable by void. Submit and withdraw: once per lesson, re-doable. Confirm: once per lesson, hard to reverse. Void and reopen: rare, protected.
6. **Derived values:** count, ordinal, last recorded meeting, recorded absences, consecutive recorded absences, lessons completed, awaiting confirmation, Active Discipleships: all DC section 11. The only manual progress step is the submission (section 64).
7. **States:** per screen, F2.
8. **Patterns:** Record Meeting is a task screen with progressive disclosure (section 60). Confirm, void and reopen use the shared dialog. Submit and withdraw are inline actions without a dialog, because each is undone by the other. Choosing a Disciple from Home uses a sheet. Journey uses sections with the current lesson expanded (accordion). No tabs, except the Journey tab bar of decision 20 (N8; UI section 60 amended 2026-10-05): two long views used separately (UI section 60's own criterion), shown only when both relationships exist, never empty.
9. **Navigation:** decisions 9 and 20; no destination duplicates another; a journey is shown in Journey, My Journey (own) and in Disciple detail opened from My Disciples (or from D Group detail for a Leader or Coordinator) only. No Attendance destination.
10. **Components:** E1 and E2.
11. **Cross-role effects:** a recorded meeting changes the Disciple's Progress, the Leader's Members lines and the Coordinator's drill-down; a submission adds to the Leader's Awaiting confirmation; a confirmation moves the Disciple's current lesson.
12. **Chore and ranking tests:** no ranking, no "behind", no consistency score, no prompt to record; sorting "longest since last meeting first" is labelled as an order.
13. **Contradictions:** section N.
14. **Order:** E1 primitives before any new screen (section J).

### F2. Screen by screen

**Progress (Disciple)**, title "My progress", purpose "Your journey through the lessons, and the meetings recorded for each."

- This is the **My Journey** view of Journey (title "Journey"; purpose unchanged), shown directly when it is the person's only relationship.
- Shows: `JourneyProgressBar` with "Lesson 4 of 12 · 3 lessons completed · Lesson 4 current" (decision 21), current lesson card (`MeetingCount`, `LessonStatusLine`), the lesson timeline (completed, current, submitted, locked), own figures (meetings attended, recorded absences, last meeting), own meeting history grouped by lesson, and "View by month".
- Actions: none, stated: "This page is read-only. Your Discipler records your meetings."
- Locked lesson: "Opens after Lesson 2 is completed." Submitted: "Finished. Your Leader will confirm it." Completed: "Completed Sep 12."
- Empty: "No meetings recorded yet. When your Discipler records your first meeting, your progress starts here." Unpaired: "You're not paired with a Discipler yet. Progress starts once you are."
- Loading: spinner in the content area on first load only. Error: "We couldn't load your progress. Check your connection and try again." Offline: "Your progress needs a connection." Restricted: not applicable (self). Success: not applicable.

**Disciples (Discipler)**, title "My Disciples", purpose "The people you disciple. Tap someone to record a meeting or see their journey."

- This is the **My Disciples** view of Journey: a tab beside My Journey when the person also has an own journey, otherwise shown directly. Always a list (several Disciples per Discipler).
- Rows (`DiscipleProgressRow`, user rule 2C): name; "Lesson 8 of 12" with the compact `JourneyProgressBar`; "7 completed · Lesson 8 current" (or "· Lesson 8 awaiting confirmation" where submitted); "Last recorded meeting Oct 1" or "No meeting recorded yet". The meeting count stays on Disciple detail. Ordered "Longest since last meeting first" (labelled).
- Primary: **Record a meeting** (one Disciple: straight to the form; several: the choose-Disciple sheet, each with their current lesson, so "same lesson" is visible first).
- Empty: "No Disciples are paired with you yet. Your Leader or the Coordinator pairs Disciples with you." This empty state appears only for a person with no own journey; a person with an own journey sees My Journey with the one-line note "You're also a Discipler. Disciples paired with you will appear here." instead of an empty tab (that state becomes reachable only in Slice 6). Restricted (not a Discipler): "This page is for Disciplers. Your Leader or the Coordinator pairs Disciples with Disciplers." Offline: rows are not cached: "Your Disciples need a connection." Error: "We couldn't load your Disciples…".

**Disciple detail (Discipler, Leader, Coordinator)**, title the person's name, purpose "Progress and meeting history for {first name}."

- `JourneyProgressBar` (full) at the top, the same component as My Journey.
- Lesson card with `MeetingCount` and what happens next: In progress: "When you've finished covering Lesson 4 together, mark it as finished." Submitted: "Marked finished by Mark Reyes on Sep 30 · Awaiting Leader confirmation." Completed: "Completed Sep 12 · confirmed by Lea Santos."
- Actions by viewer (only when the journey's courtesy flag is true):

  | Viewer | Actions |
  |---|---|
  | Assigned Discipler | **Record a meeting** (primary); "Mark Lesson n as finished" (secondary, in progress); "Withdraw" (submitted); Void on own rows |
  | Leader | **Confirm Lesson n** (primary, when submitted, dialog); "Return to Discipler" (withdraw); "Record on behalf of {Discipler}" and "Mark as finished on behalf" (secondary); Void on group rows |
  | Coordinator | Confirm (secondary, when submitted, dialog); Reopen (overflow, dialog); fallback record, submit and withdraw (secondary); Void |
  | Discipler, not assigned | cannot open Disciple detail (N7); a deep link shows the restricted state |

- Confirm dialog: "Confirm Lesson 4 for Juan? This marks Lesson 4 completed and opens Lesson 5. Only the Coordinator can reopen it." Buttons: "Confirm Lesson 4", "Cancel".
- Void dialog: "Void this meeting? It will no longer count toward Lesson 2. This can't be undone; record it again if needed."
- Reopen dialog: "Reopen Lesson 3? It returns to awaiting confirmation. Later lessons must not be completed."
- History rows (`MeetingHistoryRow`): "Meeting 3 · Present · Counted"; "Absent · Not counted · Recorded absence"; "Excused · Not counted"; voided rows greyed, "Voided by …"; recorder on each row; shared notes behind "Show notes".
- Empty history: "No meetings recorded for {first name} yet." Restricted (deep link without scope): "This page isn't available to you. Only {the person}'s Discipler, Leader and the Coordinator can open it." without confirming the person exists (use "this person"). Offline: "This page needs a connection." Success: "Meeting voided", "Lesson 4 marked as finished", "Lesson 4 confirmed for Juan", "Submission withdrawn", "Lesson 3 reopened".

**Record a meeting**, title "Record a meeting", purpose "Record what happened at a meetup, including one that didn't take place."

Lesson-centred order (UI section 25, decision C):

1. **Lesson**, shown, not chosen: "Lesson 4 · {title}". A Disciple on another lesson is listed disabled: "On Lesson 3. Record their meeting separately."
2. **Date**: today by default; no future dates ("Meetings are recorded after they happen."); a date before the pairing began shows its reason inline.
3. **Outcome per Disciple** (`OutcomeSelector`): Present, Late, Absent, Excused, with "Present and Late count toward the lesson. Absent and Excused don't." A "Nobody came" shortcut sets every outcome to Absent. The Disciple opened from is preset Present.
4. **Notes (optional)** behind "Add notes (optional)": "Shared with the Disciples in this meeting."
5. **Review line** above the button: "Records a Lesson 4 meeting on Oct 1 · counts for Diana" or, when nobody came, "Records a Lesson 4 meeting on Oct 1 · Diana: Absent, doesn't count".
6. Primary **Record meeting**. Success: snackbar "Meeting recorded for Diana Cruz", back to detail showing the new count.

Absent and Excused rows never show an ordinal and never change the count. Empty (no eligible Disciple): "No Disciples can be recorded together for this lesson." Offline: the button explains itself on tap. The form keeps every value on error.

**Meetings by month (read-only monthly indicator)**, title "Meetings by month", purpose "Meetings recorded for {first name}, by the date they took place."

- Month switcher (previous and next only, never beyond the current month). Each recorded date shows its outcome: "Meeting · Present", "Recorded absence". Dates without a record are plain.
- No create action, no planning, no warning styling of blank dates. Empty: "No meetings recorded in September." Entry: Disciple through Journey, My Journey; Discipler through Journey, My Disciples, the Disciple; Leader and Coordinator only from inside one Disciple's detail. No group-wide calendar, no scheduling (user decisions 10, 11).

**D Group detail additions (Leader; Coordinator)**

- Leader order: **Awaiting confirmation** ("2 lessons are waiting for you", each "Lesson 4 · Juan · marked finished by Mark", with Confirm opening the dialog; empty: "Nothing to confirm right now."), then **Members** with progress rows, then Disciplers, Invitations, and Invite a member as a secondary action.
- Group facts line: "6 Disciples · 5 paired · 2 awaiting confirmation".

**Home**

Home composes one block per relationship the person has (user rule 2L), in this order, with no role switch:

- Own journey ("Your journey"): compact `JourneyProgressBar`, current lesson card ("Lesson 4 · 3 meetings recorded", Discipler name), "See my journey". A Disciple-only person sees only this block and their D Group line.
- Disciples ("Your discipleships"): rows for up to three in the compact row format, "See all", primary **Record a meeting**. Shown only when at least one Disciple is paired.
- Neither block shows Discipler eligibility, an appointment prompt or a church-wide figure in this slice (section P).
- Leader: tile "{n} lessons awaiting your confirmation" first (opens D Group detail at that section), then Members summary. No scheduling control.
- Coordinator: tiles "{n} people waiting to join", "{n} not in a D Group" (lands on that list), "{n} active discipleships", then D Groups.
- Admin only: "{n} people waiting to join".
- Each tile's figure is in words for screen readers. Offline: tiles not in the snapshot read "Needs a connection".

### F3. Error reasons and messages

Generic fallbacks: network ("You're offline or the connection dropped. Try again."), "You are not allowed to do that.", "Please sign in again to continue."

| Reason | Message shown |
|---|---|
| `participants_required` | Choose at least one Disciple for this meeting. |
| `duplicate_participant` | Each Disciple can be added once. Remove the duplicate and try again. |
| `invalid_attendance_status` | Choose Present, Late, Absent or Excused for each Disciple. |
| `occurred_at_in_future` | That date is in the future. Meetings are recorded after they happen. |
| `discipler_not_active_at_occurred_at` | You weren't this group's Discipler on that date. Choose a date since you started. |
| `participant_not_assigned_at_occurred_at` | {Name} wasn't paired with this Discipler on that date. Choose a later date, or record without them. |
| `lesson_not_eligible` | {Name} is on Lesson {n}. Lessons are recorded in order, one at a time. |
| `lesson_not_in_active_curriculum` | That lesson isn't part of your church's current curriculum. |
| `member_not_active` | {Name} is no longer an active member, so meetings can't be recorded for them. |
| `cannot_record_own_meeting` | You can't record a meeting you took part in as a Disciple. Ask your Discipler or Leader. |
| `meeting_not_recorded` / `participant_not_recorded` | This was already voided. Refresh to see the latest. |
| `void_meeting_instead` | This is the only person in the meeting. Void the whole meeting instead. |
| `lesson_completed_protected` | Voiding this would leave {Name}'s completed Lesson {n} without the meetings it was confirmed on. Ask the Coordinator to reopen the lesson first. |
| `lesson_not_in_progress` | Lesson {n} has no counted meeting yet, so it can't be marked finished. |
| `below_submission_minimum` | Lesson {n} needs at least {min} counted meetings before it can be marked finished. It has {count}. (Reachable only if N1 sets a minimum above 1.) |
| `lesson_not_submitted` | Lesson {n} isn't marked finished, so there's nothing to confirm or withdraw. Refresh to see the latest. |
| `cannot_act_on_own_lesson` | You can't mark, confirm or withdraw your own lesson. Another Leader or the Coordinator can. |
| `lesson_not_completed` | Lesson {n} isn't completed, so there's nothing to reopen. |
| `later_lesson_completed` | A later lesson is already completed. Reopen lessons from the latest one back. |
| `eligibility_lesson_protected` | {Name} has been appointed as a Discipler, so Lesson {n} and earlier lessons can't be reopened. Later lessons can. |
| `not_authorized` | You can't do that for this person. Ask their Leader or the Coordinator. |
| `*_not_found` | We couldn't find that anymore. It may have been changed. Refresh and try again. |

Load failures use `ErrorState` with the screen's subject; offline shows the offline message instead.

---

## G. Seed

Extend `supabase/seed.sql` after the Slice 3 structure.

Seed today pairs only disciple1 (`seed.sql`: disciple2 is "Disciple, not paired"). This slice also pairs disciple2 with the Discipler through `set_discipler()`, so the Leader has a submission to confirm; member@ stays unplaced.

Before recording, backdate the disciple1 and disciple2 DISCIPLE rows, the Discipler's row and both assignments to 60 days ago, by trusted direct update ✔. Then, acting as the Discipler through the RPCs:

1. **disciple1, Lesson 1:** five credited meetings (one LATE) and one ABSENT; the Discipler submits it as finished; the Leader confirms it.
2. **disciple1, Lesson 2:** two credited meetings, then three ABSENT in a row, not submitted. It shows In progress. **No condition is raised** (decision 7); the journey shows "3 consecutive recorded absences" as a fact.
3. **disciple2, Lesson 1:** six credited meetings, submitted as finished and left READY_FOR_COMPLETION for manual confirmation.

The submitted lessons carry five and six credited meetings so the seed stays valid under any minimum up to five (N1). Document the resulting states in `config/README.md`.

No seed person reaches Lesson 5 in this slice. The progression slice adds a Disciple with Lesson 5 confirmed (eligible), one appointed Discipler who is still a Disciple, and a Disciple paired with them.

## H. Tests

**Integration.** Cleanup order gains, in front of the existing chain: participants → meetings → progress. Fixture helpers: `placePairedDisciple(since:)` (backdating through the service role), `recordMeeting(...)`, `submitLesson(...)`.

| File | Covers |
|---|---|
| `discipleship_meeting_test.dart` | recording with every outcome (including all Absent and all Excused) and the credit table; NOT_STARTED → IN_PROGRESS on first credited only; **no count ever produces READY_FOR_COMPLETION** (record 8 credited meetings, status stays IN_PROGRESS); `started_at` after a backdated entry; ordinal; small-group independent outcomes; mixed lessons refused; sequential refusal; recording accepted while READY_FOR_COMPLETION and the submission kept; void and re-record; last-participant refusal; fallback recording (`recorded_by`); audit rows |
| `lesson_completion_test.dart` | submit by assigned Discipler, by Leader and Coordinator fallback; submit refused when NOT_STARTED, when not the eligible lesson, twice; withdraw by each permitted role; confirm by Leader and Coordinator, refused unless submitted; same person submits and confirms (Leader who disciples) allowed; next lesson becomes eligible after confirm; COMPLETED protection against the policy minimum; auto-withdrawal when a void leaves a submission below the minimum; reopen preconditions and resulting state (READY with the submission retained) |
| `meeting_policy_test.dart` | the policy group: `submission_minimum` never below 1; consumers read the function, not `required_meetings` (changing `required_meetings` in a test fixture changes nothing until the policy says so); model-specific cases added when N1 is decided |
| `discipleship_reads_test.dart` | journey, history (with month range), meeting summary, list and summary values match DC section 11; no ratio or percentage returned; no "missed" label; courtesy flags per viewer; `lessons_completed` counts COMPLETED only (a READY_FOR_COMPLETION lesson is not counted) and `lessons_total` equals the ACTIVE curriculum's lesson count; one Discipler with two paired Disciples gets two rows from `list_disciple_progress(null)` |
| `discipleship_security_test.dart` | negatives per RPC and table: another church; Leader outside their group or reopening; Discipler on an unassigned Disciple (record, void, submit, withdraw), on a Leader-recorded void, after their row ended, reading other Disciplers' meeting rows, confirming; Discipler reading progress of a Disciple in their group who is not assigned to them (refused, N7); Disciple writing anything or reading others, and reading a co-participant's row; a Coordinator who is a Disciple acting on their own lesson; Member and Admin only see curriculum only; PENDING sees nothing; anon; direct table writes; an INACTIVE caller; `anon` and `authenticated` can neither read nor write `d_group_gatherings` or `gathering_attendance` (ADR-014 lock-down) |
| `discipleship_integrity_test.dart` | service-role writes rejected: P1 to P3; Discipler not active at `occurred_at`; cross-church lesson or progress; immutable columns; VOIDED → RECORDED; the progress State Check, including READY_FOR_COMPLETION without `submitted_by`. The explicit "participant is not the Discipler's own person" predicate (section P item 1) cannot be reached while Migration 006's exclusion holds; its test is written in the progression slice, which makes the state constructible |

Existing tests that encode the old exclusion stay unchanged and green in this slice: `test/integration/ministry_integrity_test.dart` "DISCIPLE cannot coexist with DISCIPLER or LEADER" (line 92). The progression slice splits it (DISCIPLER half inverted, LEADER half kept).

**Unit.** `LessonState` display rule (never a fraction; typical shown only when present); outcome counting hint; `MeetingPolicy` handling of null recommendation; `fromMap` for every domain type; `MeetingDraft` validation; failure mapping (every reason maps to a non-generic sentence); `dockItemsFor` per role and combination (never more than five, no Requests, "D Group" label); route patterns; `ErrorState` subject wording; `DiscipleJourney` totals (completed counts COMPLETED only; submitted is current, not completed; total from the lesson rows); `JourneyViews` for every state of decision 20 (Disciple only; Disciple and appointed without Disciples, with the note flag; Disciple with Disciples; Discipler with Disciples and no own journey; Discipler with neither; Leader or Coordinator who also disciples; none), built from constructed MinistryContext values because the combined states are not yet reachable in the database.

**Widget.** Progress timeline; `JourneyProgressBar` full and compact (segment states ✓ ● ○, submitted lesson shown as current with "awaiting confirmation", no percentage text, semantics label in words, a curriculum of other than 12 lessons renders that many segments); Journey shows no tab bar in single-view states and two tabs only in the `both` state, and the appointed-without-Disciples note; `MeetingCount` with and without a typical number and at counts above it (no warning style); record form (lesson fixed, future date blocked, "Nobody came" preset, review line, Absent rows without ordinal); Disciple detail actions per viewer from the courtesy flags; confirm dialog text and that confirm is not sent without it; submit and withdraw inline without a dialog; history rows; month view (blank dates plain, no create action); dock items; Home tiles per role; offline: Record, Mark finished, Withdraw, Confirm, Reopen and Void explain themselves on tap; every empty state and every failure reason renders its F2/F3 sentence; the seven `ErrorState` call sites show their subject and never exception text; shared `EmptyState` and confirmation dialog used by the migrated pages.

## I. Deferred

| Item | Stopgap |
|---|---|
| Consecutive recorded absence monitoring (`CONSECUTIVE_ABSENCE`, ADR-014) and follow-ups | factual recorded absences and last recorded meeting date. Owner: Slice 9 |
| Follow-ups | none; they depend on monitoring |
| D Group gatherings and gathering attendance | not deferred: removed from the MVP (ADR-014). Grants locked down in this slice (section R) |
| Discipler eligibility (Lesson 5 confirmed), the Coordinator's "Eligible for Discipler" list, appointment, concurrent Disciple and Discipler responsibilities, person view with Own Journey and Ministry Responsibilities (section P) | the journey shows completed lessons factually; no eligibility wording. Owner: Discipler Progression slice, after ADR-012 |
| Workbook mode, Guide mode, Guide answers, workbook responses | none; lesson card keeps a slot for "Open lesson". Owner: Curriculum / Lesson Content slice and a follow-on, after a Workbook / Guide ADR |
| Church-wide motivation on Home (user rule 2L) | none; RBAC section 2b privacy review first (D15, Slice 11) |
| Lesson reader and offline content (ADR-010) | lesson titles only |
| Church-wide aggregates for non-Coordinators | none; privacy review required |
| Progress in the offline snapshot | progress screens show "needs a connection" |
| Threshold settings UI | `consecutive_absence_threshold` seeded at 3 (Slice 9) |
| Inactivity or missed-meeting condition | not deferred: withdrawn (ADR-014 decision 4). The last recorded meeting date stays a displayed fact |
| "Lessons completed this month" | candidate Reporting / Oversight metric (Slice 11): needs a definition, the counting timestamp, church time zone, privacy review and small-population suppression (user decision 9) |

## J. Implementation order

Each step lands its migration, Flutter and tests together; existing tests stay green.

0. **Before step 1:** done 2026-10-05: N8 approved and UI_DESIGN_SYSTEM sections 20 to 22, 60 to 63 and MVP section 21 amended; ADR-012 and ADR-014 accepted. Re-read those sections before step 1.
1. **Shared UI groundwork (no database):** E1 in full, including the seven `ErrorState` fixes, the offline affordance, the core moves, `EmptyState`, the single confirmation dialog, the dock and Home Requests changes, with their widget tests.
2. **Schema:** the migration skeleton (rename, `attendance_status`, `submitted_by`, State Check, grants including the gathering lock-down of section R, indexes); no enum migration; test cleanup and fixtures; integrity triggers and their tests.
3. **Policy point and access:** `lesson_meeting_policy` with the placeholder floor; helpers; RLS policies; curriculum read; table-policy security cases; `meeting_policy_test.dart` floor cases.
4. **Recording:** `record_discipleship_meeting` and `recompute_lesson_progress`; Record a meeting; My Disciples; the read-only parts of Disciple detail.
5. **Reads and journey:** read RPCs; Progress page (My Journey); `JourneyProgressBar`, `LessonTimeline`, `MeetingCount`, `LessonStatusLine`; `JourneyViews` and the Journey host page; dock entries; Home per relationship; Profile responsibilities, journey summary and ministry line.
6. **Voids:** both void operations with COMPLETED protection and auto-withdrawal; void UI with the shared dialog.
7. **Submission and confirmation:** submit, withdraw, confirm, reopen; lesson card actions; Awaiting confirmation on D Group detail; Leader Home tile; confirm dialog. **Gate N1:** before this step is closed, the policy body, its test group and the `below_submission_minimum` wording are final. **Gate D2:** before reopen is built, D2 is answered and `discipler_eligibility_lesson` exists; reopen precondition 4 in the narrowed form (N9).
8. **Members progress:** the Leader and Coordinator Members section of D Group detail and the assigned-Disciple branch of `can_view_progress_of` (N7), with security tests including the refused unassigned read.
9. **Monthly view:** history range read and `MonthMeetingView`.
10. **Wrap-up:** seed; DBML migration notes; DC and RBAC "as built" notes; full suites, format, analyze; the role walkthrough (section 69).

## K. Verification

1. **Automated:** `flutter analyze`; `dart format --output=none --set-exit-if-changed .`; `flutter test`; the integration suite with `--dart-define-from-file=config/test.json test/integration`.
2. **Migrations:** 001 to 006 byte-identical to HEAD.
3. **Search checks:** no `required_meetings` reference in `lib/` or in any SQL outside the policy function; no `e.toString()` passed to `ErrorState`; no "/ " meeting fraction in UI strings; no "missed" wording and no "%" in discipleship UI strings; no `CONSECUTIVE_MISSED_MEETINGS` anywhere; `anon` and `authenticated` hold no privilege on `d_group_gatherings` and `gathering_attendance`.
4. **Role walkthrough** (`npx supabase db reset`, then the app), written in the first person per section 69:
   - **Discipler:** record a meeting with Present and one with Absent; the count changes only for the Present one, and the Absent one shows as a recorded absence; mark Lesson 1 finished for the in-progress Disciple, withdraw, mark again; void own record; no Void on a Leader-recorded meeting; offline taps explain themselves.
   - **Leader:** Home shows the awaiting tile; confirm disciple2's Lesson 1 through the dialog; "Return to Discipler" on a submission; Members rows factual, no ranking; Invite is secondary; fallback recording.
   - **Coordinator:** requests and active-discipleships tiles; reopen a lesson (back to awaiting confirmation); refused on an earlier lesson when a later one is completed.
   - **Journey:** as disciple1 the dock shows Journey and it opens My Journey with no tab bar; as the Discipler it opens My Disciples with two rows (disciple1, disciple2) in the "Lesson n of 12 · k completed" format; as the Leader without a DISCIPLER row there is no Journey item.
   - **disciple1:** Progress shows the segmented progress ("Lesson 2 of 12 · 1 lesson completed · Lesson 2 current"), the timeline, "3 consecutive recorded absences" as a fact with no attention styling, history with own rows only, month view with blank dates plain; no actions.
   - **Admin only:** Home shows requests only; no progress anywhere.
   - **Deep link:** `/disciples/<other id>` as a Disciple shows the restricted state.
5. **Android:** a smoke test on the emulator or a USB phone.

---

## L. UX changes in this reissue (summary)

Leader Members tab replaced by the D Group destination; Requests moved to Home; "My Group" renamed "D Group"; meeting progress as a count; explicit submission and confirmation dialog; monthly view; factual wording for absences; shared primitives and error fixes first. Amendment 2026-10-05: factual segmented journey progress; My Disciples rows as "Lesson n of N · k completed"; Home and Profile composed per relationship; single Journey destination with relationship-derived views (N8). Second amendment 2026-10-05: no gatherings, no missed-meeting wording ("recorded absences"), no percentages, read-only monthly indicator with relationship entry paths, Discipler progress limited to assigned Disciples (N7), no enum migration, gathering grants locked down.

## M. Decisions needed

| # | Decision | Blocks | Proposed default / status |
|---|---|---|---|
| N1 | Minimum credited meetings before a lesson can be marked finished: Model A, B or C (section C) | Closing step 7 and the slice | none; placeholder floor until answered. In every model the count never completes a lesson (decision 22) |
| D2 | Where the eligibility lesson ("Lesson 5") is defined (section Q) | | **Resolved 2026-10-05: one policy function**, `private.discipler_eligibility_lesson()`, returning 5; not configurable per church (section S) |
| N2 | If Model B: per lesson (from `required_meetings`) or one church-wide value | the policy body | per lesson |
| N3 | Who may withdraw a submission | nothing (default built) | assigned Discipler, Leader, Coordinator |
| N4 | Must submission and confirmation be different people? | nothing (default built) | no, both attributed |
| N5 | May a Discipler read meeting records of Disciples assigned to another Discipler in their group (O1)? | nothing (restrictive default built) | no. N7 already limits progress reads to assigned Disciples |
| N6 | ADR-009 missed-meeting condition | | **Resolved 2026-10-05: withdrawn, not deferred** (ADR-014) |
| N7 | Discipler progress scope | | **Resolved 2026-10-05: own assigned Disciples only** (user decision 19; decision 13) |
| N8 | One Journey destination with relationship-derived views | | **Resolved 2026-10-05: approved** (user decision 20; UI section 60 tab rule narrowly amended) |
| N9 | Accept ADR-012 before the Slice 5 work that depends on it | | **Resolved 2026-10-05: accepted** (user decision 21). Narrowed reopen precondition built in step 7, subject to D2 |

## N. Contradictions (reported)

- **O1 Discipler meeting visibility.** RBAC section 2a's meeting-context branch versus sections 2 and 5. Unresolved; the plan follows sections 2 and 5. N7 narrows progress reads only, not meeting reads.
- **O2 "No active Leader" fallback.** DC section 4, BR-033 and RBAC justify Coordinator confirmation "where a D Group has no active Leader", which DC section 2 Leader Presence now prevents. Rationale only; does not block.
- **O3 Stale Migration 001 comments** about Migration 002. Addressed by the new file header.
- **O4 Recording after submission.** The Director's wording "recording continues on the current lesson until it is submitted as finished" can be read as stopping recording after submission. The documents keep BR-032 (meetings may continue while awaiting confirmation). Confirm with the Director.
- **O5 Concurrent Disciple and Discipler.** Resolved in the documents by ADR-012 (2026-10-05). The database still refuses the combination (Migration 006) until Slice 6; this slice keeps that test green.
- **O6 Eligibility at Lesson 5 versus every lesson.** Resolved by ADR-012. This slice implements no eligibility; only the reopen precondition depends on it (D2).
- **O7 Journey tabs versus "no tabs".** Resolved by N8 and the UI section 60 amendment.
- **O8 Church motivation on Home.** User rule 2L versus RBAC section 2b. Still open as D15 (Reporting, Slice 11). This slice shows none.
- **O9 Discipler progress scope.** Resolved by N7.
- **O10 Migration 004 column comment.** `church_settings.consecutive_missed_meeting_threshold` carries a database comment naming the withdrawn `CONSECUTIVE_MISSED_MEETINGS` condition. Documents mark the column dormant (ADR-014 decision 13); the comment can only change in a forward migration. Not part of this slice unless the user adds it.

## Q. Open D decisions (from the progression audit), classified 2026-10-05

Already decided, for reference: D1 (roadmap, user decision 2: Discipler Progression is Slice 6); D3 (same D Group, ADR-012 decision 3); D4 (direct appointment, no acceptance, ADR-012 decision 2); D12 (the assigned Discipler does not see private workbook responses by default, user decision 17). D10 (eligibility shown to the Coordinator only at first) was reported as approved in the gathering-removal reconciliation of 2026-10-05 but is not in the user's decision list of that date; confirm.

### D2, required before Slice 5 step 7

**Question.** "Where is 'Lesson 5' defined: one policy function, a `curricula` column, or a church setting?"

**Answered 2026-10-05 (third):** option A, one policy function. The eligibility lesson is a ministry policy, not a church setting; callers depend on the function and never encode the number. See section S.

**Why Slice 5 depends on it.** N9 is approved, so step 7 builds reopen precondition 4 in its narrowed form: for an appointed person, the eligibility lesson and earlier lessons cannot be reopened (ADR-012 decision 9; DC section 4). That predicate must name the eligibility lesson. Writing a literal 5 into `reopen_lesson_completion()` would contradict BR-036's principle that curriculum facts live in one place, and Slice 6's eligibility derivation must read the same source. Nothing else in Slice 5 needs D2.

**Proposed default.** One trusted policy function, `private.discipler_eligibility_lesson(curriculum)`, returning 5 for the MVP curriculum, built in the Slice 5 migration and reused by Slice 6. A column later only if the ministry wants the lesson configurable.

| Option | Consequences |
|---|---|
| A. Policy function (default) | No schema change. Same pattern as ADR-011's meeting policy. One place to change; a change needs a forward migration replacing the function. The value cannot differ per curriculum without that migration |
| B. Column on `curricula` (for example the eligibility lesson number) | Schema change in the Slice 5 migration, DBML and DC updates, seed value for the ACTIVE curriculum, a check that the number exists in that curriculum. Configurable per curriculum version, but the MVP has no write path for it (seed or migration only), so the practical difference from A is small now |
| C. Column on `church_settings` | Configurable per church, but detached from the curriculum: a curriculum with different numbering silently changes the meaning. Bootstrap (Migration 004) would need to set it explicitly or rely on a default; the postcondition assertion does not cover it. Weakest coupling |
| D. Decide later; build precondition 4 in the broad documented form (refuse any reopen after appointment) and let Slice 6 replace it | Unblocks step 7 without D2, and it never fires in Slice 5 (no appointments exist). But it builds a rule the governing documents no longer state (DC section 4 now carries the narrowed form), contradicts the approved N9 intent, and guarantees rework in Slice 6 |

### Other D decisions

Classes: A blocks Slice 5; B blocks Slice 6; C blocks Curriculum / Workbook (Slices 7 and 8); D blocks Monitoring (Slice 9); E blocks Reporting (Slice 11); F deferrable. None is decided here.

| # | Class | Exact question | Proposed default | Affected governing rule | Owning slice | Consequence of deferring |
|---|---|---|---|---|---|---|
| D5 | B | "Can the Coordinator appoint someone not yet eligible (exception)?" | No; the existing invitation path remains for unplaced, non-journey members | ADR-012 decisions 1 and 2; BR-036, BR-037; DC section 5 preconditions | 6 | Slice 6 cannot finalise the appointment preconditions or their tests |
| D6 | B | "Does the Leader keep pairing authority for appointed Disciplers, or only the Coordinator?" | Leader keeps it (RBAC section 2 "Assign Disciple to Discipler" unchanged) | RBAC section 2 and section 10 `set_discipler()`; BR-014 | 6 | Nothing breaks: today's rule (Coordinator and own-group Leader) continues; Slice 6 copy and tests assume it |
| D7 | B | "Refuse reciprocal pairing (A disciples B while B disciples A)?" | Refuse (user: to be decided) | ADR-012 open questions; DC section 2 assignment integrity; DBML `discipler_assignments` note | 6 | The Slice 6 assignment integrity function cannot be finished; if left open at Slice 6, reciprocal pairs become possible |
| D8 | B | "Can an eligible person whose DISCIPLE row has ended (removed, or journey finished) be appointed?" | Not through appointment; through the existing invitation as Discipler | DC section 5 preconditions; RBAC section 10 | 6 | Slice 6 preconditions incomplete for that case |
| D9 | B | "May a Coordinator who is a Disciple appoint themselves?" | No (self rule) | DC section 5; RBAC section 5 self rules | 6 | Slice 6 cannot finish the appointment authority check |
| D11 | F | "Default tab when both My Journey and My Disciples exist" | My Journey, remembered per device | UI_DESIGN_SYSTEM sections 21, 22, 60; decision 20 | 5 builds the default; the state is reachable from 6 | None until Slice 6 makes the state reachable; the default is a presentation choice changed in one place |
| D13 | C | "Guide content read scope" (exact rule) | Current assigned Discipler for lessons their Disciples are on or have completed; Leader of the group; Coordinator | ADR-010 decision 12; ADR-013 (reserved); RBAC sections 2 and 5 | 8 (with 7) | Guide content cannot be published securely; Workbook / Guide slice blocked |
| D14 | B (and C) | "May a Disciple-Discipler conduct (and see the Guide for) a lesson they have not yet completed themselves?" | Allowed, not enforced; confirm with the Director | ADR-012 decision 5; RBAC recording authority; ADR-013 Guide scope | 6 (recording), 8 (Guide) | Slice 6 makes the state possible with no rule; recording stays allowed by default |
| D15 | E | "Church-wide motivation on Home: what figure, and does it pass the RBAC section 2b privacy review?" | None until reviewed. "Lessons completed this month" is the candidate (user decision 9) | RBAC section 2b; DC section 11; MVP Home | 11 | No church-wide figure on Home; nothing else affected |
| D16 | F | "What happens to the DISCIPLE responsibility after the final lesson is confirmed?" | Stays until a Leader or Coordinator ends it explicitly ("journey completed"); never automatic | BR-036, BR-037; DC section 11 Active Discipleships; ADR-012 decision 4 | 6 or 11 | Slice 5 shows "12 of 12 completed" with no current lesson and ends nothing automatically, which matches the default; Active Discipleships wording and Reporting definitions wait |
| D17 | C | "Must workbook responses be answerable offline?" | No; online-only, consistent with ADR-010 decision 10 | ADR-010 decision 10; ADR-013 (reserved) | 8 | Workbook responses cannot be specified |

Counts: A 0 (D2 is required before step 7 and listed separately); B 6 (D5, D6, D7, D8, D9, D14); C 2 (D13, D17); D 0; E 1 (D15); F 2 (D11, D16).

## R. Gatherings removed: impact on this slice (ADR-014)

- No dependency on gatherings or gathering attendance anywhere in this slice. Attendance is only the per-Disciple outcome in Record Meeting.
- No enum change: `CONSECUTIVE_MISSED_MEETINGS` is withdrawn and `CONSECUTIVE_ABSENCE` keeps its name with the new meaning. The separate enum migration is dropped (section D).
- `attendance_status` is used with all four values (Present, Late credited; Absent a recorded absence; Excused neither credited nor an absence).
- Terminology: "recorded absences", "consecutive recorded absences", "Last recorded meeting". No "missed meeting", "missed meetup" or "meetups missed"; no held or missed labels.
- Gathering grants: locked down in this slice's grant step as the forward-migration treatment of ADR-014 decision 14 (security-only; section D). Deprecation comments and any drop are not part of this slice.
- Thresholds: neither is read in this slice. `consecutive_absence_threshold` is the Slice 9 threshold; `consecutive_missed_meeting_threshold` stays dormant (O10).
- The monthly indicator is history from recorded meeting dates only; the week strip is gone (UI section 20).

## S. Final decisions before implementation (user, 2026-10-05, third)

1. **Documentation approved** and committed before step 1. ADR-012 and ADR-014 accepted as written; ADR-013 stays reserved for Slices 7 and 8.
2. **D2: one policy function.** `private.discipler_eligibility_lesson()` returns the eligibility lesson number (5). It takes no church or curriculum argument and reads no setting: the rule is ministry policy, not configuration. No other SQL or Dart encodes the number.
3. **Consecutive recorded absence threshold = 3.** `church_settings.consecutive_absence_threshold` keeps its seeded value 3 and means 3 consecutive explicitly recorded ABSENT outcomes. "2 consecutive recorded absences" in earlier text was wording, not a threshold. NO RECORD is never ABSENT; EXCUSED is never ABSENT. The threshold is not read in this slice (Slice 9).
4. **Follow-up branches.** The Leader and Discipler branches stay documented and inactive. No trigger is fabricated, no missed meeting or inactivity is inferred. Slice 9 owns them.
5. **N1 (minimum meetings) stays open.** Every step that does not depend on it proceeds. When step 7 reaches the exact point where submission needs the policy body, only that part stops and the decision is surfaced. Meeting count never completes a lesson in any model.
6. **Remaining contradictions** are handled only when the owning step needs them:
   - Migration 004 comment (O10): not edited.
   - Inactive D Group behaviour: deferred unless a Slice 5 step needs a restriction.
   - "Last recorded meeting": where the UI says "Last recorded meeting" it means the latest recorded meeting, not the latest credited one. If the read built in step 5 would differ, that step flags it narrowly.
   - O1: least-privilege, relationship-scoped meeting access; no broadening.
   - "D Group health": factual states only, no health score.
   - Workbook responses: Slice 8. Guide authorization (ADR-010 versus ADR-013): Slices 7 and 8.
   - D10: deferred unless a step depends on it.
   - The two remaining user-facing gathering strings are removed when their UI is touched.
7. **Curriculum source.** The ministry has supplied the curriculum as a PDF containing 10 complete lessons. It is not processed in this slice. The 12-lesson assumption is **not** changed now: Slice 7 inspects the PDF and reconciles whether the curriculum is 10 lessons, the PDF is part of a larger one, or the 12-lesson assumption is obsolete. Nothing here hard-codes a lesson total: every total comes from the ACTIVE curriculum.
8. **After the MVP:** a separate Production / Release Readiness milestone (website, privacy policy, terms, account deletion, support, legal links, production security review, store assets, signing, submission). Not part of any slice.

## T. Decisions of 2026-10-05 (fourth): Discipler completes lessons, calendar history

Recorded in [ADR-015](../adr/ADR-015-discipler-marks-lesson-completed.md); the governing documents carry the rules (revision 2026-10-05, ADR-015). Where earlier sections of this plan describe submission, withdrawal, Leader confirmation, "awaiting confirmation" or a reopen back to READY_FOR_COMPLETION, this section supersedes them. Earlier sections are not rewritten.

1. **One explicit step.** The Disciple's current assigned Discipler marks the lesson completed ("Mark Lesson n completed"). It is COMPLETED immediately and the next lesson becomes current for every role. No Leader confirmation, no "awaiting confirmation" state.
2. **Fallback.** The Leader of the Disciple's current D Group and the Coordinator may mark it completed on the Discipler's behalf. Nobody marks their own lesson.
3. **Preconditions.** Eligible (current) lesson; IN_PROGRESS; credited meetings >= `submission_minimum` at the moment of marking completed. N1 still decides the value. The count never completes a lesson.
4. **Storage, no schema change.** `complete_lesson()` sets COMPLETED, `completed_at = now()`, `confirmed_by` = caller, `ready_at = completed_at`, `submitted_by` = caller. The Progress State Check is unchanged. READY_FOR_COMPLETION stays in the enum; nothing enters it.
5. **Undo.** `undo_lesson_completion()`: current assigned Discipler, Leader of the current group or Coordinator; only while (a) it is the latest COMPLETED lesson and (b) no RECORDED participant row in a RECORDED meeting exists for the person on the next lesson. Back to IN_PROGRESS (NOT_STARTED with no credited meeting); clears `ready_at`, `submitted_by`, `completed_at`, `confirmed_by`; audited with the prior values. Self rule applies. From Slice 6 the narrowed eligibility-lesson protection (ADR-012 decision 9) also applies.
6. **Reopen.** After the window, Coordinator only, through `reopen_lesson_completion()` with unchanged preconditions 1 to 4. Result: IN_PROGRESS, or NOT_STARTED when no credited meeting remains; never READY_FOR_COMPLETION.
7. **Withdrawn.** `withdraw_lesson_submission()` and `confirm_lesson_completion()` are not built. `submit_lesson_finished()` is replaced by `complete_lesson()`. The Leader's Awaiting confirmation section and the "lessons awaiting your confirmation" Home tile are withdrawn.
8. **Voids.** COMPLETED protection unchanged. The READY_FOR_COMPLETION auto-withdrawal is dormant, because nothing enters that state; it stays documented rather than deleted.
9. **Eligibility.** Lesson 5 COMPLETED still creates eligibility; "confirmed COMPLETED" becomes "COMPLETED". The Coordinator's appointment is the human check.
10. **UI and history.** UI_DESIGN_SYSTEM.md is set aside for now: where it differs, implementation uses standard Material 3 Flutter patterns. The meeting history on Disciple detail and My Journey becomes a month calendar with outcome-marked dates; tapping a date shows that meeting's details; the full list is one tap away.

**Implementation order changes (section J).**

- Step 7 becomes **"complete_lesson, undo_lesson_completion, reopen (Coordinator)"**: the lesson card action "Mark Lesson n completed" (Discipler; Leader and Coordinator as fallback), undo while the window holds, Coordinator reopen. Gates N1 and D2 are unchanged and apply to `complete_lesson()` and reopen respectively.
- Removed from step 7: withdraw, confirm, the Awaiting confirmation section on D Group detail, the Leader Home tile and the confirm dialog.
- The monthly calendar (step 9) is brought forward into the Disciple detail and My Journey history.
- Section C's policy-read table: `complete_lesson()` precondition reads `submission_minimum`; the `confirm_lesson_completion()` re-check row is gone; the READY_FOR_COMPLETION void row is dormant.

**As built (matches the governing documents).** `complete_lesson(p_membership_id, p_lesson_id)` and `undo_lesson_completion(p_membership_id, p_lesson_id)`; refusal reasons `cannot_act_on_own_lesson`, `lesson_not_in_progress`, `below_submission_minimum`, `lesson_not_completed`, `later_lesson_completed`, `next_lesson_started`, `lesson_not_eligible`, `not_authorized`; audit actions `LESSON_COMPLETED` and `LESSON_COMPLETION_UNDONE`. `get_progress_summary()` (section D) now returns only `active_discipleships`; the "lessons awaiting the caller's confirmation" figure is removed.

**Seed (section G).** Daniel's "awaiting confirmation" stand-in becomes Lesson 1 IN_PROGRESS with six counted meetings, ready for Dino to mark completed. Diana's completed Lesson 1 is produced by `complete_lesson()` (the working-tree seed already calls it), instead of a submit-and-confirm pair.

**Tests (section H).** Completion, fallback, self-refusal and precondition cases target `complete_lesson()`; undo covers both window conditions, the resulting state, the cleared columns and the audit row; reopen expects IN_PROGRESS or NOT_STARTED; withdrawal and confirmation cases are dropped.

**Reopen rule (user, 2026-10-05, fifth).** `reopen_lesson_completion()` (Coordinator only) refuses to reopen Lesson N when any later lesson is COMPLETED (`later_lesson_completed`) or has a RECORDED participant row in a RECORDED meeting for the person, whatever the outcome (`later_lesson_has_meetings`). It never moves, voids or deletes later meeting history; the refusal tells the Coordinator to void the conflicting later meetings first. DC section 4, reopen precondition 3, carries the rule. Enforced server-side and covered by integration tests when step 7 builds reopen.

**Journey layout revision (user, 2026-10-05, sixth).** The current lesson comes first on My Journey and Disciple detail, in one card: a ring for lessons completed out of the curriculum (no percentage printed), Lesson n with its title and the Discipler, the meeting count, one step per recorded meeting of the current lesson coloured by outcome (no "remaining" markers, ADR-011), an outcome breakdown and the status line. The 12-segment journey stepper of decision 21 is replaced: rows, Home and Profile use one continuous bar; the lesson-by-lesson timeline becomes a collapsed "All lessons" list. "Mark Lesson n completed" sits in the card and asks for confirmation, stating the meetings recorded, what changes and the undo window. Recording moves into the meeting calendar: "Record a meeting today", or "Record a meeting on {date}" for a selected earlier empty date, which opens the form on that date. D Group detail lists unpaired Disciples first, with a "Not paired yet" chip and a prominent Pair action, and each Disciple row opens their detail.

**Pills and roster revision (user, 2026-10-05, seventh).** One shared pill and avatar component (`AppPill`, `InitialsAvatar`; tones lime, black, grey, amber, red) carries state, role and facts across the journey pages, My Disciples, Home, My D Group and D Group detail. The current lesson card shows the lesson state and the last recorded meeting as pills (the last recorded meeting in black so it stands out) and the outcome counts as pills; the overall meeting facts (attended, recorded absences, excused, and for oversight a run of recorded absences) move to pills above the meeting calendar. Disciple rows on Home and in My Disciples use a lesson stepper (one segment per curriculum lesson) so several people's positions compare at a glance; single-person views keep the ring. My D Group gains a group header (the person's own role, a count per role) and person tiles with role pills; a Discipler's Disciples show their current lesson and last recorded meeting. Role colours are consistent: Leader black, Discipler lime, Disciple grey, unpaired amber.

**Colour revision (user, 2026-10-05, eighth).** Pills, avatars, steps and progress use a semantic pastel palette with Material 3 style tonal pairs and separate dark-mode values (`lib/core/widgets/app_pill.dart`), beside the brand theme: matte green for progress, counted meetings and completion; soft blue for in progress and the Disciple role; slate for the last recorded meeting; violet for the Leader; teal for Disciplers; amber for needs attention; soft red for recorded absences; grey for secondary facts. Lime stays the brand colour for primary actions and selection. Avatar placeholders take a stable pastel from the person's name.

**Curriculum of ten lessons (user, 2026-10-05, ninth).** The ministry's curriculum has ten lessons, not twelve. This supersedes section S item 7's "the 12-lesson assumption is not changed now". Migration 004 is unchanged (applied, immutable). The Slice 5 migration (`20261002000001_discipleship_meeting_progress.sql`, section 11) replaces `private.bootstrap_church()` and `private.assert_bootstrap_postconditions()` with the lesson count changed from twelve to ten: lessons numbered 1 to 10, `required_meetings` still seeded as 4 and still unread by any rule. It removes Lessons 11 and 12 from existing ACTIVE curricula only when no meeting or progress row references them; otherwise the migration stops. No app code or other SQL encodes a lesson total: every total comes from the ACTIVE curriculum's rows (BR-036 principle). The Discipler eligibility lesson stays 5 (`private.discipler_eligibility_lesson()`). The ministry PDF (10 complete lessons) is still processed in Slice 7 for lesson content; Slice 7 no longer reconciles the count. Earlier "of 12" examples in this plan are historical; the governing documents carry ten (revision 2026-10-05, ninth).

**Flat cards, three colours, separate tiles (user, 2026-10-05, tenth).** Cards have no shadow. Beside the brand theme (lime, black, white, grey) the app uses exactly three hues: blue (in progress, the Disciple role), amber (Late, needs attention) and red (recorded absence). Progress (ring, stepper, bars) uses the brand lime; Present is lime and Late is amber. The most important pills are outlined (the current lesson's state, the last recorded meeting, warnings). Avatar placeholders never use lime. Lists are separate tiles, not divider-joined rows; related items sit as tiles inside one larger card (`TileGroup`). Record a meeting is rebuilt around a lesson header, quick date chips, one tile per Disciple with four large colour-coded outcome choices, a notes field and a summary. Home greets with a short line and a daily slogan as the title.

**Whiter pages, no outlines, one content per card (user, 2026-10-05, eleventh).** Pills have no outline. The page background is #F8F9FA and components are pure white with a faint border. Related items are separate white cards with space between, with no outer card (one component holds one related content). Lime is removed from icon tiles and text links: icon tiles are light grey with a black icon, and links such as "View full history" use the black underlined link; text and outlined buttons are black in the theme. Section headings are larger, bold and black. Lime remains for primary button fills, progress (ring, stepper, bars) and Present.

**Fully flat components (user, 2026-10-05, twelfth).** Cards have no border and no shadow: pure white on the #F8F9FA page. Unselected outcome choices in Record a meeting use a light grey fill instead of a border.

**Fewer coloured pills (user, 2026-10-05, thirteenth).** The default pill is an outline only (dark grey in light mode, light grey in dark mode) for supporting facts: the last recorded meeting, outcome counts, meeting totals, role pills on other people. Lime fills are kept for the single most important, active fact (the current lesson in progress, a completed lesson, a Disciple's lesson in progress, the person's own role). Amber is kept only for attention ("Not paired", a run of recorded absences). Importance is carried by weight and opacity: bold for names and key facts, muted for supporting lines. The Home group card has a lime gradient behind a single switch (`_useGradient` in `group_summary_card.dart`) so it can be reverted.

**Lime group card, grey pills, charcoal dark mode (user, 2026-10-05, fourteenth).** The Home group card is the theme lime with pure black text in both modes (the gradient is replaced; `_useLime` in `group_summary_card.dart` returns it to white); pills on it are translucent black with black text. Supporting pills are grey-filled (no outline). Pastel lime with strong green text marks the important pills: the Leader role, your own role, your Leader and Discipler, and the active lesson. Dark mode follows the reference image: a charcoal page (#1B1B1D) with lighter charcoal cards (#2A2A2D); light mode is unchanged.

**Premium group card, yellow "not started" (user, 2026-10-05, fifteenth).** The Home group card has a 32 px radius, two soft decorative circles in the top-right corner, a "MY D GROUP" chip with a round black arrow button, a larger group name, and the person's Leader, Discipler and Disciples in a translucent inner panel. Elements on the lime card contrast with the theme mode: translucent black in light mode, white (pills and avatars, black text) in dark mode. The attention tone is now a true yellow (pastel yellow with deep yellow text), used for Late, "not started" lessons and "Not paired".

**Group card reverted to pastel green; dark mode reverted (user, 2026-10-05, sixteenth).** Dark mode is back to the pure black page with near-black cards. The Home group card keeps its modern structure (chip, arrow button, decorative circles, inner panel) but uses a Material tonal container of the brand green: pastel green with dark green-black text in light mode, deep green with light text in dark mode. Pills and the arrow button on it invert (dark with light text in light mode, light with dark text in dark mode). Avatars keep their name colours. `_useGreen` in `group_summary_card.dart` returns it to the plain card.
