import SwiftUI

/// A sparkline whose area is filled with an **ordered (Bayer) dither** rather
/// than a smooth gradient — the signature chart of the shelf.
///
/// The fill is a grid of small square dots. A dot is drawn when its cell's
/// Bayer threshold falls under the local *intensity*, which is 1 immediately
/// under the line and 0 at the baseline. Because the intensity is normalised
/// against each column's own depth, the dense band hugs the contour of the
/// line wherever it runs, and the pattern thins out toward the bottom.
///
/// Everything is authored in points at 1×; the shelf scales the finished tile.
struct DitherChart: View {
    var samples: [Double]
    var tint: Color
    var lineWidth: CGFloat = 1.5
    var dotSize: CGFloat = 1

    /// Standard 4×4 ordered dither matrix, pre-divided into 0…<1 thresholds.
    /// 4×4 (not 8×8) is what the shipped art uses: at the faintest intensity
    /// exactly one cell in four lights up per row.
    private static let bayer: [Double] = [
        0, 8, 2, 10,
        12, 4, 14, 6,
        3, 11, 1, 9,
        15, 7, 13, 5,
    ].map { $0 / 16 }

    /// NaN and infinity come out of a half-populated intraday series; they
    /// would poison min/max and blank the whole chart, so they never enter it.
    private var finite: [Double] { samples.filter(\.isFinite) }

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            guard size.width > 0, size.height > 0 else { return }
            let points = self.points(in: size)
            guard points.count >= 2 else { return }

            context.fill(dither(under: points, in: size), with: .color(tint.opacity(0.8)))

            var line = Path()
            line.addLines(points)
            context.stroke(
                line,
                with: .color(tint),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
    }

    // MARK: Geometry

    /// Baseline the dither falls to: the bottom of the frame, inset by half a
    /// stroke so a line sitting at the floor is not clipped.
    private func baseline(_ size: CGSize) -> CGFloat { size.height - lineWidth / 2 }

    private func points(in size: CGSize) -> [CGPoint] {
        let values = finite
        guard values.count >= 2, let low = values.min(), let high = values.max() else { return [] }

        let top = lineWidth / 2
        let bottom = baseline(size)
        let span = high - low

        // Headroom under the series so the dither has somewhere to live: the
        // low point sits a third of the way up rather than on the floor. An
        // all-equal series has no span at all — centre it instead of dividing
        // by zero.
        let floorValue = low - span / 2
        let scale = span > 0 ? (bottom - top) / (high - floorValue) : 0
        let step = size.width / CGFloat(values.count - 1)

        return values.enumerated().map { index, value in
            let y = span > 0
                ? top + (high - value) * scale
                : (top + bottom) / 2
            return CGPoint(x: CGFloat(index) * step, y: y)
        }
    }

    // MARK: Dither

    private func dither(under points: [CGPoint], in size: CGSize) -> Path {
        // Dots on a grid of twice their own size: the shipped art is a 1pt dot
        // every 2pt.
        let step = max(dotSize, 0.5) * 2
        let bottom = baseline(size)
        var path = Path()
        var segment = 0
        var x: CGFloat = 0
        var column = 0

        while x + dotSize <= size.width {
            while segment < points.count - 2, points[segment + 1].x < x { segment += 1 }
            let a = points[segment]
            let b = points[segment + 1]
            let t = b.x > a.x ? min(max((x - a.x) / (b.x - a.x), 0), 1) : 0
            // Start clear of the stroke so the dots read as fill, not as fuzz
            // on the line itself.
            let lineY = a.y + (b.y - a.y) * t + lineWidth / 2
            let depth = bottom - lineY

            // Rows are laid out upward from the baseline, so the fill always
            // closes on the floor of the chart instead of stopping a row short
            // wherever the grid happens to fall.
            if depth > 0 {
                var y = bottom - dotSize
                var row = 0
                while y >= lineY {
                    if Self.bayer[(row & 3) * 4 + (column & 3)] < (bottom - y) / depth {
                        path.addRect(CGRect(x: x, y: y, width: dotSize, height: dotSize))
                    }
                    y -= step
                    row += 1
                }
            }

            x += step
            column += 1
        }
        return path
    }
}
