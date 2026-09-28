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

    /// A choice made this session that could not be saved. A plain `Nation?` cannot
    /// represent this: a failed choice can itself be "all of the UK", which must be told
    /// apart from no failed choice at all, or the two collapse to the same `nil`.
    struct UnsavedChoice: Equatable, Sendable {
        /// `nil` when the failed choice was "all of the UK" itself, not a nation.
        let nation: Nation?
    }

    /// `nil` means all of the UK.
    private(set) var nation: Nation?
    private(set) var problem: Problem?
    /// Get help and Learn never read this — they fall back to all of the UK, as `problem`
    /// alone says to. Refuges needs a nation to list, so it shows the one named here
    /// instead, with its own wording, for as long as the failure it belongs to is current.
    /// Never persisted, and never left over: cleared by any later choice, saved or not, so
    /// it cannot reattach to an unrelated failure.
    private(set) var unsavedChoice: UnsavedChoice?

    private let store: any NationStoring

    init(store: any NationStoring) {
        self.store = store
    }

    func load() {
        unsavedChoice = nil
        (nation, problem) = Self.saved(in: store)
    }

    private static func saved(in store: any NationStoring) -> (Nation?, Problem?) {
        do {
            guard let id = try store.load() else { return (nil, nil) }
            // An id this version does not know, perhaps written by a later one, is not
            // mapped to the nearest thing: it is reported.
            guard let saved = Nation(rawValue: id) else { return (nil, .couldNotRead) }
            return (saved, nil)
        } catch {
            return (nil, .couldNotRead)
        }
    }

    /// Saves the person's choice. If it cannot be saved, the screens show all of the UK
    /// and say so, rather than the old nation (which is no longer what they want, though
    /// the store still holds it, so it returns at the next launch) or the new one (which
    /// would silently be lost at the next launch). Every call, whether it succeeds or
    /// fails, replaces whatever `unsavedChoice` held before — a failure never outlives
    /// itself by attaching to a later, unrelated one.
    func choose(_ newNation: Nation?) {
        do {
            try store.save(newNation?.rawValue)
            nation = newNation
            problem = nil
            unsavedChoice = nil
        } catch {
            nation = nil
            problem = .couldNotSave
            unsavedChoice = UnsavedChoice(nation: newNation)
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
    func isStale(detected: Nation) -> Bool {
        guard let nation else { return false }
        return nation != detected
    }
}
