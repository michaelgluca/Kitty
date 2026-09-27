import Observation
import SafetyDomain
import SafetyServices
import SwiftUI

/// Calling and texting a support service, with the confirmation and failure report
/// every such button needs. Shared by the Help and Refuges screens so the safeguards
/// cannot drift apart between them.
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

    /// Where a text goes. In Test Mode it goes to a drama number, like every other
    /// flow, so a rehearsal can never open Messages to 61016 or a helpline's text
    /// line.
    static func textTarget(for number: PhoneNumber, testMode: Bool) -> PhoneNumber {
        testMode ? TestModeNumbers.service : number
    }

    /// In Test Mode a text goes to a drama number, like every other flow.
    func text(_ number: PhoneNumber, testMode: Bool, using texter: any TextOpening) async {
        let target = Self.textTarget(for: number, testMode: testMode)
        if await texter.openText(to: target) == false {
            failure = .text(target)
        }
    }
}

extension View {
    /// The confirmation before any call, and the report when a call or text cannot
    /// start. ONE confirmation per screen, never one per row: with a dialog on every
    /// row of a List, SwiftUI presented the previous row's dialog (see M2).
    func serviceContactDialogs(_ actions: ServiceContactActions, dialler: any Dialling) -> some View {
        modifier(ServiceContactDialogs(actions: actions, dialler: dialler))
    }
}

private struct ServiceContactDialogs: ViewModifier {

    let actions: ServiceContactActions
    let dialler: any Dialling

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                Text(actions.pendingCall.map { String(format: Strings.localized("help.callConfirm.title"), $0.serviceName) } ?? ""),
                isPresented: Binding(get: { actions.pendingCall != nil }, set: { if !$0 { actions.pendingCall = nil } }),
                titleVisibility: .visible,
                presenting: actions.pendingCall
            ) { call in
                Button(Strings.localized("help.callConfirm.confirm")) {
                    Task { await actions.place(call, using: dialler) }
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
