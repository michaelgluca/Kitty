import Foundation

/// The numbers Test Mode uses in place of real ones.
///
/// Every one is in Ofcom's reserved drama range, so no Test Mode flow can reach a
/// real person, a helpline or 999.
public enum TestModeNumbers {
    /// Stands in for 999.
    public static let emergency = PhoneNumber.drama(999)
    /// Stands in for any support service's call or text line.
    public static let service = PhoneNumber.drama(0)

    /// Stands in for the trusted contact at `index`: 07700 900001 upward, wrapping
    /// within 900001–900998 so it never collides with the two numbers above.
    public static func contact(at index: Int) -> PhoneNumber {
        let slot = ((index % 998) + 998) % 998
        return .drama(1 + slot)
    }
}

/// One person an alert is addressed to.
public struct AlertRecipient: Equatable, Sendable {
    public let name: String
    public let number: PhoneNumber

    public init(name: String, number: PhoneNumber) {
        self.name = name
        self.number = number
    }
}

public enum AlertPlan: Equatable, Sendable {
    /// No one to alert. The screen routes to choosing contacts rather than failing.
    case needsContacts
    case ready(recipients: [AlertRecipient], isTest: Bool)
}

public enum AlertPlanner {

    /// Who the alert goes to. In Test Mode every number is replaced with a drama
    /// number and the names are kept, so the rehearsal reads exactly like the real
    /// thing and still cannot reach anyone.
    public static func plan(contacts: [TrustedContact], testMode: Bool) -> AlertPlan {
        guard !contacts.isEmpty else { return .needsContacts }
        let recipients = contacts.enumerated().map { index, contact in
            AlertRecipient(
                name: contact.displayName,
                number: testMode ? TestModeNumbers.contact(at: index) : contact.phoneNumber
            )
        }
        return .ready(recipients: recipients, isTest: testMode)
    }
}

/// What tapping the 999 button will do.
public struct EmergencyCallPlan: Equatable, Sendable {
    /// The number the person asked for, shown on the button and in the confirmation.
    public let emergencyNumber: PhoneNumber
    /// What will actually be dialled. Differs from `emergencyNumber` only in Test Mode.
    public let dialled: PhoneNumber
    public let isTest: Bool
}

public enum EmergencyCallPlanner {

    /// `nil` means there is no 999 button.
    ///
    /// 999 works only in the UK. Elsewhere the region-aware disclaimer tells the
    /// person to call their local emergency number, rather than the app guessing one.
    /// Missing content also means no button — never a guessed number.
    public static func plan(emergencyNumber: String?, region: RegionStance, testMode: Bool) -> EmergencyCallPlan? {
        guard region.isUnitedKingdom, let raw = emergencyNumber, let number = PhoneNumber(raw) else { return nil }
        return EmergencyCallPlan(
            emergencyNumber: number,
            dialled: testMode ? TestModeNumbers.emergency : number,
            isTest: testMode
        )
    }
}
