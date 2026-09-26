# ADR-0007 — Zero third-party dependencies, enforced in CI

**Status:** Accepted

## Context

The 2023 proof of concept had zero dependencies — incidentally rather than deliberately. That absence
is doing real work: Apple's signed-SDK and SDK-privacy-manifest requirements apply only to SDKs on
Apple's published list, so having none removes signature validation, manifest merging and third-party
disclosure obligations entirely. It is also what makes "Data Not Collected" straightforwardly true.

A single analytics, crash-reporting or attribution library added by a future contributor would break
the privacy label and make the maintainer a data controller under UK GDPR.

## Decision

No third-party dependencies. If one ever becomes necessary it requires an ADR justifying it on
privacy, security, licence and maintenance grounds. **CI fails the build on any new package
dependency and on any networking symbol.**

## Consequences

- The guarantee is enforced mechanically rather than by reviewer discipline.
- Also declined for the same reason: `CrashReportExtension` (iOS 27), whose documented purpose is
  posting crash reports to a developer-run server; `MetricKit`; and CloudKit.
- Crash diagnostics come only from Apple's consented Xcode Organizer channel, where Apple states
  "You are not responsible for disclosing data collected by Apple."
- Some things will be built by hand that a package would provide. That is the accepted cost.
