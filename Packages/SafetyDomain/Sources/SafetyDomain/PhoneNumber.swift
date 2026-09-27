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
        // Three digits is the shortest real service number in the UK — 101, the
        // police non-emergency line. An earlier five-digit minimum silently made 101
        // impossible to call.
        //
        // Whether a number is acceptable as a *trusted contact* is a separate, stricter
        // question — an emergency short code must never become one — and is decided
        // where contacts are chosen, not here.
        guard digits.count >= 3 else { return nil }

        self.raw = trimmed
        self.dialable = (hasPlus ? "+" : "") + digits
    }
}

public extension PhoneNumber {

    /// Opens the dialler. Always `tel:`, never `telprompt:` — `telprompt:` skips the
    /// system's own call confirmation, which is the second safeguard behind the app's.
    var callURL: URL? { URL(string: "tel:\(dialable)") }

    /// Opens Messages to this number with nothing pre-filled.
    ///
    /// The documented `sms:` scheme takes a number only; Apple's reference says the URL
    /// "must not include any message text". The widely copied `&body=` is undocumented,
    /// and the 2023 build used it wrongly. Nothing is appended.
    var textURL: URL? { URL(string: "sms:\(dialable)") }
}
