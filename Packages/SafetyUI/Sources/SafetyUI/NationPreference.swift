import Foundation
import Observation
import SafetyContent
import SafetyServices

/// The UK nation the person chose, shared by Get help, Learn and Refuges and remembered
/// on this device. Changing it anywhere changes it everywhere.
///
/// Only ever set by the person. A nation detected from their location is offered
/// (`offer(detected:)`) and never applied without a tap. When the store fails, the screens
/// say so and show all of the UK, never a nation from before and never a guess.
///
/// `RootView` must inject this into the Environment, loaded before the first frame.
@MainActor
@Observable
final class NationPreference {

    enum Problem: Equatable, Sendable {
        case couldNotRead
        case couldNotSave
    }

    /// `nil` means all of the UK.
    private(set) var nation: Nation?
    private(set) var problem: Problem?

    private let store: any NationStoring

    init(store: any NationStoring) {
        self.store = store
    }

    func load() {
        do {
            guard let id = try store.load() else {
                nation = nil
                problem = nil
                return
            }
            // An id this version does not know, perhaps written by a later one, is not
            // mapped to the nearest thing: it is reported.
            guard let saved = Nation(rawValue: id) else {
                nation = nil
                problem = .couldNotRead
                return
            }
            nation = saved
            problem = nil
        } catch {
            nation = nil
            problem = .couldNotRead
        }
    }

    /// Saves the person's choice. If it cannot be saved, the screens show all of the UK
    /// and say so, rather than the old nation (which is no longer what they want) or the
    /// new one (which would silently be lost at the next launch).
    func choose(_ newNation: Nation?) {
        do {
            try store.save(newNation?.rawValue)
            nation = newNation
            problem = nil
        } catch {
            nation = nil
            problem = .couldNotSave
        }
    }

    /// For a `Picker`: reading gives the nation shown, and setting saves the choice.
    var selection: Nation? {
        get { nation }
        set { choose(newValue) }
    }

    /// The nation Nearby detected, if it is not already the one chosen. Offered in the
    /// nation menu; applied only by `choose(_:)`.
    func offer(detected: Nation?) -> Nation? {
        guard let detected, detected != nation else { return nil }
        return detected
    }

    /// Whether a saved nation differs from where Nearby last found the person: they may
    /// have moved. Flagged as a visible row rather than only inside the menu, and never
    /// applied without a tap.
    func isStale(detected: Nation?) -> Bool {
        guard let nation, let detected else { return false }
        return nation != detected
    }
}
