import Foundation
import Testing

@testable import SafetyServices

@Suite("Saved nation in UserDefaults")
struct NationStoreTests {

    /// A throwaway defaults domain and key per test, removed afterwards, so tests never
    /// touch the app's own preferences or each other's.
    private func withStore(_ body: (UserDefaults, String) throws -> Void) throws {
        let suite = "kitty.tests.nation.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults, "nation.saved.\(UUID().uuidString)")
    }

    @Test("Nothing saved reads as nothing chosen")
    func empty() throws {
        try withStore { defaults, key in
            let loaded = try UserDefaultsNationStore(defaults: defaults, key: key).load()
            #expect(loaded == nil)
        }
    }

    @Test("A saved nation id reads back, including on the next launch, and clearing it reads as nothing chosen")
    func roundTrip() throws {
        try withStore { defaults, key in
            let store = UserDefaultsNationStore(defaults: defaults, key: key)
            try store.save("scotland")
            #expect(try store.load() == "scotland")
            // A second store on the same defaults stands in for the next launch.
            #expect(try UserDefaultsNationStore(defaults: defaults, key: key).load() == "scotland")
            try store.save(nil)
            #expect(try store.load() == nil)
        }
    }

    @Test("Something stored that is not a nation id is reported as unreadable, never guessed at")
    func unreadable() throws {
        try withStore { defaults, key in
            defaults.set(42, forKey: key)
            #expect(throws: NationStoreFailure.unreadable) {
                try UserDefaultsNationStore(defaults: defaults, key: key).load()
            }
        }
    }

    @Test("A write that does not stick is reported, not assumed")
    func writeThatDoesNotStick() throws {
        try withStore { defaults, key in
            // A registered default survives removeObject, so clearing the choice cannot
            // take effect: the silent failure the read-back exists to catch.
            defaults.register(defaults: [key: "wales"])
            #expect(throws: NationStoreFailure.notSaved) {
                try UserDefaultsNationStore(defaults: defaults, key: key).save(nil)
            }
        }
    }
}
