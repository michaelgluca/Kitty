import Foundation

/// Why a chosen number cannot become a trusted contact.
public enum TrustedContactRejection: Error, Equatable, Sendable {
    /// Nothing usable to text or call.
    case notAPhoneNumber
    /// 999, 112, 101, 18000, 61016 and every other short code. The alert texts every
    /// trusted contact, so a short code here would send it to 999 or a service
    /// without the person realising.
    case serviceNumber
    /// Already on the list, under this name.
    case duplicate(existingName: String)
}

/// Decides whether a number chosen in the contact picker may become a trusted contact.
///
/// Stricter than `PhoneNumber`, which must also accept 101 and 61016 so the Help
/// screen can call and text them. A trusted contact is a person.
public enum TrustedContactRules {

    /// Emergency and service short codes are at most six digits (116 123 is the
    /// longest in the UK). A person's number, even in the smallest numbering plans,
    /// has seven or more once written with its country code.
    public static let minimumDigits = 7

    public static func make(
        displayName: String,
        rawNumber: String,
        existing: [TrustedContact]
    ) -> Result<TrustedContact, TrustedContactRejection> {
        guard let number = PhoneNumber(rawNumber) else { return .failure(.notAPhoneNumber) }
        guard significantDigits(of: number).count >= minimumDigits else { return .failure(.serviceNumber) }

        let key = comparisonKey(number)
        if let match = existing.first(where: { comparisonKey($0.phoneNumber) == key }) {
            return .failure(.duplicate(existingName: match.displayName))
        }

        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return .success(TrustedContact(displayName: trimmed.isEmpty ? number.raw : trimmed, phoneNumber: number))
    }

    /// The digits after any international prefix. "+44 999" and "0044 999" are 999
    /// with a country code in front, and must be caught exactly like 999.
    static func significantDigits(of number: PhoneNumber) -> Substring {
        let digits = number.dialable
        if digits.hasPrefix("+") { return digits.dropFirst() }
        if digits.hasPrefix("00") { return digits.dropFirst(2) }
        return Substring(digits)
    }

    /// UK numbers are saved both ways — 07700 900001 and +44 7700 900001 — and are
    /// the same person. Other countries' numbers are compared exactly.
    static func comparisonKey(_ number: PhoneNumber) -> String {
        let digits = number.dialable
        if digits.hasPrefix("+44") { return "0" + digits.dropFirst(3) }
        if digits.hasPrefix("0044") { return "0" + digits.dropFirst(4) }
        return digits
    }
}
