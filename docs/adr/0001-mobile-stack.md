# ADR 0001: Mobile Stack

## Status
Accepted

## Context

ShadeFast needs one mobile codebase with high iteration speed, strong rendering performance, and predictable state management for realtime feeds.

## Decision

Use Flutter + Riverpod + GoRouter.

## Consequences

- Pros: single codebase, rapid UI iteration, strong community ecosystem.
- Pros: Riverpod makes side-effects/testability easier than ad-hoc state patterns.
- Cons: requires Flutter/Dart tooling for all contributors.
- Cons: plugin compatibility must be validated early for media workflows.
