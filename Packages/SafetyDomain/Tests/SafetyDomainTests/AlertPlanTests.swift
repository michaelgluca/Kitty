import Foundation
import Testing

@testable import SafetyDomain

@Suite("Test Mode numbers")
struct TestModeNumbersTests {

    @Test("Each stand-in is in the drama range, and they never collide")
    func standIns() {
        #expect(TestModeNumbers.emergency.raw == "07700 900999")
        #expect(TestModeNumbers.service.raw == "07700 900000")
        #expect(TestModeNumbers.contact(at: 0).raw == "07700 900001")
        #expect(TestModeNumbers.contact(at: 1).raw == "07700 900002")

        let contacts = (-10..<2_000).map { TestModeNumbers.contact(at: $0) }
        #expect(contacts.allSatisfy { $0.isReservedForDrama })
        #expect(!contacts.contains(TestModeNumbers.emergency))
        #expect(!contacts.contains(TestModeNumbers.service))
    }
}

@Suite("Alert plan")
struct AlertPlanTests {

    // London and Leeds numbers from Ofcom's drama ranges. PhoneNumber does not
    // recognise these ranges as drama, so they stand in for real numbers here and
    // prove that Test Mode replaces them.
    private let alice = TrustedContact(displayName: "Alice", phoneNumber: PhoneNumber("020 7946 0018")!)
    private let bob = TrustedContact(displayName: "Bob", phoneNumber: PhoneNumber("0113 496 0001")!)

    @Test("No contacts means setup, never a message to nobody")
    func noContacts() {
        #expect(AlertPlanner.plan(contacts: [], testMode: false) == .needsContacts)
        #expect(AlertPlanner.plan(contacts: [], testMode: true) == .needsContacts)
    }

    @Test("A real alert goes to every trusted contact, in the person's order")
    func real() {
        #expect(AlertPlanner.plan(contacts: [alice, bob], testMode: false) == .ready(
            recipients: [
                AlertRecipient(name: "Alice", number: alice.phoneNumber),
                AlertRecipient(name: "Bob", number: bob.phoneNumber),
            ],
            isTest: false
        ))
    }

    @Test("In Test Mode no recipient is a real number, and names are kept so the flow reads the same")
    func testMode() {
        #expect(AlertPlanner.plan(contacts: [alice, bob], testMode: true) == .ready(
            recipients: [
                AlertRecipient(name: "Alice", number: TestModeNumbers.contact(at: 0)),
                AlertRecipient(name: "Bob", number: TestModeNumbers.contact(at: 1)),
            ],
            isTest: true
        ))
    }
}

@Suite("999 call plan")
struct EmergencyCallPlanTests {

    @Test("In the UK, outside Test Mode, it dials the content pack's number")
    func real() throws {
        let plan = try #require(EmergencyCallPlanner.plan(emergencyNumber: "999", region: .unitedKingdom, testMode: false))
        #expect(plan.emergencyNumber.dialable == "999")
        #expect(plan.dialled.dialable == "999")
        #expect(!plan.isTest)
    }

    @Test("In Test Mode it dials the drama stand-in and never 999, but still shows what it stands in for")
    func testMode() throws {
        let plan = try #require(EmergencyCallPlanner.plan(emergencyNumber: "999", region: .unitedKingdom, testMode: true))
        #expect(plan.dialled == TestModeNumbers.emergency)
        #expect(plan.dialled.dialable != "999")
        #expect(plan.emergencyNumber.dialable == "999")
        #expect(plan.isTest)
    }

    @Test("Outside the UK there is no 999 button at all")
    func elsewhere() {
        #expect(EmergencyCallPlanner.plan(emergencyNumber: "999", region: .elsewhere(countryCode: "US"), testMode: false) == nil)
        #expect(EmergencyCallPlanner.plan(emergencyNumber: "999", region: .elsewhere(countryCode: nil), testMode: true) == nil)
    }

    @Test("Missing or unusable content means no button, never a guessed number")
    func missingContent() {
        #expect(EmergencyCallPlanner.plan(emergencyNumber: nil, region: .unitedKingdom, testMode: false) == nil)
        #expect(EmergencyCallPlanner.plan(emergencyNumber: "", region: .unitedKingdom, testMode: false) == nil)
    }
}
