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

    private let pack: ContentPack?

    public init(pack: ContentPack? = try? ContentLoader.loadUK()) {
        self.pack = pack
    }

    public var body: some View {
        NavigationStack {
            List {
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
                            ServiceRow(service: service, now: services.time.now)
                        }
                    } header: {
                        Text("help.section.services", bundle: .module)
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

    private var status: OpeningStatus { service.availability.status(at: now) }

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Space.tight) {
            HStack(alignment: .firstTextBaseline) {
                Text(service.name).font(.headline)
                Spacer(minLength: Design.Space.tight)
                CoverageBadge(coverage: service.coverage)
            }

            Text(service.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            OpeningStatusLabel(status: status)

            if let phone = service.phone, let number = PhoneNumber(phone) {
                CallButton(number: number, serviceName: service.name)
            } else {
                // Stated explicitly. Women's Aid runs no telephone line, and leaving
                // that blank invites someone to go looking for a number that does
                // not exist.
                Text("help.noPhone", bundle: .module)
                    .font(.footnote)
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
