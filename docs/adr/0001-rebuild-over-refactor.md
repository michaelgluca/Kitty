# ADR-0001 — Clean rebuild rather than refactor

**Status:** Accepted

## Context

The 2023 dissertation proof of concept is 783 lines across 14 files. It **builds clean** on Xcode 27
(0 errors, 3 warnings) and is one build setting from Swift 6 strict concurrency, so "it no longer
compiles" is not the argument.

The argument is that there is nothing structural to preserve and the behaviour is wrong. The
`Model/View/Controller` folders are labels only — commit `ad2d251` ("move contentView to controller")
moved a file between folders with a zero-line diff. There are 0 ViewModels, 0 protocols, 0 injection
points, 0 tests, and no abstraction over `UIApplication`, `MapKit` or `LAContext`. All non-view logic
is roughly 60 lines across six functions, and every one of them is defective: the Face ID gate never
gates, the emergency SMS targets a number that does not receive SMS, the map computes every route
from a hardcoded Trafalgar Square coordinate, and no location permission is declared at all.

## Decision

Rebuild. Carry forward the **content** (advice taxonomy, resource directory, URL set), the
**design** (four-tab information architecture, visual identity) and the **domain research**. Carry
forward no code.

## Consequences

- Refactoring 783 lines of subtly wrong safety-critical code with no test suite to hold it in place
  would cost more than rewriting it, and would risk preserving defects bug-for-bug.
- Each project constraint independently touches most of the file set: Swift 6 concurrency requires
  restructuring the auth callback; String Catalogs require touching every string; never-fail-silently
  requires an error architecture that does not exist; testable-without-999 requires a substitution
  seam at every call site; the Android port requires platform-neutral content.
- One real asset transfers for free: the zero-collection posture is already complete, because it is
  an *absence* of code — no `URLSession`, no analytics, no SPM packages.
- The 2023 history is preserved locally on `archive/dissertation-2023`.
