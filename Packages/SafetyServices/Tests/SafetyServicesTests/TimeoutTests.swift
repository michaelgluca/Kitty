import Foundation
import Testing

@testable import SafetyServices

/// An operation that ignores cancellation and does not finish until opened — the
/// worst-behaved location provider imaginable.
private final class Gate: @unchecked Sendable {
    private let lock = NSLock()
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        await withCheckedContinuation { continuation in
            let resumeNow = lock.withLock { () -> Bool in
                if isOpen { return true }
                waiters.append(continuation)
                return false
            }
            if resumeNow { continuation.resume() }
        }
    }

    func open() {
        let pending = lock.withLock { () -> [CheckedContinuation<Void, Never>] in
            isOpen = true
            defer { waiters = [] }
            return waiters
        }
        pending.forEach { $0.resume() }
    }
}

private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func set() { lock.withLock { value = true } }
    var isSet: Bool { lock.withLock { value } }
}

@Suite("First result within a timeout")
struct TimeoutTests {

    @Test("Returns the value when the operation answers in time")
    func answersInTime() async {
        let result: Int? = await firstResult(within: .seconds(5)) { 42 }
        #expect(result == 42)
    }

    @Test("Returns nil when the operation answers nil")
    func answersNil() async {
        let result: Int? = await firstResult(within: .seconds(5)) { nil }
        #expect(result == nil)
    }

    @Test("Gives up on time even when the operation ignores cancellation")
    func abandonsAHungOperation() async {
        let gate = Gate()
        let clock = ContinuousClock()
        let start = clock.now
        let result: Int? = await firstResult(within: .milliseconds(100)) {
            await gate.wait()
            return 1
        }
        #expect(result == nil)
        // Generous, because CI machines are slow. A hang would be forever.
        #expect(clock.now - start < .seconds(3))
        gate.open()
    }

    @Test("Cancels the abandoned operation, so one that listens can stop early")
    func cancelsTheLoser() async throws {
        let cancelled = Flag()
        let _: Int? = await firstResult(within: .milliseconds(50)) {
            do {
                try await Task.sleep(for: .seconds(30))
            } catch {
                cancelled.set()
            }
            return nil
        }
        for _ in 0..<100 where !cancelled.isSet {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(cancelled.isSet)
    }
}
