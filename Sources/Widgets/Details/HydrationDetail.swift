import Foundation
import SwiftUI

/// The hydration reminder in wall-clock terms, plus a button big enough to
/// press without aiming at it.
///
/// The widget stores two things and only two: how long a cycle is
/// (`duration`) and when the last drink was logged (`lastDrink`). There is no
/// count of glasses, no daily goal and no log - one timestamp is overwritten
/// by the next - so this panel draws no tally, no goal ring and no week's
/// chart. Inventing any of them would be inventing the data behind them.
///
/// What it can say that the tile cannot: the clock time the next drink is due
/// at rather than a countdown to it, when the last one actually went in, the
/// interval those two are separated by, and - the tile's blind spot, since its
/// countdown floors at 0:00 - how long a drink has been overdue.
struct HydrationDetail: View {
    var instance: WidgetInstance
    var context: WidgetContext

    var body: some View {
        // Seconds, to agree with the tile's own clock. It has to be a schedule
        // rather than `context.now`: the panel's root view is assigned once
        // when it opens, so that clock is frozen and the countdown would sit
        // perfectly still for as long as the panel stayed up.
        TimelineView(.periodic(from: .now, by: 1)) { tick in
            content(now: tick.date)
        }
    }

    private func content(now: Date) -> some View {
        let left = remaining(now: now)
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                // A time of day, which is the thing the tile's countdown is
                // not: "2:49 PM" is a moment you can plan around, "17:22" is
                // one you have to do arithmetic on.
                Text(left > 0 ? "Next drink at \(clock(now.addingTimeInterval(left)))"
                              : "Time for a drink")
                    .font(WidgetStyle.label(14))
                    .foregroundStyle(WidgetStyle.primary)
                Text(headlineCaption(left, now: now))
                    .font(WidgetStyle.caption(11))
                    .foregroundStyle(WidgetStyle.secondary)
                    .monospacedDigit()
            }

            Divider()

            VStack(spacing: 6) {
                row("Last drink", lastDrinkLine(now: now))
                row("Reminder every", interval)
            }

            drinkButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Rows

    private func row(_ label: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(WidgetStyle.caption(11))
                .foregroundStyle(WidgetStyle.secondary)
            Spacer(minLength: 0)
            Text(value)
                .font(WidgetStyle.label(11))
                .foregroundStyle(WidgetStyle.primary)
                .monospacedDigit()
                .rollingValue(value)
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    /// The tile's "+" is 13pt across because a card's own click belongs to the
    /// shelf and nothing on it may spread. The panel has no such contest, so
    /// the one action this widget has gets the full width.
    private var drinkButton: some View {
        Button {
            // The tile animates its water rising on a drink; the same write
            // redraws this panel, so it is animated from here too.
            withAnimation(.snappy(duration: 0.35)) { drink() }
        } label: {
            Text("Log a drink")
                .font(WidgetStyle.label(13))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background {
                    RoundedRectangle(cornerRadius: 11, style: .continuous).fill(accent)
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log a drink")
    }

    // MARK: Lines

    /// Under the headline: the countdown the tile shows when there is one, and
    /// how far past due it is when there is not. The tile clamps at 0:00 and
    /// stays there, which says a drink is due but never that it has been due
    /// for half an hour.
    private func headlineCaption(_ left: TimeInterval, now: Date) -> String {
        guard left <= 0 else { return "\(docketClockString(left)) to go" }
        let last = instance.config.double("lastDrink")
        guard !context.isPreview, last > 0 else { return "Due now" }
        let over = now.timeIntervalSince1970 - last - duration
        return over >= 60 ? "Overdue by \(spelled(over))" : "Due now"
    }

    /// The one fact only the stored timestamp holds. A widget that has never
    /// been tapped has no last drink - its cycle is anchored to the reference
    /// date instead - so it says so rather than dressing the anchor up as one.
    private func lastDrinkLine(now: Date) -> String {
        let last = instance.config.double("lastDrink")
        guard !context.isPreview, last > 0 else { return "Not logged yet" }
        let date = Date(timeIntervalSince1970: last)
        let since = max(0, now.timeIntervalSince(date))
        return since < 60 ? "\(clock(date)) · just now"
                          : "\(clock(date)) · \(spelled(since)) ago"
    }

    // MARK: Data
    //
    // The tile's accessors, key for key, so the card and the panel cannot
    // disagree about when the next drink is due.

    /// Guard against a zero or negative stored interval: it would divide by
    /// zero below and NaN the whole path.
    private var duration: TimeInterval {
        max(60, instance.config.double("duration", default: 2700))
    }

    private var interval: String { spelled(duration) }

    /// Seconds until the next drink, counted from the last one once there has
    /// been one and from the reference date until then - the tile's rule,
    /// re-read against the schedule's clock rather than the frozen one.
    private func remaining(now: Date) -> TimeInterval {
        // The tile's sample value, so a library preview of the two agrees.
        if context.isPreview { return 1800 }
        let period = duration
        let last = instance.config.double("lastDrink")
        if last > 0 {
            return max(0, period - max(0, now.timeIntervalSince1970 - last))
        }
        let into = now.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: period)
        return period - into
    }

    private func drink() {
        guard !context.isPreview else { return }
        WidgetWriter.write(instance) { config in
            config.set("lastDrink", .number(Date.now.timeIntervalSince1970))
        }
    }

    private var accent: Color {
        WidgetCatalog.accentHex(.hydration).map { Color(hex: $0) } ?? WidgetStyle.primary
    }

    private func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// Hours and minutes in words - "45 min", "1 hr 30 min". The m:ss clock is
    /// right for a countdown that is ticking and wrong for a span that is
    /// merely long.
    private func spelled(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}
