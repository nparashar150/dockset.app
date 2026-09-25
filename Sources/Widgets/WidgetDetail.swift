import AppKit
import SwiftUI

/// A widget's detail panel: what opens when its tile is clicked.
///
/// This is the shape the reference shelf takes and the one thing the tiles
/// were missing. A tile is a glance — a temperature, a percentage, a title —
/// and the panel is where the same widget says everything it knows: the whole
/// day's events rather than the next one, every battery rather than the Mac's,
/// a chart behind the number.
///
/// Its own window for the same reason the hover label and an opened group have
/// theirs: drawing it inside the shelf would mean reserving space for the
/// largest panel any widget might want.
@MainActor
final class WidgetDetailWindow {
    static let shared = WidgetDetailWindow()

    /// Which widget is showing, so clicking its tile again closes it.
    private(set) var openWidgetID: UUID?

    private var panel: KeyablePanel?
    private var hosting: FirstMouseHostingView<WidgetDetailChrome>?
    /// Watches for the click that dismisses it — one monitor for clicks
    /// landing in another app, one for clicks landing in this one.
    private var monitors: [Any] = []
    /// The shelf's own frame, which the dismissal watcher ignores.
    ///
    /// The shelf already decides what a click on it means — the same tile
    /// toggles this shut, another widget swaps it, an app tile closes it. A
    /// monitor closing it first would let the tile's own tap reopen it on the
    /// very same press.
    private var host: CGRect = .zero
    /// Changes on every open, to replay the entrance.
    private var session = UUID()
    /// What the open panel was shown with, so a config change underneath it
    /// can be redrawn without reopening it.
    private var shown: (context: WidgetContext, edge: DockPosition)?

    private init() {}

    var isOpen: Bool { openWidgetID != nil && panel?.isVisible == true }

    func toggle(_ instance: WidgetInstance, context: WidgetContext,
                anchor: CGPoint, edge: DockPosition, host: CGRect) {
        if openWidgetID == instance.id { return close() }
        show(instance, context: context, anchor: anchor, edge: edge, host: host)
    }

    /// Redraws the open panel after its widget's config changed.
    ///
    /// The panel is handed a `WidgetInstance` by value, so a tile that edits
    /// its own config — the stocks chevron stepping to the next symbol, a
    /// setting changed while the panel is up — left the two disagreeing until
    /// it was closed and reopened. Every widget write funnels through
    /// `WidgetWriter`, which is where this is called from.
    ///
    /// Deliberately keeps `session`, so the entrance does not replay, and the
    /// frame, so the panel does not jump: the width is fixed per kind, and a
    /// config change that made the panel *taller* would keep the old height
    /// until reopened.
    func refresh(_ instance: WidgetInstance) {
        guard openWidgetID == instance.id, let shown else { return }
        hosting?.rootView = WidgetDetailChrome(
            instance: instance, context: shown.context, edge: shown.edge,
            session: session)
    }

    /// Closes on the next click outside the panel and its own tile.
    ///
    /// The panel used to close when the *pointer* left it, on a half-second
    /// timer — which is why it needed a close button: a panel that vanishes
    /// because you looked away is one you cannot trust to stay. Nothing on
    /// this platform behaves that way. A popover waits for a click.
    private func watchForDismissal() {
        stopWatching()
        let dismiss: (NSEvent) -> Void = { [weak self] event in
            guard let self, let panel = self.panel else { return }
            // A local event reports a window-relative location; a global one
            // is already on screen.
            let point = event.window?.convertPoint(toScreen: event.locationInWindow)
                ?? NSEvent.mouseLocation
            guard !panel.frame.contains(point),
                  !self.host.contains(point) else { return }
            self.close()
        }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: dismiss) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
            dismiss(event)
            return event
        }) { monitors.append(local) }
    }

    private func stopWatching() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    func close() {
        guard openWidgetID != nil else { return }
        openWidgetID = nil
        shown = nil
        stopWatching()
        guard panel?.isVisible == true else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.openWidgetID == nil else { return }
                self.panel?.orderOut(nil)
                self.panel?.alphaValue = 1
            }
        }
    }

    private func show(_ instance: WidgetInstance, context: WidgetContext,
                      anchor: CGPoint, edge: DockPosition, host: CGRect) {
        let panel = existingOrNew()
        session = UUID()
        shown = (context, edge)
        self.host = host
        hosting?.rootView = WidgetDetailChrome(
            instance: instance, context: context, edge: edge, session: session)

        let size = hosting?.fittingSize ?? .zero
        // Claimed only once there is something to show. Setting it above the
        // guard meant a bail here left the widget marked open with no window,
        // and `toggle` would then answer every later click by closing a panel
        // that was never up.
        guard size.width > 1, size.height > 1 else { return }
        openWidgetID = instance.id

        // Grows away from the shelf, clear of the tile it came from.
        let gap: CGFloat = 12
        let origin: CGPoint = switch edge {
        case .bottom: CGPoint(x: anchor.x - size.width / 2, y: anchor.y + gap)
        case .left: CGPoint(x: anchor.x + gap, y: anchor.y - size.height / 2)
        case .right: CGPoint(x: anchor.x - size.width - gap, y: anchor.y - size.height / 2)
        }

        panel.setFrame(CGRect(origin: clamped(origin, size: size), size: size), display: false)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        // A panel carrying a text field or a slider needs the keyboard, and a
        // borderless window is refused key status without the override.
        panel.makeKey()
        watchForDismissal()
    }

    private func clamped(_ origin: CGPoint, size: NSSize) -> CGPoint {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(origin) })
                ?? NSScreen.main else { return origin }
        let visible = screen.visibleFrame
        return CGPoint(
            x: min(max(origin.x, visible.minX + 8), max(visible.minX, visible.maxX - size.width - 8)),
            y: min(max(origin.y, visible.minY + 8), max(visible.minY, visible.maxY - size.height - 8))
        )
    }

    private func existingOrNew() -> NSPanel {
        if let panel { return panel }
        let hosting = FirstMouseHostingView(
            rootView: WidgetDetailChrome(instance: WidgetInstance(kind: .clock,
                                                                  config: WidgetConfig()),
                                         context: WidgetContext(),
                                         edge: .bottom, session: session))
        hosting.sizingOptions = [.intrinsicContentSize]

        let panel = KeyablePanel(contentRect: .zero,
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
        panel.onCancel = { [weak self] in self?.close() }
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary,
                                    .fullScreenAuxiliary, .ignoresCycle]
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 2)

        self.panel = panel
        self.hosting = hosting
        return panel
    }
}

/// The chrome every detail panel wears: its name, quietly, and a tint
/// borrowed from the widget itself.
///
/// Deliberately thin. Everything a header row used to carry has somewhere
/// better to be — dismissal is a click outside, Escape or Command-W, and
/// per-widget settings are in the tile's context menu.
struct WidgetDetailChrome: View {
    var instance: WidgetInstance
    var context: WidgetContext
    var edge: DockPosition
    /// Identifies one opening, so the entrance replays each time.
    var session: UUID

    @Environment(\.colorScheme) private var scheme
    @State private var appeared = false

    private var name: String {
        WidgetCatalog.entry(instance.kind)?.name ?? instance.kind.rawValue
    }

    /// nil for the readouts that are not "about" a colour — see the catalog.
    private var accent: Color? {
        WidgetCatalog.accentHex(instance.kind).map { Color(hex: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            WidgetDetailBody(instance: instance, context: context)
        }
        .padding(16)
        .frame(width: WidgetDetail.width(instance.kind), alignment: .leading)
        .background(surface)
        .fixedSize()
        // Rises a little and fades in. It used to scale up out of the tile,
        // which is an iOS sheet's entrance; a panel on this platform arrives
        // more or less where it means to stay.
        .offset(x: rise.width, y: rise.height)
        .opacity(appeared ? 1 : 0)
        .onAppear { enter() }
        .onChange(of: session) { _, _ in
            appeared = false
            Task { @MainActor in enter() }
        }
    }

    /// Opaque, not glass.
    ///
    /// The panel was `.regularMaterial` with the widget's accent flooded over
    /// the whole surface. Two problems: a vibrant panel this size samples
    /// whatever is behind it, so it reads as a different colour over every
    /// window, and a flat wash of brand colour across an entire surface is a
    /// web card, not a Mac window. An opaque window background with the accent
    /// only in the corner keeps the widget's identity without staining it.
    private var surface: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(nsColor: .windowBackgroundColor))
            .overlay {
                if let accent {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(
                            colors: [accent.opacity(scheme == .dark ? 0.22 : 0.16), .clear],
                            startPoint: .topLeading, endPoint: .center))
                }
            }
            .overlay {
                // A hairline, not a highlight: `.white` at a third was
                // visible as a drawn outline rather than an edge.
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.primary.opacity(scheme == .dark ? 0.14 : 0.10),
                                  lineWidth: 0.5)
            }
    }

    /// Three points, away from the shelf, so it settles toward the tile.
    private var rise: CGSize {
        guard !appeared else { return .zero }
        return switch edge {
        case .bottom: CGSize(width: 0, height: 3)
        case .left: CGSize(width: -3, height: 0)
        case .right: CGSize(width: 3, height: 0)
        }
    }

    /// Just the name, quietly.
    ///
    /// No close button: the panel goes away on a click outside it, on Escape
    /// and on Command-W, which is what every transient window on this platform
    /// does. A button to shut it is what you add when you do not trust that,
    /// and it is the first thing that makes a panel read as a web dialog.
    ///
    /// No settings button either — per-widget settings live in the tile's own
    /// context menu, the way Notification Center keeps "Edit Widget" there
    /// rather than in a header.
    private var header: some View {
        Text(name)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func enter() {
        withAnimation(.easeOut(duration: 0.14)) { appeared = true }
    }
}

/// How wide each kind's panel is.
///
/// Per kind rather than one width for all: a battery panel is a list of four
/// rows, a revenue panel carries a chart, and a sticky note is a square of
/// paper. Forcing them to a common width leaves most of them padded out.
enum WidgetDetail {
    /// Whether this kind has more to say than its tile already shows.
    ///
    /// Kinds without a panel keep opening their app instead. A panel that
    /// only restates the tile, or apologises for having nothing, is worse
    /// than the app the widget is about.
    static func exists(for kind: WidgetKind) -> Bool {
        switch kind {
        case .music, .timer, .calendar, .battery, .system,
             .notes, .stripe, .paddle, .shopify, .stock, .watchlist, .weather:
            true
        default:
            false
        }
    }

    static func width(_ kind: WidgetKind) -> CGFloat {
        switch kind {
        case .stripe, .paddle, .shopify: 340
        case .calendar, .reminders: 320
        case .battery: 330
        case .notes: 300
        case .system, .network: 340
        // Wide enough for the whole hourly series as a strip; the tile fits
        // five of those hours and the service publishes twelve.
        case .weather: 340
        case .music: 330
        default: 300
        }
    }
}
