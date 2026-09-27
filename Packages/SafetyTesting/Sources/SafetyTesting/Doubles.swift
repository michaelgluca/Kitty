import Foundation
import SafetyDomain
import SafetyServices

/// Numbers from Ofcom's reserved drama range, which cannot reach a real subscriber.
/// Every fixture and every Test Mode path uses these, so no test can ever text or
/// call a person.
public enum SafeTestNumbers {
    public static let alice = PhoneNumber("+447700900001")!
    public static let bob = PhoneNumber("+447700900002")!

    public static var contacts: [TrustedContact] {
        [
            TrustedContact(displayName: "Alice (test)", phoneNumber: alice),
            TrustedContact(displayName: "Bob (test)", phoneNumber: bob),
        ]
    }
}

public final class StubLocationProvider: LocationProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var _authorization: LocationAuthorization
    private let authorizationAfterRequest: LocationAuthorization?
    private let fix: LocationFix?
    private let delay: Duration
    private var _fixRequestCount = 0
    private var _authorizationRequestCount = 0

    /// - Parameter authorizationAfterRequest: what the person answers if asked while
    ///   the state is `.notDetermined`. `nil` leaves the state unchanged.
    public init(
        authorization: LocationAuthorization = .authorizedWhenInUse,
        authorizationAfterRequest: LocationAuthorization? = nil,
        fix: LocationFix? = nil,
        delay: Duration = .zero
    ) {
        self._authorization = authorization
        self.authorizationAfterRequest = authorizationAfterRequest
        self.fix = fix
        self.delay = delay
    }

    public var fixRequestCount: Int { lock.withLock { _fixRequestCount } }
    /// How many times a permission prompt would have been shown.
    public var authorizationRequestCount: Int { lock.withLock { _authorizationRequestCount } }

    @MainActor public var authorization: LocationAuthorization { lock.withLock { _authorization } }

    @MainActor
    public func requestWhenInUseAuthorization() async -> LocationAuthorization {
        lock.withLock {
            _authorizationRequestCount += 1
            if _authorization == .notDetermined, let answer = authorizationAfterRequest {
                _authorization = answer
            }
            return _authorization
        }
    }

    @MainActor
    public func currentFix(timeout: Duration) async -> LocationFix? {
        lock.withLock { _fixRequestCount += 1 }
        if delay > .zero {
            // Models a slow fix that honours its timeout.
            if delay > timeout { return nil }
            try? await Task.sleep(for: delay)
        }
        return fix
    }
}

/// A location provider that ignores its own timeout and never answers until
/// released. Proves callers do not trust a provider to keep its promise.
public final class HangingLocationProvider: LocationProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var released = false
    private var waiters: [CheckedContinuation<LocationFix?, Never>] = []

    public init() {}

    @MainActor public var authorization: LocationAuthorization { .authorizedWhenInUse }
    @MainActor public func requestWhenInUseAuthorization() async -> LocationAuthorization { .authorizedWhenInUse }

    @MainActor
    public func currentFix(timeout: Duration) async -> LocationFix? {
        await withCheckedContinuation { continuation in
            let answerNow = lock.withLock { () -> Bool in
                if released { return true }
                waiters.append(continuation)
                return false
            }
            if answerNow { continuation.resume(returning: nil) }
        }
    }

    /// Lets every waiting caller finish, so a test leaves nothing hanging.
    public func release() {
        let pending = lock.withLock { () -> [CheckedContinuation<LocationFix?, Never>] in
            released = true
            defer { waiters = [] }
            return waiters
        }
        pending.forEach { $0.resume(returning: nil) }
    }
}

public final class SpyMessageComposer: MessageComposing, @unchecked Sendable {
    public struct Composed: Sendable, Equatable {
        public let recipients: [PhoneNumber]
        public let body: String
    }

    private let lock = NSLock()
    private var _composed: [Composed] = []
    private let outcome: MessageOutcome

    public let canSendText: Bool

    public init(outcome: MessageOutcome = .sent, canSendText: Bool = true) {
        self.outcome = outcome
        self.canSendText = canSendText
    }

    public var composed: [Composed] { lock.withLock { _composed } }

    @MainActor
    public func compose(recipients: [PhoneNumber], body: String) async -> MessageOutcome {
        // A double that could reach a real person would defeat the point.
        precondition(
            recipients.allSatisfy(\.isReservedForDrama),
            "SpyMessageComposer was given a number outside Ofcom's reserved drama range: \(recipients.map(\.dialable))"
        )
        lock.withLock { _composed.append(Composed(recipients: recipients, body: body)) }
        return outcome
    }
}

public final class SpyDialler: Dialling, @unchecked Sendable {
    private let lock = NSLock()
    private var _dialled: [PhoneNumber] = []
    private let succeeds: Bool

    public init(succeeds: Bool = true) { self.succeeds = succeeds }

    public var dialled: [PhoneNumber] { lock.withLock { _dialled } }

    @MainActor
    public func dial(_ number: PhoneNumber) async -> Bool {
        precondition(
            number.isReservedForDrama,
            "SpyDialler was asked to dial \(number.dialable), which is not in the reserved drama range."
        )
        lock.withLock { _dialled.append(number) }
        return succeeds
    }
}

public final class SpyTextOpener: TextOpening, @unchecked Sendable {
    private let lock = NSLock()
    private var _opened: [PhoneNumber] = []
    private let succeeds: Bool

    public init(succeeds: Bool = true) { self.succeeds = succeeds }

    public var opened: [PhoneNumber] { lock.withLock { _opened } }

    @MainActor
    public func openText(to number: PhoneNumber) async -> Bool {
        lock.withLock { _opened.append(number) }
        return succeeds
    }
}

public final class InMemoryContactStore: TrustedContactStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var contacts: [TrustedContact]
    private var _saveCount = 0
    private let loadFailure: (any Error)?
    private let saveFailure: (any Error)?

    public init(contacts: [TrustedContact] = [], loadFailure: (any Error)? = nil, saveFailure: (any Error)? = nil) {
        self.contacts = contacts
        self.loadFailure = loadFailure
        self.saveFailure = saveFailure
    }

    /// What is stored now.
    public var saved: [TrustedContact] { lock.withLock { contacts } }
    /// Every call to `save`, whether or not it succeeded.
    public var saveCount: Int { lock.withLock { _saveCount } }

    public func load() throws -> [TrustedContact] {
        if let loadFailure { throw loadFailure }
        return lock.withLock { contacts }
    }

    public func save(_ contacts: [TrustedContact]) throws {
        lock.withLock { _saveCount += 1 }
        if let saveFailure { throw saveFailure }
        lock.withLock { self.contacts = contacts }
    }
}

/// Hands back scripted picker results in order, then `.cancelled`.
public final class StubContactPicker: ContactPicking, @unchecked Sendable {
    private let lock = NSLock()
    private var outcomes: [ContactPickOutcome]
    private var _presentedCount = 0

    public init(_ outcomes: [ContactPickOutcome] = []) {
        self.outcomes = outcomes
    }

    public var presentedCount: Int { lock.withLock { _presentedCount } }

    @MainActor
    public func pickContact() async -> ContactPickOutcome {
        lock.withLock {
            _presentedCount += 1
            return outcomes.isEmpty ? .cancelled : outcomes.removeFirst()
        }
    }
}

public final class SpySettingsOpener: SettingsOpening, @unchecked Sendable {
    private let lock = NSLock()
    private var _openCount = 0
    private let succeeds: Bool

    public init(succeeds: Bool = true) { self.succeeds = succeeds }

    public var openCount: Int { lock.withLock { _openCount } }

    @MainActor
    public func openAppSettings() async -> Bool {
        lock.withLock { _openCount += 1 }
        return succeeds
    }
}

public struct FixedBattery: BatteryReading {
    public let fraction: Double?
    public init(fraction: Double?) { self.fraction = fraction }
}

public struct FixedTime: TimeSource {
    public let now: Date
    public let timeZone: TimeZone
    public init(now: Date, timeZone: TimeZone = TimeZone(identifier: "Europe/London")!) {
        self.now = now
        self.timeZone = timeZone
    }
}
