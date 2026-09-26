# ADR-0008 — Apache-2.0, plus a separate trade mark policy

**Status:** Proposed — recommended in the approved plan; confirm before the repository is published

## Context

Copyleft on the App Store is legally contested and practically tolerated: Signal, Element and
Bitwarden all ship AGPL or GPL binaries. It works because each is a sole copyright holder with a CLA,
so nobody has standing to complain. The FSF's position — that Apple's Usage Rules are "further
restrictions" barred by GPLv2 §6 / GPLv3 §10 — is live, and Apple's documented response to a credible
complaint is takedown, as with GNU Go and VLC. **For a safety app an App Store takedown is a
user-safety event, not a business inconvenience.**

LGPL fits iOS badly, because the relink requirement conflicts with static linking and code signing.
MPL-2.0 is the one clean copyleft option and is what VLC chose to solve this exact problem.

## Decision

**Apache-2.0** for the code, plus a separate `TRADEMARK.md`.

## Consequences

- Strongest patent position of the candidates: §3 grants an express patent licence with a
  litigation-termination trigger. MIT and BSD-3-Clause grant none.
- §6 withholds trade mark rights, but only defensively — it stops a forker claiming the licence gave
  them the name; it creates no trade mark right.
- Real protection against a misleading fork comes from the separate trade mark policy plus
  registration, following the Signal / Bitwarden / Element pattern: code open, brand not. Apple's
  guidelines 4.1, 4.3 and 5.2.1 are the enforcement route, and they work better with a registered mark.
- **MPL-2.0 remains a reasonable alternative** if copyleft teeth are wanted: it would force a clone's
  modifications to our own files to stay open. It would not stop a forker adding new proprietary files.
