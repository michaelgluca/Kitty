import SafetyContent
import SafetyServices
import SwiftUI

/// Women's refuges near you — as the services that place women in refuge, never as
/// addresses. Refuge addresses are confidential, and a feature that found them would
/// hand an abuser the means to find someone who fled (ADR-0013).
struct RefugesScreen: View {

    @Environment(\.services) private var services
    @Environment(TestModeSession.self) private var testMode: TestModeSession?

    let pack: ContentPack?
    let detected: Nation?

    @State private var chosen: Nation?
    @State private var contact = ServiceContactActions()
    /// The nation `chosen` was seeded from, frozen at the moment this screen was
    /// first created — unlike `detected`, a plain `let` that is refreshed with
    /// whatever `NearbyModel.detectedNation` holds each time the parent redraws.
    /// Without this, a person who opens Refuges before the area lookup lands (so
    /// `chosen` starts `nil`), then has the lookup resolve afterwards and happens to
    /// pick that same nation by hand, would be told it was "chosen from your
    /// location" when they chose it themselves.
    @State private var seededNation: Nation?

    init(pack: ContentPack?, detected: Nation?) {
        self.pack = pack
        self.detected = detected
        _chosen = State(initialValue: detected)
        _seededNation = State(initialValue: detected)
    }

    private var isTestMode: Bool { testMode?.isOn == true }

    var body: some View {
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
                    Picker(selection: $chosen) {
                        Text("refuges.nation.choose", bundle: .module).tag(Nation?.none)
                        ForEach(Nation.allCases) { nation in
                            Text(NationCopy.name(nation)).tag(Optional(nation))
                        }
                    } label: {
                        Text("refuges.nation.header", bundle: .module)
                    }
                    .accessibilityIdentifier("refuges.nation")
                } footer: {
                    if chosen != nil, chosen == seededNation {
                        Text("refuges.nation.fromLocation", bundle: .module)
                    }
                }

                if let chosen {
                    Section {
                        ForEach(pack.refuges(for: chosen)) { service in
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
                        Text(String(format: Strings.localized("refuges.list.header"), NationCopy.name(chosen)))
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
                ContentUnavailableView {
                    Label { Text("learn.unavailable.title", bundle: .module) } icon: { Image(systemName: "exclamationmark.triangle.fill") }
                } description: {
                    Text("learn.unavailable.body", bundle: .module)
                }
            }
        }
        .navigationTitle(Text("refuges.title", bundle: .module))
        .serviceContactDialogs(contact, dialler: services.dialler)
    }
}
