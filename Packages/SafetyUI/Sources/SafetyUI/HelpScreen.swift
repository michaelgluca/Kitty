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

    /// The one call awaiting confirmation, captured at the moment of the tap.
    @State private var pendingCall: PendingCall?
    /// A call or text the system could not start, shown so the user can do it by hand.
    @State private var failure: ContactFailure?

    private var isTestMode: Bool { testMode?.isOn == true }

    private let pack: ContentPack?

    public init(pack: ContentPack? = try? ContentLoader.loadUK()) {
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
                        ForEach(pack.guides) { GuideRow(guide: $0) }
                    } header: {
                        Text("help.section.guides", bundle: .module)
                    } footer: {
                        Text("help.guides.footer", bundle: .module)
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
            // ONE confirmation for the whole screen, not one per row. With a dialog on
            // every row of a List, SwiftUI presented stale state: tapping one service
            // produced the previous service's dialog, and confirming would have called
            // the wrong number. `presenting:` hands the action the value captured at
            // presentation, and the message shows that same value's number — so what
            // the user reads and what is dialled cannot differ.
            .confirmationDialog(
                Text(pendingCall.map { String(format: Strings.localized("help.callConfirm.title"), $0.serviceName) } ?? ""),
                isPresented: Binding(get: { pendingCall != nil }, set: { if !$0 { pendingCall = nil } }),
                titleVisibility: .visible,
                presenting: pendingCall
            ) { call in
                Button(Strings.localized("help.callConfirm.confirm")) { place(call) }
                Button(Strings.localized("help.callConfirm.cancel"), role: .cancel) {}
            } message: { call in
                Text(call.confirmationMessage)
            }
            .alert(
                Text(failure.map(\.message) ?? ""),
                isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
            ) {
                Button(Strings.localized("help.ok"), role: .cancel) {}
            }
        }
    }
}

extension HelpScreen {

    private func call(_ number: PhoneNumber, serviceName: String) {
        pendingCall = PendingCall.make(serviceName: serviceName, number: number, testMode: isTestMode)
    }

    private func text(_ number: PhoneNumber) {
        // In Test Mode a text goes to a drama number, like every other flow.
        let target = isTestMode ? TestModeNumbers.service : number
        let texter = services.texter
        Task { @MainActor in
            if await texter.openText(to: target) == false {
                failure = .text(target)
            }
        }
    }

    /// Dials exactly the number that was confirmed — never re-read from state.
    private func place(_ call: PendingCall) {
        let dialler = services.dialler
        Task { @MainActor in
            if await dialler.dial(call.dialled) == false {
                failure = .call(call.dialled)
            }
        }
    }
}

/// A call awaiting confirmation. Captured whole at the moment of the tap, so the
/// confirmation and the dial both read one value and cannot drift apart — not even
/// if Test Mode is switched off while the dialog is open.
struct PendingCall: Equatable {
    let serviceName: String
    /// The number on the service's card.
    let number: PhoneNumber
    /// What will actually be dialled: `number`, or in Test Mode a drama number.
    let dialled: PhoneNumber
    let isTest: Bool

    static func make(serviceName: String, number: PhoneNumber, testMode: Bool) -> PendingCall {
        PendingCall(
            serviceName: serviceName,
            number: number,
            dialled: testMode ? TestModeNumbers.service : number,
            isTest: testMode
        )
    }

    var confirmationMessage: String {
        isTest
            ? String(format: Strings.localized("help.callConfirm.messageTestMode"), dialled.raw, number.raw)
            : String(format: Strings.localized("help.callConfirm.messageWithNumber"), number.raw)
    }
}

/// A call or text the system could not start. Never silent: the number is shown so
/// the user can dial or text it by hand.
enum ContactFailure: Equatable {
    case call(PhoneNumber)
    case text(PhoneNumber)

    var message: String {
        switch self {
        case let .call(n): String(format: Strings.localized("help.callFailed"), n.raw)
        case let .text(n): String(format: Strings.localized("help.textFailed"), n.raw)
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
            } else if service.kind != .reporting {
                // Only where someone might go looking for a number that does not
                // exist — Women's Aid. A web-only reporting route such as GOV.UK
                // does not need telling.
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

struct GuideRow: View {
    let guide: SafetyGuide

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Space.tight) {
            Text(guide.title).font(.headline)
            Text(guide.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let caution = guide.caution {
                // A trade-off to understand before switching the feature on — not a
                // footnote. Medical ID's "Show When Locked" exposes the emergency
                // contacts to anyone holding the phone.
                Label {
                    Text(caution).font(.footnote).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .foregroundStyle(.orange)
            }

            if let url = URL(string: guide.url) {
                Link(destination: url) {
                    Text("help.openInstructions", bundle: .module).font(.subheadline)
                }
            }
        }
        .padding(.vertical, Design.Space.tight)
    }
}
