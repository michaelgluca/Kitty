# ADR-0012 — The alert flow and Test Mode

**Status:** Accepted

## Context

M3 builds the alert, the trusted-contact list, the 999 button and Test Mode. Several choices in it
would otherwise have to be reverse-engineered, and some of them look like omissions when they are
deliberate.

## Decision

- **The alert never shows a permission prompt.** It reads a location only if the person has already
  allowed it at full accuracy, and otherwise sends without one, saying so. Permission is asked from
  an explicit "Allow location" button on the Alert tab. A system dialog in the middle of raising an
  alert is a block, and US-1 requires that the alert never blocks on location.
- **The location attempt has a hard three-second limit** that does not rely on the location provider
  honouring its own timeout. A fix more than two minutes old is treated as no location.
- **"Sent" means handed to Messages.** iOS reports that the person tapped Send, nothing about
  delivery, so the app says it cannot confirm delivery.
- **A trusted contact needs at least seven digits after any international prefix.** That refuses
  999, 112, 101, 18000, 61016 and every other short code worldwide. The alert texts every trusted
  contact, so a short code on the list would send it to 999 or a service without the person realising.
- **The 999 button exists only in the UK stance**, dials the number from the content pack, and always
  asks first. Elsewhere the disclaimer tells the person to call their local emergency number; the app
  does not guess 112 or 911.
- **Test Mode covers every flow and is session-only.** Alert recipients become 07700 900001 upward,
  999 becomes 07700 900999, Help-screen calls and texts become 07700 900000 — all in Ofcom's reserved
  drama range. It is never saved: off at every launch, and off whenever the app goes to the
  background.
- **An unreadable contact list is never overwritten silently.** It is reported, and replacing it
  needs an explicit, confirmed "Start a new list".
- **UI tests use their own Keychain item** and DEBUG-only launch switches, so they never touch a
  developer's real contacts and the switches do not exist in release builds.

## Consequences

- Someone who never allowed location gets alerts without one until they tap "Allow location". The
  Alert tab says so before they need it.
- Test Mode left on by accident is the most dangerous state in the app. It is announced on every
  screen that can call or text, marked on the 999 button and in the message, and cannot outlive the
  session.
- App Review can exercise every flow in Test Mode with no risk of reaching a real person. The Notes
  for Review should say so.
- The Face ID lock (ADR-0010) is unaffected and remains open.
