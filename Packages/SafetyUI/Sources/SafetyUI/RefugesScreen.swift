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
                    // both false and dangerous. Shown rather than swallowed, matching
                    // `LearnScreen`.
                    ContentUnavailableNotice(titleKey: "learn.unavailable.title", bodyKey: "learn.unavailable.body")
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

/// Which nation the refuge list is for: where it came from, and — for the problem row's
/// wording — whether that is a pick that could not be saved. `isUnsavedPick` is set only
/// by `nationShown` itself, at the one place that actually took the unsaved-pick branch,
/// rather than left for `problemText` to re-derive by comparing optionals: "the nation
/// shown happens to equal the failed pick" cannot be told apart, by `==` alone, from "both
/// happen to be the same nation (or both `nil`) for unrelated reasons".
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
    ///    list is there at once, labelled as such, and never saved (as in M4).
    /// 4. Otherwise none, and the screen asks.
    static func nationShown(saved: Nation?, unsavedChoice: NationPreference.UnsavedChoice?, detected: Nation?) -> NationShown {
        if let saved { return NationShown(nation: saved, isFromLocation: false, isUnsavedPick: false) }
        if let pick = unsavedChoice?.nation {
            return NationShown(nation: pick, isFromLocation: false, isUnsavedPick: true)
        }
        return NationShown(nation: detected, isFromLocation: detected != nil, isUnsavedPick: false)
    }

    /// The problem row's text. The refuges-specific "could not be saved, so it is used on
    /// this screen only" wording is used only when what is shown is genuinely the pick
    /// that failed (`shown.isUnsavedPick`) — never merely because a nation, or the lack of
    /// one, happens to match. Every other save failure — one made elsewhere that named a
    /// different nation, or one that was "all of the UK" itself — says something that
    /// claims nothing about what is on screen. A read failure has no pick to misattribute,
    /// so it always uses the refuges-specific wording.
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

            if let problem = preference.problem {
                NationProblemRow(text: RefugesScreen.problemText(problem, shown: shown))
            }
            // The person may have moved since choosing: offered, never applied.
            if let detected, preference.isStale(detected: detected) {
                NationOfferButton(nation: detected) { pick(detected) }
            }
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
