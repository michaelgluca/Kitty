import Foundation
import SafetyDomain
import SafetyServices
import SafetyTesting
import Testing

@testable import SafetyUI

private let now = Date(timeIntervalSince1970: 1_758_900_000)

private func london(age: TimeInterval = 5) -> LocationFix {
    LocationFix(
        coordinate: Coordinate(latitude: 51.50853, longitude: -0.12574),
        horizontalAccuracy: 12,
        timestamp: now.addingTimeInterval(-age)
    )
}

/// A message composer that never answers until released. Proves the busy guard
/// holds while `.composing`, not just while `.locating`. Same shape as
/// `HangingLocationProvider`: a lock, stored continuations, and a `release`.
private final class HangingMessageComposer: MessageComposing, @unchecked Sendable {
    private let lock = NSLock()
    private var released: MessageOutcome?
    private var waiters: [CheckedContinuation<MessageOutcome, Never>] = []
    private var _composedCount = 0

    let canSendText: Bool

    init(canSendText: Bool = true) {
        self.canSendText = canSendText
    }

    var composedCount: Int { lock.withLock { _composedCount } }

    @MainActor
    func compose(recipients: [PhoneNumber], body: String) async -> MessageOutcome {
        // A double that could reach a real person would defeat the point.
        precondition(
            recipients.allSatisfy(\.isReservedForDrama),
            "HangingMessageComposer was given a number outside Ofcom's reserved drama range: \(recipients.map(\.dialable))"
        )
        lock.withLock { _composedCount += 1 }
        return await withCheckedContinuation { continuation in
            let answerNow = lock.withLock { () -> MessageOutcome? in
                if let released { return released }
                waiters.append(continuation)
                return nil
            }
            if let answerNow { continuation.resume(returning: answerNow) }
        }
    }

    /// Lets every waiting caller finish, so a test leaves nothing hanging.
    func release(with outcome: MessageOutcome = .sent) {
        let pending = lock.withLock { () -> [CheckedContinuation<MessageOutcome, Never>] in
            released = outcome
            defer { waiters = [] }
            return waiters
        }
        pending.forEach { $0.resume(returning: outcome) }
    }
}

@MainActor
@Suite("Alert model")
struct AlertModelTests {

    private func services(
        location: any LocationProviding = StubLocationProvider(fix: london()),
        messages: any MessageComposing = SpyMessageComposer()
    ) -> Services {
        var services = Services.unavailable
        services.location = location
        services.messages = messages
        services.battery = FixedBattery(fraction: 0.5)
        services.time = FixedTime(now: now)
        return services
    }

    private func model(_ services: Services, timeout: Duration = .milliseconds(300)) -> AlertModel {
        AlertModel(services: services, strings: Strings.alert, locale: Locale(identifier: "en_GB"), locationTimeout: timeout)
    }

    @Test("No contacts routes to setup and composes nothing")
    func noContacts() async {
        let spy = SpyMessageComposer()
        let m = model(services(messages: spy))
        await m.raise(contacts: [], contactsReadable: true, testMode: false)
        #expect(m.phase == .finished(.needsContacts))
        #expect(spy.composed.isEmpty)
    }

    @Test("Unreadable contacts are reported, never treated as having none")
    func unreadable() async {
        let spy = SpyMessageComposer()
        let m = model(services(messages: spy))
        await m.raise(contacts: [], contactsReadable: false, testMode: false)
        #expect(m.phase == .finished(.contactsUnreadable))
        #expect(spy.composed.isEmpty)
    }

    @Test("A phone that cannot text is told at once, and offered calls, without waiting for a location")
    func cannotText() async {
        let location = StubLocationProvider(fix: london())
        let m = model(services(location: location, messages: SpyMessageComposer(canSendText: false)))
        await m.raise(contacts: SafeTestNumbers.contacts, contactsReadable: true, testMode: false)
        #expect(m.phase == .finished(.cannotText))
        #expect(m.recipients.map(\.number) == [SafeTestNumbers.alice, SafeTestNumbers.bob])
        #expect(location.fixRequestCount == 0)
    }

    @Test("Sends one message to every contact, with where they are")
    func sendsWithLocation() async throws {
        let spy = SpyMessageComposer()
        let m = model(services(messages: spy))
        await m.raise(contacts: SafeTestNumbers.contacts, contactsReadable: true, testMode: false)

        let composed = try #require(spy.composed.first)
        #expect(spy.composed.count == 1)
        #expect(composed.recipients == [SafeTestNumbers.alice, SafeTestNumbers.bob])
        #expect(composed.body.contains("maps.apple.com"))
        #expect(m.phase == .finished(.handedToMessages(includedLocation: true)))
    }

    @Test("Never asks for location permission from the alert, and sends without it", arguments: [
        LocationAuthorization.notDetermined, .denied, .restricted, .authorizedReducedAccuracy,
    ])
    func neverPrompts(authorization: LocationAuthorization) async throws {
        let location = StubLocationProvider(authorization: authorization, authorizationAfterRequest: .authorizedWhenInUse, fix: london())
        let spy = SpyMessageComposer()
        let m = model(services(location: location, messages: spy))
        await m.raise(contacts: SafeTestNumbers.contacts, contactsReadable: true, testMode: false)

        #expect(location.authorizationRequestCount == 0)
        #expect(location.fixRequestCount == 0)
        let composed = try #require(spy.composed.first)
        #expect(composed.body.contains("My location is not available."))
        #expect(m.phase == .finished(.handedToMessages(includedLocation: false)))
    }

    @Test("A provider that never answers does not hold the alert")
    func hungProvider() async throws {
        let hanging = HangingLocationProvider()
        defer { hanging.release() }
        let spy = SpyMessageComposer()
        let m = model(services(location: hanging, messages: spy), timeout: .milliseconds(200))

        let clock = ContinuousClock()
        let start = clock.now
        await m.raise(contacts: SafeTestNumbers.contacts, contactsReadable: true, testMode: false)
        #expect(clock.now - start < .seconds(3))

        let composed = try #require(spy.composed.first)
        #expect(composed.body.contains("My location is not available."))
        #expect(m.phase == .finished(.handedToMessages(includedLocation: false)))
    }

    @Test("A stale cached fix is not sent as where they are now")
    func staleFix() async throws {
        let spy = SpyMessageComposer()
        let m = model(services(location: StubLocationProvider(fix: london(age: 600)), messages: spy))
        await m.raise(contacts: SafeTestNumbers.contacts, contactsReadable: true, testMode: false)
        let composed = try #require(spy.composed.first)
        #expect(!composed.body.contains("maps.apple.com"))
        #expect(composed.body.contains("My location is not available."))
        #expect(m.phase == .finished(.handedToMessages(includedLocation: false)))
    }

    @Test("Reports exactly what the person did in Messages", arguments: [
        (MessageOutcome.cancelled, AlertModel.Outcome.cancelled),
        (MessageOutcome.failed, AlertModel.Outcome.failed),
        (MessageOutcome.unavailable, AlertModel.Outcome.cannotText),
    ])
    func outcomes(messages: MessageOutcome, expected: AlertModel.Outcome) async {
        let m = model(services(messages: SpyMessageComposer(outcome: messages)))
        await m.raise(contacts: SafeTestNumbers.contacts, contactsReadable: true, testMode: false)
        #expect(m.phase == .finished(expected))
    }

    @Test("In Test Mode no real number is ever composed, and the message says TEST first")
    func testModeNeverReachesARealNumber() async throws {
        // These are not recognised as drama numbers, so SpyMessageComposer would stop
        // the test outright if one reached it. Test Mode must replace them.
        let realLooking = [
            TrustedContact(displayName: "Alice", phoneNumber: try #require(PhoneNumber("020 7946 0018"))),
            TrustedContact(displayName: "Bob", phoneNumber: try #require(PhoneNumber("0113 496 0001"))),
        ]
        let spy = SpyMessageComposer()
        let m = model(services(messages: spy))
        await m.raise(contacts: realLooking, contactsReadable: true, testMode: true)

        let composed = try #require(spy.composed.first)
        #expect(composed.recipients == [TestModeNumbers.contact(at: 0), TestModeNumbers.contact(at: 1)])
        #expect(composed.body.components(separatedBy: "\n").first == Strings.alert.testNotice)
        #expect(m.recipients.map(\.name) == ["Alice", "Bob"])
        #expect(m.recipients.map(\.number) == [TestModeNumbers.contact(at: 0), TestModeNumbers.contact(at: 1)])
    }

    @Test("A second tap while the first is still working does nothing")
    func doubleTap() async throws {
        let hanging = HangingLocationProvider()
        let spy = SpyMessageComposer()
        let m = model(services(location: hanging, messages: spy), timeout: .seconds(5))

        let first = Task { await m.raise(contacts: SafeTestNumbers.contacts, contactsReadable: true, testMode: false) }
        for _ in 0..<10_000 where m.phase != .locating { await Task.yield() }
        try #require(m.phase == .locating)
        #expect(m.isBusy)

        await m.raise(contacts: SafeTestNumbers.contacts, contactsReadable: true, testMode: false)
        m.reset()
        #expect(m.phase == .locating)

        hanging.release()
        await first.value
        #expect(spy.composed.count == 1)

        m.reset()
        #expect(m.phase == .idle)
    }

    @Test("The busy guard also holds while a compose sheet is up, not only while locating")
    func doubleTapWhileComposing() async throws {
        let composer = HangingMessageComposer()
        defer { composer.release() }
        let m = model(services(messages: composer))

        let first = Task { await m.raise(contacts: SafeTestNumbers.contacts, contactsReadable: true, testMode: false) }
        for _ in 0..<10_000 where m.phase != .composing { await Task.yield() }
        try #require(m.phase == .composing)
        #expect(m.isBusy)

        await m.raise(contacts: SafeTestNumbers.contacts, contactsReadable: true, testMode: false)

        composer.release(with: .sent)
        await first.value
        #expect(composer.composedCount == 1)
        #expect(m.phase == .finished(.handedToMessages(includedLocation: true)))
    }

    @Test("Defaults to a three-second location timeout")
    func defaultTimeout() {
        #expect(AlertModel.defaultLocationTimeout == .seconds(3))
    }
}
