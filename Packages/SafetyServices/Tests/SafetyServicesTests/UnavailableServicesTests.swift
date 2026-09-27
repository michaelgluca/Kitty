import Foundation
import SafetyDomain
import Testing

@testable import SafetyServices

@MainActor
@Suite("Unavailable services")
struct UnavailableServicesTests {

    @Test("Every default reports failure rather than pretending to work")
    func defaultsFailVisibly() async {
        let services = Services.unavailable
        #expect(await services.picker.pickContact() == .unavailable)
        #expect(await services.settings.openAppSettings() == false)
        #expect(services.messages.canSendText == false)
        #expect(await services.messages.compose(recipients: [], body: "x") == .unavailable)
        #expect(services.location.authorization == .notDetermined)
        #expect(await services.location.currentFix(timeout: .zero) == nil)
    }
}
