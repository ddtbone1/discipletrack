# ADR-004: RBAC and Row Level Security

## Status

Accepted

## Context

DiscipleTrack contains different authority levels.

Church-level roles:

- ADMIN
- COORDINATOR

D Group responsibilities:

- LEADER
- DISCIPLER
- DISCIPLE

Permissions also depend on relationships.

Examples:

- Leader → own D Group
- Discipler → assigned Disciples
- Disciple → primarily self

Some information, especially follow-up notes, is sensitive.

## Decision

Use Role-Based Access Control together with PostgreSQL/Supabase Row Level Security.

RBAC determines:

"What is this role allowed to do?"

RLS determines:

"Which records is this user allowed to access?"

## Why

Authorization cannot rely on Flutter hiding buttons or screens.

A malicious or faulty client must still be unable to access unauthorized records.

## Consequences

RLS must be enabled on user-accessible domain tables.

Policies must consider:

- church membership
- church-level roles
- D Group responsibility
- Discipler assignments
- record ownership/scope

ADMIN does not automatically receive unrestricted access to sensitive discipleship care information.

Technical authority and ministry-care authority remain separate.