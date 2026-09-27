import Foundation
import SafetyDomain
import SafetyTesting
import SwiftUI
import Testing

@testable import SafetyUI

@MainActor
@Suite("Test Mode session")
struct TestModeSessionTests {

    @Test("Off at every launch")
    func offByDefault() {
        #expect(TestModeSession().isOn == false)
    }

    @Test("Switches itself off when the app goes to the background")
    func offInBackground() {
        // Left on by accident, Test Mode would send a real alert to drama numbers.
        // Leaving the app is the moment it is most likely to be forgotten.
        let session = TestModeSession()
        session.isOn = true
        session.scenePhaseChanged(to: .background)
        #expect(!session.isOn)
    }

    @Test("Survives a brief interruption such as Control Centre")
    func staysOnWhenInactive() {
        let session = TestModeSession()
        session.isOn = true
        session.scenePhaseChanged(to: .inactive)
        session.scenePhaseChanged(to: .active)
        #expect(session.isOn)
    }
}

@MainActor
@Suite("Help-screen calls in Test Mode")
struct HelpCallTestModeTests {

    @Test("In Test Mode a Help-screen call dials the stand-in and names the number it replaces")
    func testMode() throws {
        let real = try #require(PhoneNumber("0808 2000 247"))
        let call = PendingCall.make(serviceName: "Helpline", number: real, testMode: true)
        #expect(call.dialled == TestModeNumbers.service)
        #expect(call.isTest)
        #expect(call.confirmationMessage.contains("07700 900000"))
        #expect(call.confirmationMessage.contains("0808 2000 247"))
    }

    @Test("Outside Test Mode it dials exactly the number shown")
    func real() throws {
        let real = try #require(PhoneNumber("0808 2000 247"))
        let call = PendingCall.make(serviceName: "Helpline", number: real, testMode: false)
        #expect(call.dialled == real)
        #expect(!call.isTest)
        #expect(call.confirmationMessage.contains("0808 2000 247"))
        #expect(!call.confirmationMessage.contains("07700"))
    }

    @Test("In Test Mode a Help-screen text opens Messages to the stand-in, never the service")
    func textInTestMode() async throws {
        let real = try #require(PhoneNumber("61016"))
        let target = HelpScreen.textTarget(for: real, testMode: true)
        #expect(target == TestModeNumbers.service)

        // SpyTextOpener stops the test outright if handed a number outside the drama
        // range, so a Test Mode text that leaked the real number could not pass here.
        let texter = SpyTextOpener()
        #expect(await texter.openText(to: target))
        #expect(texter.opened == [TestModeNumbers.service])
    }

    @Test("Outside Test Mode a Help-screen text goes to exactly the number shown")
    func textOutsideTestMode() throws {
        let real = try #require(PhoneNumber("61016"))
        #expect(HelpScreen.textTarget(for: real, testMode: false) == real)
    }

    @Test("The Test Mode banner's words resolve to real text")
    func bannerCopy() {
        for key in ["testMode.banner.title", "testMode.banner.body", "testMode.banner.turnOff"] {
            let value = Strings.localized(String.LocalizationValue(key))
            #expect(value != key, "Missing catalogue entry: \(key)")
        }
    }
}

/// The doubles that stand in for calls and texts must themselves refuse a real
/// number, or a Test Mode regression would pass every test while reaching a person.
@Suite("Doubles refuse real numbers")
struct DoublesRefuseRealNumbersTests {

    @Test("The text double stops the test when handed a number outside the drama range")
    func textOpenerTraps() async {
        await #expect(processExitsWith: .failure) {
            guard let real = PhoneNumber("61016") else { return }
            _ = await SpyTextOpener().openText(to: real)
        }
    }

    @Test("The dialler double stops the test when asked to dial a number outside the drama range")
    func diallerTraps() async {
        await #expect(processExitsWith: .failure) {
            guard let real = PhoneNumber("0808 2000 247") else { return }
            _ = await SpyDialler().dial(real)
        }
    }
}
