import SafetyContent
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
    @Environment(TestModeSession.self) private var testMode: TestModeSession?
    @Environment(NationPreference.self) private var nationPreference

    let pack: ContentPack?
    /// Where Nearby found the person, refreshed each time the parent redraws.
    let detected: Nation?

    @State private var contact = ServiceContactActions()
    /// A nation picked here that could not be saved. Get help and Learn fall back to all
    /// of the UK when the store fails, but a refuge list needs a nation, so the person's
    /// pick is kept for this screen, and the screen says it was not saved.
    @State private var unsaved: Nation?

    init(pack: ContentPack?, detected: Nation?) {
        self.pack = pack
        self.detected = detected
    }

    private var isTestMode: Bool { testMode?.isOn == true }

    /// `unsaved` only while its warning is still current — otherwise a pick that
    /// failed to save here would keep being shown after a later, successful save
    /// made elsewhere (Get help or Learn) cleared the problem.
    private var current: NationShown {
        let unsavedPick = nationPreference.problem == .couldNotSave ? unsaved : nil
        return Self.nationShown(saved: nationPreference.nation, unsaved: unsavedPick, detected: detected)
    }

    var body: some View {
        let current = self.current
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

                Section {
                    Picker(selection: Binding(get: { current.nation }, set: pick)) {
                        // Offered only until a nation is shown: once one is, choosing it
                        // would silently do nothing (a nil pick is ignored, see `pick`),
                        // and this screen's nation is never reset to all of the UK.
                        if current.nation == nil {
                            Text("refuges.nation.choose", bundle: .module).tag(Nation?.none)
                        }
                        ForEach(Nation.allCases) { nation in
                            Text(NationCopy.name(nation)).tag(Optional(nation))
                        }
                    } label: {
                        Text("refuges.nation.header", bundle: .module)
                    }
                    .accessibilityIdentifier("refuges.nation")

                    if let problem = nationPreference.problem {
                        NationProblemRow(text: FilterCopy.refugesProblem(problem))
                    }
                    // The person may have moved since choosing: offered, never applied.
                    if let detected, nationPreference.isStale(detected: detected) {
                        NationOfferButton(nation: detected) { pick(detected) }
                    }
                } footer: {
                    if current.isFromLocation {
                        Text("refuges.nation.fromLocation", bundle: .module)
                    }
                }

                if let nation = current.nation {
                    Section {
                        ForEach(pack.refuges(for: nation)) { service in
                            ServiceRow(
                                service: service,
                                now: services.time.now,
                                onCall: { contact.requestCall($0, serviceName: $1, testMode: isTestMode) },
                                onText: { number in
                                    let texter = services.texter
                                    let testMode = isTestMode
                                    Task { await contact.text(number, testMode: testMode, using: texter) }
                                },
                                showsNoPhoneLine: false
                            )
                        }
                    } header: {
                        Text(String(format: Strings.localized("refuges.list.header"), NationCopy.name(nation)))
                    }
                } else {
                    Section {
                        Text("refuges.nation.prompt", bundle: .module).foregroundStyle(.secondary)
                    }
                }
            } else {
                // The pack is bundled, so this should be unreachable in a real
                // install — but reachable in DEBUG (-kitty.withoutContent), and a
                // silent empty screen would read as "there are no refuges", which is
                // both false and dangerous. Shown rather than swallowed, matching
                // `LearnScreen`.
                ContentUnavailableNotice(titleKey: "learn.unavailable.title", bodyKey: "learn.unavailable.body")
            }
        }
        .navigationTitle(Text("refuges.title", bundle: .module))
        .serviceContactDialogs(contact, dialler: services.dialler)
    }

    /// Saves the pick for every screen. If it cannot be saved, it is kept for this one.
    /// A `nil` pick is ignored: the picker offers one only until a nation is shown, but
    /// this guards the same rule at the point where it matters, so choosing here can
    /// never reset the nation Get help and Learn share back to all of the UK.
    private func pick(_ nation: Nation?) {
        guard let nation else { return }
        nationPreference.choose(nation)
        unsaved = nationPreference.problem == .couldNotSave ? nation : nil
    }
}

/// Which nation the refuge list is for, and whether it came from the person's location.
struct NationShown: Equatable {
    let nation: Nation?
    let isFromLocation: Bool
}

extension RefugesScreen {

    /// The order of precedence:
    /// 1. The person's saved choice, shared with Get help and Learn.
    /// 2. A pick made here that could not be saved.
    /// 3. Until they choose, the nation found from their location. It is shown so the
    ///    list is there at once, labelled as such, and never saved (as in M4).
    /// 4. Otherwise none, and the screen asks.
    static func nationShown(saved: Nation?, unsaved: Nation?, detected: Nation?) -> NationShown {
        if let saved { return NationShown(nation: saved, isFromLocation: false) }
        if let unsaved { return NationShown(nation: unsaved, isFromLocation: false) }
        return NationShown(nation: detected, isFromLocation: detected != nil)
    }
}
