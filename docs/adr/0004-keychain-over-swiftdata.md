# ADR-0004 — Keychain and a versioned Codable envelope, not SwiftData

**Status:** Accepted

## Context

v1.0's entire persisted user data is a short list of trusted contacts and a handful of settings
flags. The 2023 design document proposed Core Data; nothing was ever built.

Trusted contacts are sensitive: they are the people a user would turn to when fleeing someone, and
the threat model includes an abuser with access to the unlocked phone and possibly to iCloud.

## Decision

Trusted contacts live in the **Keychain** with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
Non-sensitive settings live in `UserDefaults`. Files, if any, default to `NSFileProtectionComplete`.
Schema migration is a `schemaVersion` field on a `Codable` envelope plus pure migration functions
with round-trip tests. No SwiftData and no Core Data in v1.0.

## Consequences

- `ThisDeviceOnly` is load-bearing, not a detail: items without it are eligible for iCloud Keychain
  and encrypted-backup migration, which would expose them to an abuser with iCloud access.
- SwiftData would add a migration surface and framework ceremony for a list of a few contacts.
- Migration functions being pure makes them trivially testable in `SafetyDomain`.
- Revisit if v1.1's check-in needs a richer local store. `NSFileProtectionCompleteWhenUserInactive`
  (iOS 17+) becomes relevant only if something must be written while the device is locked.
