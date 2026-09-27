# ADR-0013 — Learn and Nearby: rights, iPhone features, police stations and refuges

**Status:** Accepted

## Context

The app gained three sections: what the law says about women's rights, how to use the iPhone's
built-in safety features, and — on a Nearby tab — directions to the nearest police station and a
list of women's refuges. Each involves a choice a future reader would otherwise have to
reverse-engineer, and one of them is a deliberate refusal.

## Decision

- **Refuge addresses are never shown, searched for or put on a map.** UK refuge addresses are kept
  confidential for residents' safety. A "shelters near me" feature would be a tool for an abuser
  holding the phone to find someone who fled. The refuges list is therefore the services that place
  women in refuge — national helplines, official local-service directories, and the council or
  Housing Executive route — for the person's nation, with the reason addresses are withheld on
  screen.
- **The police-station finder is MapKit only** (plan §3.5, option (b)): an `MKLocalSearch` for
  "police station", limited to points of interest in the police category, within 2 km, then 8 km,
  then 25 km. Every step uses the same query and category, and every result must then pass the name
  rule below and fall inside that step's radius. Coordinates go only to Apple. There is no crime
  map; ADR-0011 stays open.
- **The station search asks for "police station" within the police category, then keeps only
  results that read as a police station.** Apple's `.police` points-of-interest category also
  returned a police telephone box and a crime museum as the "nearest station" in testing, and
  directing someone in danger there is a safety failure. A pure, tested rule filters the raw MapKit
  results by name before anything reaches the screen. It checks a reject list first, by whole word:
  "museum" (and the Welsh "amgueddfa"), "former", "closed", "telephone", "old police station",
  "police box" and "phone box", because those places also read as a station by name. It then accepts
  the wording of all four nations: "police station" (or "police" and "station" anywhere in the
  name), "police office", "PSNI", "Police Service of Northern Ireland", and the Welsh "gorsaf" together with "heddlu" ("Gorsaf Heddlu", "Gorsaf yr
  Heddlu"). A nation's wording left out hides its nearer stations and shows a farther one as nearest,
  so it is a defect, not a nicety. The cost is that a real station with an unusual name may be
  filtered out; the Apple Maps hand-off and the 999 note mitigate a missed real station, which is
  recoverable in a way that a wrong destination is not. The note shows whenever a station was looked
  for: beside a station found, and when none was found, the search could not run or there was no
  fix.
- **A Nearby result is never shown as current once it may not be.** A found result records when its
  location was read, from the injected time source, and is stale after 5 minutes. When the tab
  appears, or the app becomes active with the tab open, the model searches again unless a search is
  already running: always when there is no result, and for a result once it is stale. A current
  result is not searched again on every tab switch. While a search replaces a result, the old one
  stays on screen under a line saying it is from the last search, and its detected nation is
  withdrawn, so the refuge list asks. Any state the search ends in drops the old result, so a failed
  search shows its failure and never leaves an old result looking current.
- **A station's distance is in a straight line, and says so.** Only the walking route to the nearest
  station is measured along paths; the other rows show the straight-line distance, which reads
  "away in a straight line" so it is not taken for the walk.
- **Every Nearby network wait is time-limited**, so a hung MapKit call can never leave the screen
  spinning forever: the nation lookup 5 seconds, each search step 10 seconds, the walking route 10
  seconds. A route that times out still shows the station and its distance — orientation without a
  drawn line is still useful. The station search never waits on the nation lookup; the two run
  independently so a slow nation guess cannot delay a result someone needs quickly.
- **Walking directions hand off to Apple Maps.** Kitty G draws one walking route to the nearest
  station for orientation, and does not navigate.
- **Nearby is a second, on-screen use of When-In-Use location**, beyond ADR-0005's single snapshot
  taken at alert time: a live search while the Nearby tab is open, shown against the system's own
  location dot on the map. Coordinates go only to Apple, through MapKit. This still needs no new
  permission and no Always permission — the existing When-In-Use grant covers both uses.
- **The nation comes from reverse geocoding, or the person chooses.** The nation is read from the
  last part of the geocoded address, not from MapKit's region name, which is the country ("United
  Kingdom") and not the nation. Only a name that is exactly a nation's counts; nothing is inferred
  from a street name or the phone's region. A nation detected on an earlier search is cleared if a
  later search cannot confirm one, so a stale nation is never shown as if it came from the current
  location — the person picks instead. The app never assumes England. Outside the UK there is no
  refuge list at all.
- **There is no "open Apple Maps" action when location is unavailable.** There is no MapKit API to
  open a Maps search without a coordinate, and a `maps://` URL would add both an allowlist entry and
  new egress surface for a button of limited value. Each no-location state (denied, restricted, no
  signal, search failed) explains itself on screen and offers only the ways forward that actually
  exist for that state — allow location, open Settings, or search again.
- **Rights content is nation-tagged general information**, and every topic cites every official
  source it relies on, with no numeric limit on how many. An earlier cap on sources per topic was
  tried and reverted: it silently dropped true, verified protections that were specific to Northern
  Ireland, which is a worse defect than a long source list. Every point says where it applies,
  "across the UK" only when true in all four nations, and every topic says it is not legal advice.
- **The iPhone guides live on the Learn tab**, with a link left on the Help tab, so the same verified
  content is not duplicated on two screens.
- **UI tests stub location, places, route and region** through DEBUG-only launch switches, so no
  automated test depends on a live network call or a real device location. The live MapKit path —
  real points of interest, real routes, the police-station name filter — is checked by manual
  simulator runs at UK-wide test points, recorded in the workspace's task reports.
- **All of this is content**, built from research checked against primary sources; every URL is on
  the CI-checked allowlist with its page title. A few official pages refuse CI's runners outright or
  serve no page title at all; those carry dated manual entries on the allowlist rather than being
  dropped, because dropping them would remove a verified source, not a broken one.
- **Content that describes a law change on a future date is written as future**, not as already in
  force. The dates to recheck before release are the dates something in the pack's rights content
  changes. Each is listed with the rights topic id or ids in `uk-content.json` it affects:
  - 29 Sep 2026: the England and Wales exposure offence commences (`harassment-in-public`; the pack
    makes no exposure claim today).
  - 1 Oct 2026: Police Scotland must refer victims to victim support (`victims-rights`). The same
    day, the employment tribunal limit changes in `rights-at-work`, already written as future.
  - 30 Oct 2026: the employer "all reasonable steps" duty to prevent sexual harassment
    (`rights-at-work`; not in the pack until a commencement order is made).
  - 16 Nov 2026: Scottish victim statements in solemn cases (`victims-rights`).
  - 24 Nov 2026: the domestic abuse protection order pilot ends (`protection-orders`).

## Consequences

- Someone looking for a refuge is sent to the people who can place her, which is how refuge access
  works in the UK. The app cannot show that a refuge is "2 miles away", and says why.
- The police finder needs a connection and a precise location. Each missing piece is its own state on
  screen, and reduced accuracy is stated as not precise enough.
- Police front counters keep limited hours; the screen says so, with 999 in the UK.
- A real police station with an unusual name — one that does not read as a police station by name —
  can be hidden by the name filter. The Apple Maps hand-off and the 999 note are the mitigation, not
  a fix; this is a deliberate trade against showing a telephone box or a museum as "nearest station".
- The content will go stale as law and services change. The weekly URL check catches moved pages; the
  facts themselves need a periodic human review, dated in the pack's `reviewedOn`, and the five dates
  above need a specific recheck before release.
- Manual allowlist entries for pages that refuse CI runners are unverified by CI on every run; they
  rely on the dated manual check staying current.
