import Observation
import SafetyDomain
import SafetyServices
import SwiftUI

/// Calling and texting a support service, with the confirmation and failure report
/// every such button needs. Owned by `ServiceContactHost`, the one place that also
/// reads Test Mode and the services, so Get help and Refuges cannot drift apart.
@MainActor
@Observable
final class ServiceContactActions {

    /// The one call awaiting confirmation, captured whole at the tap.
    var pendingCall: PendingCall?
    /// A call or text the system could not start. Never silent: the number is shown
    /// so the person can dial or text it by hand.
    var failure: ContactFailure?

    func requestCall(_ number: PhoneNumber, serviceName: String, testMode: Bool) {
        pendingCall = PendingCall.make(serviceName: serviceName, number: number, testMode: testMode)
    }

    /// Dials exactly the number that was confirmed — never re-read from state.
    func place(_ call: PendingCall, using dialler: any Dialling) async {
        if await dialler.dial(call.dialled) == false {
            failure = .call(call.dialled)
        }
    }

    /// Where a call or text goes. In Test Mode it goes to a drama number, like every
    /// other flow, so a rehearsal can never ring or open Messages to 61016 or a
    /// helpline's own line.
    nonisolated static func target(for number: PhoneNumber, testMode: Bool) -> PhoneNumber {
        testMode ? TestModeNumbers.service : number
    }

    func text(_ number: PhoneNumber, testMode: Bool, using texter: any TextOpening) async {
        let target = Self.target(for: number, testMode: testMode)
        if await texter.openText(to: target) == false {
            failure = .text(target)
        }
    }
}

/// What a service row calls when the person taps Call or Text.
struct ServiceContact {
    /// The number, and the service's name for the confirmation.
    let call: (PhoneNumber, String) -> Void
    let text: (PhoneNumber) -> Void
}

/// Hands its content the way to call and text a service, and presents the
/// confirmation and the failure report that go with it. Every screen that lists
/// services puts them inside one, so Test Mode is read, and its drama number used, in
/// exactly one place.
///
/// ONE confirmation per screen, never one per row: with a dialog on every row of a
/// List, SwiftUI presented the previous row's dialog.
struct ServiceContactHost<Content: View>: View {

    @Environment(\.services) private var services
    // Optional: returns nil rather than crashing when no session is supplied, such as
    // in a preview. No session in the environment means Test Mode is off.
    @Environment(TestModeSession.self) private var testMode: TestModeSession?

    @State private var actions = ServiceContactActions()

    @ViewBuilder let content: (ServiceContact) -> Content

    /// Read at the tap, so a call or text always follows Test Mode as it is now.
    private var isTestMode: Bool { testMode?.isOn == true }

    var body: some View {
        content(ServiceContact(call: call, text: text))
            .confirmationDialog(
                Text(actions.pendingCall.map { String(format: Strings.localized("help.callConfirm.title"), $0.serviceName) } ?? ""),
                isPresented: Binding(get: { actions.pendingCall != nil }, set: { if !$0 { actions.pendingCall = nil } }),
                titleVisibility: .visible,
                presenting: actions.pendingCall
            ) { call in
                Button(Strings.localized("help.callConfirm.confirm")) {
                    Task { await actions.place(call, using: services.dialler) }
                }
                Button(Strings.localized("help.callConfirm.cancel"), role: .cancel) {}
            } message: { call in
                Text(call.confirmationMessage)
            }
            .alert(
                Text(actions.failure.map(\.message) ?? ""),
                isPresented: Binding(get: { actions.failure != nil }, set: { if !$0 { actions.failure = nil } })
            ) {
                Button(Strings.localized("help.ok"), role: .cancel) {}
            }
    }

    private func call(_ number: PhoneNumber, serviceName: String) {
        actions.requestCall(number, serviceName: serviceName, testMode: isTestMode)
    }

    private func text(_ number: PhoneNumber) {
        let texter = services.texter
        let testMode = isTestMode
        Task { await actions.text(number, testMode: testMode, using: texter) }
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
            dialled: ServiceContactActions.target(for: number, testMode: testMode),
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
