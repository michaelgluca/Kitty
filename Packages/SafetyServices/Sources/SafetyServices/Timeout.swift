import Foundation

/// Runs `operation` and returns its result, or `nil` once `timeout` has passed —
/// whichever comes first.
///
/// It does not wait for `operation` to acknowledge cancellation. A task group would:
/// a group cannot return until every child has finished, so a location stream that
/// ignored cancellation would hold the alert hostage. Here the loser is cancelled and
/// abandoned, and the caller carries on. This is what makes "the alert never blocks
/// on location" true however a provider behaves.
public func firstResult<T: Sendable>(
    within timeout: Duration,
    _ operation: @escaping @Sendable () async -> T?
) async -> T? {
    await withCheckedContinuation { continuation in
        let gate = ResumeOnce(continuation)
        let work = Task { gate.resume(await operation()) }
        Task {
            do {
                try await Task.sleep(for: timeout)
            } catch {
                // Only cancellation ends the sleep early, and nothing cancels this
                // task. Resuming regardless keeps the promise: the caller always
                // gets an answer.
            }
            work.cancel()
            gate.resume(nil)
        }
    }
}

/// Resumes a continuation exactly once, whichever side gets there first.
private final class ResumeOnce<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T?, Never>?

    init(_ continuation: CheckedContinuation<T?, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: T?) {
        let pending = lock.withLock { () -> CheckedContinuation<T?, Never>? in
            defer { continuation = nil }
            return continuation
        }
        pending?.resume(returning: value)
    }
}
