# ADR-007: Server-Side Monitoring

## Status

Superseded by [ADR-009](ADR-009-discipleship-meeting-attendance-monitoring.md)

ADR-009 carries forward this ADR's server-side, deterministic,
idempotent and episode-scoped monitoring principles. It replaces the
gathering-only monitoring source below with role-specific sources:
gathering attendance for Leaders and Disciplers, discipleship meeting
outcomes for Disciples. The text below is preserved as historical
record and is no longer authoritative.

## Context

A major purpose of DiscipleTrack is identifying members who may need attention.

Initial MVP monitoring includes:

CONSECUTIVE_ABSENCE

Example:

3 consecutive unexplained absences
→ attention condition
→ follow-up responsibility

This detection must produce one authoritative result for the whole church, rather than a result that depends on which device happened to evaluate it.

## Decision

Automated monitoring runs server-side.

Flutter displays monitoring results but does not determine the authoritative monitoring state.

For the MVP, monitoring is triggered when relevant official data changes, such as:

- gathering finalization
- correction of finalized attendance
- D Group transfer

Absence monitoring is scoped to a D Group membership episode. A transfer therefore closes the old episode, resolves the attention conditions belonging to it, and recomputes the streak against the new episode's own eligible gatherings rather than carrying the previous group's streak forward.

Monitoring logic must be idempotent.

Running the same monitoring operation repeatedly against the same state must not create duplicate conditions or follow-ups.

## Why

Client-side monitoring would depend on someone opening the application and could produce inconsistent results between devices.

Computing and storing the state server-side gives the church one authoritative result, identical for every client and independent of which device opens the app. A client that has never run monitoring still sees the same conditions and follow-ups as everyone else.

For the MVP the evaluation is triggered by the data changes listed above. Scheduled re-evaluation independent of user action is future scope.

## Consequences

Monitoring logic must:

1. Use FINALIZED gatherings only.
2. Ignore DRAFT gatherings.
3. Ignore CANCELLED gatherings.
4. Evaluate attendance chronologically.
5. Create conditions when thresholds are reached.
6. Avoid duplicate active conditions.
7. Resolve conditions when they no longer apply, including on D Group transfer.
8. Recalculate after relevant attendance corrections and after D Group transfer.

Future monitoring rules may include:

- prolonged inactivity
- stalled discipleship progress
- unresolved follow-ups
- attendance decline

These are future features and are not part of the initial MVP monitoring implementation.