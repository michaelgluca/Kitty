# ADR-0005 — One location snapshot, When In Use only

**Status:** Accepted

## Context

Given ADR-0002, continuous sharing is impossible without a server. The remaining question was whether
v1.0 should still run background location for a journey feature.

## Decision

v1.0 captures a **single location snapshot** at the moment the user raises an alert, using a one-shot
`CLLocationUpdate` under **When In Use** authorization. No `UIBackgroundModes`. No
`NSLocationAlwaysAndWhenInUseUsageDescription`.

## Consequences

- **When In Use location is the app's only permission.** Nothing else is requested.
- Omitting the Always purpose string entirely is a checkable signal, to App Review and to users, that
  the app *cannot* track them in the background.
- Removes the largest App Review flashpoint for safety apps, the periodic "has been using your
  location in the background" re-prompt, and the whole battery-budget question.
- The location attempt is capped at 3 seconds and **never blocks the alert** — if no fix arrives, the
  message sends saying location is unavailable.
- Reduced accuracy (~5 km) is surfaced honestly as insufficient rather than silently used.
- `CLServiceSession`'s diagnostics `AsyncSequence` provides the explicit failure states that the
  never-fail-silently rule requires.
