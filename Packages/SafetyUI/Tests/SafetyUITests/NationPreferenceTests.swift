import Foundation
import SafetyContent
import SafetyTesting
import Testing

@testable import SafetyUI

@MainActor
@Suite("Saved nation")
struct NationPreferenceTests {

    private struct Broken: Error {}

    private func loaded(_ store: InMemoryNationStore) -> NationPreference {
        let preference = NationPreference(store: store)
        preference.load()
        return preference
    }

    @Test("With nothing saved, all of the UK is shown and nothing is wrong")
    func nothingSaved() {
        let preference = loaded(InMemoryNationStore())
        #expect(preference.nation == nil)
        #expect(preference.problem == nil)
    }

    @Test("A chosen nation is saved, and read back on the next launch")
    func roundTrip() {
        let store = InMemoryNationStore()
        loaded(store).choose(.scotland)
        #expect(store.saved == "scotland")
        let next = loaded(store)
        #expect(next.nation == .scotland)
        next.choose(nil)
        #expect(store.saved == nil)
        #expect(next.nation == nil)
    }

    @Test("A saved nation that cannot be read shows all of the UK, and says so")
    func unreadable() {
        let preference = loaded(InMemoryNationStore(saved: "scotland", loadFailure: Broken()))
        #expect(preference.nation == nil)
        #expect(preference.problem == .couldNotRead)
    }

    @Test("An id this version does not know is unreadable, never another nation")
    func unknownID() {
        let preference = loaded(InMemoryNationStore(saved: "isleOfMan"))
        #expect(preference.nation == nil)
        #expect(preference.problem == .couldNotRead)
    }

    @Test("A choice that cannot be saved shows all of the UK: not the old nation, and not the new one")
    func cannotSave() {
        let store = InMemoryNationStore(saved: "scotland", saveFailure: Broken())
        let preference = loaded(store)
        #expect(preference.nation == .scotland)
        preference.choose(.wales)
        #expect(preference.nation == nil)
        #expect(preference.problem == .couldNotSave)
        #expect(store.saved == "scotland")
    }

    @Test("A later successful choice clears the problem")
    func recovers() {
        let preference = loaded(InMemoryNationStore(loadFailure: Broken()))
        #expect(preference.problem == .couldNotRead)
        preference.choose(.wales)
        #expect(preference.nation == .wales)
        #expect(preference.problem == nil)
    }

    @Test("The picker's selection reads the nation and saves a new one")
    func selection() {
        let store = InMemoryNationStore()
        let preference = loaded(store)
        preference.selection = .northernIreland
        #expect(preference.selection == .northernIreland)
        #expect(store.saved == "northernIreland")
    }

    @Test("A detected nation is offered, but not applied until the person confirms it")
    func offerNotApplied() {
        let store = InMemoryNationStore()
        let preference = loaded(store)
        #expect(preference.offer(detected: .scotland) == .scotland)
        #expect(preference.nation == nil)
        #expect(store.saveCount == 0)
        preference.choose(.scotland)
        #expect(preference.offer(detected: .scotland) == nil, "Nothing to offer once it is chosen")
        #expect(preference.offer(detected: nil) == nil)
    }

    @Test("After a move, the saved nation stays until the person switches, and the new one is flagged")
    func stale() {
        let preference = loaded(InMemoryNationStore(saved: "scotland"))
        #expect(preference.isStale(detected: .england))
        #expect(preference.offer(detected: .england) == .england)
        #expect(preference.nation == .scotland)
        #expect(!preference.isStale(detected: .scotland))
        #expect(!preference.isStale(detected: nil), "No detection is not a move")
        #expect(!loaded(InMemoryNationStore()).isStale(detected: .england),
                "With all of the UK chosen, the offer stays in the menu and is not flagged")
    }
}
