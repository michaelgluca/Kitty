# Architecture Decision Records

One file per decision that a future reader would otherwise have to reverse-engineer. Format:
Status / Context / Decision / Consequences. Never edit a decided ADR — supersede it with a new one
and update the status of the old.

| ADR | Decision | Status |
|---|---|---|
| [0001](0001-rebuild-over-refactor.md) | Clean rebuild rather than refactor | Accepted |
| [0002](0002-no-backend-and-the-messaging-constraint.md) | No backend, and what that forecloses | Accepted |
| [0003](0003-package-boundaries.md) | Local package boundaries and Android portability | Accepted |
| [0004](0004-keychain-over-swiftdata.md) | Keychain + versioned Codable, not SwiftData | Accepted |
| [0005](0005-snapshot-location-when-in-use.md) | One location snapshot, When In Use only | Accepted |
| [0006](0006-ios-26-deployment-target.md) | Minimum iOS 26 | Accepted |
| [0007](0007-no-third-party-dependencies.md) | Zero dependencies, enforced in CI | Accepted |
| [0008](0008-licence-apache-2.md) | Apache-2.0 plus a separate trade mark policy | Proposed |
| [0009](0009-name-kitty-g.md) | Name "Kitty G" despite the trade mark position | Accepted |
| [0010](0010-face-id-lock.md) | Whether an app lock ships in v1.0 | Open |
| [0011](0011-crime-map.md) | Crime map: scope and privacy | Open |
| [0012](0012-alert-flow-and-test-mode.md) | The alert flow and Test Mode | Accepted |
