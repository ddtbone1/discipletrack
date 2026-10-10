# ADR-004: RBAC and Row Level Security

## Status

Accepted. Amended 2026-10-08 by [ADR-022](ADR-022-platform-super-admin-church-provisioning.md): the church-level ADMIN role is retired, and the separation of technical from ministry-care authority below now applies to the platform Super Admin.

## Context

DiscipleTrack contains different authority levels.

Platform-level role (ADR-022):

- SUPER_ADMIN, in `platform_roles`, independent of any church membership

Church-level role:

- COORDINATOR

The church-level ADMIN role is retired (ADR-022). Its enum value remains; no operation grants it and no active row exists.

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

- church membership, in a church whose status is ACTIVE (ADR-022)
- the platform role, which grants no church data
- church-level roles
- D Group responsibility
- Discipler assignments
- record ownership/scope

The Super Admin does not receive ministry-care access. In the MVP this is absolute rather than merely limited: a Super Admin has no access to member identities, memberships, profiles, D Groups, meetings and their outcomes, discipleship progress, lesson content, attention conditions or follow-up notes. The one exception is the name and email of each church's active Coordinators (ADR-022 decision 5). Where one person needs both kinds of authority, COORDINATOR is assigned separately, by someone else (ADR-022 decision 6).

As first written, this paragraph applied to the church-level ADMIN role, now retired.

Technical authority and ministry-care authority remain separate.