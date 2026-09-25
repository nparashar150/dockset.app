import SwiftUI

/// The panel behind both stock widgets: one symbol at length, or every symbol
/// on the watchlist at once.
///
/// One view for two kinds because it is the same readout at two lengths — a
/// Stock is a Watchlist of one with room for a name and a chart — and both read
/// the same cache through the same accessors as their tiles.
///
/// Nothing here fetches. The panel only ever opens from a tile that is already
/// tracking its symbols, so it renders whatever the cache holds and admits it
/// when that is nothing; a second `track` would only duplicate the tile's.
struct StocksDetail: View {
    var instance: WidgetInstance
    var context: WidgetContext

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if instance.kind == .watchlist {
            watchlist
        } else {
            single
        }
    }

    // MARK: Data
    //
    // The tiles' own accessors, key for key: the panel must never disagree with
    // the tile it grew out of about which symbol is on show.

    private var symbol: String {
        let raw = StockService.normalised(instance.config.string("symbol", default: "AAPL"))
        return raw.isEmpty ? "AAPL" : raw
    }

    private var symbols: [String] {
        let configured = instance.config
            .strings("symbols", default: ["AAPL", "MSFT", "NVDA"])
            .map(StockService.normalised)
            .filter { !$0.isEmpty }
        return configured.isEmpty ? ["AAPL", "MSFT", "NVDA"] : configured
    }

    /// The symbol the tile is currently leading with. A stored choice can
    /// outlive the list it indexed, so an index off the end reads as the start.
    private var leadIndex: Int {
        let stored = instance.config.int("lead")
        return symbols.indices.contains(stored) ? stored : 0
    }

    private func quote(_ symbol: String) -> StockQuote? {
        context.isPreview ? .preview(symbol) : StockService.shared.quote(symbol)
    }

    private func accent(_ quote: StockQuote?) -> Color {
        StockInk.accent(rising: quote?.rising ?? true, scheme: scheme)
    }

    /// Infinities arrive in a half-populated intraday series and would poison
    /// the range labels the same way they poison the chart's min and max.
    private func series(_ quote: StockQuote) -> [Double] {
        quote.history.filter(\.isFinite)
    }

    private func signed(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2))
            .sign(strategy: .always(includingZero: true)))
    }

    // MARK: One symbol

    private var single: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let quote = quote(symbol) {
                identity(quote)
                price(quote)
                change(quote)
                chart(quote)
                if quote.stale { staleNote }
            } else {
                unavailable(symbol)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func identity(_ quote: StockQuote) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(quote.symbol)
                .font(WidgetStyle.label(13))
                .foregroundStyle(WidgetStyle.primary)
            // The service falls back to the ticker when the endpoint sends no
            // name; repeating it as a subtitle would read as a rendering bug.
            if quote.name != quote.symbol {
                Text(quote.name)
                    .font(WidgetStyle.caption(11))
                    .foregroundStyle(WidgetStyle.secondary)
            }
        }
        .lineLimit(1)
        .truncationMode(.tail)
    }

    private func price(_ quote: StockQuote) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(quote.priceText)
                .font(WidgetStyle.value(34))
                .foregroundStyle(WidgetStyle.primary)
                .monospacedDigit()
                .rollingValue(quote.price)
            // The tile has no room to name the currency, so a foreign listing
            // reads there as if it were dollars. The panel does have room.
            Text(quote.currency)
                .font(WidgetStyle.caption(11))
                .foregroundStyle(WidgetStyle.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private func change(_ quote: StockQuote) -> some View {
        HStack(spacing: 5) {
            Image(systemName: quote.rising ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .bold))
            // Both halves of the day's move: the tile shows only the
            // percentage, which says nothing about the size of the position.
            Text(signed(quote.change))
                .monospacedDigit()
                .rollingValue(quote.change)
            Text(quote.percentText)
                .monospacedDigit()
                .rollingValue(quote.changePercent)
        }
        .font(WidgetStyle.label(12))
        .foregroundStyle(accent(quote))
        .lineLimit(1)
    }

    /// Drawn whenever there is a series behind it, regardless of the tile's
    /// `chart` switch: that switch is about how dense the tile is, and a panel
    /// with the room to show the day and a number with no context is the thing
    /// the panel exists to fix. Two points are the minimum an intraday line can
    /// be drawn from; below that the whole block goes rather than leaving a
    /// flat line and an empty gap.
    @ViewBuilder
    private func chart(_ quote: StockQuote) -> some View {
        let samples = series(quote)
        if samples.count >= 2 {
            VStack(alignment: .leading, spacing: 4) {
                DitherChart(samples: samples, tint: accent(quote))
                    .frame(height: 68)
                // The ends of the plotted range, not a clock: the service keeps
                // closes without their timestamps, so a time axis here would be
                // guesswork.
                HStack(spacing: 8) {
                    rangeLabel(samples.first)
                    Spacer(minLength: 8)
                    rangeLabel(samples.last)
                }
            }
            .padding(.top, 2)
        }
    }

    private func rangeLabel(_ value: Double?) -> some View {
        Text(value?.formatted(.number.precision(.fractionLength(2))) ?? "")
            .font(WidgetStyle.caption(10))
            .foregroundStyle(WidgetStyle.secondary)
            .monospacedDigit()
    }

    // MARK: Watchlist

    private var watchlist: some View {
        let symbols = symbols
        let quotes = symbols.map { quote($0) }
        let lead = leadIndex
        return VStack(alignment: .leading, spacing: 8) {
            // Configured order, not the tile's rotation: the tile pages because
            // it can only fit a few symbols, and the panel showing them all has
            // no reason to reshuffle itself under the reader. Indexed rather
            // than keyed on the ticker, because nothing stops a watchlist from
            // carrying the same symbol twice.
            ForEach(symbols.indices, id: \.self) { index in
                row(symbols[index], quote: quotes[index], lead: index == lead)
            }
            if quotes.contains(where: { $0?.stale == true }) { staleNote }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ symbol: String, quote: StockQuote?, lead: Bool) -> some View {
        HStack(spacing: 10) {
            Text(symbol)
                .font(WidgetStyle.label(lead ? 13 : 12))
                .foregroundStyle(WidgetStyle.primary)
            Spacer(minLength: 8)
            Text(quote?.priceText ?? "—")
                .font(WidgetStyle.value(15))
                .foregroundStyle(WidgetStyle.primary)
                .monospacedDigit()
                .rollingValue(quote?.price ?? 0)
            Text(quote?.percentText ?? "—")
                .font(WidgetStyle.label(11))
                .foregroundStyle(accent(quote))
                .monospacedDigit()
                .rollingValue(quote?.changePercent ?? 0)
                // Fixed so the signed percentages line up as a column instead
                // of ragging against the varying price widths.
                .frame(width: 58, alignment: .trailing)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        // The tile's own weighting: a stale row sits back, and the rows behind
        // the lead sit back further.
        .opacity((quote?.stale == true ? 0.55 : 1) * (lead ? 1 : 0.6))
    }

    // MARK: Empty states

    /// A missing quote is either a first fetch that has not landed or one that
    /// failed with nothing cached behind it — the service cannot tell them
    /// apart, so neither does this.
    private func unavailable(_ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(symbol)
                .font(WidgetStyle.label(13))
                .foregroundStyle(WidgetStyle.primary)
            Text("No quote yet.")
                .font(WidgetStyle.caption(11))
                .foregroundStyle(WidgetStyle.secondary)
        }
    }

    private var staleNote: some View {
        HStack(spacing: 5) {
            Image(systemName: "exclamationmark.triangle")
            Text("Last refresh failed — these are the previous good numbers.")
        }
        .font(WidgetStyle.caption(10))
        .foregroundStyle(WidgetStyle.secondary)
        .lineLimit(2)
    }
}
