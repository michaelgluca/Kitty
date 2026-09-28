import SafetyContent
import SafetyDomain
import SafetyServices
import SwiftUI

/// Women's refuges near you — as the services that place women in refuge, never as
/// addresses. Refuge addresses are confidential, and a feature that found them would
/// hand an abuser the means to find someone who fled (ADR-0013).
///
/// Lists the nation the person chose, which Get help and Learn share (ADR-0014).
///
/// `RootView` must inject the `NationPreference` this screen reads from the
/// Environment, and the `NearbyModel` that `NearbyScreen` reads to pass this screen's
/// `detected`.
struct RefugesScreen: View {

    @Environment(\.services) private var services
    @Environment(NationPreference.self) private var nationPreference

    let pack: ContentPack?
    /// Where Nearby found the person, refreshed each time the parent redraws.
    let detected: Nation?

    var body: some View {
        let shown = Self.nationShown(saved: nationPreference.nation, unsavedChoice: nationPreference.unsavedChoice, detected: detected)
        ServiceContactHost { contact in
            List {
                if let pack {
                    Section {
                        VStack(alignment: .leading, spacing: Design.Space.tight) {
                            Text(pack.refugeNote.text).fixedSize(horizontal: false, vertical: true)
                            if let url = URL(string: pack.refugeNote.source.url) {
                                Link(destination: url) { Text(pack.refugeNote.source.title).font(.subheadline) }
                            }
                        }
                        .accessibilityIdentifier("refuges.why")
                    } header: {
                        Text("refuges.why.header", bundle: .module)
                    }

                    RefugesNationSection(preference: nationPreference, detected: detected, shown: shown, pick: pick)
                    RefugeListSection(pack: pack, nation: shown.nation, now: services.time.now, contact: contact)
                } else {
                    // The pack is bundled, so this should be unreachable in a real
                    // install — but reachable in DEBUG (-kitty.withoutContent), and a
                    // silent empty screen would read as "there are no refuges", which is
                    // both false and dangerous.
                    ContentUnavailableNotice(titleKey: "refuges.unavailable.title", bodyKey: "refuges.unavailable.body")
                }
            }
        }
        .navigationTitle(Text("refuges.title", bundle: .module))
    }

    /// Saves the pick for every screen. If it cannot be saved, `NationPreference` keeps it
    /// for this screen only. A `nil` pick is ignored: the picker offers one only until a
    /// nation is shown, but this guards the same rule at the point where it matters, so
    /// choosing here can never reset the nation Get help and Learn share back to all of
    /// the UK.
    private func pick(_ nation: Nation?) {
        guard let nation else { return }
        nationPreference.choose(nation)
    }
}

/// Which nation the refuge list is for, and where it came from. `isUnsavedPick` is true
/// only when the list shows a pick that could not be saved.
struct NationShown: Equatable {
    let nation: Nation?
    let isFromLocation: Bool
    let isUnsavedPick: Bool
}

extension RefugesScreen {

    /// The order of precedence:
    /// 1. The person's saved choice, shared with Get help and Learn.
    /// 2. A pick made here that could not be saved — but only when it named a nation.
    ///    A failed pick of "all of the UK" is not a nation to list, so it is treated
    ///    exactly as if there had been no unsaved pick at all, and falls through.
    /// 3. Until they choose, the nation found from their location. It is shown so the
    ///    list is there at once, labelled as such, and never saved: a location is
    ///    offered, never chosen for the person.
    /// 4. Otherwise none, and the screen asks.
    static func nationShown(saved: Nation?, unsavedChoice: NationPreference.UnsavedChoice?, detected: Nation?) -> NationShown {
        if let saved { return NationShown(nation: saved, isFromLocation: false, isUnsavedPick: false) }
        if let pick = unsavedChoice?.nation {
            return NationShown(nation: pick, isFromLocation: false, isUnsavedPick: true)
        }
        return NationShown(nation: detected, isFromLocation: detected != nil, isUnsavedPick: false)
    }

    /// The problem row's text. "Used on this screen only" is said only for the unsaved
    /// pick the list is showing; any other save failure gets wording that claims nothing
    /// about what is on screen.
    static func problemText(_ problem: NationPreference.Problem, shown: NationShown) -> String {
        switch problem {
        case .couldNotRead:
            FilterCopy.refugesProblem(problem)
        case .couldNotSave:
            shown.isUnsavedPick ? FilterCopy.refugesProblem(problem) : FilterCopy.refugesCouldNotSaveElsewhere
        }
    }
}

/// The nation picker, the store-failure row, and the detected-nation offer — extracted so
/// `RefugesScreen.body` reads as one screen, matching `HelpScreen`'s `HelpSections`.
private struct RefugesNationSection: View {

    let preference: NationPreference
    let detected: Nation?
    let shown: NationShown
    let pick: (Nation?) -> Void

    var body: some View {
        Section {
            Picker(selection: Binding(get: { shown.nation }, set: { pick($0) })) {
                // Offered only until a nation is shown: once one is, choosing it
                // would silently do nothing (a nil pick is ignored, see `pick`),
                // and this screen's nation is never reset to all of the UK.
                if shown.nation == nil {
                    Text("refuges.nation.choose", bundle: .module).tag(Nation?.none)
                }
                ForEach(Nation.allCases) { nation in
                    Text(NationCopy.name(nation)).tag(Optional(nation))
                }
            } label: {
                Text("refuges.nation.header", bundle: .module)
            }
            .accessibilityIdentifier("refuges.nation")

            NationStatusRows(
                preference: preference, detected: detected,
                problemText: { RefugesScreen.problemText($0, shown: shown) }, onUseDetected: pick
            )
        } footer: {
            if shown.isFromLocation {
                Text("refuges.nation.fromLocation", bundle: .module)
            }
        }
    }
}

/// The refuge list for the shown nation, or the prompt to choose one — extracted so
/// `RefugesScreen.body` reads as one screen, matching `HelpScreen`'s `HelpSections`.
private struct RefugeListSection: View {

    let pack: ContentPack
    let nation: Nation?
    let now: Date
    let contact: ServiceContact

    var body: some View {
        if let nation {
            Section {
                ForEach(pack.refuges(for: nation)) { service in
                    ServiceRow(service: service, now: now, contact: contact, showsNoPhoneLine: false)
                }
            } header: {
                Text(String(format: Strings.localized("refuges.list.header"), NationCopy.name(nation)))
            }
        } else {
            Section {
                Text("refuges.nation.prompt", bundle: .module).foregroundStyle(.secondary)
            }
        }
    }
}
