# ADR-0006 — Minimum deployment target iOS 26

**Status:** Accepted

## Context

Building *with* the iOS 27 SDK is separate from the deployment *target*. Xcode 27 permits targets
down to iOS 15. Apple will require the iOS 27 SDK for uploads from April 2027; we already exceed that.

## Decision

Minimum **iOS 26**, built against the **iOS 27 SDK**.

## Consequences

- Every Liquid Glass API and the modern App Intents surface are available **unconditionally, with no
  `#available` fences** — a real reduction in code and test surface versus an iOS 17 or 18 floor.
- AlarmKit (iOS 26+) and Critical Messaging (iOS 18.2+) are both reachable for v1.1 without raising
  the floor again.
- It keeps last year's devices. This matters more than usual here: people in financially abusive
  situations often have older or hand-me-down phones, and a safety app that excludes them works
  against its own purpose.
- iOS 27-only devices are not required, so adoption at launch does not gate reach.
