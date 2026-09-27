import Foundation
import SafetyDomain
import SafetyServices
import Testing

@testable import SafetyUI

private let everyOutcome: [AlertModel.Outcome] = [
    .handedToMessages(includedLocation: true), .handedToMessages(includedLocation: false),
    .cancelled, .failed, .cannotText, .needsContacts, .contactsUnreadable,
]

private let everyAuthorization: [LocationAuthorization] = [
    .notDetermined, .denied, .restricted, .authorizedWhenInUse, .authorizedReducedAccuracy,
]

/// True when the text is real copy rather than an unresolved catalogue key. Every
/// sentence checked here has a space in it; a raw key such as
/// "alert.result.failed" never does.
private func isResolved(_ text: String) -> Bool {
    !text.isEmpty && text.contains(" ")
}

@Suite("Screen copy")
struct ScreenCopyTests {

    @Test("Every alert outcome has real words")
    func outcomes() {
        for outcome in everyOutcome {
            #expect(isResolved(AlertCopy.message(for: outcome)), "Unresolved copy for \(outcome)")
        }
        #expect(isResolved(AlertCopy.progress(.locating) ?? ""))
        #expect(isResolved(AlertCopy.progress(.composing) ?? ""))
        #expect(AlertCopy.progress(.idle) == nil)
    }

    @Test("Never claims delivery, and says whether the location went with it")
    func sentIsHonest() {
        let with = AlertCopy.message(for: .handedToMessages(includedLocation: true))
        let without = AlertCopy.message(for: .handedToMessages(includedLocation: false))
        #expect(with.contains("cannot confirm"))
        #expect(with.contains("included where you are"))
        #expect(without.contains("did not include your location"))
    }

    @Test("Offers calls exactly when the message could not go")
    func offersCalls() {
        #expect(AlertCopy.offersCalls(.failed))
        #expect(AlertCopy.offersCalls(.cannotText))
        #expect(!AlertCopy.offersCalls(.cancelled))
        #expect(!AlertCopy.offersCalls(.handedToMessages(includedLocation: true)))
        #expect(!AlertCopy.offersCalls(.needsContacts))
    }

    @Test("A call-instead button names the person and the number")
    func callButton() {
        let label = AlertCopy.callButton(for: AlertRecipient(name: "Alice", number: .drama(1)))
        #expect(label == "Call Alice (07700 900001)")
    }

    @Test("Every location state has real words and the right action")
    func location() {
        for authorization in everyAuthorization {
            #expect(isResolved(LocationCopy.message(for: authorization)), "Unresolved copy for \(authorization)")
        }
        #expect(LocationCopy.action(for: .notDetermined) == .allow)
        #expect(LocationCopy.action(for: .denied) == .openSettings)
        #expect(LocationCopy.action(for: .authorizedReducedAccuracy) == .openSettings)
        #expect(LocationCopy.action(for: .restricted) == nil)
        #expect(LocationCopy.action(for: .authorizedWhenInUse) == nil)
    }

    @Test("The 999 confirmation names 999 and says the iPhone shares its location")
    func emergencyReal() throws {
        let plan = try #require(EmergencyCallPlanner.plan(emergencyNumber: "999", region: .unitedKingdom, testMode: false))
        #expect(EmergencyCallCopy.buttonTitle(for: plan) == "Call 999")
        #expect(EmergencyCallCopy.confirmationTitle(for: plan) == "Call 999?")
        let message = EmergencyCallCopy.confirmationMessage(for: plan)
        #expect(message.contains("999"))
        #expect(message.contains("shares its location"))
        #expect(message.contains("does not make the call"))
    }

    @Test("In Test Mode the 999 button and confirmation say so and name the stand-in")
    func emergencyTestMode() throws {
        let plan = try #require(EmergencyCallPlanner.plan(emergencyNumber: "999", region: .unitedKingdom, testMode: true))
        #expect(EmergencyCallCopy.buttonTitle(for: plan) == "Call 999 (Test Mode)")
        let message = EmergencyCallCopy.confirmationMessage(for: plan)
        #expect(message.hasPrefix("Test Mode: this will call 07700 900999"))
        #expect(message.contains("999 will not be called"))
    }

    @Test("Every contacts problem has real words, naming the number or person involved")
    func problems() {
        let problems: [ContactsModel.Problem] = [
            .rejected(.notAPhoneNumber, number: ""),
            .rejected(.serviceNumber, number: "999"),
            .rejected(.duplicate(existingName: "Alice"), number: "07700 900001"),
            .saveFailed,
            .pickerUnavailable,
        ]
        for problem in problems {
            #expect(isResolved(problem.message), "Unresolved copy for \(problem)")
        }
        #expect(ContactsModel.Problem.rejected(.serviceNumber, number: "999").message.contains("999"))
        #expect(ContactsModel.Problem.rejected(.duplicate(existingName: "Alice"), number: "x").message.contains("Alice"))
    }

    @Test("The combined sent message format has exactly the two positional placeholders")
    func sentCombinedFormat() {
        let combined = Strings.localized("alert.result.sent.combined")
        #expect(combined.contains("%1$@"))
        #expect(combined.contains("%2$@"))
        #expect(!combined.contains("%3$@"))
    }

    @Test("Every key the screens use resolves", arguments: [
        "alert.contacts.title", "alert.contacts.none", "alert.contacts.unreadable", "alert.contacts.add",
        "alert.contacts.open",
        "alert.result.dismiss", "alert.result.sent.combined", "alert.location.allow", "alert.location.openSettings", "alert.location.settingsFailed",
        "emergency.call.hint", "emergency.unavailable",
        "contacts.title", "contacts.explainer", "contacts.add", "contacts.empty",
        "contacts.remove.action", "contacts.remove.title", "contacts.remove.message", "contacts.remove.confirm",
        "contacts.remove.row",
        "contacts.unreadable.title", "contacts.unreadable.body", "contacts.unreadable.startNew",
        "contacts.unreadable.confirmTitle", "contacts.unreadable.confirmMessage",
        "settings.testMode.toggle", "settings.testMode.footer",
    ])
    func keysResolve(key: String) {
        #expect(Strings.localized(String.LocalizationValue(key)) != key, "Missing catalogue entry: \(key)")
    }
}
