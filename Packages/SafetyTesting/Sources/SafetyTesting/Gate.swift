import Foundation

/// An answer a test holds back. Every `wait()` suspends until the test calls
/// `open(with:)`, and answers at once after that.
///
/// The building block of every double that stands for a service that never answers:
/// the model under test must not trust the service to return, so the double must be
/// able to stay silent for as long as the test needs, and then let every waiting
/// caller finish so nothing is left suspended.
public final class Gate<Value: Sendable>: @unchecked Sendable {

    private enum State {
        case closed(waiting: [CheckedContinuation<Value, Never>])
        case open(Value)
    }

    private let lock = NSLock()
    private var state = State.closed(waiting: [])

    public init() {}

    /// The answer, once the gate is open.
    public func wait() async -> Value {
        await withCheckedContinuation { continuation in
            lock.withLock {
                switch state {
                case let .closed(waiting): state = .closed(waiting: waiting + [continuation])
                case let .open(value): continuation.resume(returning: value)
                }
            }
        }
    }

    /// Answers every waiting caller with `value`, and every later one too.
    public func open(with value: Value) {
        lock.withLock {
            if case let .closed(waiting) = state {
                waiting.forEach { $0.resume(returning: value) }
            }
            state = .open(value)
        }
    }
}
