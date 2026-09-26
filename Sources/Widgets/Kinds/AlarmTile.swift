import SwiftUI

/// The next time an alarm named in the config will fire.
///
/// A click on the card opens Clock.app, so the card belongs to the shelf.
/// Arming and silencing stays on the tile as the alarm's own glyph, sized to
/// itself: silencing an alarm by a stray click on a card is how you sleep
/// through something. `enabled` lives in the widget's own config, so a
/// silenced alarm stays silenced across a relaunch. The time itself is never
/// hidden while off - you set a switch by knowing what it is set to.
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
                    // 76x76 column: switch, time, name. The "in Xh Ym" caption
                    // is the row that does not fit, so it goes. The glyph is
                    // 14pt rather than 18 so its disc lands on the 28pt the
                    // bare symbol already reserved and the column keeps its
                    // two lines.
                    VStack(spacing: 2) {
                        toggleGlyph(enabled: enabled, size: 14)
                        VStack(spacing: 2) {
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
                        .opacity(enabled ? 1 : 0.45)
                    }
                } else {
                    // The switch sits level with the block it acts on rather
                    // than in the top corner: a card is 58pt tall, and a glyph
                    // pinned to the top of it reads as a badge printed on the
                    // tile instead of something to press.
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(next.formatted(.dateTime.hour().minute()))
                                .font(WidgetStyle.value(24))
                                .monospacedDigit()
                                .foregroundStyle(WidgetStyle.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(name.isEmpty ? "Alarm" : name)
                                    .font(WidgetStyle.label(14))
                                    .foregroundStyle(WidgetStyle.primary)
                                    .lineLimit(1)
                                    // The countdown is fixed and the switch
                                    // takes 30, so a long name gives way
                                    // rather than truncating at "Morning al…".
                                    .minimumScaleFactor(0.8)
                                // A countdown to something that will not ring
                                // is a lie.
                                Text(enabled ? countdownCaption(to: next) : "Off")
                                    .font(WidgetStyle.caption(13))
                                    .monospacedDigit()
                                    .foregroundStyle(WidgetStyle.secondary)
                                    .fixedSize()
                            }
                        }
                        .opacity(enabled ? 1 : 0.45)
                        Spacer(minLength: 0)
                        toggleGlyph(enabled: enabled, size: 15)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Only ever as big as itself: the card's own click has to reach the shelf,
    /// which is what opens Clock.app, so nothing here may spread to fill it.
    /// `TileGlyph` is the shelf-wide treatment for exactly that - see
    /// StopwatchTile - and it is what turns this from an orange badge in the
    /// corner into a switch.
    ///
    /// The disc carries the alarm's own colour, so an armed alarm sits on
    /// orange and a silenced one on grey: the state is legible before the
    /// glyph itself is read. It stays at full strength while the rest of the
    /// card fades, because the faded thing is what you are being asked to
    /// press to bring back.
    private func toggleGlyph(enabled: Bool, size: CGFloat) -> some View {
        TileGlyph(
            symbol: enabled ? "alarm.fill" : "alarm.slash.fill",
            size: size,
            tint: enabled ? Color(hex: PaletteColor.orange.hex) : WidgetStyle.secondary,
            action: context.isPreview ? nil : (toggle as () -> Void)
        )
        .accessibilityLabel(
            "\(enabled ? "Turn off" : "Turn on") alarm at \(nextOccurrence.formatted(.dateTime.hour().minute()))"
        )
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
