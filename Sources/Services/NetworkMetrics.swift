import Foundation
import Observation

/// Throughput across every non-loopback interface, in bytes per second.
///
/// The kernel only hands out cumulative byte counters, so the rate is a delta
/// between samples divided by the real elapsed time - the timer can fire late,
/// and dividing by a nominal 1s would over-report after a sleep.
@MainActor @Observable
final class NetworkMetrics {
    static let shared = NetworkMetrics()

    /// How many samples the sparkline widgets can draw.
    static let historyLength = 60

    private(set) var download: Double = 0
    private(set) var upload: Double = 0
    /// Most recent last, at most `historyLength` entries.
    private(set) var downloadHistory: [Double] = []
    private(set) var uploadHistory: [Double] = []

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var previous: (rx: UInt64, tx: UInt64, at: TimeInterval)?

    private init() {}

    func start() {
        guard timer == nil else { return }
        sample()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        // Next start() re-baselines instead of charging the whole idle gap
        // to a single sample.
        previous = nil
    }

    private func sample() {
        guard let totals = Self.interfaceTotals() else { return }
        // systemUptime, not Date: a clock adjustment must not invent traffic.
        let at = ProcessInfo.processInfo.systemUptime
        defer { previous = (totals.rx, totals.tx, at) }

        guard let last = previous else { return }  // first sample is only a baseline
        let elapsed = at - last.at
        guard elapsed > 0 else { return }

        // Counters are 32-bit and wrap, and an interface coming back up resets
        // them; a negative delta is a reset, not 4GB of traffic in one second.
        download = Double(totals.rx >= last.rx ? totals.rx - last.rx : 0) / elapsed
        upload = Double(totals.tx >= last.tx ? totals.tx - last.tx : 0) / elapsed
        record(download, into: &downloadHistory)
        record(upload, into: &uploadHistory)
    }

    private func record(_ value: Double, into history: inout [Double]) {
        history.append(value)
        if history.count > Self.historyLength {
            history.removeFirst(history.count - Self.historyLength)
        }
    }

    /// Cumulative bytes in/out summed over every non-loopback link.
    private static func interfaceTotals() -> (rx: UInt64, tx: UInt64)? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }

        var rx: UInt64 = 0
        var tx: UInt64 = 0
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(entry.pointee.ifa_flags)
            guard flags & IFF_LOOPBACK == 0, flags & IFF_UP != 0 else { continue }
            // Byte counters live on the link-layer entry, not the IP ones -
            // counting every address family would multiply the same traffic.
            guard let address = entry.pointee.ifa_addr, address.pointee.sa_family == UInt8(AF_LINK),
                  let data = entry.pointee.ifa_data?.assumingMemoryBound(to: if_data.self)
            else { continue }
            rx += UInt64(data.pointee.ifi_ibytes)
            tx += UInt64(data.pointee.ifi_obytes)
        }
        return (rx, tx)
    }
}
