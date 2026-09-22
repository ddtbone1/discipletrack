# ADR-005: Controlled Database Operations

## Status

Accepted

## Context

Several DiscipleTrack workflows modify multiple related records.

Examples:

- D Group transfer
- Discipler reassignment
- attendance finalization
- finalized attendance correction
- lesson completion
- Disciple promotion
- follow-up resolution

Performing these as independent Flutter writes could leave the database partially updated.

## Decision

Complex business transitions must use trusted transactional database operations such as PostgreSQL functions exposed through Supabase RPC where appropriate.

Example:

transfer_disciple()

1. Authenticate caller.
2. Validate authorization.
3. Validate current state.
4. End previous D Group membership.
5. End affected Discipler assignment.
6. Create new D Group membership.
7. Create required new relationships.
8. Record audit information.
9. Commit.

If any required step fails, the entire operation rolls back.

## Why

This provides:

- atomicity
- centralized validation
- consistent authorization
- protection against partial updates
- easier testing

## Consequences

Flutter should call domain operations rather than manually reproducing complex business workflows.

Simple safe CRUD operations may still interact directly with tables when permitted by RLS.

Not every operation requires an RPC.

Use controlled operations when business invariants or multiple writes require them.