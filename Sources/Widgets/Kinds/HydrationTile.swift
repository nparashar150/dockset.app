import Foundation
import SwiftUI

/// A glass that fills up between drinks (168×124, always expanded).
///
/// The card is a light blue in *both* appearances — matching the shipped
/// design — so only the ink flips with the colour scheme.
///
/// A click on the card belongs to the shelf, so logging a drink is a "+" beside
/// the readout rather than the whole glass: the card is what opens the widget,
/// and a tile-wide tap would take that click before the shelf ever saw it.
struct HydrationTile: View {
    var instance: WidgetInstance
    var context: WidgetContext

    @Environment(\.colorScheme) private var scheme

    /// Guard against a zero or negative stored interval: it would divide by
    /// zero below and NaN the whole path.
    private var duration: TimeInterval {
        max(60, instance.config.double("duration", default: 2700))
    }

    /// Seconds until the next drink.
    ///
    /// Counted from the last drink once there has been one.
    ///
    /// Until then the cycle is anchored to the reference date, so a widget
    /// that has never been tapped still agrees with every other shelf about
    /// where in the interval it is.
    private var remaining: TimeInterval {
        // Sample value chosen to match the library reference render.
        if context.isPreview { return 1800 }
        let period = duration
        let last = instance.config.double("lastDrink")
        if last > 0 {
            let since = max(0, context.now.timeIntervalSince1970 - last)
            return max(0, period - since)
        }
        let into = context.now.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: period)
        return period - into
    }

    /// Logs a drink: the glass empties and starts filling again.
    private func drink() {
        guard !context.isPreview else { return }
        WidgetWriter.write(instance) { config in
            config.set("lastDrink", .number(Date.now.timeIntervalSince1970))
        }
    }

    /// Height of the water, 0…1, as elapsed progress toward the next drink.
    private var level: Double {
        // The reference preview shows a near-full glass; keep the library card
        // looking like the widget rather than like an empty one.
        if context.isPreview { return 0.75 }
        return min(1, max(0, 1 - remaining / duration))
    }

    private var clock: String {
        let seconds = max(0, Int(remaining.rounded(.up)))
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }

    // MARK: Palette

    private var cardFill: Color { Color(hex: scheme == .dark ? "#E0F2FF" : "#EBF3FA") }
    private var waterTop: Color { Color(hex: scheme == .dark ? "#96DDFE" : "#74D0F5") }
    private var waterBottom: Color { Color(hex: scheme == .dark ? "#76CAFE" : "#5EBAFB") }
    private var crest: Color { Color(hex: scheme == .dark ? "#AEE2FF" : "#97D9F7") }

    var body: some View {
        WidgetSurface(fill: cardFill) {
            Group {
                if context.position.isVertical {
                    // 76×88: the water is the widget, so it keeps the whole
                    // column and the readout floats in the middle of it. No
                    // room — and no need — for the caption.
                    VStack(spacing: 4) {
                        Text(clock)
                            .font(.system(size: 17, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(WidgetStyle.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        drinkButton(size: 11)
                    }
                } else {
                    // The readout and the control sit side by side rather than
                    // stacked: a wide card is 58pt tall, which the clock, its
                    // caption and a 26pt disc under them overran — the "+" was
                    // being clipped off the bottom of the glass.
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(clock)
                                .font(.system(size: 21, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(WidgetStyle.primary)
                                .lineLimit(1)
                            Text("Next drink")
                                .font(WidgetStyle.caption(14))
                                .foregroundStyle(WidgetStyle.primary.opacity(0.75))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        drinkButton(size: 13)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // The surface insets its content by 10pt; undo that for the water
            // alone so it reaches the rounded edges the surface clips to.
            .background(water.padding(.horizontal, -WidgetStyle.inset))
        }
    }

    /// Only ever as big as itself: the card's own click has to reach the shelf,
    /// so nothing here may spread to fill it. `TileGlyph` is the shelf-wide
    /// treatment for exactly that — see StopwatchTile. The plain "+" replaces
    /// `plus.circle.fill`, which would have drawn a disc inside a disc.
    ///
    /// The fill rising is the only confirmation a drink registered, which is
    /// why the write is animated rather than the press.
    private func drinkButton(size: CGFloat) -> some View {
        TileGlyph(symbol: "plus", size: size, action: context.isPreview ? nil : {
            withAnimation(.snappy(duration: 0.35)) { drink() }
        })
        .accessibilityLabel("Log a drink")
    }

    private var water: some View {
        Canvas { ctx, size in
            let surface = size.height * (1 - level)
            // Back swell first, half a wavelength out of phase, so it peeks
            // out wherever the front wave troughs.
            ctx.fill(
                wave(in: size, surface: surface - 1.5, amplitude: 2, phase: .pi),
                with: .color(crest.opacity(0.7))
            )
            ctx.fill(
                wave(in: size, surface: surface, amplitude: 2.6, phase: 0),
                with: .linearGradient(
                    Gradient(colors: [waterTop, waterBottom]),
                    startPoint: CGPoint(x: 0, y: surface),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
        }
        .allowsHitTesting(false)
    }

    /// The body of water: one sine along the top, straight down to the bottom.
    private func wave(in size: CGSize, surface: CGFloat,
                      amplitude: CGFloat, phase: Double) -> Path {
        let steps = 48
        var path = Path()
        path.move(to: CGPoint(x: 0, y: surface))
        for step in 0...steps {
            let t = Double(step) / Double(steps)
            let y = surface + amplitude * CGFloat(sin(t * 2 * .pi + phase))
            path.addLine(to: CGPoint(x: size.width * CGFloat(t), y: y))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }
}
