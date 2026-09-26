# Contributing

Thank you for considering it. Please read this before opening a pull request — this project has
constraints that are unusual, and several of them will fail your build automatically if you have not
read them first.

## The constraints that are not negotiable

These exist because people may rely on this app in a genuine emergency. A change that breaches one
will be declined regardless of how good it is otherwise.

1. **Zero data collection.** No accounts, no backend, no analytics, no ads, no tracking, no
   third-party SDKs that transmit anything. The App Store privacy label must honestly read *Data Not
   Collected*.
2. **The user controls every transmission.** Anything leaving the device goes through channels the
   user operates — Messages, calls, the share sheet. The maintainer must never be able to read it.
3. **Safety-critical reliability.** Core flows work offline, take as few taps as possible, **never
   fail silently**, and degrade gracefully when a permission is denied. The app never contacts
   emergency services without an explicit user action, and every flow must be testable without
   contacting real emergency services.
4. **Apple frameworks only.** There are currently **zero** third-party dependencies and we intend to
   keep it that way. SPM only if that ever changes.

**CI enforces items 1 and 4 mechanically.** A pull request that adds a package dependency or a
networking symbol fails the build. That is intentional — the guarantee should not depend on anyone
remembering it during review.

## Hard rules in code

- **No force unwraps in shipping code.** No `!` on optionals, no `try!`, no `as!`. Tests may.
- **No silent failures.** Every error path produces something the user can see. A bare `try?` that
  swallows an error is a defect, not a style preference.
- **No placeholder data in a real code path.** The 2023 proof of concept computed every map route
  from a hardcoded Trafalgar Square coordinate, so a user in Manchester got confident directions from
  the wrong city with no error shown. Never ship a fallback that is indistinguishable from real data.
- **No user-facing string literals.** Everything goes through the String Catalog. CI checks this.
- **`tel:` never `telprompt:`**, and never dial automatically.
- **Do not log personal data.** `os.Logger` with `privacy: .private`. Never a coordinate, a contact
  detail or a message body.
- **Keychain items are always `...ThisDeviceOnly`**, so nothing can migrate through iCloud Keychain
  or an encrypted backup to a device an abuser controls.
- **`SafetyDomain` imports no UI framework.** No SwiftUI, no UIKit, no MapKit, no CoreLocation types.
  This keeps the emergency logic testable without a device and keeps a future Android port cheap. It
  is the rule most easily eroded by one convenient import.

## Changing safety content

Phone numbers, helpline details, links and guidance are treated as **code, not copy**. A wrong number
or a dead link in this app has real consequences.

- Every change must cite the **issuing body's own page** — the police force, the charity, gov.uk. Not
  a news article, not a blog, not another app, not an LLM.
- Every outbound URL goes on the allowlist and is checked by CI.
- Be aware that well-known sources go bad: `emergencysms.org.uk`, still linked from several UK police
  and fire service websites, has been taken over and now serves a gambling affiliate site. Verify the
  destination by loading it, every time.
- Do not repeat the viral version of the Silent Solution. A silent 999 call does not bring police,
  and pressing 55 does not let police track you.

## Workflow

1. Open an issue first for anything beyond a small fix, so we can agree the approach before you spend
   time on it.
2. Branch from `main`. Keep the change focused.
3. **Write tests alongside the code. Test-first for anything in the alert or 999 path.**
4. [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `chore:`,
   `refactor:`, `test:`.
5. **Sign off every commit** with `git commit -s` — this project uses the
   [Developer Certificate of Origin](https://developercertificate.org/). CI checks it.
6. Open the pull request and fill in the template.

## Definition of Done

- [ ] Tests written alongside; test-first for alert and 999 paths
- [ ] No force unwraps; every error branch has a visible state and a test
- [ ] Every user-facing string in the String Catalog
- [ ] VoiceOver verified; layout checked at AX5 Dynamic Type with no clipping
- [ ] Checked in light and dark, with Increase Contrast and Reduce Transparency on
- [ ] No new dependency, no new networking call
- [ ] An ADR added under `docs/adr/` if a decision was made that a future reader would otherwise have
      to reverse-engineer
- [ ] CI green

## Testing emergency flows

**Never dial 999 in a test, manual or automated.** Test Mode substitutes numbers from Ofcom's
reserved drama range `07700 900000`–`900999`, which cannot reach a real recipient. If you are adding
a flow that sends or calls, it must be reachable in Test Mode, and a reviewer must be able to
exercise it end to end without contacting anyone.

## Security

Do not open a public issue for a vulnerability — see [SECURITY.md](SECURITY.md). Note that incorrect
emergency information is treated as a security issue.

## Forks

The code is Apache-2.0; the name and icon are not. If you publish a fork, change the name, bundle
identifier and icon first — see [TRADEMARK.md](TRADEMARK.md). A modified build that looks like this
one could mislead someone in danger, which is the entire reason that policy exists.

## Code of Conduct

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).
