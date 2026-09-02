import SwiftUI

/// Time left against a deadline, with what it is counting to underneath.
///
/// Click to start it from idle, double-click to restart the full period. The
/// deadline lives in the widget's own config, so it survives a relaunch and
/// follows the widget between profiles.
struct CountdownTile: View {
    var instance: WidgetInstance
    var context: WidgetContext

    var body: some View {
        let duration = max(0, instance.config.double("duration", default: 300))
        let name = instance.config.string("name")
        let title = name.isEmpty ? "Countdown" : name

        WidgetSurface {
            Group {
                if context.position.isVertical {
                    // 76x62 column: no room for the timer symbol, so the clock
                    // carries the tile and the name captions it.
                    VStack(spacing: 1) {
                        Text(plinthClockString(remaining(duration: duration)))
                            .font(WidgetStyle.value(19))
                            .monospacedDigit()
                            .foregroundStyle(WidgetStyle.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(title)
                            .font(WidgetStyle.caption(9))
                            .foregroundStyle(WidgetStyle.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "timer")
                            .font(.system(size: 23, weight: .regular))
                            .foregroundStyle(WidgetStyle.secondary)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(plinthClockString(remaining(duration: duration)))
                                .font(WidgetStyle.value(20))
                                .monospacedDigit()
                                .foregroundStyle(WidgetStyle.primary)
                            Text(title)
                                .font(WidgetStyle.caption(13))
                                .foregroundStyle(WidgetStyle.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            .onTapGesture(count: 2) { restart() }
            .onTapGesture { startIfIdle() }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(isRunning ? "Restart \(title)" : "Start \(title)")
        }
    }

    /// A countdown is running only while it carries a deadline; idle it shows
    /// what it would count from, not 0:00.
    private func remaining(duration: TimeInterval) -> TimeInterval {
        guard !context.isPreview, instance.config["deadline"] != nil else { return duration }
        let deadline = instance.config.double("deadline")
        return max(0, min(deadline - context.now.timeIntervalSince1970, duration))
    }

    private var isRunning: Bool {
        !context.isPreview && instance.config.double("deadline") > context.now.timeIntervalSince1970
    }

    /// The deadline is stored rather than a remaining time, so the tile keeps
    /// counting down across a relaunch instead of resuming where it stopped.
    private func restart() {
        guard !context.isPreview else { return }
        let duration = max(0, instance.config.double("duration", default: 300))
        withAnimation(.snappy(duration: 0.3)) {
            WidgetWriter.write(instance) { config in
                config.set("deadline", .number(Date.now.timeIntervalSince1970 + duration))
            }
        }
    }

    /// A single click never shortens a countdown already in flight; cutting one
    /// short is deliberate enough to be worth the second click.
    private func startIfIdle() {
        guard !isRunning else { return }
        restart()
    }
}
