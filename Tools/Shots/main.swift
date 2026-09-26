import AppKit
import SwiftUI

// Renders the app's real detail panels into real, on-screen windows and prints
// where each one landed, so `scripts/capture-shots.sh` can photograph the
// screen region it occupies.
//
// Why a window on a real display, rather than `ImageRenderer` or
// `cacheDisplay`: a panel's surface is `VisualEffectPlate(material: .popover,
// blending: .behindWindow)`, and behind-window vibrancy is sampled by the
// window server from what is genuinely composited behind the window. Nothing
// is behind an offscreen bitmap, so an offscreen render comes back as a
// transparent — or, once flattened, black — slab with the text floating on it.
// The material is most of what these panels look like, so the only honest
// render is one the display has actually drawn.
//
// The images are documentation, and documentation that overstates the app is
// worse than none: every panel here is the shipping view, handed either its
// own `isPreview` sample data (the same values the widget library shows) or
// live readings from this machine. Nothing is mocked up, and no number is
// typed in here to flatter a screenshot.

// MARK: - Protocol with the capture script
//
// One line per shot on stdout — `name x y width height` — then a blocking read
// of stdin, which the script answers once `screencapture` has returned. A
// handshake rather than a sleep because a fixed wait is either too short on a
// busy machine or wasted on an idle one, and a truncated capture is silent.

private func emit(_ line: String) {
    print(line)
    // stdout is a pipe here, so it is block-buffered: without this the script
    // waits for a line that is still sitting in the buffer, and the script's
    // acknowledgement never comes. Deadlock.
    fflush(stdout)
}

private func log(_ message: String) {
    FileHandle.standardError.write(Data("shots: \(message)\n".utf8))
}

/// `screencapture -R` measures from the top-left of the primary display and
/// counts downward; AppKit's screen coordinates start at that display's
/// bottom-left and count upward. Both describe the same global space, so the
/// flip is against the *primary* screen's full frame — not the visible frame,
/// which excludes the menu bar, and not the frame of whichever screen the
/// window happens to be on.
private func topLeftRect(_ rect: CGRect) -> CGRect {
    let primary = NSScreen.screens.first?.frame ?? .zero
    return CGRect(x: rect.minX, y: primary.maxY - rect.maxY,
                  width: rect.width, height: rect.height)
}

// MARK: - The shots

@MainActor
private struct Shot {
    var name: String
    var instance: WidgetInstance
    /// Sample values, as the widget library shows them, or live readings.
    var isPreview: Bool
    /// Run before the window is built, for a panel whose state lives outside
    /// its config.
    var prepare: @MainActor () async -> Void = {}
}

@MainActor
private func shots() -> [Shot] {
    [
        // Sample data. `WeatherService` would need a location, consent and a
        // network round trip; `isPreview` is the reading the library shows.
        Shot(name: "weather", instance: widget(.weather), isPreview: true),

        // Live: the zone's own rules do this arithmetic, so the strip is the
        // real overlap between here and Tokyo at the moment of capture.
        Shot(name: "world-clock",
             instance: widget(.world, ["zone": .string("Asia/Tokyo"),
                                       "city": .string("Tokyo")]),
             isPreview: false),

        // Sample data. A real read would list this machine's own accessories,
        // which is both less illustrative and more personal than it looks.
        Shot(name: "battery", instance: widget(.battery), isPreview: true),

        // Live, and genuinely running: `prepare` does exactly what pressing
        // Start does.
        Shot(name: "focus-timer", instance: widget(.timer), isPreview: false,
             prepare: startFocusSession),

        // Sample data — the same deterministic traffic the library draws.
        Shot(name: "network", instance: widget(.network), isPreview: true),

        // The music panel has no sample data at all, by design: it shows what
        // a player is actually doing or says plainly that it has nothing to
        // read. Reading a player needs Apple Events, which needs automation
        // consent this tool has not been granted, so what this captures is the
        // empty state. Honest, and labelled as such in the report.
        Shot(name: "music", instance: widget(.music), isPreview: true),

        // Live, and deliberately last: the graph is drawn from
        // `SystemMetrics`' rolling buffer, which has no `isPreview` stand-in —
        // the only way to show it is to let the sampler fill, which it has
        // been doing since launch while the other panels were captured.
        Shot(name: "system-activity",
             instance: widget(.system, ["metrics": .list([.string("cpu"),
                                                          .string("memory"),
                                                          .string("disk")])]),
             isPreview: false,
             prepare: { await waitForHistory(samples: SystemMetrics.historyLength,
                                             limit: .seconds(75)) }),
    ]
}

private func widget(_ kind: WidgetKind,
                    _ values: [String: WidgetConfig.Value] = [:]) -> WidgetInstance {
    WidgetInstance(kind: kind, config: WidgetConfig(values))
}

/// Starts a focus session the way the panel's own Start button does.
///
/// `TimerStateProvider` is in-memory and is never persisted, so this touches
/// nothing the user has saved — and the countdown in the image is a real one,
/// not a time typed in to look busy.
@MainActor
private func startFocusSession() async {
    var state = TimerState()
    let length = Double(state.work * 60)
    state.duration = length
    state.deadline = Date().addingTimeInterval(length)
    TimerStateProvider.shared.state = state
}

// MARK: - Windows

/// A plain neutral field behind the panels.
///
/// Two jobs, both honest: the vibrancy has something real to sample, so the
/// material reads as itself rather than as a flat fill; and whatever else is
/// on the capture machine's screen stays out of the images. It is deliberately
/// nobody's artwork and nobody else's app.
@MainActor
private func makeBackdrop(on screen: NSScreen) -> NSWindow {
    let window = NSWindow(contentRect: screen.frame, styleMask: .borderless,
                          backing: .buffered, defer: false)
    window.contentView = NSHostingView(
        rootView: LinearGradient(colors: [Color(nsColor: .windowBackgroundColor),
                                          Color(nsColor: .underPageBackgroundColor)],
                                 startPoint: .top, endPoint: .bottom))
    window.isOpaque = true
    window.isReleasedWhenClosed = false
    window.ignoresMouseEvents = true
    window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    // Above everything else on the display, so a terminal window cannot end up
    // inside a screenshot or underneath the material.
    window.level = .screenSaver
    window.setFrame(screen.frame, display: true)
    window.orderFrontRegardless()
    return window
}

@MainActor
private func makePanel(_ shot: Shot, on screen: NSScreen) -> NSWindow? {
    let chrome = WidgetDetailChrome(
        instance: shot.instance,
        context: WidgetContext(position: .bottom, now: .now, isPreview: shot.isPreview),
        // The tail points down, at a shelf on the bottom edge, which is where
        // the Dock is for almost everyone.
        edge: .bottom,
        session: UUID())

    let hosting = NSHostingView(rootView: chrome)
    hosting.sizingOptions = [.intrinsicContentSize]
    let size = hosting.fittingSize
    guard size.width > 1, size.height > 1 else {
        log("\(shot.name): the panel measured empty, skipping")
        return nil
    }

    // Middle of the screen, well clear of every edge, so the shadow and the
    // padding below always have room.
    let frame = CGRect(x: (screen.frame.midX - size.width / 2).rounded(),
                       y: (screen.frame.midY - size.height / 2).rounded(),
                       width: size.width, height: size.height)
    let window = NSWindow(contentRect: frame, styleMask: .borderless,
                          backing: .buffered, defer: false)
    window.contentView = hosting
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = true
    window.isReleasedWhenClosed = false
    window.ignoresMouseEvents = true
    window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
    window.setFrame(frame, display: true)
    window.orderFrontRegardless()
    return window
}

// MARK: - Run

/// Enough for SwiftUI to lay out, the entrance animation to finish, and the
/// window server to have composited the material at least once.
private let settle = Duration.milliseconds(800)

/// Room around the panel for its shadow, which is part of how it looks and is
/// cropped off by the window frame alone. Only ever fills with backdrop.
private let shadowPadding: CGFloat = 26

/// Waits for the metrics buffer to fill, so the history graph covers the full
/// minute it names rather than the handful of seconds it happened to have.
@MainActor
private func waitForHistory(samples wanted: Int, limit: Duration) async {
    let started = Date()
    while SystemMetrics.shared.cpuHistory.count < wanted {
        if Date().timeIntervalSince(started) > Double(limit.components.seconds) {
            log("history filled to \(SystemMetrics.shared.cpuHistory.count) of \(wanted) before the time limit; the panel will say so itself")
            return
        }
        log("waiting for system history: \(SystemMetrics.shared.cpuHistory.count)/\(wanted)")
        try? await Task.sleep(for: .seconds(2))
    }
}

@MainActor
private func run() async {
    // `.main` is the screen with keyboard focus, which a tool that never
    // becomes key may not have; the first screen is the primary display.
    guard let screen = NSScreen.main ?? NSScreen.screens.first else {
        log("no display attached — these shots have to be taken on a real screen")
        exit(1)
    }

    // Started first thing so the buffer is filling all through the run, and
    // the system panel — captured last — has a full minute to draw.
    SystemMetrics.shared.start()

    let backdrop = makeBackdrop(on: screen)
    // The backdrop is what the material samples, so give it a moment to be on
    // screen before the first panel is placed over it.
    try? await Task.sleep(for: settle)

    for shot in shots() {
        await shot.prepare()
        guard let window = makePanel(shot, on: screen) else { continue }
        try? await Task.sleep(for: settle)

        let region = window.frame
            .insetBy(dx: -shadowPadding, dy: -shadowPadding)
            .intersection(screen.frame)
        let rect = topLeftRect(region)
        emit("\(shot.name) \(Int(rect.minX)) \(Int(rect.minY)) \(Int(rect.width)) \(Int(rect.height))")

        // Blocks the main thread until the script says the capture is done.
        // Safe to block: the window is already on screen and the window server
        // composites it without this process doing anything at all.
        guard readLine() != nil else {
            log("the capture script closed the pipe; stopping")
            window.orderOut(nil)
            break
        }
        window.orderOut(nil)
    }

    backdrop.orderOut(nil)
    log("done")
    exit(0)
}

let app = NSApplication.shared
// No Dock tile and no menu bar for a tool that exists for about a minute.
app.setActivationPolicy(.accessory)
Task { @MainActor in await run() }
app.run()
