import SwiftUI

/// One alarm, said properly.
///
/// The widget holds exactly one — `time`, `name` and `enabled` in its own
/// config — so this is a single-alarm panel rather than a list pretending to
/// be one. Several alarms means several widgets, each with its own tile and
/// its own panel.
///
/// What the card cannot fit: which day the next ring lands on, the count to it
/// to the second rather than rounded up to the minute, and a switch you have
/// to mean — silencing an alarm is how you sleep through something, which is
/// why the tile keeps it to a glyph the size of itself and the panel gives it
/// a button.
struct AlarmDetail: View {
    var instance: WidgetInstance
    var context: WidgetContext

    var body: some View {
        // The panel's context is frozen at the moment it opened, so the
        // schedule is what carries the count down — and what rolls the next
        // occurrence over to tomorrow the second this one passes.
        TimelineView(.periodic(from: .now, by: 1)) { tick in
            content(now: tick.date)
        }
    }

    private func content(now: Date) -> some View {
        let next = nextOccurrence(after: now)
        let enabled = instance.config.bool("enabled", default: true)
        let name = instance.config.string("name")

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(next.formatted(.dateTime.hour().minute()))
                    .font(WidgetStyle.value(44))
                    .monospacedDigit()
                    .foregroundStyle(WidgetStyle.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(name.isEmpty ? "Alarm" : name)
                    .font(WidgetStyle.label(14))
                    .foregroundStyle(WidgetStyle.primary)
                    .lineLimit(1)
            }
            // The time itself is never dimmed while off: you set a switch by
            // knowing what it is set to.
            .opacity(enabled ? 1 : 0.55)

            Divider()

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(dayLine(next, now: now))
                    .font(WidgetStyle.caption(12))
                    .foregroundStyle(WidgetStyle.secondary)
                Spacer(minLength: 8)
                // A countdown to something that will not ring is a lie, so a
                // silenced alarm says so instead.
                Text(enabled ? countdown(to: next, from: now) : "Silenced")
                    .font(WidgetStyle.caption(12))
                    .monospacedDigit()
                    .foregroundStyle(WidgetStyle.secondary)
                    .rollingValue(Int(next.timeIntervalSince(now)))
                    .fixedSize()
            }

            // Filled for arming, because that is the action that makes the
            // alarm do its job; silencing is outlined for the same reason
            // Reset is next to Start.
            ClockPanelButton(title: enabled ? "Silence" : "Turn On",
                             fill: enabled ? nil : Color(hex: PaletteColor.orange.hex),
                             action: toggle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Data
    //
    // The tile's accessors, key for key: the panel must not disagree with the
    // card that opened it about when this alarm next rings.

    /// Next time today's clock reaches the configured `HH:mm`; tomorrow once
    /// it has already passed.
    private func nextOccurrence(after now: Date) -> Date {
        let parts = instance.config.string("time", default: "14:30").split(separator: ":")
        let hour = parts.count == 2 ? Int(parts[0]) ?? 14 : 14
        let minute = parts.count == 2 ? Int(parts[1]) ?? 30 : 30
        let cal = Calendar.current
        guard let today = cal.date(bySettingHour: min(hour, 23), minute: min(minute, 59),
                                   second: 0, of: now) else { return now }
        guard today <= now else { return today }
        return cal.date(byAdding: .day, value: 1, to: today) ?? today
    }

    /// An alarm repeats daily, so the next one is today's or tomorrow's and
    /// nothing else — but which of the two, and what date that is, is exactly
    /// what a 24-hour time on a card leaves you to work out.
    private func dayLine(_ date: Date, now: Date) -> String {
        let day = Calendar.current.isDate(date, inSameDayAs: now) ? "Today" : "Tomorrow"
        return "\(day) · \(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))"
    }

    private func countdown(to date: Date, from now: Date) -> String {
        let total = max(0, Int(date.timeIntervalSince(now)))
        let (h, m, s) = (total / 3600, (total % 3600) / 60, total % 60)
        return h > 0 ? String(format: "in %dh %02dm %02ds", h, m, s)
                     : String(format: "in %dm %02ds", m, s)
    }

    // MARK: Actions

    private func toggle() {
        guard !context.isPreview else { return }
        let enabled = instance.config.bool("enabled", default: true)
        withAnimation(.snappy(duration: 0.3)) {
            WidgetWriter.write(instance) { config in
                config.set("enabled", .bool(!enabled))
            }
        }
    }
}
