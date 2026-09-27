import CoreLocation
import os
import SafetyDomain
import SafetyServices

/// Never logs a coordinate. Only that something went wrong.
nonisolated private let locationLog = Logger(subsystem: "uk.co.example.safety", category: "location")

/// One location snapshot, When In Use only (ADR-0005).
@MainActor
final class CoreLocationProvider: NSObject, LocationProviding, CLLocationManagerDelegate {

    private let manager = CLLocationManager()
    private var authorizationWaiters: [CheckedContinuation<LocationAuthorization, Never>] = []

    override init() {
        super.init()
        manager.delegate = self
    }

    var authorization: LocationAuthorization {
        Self.map(manager.authorizationStatus, manager.accuracyAuthorization)
    }

    func requestWhenInUseAuthorization() async -> LocationAuthorization {
        // Once answered, iOS never shows the prompt again and sends no callback, so
        // asking again would wait for ever.
        guard manager.authorizationStatus == .notDetermined else { return authorization }
        return await withCheckedContinuation { continuation in
            authorizationWaiters.append(continuation)
            manager.requestWhenInUseAuthorization()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Called on the main thread, where the manager was created. The delegate
        // callback's own `manager` parameter is not Sendable and is deliberately
        // never touched here — `self.manager` is the same instance, and reading it
        // through `self` stays inside this type's isolation instead of sending a
        // non-Sendable value across the boundary.
        MainActor.assumeIsolated {
            guard self.manager.authorizationStatus != .notDetermined else { return }
            let answer = authorization
            let waiting = authorizationWaiters
            authorizationWaiters = []
            waiting.forEach { $0.resume(returning: answer) }
        }
    }

    func currentFix(timeout: Duration) async -> LocationFix? {
        // Never prompts. Starting updates while undetermined can show the system
        // dialog, and this is called from the alert path.
        guard authorization == .authorizedWhenInUse else { return nil }
        return await firstResult(within: timeout) {
            do {
                for try await update in CLLocationUpdate.liveUpdates() {
                    guard let location = update.location else { continue }
                    let fix = LocationFix(
                        coordinate: Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
                        horizontalAccuracy: location.horizontalAccuracy,
                        timestamp: location.timestamp
                    )
                    // The first reading is often cached or coarse. Keep listening until
                    // one is good enough to send, or the timeout ends the wait.
                    if fix.isUsable && fix.isFresh(at: Date()) { return fix }
                }
            } catch {
                // The alert still goes, saying location is unavailable — the person
                // sees that on screen. This line is for diagnosis only.
                locationLog.error("Location updates ended with an error")
            }
            return nil
        }
    }

    private static func map(_ status: CLAuthorizationStatus, _ accuracy: CLAccuracyAuthorization) -> LocationAuthorization {
        switch status {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        case .authorizedWhenInUse, .authorizedAlways:
            accuracy == .reducedAccuracy ? .authorizedReducedAccuracy : .authorizedWhenInUse
        @unknown default:
            // Treated as unusable with no action to offer, rather than as a state the
            // app might wrongly try to prompt from.
            .restricted
        }
    }
}
