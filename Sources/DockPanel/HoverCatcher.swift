import SwiftUI
import AppKit

/// Reports the pointer position over the shelf.
///
/// SwiftUI's `.onHover` / `.onContinuousHover` install tracking areas scoped to
/// the active app. Plinth is an accessory agent that is never active, and its
/// shelf lives in a non-activating panel — so those callbacks simply never
/// fire here. An `.activeAlways` tracking area of our own is the only thing
/// that reports hover in this situation, and without hover there is no
/// magnification and no tooltips.
struct HoverCatcher: NSViewRepresentable {
    /// Pointer in the catcher's own coordinates (top-left origin, matching
    /// SwiftUI), or nil once it leaves.
    var onMove: (CGPoint?) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onMove = onMove
        return view
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.onMove = onMove
    }

    final class CatcherView: NSView {
        var onMove: ((CGPoint?) -> Void)?

        /// Invisible to clicks: tiles underneath must still get taps and drags.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            for area in trackingAreas { removeTrackingArea(area) }
            addTrackingArea(NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                owner: self
            ))
        }

        private var lastReported: CGPoint?

        private func report(_ event: NSEvent) {
            let local = convert(event.locationInWindow, from: nil)
            // AppKit views here are not flipped; SwiftUI measures from the top.
            let point = CGPoint(x: local.x, y: bounds.height - local.y)
            // Magnification is a raised cosine over a ~110pt radius, so a
            // sub-point move cannot change a single pixel — but it did rebuild
            // every tile in the shelf, because the pointer is view state.
            if let last = lastReported,
               abs(last.x - point.x) < 1, abs(last.y - point.y) < 1 { return }
            lastReported = point
            onMove?(point)
        }

        override func mouseMoved(with event: NSEvent) { report(event) }
        override func mouseEntered(with event: NSEvent) { report(event) }
        override func mouseDragged(with event: NSEvent) { report(event) }
        override func mouseExited(with event: NSEvent) {
            lastReported = nil
            onMove?(nil)
        }
    }
}
