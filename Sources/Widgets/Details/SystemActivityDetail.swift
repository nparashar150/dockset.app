import Foundation
import SwiftUI

/// System Activity said at length: the tile's gauges at a size that can hold a
/// number, and under them the figures a 42pt ring has no room for.
///
/// Which metrics appear is the widget's own `metrics` config — a click cycles
/// that list on the tile, so the panel has to follow it rather than assume the
/// CPU-and-memory default it happens to ship with.
struct SystemActivityDetail: View {
    var instance: WidgetInstance
    var context: WidgetContext

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: Self.gaugeGap) {
                ForEach(metrics, id: \.self) { gauge($0) }
            }
            .frame(maxWidth: .infinity)

            Divider()

            VStack(spacing: 7) {
                ForEach(metrics, id: \.self) { row($0) }
            }
        }
    }

    // MARK: Gauges

    private static let gaugeGap: CGFloat = 12

    /// The panel is a fixed width, so the gauges are sized from it rather than
    /// measured: 110pt is the pair the reference draws, and a third or fourth
    /// configured metric gives width back instead of running off the edge.
    private var diameter: CGFloat {
        // The chrome pads 18pt on each side of whatever it is handed.
        let content = WidgetDetail.width(instance.kind) - 36
        let count = CGFloat(metrics.count)
        return min(110, (content - Self.gaugeGap * (count - 1)) / count)
    }

    private func gauge(_ metric: Metric) -> some View {
        VStack(spacing: 8) {
            MetricProgressRing(progress: value(metric),
                               tint: metric.color,
                               track: metric.color.opacity(0.16),
                               diameter: diameter,
                               lineWidth: diameter * 0.12) {
                percent(value(metric), size: diameter * 0.26)
            }
            // The tile's ring carries a symbol because a 42pt card has nowhere
            // to put a caption. At this size the reading goes back inside and
            // the name underneath, with the arc's colour tying the two.
            Text(metric.label)
                .font(WidgetStyle.caption(12))
                .foregroundStyle(WidgetStyle.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(metric.label)
        .accessibilityValue("\(whole(value(metric))) percent")
    }

    @ViewBuilder
    private func percent(_ value: Double, size: CGFloat) -> some View {
        let reading = whole(value)
        HStack(spacing: 0) {
            Text("\(reading)")
                .font(.system(size: size, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(WidgetStyle.primary)
                .rollingValue(reading)
            // Smaller than the figure, so a three-digit reading still clears
            // the arc it sits inside.
            Text("%")
                .font(.system(size: size * 0.62, weight: .bold))
                .foregroundStyle(WidgetStyle.secondary)
        }
    }

    // MARK: Detail

    private func row(_ metric: Metric) -> some View {
        let line = detail(metric)
        return HStack(spacing: 12) {
            Text(line.label)
                .font(WidgetStyle.caption(12))
                .foregroundStyle(WidgetStyle.secondary)
            Spacer(minLength: 0)
            Text(line.value)
                .font(WidgetStyle.label(12))
                .monospacedDigit()
                .foregroundStyle(WidgetStyle.primary)
                .rollingValue(line.value)
        }
        .lineLimit(1)
    }

    /// The one fact each gauge leaves out.
    ///
    /// The sampler publishes fractions, so memory is the only one that can be
    /// restated in bytes — its fraction is measured against
    /// `physicalMemory`, which makes the multiplication the reading itself
    /// rather than a guess. The others say what they are a fraction *of*, or
    /// what the number cannot show, instead of inventing an absolute figure.
    private func detail(_ metric: Metric) -> (label: String, value: String) {
        switch metric {
        case .cpu:
            // The ring is this second; the average is the minute behind it,
            // off the same series the tile's sparkline draws. Named with the
            // span it actually has, which is shorter than a minute until the
            // history fills.
            let series = context.isPreview ? [] : SystemMetrics.shared.cpuHistory
            guard !series.isEmpty else { return ("Average CPU", "—") }
            let average = series.reduce(0, +) / Double(series.count)
            return ("Average CPU, last \(series.count)s", "\(whole(average))%")
        case .memory:
            let total = Double(ProcessInfo.processInfo.physicalMemory)
            let gib = 1024.0 * 1024 * 1024
            return ("Memory used",
                    String(format: "%.1f / %.0f GiB", value(metric) * total / gib, total / gib))
        case .disk:
            // Only the fraction is published, and it is the root volume's.
            return ("Startup volume used", "\(whole(value(metric)))%")
        case .battery:
            let mac = context.isPreview ? nil : BatteryMetrics.shared.device(.mac)
            guard let mac, mac.present else { return ("Mac battery", "Not reported") }
            return ("Mac battery", mac.charging ? "Charging" : "On battery")
        }
    }

    // MARK: Data

    /// The tile's key and the tile's fallback, so the panel cannot disagree
    /// with the card that opened it.
    private var metrics: [Metric] {
        let parsed = instance.config
            .strings("metrics", default: ["cpu", "memory"])
            .compactMap(Metric.init(rawValue:))
        return parsed.isEmpty ? [.cpu, .memory] : parsed
    }

    private func value(_ metric: Metric) -> Double {
        if context.isPreview { return metric.sample }
        switch metric {
        case .cpu, .memory, .disk:
            return SystemMetrics.shared.value(for: metric.rawValue)
        // The Mac's own battery: the other devices belong to the battery
        // widget, which is the one that can show more than one of them.
        case .battery:
            return BatteryMetrics.shared.device(.mac)?.level ?? 0
        }
    }

    private func whole(_ value: Double) -> Int {
        Int((min(max(value, 0), 1) * 100).rounded())
    }

    /// The tile's metric list, which is nested and private to it. Same raw
    /// values because both sides read the same config key — a metric added
    /// there has to be added here too, or the panel drops it silently.
    private enum Metric: String {
        case cpu, memory, disk, battery

        var label: String {
            switch self {
            case .cpu: "CPU"
            case .memory: "Memory"
            case .disk: "Disk"
            case .battery: "Battery"
            }
        }

        var color: Color {
            switch self {
            case .cpu: Color(hex: MetricColor.cpu)
            case .memory: Color(hex: MetricColor.memory)
            case .disk: Color(hex: MetricColor.storage)
            case .battery: Color(hex: MetricColor.batteryPresent)
            }
        }

        /// The library has no sampler behind it.
        var sample: Double {
            switch self {
            case .cpu: 0.24
            case .memory: 0.63
            case .disk: 0.41
            case .battery: 0.78
            }
        }
    }
}
