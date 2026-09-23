import AppKit
import SwiftUI
import XCTest

/// Tests that deliver real `NSEvent`s to a window.
///
/// The shelf's worst defects were all "a click or a keystroke never arrived",
/// and none of them were visible in the layout maths: an empty content shape
/// removed every widget's controls from hit testing, a borderless panel could
/// not take a keystroke, and a non-key window swallowed the first press. None
/// of it could be caught by asserting on values.
///
/// Synthetic input through the OS is blocked for this process, but an
/// `NSEvent` sent straight to a window reaches SwiftUI's gesture recognisers
/// and AppKit's responders — which is what makes these testable at all.
@MainActor
final class InteractionTests: XCTestCase {

    // MARK: Harness

    /// Hosts `view` in a panel, runs `body`, and tears the window down.
    private func inPanel<V: View>(_ view: V,
                                  size: CGSize = CGSize(width: 200, height: 120),
                                  keyable: Bool = false,
                                  firstMouse: Bool = false,
                                  _ body: (NSPanel) -> Void) {
        let frame = NSRect(origin: .zero, size: size)
        let panel: NSPanel = keyable
            ? KeyablePanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                           backing: .buffered, defer: false)
            : NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                      backing: .buffered, defer: false)
        let hosting: NSView = firstMouse
            ? FirstMouseHostingView(rootView: view)
            : NSHostingView(rootView: view)
        hosting.frame = frame
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.orderFrontRegardless()
        hosting.layoutSubtreeIfNeeded()
        settle(0.3)
        body(panel)
        panel.orderOut(nil)
    }

    private func settle(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private func send(_ type: NSEvent.EventType, at point: NSPoint, to panel: NSPanel) {
        guard let event = NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: panel.windowNumber, context: nil,
            eventNumber: 0, clickCount: 1, pressure: 1) else { return }
        panel.sendEvent(event)
        settle(0.1)
    }

    private func click(at point: NSPoint, in panel: NSPanel) {
        send(.leftMouseDown, at: point, to: panel)
        send(.leftMouseUp, at: point, to: panel)
        settle(0.2)
    }

    private func drag(from start: NSPoint, to end: NSPoint, in panel: NSPanel) {
        send(.leftMouseDown, at: start, to: panel)
        for step in 1...10 {
            let t = CGFloat(step) / 10
            send(.leftMouseDragged,
                 at: NSPoint(x: start.x + (end.x - start.x) * t,
                             y: start.y + (end.y - start.y) * t),
                 to: panel)
        }
        send(.leftMouseUp, at: end, to: panel)
        settle(0.2)
    }

    // MARK: Hit testing

    /// A counter a test view can bump from a gesture.
    private final class Tally {
        var inner = 0
        var outer = 0
    }

    private struct NestedTargets: View {
        let tally: Tally
        var filled: Bool
        var body: some View {
            ZStack {
                Color.gray
                Color.blue.frame(width: 40, height: 40)
                    .contentShape(.rect)
                    .onTapGesture { tally.inner += 1 }
            }
            .frame(width: 200, height: 120)
            .modifier(TileHitShape(filled: filled))
            .onTapGesture { tally.outer += 1 }
        }
    }

    /// A widget's own controls must receive their own clicks.
    ///
    /// The shelf gave widget tiles an *empty* content shape, on the theory
    /// that it cleared only the tile's hit region and left descendants
    /// hittable. It does not: an empty content shape takes the whole subtree
    /// out of hit testing, so every control inside every widget was dead.
    func testAnInteriorControlReceivesItsOwnClick() {
        let tally = Tally()
        inPanel(NestedTargets(tally: tally, filled: false)) { panel in
            click(at: NSPoint(x: 100, y: 60), in: panel)
        }
        XCTAssertEqual(tally.inner, 1)
    }

    /// And a tile that wants its whole area clickable still gets it.
    func testAFilledHitShapeStillReceivesClicks() {
        let tally = Tally()
        inPanel(NestedTargets(tally: tally, filled: true)) { panel in
            click(at: NSPoint(x: 100, y: 60), in: panel)
        }
        XCTAssertEqual(tally.inner, 1)
    }

    /// The interior wins over the tile's own action, which is what lets a
    /// widget carry both a control and a whole-card tap.
    func testTheInteriorWinsOverTheCardsOwnAction() {
        let tally = Tally()
        inPanel(NestedTargets(tally: tally, filled: false)) { panel in
            click(at: NSPoint(x: 100, y: 60), in: panel)
        }
        XCTAssertEqual(tally.inner, 1)
        XCTAssertEqual(tally.outer, 0, "the card must not also fire")
    }

    /// Away from the control, the card's own action is what runs — a widget
    /// with somewhere to go opens it, rather than swallowing the click.
    func testTheCardActsWhenClickedAwayFromItsControls() {
        let tally = Tally()
        inPanel(NestedTargets(tally: tally, filled: false)) { panel in
            click(at: NSPoint(x: 20, y: 60), in: panel)
        }
        XCTAssertEqual(tally.inner, 0)
        XCTAssertEqual(tally.outer, 1)
    }

    // MARK: Key status

    /// Keystrokes only reach the key window, so a panel that can never be key
    /// shows a caret that accepts nothing. That is what stopped a group from
    /// being renamed in place.
    func testABorderlessPanelCannotBecomeKey() {
        inPanel(Color.clear, keyable: false) { panel in
            panel.makeKey()
            XCTAssertFalse(panel.isKeyWindow)
        }
    }

    func testAKeyablePanelBecomesKey() {
        inPanel(Color.clear, keyable: true) { panel in
            panel.makeKey()
            XCTAssertTrue(panel.isKeyWindow)
        }
    }

    /// The first click into a window that is not key is consumed as the click
    /// that focuses it. Without this the opening press of every drag out of a
    /// group was swallowed.
    func testTheHostingViewTakesTheFirstMouse() {
        inPanel(Color.clear, firstMouse: true) { panel in
            XCTAssertEqual(panel.contentView?.acceptsFirstMouse(for: nil), true)
        }
    }

    func testAPlainHostingViewRefusesTheFirstMouse() {
        inPanel(Color.clear, firstMouse: false) { panel in
            XCTAssertEqual(panel.contentView?.acceptsFirstMouse(for: nil), false)
        }
    }

    // MARK: Dragging out of a group

    private struct DragOutTarget: View {
        let tally: Tally
        var sheet: CGSize
        @State private var offset: CGSize = .zero
        var body: some View {
            ZStack {
                Color.gray
                Color.blue.frame(width: 40, height: 40)
                    .offset(offset)
                    .contentShape(.rect)
                    .gesture(
                        DragGesture(minimumDistance: 8, coordinateSpace: .named("sheet"))
                            .onChanged { offset = $0.translation }
                            .onEnded { value in
                                if GroupDrag.leavesSheet(value.location, sheet: sheet) {
                                    tally.outer += 1
                                } else {
                                    tally.inner += 1
                                }
                                offset = .zero
                            })
            }
            .frame(width: sheet.width, height: sheet.height)
            .coordinateSpace(name: "sheet")
        }
    }

    /// Dragging an icon past the sheet's edge takes it out of the group.
    func testDraggingPastTheSheetEdgeLeavesTheGroupForReal() {
        let tally = Tally()
        let sheet = CGSize(width: 200, height: 120)
        inPanel(DragOutTarget(tally: tally, sheet: sheet), size: sheet, firstMouse: true) { panel in
            drag(from: NSPoint(x: 100, y: 60), to: NSPoint(x: 100, y: 300), in: panel)
        }
        XCTAssertEqual(tally.outer, 1, "released outside, so it should leave")
        XCTAssertEqual(tally.inner, 0)
    }

    /// Nudging it within the sheet changes nothing, so it springs home.
    func testDraggingWithinTheSheetKeepsTheIconForReal() {
        let tally = Tally()
        let sheet = CGSize(width: 200, height: 120)
        inPanel(DragOutTarget(tally: tally, sheet: sheet), size: sheet, firstMouse: true) { panel in
            drag(from: NSPoint(x: 100, y: 60), to: NSPoint(x: 130, y: 70), in: panel)
        }
        XCTAssertEqual(tally.inner, 1, "released inside, so it should return")
        XCTAssertEqual(tally.outer, 0)
    }
}
