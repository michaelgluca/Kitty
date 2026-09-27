import SafetyContent
import SafetyDomain
import SafetyServices
import SwiftUI

/// Support services and the ways to reach 999.
///
/// Entirely offline: the content pack is bundled, so this screen works with no
/// signal, no permission and no network. That is the point — it is the part of the
/// app most likely to be needed when everything else has failed.
public struct HelpScreen: View {

    @Environment(\.services) private var services
    @Environment(\.regionStance) private var region
    // Optional: returns nil rather than crashing when no session is supplied, such as
    // in a preview. No session in the environment means Test Mode is off.
    @Environment(TestModeSession.self) private var testMode: TestModeSession?

    @State private var contact = ServiceContactActions()

    private var isTestMode: Bool { testMode?.isOn == true }

    private let pack: ContentPack?

    public init(pack: ContentPack?) {
        self.pack = pack
    }

    public var body: some View {
        NavigationStack {
            List {
                if let testMode, testMode.isOn {
                    Section { TestModeBanner(session: testMode) }
                }

                if !region.isUnitedKingdom {
                    Section { NonUKNotice() }
                }

                if let pack {
                    Section {
                        ForEach(pack.emergencyRoutes) { EmergencyRouteRow(route: $0) }
                    } header: {
                        Text("help.section.emergency", bundle: .module)
                    }

                    Section {
                        ForEach(pack.services) { service in
                            ServiceRow(service: service, now: services.time.now, onCall: call, onText: text)
                        }
                    } header: {
                        Text("help.section.services", bundle: .module)
                    }

                    // Read through the gate, never the raw list: outside the UK this
                    // is empty and the section does not render at all (Guideline 1.7).
                    let reporting = pack.reporting(for: region)
                    if !reporting.isEmpty {
                        Section {
                            ForEach(reporting) { route in
                                ServiceRow(service: route, now: services.time.now, onCall: call, onText: text)
                            }
                        } header: {
                            Text("help.section.reporting", bundle: .module)
                        } footer: {
                            Text("help.reporting.footer", bundle: .module)
                        }
                    }

                    Section {
                        NavigationLink {
                            SafetyFeaturesScreen(pack: pack)
                        } label: {
                            Label {
                                Text("help.features.link", bundle: .module)
                            } icon: {
                                Image(systemName: "iphone.gen3")
                            }
                        }
                        .accessibilityIdentifier("help.features.link")
                    }
                } else {
                    // The pack is bundled, so this should be unreachable — but it is
                    // shown rather than swallowed, because an empty list would read
                    // as "there is no help available".
                    ContentUnavailableView(
                        "Safety information could not be loaded",
                        systemImage: "exclamationmark.triangle.fill",
                        description: Text(verbatim: "Please reinstall Kitty G. In an emergency, call 999.")
                    )
                }
            }
            .navigationTitle(Text("help.title", bundle: .module))
            .serviceContactDialogs(contact, dialler: services.dialler)
        }
    }
}

extension HelpScreen {

    private func call(_ number: PhoneNumber, serviceName: String) {
        contact.requestCall(number, serviceName: serviceName, testMode: isTestMode)
    }

    private func text(_ number: PhoneNumber) {
        let texter = services.texter
        let testMode = isTestMode
        Task { await contact.text(number, testMode: testMode, using: texter) }
    }
}

struct EmergencyRouteRow: View {
    let route: EmergencyRoute

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Space.tight) {
            Text(route.name).font(.headline)
            Text(route.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let prerequisite = route.prerequisite {
                // Rendered prominently rather than as a footnote. Someone who
                // believes they can text 999 without registering will find out at
                // the worst possible moment.
                Label {
                    Text(String(format: Strings.localized("help.prerequisite"), prerequisite))
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.circle.fill")
                }
                .foregroundStyle(.orange)
                .padding(.top, Design.Space.tight)
            }

            if let link = route.learnMoreURL, let url = URL(string: link) {
                // Opened in the system browser rather than an in-app web view: an
                // unrestricted in-app browser pushes the App Store age rating to 16+.
                Link(destination: url) {
                    Text("help.openWebsite", bundle: .module).font(.subheadline)
                }
                .padding(.top, Design.Space.tight)
            }
        }
        .padding(.vertical, Design.Space.tight)
        .accessibilityElement(children: .combine)
    }
}

struct ServiceRow: View {
    let service: SupportService
    let now: Date
    let onCall: (PhoneNumber, String) -> Void
    let onText: (PhoneNumber) -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    private var status: OpeningStatus { service.availability.status(at: now) }

    /// Side by side at normal sizes; stacked at accessibility sizes.
    ///
    /// Found by checking on device at AX5: side by side, the badge took half the
    /// width and squeezed "National Domestic Abuse Helpline" into a narrow column
    /// that broke mid-word — "Helplin / e", with no hyphen. That is worst for exactly
    /// the people who use the largest text, so the layout changes rather than the
    /// text shrinking.
    private var headerLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Design.Space.tight))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Design.Space.tight))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Space.tight) {
            headerLayout {
                Text(service.name)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if !typeSize.isAccessibilitySize {
                    Spacer(minLength: Design.Space.tight)
                }
                // No badge when the operator does not state its coverage. Showing a
                // nation it has not claimed would be inventing a fact.
                if let coverage = service.coverage {
                    CoverageBadge(coverage: coverage)
                }
            }

            if let audience = service.audience {
                // Shown before the number so nobody calls a line that will turn them
                // away — the National Domestic Abuse Helpline is for women, and the
                // Northern Ireland helpline for over-18s.
                Text(String(format: Strings.localized("help.audience"), audience))
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(service.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            OpeningStatusLabel(status: status)

            if let textNote = service.textNote, service.textNumber != nil {
                Label {
                    Text(textNote).font(.footnote).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "info.circle")
                }
                .foregroundStyle(.secondary)
            }

            if let text = service.textNumber, let number = PhoneNumber(text) {
                TextButton(number: number) { onText(number) }
            }

            if let phone = service.phone, let number = PhoneNumber(phone) {
                CallButton(number: number, serviceName: service.name) { onCall(number, service.name) }
            } else if service.kind != .reporting, service.kind != .information {
                // Only where someone might go looking for a number that does not
                // exist — Women's Aid. A web-only reporting route such as GOV.UK
                // does not need telling, and nor does an `.information` entry such
                // as a refuge directory or a council homelessness route: those are
                // never phone lines in the first place, so the line would be false.
                // Stated explicitly. Women's Aid runs no telephone line, and leaving
                // that blank invites someone to go looking for a number that does
                // not exist.
                Text("help.noPhone", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let note = service.billingNote {
                // Matters to someone whose abuser checks their phone bill. Only ever
                // shown where the operator itself makes the claim.
                Label {
                    Text(note).font(.footnote).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "doc.text.magnifyingglass")
                }
                .foregroundStyle(.secondary)
            }

            if let url = URL(string: service.url) {
                Link(destination: url) {
                    Text("help.openWebsite", bundle: .module).font(.subheadline)
                }
            }

            if let attribution = service.attribution {
                Text(attribution).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, Design.Space.tight)
    }
}

struct OpeningStatusLabel: View {
    let status: OpeningStatus

    var body: some View {
        switch status {
        case .openNow:
            // Never colour alone: the icon and the words carry the meaning too.
            Label { Text("help.status.open", bundle: .module) } icon: { Image(systemName: "checkmark.circle.fill") }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.green)
        case .closedNow:
            Label { Text("help.status.closed", bundle: .module) } icon: { Image(systemName: "moon.fill") }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        case .unknown:
            Label { Text("help.status.unknown", bundle: .module) } icon: { Image(systemName: "questionmark.circle") }
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct CoverageBadge: View {
    let coverage: Coverage

    private var key: String {
        switch coverage {
        case .unitedKingdom: "help.coverage.unitedKingdom"
        case .england: "help.coverage.england"
        case .englandAndWales: "help.coverage.englandAndWales"
        case .wales: "help.coverage.wales"
        case .scotland: "help.coverage.scotland"
        case .northernIreland: "help.coverage.northernIreland"
        case .greatBritain: "help.coverage.greatBritain"
        case .london: "help.coverage.london"
        }
    }

    var body: some View {
        Text(Strings.localized(String.LocalizationValue(key)))
            .font(.caption.weight(.medium))
            .padding(.horizontal, Design.Space.tight)
            .padding(.vertical, 2)
            .background(Capsule().fill(.quaternary))
            .fixedSize()
            .accessibilityLabel(Text(Strings.localized(String.LocalizationValue(key))))
    }
}

