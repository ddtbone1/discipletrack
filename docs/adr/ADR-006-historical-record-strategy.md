# ADR-006: Preserve Historical Domain Records

## Status

Accepted

## Context

DiscipleTrack is intended to show a person's discipleship journey over time.

Overwriting or deleting old relationships would destroy useful history.

Examples include:

- previous D Group membership
- previous Discipler assignment
- ministry responsibility changes
- attendance
- discipleship meetings
- follow-up actions

## Decision

Important historical domain records should normally be preserved.

Use lifecycle fields such as:

- started_at
- ended_at
- resolved_at
- archived_at
- voided_at
- status

instead of deleting or overwriting historical facts.

Incorrect discipleship meetings or participants should be VOIDED rather than silently deleted.

## Why

DiscipleTrack needs to answer historical questions such as:

- Which D Group was this person in?
- Who was their Discipler?
- What meetings occurred?
- What follow-up actions happened?
- When did they become a Discipler?

## Consequences

Queries must distinguish active and historical records.

For example:

ended_at IS NULL

may represent an active assignment.

The database will contain more historical rows, but this is intentional.

Hard deletion should be reserved for cases where it is genuinely appropriate.
