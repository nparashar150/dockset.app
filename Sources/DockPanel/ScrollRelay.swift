import AppKit
import SwiftUI
import Observation

/// Carries scroll-wheel deltas from the shelf's panel into its SwiftUI view.
///
/// The panel is the right place to catch them: a view overlaid to receive
/// scrolls must also accept hits, and one that did swallowed every click on
/// the shelf. Unhandled scroll events bubble up the responder chain to the
/// window, so the panel sees them without taking anything away from the tiles.
@MainActor
@Observable
final class ScrollRelay {
    static let shared = ScrollRelay()

    /// Most recent delta along the shelf's long axis.
    private(set) var delta: CGFloat = 0
    /// Bumped per event, so identical deltas still register as a change.
    private(set) var tick: Int = 0

    private init() {}

    func push(_ value: CGFloat) {
        delta = value
        tick &+= 1
    }

    /// Points to move the shelf for one scroll event.
    ///
    /// Whichever axis the gesture favours drives the shelf, on either
    /// orientation: a mouse wheel only ever reports Y, and a two-finger swipe
    /// across a side shelf is as natural as one along it.
    ///
    /// A trackpad reports precise deltas already in points, so those map
    /// straight through. A mouse wheel reports *notches* — passing a delta of
    /// 1 through unscaled would creep the shelf one point per click.
    nonisolated static func step(dx: CGFloat, dy: CGFloat, precise: Bool) -> CGFloat {
        let delta = abs(dx) > abs(dy) ? dx : dy
        return precise ? delta : delta * 16
    }
}

/// Hosting view that handles the scroll wheel itself.
///
/// Event monitors are the wrong tool here, and the panel is too far up. A
/// *local* monitor only sees events routed to this app, and a non-activating
/// panel belonging to an accessory agent is often not the event target — macOS
/// hands the scroll to whatever is underneath, so it never fires. A *global*
/// monitor always sees it but needs Accessibility permission and cannot
/// consume, so the window behind scrolls too. Overriding the panel does
/// nothing either, because `NSHostingView` swallows the event before it can
/// walk up the responder chain.
///
/// Handling it on the hosting view itself is the one place it reliably
/// arrives, and not calling `super` consumes it so nothing behind moves.
final class ScrollingHostingView<Content: View>: NSHostingView<Content> {

    override func scrollWheel(with event: NSEvent) {
        let step = ScrollRelay.step(dx: event.scrollingDeltaX,
                                    dy: event.scrollingDeltaY,
                                    precise: event.hasPreciseScrollingDeltas)
        guard step != 0 else {
            super.scrollWheel(with: event)
            return
        }
        ScrollRelay.shared.push(step)
    }

    /// Keeps the panel the size SwiftUI wants.
    ///
    /// `NSHostingController` does this for you; using the view directly does
    /// not, and skipping it collapsed the shelf window to zero.
    /// Reports the size SwiftUI wants; the panel's owner decides where that
    /// size sits. Setting it here kept the old origin, so the shelf grew out
    /// of a corner and was re-centred a step later.
    var onWantedSize: ((CGSize) -> Void)?

    override func layout() {
        super.layout()
        let wanted = fittingSize
        guard let window, wanted.width > 1, wanted.height > 1 else { return }
        let current = window.frame.size
        guard abs(current.width - wanted.width) > 0.5
                || abs(current.height - wanted.height) > 0.5 else { return }
        onWantedSize?(wanted)
    }
}
