import Foundation
import SafetyDomain
import SafetyServices
import SafetyTesting
import Testing

@testable import SafetyUI

private struct Boom: Error {}

private let carol = ContactPickOutcome.picked(PickedContact(displayName: "Carol", phoneNumber: "07700 900003"))

@MainActor
@Suite("Trusted contacts model")
struct ContactsModelTests {

    private func model(
        _ store: InMemoryContactStore = InMemoryContactStore(),
        picks: [ContactPickOutcome] = []
    ) -> ContactsModel {
        let model = ContactsModel(store: store, picker: StubContactPicker(picks))
        model.load()
        return model
    }

    @Test("Loads what was saved, in order")
    func loads() {
        let m = model(InMemoryContactStore(contacts: SafeTestNumbers.contacts))
        #expect(m.loadState == .loaded)
        #expect(m.canEdit)
        #expect(m.contacts.map(\.displayName) == ["Alice (test)", "Bob (test)"])
    }

    @Test("An unreadable list is reported rather than shown as empty, and nothing can be saved over it")
    func unreadable() async {
        // Written by a newer build, or damaged. The contacts may come back if the app
        // is updated, so an edit here must not silently replace them.
        let store = InMemoryContactStore(loadFailure: Boom())
        let m = model(store, picks: [carol])
        #expect(m.loadState == .unreadable)
        #expect(!m.canEdit)

        await m.addFromPicker()
        m.move(fromOffsets: IndexSet(integer: 0), toOffset: 0)
        #expect(store.saveCount == 0)
    }

    @Test("Starting a new list replaces an unreadable one, and only that")
    func startNewList() {
        let store = InMemoryContactStore(loadFailure: Boom())
        let m = model(store)
        m.startNewList()
        #expect(m.loadState == .loaded)
        #expect(m.contacts.isEmpty)
        #expect(store.saveCount == 1)

        // Once readable, it does nothing.
        m.startNewList()
        #expect(store.saveCount == 1)
    }

    @Test("Adding a picked contact saves it and shows it")
    func adds() async {
        let store = InMemoryContactStore()
        let m = model(store, picks: [carol])
        await m.addFromPicker()
        #expect(m.contacts.map(\.displayName) == ["Carol"])
        #expect(store.saved.map(\.displayName) == ["Carol"])
        #expect(m.problem == nil)
    }

    @Test("Refuses 999 with a reason the person can read")
    func refuses999() async {
        let m = model(picks: [.picked(PickedContact(displayName: "Police", phoneNumber: "999"))])
        await m.addFromPicker()
        #expect(m.contacts.isEmpty)
        #expect(m.problem == .rejected(.serviceNumber, number: "999"))
    }

    @Test("Refuses a duplicate, naming who already has the number")
    func refusesDuplicate() async {
        // SafeTestNumbers.alice is +447700900001, saved as "Alice (test)".
        let m = model(
            InMemoryContactStore(contacts: SafeTestNumbers.contacts),
            picks: [.picked(PickedContact(displayName: "Alice again", phoneNumber: "07700 900001"))]
        )
        await m.addFromPicker()
        #expect(m.contacts.count == 2)
        #expect(m.problem == .rejected(.duplicate(existingName: "Alice (test)"), number: "07700 900001"))
    }

    @Test("Cancelling the picker changes nothing and reports nothing")
    func cancel() async {
        let store = InMemoryContactStore()
        let m = model(store, picks: [.cancelled])
        await m.addFromPicker()
        #expect(m.contacts.isEmpty)
        #expect(m.problem == nil)
        #expect(store.saveCount == 0)
    }

    @Test("A picker that cannot open says so")
    func pickerUnavailable() async {
        let m = model(picks: [.unavailable])
        await m.addFromPicker()
        #expect(m.problem == .pickerUnavailable)
    }

    @Test("A failed save leaves the list as it was, and says so")
    func saveFails() async {
        let store = InMemoryContactStore(contacts: SafeTestNumbers.contacts, saveFailure: Boom())
        let m = model(store, picks: [carol])

        await m.addFromPicker()
        #expect(m.contacts.count == 2)
        #expect(m.problem == .saveFailed)

        m.problem = nil
        m.remove(id: m.contacts[0].id)
        #expect(m.contacts.count == 2)
        #expect(m.problem == .saveFailed)
    }

    @Test("Removing and reordering are saved before they are shown")
    func removeAndMove() {
        let store = InMemoryContactStore(contacts: SafeTestNumbers.contacts)
        let m = model(store)

        m.move(fromOffsets: IndexSet(integer: 1), toOffset: 0)
        #expect(store.saved.map(\.displayName) == ["Bob (test)", "Alice (test)"])
        #expect(m.contacts == store.saved)

        m.remove(id: m.contacts[0].id)
        #expect(store.saved.map(\.displayName) == ["Alice (test)"])
        #expect(m.contacts == store.saved)
    }

    @Test("If starting a new list cannot be saved, the unreadable list stays unreadable and says so")
    func startNewListFails() {
        let store = InMemoryContactStore(loadFailure: Boom(), saveFailure: Boom())
        let m = model(store)
        m.startNewList()
        #expect(m.loadState == .unreadable)
        #expect(!m.canEdit)
        #expect(m.contacts.isEmpty)
        #expect(m.problem == .saveFailed)
    }
}
