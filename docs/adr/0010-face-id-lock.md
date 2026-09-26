# ADR-0010 — Whether an app lock ships in v1.0

**Status:** Open — decision required before milestone M3

## Context

The dissertation claimed NFR5 (local authentication) as met. It was not: `unlocked` initialised to
`true`, authentication ran from `.onAppear` after the content was already on screen, nothing
anywhere set the flag false, and the settings toggle cancelled itself so the feature could never be
switched on. Nothing was encrypted behind it — it was a view condition, not a security boundary.

Rebuilt properly it needs: default-locked state, a real locked view, re-lock on `scenePhase`, a
redacted app-switcher snapshot, correct `LAError` handling with a passcode fallback, and Keychain
storage so the gate is cryptographic.

Against that, v1.0 stores only a short list of trusted contacts, and a lock costs time in an
emergency. One survey respondent said exactly that, calling it "an additional obstacle to getting
help".

## Options

1. **Do not ship it in v1.0** — recommended. The data does not yet justify the cost, and a weak lock
   invites false confidence.
2. Ship it properly, cryptographically, with an obvious bypass-free design.
3. Ship it only once v1.1 stores journey history or incident notes.

## Consequences of deferring

The honest protections for the abusive-partner threat remain: the discreet primary mark, no
notifications in v1.0, a redacted app-switcher snapshot, honest copy that does not imply the app is
hidden, and routing users to Apple's Safety Check.
