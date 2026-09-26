import Foundation
import SafetyDomain
import SafetyServices

// Real CoreLocation and MessageUI implementations land in M3 and M4. Until then the
// app wires in implementations that report their own unavailability rather than
// silently doing nothing.
//
// This is the "never fail silently" rule applied to unfinished work: a stub that
// returns success would let a broken flow look healthy, which is precisely how the
// 2023 build shipped a Face ID gate that never locked and a map that always routed
// from Trafalgar Square.

struct UnavailableLocationProvider: LocationProviding {
    var authorization: LocationAuthorization { get async { .notDetermined } }
    func requestWhenInUseAuthorization() async -> LocationAuthorization { .notDetermined }
    func currentFix(timeout: Duration) async -> LocationFix? { nil }
}

struct UnavailableMessageComposer: MessageComposing {
    var canSendText: Bool { false }
    @MainActor
    func compose(recipients: [PhoneNumber], body: String) async -> MessageOutcome { .unavailable }
}

struct UnavailableDialler: Dialling {
    @MainActor
    func dial(_ number: PhoneNumber) async -> Bool { false }
}
