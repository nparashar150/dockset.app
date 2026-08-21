import AppKit
import SwiftUI

/// The hover label, in a window of its own.
///
/// Drawing it inside the shelf meant reserving empty space around the shelf
/// big enough to hold it — which is guesswork: it depends on the edge, and on
/// how long an app's name happens to be. Too little and long names were
/// clipped by the window edge; enough for the worst case is a large invisible
/// window. Apple's Dock uses a separate window for exactly this reason, and
/// doing the same removes the reserve, the clipping, and the constants.
@MainActor
final class TooltipWindow {
    static let shared = TooltipWindow()

    private var panel: NSPanel?
    private var hosting: NSHostingView<TooltipLabel>?
    private var current: String?
    /// Measured once per label, not once per pointer move.
    private var currentSize: NSSize = .zero
    /// Last frame actually set, so an unchanged one costs nothing.
    private var currentFrame: CGRect = .zero

    private init() {}

    /// - Parameters:
    ///   - anchor: the point on the tile the label should point away from, in
    ///     screen coordinates.
    ///   - edge: which way to place the label.
    func show(_ text: String, anchor: CGPoint, edge: DockPosition) {
        let panel = existingOrNew()
        if current != text {
            hosting?.rootView = TooltipLabel(text: text)
            current = text
            // A full SwiftUI sizing pass. It only depends on the text, so it
            // must not run on every pointer move — sweeping the row changed
            // the anchor constantly while the label stayed the same.
            currentSize = hosting?.fittingSize ?? .zero
        }

        let size = currentSize
        guard size.width > 1 else { return }

        let gap: CGFloat = 10
        let origin: CGPoint = switch edge {
        case .bottom: CGPoint(x: anchor.x - size.width / 2, y: anchor.y + gap)
        case .left: CGPoint(x: anchor.x + gap, y: anchor.y - size.height / 2)
        case .right: CGPoint(x: anchor.x - size.width - gap, y: anchor.y - size.height / 2)
        }

        let frame = CGRect(origin: clamped(origin, size: size), size: size)
        // `setFrame(display:)` forces a synchronous redraw of a second window.
        // At pointer rate that is the cost of hovering; sub-point moves cannot
        // change a pixel, so they are not worth one.
        if abs(frame.origin.x - currentFrame.origin.x) > 0.5
            || abs(frame.origin.y - currentFrame.origin.y) > 0.5
            || frame.size != currentFrame.size {
            currentFrame = frame
            panel.setFrame(frame, display: false)
        }
        if !panel.isVisible {
            // Fades up the first time it appears. Moving between tiles only
            // moves the window, which must stay cheap — see the frame guard
            // above — so there is nothing to animate on that path.
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().alphaValue = 1
            }
        }
    }

    func hide() {
        // Only when something is actually shown. `orderOut` is a synchronous
        // WindowServer round trip that parks the main thread for about 1.5ms,
        // and this is called on *every* pointer move that is not over an icon
        // — between tiles, over any widget, in the gaps. Measured at ~2s of
        // blocked main thread per 5s of movement: the shelf's whole stutter.
        guard panel?.isVisible == true else { return }
        current = nil
        currentFrame = .zero
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                // Unless a label was shown again while this was fading.
                guard let self, self.current == nil else { return }
                self.panel?.orderOut(nil)
                self.panel?.alphaValue = 1
            }
        }
    }

    /// Keeps the label on screen when a tile sits near a corner.
    private func clamped(_ origin: CGPoint, size: NSSize) -> CGPoint {
        // Cached: enumerating every screen per pointer move is pure waste, and
        // the answer only changes when the label crosses to another display.
        if let cached = screenCache, cached.frame.contains(origin) {
            return clamp(origin, size: size, to: cached)
        }
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(origin) })
            ?? NSScreen.main else { return origin }
        screenCache = screen
        return clamp(origin, size: size, to: screen)
    }

    private func clamp(_ origin: CGPoint, size: NSSize, to screen: NSScreen) -> CGPoint {
        let visible = screen.visibleFrame
        return CGPoint(
            x: min(max(origin.x, visible.minX + 4), visible.maxX - size.width - 4),
            y: min(max(origin.y, visible.minY + 4), visible.maxY - size.height - 4)
        )
    }

    private var screenCache: NSScreen?

    private func existingOrNew() -> NSPanel {
        if let panel { return panel }
        let view = NSHostingView(rootView: TooltipLabel(text: ""))
        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.contentView = view
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false                  // the capsule draws its own
        panel.level = .statusBar                 // above the shelf itself
        panel.ignoresMouseEvents = true          // never interferes with hover
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        self.panel = panel
        self.hosting = view
        return panel
    }
}

/// Matched to the Dock's own label: a capsule, ~21pt tall, 13pt text, with a
/// hairline rim and a thin material that lets the background read through.
struct TooltipLabel: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.primary)
            .fixedSize()
            .padding(.horizontal, 11)
            .frame(height: 21)
            .background {
                Capsule(style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.22), radius: 5, y: 1)
            }
            .padding(6)   // room for the shadow inside the panel
    }
}

/// Reports the `NSWindow` hosting a SwiftUI view, so shelf-relative points can
/// be converted to screen coordinates.
struct WindowReader: NSViewRepresentable {
    var onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { onResolve(view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { onResolve(view.window) }
    }
}
