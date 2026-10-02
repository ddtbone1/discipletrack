> **Working plan, not an authoritative document.** Approved scope and decisions for Vertical Slice 5 (user decisions 2026-10-02, recorded under "Decisions taken"). Where it differs from the governing documents listed in AGENTS.md, those documents are amended as part of the slice (lighter documentation rule, Slice 3 decision 12).

# Vertical Slice 5: Discipleship Meeting + Progress

## Context

Slice 3 left in place everything this slice depends on:

- DISCIPLE rows, created only by an accepted invitation;
- active `discipler_assignments` to DISCIPLER rows in the same group (P1 to P3);
- an active Leader in every group;
- tested scoping helpers;
- `MONITORING HOOK` comments where assignments end.

This slice delivers the core loop in MVP §2: **record meeting (held or missed) → lesson progress → Leader confirmation**. Missed-meeting monitoring is deferred (decision 7).

Verified baseline:

- HEAD is `2bcfcd1` (Slices 3 and 4). Migrations 001 to 006 are committed and immutable.
- The tables already exist from Migration 001 but have no policies, RPCs or triggers, and still hold Supabase's default grants: `curricula`, `curriculum_lessons`, `discipleship_meetings`, `discipleship_meeting_participants`, `disciple_lesson_progress`, `attention_conditions`.
- Bootstrap (Migration 004) already seeds one ACTIVE curriculum with 12 lessons × `required_meetings = 4`, and already added `church_settings.consecutive_missed_meeting_threshold` (default 3).

ERD v2 / ADR-009 changes still **missing from the database**:

| Change | Current DB | Required |
|---|---|---|
| `meeting_participation_status` value | `COUNTED` (also the column default) | renamed to `RECORDED` |
| `discipleship_meeting_participants.attendance_status` | absent | `attendance_status NOT NULL`, no default |
| `attention_condition_type` | `CONSECUTIVE_ABSENCE` | add `CONSECUTIVE_MISSED_MEETINGS` |
| `follow_up_reason` | `CONSECUTIVE_ABSENCE` | add `CONSECUTIVE_MISSED_MEETINGS` |

Migration 001 comments say `occurred_at` immutability and P1 to P3 are enforced "in Migration 002". Migration 002 explicitly defers both, so neither exists yet. This slice implements them.

---

## A. Decisions (proposed)

1. **One record per meetup, after the fact.** No scheduling (MVP §33). "Held" and "missed" are derived, never stored.
2. **Eligibility ★.** A Disciple is eligible for exactly one lesson: the lowest-numbered lesson of the ACTIVE curriculum that is not COMPLETED. This satisfies "N-1 COMPLETED, lesson 1 exempt" and also refuses meetings for an already-COMPLETED lesson, a case the docs leave open. It is checked against current state at recording time.
3. **Who records.**
   - The DISCIPLER, for their own active DISCIPLER row.
   - The LEADER, for any DISCIPLER row in their own group.
   - The COORDINATOR, for any group, as a fallback. `recorded_by` shows who entered it.
   - Participants are validated against P1 to P3 as of `occurred_at`, so a backdated entry works for the assignment that existed at that time.
4. **No self-recording or self-confirmation ★.** A caller is never a participant in a meeting they record, and never confirms their own lesson. Without this rule, a Coordinator who holds DISCIPLE could do both.
5. **Void semantics.**
   - Voiding a meeting does not cascade to its participant rows; meeting status alone removes credit.
   - Voiding the **last** RECORDED participant of a meeting is refused (`void_meeting_instead`). Otherwise an empty RECORDED meeting would count as a missed meetup under DC §4.
6. **Progress rows are maintained state, counts are not.**
   - `disciple_lesson_progress` holds `status`, `started_at`, `ready_at`, `completed_at` and `confirmed_by`, recomputed by one private function after every record or void.
   - Credited count, ordinal, consistency and streak are computed at read time.
   - `ready_at` is the `occurred_at` of the `required_meetings`-th credited participation, ordered by `(occurred_at, meeting id)`.
7. **No missed-meeting monitoring in this slice (user).** Meetings happen on each pair's own chosen schedule, so this slice raises no `CONSECUTIVE_MISSED_MEETINGS` condition and writes no `attention_conditions` rows. Missed meetups are still *recorded* (they are part of the meeting record) but trigger nothing.
   - **ADR conflict, reported:** ADR-009 (accepted) defines this condition. Deferring it is consistent with the ADR; dropping it for good needs a superseding ADR (AGENTS.md). Open for the user.
   - The enum additions (`attention_condition_type`, `follow_up_reason`) are therefore not needed now; they arrive with whichever slice builds monitoring.
   - The `MONITORING HOOK` comments in Migration 006 stay in place for that slice.
8. **(Withdrawn with decision 7.)** No `discipler_assignments` trigger in this slice.
9. **Dock (user).**
   - Disciple gets **Progress** (`/progress`).
   - Discipler gets **Disciples** (`/disciples`).
   - Leader gets **Members** (`/members`): everyone in their group with their progress, opening member detail (UI §22).
   - Coordinator: unchanged.
10. **Offline.** Every new write action is disabled while offline. Progress is not added to the Slice 4 snapshot (deferred).
11. **Out of scope** (MVP §33 or later slices): promotion, follow-ups, gatherings, the inactivity condition, meeting photos, scheduling, a Coordinator sequencing override, reasons on voids, and a church-wide Coordinator progress dashboard.

## B. Roles in this slice

| Action | Coordinator | Leader (own group) | Discipler | Disciple |
|---|---|---|---|---|
| Read curriculum | Yes | Yes | Yes | Yes (also unplaced Members and Admin) |
| Record meeting, held or missed | Fallback, any group | Fallback, any Discipler in group | Own assigned Disciples | No |
| Void meeting / participant | Yes | Meetings of own group | Self-recorded under own active DISCIPLER row | No |
| Confirm lesson completion | Oversight | Disciples currently in own group | No | No |
| Reopen completion | Yes | No | No | No |
| View progress (journey) | Church-wide | Current group members | **Every Disciple in their group** (user) | Self |
| View meeting history | Church-wide | Meetings of own group | Meetings under own DISCIPLER row(s) | Meetings they take part in |

- All authority requires the caller's own membership to be ACTIVE (RBAC §1a).
- ADMIN without COORDINATOR has no meeting, progress or condition access (RBAC §2).

## C. Database: two new migrations

One file: `supabase/migrations/20261002000001_discipleship_meeting_progress.sql`. The enum additions are not needed in this slice (decision 7).

**Schema changes (file 2).**

- Rename `meeting_participation_status` value `COUNTED` to `RECORDED`.
- A DO-block guard raises if `discipleship_meeting_participants` has rows. Then add `attendance_status public.attendance_status not null`, with no default.
- `disciple_lesson_progress` state CHECK (a new DC invariant):

  | Status | Required fields |
  |---|---|
  | NOT_STARTED | all four timestamps and `confirmed_by` null |
  | IN_PROGRESS | `started_at` set; the rest null |
  | READY_FOR_COMPLETION | `started_at` and `ready_at` set; the rest null |
  | COMPLETED | all four set |

- Indexes:
  - `discipleship_meetings (discipler_d_group_membership_id, occurred_at, id)`;
  - `discipleship_meetings (d_group_id, occurred_at)`;
  - `discipleship_meeting_participants (church_membership_id)`;
  - `discipleship_meetings (lesson_id)`.

**Grants.**

- Revoke all from `anon` on: `curricula`, `curriculum_lessons`, `discipleship_meetings`, `discipleship_meeting_participants`, `disciple_lesson_progress`, `attention_conditions`, `follow_ups`, `follow_up_actions`.
- Revoke INSERT, UPDATE, DELETE and TRUNCATE from `authenticated` on the same tables. Only SELECT under RLS remains.
- `follow_ups` and `follow_up_actions` keep zero policies.

**Integrity triggers** (constraint triggers, SECURITY DEFINER, schema `private`, as in 006):

| Table | Rules |
|---|---|
| `discipleship_meetings` INSERT | the discipler row is a DISCIPLER row of `d_group_id`, active at `occurred_at`; the lesson's curriculum belongs to the group's church |
| `discipleship_meetings` UPDATE | `d_group_id`, `discipler_d_group_membership_id`, `lesson_id`, `occurred_at`, `recorded_by` and `created_at` are immutable; RECORDED → VOIDED only (sets `voided_by`, `voided_at`); VOIDED is terminal |
| `discipleship_meeting_participants` INSERT | if RECORDED: P1, P2 and P3 as of the meeting's `occurred_at`; same church; the parent meeting is RECORDED |
| `discipleship_meeting_participants` UPDATE | `meeting_id`, `church_membership_id` and `attendance_status` are immutable; RECORDED → VOIDED only, which is terminal |
| `disciple_lesson_progress` | the lesson's church equals the membership's church |
| `attention_conditions` | `d_group_id` church equals the membership church; `CONSECUTIVE_MISSED_MEETINGS` requires a `d_group_id`; ACTIVE → RESOLVED sets `resolved_at`, and RESOLVED is terminal |
| `discipler_assignments` AFTER INSERT / UPDATE OF `ended_at` | calls `private.evaluate_missed_meetings(<disciple membership>)` (decision 8) |

**Helpers** (`private`, SECURITY DEFINER, STABLE):

- `is_active_member_of(church)`: curriculum reads.
- `current_disciple_row(membership)`: the active DISCIPLE `d_group_memberships` row, or null.
- `leads_current_group_of_disciple(membership)`: the caller leads that person's current group.
- `can_view_progress_of(membership)`: any of the following:
  - the Coordinator of the church;
  - `leads_current_group_of_disciple`;
  - the caller holds an active DISCIPLER row in the person's current group (user: Disciplers see all progress in their group);
  - `is_my_membership` (from 006).
- `can_view_meeting(meeting)`: the meeting-context predicate in section B, used by the policies on both meeting tables.
- `can_void_meeting(meeting)`: any of the following:
  - the Coordinator;
  - `leads_d_group(d_group_id)`;
  - `recorded_by` is the caller, and the caller owns that discipler row and it is still active.
- `credited_count(membership, lesson)`: the derived predicate of DC §4.
- `eligible_lesson(membership)`: decision 2.

**Internal workers** (`private`, VOLATILE, service role only):

- `recompute_lesson_progress(membership, lesson)`:
  - upserts the progress row, creating it lazily;
  - leaves COMPLETED rows untouched;
  - otherwise sets the status from the credited count against `required_meetings`, plus `started_at` (earliest credited `occurred_at`) and `ready_at` (decision 6).
- `evaluate_missed_meetings(membership)`:
  1. Computes the streak per DC §11 under the current assignment: leading ABSENT rows, newest first, within the assignment period.
  2. Reads the threshold from `church_settings`.
  3. Resolves the ACTIVE condition when the assignment changed, the assignment ended, or the streak fell below the threshold.
  4. Creates a condition when the streak reaches the threshold and none is active. It carries `d_group_id` and `metadata {discipler_assignment_id, streak, last_meeting_id}`.

  It is idempotent, and the existing partial unique index guards it.

**RPCs** (`public`, SECURITY DEFINER). Each one checks authority first, locks participant memberships in id order, uses `now()` and writes one audit event.

| Operation | Who | Behaviour | Audit |
|---|---|---|---|
| `record_discipleship_meeting(discipler_dgm, lesson, occurred_at, participants jsonb [{church_membership_id, attendance_status}], notes)` | Discipler (own row) / Leader of the group / Coordinator | Derives `d_group_id`. Validates: <ul><li>not in the future;</li><li>participants non-empty, distinct, with explicit outcomes;</li><li>the discipler row active at `occurred_at`;</li><li>the lesson in the ACTIVE curriculum;</li><li>participants ACTIVE and not the caller;</li><li>P1 to P3;</li><li>every participant's eligible lesson is this lesson.</li></ul>Inserts the meeting and participants, then recomputes progress and evaluates monitoring for each. Accepts meetings while a lesson is READY_FOR_COMPLETION. | `DISCIPLESHIP_MEETING_RECORDED` |
| `void_discipleship_meeting(meeting)` | `can_void_meeting` | The meeting must be RECORDED. **COMPLETED protection:** refused if a credited participant's COMPLETED lesson would drop below `required_meetings`. Sets VOIDED, then recomputes and evaluates. | `DISCIPLESHIP_MEETING_VOIDED` |
| `void_meeting_participant(participant)` | `can_void_meeting(parent)` | Parent and row both RECORDED; the last RECORDED participant is refused; same COMPLETED protection. | `MEETING_PARTICIPANT_VOIDED` |
| `confirm_lesson_completion(membership, lesson)` | Leader of the Disciple's current group / Coordinator | Requires READY_FOR_COMPLETION and a credited count ≥ required; never self. Sets COMPLETED, `completed_at` and `confirmed_by`. | `LESSON_COMPLETION_CONFIRMED` |
| `reopen_lesson_completion(membership, lesson)` | Coordinator only | DC §4 preconditions 1 to 4. The resulting state comes from the credited count. Clears `completed_at` and `confirmed_by`. | `LESSON_COMPLETION_REOPENED` |
| `get_disciple_journey(membership)` | `can_view_progress_of` | Read-only. One row per lesson: number, title, required, credited count, status, timestamps, confirmer name, `is_current`, `is_locked`. | none |
| `get_disciple_consistency(membership)` | `can_view_progress_of` | Read-only DC §11 metrics: <ul><li>attended, missed, excused;</li><li>consistency (null on a zero denominator);</li><li>last meeting date;</li><li>current streak;</li><li>`has_active_condition`.</li></ul> | none |
| `get_meeting_history(membership)` | meeting-context filter per row | Read-only. Date, lesson, outcome, credited, ordinal, held or missed, recorder, notes, statuses, `can_void`. | none |
| `list_disciple_progress(d_group default null)` | Leader/Coordinator for a group; null means the caller's assigned Disciples | Read-only. Per Disciple: name, Discipler, current lesson, credited and required, status, last meeting, meetups missed, needs attention. | none |

Errors follow the 006 convention:

| Code | Reasons |
|---|---|
| PT400 | `participants_required`, `duplicate_participant`, `invalid_attendance_status` |
| PT401 | `authentication_required` |
| PT403 | `not_authorized` |
| PT404 | `lesson_not_found`, `meeting_not_found`, `participant_not_found`, and the other not-found reasons |
| PT409 | `occurred_at_in_future`, `discipler_not_active_at_occurred_at`, `lesson_not_in_active_curriculum`, `member_not_active`, `cannot_record_own_meeting`, `participant_not_assigned_at_occurred_at`, `lesson_not_eligible`, `meeting_not_recorded`, `participant_not_recorded`, `void_meeting_instead`, `lesson_completed_protected`, `lesson_not_ready`, `cannot_confirm_own_lesson`, `lesson_not_completed`, `later_lesson_completed`, `already_promoted` |

**RLS (read-only policies).**

| Table | Coordinator | Leader | Discipler | Disciple | Member / Admin-only |
|---|---|---|---|---|---|
| `curricula`, `curriculum_lessons` | own church | own church | own church | own church | own church when ACTIVE |
| `discipleship_meetings` | church-wide | own group | under own DISCIPLER row(s) | where a participant | none |
| `discipleship_meeting_participants` | via `can_view_meeting` | same | same | own rows only | none |
| `disciple_lesson_progress` | church-wide | current group members | every Disciple currently in their group (user) | self | none |
| `follow_ups`, `follow_up_actions` | none (deferred) | none | none | none | none |

## D. Flutter

**New `lib/features/discipleship/`** (mirrors `lib/features/ministry/`):

- **domain:**
  - `curriculum_lesson`
  - `attendance_outcome`: PRESENT, LATE, ABSENT, EXCUSED; display only
  - `lesson_progress`: `LessonState` covering locked, notStarted, inProgress, ready and completed, plus a display rule. Below the requirement it shows "Meeting n of m". At or above it shows "Requirement reached · n meetings recorded · Awaiting Leader confirmation", never "5/4" (UI §33).
  - `disciple_journey`
  - `meeting_consistency`
  - `meeting_history_entry`
  - `disciple_progress_summary`
  - `meeting_draft`
- **data:** `discipleship_repository`, with `DiscipleshipFailure` mapping every reason above to wording.
- **application:**
  - providers: `myJourneyProvider`, `journeyProvider(id)`, `consistencyProvider(id)`, `meetingHistoryProvider(id)`, `myDisciplesProvider`, `groupProgressProvider(groupId)`, `awaitingConfirmationCountProvider`;
  - `record_meeting_controller`;
  - `lesson_review_controller` (confirm, reopen);
  - `meeting_void_controller`.
- **presentation:**
  - `progress_page`: the Disciple's own journey. A horizontal summary (UI §31) above a vertical timeline (UI §32), then consistency and history.
  - `my_disciples_page`: the Discipler's list, each with current lesson, meeting dots, last meeting and a needs-attention marker.
  - `disciple_detail_page`: shared by Discipler, Leader and Coordinator. It shows journey and history, with these actions:
    - Record Meeting: the Discipler, and Leader or Coordinator as a fallback (UI §26);
    - Confirm: Leader or Coordinator, when the lesson is ready;
    - Reopen: the Coordinator;
    - Void: on rows where `can_void` is true.
  - `record_meeting_page` (UI §25):
    - Meeting held / Meetup missed ("missed" presets every outcome to Absent);
    - the lesson, prefilled from the current lesson;
    - the date (no future dates);
    - Disciples, each with an outcome;
    - optional notes.
  - widgets: meeting progress dots (driven by `required_meetings`), lesson timeline, journey strip, outcome selector, meeting history list ("Meeting 3 · Present · Counted" / "Missed meetup · Absent · Not counted"), void confirm sheet.

**Modified:**

- **`routes.dart` and `router.dart`:** `/progress`, `/disciples`, `/disciples/:membershipId` and `/disciples/:membershipId/record`, added to the active allow set.
- **`dock_shell.dart`:** Progress for a Disciple; Disciples for a Discipler, including a Leader who also disciples (decision 9).
- **`d_group_detail_page.dart`:** a progress line per Disciple, opening disciple detail; an "Awaiting confirmation" section for Leader and Coordinator.
- **`home_page.dart`:**
  - Disciple card: current lesson and dots;
  - Discipler: My Disciples and Record Meeting;
  - Leader: an "n lessons awaiting confirmation" tile.
- **`app.dart`:** the resume hook also invalidates discipleship providers.
- **Previews:** the new pages.

New screens stay consistent with UI_DESIGN_SYSTEM §57 (the welcome and login standard); see D2.

## D2. UX: every screen explains itself

**Approach.** Functionality first; the full UI refinement pass comes later. New screens stay visually consistent with the finished welcome and login pages (UI_DESIGN_SYSTEM §57):

- the grey page with white soft-shadow cards;
- pill fields with floating labels;
- one lime pill primary action per screen;
- a bold title with a grey supporting line;
- a back arrow on every pushed page.

They do not need bespoke visual polish.

**Rules for every screen:**

- A one-line **purpose** under the title says what the person can do there, in their words.
- **Empty states** say why the screen is empty and what happens next. They offer an action only if the person can actually take it (UI §42).
- **Errors** are plain language: what happened, then what to do. They never show a raw code or database text. They appear inline next to what they concern, the form keeps what was typed, and **Try again** is offered when retrying can help.
- **Loading** keeps the previous content where it exists. It shows a spinner only on a first load or inside the button that was pressed.
- **Success** is confirmed in one short snackbar that names what changed, for example "Meeting recorded for Diana Cruz". The screen then shows the new state.
- **Offline**: the banner is present and every write action is disabled, as in Slice 4. A disabled action explains itself on tap: "You're offline. Connect to record this meeting."
- **Destructive or hard-to-undo actions** (void, reopen) ask once and say what will change, for example: "Void this meeting? It will no longer count toward Lesson 2. This can't be undone." Routine actions do not ask.
- **Words are consistent:**
  - "Meeting held" / "Meetup missed";
  - "Counted" / "Not counted";
  - "Ready for confirmation", "Completed", "Needs attention";
  - "Lesson 3 · Meeting 2 of 4" (never "5/4": at or above the requirement it reads "Requirement reached · 5 meetings recorded").

### Screen by screen

**Progress (Disciple)** — title "My progress", purpose "Your journey through the lessons, and the meetings that counted."

- Shows:
  - the current lesson with its meeting dots;
  - a timeline of all lessons (completed, current, locked);
  - consistency figures;
  - meeting history.
- Locked lessons say "Opens after Lesson 2 is completed."
- A lesson that is ready says "Ready for confirmation. Your Leader will confirm it."
- Empty: "No meetings recorded yet. When your Discipler records your first meeting, your progress starts here."
- Unplaced or unpaired: "You're not paired with a Discipler yet. Progress starts once you are."
- Actions: none (read-only), stated plainly so nobody looks for a button.

**My Disciples (Discipler)** — title "My Disciples", purpose "The people you disciple. Tap someone to record a meeting or see their progress."

- Each row: name, current lesson and dots, last meeting ("Last met 3 days ago" or "No meetings yet"), and a "Needs attention" marker with its reason ("3 missed meetups in a row").
- Sorted so "Needs attention" comes first, then the longest since last meeting.
- Empty: "No Disciples are paired with you yet. Your Leader pairs Disciples with you."
- Primary action: **Record a meeting**.

**Disciple detail (Discipler, Leader, Coordinator)** — title is the person's name, purpose "Progress and meeting history for {first name}."

- **Lesson card:** the current lesson, dots, status and what happens next:
  - In progress: "2 more counted meetings to reach the requirement."
  - Ready: "Ready for confirmation by the Leader."
  - Completed: "Completed on 12 Sep, confirmed by Lea Santos."
- **Actions, only those this person can take:**
  - Record a meeting (the Discipler; Leader or Coordinator see "Record on behalf of {Discipler}");
  - **Confirm Lesson n** (Leader or Coordinator, only when ready), with the line "This marks Lesson n completed and opens Lesson n+1.";
  - **Reopen** (Coordinator, completed lessons), in an overflow menu with a confirmation.
- **History rows:**
  - "Meeting 3 · Present · Counted";
  - "Missed meetup · Absent · Not counted";
  - "Excused · Not counted";
  - a voided row is greyed with "Voided by …";
  - each row shows who recorded it, and **Void** only where allowed.
- Empty history: "No meetings recorded for {first name} yet."

**Record a meeting** — title "Record a meeting", purpose "Record what happened. A missed meetup counts as a record too."

1. **What happened?** A segmented choice, "Meeting held" or "Meetup missed". Missed sets everyone to Absent and says "Nobody attended? Record it as missed; it doesn't count toward the lesson."
2. **Lesson:** prefilled with the Disciples' current lesson, with the line "Only Disciples on this lesson can be recorded together." A Disciple on a different lesson is shown disabled with the reason "On Lesson 3".
3. **Date:** today by default; future dates are blocked ("Meetings are recorded after they happen."); a date before the pairing began shows its reason.
4. **Who attended:** each Disciple has an outcome chooser (Present, Late, Absent, Excused) with helper text "Present and Late count toward the lesson. Absent and Excused don't."
5. **Notes:** optional, shared, labelled "Notes (optional)".

The primary action reads **Record meeting** (or **Record missed meetup**). After success: a snackbar, then back to the detail page, which shows the new dots.

**Group detail additions (Leader, Coordinator)**:

- a progress line per Disciple ("Lesson 2 · 3 of 4 · Last met 5 Sep"), which opens detail;
- an **Awaiting confirmation** section: "{n} lessons are ready for you to confirm", each with Confirm;
- empty: "Nothing to confirm right now."

**Home**:

- Disciple: their lesson card with dots, plus "See my progress".
- Discipler: a "My Disciples" tile, with "{n} need attention" when any do, plus Record a meeting.
- Leader: a "{n} lessons awaiting confirmation" tile.
- Each tile states its number in words for screen readers.

### Error messages

Every reason the database can return has a sentence. Generic codes fall back to the shared ones: network, "You are not allowed to do that.", and "Please sign in again to continue."

| Reason | Message shown |
|---|---|
| `participants_required` | Choose at least one Disciple for this meeting. |
| `duplicate_participant` | Each Disciple can be added once. Remove the duplicate and try again. |
| `invalid_attendance_status` | Choose Present, Late, Absent or Excused for each Disciple. |
| `occurred_at_in_future` | That date is in the future. Meetings are recorded after they happen. |
| `discipler_not_active_at_occurred_at` | You weren't this group's Discipler on that date. Choose a date since you started. |
| `participant_not_assigned_at_occurred_at` | {Name} wasn't paired with this Discipler on that date. Choose a later date, or record without them. |
| `lesson_not_eligible` | {Name} is on Lesson {n}. Record lessons in order, one at a time. |
| `lesson_not_in_active_curriculum` | That lesson isn't part of your church's current curriculum. |
| `member_not_active` | {Name} is no longer an active member, so meetings can't be recorded for them. |
| `cannot_record_own_meeting` | You can't record a meeting you took part in as a Disciple. Ask your Discipler or Leader. |
| `meeting_not_recorded` / `participant_not_recorded` | This was already voided. Refresh to see the latest. |
| `void_meeting_instead` | This is the only person in the meeting. Void the whole meeting instead. |
| `lesson_completed_protected` | Voiding this would undo {Name}'s completed Lesson {n}. Ask a Coordinator to reopen the lesson first. |
| `lesson_not_ready` | Lesson {n} doesn't have enough counted meetings yet ({x} of {y}). |
| `cannot_confirm_own_lesson` | You can't confirm your own lesson. Another Leader or the Coordinator can. |
| `lesson_not_completed` | Lesson {n} isn't completed, so there's nothing to reopen. |
| `later_lesson_completed` | A later lesson is already completed. Reopen lessons from the latest one back. |
| `already_promoted` | {Name} has already become a Discipler, so their lessons can't be reopened. |
| `not_authorized` | You can't do that for this person. Ask their Leader or the Coordinator. |
| `*_not_found` | We couldn't find that anymore. It may have been changed. Refresh and try again. |

Load failures on any screen show a full-page message with **Try again**: "We couldn't load {what}. Check your connection and try again." Offline, the screen shows the offline message instead.


## E. Seed

Extend `supabase/seed.sql` after the Slice 3 structure.

Before recording, it backdates the disciple1 DISCIPLE row, the Discipler's row and their assignment to 60 days ago, by a trusted direct update ★. Without the backdating, P1 to P3 refuse meetings dated before seed time.

Then, recording as the Discipler through `record_discipleship_meeting`:

1. disciple1: Lesson 1 gets 4 credited meetings (one LATE) and one ABSENT; the Leader confirms it.
2. disciple1: Lesson 2 gets 2 credited meetings, then 3 ABSENT in a row, which raises a `CONSECUTIVE_MISSED_MEETINGS` condition.
3. disciple2, paired too: Lesson 1 gets 4 credited meetings and is left READY_FOR_COMPLETION for manual confirmation.

Document the resulting states in `config/README.md`.

## F. Tests

**Integration.**

- Cleanup order gains, in front of the existing chain: attention_conditions → participants → meetings → progress.
- Fixture helpers: `placePairedDisciple(since:)` (backdating through the service role) and `recordMeeting(...)`.

| File | Covers |
|---|---|
| `discipleship_meeting_test.dart` | <ul><li>held and missed recording; the outcome credit table;</li><li>NOT_STARTED → IN_PROGRESS → READY; extra meetings not clamped;</li><li>`started_at`/`ready_at` after a backdated entry; ordinal;</li><li>small-group independent outcomes; mixed lessons refused; sequential refusal;</li><li>void and re-record; READY → IN_PROGRESS after a void; last-participant refusal;</li><li>COMPLETED protection;</li><li>confirm by Leader and by Coordinator; reopen preconditions;</li><li>fallback recording (`recorded_by`); audit rows;</li><li>the read RPCs return the DC §11 values</li></ul> |
| `missed_meeting_monitoring_test.dart` | <ul><li>threshold from settings;</li><li>ABSENT ×3 creates exactly one condition, idempotently;</li><li>EXCUSED, PRESENT and LATE break the streak;</li><li>the streak crosses lessons;</li><li>a void that drops the streak resolves;</li><li>a later episode creates a new row;</li><li>re-pair, unpair and removal resolve in the same transaction;</li><li>`d_group_id` is populated</li></ul> |
| `discipleship_security_test.dart` | negatives per RPC and table: <ul><li>another church;</li><li>a Leader outside their group, or reopening;</li><li>a Discipler: unassigned Disciple, Leader-recorded void, after their row ended, other Disciplers' meetings, confirming;</li><li>a Disciple writing or reading others;</li><li>a Coordinator who is a Disciple recording or confirming their own lesson;</li><li>Member and Admin-only see curriculum only; PENDING sees no curriculum;</li><li>anon;</li><li>direct writes;</li><li>an INACTIVE caller</li></ul> |
| `discipleship_integrity_test.dart` | service-role writes rejected: <ul><li>P1, P2 or P3 broken;</li><li>discipler not active at `occurred_at`;</li><li>cross-church lesson, progress or condition;</li><li>immutable column updates; VOIDED → RECORDED;</li><li>progress state CHECK;</li><li>a condition without `d_group_id`</li></ul> |

**Unit tests:**

- the `LessonState` display rule (never "5/4");
- outcome credit mapping;
- `fromMap` for every domain type;
- `MeetingDraft` validation;
- failure mapping;
- `dockItemsFor` per role;
- route patterns.

**Widget tests:**

- progress timeline and strip;
- dots following `required_meetings` (3 and 4);
- record form: missed preset, future date blocked, lesson filter;
- disciple detail actions per viewer;
- counted and not-counted history rows;
- dock items;
- offline disables Record, Confirm, Reopen and Void, with the offline explanation;
- every empty state and every failure reason renders its D2 message (one test per screen, plus a unit test that every reason maps to a non-generic sentence).

## G. Implementation order

Each step lands its migration, Flutter and tests together. Existing tests stay green.

1. Groundwork:
   - the enum migration;
   - the file 2 skeleton: rename, column, grants, indexes, progress CHECK;
   - test cleanup and fixture helpers;
   - integrity triggers with their tests.
2. Helpers, workers and RLS policies; the curriculum read; table-policy security cases.
3. `record_discipleship_meeting` and `recompute_lesson_progress`; the record form, My Disciples, and the read-only parts of disciple detail.
4. Read RPCs; progress page, timeline, dots and strip; dock items; Home entries.
5. Void operations with COMPLETED protection; void UI.
6. Confirm and reopen; Awaiting confirmation on group detail and the Leader Home tile.
7. Monitoring: `evaluate_missed_meetings`, the `discipler_assignments` trigger, calls from record and void; needs-attention markers; the monitoring tests.
8. Wrap-up:
   - the seed;
   - documentation updates:
     - **DBML:** migration notes;
     - **RBAC:** §5 and §10 as built, trigger-based episode resolution, the self rules;
     - **DC:** §4 progress CHECK, `ready_at`, eligibility, the last-participant rule; §6 trigger hook;
   - full suites, format and analyze;
   - the manual walkthrough.

## H. Deferred

| Item | Stopgap |
|---|---|
| Follow-ups (creation, chain, UI) | ACTIVE conditions show as "Needs attention"; the Follow-up slice backfills follow-ups |
| Gatherings and `CONSECUTIVE_ABSENCE` | not needed for Disciples |
| Promotion and eligibility display | the journey shows all lessons completed |
| Church-wide Coordinator progress dashboard | per-group progress on group detail |
| Progress in the offline snapshot | progress screens show the offline state |
| Threshold settings UI | seeded at 3 |
| Membership leaving ACTIVE | as in Slice 3 |
| Inactivity condition | last meeting date in oversight views (ADR-009) |

## I. Verification

1. **Automated:** `flutter analyze`, the format check, `flutter test` and the integration suite all pass.
2. **Migrations:** 001 to 006 are byte-identical to HEAD.
3. **Manual walkthrough** (`npx supabase db reset`, then the app):
   - **Discipler:** record a held meeting and a missed one; void their own; no Void on a Leader-recorded meeting.
   - **Leader:** progress per Disciple and the condition; confirm the READY lesson; fallback recording.
   - **Coordinator:** reopen a lesson; refused on a later-completed lesson.
   - **disciple1:** Progress tab shows the timeline, "Missed meetup" history and no actions.
   - **Deep link:** `/disciples/<other id>` as a Disciple shows a refused or empty screen.
4. **Android:** a smoke test on the emulator or a USB phone.

---

## Decisions needed

1. **Monitoring scope.** Create `CONSECUTIVE_MISSED_MEETINGS` conditions in this slice (recommended), or defer all monitoring to the Follow-up slice? Follow-up records are deferred either way.
2. **Completed lessons.** Refuse recording against a COMPLETED lesson, and backdating across a completion (recommended)? The alternative is to allow extra meetings on completed lessons.
3. **Self rules.** Refuse self-recording and self-confirmation for anyone who holds DISCIPLE, a Coordinator included? Recommended yes.
4. **Co-participants.** In a small-group meeting, may a Disciple see the other Disciples' outcomes? Recommended no, pending Contradiction 3.
5. **Dock.** Progress for Disciples and Disciples for Disciplers, nothing new for Leader or Coordinator? Or a Leader "Members" item per UI §22?
6. **Seed.** Is backdating the seeded placement and assignment rows by trusted direct update acceptable, so that meetings carry realistic past dates?

## Contradictions found (reported, not resolved)

1. **Discipler meeting visibility.**
   - RBAC §2a (Meeting-context scope) grants meetings whose `d_group_id` is the viewer's group *or* whose Discipler row is the viewer's own. Read literally, every Discipler sees all meetings in their group.
   - RBAC §2 ("Own Discipler meetings") and §5 discipleship_meetings ("meetings recorded under own D Group membership") restrict it to their own.
   - The plan follows §2 and §5 provisionally.
2. **Discipler progress visibility.**
   - RBAC §2a (Current-membership scope, which "applies to disciple_lesson_progress") covers the whole group.
   - RBAC §2 ("Assigned Disciples") and §5 disciple_lesson_progress ("currently assigned Disciples") say otherwise.
3. **Disciple seeing co-participants.**
   - RBAC §5 discipleship_meeting_participants says SELECT "follow[s] the visibility of the parent discipleship meeting". A Disciple in a small-group meeting would therefore read other Disciples' outcomes.
   - RBAC §2 says a Disciple's meeting history is "Self", and that a Disciple views church members as "Self".
4. **"No active Leader" fallback cannot occur.**
   - DC §4, BR-033 and RBAC §2/§5 justify Coordinator confirmation "where a D Group has no active Leader".
   - DC §2 Leader Presence (Slice 3) now guarantees every group has one. The rationale conflicts with the current invariant; this does not block the build.
5. **ADR-009 versus the schema.** ADR-009 says the new migration introduces the missed-meeting threshold, but Migration 004 already added `consecutive_missed_meeting_threshold`. This is a stale statement, not a design conflict.
6. **Hard-coded "four".**
   - MVP §20 and BR-033 state a fixed four meetings per lesson.
   - MVP §18, BR-030, DC §0 and UI §33 make `required_meetings` data.
   - Low severity; the plan uses `required_meetings` everywhere.
7. **Stale comments in Migration 001.** They say `occurred_at` immutability and P1 to P3 are enforced "in Migration 002"; Migration 002 defers both. Applied migrations cannot be corrected, so the new file's header should state where they actually land.


---

## Decisions taken (user, 2026-10-02)

1. **Monitoring:** no missed-meeting conditions in this slice, because meetings follow each pair's own schedule. Missed meetups are still recorded. ADR-009 conflict reported in decision 7; a superseding ADR is needed only if the condition is dropped for good.
2. **Completed lessons:** recording against a COMPLETED lesson is refused (decision 2 as proposed).
3. **Self rules:** a person can never record a meeting they take part in as a Disciple, nor confirm their own lesson.
4. **Co-participants:** left to the plan. A Disciple sees only their own participant row, not other Disciples' outcomes in a group meeting.
5. **Dock:** Leader gets a **Members** tab, alongside Progress for Disciples and Disciples for Disciplers.
6. **Seed:** backdating the seeded placement and assignment rows is approved.
7. **Contradiction 2 resolved:** Disciplers see the progress of every Disciple in their group. RBAC §2, §2a and §5 are amended in this slice to say so.
   - Contradiction 1 (meeting records) is not covered by this ruling. A Discipler's view of individual meeting records stays limited to meetings under their own DISCIPLER row, pending the user.

**Before any UI is built,** a UX analysis and plan against modern standards is written as `docs/plans/slice-5-ux.md` and reviewed, then the UI is implemented from it.
