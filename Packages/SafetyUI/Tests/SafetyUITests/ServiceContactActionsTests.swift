import Foundation
import SafetyDomain
import SafetyTesting
import Testing

@testable import SafetyUI

@MainActor
@Suite("Calling and texting a service")
struct ServiceContactActionsTests {

    private let line = PhoneNumber.drama(5)

    @Test("A call waits for confirmation, capturing the service and number at the tap")
    func requestCapturesTheTap() {
        let actions = ServiceContactActions()
        actions.requestCall(line, serviceName: "Helpline", testMode: false)
        #expect(actions.pendingCall == PendingCall.make(serviceName: "Helpline", number: line, testMode: false))
    }

    @Test("Placing a confirmed call dials exactly that number")
    func placeDials() async throws {
        let actions = ServiceContactActions()
        let dialler = SpyDialler()
        actions.requestCall(line, serviceName: "Helpline", testMode: false)
        let call = try #require(actions.pendingCall)
        await actions.place(call, using: dialler)
        #expect(dialler.dialled == [line])
        #expect(actions.failure == nil)
    }

    @Test("A call the phone cannot start is reported with the number to dial by hand")
    func callFails() async throws {
        let actions = ServiceContactActions()
        actions.requestCall(line, serviceName: "Helpline", testMode: false)
        await actions.place(try #require(actions.pendingCall), using: SpyDialler(succeeds: false))
        #expect(actions.failure == .call(line))
    }

    @Test("In Test Mode a text goes to the stand-in, and a failure names it")
    func textTestMode() async {
        let actions = ServiceContactActions()
        let texter = SpyTextOpener(succeeds: false)
        await actions.text(line, testMode: true, using: texter)
        #expect(texter.opened == [TestModeNumbers.service])
        #expect(actions.failure == .text(TestModeNumbers.service))
    }

    @Test("Outside Test Mode a text goes to the service's own number")
    func textReal() async {
        let actions = ServiceContactActions()
        let texter = SpyTextOpener()
        await actions.text(line, testMode: false, using: texter)
        #expect(texter.opened == [line])
        #expect(actions.failure == nil)
    }
}
