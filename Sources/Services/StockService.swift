import Foundation
import Observation

/// One symbol's last known state. `history` is the intraday close series the
/// dithered chart draws; `stale` means the last refresh failed and these
/// numbers are the previous good ones rather than fresh.
struct StockQuote: Sendable {
    var symbol, name: String
    var price, change, changePercent: Double
    var currency: String
    var history: [Double]
    var stale: Bool
}

/// Quotes and intraday history for the Stock and Watchlist widgets.
///
/// Backed by Yahoo's chart endpoint, which needs no key:
/// `https://query1.finance.yahoo.com/v8/finance/chart/AAPL?range=1d&interval=5m`
///
/// **That endpoint is undocumented.** It is not a contract: fields come and go
/// and it 403s a non-browser User-Agent. Every field is therefore optional and
/// every failure path returns `nil`, which leaves the cached quote in place and
/// only flips `stale`. Nothing here ever traps, and nothing ever writes a zero
/// that would read as a real price.
@MainActor @Observable
final class StockService {
    static let shared = StockService()

    /// Permanent on-screen widgets, not a page load: one poll per five
    /// minutes is plenty for a shelf, and stays far under anything Yahoo
    /// throttles.
    private static let interval: TimeInterval = 300

    private(set) var quotes: [String: StockQuote] = [:]

    @ObservationIgnored private var tracked: Set<String> = []
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var refreshing = false

    private init() {}

    // MARK: Public surface

    func quote(_ symbol: String) -> StockQuote? { quotes[Self.normalised(symbol)] }

    /// Registers the symbols a widget is showing. Nothing is fetched until the
    /// first widget asks, so a shelf with no stock widgets never touches the
    /// network.
    ///
    // ponytail: the tracked set only grows for the life of the process — a
    // removed widget costs one extra request per five minutes. Add a refcount
    // if someone actually churns watchlists.
    func track(_ symbols: [String]) {
        let wanted = Set(symbols.map(Self.normalised)).subtracting([""])
        let added = wanted.subtracting(tracked)
        guard !added.isEmpty else { return }
        tracked.formUnion(added)
        startTimer()
        // Only the newcomers: a widget appearing must not re-pull the symbols
        // already on screen, nor wait out the cadence for its own.
        Task { await load(added) }
    }

    func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        await load(tracked)
    }

    private func load(_ symbols: Set<String>) async {
        guard !symbols.isEmpty else { return }
        await withTaskGroup(of: (String, StockQuote?).self) { group in
            for symbol in symbols {
                group.addTask { (symbol, await Self.fetch(symbol)) }
            }
            for await (symbol, fresh) in group {
                if let fresh {
                    quotes[symbol] = fresh
                } else if var last = quotes[symbol] {
                    // Keep the last good numbers; only admit they are old.
                    last.stale = true
                    quotes[symbol] = last
                }
            }
        }
    }

    // MARK: Cadence

    private func startTimer() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Task { await self.refresh() }
            }
        }
        // Generous: nothing here needs to land on a particular second, and
        // slack lets the system coalesce the wakeup.
        timer.tolerance = 30
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    nonisolated static func normalised(_ symbol: String) -> String {
        symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    // MARK: Network

    /// Safari's own User-Agent. The endpoint rejects an empty or SDK one.
    nonisolated private static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 "
        + "(KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    nonisolated private static func fetch(_ symbol: String) async -> StockQuote? {
        guard let path = symbol.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              !path.isEmpty,
              let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/"
                            + path + "?range=1d&interval=5m")
        else { return nil }

        var request = URLRequest(url: url, timeoutInterval: 12)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else { return nil }
            return decode(data, symbol: symbol)
        } catch {
            return nil
        }
    }

    /// Mirrors only the handful of fields we read, all optional — a shape
    /// change drops us to `nil`, never a trap.
    private struct Payload: Decodable {
        struct Meta: Decodable {
            var currency: String?
            var shortName: String?
            var longName: String?
            var regularMarketPrice: Double?
            var chartPreviousClose: Double?
            var previousClose: Double?
        }
        struct Series: Decodable { var close: [Double?]? }
        struct Indicators: Decodable { var quote: [Series]? }
        struct Result: Decodable {
            var meta: Meta?
            var indicators: Indicators?
        }
        struct Chart: Decodable { var result: [Result]? }
        var chart: Chart?
    }

    nonisolated private static func decode(_ data: Data, symbol: String) -> StockQuote? {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              let result = payload.chart?.result?.first,
              let meta = result.meta
        else { return nil }

        // Gaps in the series are nulls, not zeros — dropping them keeps the
        // chart honest instead of drawing a cliff to the x-axis.
        let closes = (result.indicators?.quote?.first?.close ?? [])
            .compactMap { $0 }
            .filter(\.isFinite)

        guard let price = meta.regularMarketPrice ?? closes.last, price.isFinite else { return nil }

        var change = 0.0
        var percent = 0.0
        if let previous = meta.chartPreviousClose ?? meta.previousClose ?? closes.first,
           previous.isFinite, previous > 0 {
            change = price - previous
            percent = change / previous * 100
        }

        return StockQuote(
            symbol: symbol,
            name: meta.shortName ?? meta.longName ?? symbol,
            price: price,
            change: change,
            changePercent: percent,
            currency: meta.currency ?? "USD",
            history: Array(closes.suffix(160)),
            stale: false
        )
    }
}

// MARK: - Presentation

extension StockQuote {
    var rising: Bool { changePercent >= 0 }

    /// The user's own locale decides the decimal separator, so the shipped
    /// render's "333,08" and an en_US "333.08" are the same call.
    var priceText: String { price.formatted(.number.precision(.fractionLength(2))) }

    var percentText: String {
        (changePercent / 100).formatted(
            .percent.precision(.fractionLength(2)).sign(strategy: .always(includingZero: true))
        )
    }
}

// MARK: - Library previews

extension StockQuote {
    /// Representative values for the widget library, which has no live data.
    /// These are the numbers in the reference art.
    static func preview(_ symbol: String) -> StockQuote {
        let key = StockService.normalised(symbol)
        let known: [String: (price: Double, percent: Double, name: String)] = [
            "AAPL": (333.08, 0.24, "Apple Inc."),
            "MSFT": (505.41, 1.97, "Microsoft Corporation"),
            "NVDA": (210.96, -3.36, "NVIDIA Corporation"),
        ]
        let sample = known[key] ?? (128.40, 0.86, key)
        return StockQuote(
            symbol: key.isEmpty ? "AAPL" : key,
            name: sample.name,
            price: sample.price,
            change: sample.price * sample.percent / 100,
            changePercent: sample.percent,
            currency: "USD",
            history: sampleHistory(seed: key, rising: sample.percent >= 0),
            stale: false
        )
    }

    /// A deterministic random walk — same symbol, same squiggle every launch,
    /// so the library card does not shimmer as it redraws.
    private static func sampleHistory(seed: String, rising: Bool) -> [Double] {
        var state = seed.unicodeScalars.reduce(UInt64(0x9E37_79B9)) { $0 &* 31 &+ UInt64($1.value) }
        var value = 0.0
        return (0..<78).map { _ in
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let noise = Double((state >> 33) % 1000) / 1000 - 0.5
            value += noise * 0.9 + (rising ? 0.07 : -0.07)
            return value
        }
    }
}
