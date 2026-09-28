import SafetyContent
import SafetyDomain
import SafetyServices
import SwiftUI

/// Support services and the ways to reach 999.
///
/// Entirely offline: the content pack is bundled, so this screen works with no
/// signal, no permission and no network. That is the point — it is the part of the
/// app most likely to be needed when everything else has failed.
///
/// Everything below the 999 routes can be narrowed by nation, topic and search
/// (ADR-0014). The 999 routes and the Test Mode banner never are.
///
/// `RootView` must inject the `NationPreference` and `NearbyModel` this screen reads
/// from the Environment.
public struct HelpScreen: View {

    @Environment(\.services) private var services
    @Environment(\.regionStance) private var region
    // Optional: returns nil rather than crashing when no session is supplied, such as
    // in a preview. No session in the environment means Test Mode is off.
    @Environment(TestModeSession.self) private var testMode: TestModeSession?
    @Environment(NationPreference.self) private var nationPreference
    @Environment(NearbyModel.self) private var nearby

    @State private var filter = ScreenFilter()

    private let pack: ContentPack?

    public init(pack: ContentPack?) {
        self.pack = pack
    }

    /// What the filter leaves. `nil` only without a pack.
    private var content: HelpContent? {
        pack.map {
            HelpContent(pack: $0, region: region, criteria: filter.criteria(nation: nationPreference.nation), topicTerms: TopicCopy.searchTerms)
        }
    }

    public var body: some View {
        let content = content
        NavigationStack {
            ServiceContactHost { contact in
                List {
                    if let testMode, testMode.isOn {
                        Section { TestModeBanner(session: testMode) }
                    }

                    if !region.isUnitedKingdom {
                        Section { NonUKNotice() }
                    }

                    if let pack, let content {
                        HelpSections(
                            pack: pack, content: content, nationPreference: nationPreference,
                            detected: nearby.detectedNation, filter: filter,
                            now: services.time.now, contact: contact
                        )
                    } else {
                        ContentUnavailableNotice(titleKey: "help.unavailable.title", bodyKey: "help.unavailable.body")
                    }
                }
            }
            .navigationTitle(Text("help.title", bundle: .module))
            .filterSearchable(text: $filter.query)
            .announcesResultCount(content?.resultCount ?? 0)
        }
    }
}

/// The 999 routes, the filter, and everything the filter can narrow. Extracted so
/// `HelpScreen.body` reads as one screen; the 999 routes still come first and outside
/// the filter, exactly as `HelpScreen`'s own doc comment promises.
private struct HelpSections: View {

    let pack: ContentPack
    let content: HelpContent
    let nationPreference: NationPreference
    let detected: Nation?
    let filter: ScreenFilter
    let now: Date
    let contact: ServiceContact

    var body: some View {
        // First, and outside the filter: whatever is chosen or typed below, every way
        // to reach 999 stays on screen.
        Section {
            ForEach(content.emergencyRoutes) { EmergencyRouteRow(route: $0) }
        } header: {
            Text("help.section.emergency", bundle: .module)
        }

        FilterSection(preference: nationPreference, detected: detected, filter: filter)

        if content.hasNoMatches {
            Section { NoMatchesView(scope: .everything) { filter.clear() } }
        }

        if !content.services.isEmpty {
            Section {
                ForEach(content.services) { service in
                    ServiceRow(service: service, now: now, contact: contact)
                }
            } header: {
                Text("help.section.services", bundle: .module)
            }
        }

        // `HelpContent` reads reporting through the gate, never the raw list: outside
        // the UK it is empty and the section does not render at all (Guideline 1.7).
        if !content.reporting.isEmpty {
            Section {
                ForEach(content.reporting) { route in
                    ServiceRow(service: route, now: now, contact: contact)
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
    let contact: ServiceContact
    /// Whether "This service has no phone line." may render when there is no number.
    /// `true` on Get help, where it exists so nobody goes looking for a number
    /// Women's Aid does not have. `false` in the refuge list (`RefugesScreen`):
    /// there every phoneless entry is an `.information` directory or council route
    /// that was never a phone line to begin with, so the same sentence would be
    /// stating a fact about the wrong kind of entry.
    var showsNoPhoneLine = true

    @Environment(\.dynamicTypeSize) private var typeSize

    private var status: OpeningStatus { service.availability.status(at: now) }

    /// Whether the no-phone line should render for this kind, given whether this list
    /// allows it at all. Extracted from `body` so the rule is testable without
    /// rendering a view.
    static func shouldShowNoPhoneLine(kind: ServiceKind, showsNoPhoneLine: Bool) -> Bool {
        showsNoPhoneLine && kind != .reporting
    }

    /// Side by side at normal sizes; stacked at accessibility sizes.
    ///
    /// Found by checking on device at AX5: side by side, the badge took half the
    /// width and squeezed "National Domestic Abuse Helpline" into a narrow column
    /// that broke mid-word — "Helplin / e", with no hyphen. That is worst for exactly
    /// the people who use the largest text, so the layout changes rather than the
    /// text shrinking.
    private var headerLayout: AnyLayout {
        Design.adaptiveStack(at: typeSize)
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
                TextButton(number: number) { contact.text(number) }
            }

            if let phone = service.phone, let number = PhoneNumber(phone) {
                CallButton(number: number, serviceName: service.name) { contact.call(number, service.name) }
            } else if Self.shouldShowNoPhoneLine(kind: service.kind, showsNoPhoneLine: showsNoPhoneLine) {
                // Only where someone might go looking for a number that does not
                // exist — Women's Aid, on Get help. A web-only reporting route such
                // as GOV.UK does not need telling, and `showsNoPhoneLine` is false in
                // the refuge list, where a phoneless `.information` entry is a
                // directory or council route that was never a phone line to begin
                // with — the same sentence there would be stating a fact about the
                // wrong kind of entry.
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

