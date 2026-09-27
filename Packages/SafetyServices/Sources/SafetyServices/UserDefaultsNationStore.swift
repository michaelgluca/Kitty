import Foundation

/// The chosen nation, in the app's own preferences.
///
/// Not the Keychain. Which of four UK nations someone chose is not sensitive, and it never
/// leaves the device (ADR-0014). The privacy manifest already declares UserDefaults, for
/// this app's own use only (CA92.1).
///
/// UserDefaults does not report a failed write, so every write is read back. A value that
/// did not stick is reported, never assumed.
public final class UserDefaultsNationStore: NationStoring, @unchecked Sendable {
    // @unchecked: UserDefaults is documented as thread-safe, and nothing else here changes.
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults, key: String) {
        self.defaults = defaults
        self.key = key
    }

    public func load() throws -> String? {
        guard let value = defaults.object(forKey: key) else { return nil }
        guard let id = value as? String else { throw NationStoreFailure.unreadable }
        return id
    }

    public func save(_ nationID: String?) throws {
        if let nationID {
            defaults.set(nationID, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
        guard defaults.object(forKey: key) as? String == nationID else {
            throw NationStoreFailure.notSaved
        }
    }
}
