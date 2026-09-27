import Foundation
import SafetyDomain
import SafetyServices

// Which words each state gets. Kept apart from the views so every state can be
// checked for real text: a missing catalogue entry renders its key, and on the
// Alert tab that would be the thing someone reads in a crisis.

enum AlertCopy {

    static func progress(_ phase: AlertModel.Phase) -> String? {
        switch phase {
        case .locating: Strings.localized("alert.phase.locating")
        case .composing: Strings.localized("alert.phase.composing")
        case .idle, .finished: nil
        }
    }

    static func message(for outcome: AlertModel.Outcome) -> String {
        switch outcome {
        case let .handedToMessages(includedLocation):
            let location: String.LocalizationValue = includedLocation
                ? "alert.result.sent.withLocation"
                : "alert.result.sent.withoutLocation"
            return Strings.localized("alert.result.sent") + " " + Strings.localized(location)
        case .cancelled: return Strings.localized("alert.result.cancelled")
        case .failed: return Strings.localized("alert.result.failed")
        case .cannotText: return Strings.localized("alert.result.cannotText")
        case .needsContacts: return Strings.localized("alert.result.needsContacts")
        case .contactsUnreadable: return Strings.localized("alert.result.contactsUnreadable")
        }
    }

    /// When the message could not go, calling is the next-best way to reach someone.
    static func offersCalls(_ outcome: AlertModel.Outcome) -> Bool {
        outcome == .failed || outcome == .cannotText
    }

    static func callButton(for recipient: AlertRecipient) -> String {
        String(format: Strings.localized("alert.callContact"), recipient.name, recipient.number.raw)
    }
}

enum LocationAction: Equatable {
    case allow
    case openSettings
}

enum LocationCopy {

    static func message(for authorization: LocationAuthorization) -> String {
        switch authorization {
        case .authorizedWhenInUse: Strings.localized("alert.location.on")
        case .notDetermined: Strings.localized("alert.location.notDetermined")
        case .denied: Strings.localized("alert.location.denied")
        case .restricted: Strings.localized("alert.location.restricted")
        case .authorizedReducedAccuracy: Strings.localized("alert.location.reduced")
        }
    }

    /// Restricted has no action: the person cannot change it from Settings either.
    static func action(for authorization: LocationAuthorization) -> LocationAction? {
        switch authorization {
        case .notDetermined: .allow
        case .denied, .authorizedReducedAccuracy: .openSettings
        case .restricted, .authorizedWhenInUse: nil
        }
    }
}

enum EmergencyCallCopy {

    static func buttonTitle(for plan: EmergencyCallPlan) -> String {
        plan.isTest
            ? String(format: Strings.localized("emergency.call.buttonTestMode"), plan.emergencyNumber.raw)
            : String(format: Strings.localized("help.call"), plan.emergencyNumber.raw)
    }

    static func confirmationTitle(for plan: EmergencyCallPlan) -> String {
        String(format: Strings.localized("help.callConfirm.title"), plan.emergencyNumber.raw)
    }

    static func confirmationMessage(for plan: EmergencyCallPlan) -> String {
        plan.isTest
            ? String(format: Strings.localized("emergency.confirm.messageTestMode"), plan.dialled.raw, plan.emergencyNumber.raw)
            : String(format: Strings.localized("emergency.confirm.message"), plan.emergencyNumber.raw)
    }
}

extension ContactsModel.Problem {

    var message: String {
        switch self {
        case .rejected(.notAPhoneNumber, _):
            Strings.localized("contacts.problem.notAPhoneNumber")
        case let .rejected(.serviceNumber, number):
            String(format: Strings.localized("contacts.problem.serviceNumber"), number)
        case let .rejected(.duplicate(existingName), _):
            String(format: Strings.localized("contacts.problem.duplicate"), existingName)
        case .saveFailed:
            Strings.localized("contacts.problem.saveFailed")
        case .pickerUnavailable:
            Strings.localized("contacts.problem.pickerUnavailable")
        }
    }
}
