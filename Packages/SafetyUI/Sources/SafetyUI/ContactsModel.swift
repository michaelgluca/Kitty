import Foundation
import Observation
import SafetyDomain
import SafetyServices
import SwiftUI

/// The trusted-contact list, as the screens see it.
///
/// Every change is saved before it is shown. If the save fails, the list on screen
/// stays as it was and the failure is reported, so the screen never shows a contact
/// who will be gone at the next launch.
@MainActor
@Observable
public final class ContactsModel {

    public enum LoadState: Equatable, Sendable {
        case notLoaded
        case loaded
        /// The stored list exists but cannot be read — written by a newer build, or
        /// damaged. Editing is refused until the person explicitly starts a new list,
        /// so nothing silently overwrites contacts that may still be recoverable.
        case unreadable
    }

    public enum Problem: Equatable, Sendable {
        case rejected(TrustedContactRejection, number: String)
        case saveFailed
        case pickerUnavailable
    }

    public private(set) var contacts: [TrustedContact] = []
    public private(set) var loadState: LoadState = .notLoaded
    public var problem: Problem?

    public var canEdit: Bool { loadState == .loaded }

    private let store: any TrustedContactStoring
    private let picker: any ContactPicking

    public init(store: any TrustedContactStoring, picker: any ContactPicking) {
        self.store = store
        self.picker = picker
    }

    public func load() {
        do {
            contacts = try store.load()
            loadState = .loaded
        } catch {
            contacts = []
            loadState = .unreadable
        }
    }

    public func addFromPicker() async {
        guard canEdit else { return }
        switch await picker.pickContact() {
        case .cancelled:
            return
        case .unavailable:
            problem = .pickerUnavailable
        case let .picked(picked):
            switch TrustedContactRules.make(displayName: picked.displayName, rawNumber: picked.phoneNumber, existing: contacts) {
            case let .failure(reason):
                problem = .rejected(reason, number: picked.phoneNumber)
            case let .success(contact):
                commit(contacts + [contact])
            }
        }
    }

    public func remove(id: TrustedContact.ID) {
        guard canEdit else { return }
        commit(contacts.filter { $0.id != id })
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard canEdit else { return }
        var reordered = contacts
        reordered.move(fromOffsets: source, toOffset: destination)
        commit(reordered)
    }

    /// Replaces an unreadable stored list with an empty one. The screen asks for
    /// confirmation first, because what it replaces may be recoverable by updating
    /// the app.
    public func startNewList() {
        guard loadState == .unreadable else { return }
        do {
            try store.save([])
            contacts = []
            loadState = .loaded
        } catch {
            problem = .saveFailed
        }
    }

    private func commit(_ updated: [TrustedContact]) {
        do {
            try store.save(updated)
            contacts = updated
        } catch {
            problem = .saveFailed
        }
    }
}
