import SwiftUI

/// Several symbols at a glance, no charts (276×62 wide).
///
/// Wide, each symbol is its own centred column — ticker, price, signed
/// percentage — sharing the tile equally. In a 76pt column there is only room
/// for one line of figures per symbol, so each becomes a compact two-line row
/// with the ticker and the percentage on top and the price under them.
///
/// Click to page the list: the next symbol takes the front and the rest wrap
/// around behind it, so a longer watchlist can be read a symbol at a time. The
/// choice is `lead` in the widget's own config, so it survives a relaunch and
/// follows the widget between profiles.
struct WatchlistTile: View {
    var instance: WidgetInstance
    var context: WidgetContext

    @Environment(\.colorScheme) private var scheme

    private var symbols: [String] {
        let configured = instance.config
            .strings("symbols", default: ["AAPL", "MSFT", "NVDA"])
            .map(StockService.normalised)
            .filter { !$0.isEmpty }
        // An empty list would render an empty tile; fall back to the default
        // rather than to nothing.
        return configured.isEmpty ? ["AAPL", "MSFT", "NVDA"] : configured
    }

    /// The symbols are editable, so a stored choice can outlive the list it
    /// indexed. An index off the end reads as the start rather than trapping.
    private var leadIndex: Int {
        let stored = instance.config.int("lead")
        return symbols.indices.contains(stored) ? stored : 0
    }

    /// The list rotated so the chosen symbol reads first, the rest keeping
    /// their order behind it.
    private var ordered: [String] {
        let symbols = symbols
        let lead = leadIndex
        return Array(symbols[lead...] + symbols[..<lead])
    }

    private func quote(_ symbol: String) -> StockQuote? {
        context.isPreview ? .preview(symbol) : StockService.shared.quote(symbol)
    }

    var body: some View {
        let ordered = ordered
        WidgetSurface {
            Group {
                if context.position.isVertical { column(ordered) } else { wide(ordered) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            .onTapGesture { advance() }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Watchlist, \(ordered.first ?? "empty") first. Click for the next symbol.")
        }
        // Keyed on the unrotated list: paging reorders what is shown, not what
        // is being polled, and must not restart tracking.
        .task(id: symbols) {
            guard !context.isPreview else { return }
            StockService.shared.track(symbols)
        }
    }

    private func advance() {
        guard !context.isPreview else { return }
        let next = (leadIndex + 1) % symbols.count
        withAnimation(.snappy(duration: 0.3)) {
            WidgetWriter.write(instance) { config in
                config.set("lead", .number(Double(next)))
            }
        }
    }

    // MARK: Layouts

    private func wide(_ ordered: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(ordered, id: \.self) { symbol in
                let quote = quote(symbol)
                VStack(spacing: 1) {
                    Text(symbol)
                        .font(WidgetStyle.label(11))
                        .foregroundStyle(WidgetStyle.primary)
                    Text(quote?.priceText ?? "—")
                        .font(WidgetStyle.value(18))
                        .foregroundStyle(WidgetStyle.primary)
                        .monospacedDigit()
                    Text(quote?.percentText ?? "")
                        .font(WidgetStyle.label(11))
                        .foregroundStyle(accent(quote))
                        .monospacedDigit()
                }
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .opacity(weight(quote, lead: symbol == ordered.first))
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func column(_ ordered: [String]) -> some View {
        VStack(spacing: 0) {
            ForEach(ordered, id: \.self) { symbol in
                let quote = quote(symbol)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Text(symbol)
                            .font(WidgetStyle.label(9))
                            .foregroundStyle(WidgetStyle.secondary)
                        Spacer(minLength: 0)
                        Text(quote?.percentText ?? "")
                            .font(WidgetStyle.label(9))
                            .foregroundStyle(accent(quote))
                            .monospacedDigit()
                    }
                    Text(quote?.priceText ?? "—")
                        .font(WidgetStyle.value(13))
                        .foregroundStyle(WidgetStyle.primary)
                        .monospacedDigit()
                }
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .opacity(weight(quote, lead: symbol == ordered.first))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
    }

    /// A stale quote already sits back; the symbols behind the lead sit back
    /// further, which is the only cue that the click landed on a tile whose
    /// layout is otherwise unchanged.
    private func weight(_ quote: StockQuote?, lead: Bool) -> Double {
        (quote?.stale == true ? 0.55 : 1) * (lead ? 1 : 0.6)
    }

    private func accent(_ quote: StockQuote?) -> Color {
        StockInk.accent(rising: quote?.rising ?? true, scheme: scheme)
    }
}
