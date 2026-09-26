# ADR-0003 — Local package boundaries and Android portability

**Status:** Accepted

## Context

A native Kotlin port is planned, and a watchOS companion is wanted later. The 2023 code had **zero
lines of platform-neutral business logic** — everything lived inside SwiftUI view structs, so nothing
was reusable and nothing was testable without a simulator.

## Decision

Local Swift packages under `Packages/`, with the dependency rule pointing inward.

| Package | Constraint |
|---|---|
| `SafetyDomain` | **Pure Swift. No SwiftUI, UIKit, MapKit or CoreLocation types.** Entities, message templating, region resolution, URL building, validation |
| `SafetyContent` | UK content as structured data plus loader and validation. Ships as JSON the Kotlin port reuses verbatim |
| `SafetyServices` | Protocols plus Apple implementations. Every protocol has a test double |
| `SafetyUI` | SwiftUI views and the design system |
| `SafetyTesting` | Doubles, fixtures, golden content |

Dependency injection is constructor injection into a composition root in the app target, exposed to
views through the SwiftUI `Environment`. No singletons and no service locator.

## Consequences

- The emergency logic is unit-testable with no device, no simulator and no network.
- The watchOS companion and the Kotlin port both become cheap, because the expensive part — the
  content and the rules — is already platform-neutral.
- `SafetyDomain`'s import restriction is the rule most likely to erode through one convenient import.
  It is stated in `CLAUDE.md` and `CONTRIBUTING.md`, and should eventually be enforced in CI.
