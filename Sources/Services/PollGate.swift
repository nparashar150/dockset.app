import Foundation

/// Whether a periodic probe may start.
///
/// Pure, and shared, because getting this wrong is invisible and fatal.
/// `MusicService` armed its in-flight flag *above* its early returns, so the
/// first throttled tick leaked the flag and the service never polled again for
/// the life of the process - the widget froze one second after launch.
/// `BrowserMedia` had the same conditions in the correct order, which is why
/// only one of them broke.
///
/// Expressing the decision as a value means the flag can only be armed on the
/// path that actually proceeds.
enum PollGate {
    static func shouldStart(inFlight: Bool,
                            blocked: Bool,
                            sinceLastStart: TimeInterval,
                            interval: TimeInterval) -> Bool {
        !inFlight && !blocked && sinceLastStart >= interval
    }
}
