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
        let somewhere = Coordinate(latitude: 51.5, longitude: -0.12)
        let place = NearbyPlace(id: "p", name: nil, coordinate: somewhere, phone: nil)
        #expect(await services.places.policeStations(near: somewhere, radiusMetres: 1_000) == .failed)
        #expect(await services.routes.walkingRoute(from: somewhere, to: place) == .failed)
        #expect(await services.maps.openWalkingDirections(to: place) == false)
        #expect(await services.areas.area(at: somewhere) == nil)
        #expect(throws: NationStoreFailure.unavailable) { try services.nations.load() }
        #expect(throws: NationStoreFailure.unavailable) { try services.nations.save("scotland") }
    }
}
