# ADR-0011 — Crime map: scope and privacy

**Status:** Open — decision required before milestone M4

## Context

`data.police.uk` is live, keyless and Open Government Licence v3.0 (attribution required), rate
limited to 15 requests per second, updated monthly with a 2–3 month lag, and its coordinates are
deliberately snapped to anonymised points covering at least eight addresses each.

Two problems:

1. **Privacy.** Querying it puts the user's coordinates in a GET query string, sent to a Home Office
   host from the user's IP. This is the only feature that breaks an otherwise perfect offline,
   zero-network story.
2. **Guideline 1.7** — "Apps for reporting alleged criminal activity must involve local law
   enforcement, and can only be offered in countries or regions where such involvement is present."
   A directly comparable app, SafeSpot, was rejected under 1.7 for user-taggable reports.

There is also a safety concern in its own right: presenting data that is two to three months old as a
signal about a street right now could induce false confidence.

## Options

1. **Read-only official data, coordinates rounded to ~1 km, UK-gated, labelled with the exact data
   month** — recommended. The API's radius is a mile regardless, so precision buys nothing.
2. **Drop the crime map.** Keep only the police-station finder via `MKLocalSearch`, which needs no
   third-party host and preserves a perfect zero-network story.
3. Keep as designed and accept the risk.

## Regardless of the option chosen

The crime-**reporting** deep links are UK-gated, because of guideline 1.7's "countries or regions
where such involvement is present" clause. Never render crime points as precise pins on doorways, and
filter `(0, 0)` coordinates or they plot in the Gulf of Guinea.
