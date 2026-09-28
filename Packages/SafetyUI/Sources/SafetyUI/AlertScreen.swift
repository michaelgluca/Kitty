import SafetyDomain
import SafetyServices
import SwiftUI

/// The Alert tab: the one control that matters, what it will do, and what happened.
struct AlertScreen: View {

    @Environment(\.services) private var services
    @Environment(\.regionStance) private var region
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AlertModel.self) private var alert
    @Environment(ContactsModel.self) private var contacts
    @Environment(TestModeSession.self) private var testMode

    /// From the content pack. `nil` only if the bundled pack failed to load, in
    /// which case there is no 999 button, and the UK sees a line saying so instead.
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

    /// True only when the 999 button is missing because the bundled content failed
    /// to load — never merely because the region is not the UK, which is the
    /// disclaimer's job to explain.
    private var emergencyContentMissing: Bool {
        region.isUnitedKingdom && emergencyNumber == nil
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Design.Space.loose) {
                        if testMode.isOn {
                            TestModeBanner(session: testMode)
                        }

                        ContactsSummaryRow(contacts: contacts) { showContacts = true }

                        LocationStatusRow(authorization: authorization, onAllow: allowLocation, onOpenSettings: openSettings)

                        AlertStatusView(
                            phase: alert.phase,
                            // Only people planned in the mode that is on now. The
                            // result is also cleared when the mode changes (below);
                            // this covers a mode change while an alert was still in
                            // flight, which that reset cannot touch.
                            recipients: alert.callableRecipients(testModeIsOn: testMode.isOn),
                            onCall: call,
                            onAddContacts: { showContacts = true },
                            onDismiss: { alert.reset() }
                        )
                        .id("alert.status")

                        if let plan = emergencyPlan {
                            EmergencyCallButton(plan: plan) { pendingEmergency = plan }
                        } else if emergencyContentMissing {
                            Text("emergency.unavailable", bundle: .module)
                                .font(.footnote)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity)
                                .accessibilityAddTraits(.isStaticText)
                        }

                        SafetyDisclaimer()
                    }
                    .padding(.horizontal, Design.Space.gutter)
                    .padding(.bottom, Design.Space.loose)
                    .frame(maxWidth: .infinity)
                }
                .safeAreaInset(edge: .bottom) {
                    // Pinned above the tab bar, outside the scroll content, so it is
                    // always on screen, in thumb reach and one tap from launch —
                    // whatever the text size, the scroll position, or how much the
                    // Test Mode banner and the location row take up.
                    // Opaque, so scrolled content never shows through it.
                    PrimaryAlertButton { raise(scrollProxy: proxy) }
                        .disabled(alert.isBusy)
                        .padding(.horizontal, Design.Space.gutter)
                        .padding(.vertical, Design.Space.base)
                        .background(.background)
                }
                .navigationTitle(Text("tab.alert", bundle: .module))
                .navigationDestination(isPresented: $showContacts) { ContactsScreen() }
                .confirmationDialog(
                    Text(pendingEmergency.map(EmergencyCallCopy.confirmationTitle(for:)) ?? ""),
                    isPresented: Binding(get: { pendingEmergency != nil }, set: { if !$0 { pendingEmergency = nil } }),
                    titleVisibility: .visible,
                    presenting: pendingEmergency
                ) { plan in
                    // Dials exactly what was confirmed: the `EmergencyCallPlan` captured at the tap.
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
                .onChange(of: testMode.isOn) { _, _ in
                    // A result raised in the other mode is no longer true: its call
                    // buttons would dial a real contact under the Test Mode banner, or
                    // a drama number after Test Mode switched itself off. Covers the
                    // Settings toggle, the banner's button and the switch-off on
                    // leaving the app. Does nothing while an alert is in flight.
                    alert.reset()
                }
                .onChange(of: alert.phase) { _, phase in
                    // Brings the status view on screen as soon as work starts, not only
                    // once it finishes. This is a genuine value change every time (it is
                    // always reached from `.idle` or a *different* `.finished` outcome),
                    // unlike two identical `.finished` outcomes in a row, which `onChange`
                    // would not detect — see `raise(scrollProxy:)`.
                    if case .locating = phase {
                        scrollToStatus(proxy)
                        // The wait for a location can take up to three seconds. A
                        // VoiceOver user hears that it has started, not silence until
                        // Messages opens.
                        if let progress = AlertCopy.progress(phase) {
                            AccessibilityNotification.Announcement(progress).post()
                        }
                    }
                }
            }
        }
    }

    /// Handles a tap on the primary button, including a repeat tap that produces the
    /// *same* outcome as last time (for example, no contacts, twice in a row).
    ///
    /// `AlertModel.phase` does not change value in that case, so a view driven only by
    /// `.onChange(of: alert.phase)` would never react to the second tap — no navigation
    /// to add a contact, no VoiceOver announcement, nothing visibly different. Reading
    /// `alert.phase` here, right after `raise` returns, reacts every time regardless of
    /// whether the value repeats.
    private func raise(scrollProxy: ScrollViewProxy?) {
        let people = contacts.contacts
        let readable = contacts.loadState != .unreadable
        let isTest = testMode.isOn
        Task {
            await alert.raise(contacts: people, contactsReadable: readable, testMode: isTest)
            if case let .finished(outcome) = alert.phase {
                if outcome == .needsContacts || outcome == .contactsUnreadable {
                    showContacts = true
                }
                // VoiceOver users hear the outcome without hunting for it, every time —
                // not only the first time a given outcome occurs.
                AccessibilityNotification.Announcement(AlertCopy.message(for: outcome)).post()
            }
            scrollToStatus(scrollProxy)
        }
    }

    /// Brings the status view into the middle of the screen. Animated unless Reduce
    /// Motion is on, in which case the jump still happens — only the animation is
    /// skipped, never the outcome itself.
    private func scrollToStatus(_ proxy: ScrollViewProxy?) {
        guard let proxy else { return }
        if reduceMotion {
            proxy.scrollTo("alert.status", anchor: .center)
        } else {
            withAnimation {
                proxy.scrollTo("alert.status", anchor: .center)
            }
        }
    }

    /// Calls someone the failed alert was for.
    ///
    /// Defence in depth: refuses a recipient planned in the other mode. The screen
    /// already shows no such button, so this is never reached from a visible control.
    private func call(_ recipient: AlertRecipient) {
        guard alert.raisedInTestMode == testMode.isOn else { return }
        dial(recipient.number)
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
