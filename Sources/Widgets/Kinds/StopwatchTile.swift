import SwiftUI

/// Elapsed time plus a one-word state.
///
/// Already a stack, so the 76pt column is the same thing in smaller type.
///
/// Click to start or stop, double-click to reset. The state is `started` and
/// `elapsed` in the widget's own config, so it survives a relaunch and follows
/// the widget between profiles.
struct StopwatchTile: View {
    var instance: WidgetInstance
    var context: WidgetContext

    var body: some View {
        let state = state
        let vertical = context.position.isVertical
        WidgetSurface {
            VStack(spacing: 2) {
                Text(Self.format(state.elapsed))
                    .font(WidgetStyle.value(vertical ? 17 : 21))
                    .foregroundStyle(WidgetStyle.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(vertical ? 0.5 : 0.55)
                Text(state.caption)
                    .font(WidgetStyle.caption(vertical ? 9 : 12))
                    .foregroundStyle(WidgetStyle.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(vertical ? 0.7 : 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            .onTapGesture(count: 2) { reset() }
            .onTapGesture { toggle() }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(state.caption == "Running" ? "Stop stopwatch" : "Start stopwatch")
        }
    }

    /// Banks what has run so far when stopping, so restarting continues rather
    /// than beginning again.
    private func toggle() {
        guard !context.isPreview else { return }
        let started = instance.config.double("started")
        let banked = instance.config.double("elapsed")
        WidgetWriter.write(instance) { config in
            if started > 0 {
                config.set("elapsed", .number(banked + max(0, Date.now.timeIntervalSince1970 - started)))
                config.set("started", .number(0))
            } else {
                config.set("started", .number(Date.now.timeIntervalSince1970))
            }
        }
    }

    private func reset() {
        guard !context.isPreview else { return }
        WidgetWriter.write(instance) { config in
            config.set("started", .number(0))
            config.set("elapsed", .number(0))
        }
    }

    private var state: (elapsed: TimeInterval, caption: String) {
        let started = instance.config.double("started")
        let banked = instance.config.double("elapsed")
        if started > 0 {
            return (banked + max(0, context.now.timeIntervalSince1970 - started), "Running")
        }
        if banked > 0 { return (banked, "Paused") }
        // The library has no running stopwatch, so show a plausible one.
        return context.isPreview ? (83, "Paused") : (0, "Ready")
    }

    static func format(_ elapsed: TimeInterval) -> String {
        let seconds = Int(max(0, elapsed))
        let duration = Duration.seconds(seconds)
        return seconds >= 3600
            ? duration.formatted(.time(pattern: .hourMinuteSecond))
            : duration.formatted(.time(pattern: .minuteSecond))
    }
}
