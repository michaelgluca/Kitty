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
    ])
    func refusesShortCodes(number: String) {
        // The alert texts every trusted contact. A short code here would send it to
        // 999 or a service without the person realising — contacting emergency
        // services without an explicit action, which this app must never do.
        #expect(make(number) == .failure(.serviceNumber))
    }

    @Test("Refuses input that is not a phone number")
    func refusesJunk() {
        #expect(make("") == .failure(.notAPhoneNumber))
        #expect(make("not a number") == .failure(.notAPhoneNumber))
    }

    @Test("Refuses a number already on the list however it is written, and names who has it")
    func refusesDuplicates() throws {
        let alice = try make("07700 900001", name: "Alice").get()
        for written in ["07700900001", "+44 7700 900001", "0044 7700 900001"] {
            #expect(make(written, name: "Someone", existing: [alice]) == .failure(.duplicate(existingName: "Alice")))
        }
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
