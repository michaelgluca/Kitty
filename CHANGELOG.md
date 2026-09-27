# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Repository foundations: `.gitignore` as the first commit, Apache-2.0 licence, `NOTICE`,
  trade mark policy, contributing guide, code of conduct and security policy.
- Architecture Decision Records under `docs/adr`.
- CI guards that fail the build on any third-party dependency, any networking symbol, any
  force unwrap in shipping code, `telprompt:`, a hardcoded emergency number, or a reference to a
  known-hostile emergency domain.
- A weekly scheduled check that every outbound URL shipped in the app still resolves.

- Five local Swift packages: `SafetyDomain` (platform-neutral core), `SafetyContent`,
  `SafetyServices`, `SafetyUI` and `SafetyTesting`.
- The app shell: Swift 6 language mode with complete strict concurrency, scene-based life cycle,
  a launch screen, a privacy manifest declaring no collection, and the String Catalog.
- Alert message composition, with 13 tests covering the branches that matter: no location, a
  reduced-accuracy fix, null-island coordinates, a missing battery reading, and locale-independent
  coordinate formatting.
- A UK content pack as structured data, with tests pinning the facts that must not regress —
  Women's Aid has no telephone helpline, the Silent Solution guidance debunks the viral version,
  text-to-999 states its registration requirement, and 18000 is described as a number you call.
- A guard that keeps `SafetyDomain` free of UI and Apple-only frameworks.

- A UK support directory verified against each operator's own page and then
  adversarially re-checked: domestic abuse lines for all four nations, sexual
  violence, victims of crime, Samaritans, and specialist lines for men and for
  LGBT+ people. Numbers are shown the way operators publish them.
- Opening hours that handle evening-only lines and different weekday and weekend
  hours, evaluated in UK time.
- Apple's built-in safety features — Emergency SOS, emergency contacts, Medical ID,
  Check In and Safety Check — with the trade-offs a user must know first.

- UK crime reporting: GOV.UK's reporting page, 101, Crimestoppers, British Transport
  Police and StreetSafe. The app never collects a report itself, and the section is
  withheld entirely outside the UK, as App Store Guideline 1.7 requires.
- Call and Text buttons that work. Text numbers, such as British Transport Police's
  61016, are held apart from voice numbers so they can never be dialled by mistake.
- The call confirmation shows the exact number that will be dialled.
- UI tests for the call confirmation and for the UK-only reporting rule.

- Trusted contacts, chosen with the system picker (no Contacts permission), kept in the Keychain on
  this device only, removable after confirmation and reorderable. 999 and every other emergency or
  service short code are refused as contacts.
- The one-tap alert: a pre-filled Messages sheet to every trusted contact, with the time, a maps link,
  plain coordinates and battery level. It never waits more than three seconds for a location, never
  prompts for permission, never sends a stale location, and says when it could not include one. If
  the phone cannot text, it says so and offers to call each contact instead.
- A 999 button, UK only, that always asks first and explains that the iPhone shares its location
  during the call.
- Test Mode: every alert, call and text goes to Ofcom's reserved drama numbers. It is announced on
  every screen that can call or text, and switches itself off when you leave the app.
- ADR-0012, recording the alert-flow and Test Mode decisions.

- A Learn tab: what the law says about women's rights, topic by topic, with every point marked with
  the UK nations it applies in and links to the official sources; and step-by-step guides to the
  iPhone's built-in safety features, with the trade-offs to know before switching each on.
- A Nearby tab: the nearest police stations on a map, with distances, a walking route to the nearest
  and walking directions in Apple Maps. Every location and search problem is shown with a way forward.
- Women's refuges: the services that can place you in a refuge in England, Wales, Scotland or Northern
  Ireland. Refuge addresses are never shown, because they are kept confidential for residents' safety.
- ADR-0013.

### Fixed
- Call buttons on the help screen did not place calls: the real dialler had not
  been wired in, so every tap reported that the call could not start.
- 101 could not be called: phone numbers required at least five digits.

### Notes
- This is a rebuild. The 2023 MSc dissertation proof of concept is preserved on the
  `archive/dissertation-2023` branch and is not the basis of this history. See ADR-0001.
