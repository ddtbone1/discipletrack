# ADR-014: Remove D Group Gathering Attendance from the MVP

## Status

Accepted (2026-10-05, user decisions 1, 3 to 7, 12 to 15 and 18).

Partially supersedes
[ADR-009](ADR-009-discipleship-meeting-attendance-monitoring.md) and
[ADR-011](ADR-011-explicit-lesson-completion.md) for the statements
listed under "Superseded statements". Everything else in both ADRs
remains accepted.

## Context

ADR-009 kept D Group gatherings in the MVP for one reason: finalized
gathering attendance was the only monitoring source for Leaders and
Disciplers. It considered meeting-only monitoring and rejected it,
because the LEADER and DISCIPLER branches of the follow-up chain would
then have no input.

A gathering had no other approved purpose. Every governing statement
about gatherings existed to make attendance official (the DRAFT,
FINALIZED and CANCELLED lifecycle) or to feed monitoring. No document
defines a church-wide meeting, service or event, and event management
and scheduling were already out of scope (MVP_SPEC section 33). Nothing
was implemented: no RPC, policy, seed row or Flutter screen writes or
reads `d_group_gatherings` or `gathering_attendance`.

Migration 001 nevertheless created the gathering tables, the
`gathering_status` enum and the `church_settings.consecutive_absence_threshold`
column. Both gathering tables have RLS enabled with no policy, and they
still hold Supabase's default grants (ALL to `anon` and `authenticated`),
because no later migration narrowed them. RLS deny-by-default is their
only protection.

The planned Disciple condition, `CONSECUTIVE_MISSED_MEETINGS`, counted
explicitly recorded ABSENT outcomes. Its name, and wording such as
"missed meetup", suggest a fact DiscipleTrack does not have. When no
meeting is recorded, the meeting may not have been planned, may have
been postponed or rescheduled informally, may have happened without
being recorded, or may not have happened. None of these is a recorded
fact.

## Decision

### Gatherings

1. D Group gatherings are removed from the MVP entirely, together with
   gathering attendance. No reduced gathering feature is kept because
   the schema exists. Event management stays out of scope.
2. Attendance exists only as the outcome of a discipleship meeting. The
   path is: Journey, the selected discipleship, the current lesson,
   Record Meeting, then each Disciple's outcome. There is no D Group,
   church-wide or event attendance, no gathering attendance dashboard or
   percentage, and no Attendance navigation destination.

### Monitoring is driven by recorded facts only

3. Monitoring uses only facts DiscipleTrack explicitly records. It never
   infers attendance, absence or a missed meeting from missing data.
   NO RECORD is not ABSENT, and NO RECORD is not a missed meeting.
4. No attention condition and no follow-up is generated from elapsed
   time, from inactivity, or from the lack of a record.
5. The automated "missed meeting" condition is withdrawn from the MVP,
   not deferred. "Missed meeting" and "missed meetup" are not domain
   terms. A future explicit, factual missed-meeting concept would need
   its own ADR.
6. The MVP condition is consecutive recorded absences:

   | Condition | Source | Subjects | Episode | Threshold |
   |---|---|---|---|---|
   | CONSECUTIVE_ABSENCE | ABSENT outcomes on RECORDED participant rows of RECORDED discipleship meetings | DISCIPLE | current discipler assignment | `church_settings.consecutive_absence_threshold` |

   The streak is built from explicitly recorded outcomes in
   chronological order. ABSENT increments it. PRESENT and LATE break it.
   EXCUSED breaks it and is never an absence (BR-027a). User-facing
   wording is "2 consecutive recorded absences", never "2 missed
   meetings".
7. The enum value `CONSECUTIVE_ABSENCE` in `attention_condition_type` and
   `follow_up_reason` is kept and now means the condition above. It is
   not renamed, and `CONSECUTIVE_MISSED_MEETINGS` is not added.
8. A recorded meeting in which every outcome is EXCUSED is not a missed
   meeting and not an absence. It has no credited participation and
   breaks the streak. More generally, the "held" and "missed" meetup
   labels are withdrawn; a meeting record shows each Disciple's
   recorded outcome.
9. Follow-ups stay. The Disciple chain (Discipler, then Leader, then
   Coordinator) is triggered by CONSECUTIVE_ABSENCE as defined above.
   Every gathering-derived trigger is removed. No replacement trigger is
   invented. The LEADER and DISCIPLER subject branches of the chain have
   no MVP trigger after this decision; they stay documented as
   architecture that a future factual condition could use, and they are
   not built until one is approved.

### Applied schema

10. Applied migrations are not edited. The gathering objects stay in
    Migrations 001 and 002 and are documented as deprecated, with no MVP
    owner.
11. `attendance_status` (PRESENT, ABSENT, LATE, EXCUSED) stays. Record
    Meeting uses all four values, each with an already approved meaning
    (ADR-009 outcome table, ADR-011 decision 3).
12. `church_settings.consecutive_absence_threshold` is retained and
    redefined: the number of consecutive explicitly recorded ABSENT
    discipleship meeting outcomes, within the current discipler
    assignment, that raises CONSECUTIVE_ABSENCE for a Disciple. The
    column is a plain integer with no structural tie to the gathering
    tables; its only tie was documentation, so the redefinition is
    clean. The bootstrap default stays 3 (DATABASE_CONSTRAINTS.md section
    0; Migration 004 asserts it).
13. `church_settings.consecutive_missed_meeting_threshold`, added by
    Migration 004 for the withdrawn condition, is dormant. No rule reads
    it. Its database comment still names the withdrawn condition.
    Migration 004's `private.bootstrap_church()` inserts it and
    `private.assert_bootstrap_postconditions()` asserts it equals 3, so
    dropping it needs both functions replaced in the same forward
    migration and `test/integration/bootstrap_test.dart` updated. It is
    not dropped by this ADR.

### Lifecycle of the unused gathering schema

14. Unused tables must not stay broadly accessible. The recommended
    lifecycle, safest first:
    1. **Lock down** at the earliest approved migration step, expected
       to be the Slice 5 migration because it already revokes default
       grants on other tables: revoke all privileges on
       `d_group_gatherings` and `gathering_attendance` from `anon` and
       `authenticated`, keep RLS enabled, add no policy. This is a
       security-only change. It removes no object and no data and is
       reversible.
    2. **Deprecate**: the DBML, DATABASE_CONSTRAINTS.md and
       RBAC_RLS_MATRIX.md mark the objects as deprecated with no MVP
       owner. A forward migration may also update the database comments
       on the two tables and on `consecutive_missed_meeting_threshold`.
    3. **Drop**, only after a separate explicit decision: drop
       `gathering_attendance`, then `d_group_gatherings` (their
       `set_updated_at` triggers go with them), then `gathering_status`,
       in a forward migration that first verifies both tables are empty
       and refuses otherwise. Dropping
       `consecutive_missed_meeting_threshold` additionally requires the
       bootstrap function replacement in decision 13.

    Lock-down is recommended now because it closes the exposure without
    an irreversible step. Dropping is not recommended in the same step:
    it is a schema decision of its own, it touches bootstrap code for the
    threshold column, and keeping two empty, locked tables costs nothing.

## Superseded statements

### ADR-009

Quoted from the 2026-10-02 text.

| Section | Statement | Replaced by |
|---|---|---|
| Context | "D Group gatherings remain a real ministry concept: the whole group meeting together. They are also the only record of whether Leaders and Disciplers themselves are participating, because Leaders and Disciplers are never discipleship meeting participants." | Decisions 1, 9 |
| Decision, Discipleship meeting attendance | "It represents one meetup reported by the Discipler after the fact, held or missed." (the words "held or missed") | Decision 8 |
| Decision, outcome table | Column heading "Missed-meeting streak" | Decision 6: the consecutive recorded absence streak; the per-outcome effects are unchanged |
| Decision | "Held and missed meetups, and the meeting ordinal, are derived rather than stored." (the held and missed labels; the ordinal rule stays) | Decision 8 |
| Role-specific monitoring sources | Table row "CONSECUTIVE_ABSENCE / FINALIZED D Group gathering attendance / LEADER, DISCIPLER / D Group membership episode" | Decisions 1, 6, 9 |
| Role-specific monitoring sources | Table row "CONSECUTIVE_MISSED_MEETINGS / discipleship meeting participant outcomes / DISCIPLE / discipler assignment" | Decisions 6, 7: same source, subject and episode, condition named CONSECUTIVE_ABSENCE |
| Role-specific monitoring sources | "Gathering attendance never creates a condition for a DISCIPLE responsibility. A Disciple therefore has one absence-condition stream, driven by the concept that measures their discipleship." | Decision 1 (no gathering source exists) |
| Role-specific monitoring sources | "Each condition has its own threshold in church_settings." | Decisions 12, 13: one threshold |
| Role-specific monitoring sources | "D Group gatherings remain in MVP scope, secondary to the core discipleship workflow. They do not drive lesson progress or Disciple monitoring." | Decision 1 |
| Alternatives Considered | "Discipleship meetings as the only source, with gatherings deferred. Rejected. Leaders and Disciplers would have no automated monitoring, and the DISCIPLER and LEADER branches of the follow-up escalation chain would have no input." | This ADR adopts meeting outcomes as the only source and accepts the stated consequence (see Consequences) |
| Why | "Keeping gathering monitoring for Leaders and Disciplers preserves the only signal for those roles without giving Disciples a second stream." | Decisions 1, 9 |
| Consequences | "Gathering-based monitoring must:" and its rules 1 to 6 | Decision 1 |
| Consequences | "the new condition and follow-up reason value, and the new threshold" in "The schema changes (...) are introduced by a new migration in the Discipleship Meeting + Progress vertical slice." | Decisions 7, 12, 13: no new enum value; the existing threshold is redefined. The other listed schema changes (participant `attendance_status`, COUNTED to RECORDED) stand |
| Consequences, future rules | "prolonged inactivity, such as no recorded meeting within a period" | Decision 4: never a condition source; it would need a new ADR |

ADR-012 separately supersedes "and promotion" in ADR-009's meeting-based
recalculation triggers.

Not superseded, and restated here because this ADR depends on them:
ADR-009's credit predicate; its outcome effects; "Meeting-based
monitoring must" rules 1 to 4 and the recalculation triggers other than
promotion; "Both must" rules 1 to 3; the carried-forward ADR-007
principles (server-side, one result per church, triggered by data
changes, idempotent, episode-scoped); and "Monitoring only sees meetups
that were recorded. When a Discipler and Disciple stop meeting and
record nothing, no streak forms. In the MVP that situation is visible
through the Disciple's last meeting date in oversight views." The last
recorded meeting date stays a displayed fact, never a condition.

The word "consistency" in ADR-009's Context ("discipleship meeting
attendance and consistency") is read as the factual meeting history. No
consistency ratio or percentage is defined or shown (user decision 8).

### ADR-011

| Section | Statement | Replaced by |
|---|---|---|
| Status | "role-specific monitoring" in "Everything else in ADR-009, including ... role-specific monitoring, remains accepted." | Decisions 1, 6 |
| Consequences | "CONSECUTIVE_MISSED_MEETINGS still counts recorded ABSENT outcomes only (ADR-009)." | Decisions 6, 7: CONSECUTIVE_ABSENCE counts recorded ABSENT outcomes only. "A high meeting count is never an attention signal" stands |

### Other ADRs

ADR-003 ("attendance percentage", "consecutive absence count") and
ADR-005 ("attendance finalization", "finalized attendance correction")
use gathering attendance as examples. The decisions they illustrate are
unaffected and those ADRs are not changed. The examples no longer
describe MVP features.

## Alternatives Considered

**Keep a reduced gathering record without attendance.** Rejected. A
dated group event record is event management or scheduling, which the
MVP excludes, and it would have no consumer.

**Rename CONSECUTIVE_ABSENCE to CONSECUTIVE_MISSED_MEETINGS, or add the
second value.** Rejected. The approved concept is explicitly recorded
ABSENT outcomes, which the existing value already names. Adding a
second value would leave one dormant and one misnamed.

**Defer the missed-meeting condition instead of withdrawing it.**
Rejected. Deferral keeps an unfounded inference on the roadmap.

**Use `consecutive_missed_meeting_threshold` as the threshold.**
Rejected. Its name and database comment carry the withdrawn concept.
`consecutive_absence_threshold` matches the kept enum value and needs
only a documentation redefinition.

**Drop the gathering tables in the Slice 5 migration.** Not chosen now.
Lock-down closes the exposure; dropping is left to a separate decision
(decision 14).

## Why

Each official record should mean exactly what was recorded. Gathering
attendance had no purpose of its own, and an inferred missed meeting
would raise care cases from data that does not exist. A Discipler who
records "Absent" twice has stated two facts; that is a sound basis for a
care case. Keeping one condition, one source and one threshold also
removes the two-threshold and two-stream rules that existed only
because of gatherings.

## Consequences

- Leaders and Disciplers have no automated monitoring in the MVP. This
  is the outcome ADR-009 rejected, now accepted. Their participation is
  noticed through human oversight. MVP_SPEC section 1's purpose (no
  member quietly becoming inactive unnoticed) is served by automated
  monitoring for Disciples only.
- A person who is both a Disciple and a Discipler (ADR-012) is
  monitored as a Disciple only.
- The last-Coordinator protection keeps its reason as the end of the
  follow-up chain; "fallback attendance recorder" for gatherings is no
  longer one of its reasons.
- Governing documents are updated in the same pass: gathering
  requirements, roles, rules, metrics, RBAC rows, UI (including the
  UI_DESIGN_SYSTEM section 20 week strip) and roadmap entries are
  removed or marked withdrawn; the DBML keeps the gathering table
  definitions because they exist, marked deprecated.
- The Slice 5 plan needs no enum migration, and its grant step is the
  expected place for the lock-down in decision 14.
- The Gatherings / Attendance slice is removed from the roadmap.
  Monitoring / Follow-ups depends primarily on Slice 5.
- Open: whether the MVP default for `consecutive_absence_threshold`
  should stay 3 (the user's illustration uses two recorded absences);
  whether the LEADER and DISCIPLER subject branches should be removed
  from the documents rather than kept dormant; whether and when to drop
  the deprecated objects (decision 14, step 3).
