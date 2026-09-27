import SafetyDomain
import SafetyServices
import SwiftUI

/// The Alert tab: the one control that matters, what it will do, and what happened.
struct AlertScreen: View {

    @Environment(\.services) private var services
    @Environment(\.regionStance) private var region
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AlertModel.self) private var alert
    @Environment(ContactsModel.self) private var contacts
    @Environment(TestModeSession.self) private var testMode

    /// From the content pack. `nil` only if the bundled pack failed to load, in
    /// which case there is no 999 button but the disclaimer still says to call 999.
    let emergencyNumber: String?

    @State private var showContacts = false
    @State private var authorization: LocationAuthorization = .notDetermined
    /// The 999 call awaiting confirmation, captured at the tap.
    @State private var pendingEmergency: EmergencyCallPlan?
    @State private var callFailure: PhoneNumber?
    @State private var settingsFailed = false

    private var emergencyPlan: EmergencyCallPlan? {
        EmergencyCallPlanner.plan(emergencyNumber: emergencyNumber, region: region, testMode: testMode.isOn)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Design.Space.loose) {
                    if testMode.isOn {
                        TestModeBanner(session: testMode)
                    }

                    ContactsSummaryRow(contacts: contacts) { showContacts = true }

                    LocationStatusRow(authorization: authorization, onAllow: allowLocation, onOpenSettings: openSettings)

                    Spacer(minLength: Design.Space.loose)

                    // Bottom-weighted: the control sits in thumb reach for one-handed use.
                    PrimaryAlertButton { raise() }
                        .disabled(alert.isBusy)

                    AlertStatusView(
                        phase: alert.phase,
                        recipients: alert.recipients,
                        onCall: { dial($0.number) },
                        onAddContacts: { showContacts = true },
                        onDismiss: { alert.reset() }
                    )

                    if let plan = emergencyPlan {
                        EmergencyCallButton(plan: plan) { pendingEmergency = plan }
                    }

                    SafetyDisclaimer()
                }
                .padding(.horizontal, Design.Space.gutter)
                .padding(.bottom, Design.Space.loose)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(Text("tab.alert", bundle: .module))
            .navigationDestination(isPresented: $showContacts) { ContactsScreen() }
            .confirmationDialog(
                Text(pendingEmergency.map(EmergencyCallCopy.confirmationTitle(for:)) ?? ""),
                isPresented: Binding(get: { pendingEmergency != nil }, set: { if !$0 { pendingEmergency = nil } }),
                titleVisibility: .visible,
                presenting: pendingEmergency
            ) { plan in
                // Dials exactly what was confirmed — the plan captured at the tap.
                Button(Strings.localized("help.callConfirm.confirm")) { dial(plan.dialled) }
                Button(Strings.localized("help.callConfirm.cancel"), role: .cancel) {}
            } message: { plan in
                Text(EmergencyCallCopy.confirmationMessage(for: plan))
            }
            .alert(
                Text(callFailure.map { String(format: Strings.localized("help.callFailed"), $0.raw) } ?? ""),
                isPresented: Binding(get: { callFailure != nil }, set: { if !$0 { callFailure = nil } })
            ) {
                Button(Strings.localized("help.ok"), role: .cancel) {}
            }
            .alert(Text(Strings.localized("alert.location.settingsFailed")), isPresented: $settingsFailed) {
                Button(Strings.localized("help.ok"), role: .cancel) {}
            }
            .task { refreshAuthorization() }
            .onChange(of: scenePhase) { _, phase in
                // Back from Settings, the answer may have changed.
                if phase == .active { refreshAuthorization() }
            }
            .onChange(of: alert.phase) { _, phase in
                guard case let .finished(outcome) = phase else { return }
                if outcome == .needsContacts { showContacts = true }
                // VoiceOver users hear the outcome without hunting for it.
                AccessibilityNotification.Announcement(AlertCopy.message(for: outcome)).post()
            }
        }
    }

    private func raise() {
        let people = contacts.contacts
        let readable = contacts.loadState != .unreadable
        let isTest = testMode.isOn
        Task { await alert.raise(contacts: people, contactsReadable: readable, testMode: isTest) }
    }

    private func dial(_ number: PhoneNumber) {
        let dialler = services.dialler
        Task { @MainActor in
            if await dialler.dial(number) == false { callFailure = number }
        }
    }

    private func allowLocation() {
        let location = services.location
        Task { @MainActor in authorization = await location.requestWhenInUseAuthorization() }
    }

    private func openSettings() {
        let settings = services.settings
        Task { @MainActor in
            if await settings.openAppSettings() == false { settingsFailed = true }
        }
    }

    private func refreshAuthorization() {
        authorization = services.location.authorization
    }
}

/// Who the alert goes to, one tap from the list itself.
struct ContactsSummaryRow: View {

    let contacts: ContactsModel
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: Design.Space.tight) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("alert.contacts.title", bundle: .module).font(.headline)
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Design.Space.tight)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: Design.minimumTapTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("alert.contacts")
    }

    private var summary: String {
        switch contacts.loadState {
        case .unreadable:
            Strings.localized("alert.contacts.unreadable")
        case .notLoaded, .loaded:
            contacts.contacts.isEmpty
                ? Strings.localized("alert.contacts.none")
                : contacts.contacts.map(\.displayName).formatted(.list(type: .and))
        }
    }
}
