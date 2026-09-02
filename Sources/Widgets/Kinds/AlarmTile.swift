import SwiftUI

/// The next time an alarm named in the config will fire.
///
/// Click to arm or silence it. `enabled` lives in the widget's own config, so a
/// silenced alarm stays silenced across a relaunch. The time itself is never
/// hidden while off — the tile is a switch, and you set it by knowing what it
/// is set to.
struct AlarmTile: View {
    var instance: WidgetInstance
    var context: WidgetContext

    var body: some View {
        let next = nextOccurrence
        let name = instance.config.string("name")
        let enabled = instance.config.bool("enabled", default: true)

        WidgetSurface {
            Group {
                if context.position.isVertical {
                    // 76x76 column: symbol, time, name. The "in Xh Ym" caption is
                    // the row that does not fit, so it goes.
                    VStack(spacing: 2) {
                        Image(systemName: enabled ? "alarm.fill" : "alarm.slash.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(enabled ? Color(hex: PaletteColor.orange.hex) : WidgetStyle.secondary)
                        Text(next.formatted(.dateTime.hour().minute()))
                            .font(WidgetStyle.value(18))
                            .monospacedDigit()
                            .foregroundStyle(WidgetStyle.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(name.isEmpty ? "Alarm" : name)
                            .font(WidgetStyle.caption(9))
                            .foregroundStyle(WidgetStyle.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 6) {
                            Text(next.formatted(.dateTime.hour().minute()))
                                .font(WidgetStyle.value(24))
                                .monospacedDigit()
                                .foregroundStyle(WidgetStyle.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer(minLength: 0)
                            Image(systemName: enabled ? "alarm.fill" : "alarm.slash.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(enabled ? Color(hex: PaletteColor.orange.hex) : WidgetStyle.secondary)
                        }
                        Spacer(minLength: 4)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(name.isEmpty ? "Alarm" : name)
                                .font(WidgetStyle.label(14))
                                .foregroundStyle(WidgetStyle.primary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            // A countdown to something that will not ring is a lie.
                            Text(enabled ? countdownCaption(to: next) : "Off")
                                .font(WidgetStyle.caption(13))
                                .monospacedDigit()
                                .foregroundStyle(WidgetStyle.secondary)
                                .fixedSize()
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            // The surface fills the card only after this closure returns, so the
            // hit area has to be claimed here or it stops at the text.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(enabled ? 1 : 0.45)
            .contentShape(.rect)
            .onTapGesture { toggle() }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(
                "\(enabled ? "Turn off" : "Turn on") alarm at \(next.formatted(.dateTime.hour().minute()))"
            )
        }
    }

    private func toggle() {
        guard !context.isPreview else { return }
        let enabled = instance.config.bool("enabled", default: true)
        withAnimation(.snappy(duration: 0.3)) {
            WidgetWriter.write(instance) { config in
                config.set("enabled", .bool(!enabled))
            }
        }
    }

    /// Next time today's clock reaches the configured `HH:mm`; tomorrow once
    /// it has already passed.
    private var nextOccurrence: Date {
        let parts = instance.config.string("time", default: "14:30").split(separator: ":")
        let hour = parts.count == 2 ? Int(parts[0]) ?? 14 : 14
        let minute = parts.count == 2 ? Int(parts[1]) ?? 30 : 30
        let cal = Calendar.current
        guard let today = cal.date(bySettingHour: min(hour, 23), minute: min(minute, 59),
                                   second: 0, of: context.now) else { return context.now }
        guard today <= context.now else { return today }
        return cal.date(byAdding: .day, value: 1, to: today) ?? today
    }

    private func countdownCaption(to date: Date) -> String {
        let minutes = max(1, Int((date.timeIntervalSince(context.now) / 60).rounded(.up)))
        let (h, m) = (minutes / 60, minutes % 60)
        return h > 0 ? "in \(h)h \(m)m" : "in \(m)m"
    }
}
