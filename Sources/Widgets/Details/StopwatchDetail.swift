import SwiftUI

/// The stopwatch at reading size, with the two glyphs the tile shrinks to 9pt
/// named as buttons.
///
/// Everything here is the tile's own two config keys: `started`, the epoch the
/// current run began, and `elapsed`, what earlier runs banked. The panel reads
/// and writes them exactly as the tile does, so the two can never disagree
/// about whether the watch is running.
///
/// There is no lap list. Nothing in the model records a lap, and a panel is
/// not the place to invent one.
struct StopwatchDetail: View {
    var instance: WidgetInstance
    var context: WidgetContext

    var body: some View {
        // Tenths are the one thing a 21pt tile readout cannot carry, and the
        // panel's `context.now` is frozen at the moment it opened - so the
        // schedule is what moves the figure. A stopped watch has nothing to
        // redraw ten times a second; the schedule is rebuilt when the config
        // changes, which is the same moment `running` flips.
        TimelineView(.periodic(from: .now, by: running ? 0.1 : 1)) { tick in
            content(now: tick.date)
        }
    }

    private func content(now: Date) -> some View {
        let elapsed = elapsed(at: now)

        return VStack(spacing: 16) {
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(StopwatchTile.format(elapsed))
                        .font(WidgetStyle.value(52))
                        .foregroundStyle(WidgetStyle.primary)
                        // Only the seconds roll: a tenth that animated would
                        // still be mid-transition when the next one landed.
                        .rollingValue(Int(elapsed))
                    Text(".\(Int(elapsed * 10) % 10)")
                        .font(WidgetStyle.value(26))
                        .foregroundStyle(WidgetStyle.secondary)
                }
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)

                Text(caption)
                    .font(WidgetStyle.caption(12))
                    .foregroundStyle(WidgetStyle.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                ClockPanelButton(title: running ? "Stop" : "Start",
                                 fill: .accentColor, action: toggle)
                ClockPanelButton(title: "Reset", fill: nil, action: reset)
                    .disabled(untouched)
                    .opacity(untouched ? 0.4 : 1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: State
    //
    // The tile's accessors, key for key.

    private var startedAt: TimeInterval { instance.config.double("started") }
    private var banked: TimeInterval { instance.config.double("elapsed") }
    private var running: Bool { startedAt > 0 }
    /// A watch that has never run has nothing to clear.
    private var untouched: Bool { !running && banked == 0 }

    private func elapsed(at now: Date) -> TimeInterval {
        guard running else { return banked }
        return banked + max(0, now.timeIntervalSince1970 - startedAt)
    }

    /// The wall-clock moment the run on screen began - the one fact the config
    /// holds that neither the tile nor the readout can say. A run picked up
    /// after a stop says "Resumed", because `started` is then the resume
    /// rather than the beginning.
    private var caption: String {
        guard running else { return banked > 0 ? "Paused" : "Ready" }
        let since = Date(timeIntervalSince1970: startedAt)
            .formatted(date: .omitted, time: .standard)
        return (banked > 0 ? "Resumed " : "Started ") + since
    }

    // MARK: Actions

    /// Banks what has run so far when stopping, so starting again continues
    /// rather than beginning from zero - the tile's own rule.
    private func toggle() {
        guard !context.isPreview else { return }
        let started = startedAt
        let banked = banked
        withAnimation(.snappy(duration: 0.3)) {
            WidgetWriter.write(instance) { config in
                if started > 0 {
                    config.set("elapsed",
                               .number(banked + max(0, Date.now.timeIntervalSince1970 - started)))
                    config.set("started", .number(0))
                } else {
                    config.set("started", .number(Date.now.timeIntervalSince1970))
                }
            }
        }
    }

    private func reset() {
        guard !context.isPreview else { return }
        withAnimation(.snappy(duration: 0.3)) {
            WidgetWriter.write(instance) { config in
                config.set("started", .number(0))
                config.set("elapsed", .number(0))
            }
        }
    }
}

/// The panel-sized action the clock tiles can only offer as a glyph the size
/// of itself.
///
/// Shared by the Stopwatch, Countdown and Alarm panels so the three read as
/// one family, and weighted like the Focus Timer's pair: filled for the action
/// the panel is about, outlined for the one that throws work away.
struct ClockPanelButton: View {
    var title: String
    /// nil draws the outlined form.
    var fill: Color?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(WidgetStyle.label(13))
                .foregroundStyle(fill == nil ? WidgetStyle.secondary : Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(fill ?? .clear)
                        .overlay {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(fill == nil ? Color.primary.opacity(0.14) : .clear,
                                              lineWidth: 1)
                        }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
