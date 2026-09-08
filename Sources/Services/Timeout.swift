import Foundation

/// Runs `work`, giving up after `seconds` and returning nil.
///
/// Deliberately **not** built on `withTaskGroup`. A group awaits all of its
/// children when the scope ends, and cancelling does not interrupt a child
/// blocked inside a synchronous C call — so racing a sleep against a hung
/// Apple Event never actually returned. That is exactly how a single blocked
/// script left `polling` stuck true for the life of the process and the
/// Now Playing widget frozen on its empty state.
///
/// Here the continuation is resumed by whichever side finishes first, so the
/// caller is freed on time. The hung work is abandoned rather than awaited —
/// it strands a thread, which is why every caller must stop polling once this
/// returns nil instead of launching another.
func withTimeout<T: Sendable>(
    seconds: Double,
    work: @escaping @Sendable () async -> T
) async -> T? {
    let once = TimeoutOnce()
    return await withCheckedContinuation { continuation in
        Task.detached {
            let value = await work()
            if once.claim() { continuation.resume(returning: value) }
        }
        Task.detached {
            try? await Task.sleep(for: .seconds(seconds))
            if once.claim() { continuation.resume(returning: nil) }
        }
    }
}

/// Lets exactly one of two racing tasks resume a continuation.
private final class TimeoutOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false

    /// True only for the first caller.
    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if fired { return false }
        fired = true
        return true
    }
}
