## What and why

<!-- What changes, and what problem it solves. Link the issue. -->

## Definition of Done

- [ ] Tests written alongside the code; **test-first** if this touches the alert or 999 path
- [ ] No force unwraps; every error branch has a user-visible state and a test
- [ ] Every user-facing string is in the String Catalog
- [ ] VoiceOver verified; layout checked at AX5 Dynamic Type with no clipping
- [ ] Checked in light and dark, with Increase Contrast and Reduce Transparency on
- [ ] No new dependency and no new networking call
- [ ] An ADR added under `docs/adr/` if this makes a decision worth recording
- [ ] Commits signed off (`git commit -s`)

## Safety

- [ ] No flow can reach a real recipient or dial 999 in any test — Test Mode uses Ofcom's reserved
      drama range `07700 900000`–`900999`
- [ ] Any content change cites the issuing body's own page
- [ ] Nothing here implies the app contacts anyone automatically, or that it can hide itself
