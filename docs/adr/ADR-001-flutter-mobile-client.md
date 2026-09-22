# ADR-001: Flutter Mobile Client

## Status

Accepted

## Context

DiscipleTrack is primarily a mobile application used by church members, Disciplers, Leaders, Coordinators, and Admins.

The application requires:

- modern mobile UI
- reusable components
- Android/iOS support
- persistent authentication
- push notification support
- maintainable feature-based architecture

## Decision

Use Flutter and Dart for the DiscipleTrack mobile application.

Flutter is responsible for:

- UI
- navigation
- local application state
- user interaction
- client-side validation
- communication with backend services
- device integrations

## Why

Flutter allows DiscipleTrack to maintain one mobile codebase while supporting Android and iOS.

Its component/widget model also fits the planned reusable DiscipleTrack design system.

## Consequences

Benefits:

- shared Android/iOS codebase
- reusable UI components
- strong mobile development ecosystem
- consistent UI

Trade-offs:

- developers must understand Dart and Flutter architecture
- platform-specific functionality may occasionally require native integration

Flutter must not become the authoritative location for security or critical business rules.