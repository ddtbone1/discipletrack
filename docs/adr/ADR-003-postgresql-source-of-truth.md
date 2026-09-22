# ADR-003: PostgreSQL as Domain Source of Truth

## Status

Accepted

## Context

DiscipleTrack contains important domain rules involving:

- church membership
- D Group responsibilities
- attendance
- discipleship meetings
- lesson progression
- follow-ups
- promotions
- historical assignments

These rules must remain correct regardless of which client accesses the system.

## Decision

PostgreSQL is the authoritative source of truth for DiscipleTrack domain data.

Critical invariants will be protected using:

- foreign keys
- unique constraints
- check constraints
- partial unique indexes
- database functions
- transactions

Derived information should generally be calculated rather than redundantly stored.

Examples include:

- attendance percentage
- consecutive absence count
- lesson meeting count
- overall discipleship progress
- promotion eligibility
- overdue follow-up state

## Why

Flutter cannot guarantee data integrity because client applications can contain bugs, become outdated, or attempt invalid requests.

The database is the final integrity boundary.

## Consequences

Business-critical database rules must be designed deliberately.

Flutter may validate inputs for user experience, but client validation does not replace database enforcement.