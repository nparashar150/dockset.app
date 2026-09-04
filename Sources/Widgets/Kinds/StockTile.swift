import SwiftUI

/// One symbol: ticker, price, signed percentage, and a dithered intraday chart.
///
/// Wide (192×62) puts the readout on the left and the chart in the right half.
/// The 76pt column has no room beside anything, so it stacks — ticker, price,
/// percentage, then the chart across the full width.
///
/// Click to move to the next of the configured `symbols`; the one on show is
/// `symbol` in the widget's own config, so it survives a relaunch.
struct StockTile: View {
    var instance: WidgetInstance
    var context: WidgetContext

    @Environment(\.colorScheme) private var scheme

    private var symbol: String {
        let raw = StockService.normalised(instance.config.string("symbol", default: "AAPL"))
        return raw.isEmpty ? "AAPL" : raw
    }

    /// The symbols the user configured, deduplicated so a repeated entry cannot
    /// make a click land on the ticker already showing.
    private var rotation: [String] {
        instance.config.strings("symbols", default: [])
            .map(StockService.normalised)
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { unique, symbol in
                if !unique.contains(symbol) { unique.append(symbol) }
            }
    }

    /// The library shows sample values; the shelf shows the cache, which is
    /// empty only until the first fetch lands.
    private var quote: StockQuote? {
        context.isPreview ? .preview(symbol) : StockService.shared.quote(symbol)
    }

    private var accent: Color {
        StockInk.accent(rising: quote?.rising ?? true, scheme: scheme)
    }

    var body: some View {
        WidgetSurface {
            Group {
                if context.position.isVertical { column } else { wide }
            }
            // A failed refresh keeps the last good numbers and admits it by
            // fading, rather than blanking or showing a zero.
            .opacity(quote?.stale == true ? 0.55 : 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            .onTapGesture { advance() }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(rotation.count > 1 ? "\(symbol), show next symbol" : symbol)
        }
        .task(id: symbol) {
            guard !context.isPreview else { return }
            StockService.shared.track([symbol])
        }
    }

    /// One symbol is not a rotation, so the click is ignored rather than
    /// rewriting the value already on show. A symbol that is no longer in the
    /// list has no successor; the first entry is the way back in.
    private func advance() {
        guard !context.isPreview, rotation.count > 1 else { return }
        let next = rotation.firstIndex(of: symbol)
            .map { rotation[($0 + 1) % rotation.count] } ?? rotation[0]
        withAnimation(.snappy(duration: 0.3)) {
            WidgetWriter.write(instance) { config in
                config.set("symbol", .string(next))
            }
        }
    }

    // MARK: Layouts

    private var wide: some View {
        HStack(spacing: 8) {
            // Fixed: the readout keeps its natural width and the chart takes
            // whatever is left, which is the right half of a 192pt tile.
            readout(ticker: 11, price: 18, percent: 11, fixed: true)
            chart.frame(maxWidth: .infinity, maxHeight: 32)
        }
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: 2) {
            readout(ticker: 9, price: 15, percent: 9, fixed: false)
            chart.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.vertical, 5)
    }

    private var chart: DitherChart {
        DitherChart(samples: quote?.history ?? [], tint: accent)
    }

    private func readout(ticker: CGFloat, price: CGFloat, percent: CGFloat,
                         fixed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(symbol)
                .font(WidgetStyle.label(ticker))
                .foregroundStyle(WidgetStyle.primary)
            Text(quote?.priceText ?? "—")
                .font(WidgetStyle.value(price))
                .foregroundStyle(WidgetStyle.primary)
                .monospacedDigit()
            Text(quote?.percentText ?? "")
                .font(WidgetStyle.label(percent))
                .foregroundStyle(accent)
                .monospacedDigit()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: fixed ? nil : .infinity, alignment: .leading)
        .fixedSize(horizontal: fixed, vertical: false)
    }
}

/// Gain green and loss red, picked for contrast against the tile in each
/// appearance rather than left to one system swatch that goes muddy in the
/// other. Shared with the Watchlist tile.
enum StockInk {
    static func accent(rising: Bool, scheme: ColorScheme) -> Color {
        if rising {
            Color(hex: scheme == .dark ? "#30D158" : "#0D7533")
        } else {
            Color(hex: scheme == .dark ? "#FF757D" : "#C7212B")
        }
    }
}
