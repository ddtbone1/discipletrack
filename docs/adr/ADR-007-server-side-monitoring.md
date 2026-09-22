# ADR-007: Server-Side Monitoring

## Status

Accepted

## Context

A major purpose of DiscipleTrack is identifying members who may need attention.

Initial MVP monitoring includes:

CONSECUTIVE_ABSENCE

Example:

3 consecutive unexplained absences
→ attention condition
→ follow-up responsibility

This detection must work even when nobody currently has the Flutter application open.

## Decision

Automated monitoring runs server-side.

Flutter displays monitoring results but does not determine the authoritative monitoring state.

For the MVP, monitoring is triggered when relevant official data changes, such as:

- gathering finalization
- correction of finalized attendance

Monitoring logic must be idempotent.

Running the same monitoring operation repeatedly against the same state must not create duplicate conditions or follow-ups.

## Why

Client-side monitoring would depend on someone opening the application and could produce inconsistent results between devices.

Server-side monitoring gives the church one authoritative state.

## Consequences

Monitoring logic must:

1. Use FINALIZED gatherings only.
2. Ignore DRAFT gatherings.
3. Ignore CANCELLED gatherings.
4. Evaluate attendance chronologically.
5. Create conditions when thresholds are reached.
6. Avoid duplicate active conditions.
7. Resolve conditions when they no longer apply.
8. Recalculate after relevant attendance corrections.

Future monitoring rules may include:

- prolonged inactivity
- stalled discipleship progress
- unresolved follow-ups
- attendance decline

These are future features and are not part of the initial MVP monitoring implementation.