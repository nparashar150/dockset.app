import Observation
import SwiftUI

/// The Focus Timer is one timer for the whole app, not one per widget: two
/// timer tiles on the shelf show the same countdown. Until app state is wired
/// up, every tile reads the shared state from here.
@MainActor @Observable
final class TimerStateProvider {
    static let shared = TimerStateProvider()
    var state = TimerState()
}

/// Click to start or pause the countdown, double-click to put it back to a
/// full session. The click drives the shared state rather than this widget's
/// config, so both tiles of a two-tile shelf start and stop together.
struct FocusTimerTile: View {
    var instance: WidgetInstance
    var context: WidgetContext

    var body: some View {
        let state = resolvedState
        let total = max(1, state.duration ?? Double(state.minutes * 60))
        let remaining = remaining(in: state, total: total)
        let tint = WidgetStyle.tint(state.color)

        WidgetSurface {
            if context.position.isVertical {
                // 76x92 column: the ring is the widget, with the clock inside
                // it and the phase named underneath.
                VStack(spacing: 5) {
                    ZStack {
                        ring(fraction: remaining / total, tint: tint, diameter: 44, width: 6)
                        Text(plinthClockString(remaining))
                            .font(WidgetStyle.label(13))
                            .monospacedDigit()
                            .foregroundStyle(WidgetStyle.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(width: 34)
                    }
                    Text(state.phase.label)
                        .font(WidgetStyle.caption(9))
                        .foregroundStyle(WidgetStyle.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            } else if instance.expanded {
                HStack(spacing: 12) {
                    ring(fraction: remaining / total, tint: tint, diameter: 32, width: 7)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(plinthClockString(remaining))
                            .font(WidgetStyle.value(23))
                            .monospacedDigit()
                            .foregroundStyle(WidgetStyle.primary)
                        Text(state.phase.label)
                            .font(WidgetStyle.caption(14))
                            .foregroundStyle(WidgetStyle.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            } else {
                VStack(spacing: 3) {
                    ring(fraction: remaining / total, tint: tint, diameter: 24, width: 5)
                    Text(plinthClockString(remaining))
                        .font(WidgetStyle.label(13))
                        .monospacedDigit()
                        .foregroundStyle(WidgetStyle.primary)
                }
            }
        }
        .contentShape(.rect)
        .onTapGesture(count: 2) { reset() }
        .onTapGesture { toggle() }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(state.paused == nil && state.deadline != nil
            ? "Pause focus timer" : "Start focus timer")
    }

    /// Pausing banks what is left instead of the deadline, so resuming carries
    /// on from the figure on screen rather than from a moment that has since
    /// gone by. A timer already at zero has nothing to resume, so it restarts.
    private func toggle() {
        guard !context.isPreview else { return }
        var state = TimerStateProvider.shared.state
        let total = max(1, state.duration ?? Double(state.minutes * 60))
        let left = remaining(in: state, total: total)
        if left <= 0 {
            state.duration = total
            state.deadline = context.now.addingTimeInterval(total)
            state.paused = nil
        } else if state.deadline == nil {
            // Starting from idle pins the length now, so changing the session
            // in settings cannot rescale a countdown that is already running.
            state.duration = total
            state.deadline = context.now.addingTimeInterval(left)
            state.paused = nil
        } else {
            state.paused = left
            state.deadline = nil
        }
        withAnimation(.snappy(duration: 0.3)) { TimerStateProvider.shared.state = state }
    }

    /// Clearing the pinned duration too, so a reset picks up a session length
    /// the user has changed since this timer last ran.
    private func reset() {
        guard !context.isPreview else { return }
        var state = TimerStateProvider.shared.state
        state.deadline = nil
        state.paused = nil
        state.duration = nil
        withAnimation(.snappy(duration: 0.3)) { TimerStateProvider.shared.state = state }
    }

    /// The library has no running timer, so show a representative one.
    private var resolvedState: TimerState {
        guard context.isPreview else { return TimerStateProvider.shared.state }
        var preview = TimerState()
        preview.phase = .focus
        preview.duration = Double(preview.work * 60)
        preview.deadline = context.now.addingTimeInterval(300)
        return preview
    }

    /// Paused wins over the deadline; with neither the timer is idle and sits
    /// at its full duration rather than at zero.
    private func remaining(in state: TimerState, total: TimeInterval) -> TimeInterval {
        if let paused = state.paused { return max(0, min(paused, total)) }
        guard let deadline = state.deadline else { return total }
        return max(0, min(deadline.timeIntervalSince(context.now), total))
    }

    /// Empties as time passes.
    private func ring(fraction: Double, tint: Color, diameter: CGFloat, width: CGFloat) -> some View {
        ZStack {
            Circle().stroke(tint.opacity(0.18), lineWidth: width)
            Circle()
                .trim(from: 0, to: max(0, min(1, fraction)))
                .stroke(tint, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: diameter, height: diameter)
    }
}

/// `m:ss`, widening to `h:mm:ss` past an hour so a long timer is not shown as
/// a bare minute count.
func plinthClockString(_ seconds: TimeInterval) -> String {
    let total = Int(seconds.rounded(.up))
    let (h, m, s) = (total / 3600, (total % 3600) / 60, total % 60)
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}
