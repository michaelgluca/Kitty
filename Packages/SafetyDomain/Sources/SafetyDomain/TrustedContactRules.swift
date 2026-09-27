import Foundation

/// Why a chosen number cannot become a trusted contact.
public enum TrustedContactRejection: Error, Equatable, Sendable {
    /// Nothing usable to text or call.
    case notAPhoneNumber
    /// 999, 112, 101, 18000, 61016 and every other short code, however it is
    /// written — "+44 18000" included. The alert texts every trusted contact, so a
    /// short code here would send it to 999 or a service without the person
    /// realising.
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

    /// A UK number written with +44 or 0044 is measured without the country code:
    /// otherwise "+44 18000" would count as seven digits and pass. A UK subscriber's
    /// national significant number (after +44, or after the leading 0) has nine or
    /// ten digits; every UK short code has six or fewer.
    public static let minimumUKNationalDigits = 9

    public static func make(
        displayName: String,
        rawNumber: String,
        existing: [TrustedContact]
    ) -> Result<TrustedContact, TrustedContactRejection> {
        guard let number = PhoneNumber(sanitised(rawNumber)) else { return .failure(.notAPhoneNumber) }
        guard isLongEnoughForAPerson(number) else { return .failure(.serviceNumber) }

        let key = comparisonKey(number)
        if let match = existing.first(where: { comparisonKey($0.phoneNumber) == key }) {
            return .failure(.duplicate(existingName: match.displayName))
        }

        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return .success(TrustedContact(displayName: trimmed.isEmpty ? number.raw : trimmed, phoneNumber: number))
    }

    /// The number itself, from whatever the contact picker hands over.
    ///
    /// iOS stores a pause as `,`, a wait as `;`, and people save extensions as
    /// "ext 12", "x12", "p123" or with `#` and `*`. Everything from the first of
    /// those is cut, because `PhoneNumber` keeps every digit and would run the
    /// extension into the number — which then texts and calls nobody. After a
    /// country code, a written "(0)" is the UK-style trunk prefix and is dropped:
    /// "+44 (0)7700 900001" is dialled as +44 7700 900001. In a national number the
    /// same "(0)" is the number's own first digit, so it is left alone.
    static func sanitised(_ raw: String) -> String {
        let number = String(raw.prefix { !isSeparator($0) })
        let trimmed = number.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("+") || trimmed.hasPrefix("00") else { return number }
        return number.replacingOccurrences(of: "(0)", with: "")
    }

    private static func isSeparator(_ character: Character) -> Bool {
        character == "," || character == ";" || character == "#" || character == "*" || character.isLetter
    }

    /// Long enough to be a person rather than a short code. A UK number written
    /// internationally is measured by its national significant number; every other
    /// number by its digits after any international prefix.
    static func isLongEnoughForAPerson(_ number: PhoneNumber) -> Bool {
        if let national = ukNationalSignificantNumber(of: number) {
            return national.count >= minimumUKNationalDigits
        }
        return significantDigits(of: number).count >= minimumDigits
    }

    /// The digits after any international prefix. "+44 999" and "0044 999" are 999
    /// with a country code in front, and must be caught exactly like 999.
    static func significantDigits(of number: PhoneNumber) -> Substring {
        let digits = number.dialable
        if digits.hasPrefix("+") { return digits.dropFirst() }
        if digits.hasPrefix("00") { return digits.dropFirst(2) }
        return Substring(digits)
    }

    /// For a number written with +44 or 0044, the digits after the country code and
    /// any trunk 0 ("+44 0…", the "+44 (0)" form written without brackets). `nil`
    /// for anything else, including a UK number written nationally.
    static func ukNationalSignificantNumber(of number: PhoneNumber) -> Substring? {
        let digits = number.dialable
        guard digits.hasPrefix("+") || digits.hasPrefix("00") else { return nil }
        let international = significantDigits(of: number)
        guard international.hasPrefix("44") else { return nil }
        let national = international.dropFirst(2)
        return national.hasPrefix("0") ? national.dropFirst() : national
    }

    /// UK numbers are saved several ways — 07700 900001, +44 7700 900001 and
    /// +44 (0)7700 900001 — and are the same person. Other countries' numbers are
    /// compared exactly.
    static func comparisonKey(_ number: PhoneNumber) -> String {
        if let national = ukNationalSignificantNumber(of: number) { return "0" + national }
        return number.dialable
    }
}
