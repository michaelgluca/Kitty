import Foundation

/// A phone number the user chose, kept as the digits and symbols needed to dial.
///
/// Deliberately permissive about format. Numbers arrive from the system contact
/// picker in whatever shape the user saved them, and rejecting a number a person
/// deliberately chose as an emergency contact would be worse than dialling
/// something the network then refuses.
public struct PhoneNumber: Hashable, Sendable, Codable {
    public let raw: String

    /// Digits plus a leading `+`, suitable for a `tel:` or `sms:` URL.
    public let dialable: String

    /// Numbers in Ofcom's reserved drama range (07700 900000–900999) cannot reach a
    /// real subscriber, so they are safe in tests and in Test Mode.
    public var isReservedForDrama: Bool {
        let digits = dialable.drop { $0 == "+" }
        let national: Substring
        if digits.hasPrefix("44") {
            national = "0" + digits.dropFirst(2)
        } else {
            national = Substring(digits)
        }
        guard national.count == 11, national.hasPrefix("07700") else { return false }
        let block = national.dropFirst(5)
        return block.hasPrefix("900")
    }

    public init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let hasPlus = trimmed.hasPrefix("+")
        let digits = trimmed.filter(\.isNumber)
        // Shorter than this cannot be a contact number. Emergency short codes are
        // never stored as contacts — they live in SafetyContent behind a confirmation.
        guard digits.count >= 5 else { return nil }

        self.raw = trimmed
        self.dialable = (hasPlus ? "+" : "") + digits
    }
}
