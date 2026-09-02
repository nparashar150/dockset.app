import Foundation
import SwiftUI

/// How much of the current day, month or year has already gone.
///
/// Three layouts share one number: `bars` (176×78), `ring` (148×76) and
/// `percentage` (112×62). The fraction comes from the real calendar interval
/// around `context.now`, so there is nothing to stub out in the library.
///
/// Click to move the span on: day → month → year. The choice is `period` in
/// the widget's own config, the same key the catalog seeds, so it survives a
/// relaunch and follows the widget between profiles.
struct TimeProgressTile: View {
    var instance: WidgetInstance
    var context: WidgetContext

    /// One bar per 3pt of the 156pt content width.
    private static let barCount = 52

    /// Shortest span first, so a click reads as zooming out.
    private static let periods = ["day", "month", "year"]

    private var period: Calendar.Component {
        switch instance.config.string("period", default: "year") {
        case "day": .day
        case "month": .month
        default: .year
        }
    }

    /// 0…1 through the current period. A calendar interval — not a fixed
    /// 24h/365d — so DST days and leap years stay honest.
    private var fraction: Double {
        let calendar = Calendar.current
        guard let span = calendar.dateInterval(of: period, for: context.now),
              span.duration > 0 else { return 0 }
        let elapsed = context.now.timeIntervalSince(span.start) / span.duration
        return min(1, max(0, elapsed))
    }

    private var percent: Int { Int(fraction * 100) }

    private var label: String {
        switch period {
        case .day: context.now.formatted(.dateTime.weekday(.wide))
        case .month: context.now.formatted(.dateTime.month(.wide))
        default: context.now.formatted(.dateTime.year())
        }
    }

    var body: some View {
        WidgetSurface {
            Group {
                if context.position.isVertical {
                    // The 52-bar run cannot survive 56pt of usable width, so a
                    // column always rings — whatever the horizontal layout is.
                    if instance.config.string("layout", default: "bars") == "percentage" {
                        columnPercentage
                    } else {
                        columnRing
                    }
                } else {
                    switch instance.config.string("layout", default: "bars") {
                    case "ring": ringLayout
                    case "percentage": percentageLayout
                    default: barsLayout
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            .onTapGesture { cycle() }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("\(label), \(percent)% elapsed. Click for the next period.")
        }
    }

    /// Every layout reads `period`, so one write swaps the span in place and
    /// leaves the chosen layout alone. A value from elsewhere that isn't one of
    /// the three lands on the first span rather than sticking.
    private func cycle() {
        guard !context.isPreview else { return }
        let current = instance.config.string("period", default: "year")
        let index = Self.periods.firstIndex(of: current) ?? Self.periods.count - 1
        let next = Self.periods[(index + 1) % Self.periods.count]
        withAnimation(.snappy(duration: 0.3)) {
            WidgetWriter.write(instance) { config in
                config.set("period", .string(next))
            }
        }
    }

    // MARK: Layouts

    private var barsLayout: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(label)
                    .font(WidgetStyle.label(13))
                    .foregroundStyle(WidgetStyle.primary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                percentText(15)
            }
            bars
        }
    }

    private var bars: some View {
        let filled = Int(fraction * Double(Self.barCount))
        return HStack(spacing: 4.0 / 3.0) {
            ForEach(0..<Self.barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 0.85, style: .continuous)
                    .fill(index < filled ? WidgetStyle.primary : WidgetStyle.primary.opacity(0.14))
                    .frame(width: 5.0 / 3.0)
            }
        }
        .frame(height: 19)
    }

    private var ringLayout: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(WidgetStyle.primary.opacity(0.12), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(WidgetStyle.primary,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 1) {
                percentText(18)
                Text(label)
                    .font(WidgetStyle.caption(11))
                    .foregroundStyle(WidgetStyle.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
        }
    }

    private var percentageLayout: some View {
        VStack(spacing: 1) {
            percentText(22)
            Text(label)
                .font(WidgetStyle.caption(11))
                .foregroundStyle(WidgetStyle.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: Column layouts (76pt wide, 56pt usable)

    /// 76×80: ring with the figure inside, period beneath.
    private var columnRing: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(WidgetStyle.primary.opacity(0.12), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(WidgetStyle.primary,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                percentText(13)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 3)
            }
            .frame(width: 44, height: 44)

            periodLabel(10)
        }
    }

    /// 76×58: the figure over the period, nothing else.
    private var columnPercentage: some View {
        VStack(spacing: 1) {
            percentText(21)
                .minimumScaleFactor(0.6)
            periodLabel(10)
        }
    }

    /// "September" is wider than 56pt at full size, so it scales rather than
    /// truncating to "Septem…".
    private func periodLabel(_ size: CGFloat) -> some View {
        Text(label)
            .font(WidgetStyle.caption(size))
            .foregroundStyle(WidgetStyle.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    // MARK: Pieces

    /// The figure is bold and primary, the sign is quieter — reads as one
    /// number rather than a number shouting a unit.
    private func percentText(_ size: CGFloat) -> some View {
        HStack(spacing: 0) {
            Text(percent.formatted())
                .foregroundStyle(WidgetStyle.primary)
            Text("%")
                .foregroundStyle(WidgetStyle.secondary)
        }
        .font(.system(size: size, weight: .bold))
        .monospacedDigit()
        .lineLimit(1)
    }
}
