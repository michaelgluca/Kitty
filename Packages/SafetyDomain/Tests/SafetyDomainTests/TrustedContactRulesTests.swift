import Foundation
import Testing

@testable import SafetyDomain

@Suite("Trusted contact rules")
struct TrustedContactRulesTests {

    private func make(
        _ number: String,
        name: String = "Alice",
        existing: [TrustedContact] = []
    ) -> Result<TrustedContact, TrustedContactRejection> {
        TrustedContactRules.make(displayName: name, rawNumber: number, existing: existing)
    }

    @Test("Accepts ordinary UK numbers, national and international", arguments: [
        "07700 900001", "+44 7700 900001", "0044 7700 900001", "(020) 7946 0018",
    ])
    func acceptsPeople(number: String) throws {
        let contact = try make(number).get()
        #expect(contact.phoneNumber.raw == number)
        #expect(contact.displayName == "Alice")
    }

    @Test("Refuses 999 and every other emergency or service short code", arguments: [
        "999", "112", "911", "000", "18000", "61016", "101", "111", "116 123",
        "+44 999", "0044 999", "+1 911", "0999",
        // UK short codes written internationally. The country code must not count
        // towards the length of the number: "+44 18000" is 18000, not a 7-digit number.
        "+44 18000", "0044 18000", "+44 61016", "0044 61016", "+44 116 123", "0044 116 123",
        "+44 (0)999", "+44 0999",
    ])
    func refusesShortCodes(number: String) {
        // The alert texts every trusted contact. A short code here would send it to
        // 999 or a service without the person realising — contacting emergency
        // services without an explicit action, which this app must never do.
        #expect(make(number) == .failure(.serviceNumber))
    }

    @Test("Accepts the UK \"+44 (0)\" form, and stores the number without the (0)", arguments: [
        ("+44 (0)7700 900001", "+44 7700 900001", "+447700900001"),
        ("+44(0)7700 900001", "+447700 900001", "+447700900001"),
        ("0044 (0)7700 900001", "0044 7700 900001", "00447700900001"),
    ])
    func acceptsTheTrunkZeroForm(written: String, stored: String, dialable: String) throws {
        // Dialled with the 0 after the country code, the number would not connect.
        let contact = try make(written).get()
        #expect(contact.phoneNumber.raw == stored)
        #expect(contact.phoneNumber.dialable == dialable)
    }

    @Test("Keeps a (0) that is part of a national number")
    func keepsANationalLeadingZero() throws {
        // Only after a country code is "(0)" a trunk prefix to drop. Written at the
        // start of a national number, it is the number's own first digit.
        let contact = try make("(0)7700 900001").get()
        #expect(contact.phoneNumber.dialable == "07700900001")
    }

    @Test("Stores only the number when the picker adds a pause, a wait or an extension", arguments: [
        "07700 900001,123", "07700 900001;123", "07700 900001 ext 12", "07700 900001 x12",
        "07700 900001p123", "07700 900001w123", "07700 900001#", "07700 900001*9",
    ])
    func cutsAtPausesAndExtensions(written: String) throws {
        // A pause or extension run into the digits would text and call a number
        // that does not exist.
        let contact = try make(written).get()
        #expect(contact.phoneNumber.raw == "07700 900001")
        #expect(contact.phoneNumber.dialable == "07700900001")
    }

    @Test("Refuses input that is not a phone number")
    func refusesJunk() {
        #expect(make("") == .failure(.notAPhoneNumber))
        #expect(make("not a number") == .failure(.notAPhoneNumber))
    }

    @Test("Refuses a number already on the list however it is written, and names who has it")
    func refusesDuplicates() throws {
        let alice = try make("07700 900001", name: "Alice").get()
        for written in [
            "07700900001", "+44 7700 900001", "0044 7700 900001",
            "+44 (0)7700 900001", "+44 07700 900001", "0044 07700 900001", "07700 900001,123",
        ] {
            #expect(make(written, name: "Someone", existing: [alice]) == .failure(.duplicate(existingName: "Alice")))
        }
    }

    @Test("A number already stored in the +44 0 form is still recognised as a duplicate")
    func refusesDuplicatesOfATrunkZeroForm() throws {
        // Saved before the (0) was dropped, or typed without the brackets.
        let stored = TrustedContact(displayName: "Alice", phoneNumber: try #require(PhoneNumber("+44 07700 900001")))
        #expect(make("07700 900001", name: "Someone", existing: [stored]) == .failure(.duplicate(existingName: "Alice")))
    }

    @Test("A contact saved without a name is shown by their number, not as a blank row")
    func blankNameFallsBackToNumber() throws {
        #expect(try make("07700 900001", name: "   ").get().displayName == "07700 900001")
    }

    @Test("Trims the name")
    func trimsName() throws {
        #expect(try make("07700 900001", name: "  Alice \n").get().displayName == "Alice")
    }
}

@Suite("Drama numbers")
struct DramaNumberTests {

    @Test("Builds numbers in Ofcom's reserved drama range, readable and dialable")
    func builds() {
        let n = PhoneNumber.drama(999)
        #expect(n.raw == "07700 900999")
        #expect(n.dialable == "07700900999")
        #expect(n.isReservedForDrama)
        #expect(PhoneNumber.drama(1).raw == "07700 900001")
        #expect(PhoneNumber.drama(0).raw == "07700 900000")
    }

    @Test("Can never leave the reserved range, whatever it is given", arguments: [
        -1, 0, 1, 500, 999, 1_000, Int.max, Int.min,
    ])
    func clamps(suffix: Int) {
        #expect(PhoneNumber.drama(suffix).isReservedForDrama)
    }

    @Test("Clamps below and above the range to its ends")
    func clampsToEnds() {
        #expect(PhoneNumber.drama(-5).raw == "07700 900000")
        #expect(PhoneNumber.drama(5_000).raw == "07700 900999")
    }
}
