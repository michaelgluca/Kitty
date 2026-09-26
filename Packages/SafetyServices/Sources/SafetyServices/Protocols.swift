import Foundation
import SafetyDomain

// MARK: - Location

public enum LocationAuthorization: Sendable, Equatable {
    case notDetermined
    case denied
    case restricted
    case authorizedWhenInUse
    /// Precise Location is off. Readings are around 5 km, which cannot support
    /// "here is where I am", so this is surfaced rather than quietly used.
    case authorizedReducedAccuracy
}

public protocol LocationProviding: Sendable {
    var authorization: LocationAuthorization { get async }
    func requestWhenInUseAuthorization() async -> LocationAuthorization

    /// A single fix, or `nil` if none arrives within `timeout`.
    ///
    /// Returning `nil` rather than throwing is deliberate: the caller must carry on
    /// and send the alert without a location. Raising an alert is never blocked on
    /// location, and never fails because of it.
    func currentFix(timeout: Duration) async -> LocationFix?
}

// MARK: - Messaging

public enum MessageOutcome: Sendable, Equatable {
    case sent
    case cancelled
    case failed
    /// The device cannot send texts at all — no SIM, or a restriction. The caller
    /// must offer another route rather than leaving the user with a dead button.
    case unavailable
}

public protocol MessageComposing: Sendable {
    var canSendText: Bool { get }

    /// Presents the system composer, pre-filled. iOS never sends without the user
    /// tapping Send, and never will — see ADR-0002. The returned outcome says what
    /// the user actually did, which is what lets the UI avoid claiming success.
    @MainActor
    func compose(recipients: [PhoneNumber], body: String) async -> MessageOutcome
}

// MARK: - Calling

public protocol Dialling: Sendable {
    /// Opens the system dialler. Always `tel:`, never `telprompt:`, so the system
    /// confirmation is shown. Returns whether the dialler actually opened.
    @MainActor
    func dial(_ number: PhoneNumber) async -> Bool
}

// MARK: - Storage

public protocol TrustedContactStoring: Sendable {
    func load() throws -> [TrustedContact]
    func save(_ contacts: [TrustedContact]) throws
}

// MARK: - Device

public protocol BatteryReading: Sendable {
    /// 0…1, or `nil` when unknown (the simulator reports no level).
    var fraction: Double? { get }
}

public protocol TimeSource: Sendable {
    var now: Date { get }
    var timeZone: TimeZone { get }
}

public struct SystemTimeSource: TimeSource {
    public init() {}
    public var now: Date { Date() }
    public var timeZone: TimeZone { TimeZone.autoupdatingCurrent }
}
