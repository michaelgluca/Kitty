# Kitty G

A free, open-source personal safety app for iPhone, built for the UK.

**It collects nothing.** No account, no sign-in, no server, no analytics, no ads, no tracking, and no
third-party SDKs. Everything stays on your phone. When you send an alert, it goes from your phone,
through your own Messages app, to the contacts you chose — the developer cannot see it, because there
is nowhere for it to be seen.

> **Kitty G is not an emergency service and does not replace one.**
> It never contacts anyone on your behalf. Every message and every call takes an explicit action from
> you. In an emergency in the UK, call **999**.

## What it does

- **Alert your people.** Pick trusted contacts once. When you need to, two taps sends them a message
  with where you are, the time and your battery level. You review and send it yourself.
- **Call 999 deliberately.** Behind a confirmation, never automatically. iOS already sends your
  location to the 999 call handler automatically via Advanced Mobile Location — you do not need an
  app for that, and this one does not pretend to provide it.
- **Know the routes to help when you cannot speak.** Voice 999, the 55 Silent Solution, text-to-999,
  999 BSL and the 18000 relay service — all explained correctly, all available offline.
- **Find somewhere safe.** The nearest police station and other services, from your real location.
- **UK support directory.** Refuge, the National Domestic Abuse Helpline, Women's Aid, Rape Crisis,
  Victim Support, Samaritans and Citizens Advice, with accurate hours and coverage.

Works with no signal. Most of it works with no permissions at all.

## About the Silent Solution

A lot of what circulates about calling 999 silently is wrong, and believing it can cost someone their
life. The app states the following, and so does this README:

**A silent 999 call does not automatically bring police.** If you call 999 and cannot speak, listen
for the automated prompt and then press **55**. Pressing 55 tells the operator the call is genuine —
it does **not** let police track you, and it does **not** guarantee that officers will be sent. The
55 route works from a mobile only. This is the Independent Office for Police Conduct's own guidance.

## Privacy

The App Store privacy label reads **Data Not Collected**, and that is literally true rather than a
technicality. There is no backend to collect anything into.

- The only permission requested is **location, while using the app**, used on-device to find nearby
  services and to put a location in a message you send yourself.
- Trusted contacts are chosen through the system contact picker, which runs outside the app — so the
  app never gains access to your address book and never asks for Contacts permission.
- Contacts are stored in the iOS Keychain, on this device only, never synced.
- There is no logging of any personal data.

**Be aware of what the app cannot hide.** A message you send stays in Messages. A call stays in
Recents. The app appears by name in Spotlight, Settings, App Library, Screen Time and your App Store
purchase history. Kitty G does not claim to be invisible, and you should not rely on it being so. If
someone has access to your phone, Apple's own [Safety Check](https://support.apple.com/en-gb/guide/personal-safety/ips2aad835e1/web)
is built for exactly that situation.

## Building

Requires Xcode 27 or later. Minimum deployment target is iOS 26.

```bash
git clone https://github.com/michaelgluca/Kitty
cd Kitty
open Kitty.xcodeproj
```

That is the whole setup. `Local.xcconfig` is optional — the project includes it only if it exists —
so a fresh clone builds and runs in the simulator with no Apple account and no configuration. Copy
`Local.xcconfig.example` to `Local.xcconfig` and add your team ID only when you want to run on a
physical device. It is gitignored, so nothing of yours reaches the repository.

From the command line:

```bash
# All package tests
for p in Packages/*/; do swift test --package-path "$p"; done

# Build the app, no signing required
xcodebuild -project Kitty.xcodeproj -scheme Kitty \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) first. The short version: this is safety-critical
software, so correctness beats cleverness, no code path may fail silently, and the zero-collection
guarantee is enforced by CI rather than by good intentions — a pull request that adds a dependency or
a networking call will fail the build by design.

Security issues: see [SECURITY.md](SECURITY.md). Please do not open a public issue for a
vulnerability.

## Licence and name

Code is licensed under the [Apache License 2.0](LICENSE).

**The name and brand are not.** If you publish a fork, change the name, the bundle identifier and the
icon first — see [TRADEMARK.md](TRADEMARK.md). This is not territorial: a modified build that looks
like this one could mislead someone in danger.

## Origin

Kitty G began as an MSc Software Engineering dissertation at the University of Westminster in 2023.
That version was a proof of concept; this is a rebuild, and the reasoning behind each significant
decision is recorded in [docs/adr](docs/adr).

The name refers to **Catherine Susan Genovese**, known as Kitty, who was murdered in New York in
1964. Her case is usually retold as a story about bystanders who did nothing — an account first
published in 1964, substantially discredited since, and described as flawed by the newspaper that
ran it. People did call for help; the system around her failed. Her brother William has spent years
correcting that record. The app is named for her because the question her death raised — how someone
in danger reaches help, and how quickly — is still unanswered for a lot of people.

Crime statistics, where shown, contain public sector information licensed under the
[Open Government Licence v3.0](http://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).
