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

    private var panel: NSPanel?
    private var hosting: FirstMouseHostingView<WidgetDetailChrome>?
    /// Changes on every open, to replay the entrance.
    private var session = UUID()
    /// What the open panel was shown with, so a config change underneath it
    /// can be redrawn without reopening it.
    private var shown: (context: WidgetContext, edge: DockPosition,
                        settings: () -> Void)?

    private init() {}

    var isOpen: Bool { openWidgetID != nil && panel?.isVisible == true }

    /// The panel's area in screen coordinates, with slack for the gap between
    /// it and the tile it grew from.
    func contains(_ point: CGPoint) -> Bool {
        guard isOpen, let panel else { return false }
        return panel.frame.insetBy(dx: -14, dy: -14).contains(point)
    }

    func toggle(_ instance: WidgetInstance, context: WidgetContext,
                anchor: CGPoint, edge: DockPosition,
                openSettings: @escaping () -> Void) {
        if openWidgetID == instance.id { return close() }
        show(instance, context: context, anchor: anchor, edge: edge,
             openSettings: openSettings)
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
            session: session, settings: shown.settings,
            dismiss: { [weak self] in self?.close() })
    }

    func close() {
        guard openWidgetID != nil else { return }
        openWidgetID = nil
        shown = nil
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
                      anchor: CGPoint, edge: DockPosition,
                      openSettings: @escaping () -> Void) {
        let panel = existingOrNew()
        session = UUID()
        shown = (context, edge, openSettings)
        hosting?.rootView = WidgetDetailChrome(
            instance: instance, context: context, edge: edge, session: session,
            settings: openSettings,
            dismiss: { [weak self] in self?.close() })

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
                                         edge: .bottom, session: session,
                                         settings: {}, dismiss: {}))
        hosting.sizingOptions = [.intrinsicContentSize]

        let panel = KeyablePanel(contentRect: .zero,
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
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

/// The chrome every detail panel wears: its name, a settings button, a close
/// button, and a tint borrowed from the widget itself.
struct WidgetDetailChrome: View {
    var instance: WidgetInstance
    var context: WidgetContext
    var edge: DockPosition
    /// Identifies one opening, so the entrance replays each time.
    var session: UUID
    var settings: () -> Void
    var dismiss: () -> Void

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
        .padding(18)
        .frame(width: WidgetDetail.width(instance.kind), alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    // The widget's own colour, laid over the material rather
                    // than replacing it, so the panel still reads as glass.
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(accent?.opacity(scheme == .dark ? 0.16 : 0.12) ?? .clear)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(scheme == .dark ? 0.12 : 0.35),
                                      lineWidth: 1)
                }
        }
        .fixedSize()
        // Scales out of the tile rather than appearing at full size in place.
        .scaleEffect(appeared ? 1 : 0.9, anchor: growthAnchor)
        .opacity(appeared ? 1 : 0)
        .onAppear { enter() }
        .onChange(of: session) { _, _ in
            appeared = false
            Task { @MainActor in enter() }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            chromeButton("slider.horizontal.3", "Widget settings", action: settings)
            chromeButton("xmark", "Close", action: dismiss)
        }
    }

    private func chromeButton(_ symbol: String, _ label: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var growthAnchor: UnitPoint {
        switch edge {
        case .bottom: .bottom
        case .left: .leading
        case .right: .trailing
        }
    }

    private func enter() {
        withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) { appeared = true }
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
