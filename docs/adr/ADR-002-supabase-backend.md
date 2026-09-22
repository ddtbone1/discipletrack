# ADR-002: Supabase Backend

## Status

Accepted

## Context

DiscipleTrack requires backend capabilities including:

- authentication
- PostgreSQL database
- authorization
- storage
- server-side database operations
- future realtime capabilities

Building and operating a completely custom backend would add unnecessary MVP complexity.

## Decision

Use Supabase as the primary backend platform.

Initial services include:

- Supabase Auth
- PostgreSQL
- Row Level Security
- Database Functions / RPC
- Supabase Storage when required

Additional Supabase services may be introduced only when justified by actual requirements.

## Why

Supabase provides the backend infrastructure required by the MVP while still allowing DiscipleTrack's important business logic and constraints to live in PostgreSQL.

## Consequences

Benefits:

- less backend infrastructure to maintain
- integrated authentication and PostgreSQL
- strong RLS support
- suitable for Flutter integration

Trade-offs:

- architecture depends on Supabase capabilities
- developers must understand PostgreSQL and RLS rather than treating Supabase as a simple database API

Supabase does not remove the need for proper backend architecture.