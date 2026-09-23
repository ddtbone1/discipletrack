# ADR-009: Discipleship Meeting Attendance and Role-Specific Monitoring

## Status

Accepted

Supersedes [ADR-007](ADR-007-server-side-monitoring.md).

## Context

DiscipleTrack exists so that Leaders and Coordinators can see:

1. discipleship progress
2. discipleship meeting attendance and consistency
3. Disciples who may need care or follow-up

Leaders and Coordinators are oversight roles. They do not decide when a
Discipler and Disciple meet. The Discipler and their assigned
Disciple(s) arrange meetups themselves, outside the app, and
DiscipleTrack records what actually happened.

Before this decision, the specification had two gaps against that
purpose:

- The discipleship meeting model could not represent absence. A
  participant row meant "participated", and its COUNTED/VOIDED status
  was a record-validity flag. A missed meetup could not be recorded at
  all.
- ADR-007 made finalized D Group gathering attendance the only
  monitoring source. A Disciple who stopped attending discipleship
  meetings but still attended gatherings never raised a condition.

D Group gatherings remain a real ministry concept: the whole group
meeting together. They are also the only record of whether Leaders and
Disciplers themselves are participating, because Leaders and Disciplers
are never discipleship meeting participants.

## Decision

### Discipleship meeting attendance

discipleship_meetings remains the parent record. It represents one
meetup reported by the Discipler after the fact, held or missed.
DiscipleTrack does not schedule meetings.

Each participant row records one expected Disciple and carries an
explicit attendance_status, reusing the existing attendance_status enum:

| Outcome | Progress | Missed-meeting streak |
|---|---|---|
| PRESENT | credited | breaks |
| LATE | credited | breaks |
| ABSENT | not credited | increments |
| EXCUSED | not credited | breaks; not an absence |

The participant status value COUNTED is renamed RECORDED. It means
record validity only. "Credited" is a derived predicate: a RECORDED
participant, with PRESENT or LATE, in a RECORDED meeting.

Held and missed meetups, and the meeting ordinal, are derived rather
than stored.

Meeting context and participant outcomes are immutable. Corrections use
void and re-record. The Discipler may void what they recorded
themselves; Leader and Coordinator keep oversight and fallback void
authority. Every void is audited and subject to COMPLETED protection.

Credited meetings may exceed required_meetings while a lesson is
READY_FOR_COMPLETION. They are not clamped.

### Role-specific monitoring sources

| Condition | Source | Subjects | Episode |
|---|---|---|---|
| CONSECUTIVE_ABSENCE | FINALIZED D Group gathering attendance | LEADER, DISCIPLER | D Group membership episode |
| CONSECUTIVE_MISSED_MEETINGS | discipleship meeting participant outcomes | DISCIPLE | discipler assignment |

Gathering attendance never creates a condition for a DISCIPLE
responsibility. A Disciple therefore has one absence-condition stream,
driven by the concept that measures their discipleship.

Each condition has its own threshold in church_settings.

D Group gatherings remain in MVP scope, secondary to the core
discipleship workflow. They do not drive lesson progress or Disciple
monitoring.

### Carried forward from ADR-007

These parts of ADR-007 are unchanged:

- Automated monitoring runs server-side. Flutter displays monitoring
  results but does not determine the authoritative monitoring state.
- Monitoring produces one authoritative result for the whole church.
- For the MVP, monitoring is triggered when relevant official data
  changes. Scheduled re-evaluation independent of user action is future
  scope.
- Monitoring logic must be idempotent. Running it repeatedly against the
  same state must not create duplicate conditions or follow-ups.
- Monitoring is scoped to an episode. Ending an episode resolves the
  conditions belonging to it and the next episode starts a fresh streak
  rather than carrying the previous one forward.

## Alternatives Considered

**A separate missed-meetup or meeting-attendance table.** Rejected. It
would duplicate the meeting context (Discipler, D Group, lesson, time,
void lifecycle, participant validity, RLS scope), and would split one
small-group meetup where one Disciple attended and another did not
across two tables.

**A generic discipleship-interaction table.** Rejected. No requirement
calls for it.

**Both monitoring sources for Disciples.** Rejected. A Disciple absent
from both gatherings and meetups would receive two parallel condition
and follow-up streams for one underlying concern.

**Discipleship meetings as the only source, with gatherings deferred.**
Rejected. Leaders and Disciplers would have no automated monitoring, and
the DISCIPLER and LEADER branches of the follow-up escalation chain
would have no input.

## Why

The ministry concern for Disciples is participation in discipleship
meetings, so that is what their monitoring measures. Reusing the
existing meeting model keeps one authoritative record per meetup,
avoids conflicting official records, and keeps held and missed meetups
under the same validity, authorization and history rules.

Keeping gathering monitoring for Leaders and Disciplers preserves the
only signal for those roles without giving Disciples a second stream.

## Consequences

Gathering-based monitoring must:

1. Use FINALIZED gatherings only.
2. Ignore DRAFT gatherings.
3. Ignore CANCELLED gatherings.
4. Consider only gatherings at which the member held LEADER or DISCIPLER
   responsibility.
5. Evaluate attendance chronologically.
6. Recalculate after finalization and after finalized attendance
   correction.

Meeting-based monitoring must:

1. Use RECORDED participants in RECORDED meetings only.
2. Ignore VOIDED meetings and participants.
3. Consider only meetings under the Disciple's current discipler
   assignment.
4. Evaluate outcomes chronologically.
5. Recalculate after meeting recording, meeting or participant void,
   Discipler reassignment, D Group transfer and promotion.

Both must:

1. Create conditions when thresholds are reached.
2. Avoid duplicate active conditions.
3. Resolve conditions when they no longer apply, including when their
   episode ends.

Monitoring only sees meetups that were recorded. When a Discipler and
Disciple stop meeting and record nothing, no streak forms. In the MVP
that situation is visible through the Disciple's last meeting date in
oversight views.

Applied migrations are not rewritten. The schema changes (participant
attendance_status, the COUNTED → RECORDED rename, the new condition and
follow-up reason value, and the new threshold) are introduced by a new
migration in the Discipleship Meeting + Progress vertical slice.

Future monitoring rules may include:

- prolonged inactivity, such as no recorded meeting within a period
- stalled discipleship progress
- unresolved follow-ups
- attendance decline

These are future features and are not part of the MVP monitoring
implementation.
