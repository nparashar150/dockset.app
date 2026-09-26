import CoreGraphics
import XCTest


/// `GroupDrag` is the whole of "an icon was pulled out of this group": a
/// bounds test in the sheet's own coordinate space, and the offset that keeps
/// the dragged icon under the pointer while that test is being made.
///
/// Both halves shipped broken once. `leavesSheet` treated an unmeasured sheet
/// as "the pointer is outside it", which ejected the icon on the first drag
/// event; `offset` displaced the icon by the drag's translation, so it kept
/// whatever gap the cursor had from its centre when the press landed.
final class GroupDragTests: XCTestCase {

    /// A measured sheet: three icons wide, one row tall.
    private let liveSheet = CGSize(width: 300, height: 120)

    private func leaves(_ x: CGFloat, _ y: CGFloat, _ sheet: CGSize? = nil) -> Bool {
        GroupDrag.leavesSheet(CGPoint(x: x, y: y), sheet: sheet ?? liveSheet)
    }

    // MARK: leavesSheet - the four edges

    func testDraggingPastTheLeadingEdgeLeavesTheSheet() {
        XCTAssertTrue(leaves(-0.5, 60))
        XCTAssertTrue(leaves(-40, 60))
        XCTAssertFalse(leaves(0.5, 60), "just inside the leading edge is still in the group")
    }

    func testDraggingPastTheTrailingEdgeLeavesTheSheet() {
        XCTAssertTrue(leaves(300.5, 60))
        XCTAssertTrue(leaves(900, 60))
        XCTAssertFalse(leaves(299.5, 60), "just inside the trailing edge is still in the group")
    }

    /// The sheet's space grows downwards, so a pointer dragged up out of the
    /// top of the sheet has a *negative* y. Testing only the far edges is how
    /// a version of this shipped that could drop an icon downwards but not
    /// upwards out of a bottom-shelf group.
    func testDraggingPastTheTopEdgeLeavesTheSheet() {
        XCTAssertTrue(leaves(150, -0.5))
        XCTAssertTrue(leaves(150, -400))
        XCTAssertFalse(leaves(150, 0.5))
    }

    func testDraggingPastTheBottomEdgeLeavesTheSheet() {
        XCTAssertTrue(leaves(150, 120.5))
        XCTAssertTrue(leaves(150, 400))
        XCTAssertFalse(leaves(150, 119.5))
    }

    // MARK: leavesSheet - the four corners

    func testEveryCornerJustOutsideTheSheetLeaves() {
        // Both axes out at once must not cancel each other out.
        XCTAssertTrue(leaves(-0.5, -0.5), "top-leading")
        XCTAssertTrue(leaves(300.5, -0.5), "top-trailing")
        XCTAssertTrue(leaves(-0.5, 120.5), "bottom-leading")
        XCTAssertTrue(leaves(300.5, 120.5), "bottom-trailing")
    }

    /// The corner icons are the ones a drag starts from most often, and they
    /// sit exactly on two boundaries at once. If either boundary resolved
    /// outwards, the icons in the corners of a group could not be dragged at
    /// all - the first event of the gesture would eject them.
    func testEveryCornerExactlyOnTheSheetStays() {
        XCTAssertFalse(leaves(0, 0), "top-leading")
        XCTAssertFalse(leaves(300, 0), "top-trailing")
        XCTAssertFalse(leaves(0, 120), "bottom-leading")
        XCTAssertFalse(leaves(300, 120), "bottom-trailing")
    }

    // MARK: leavesSheet - the boundary itself

    /// The sheet's own outline belongs to the sheet: the bounds are a closed
    /// rectangle, so a pointer *on* an edge keeps the icon in the group.
    ///
    /// That is the safe direction, and deliberately so. Ejecting is the
    /// destructive, animated, hard-to-undo outcome - the group may dissolve
    /// behind it - while staying costs the user another half-millimetre of
    /// travel. An exclusive boundary would also make a drag that merely
    /// grazes the edge, which is most drags along the sheet's rim, fire the
    /// eject at the moment the pointer is least deliberate.
    func testTheSheetOutlineItselfCountsAsInside() {
        for x in stride(from: CGFloat(0), through: 300, by: 25) {
            XCTAssertFalse(leaves(x, 0), "top edge at x=\(x)")
            XCTAssertFalse(leaves(x, 120), "bottom edge at x=\(x)")
        }
        for y in stride(from: CGFloat(0), through: 120, by: 20) {
            XCTAssertFalse(leaves(0, y), "leading edge at y=\(y)")
            XCTAssertFalse(leaves(300, y), "trailing edge at y=\(y)")
        }
    }

    /// The closed boundary must be closed at exactly the edge and nowhere
    /// beyond it: one representable step past the rim already counts as out,
    /// so the inclusive comparison cannot be read as a tolerance band.
    func testTheSmallestRepresentableStepPastAnEdgeLeaves() {
        XCTAssertTrue(leaves(CGFloat(300).nextUp, 60))
        XCTAssertTrue(leaves(150, CGFloat(120).nextUp))
        XCTAssertTrue(leaves(CGFloat(0).nextDown, 60))
        XCTAssertTrue(leaves(150, CGFloat(0).nextDown))
    }

    /// Geometry arithmetic produces signed zeroes freely, and `-0.0` is the
    /// pointer sitting precisely on the leading edge - not a hair outside it.
    /// It must resolve the same way `0.0` does, or which side of the boundary
    /// an edge-hugging drag lands on would depend on how the coordinate was
    /// computed rather than where the pointer is.
    func testANegativeZeroCoordinateIsInside() {
        XCTAssertFalse(leaves(-0.0, 60))
        XCTAssertFalse(leaves(150, -0.0))
        XCTAssertFalse(leaves(-0.0, -0.0))
    }

    // MARK: leavesSheet - inside a live sheet

    /// The gesture has to be *possible*: for a while it was not, and an icon
    /// could not be repositioned inside its own group because every sampled
    /// point read as outside. Any point the sheet actually covers must keep
    /// the icon, so a drag that never leaves the sheet never ejects.
    func testEveryPointTheSheetCoversKeepsTheIcon() {
        for x in stride(from: CGFloat(0), through: 300, by: 7.5) {
            for y in stride(from: CGFloat(0), through: 120, by: 6) {
                XCTAssertFalse(leaves(x, y), "(\(x), \(y)) was reported outside its own sheet")
            }
        }
    }

    /// The region that keeps the icon is convex, which is what makes a drag
    /// feel continuous: sweeping the pointer in a straight line between two
    /// points inside the sheet cannot dip outside and back, so the icon
    /// cannot flicker into and out of its "leaving" state mid-gesture.
    func testTheKeepRegionIsConvexSoAStraightDragCannotFlicker() {
        let inside = [CGPoint(x: 0, y: 0), CGPoint(x: 300, y: 0), CGPoint(x: 0, y: 120),
                      CGPoint(x: 300, y: 120), CGPoint(x: 150, y: 60), CGPoint(x: 12, y: 108)]
        for a in inside {
            for b in inside {
                for step in 0...20 {
                    let t = CGFloat(step) / 20
                    let point = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                    XCTAssertFalse(GroupDrag.leavesSheet(point, sheet: liveSheet),
                                   "\(point) between \(a) and \(b) left the sheet")
                }
            }
        }
    }

    /// Dragging straight out of the sheet must cross the boundary once and
    /// stay crossed. A test that flipped back - a stale or half-applied sheet
    /// size, say - would cancel the eject animation mid-flight and leave the
    /// icon translucent and still in the group.
    func testARayOutOfTheSheetCrossesTheBoundaryExactlyOnce() {
        let centre = CGPoint(x: 150, y: 60)
        let targets = [CGPoint(x: -200, y: 60), CGPoint(x: 500, y: 60),
                       CGPoint(x: 150, y: -200), CGPoint(x: 150, y: 320),
                       CGPoint(x: -200, y: -200), CGPoint(x: 500, y: -200),
                       CGPoint(x: -200, y: 320), CGPoint(x: 500, y: 320)]
        for target in targets {
            var flips = 0
            var previous = false
            for step in 0...400 {
                let t = CGFloat(step) / 400
                let point = CGPoint(x: centre.x + (target.x - centre.x) * t,
                                    y: centre.y + (target.y - centre.y) * t)
                let out = GroupDrag.leavesSheet(point, sheet: liveSheet)
                if out != previous { flips += 1 }
                previous = out
            }
            XCTAssertEqual(flips, 1, "ray to \(target) changed its mind \(flips) times")
            XCTAssertTrue(previous, "ray to \(target) never left the sheet")
        }
    }

    // MARK: leavesSheet - sheets that have not been measured

    /// The regression this guard exists for: the sheet's size arrives from a
    /// `GeometryReader`, so it is zero for the first frames and for the whole
    /// gesture if the reader never reports. A zero rectangle contains nothing,
    /// so every pointer position read as outside and the icon was thrown out
    /// of the group by the first drag event - before the user had moved far
    /// enough to mean it.
    func testAnUnmeasuredSheetKeepsEveryIcon() {
        for x in [CGFloat(-500), -1, 0, 0.5, 40, 5_000] {
            for y in [CGFloat(-500), -1, 0, 0.5, 40, 5_000] {
                XCTAssertFalse(leaves(x, y, .zero), "(\(x), \(y)) ejected against a zero sheet")
            }
        }
    }

    /// Half a measurement is no measurement. A sheet laid out along one axis
    /// only is a mid-layout state, and trusting the axis that did arrive would
    /// eject on the very first drag event exactly as a fully zero sheet did.
    func testASheetMeasuredOnOnlyOneAxisKeepsEveryIcon() {
        XCTAssertFalse(leaves(40, 40, CGSize(width: 300, height: 0)))
        XCTAssertFalse(leaves(40, 40, CGSize(width: 0, height: 120)))
        XCTAssertFalse(leaves(-40, -40, CGSize(width: 300, height: 0)))
        XCTAssertFalse(leaves(900, 900, CGSize(width: 0, height: 120)))
    }

    /// One point in either direction is a measurement artefact, not a sheet
    /// that could hold an icon, so it is treated as unmeasured. The guard is
    /// therefore `> 1` rather than `>= 1`: at exactly 1x1 nothing may eject.
    func testAOnePointSheetCountsAsUnmeasured() {
        let tiny = CGSize(width: 1, height: 1)
        XCTAssertFalse(leaves(0.5, 0.5, tiny))
        XCTAssertFalse(leaves(40, 40, tiny))
        XCTAssertFalse(leaves(-40, -40, tiny))
        XCTAssertFalse(leaves(1, 1, tiny))
        // And one point on a single axis is just as unmeasured.
        XCTAssertFalse(leaves(40, 40, CGSize(width: 300, height: 1)))
        XCTAssertFalse(leaves(40, 40, CGSize(width: 1, height: 120)))
    }

    /// The other side of that branch: anything genuinely larger than a point
    /// is live and must be able to eject, or the guard would have swallowed
    /// the gesture for small groups instead of only for unmeasured ones.
    func testASheetJustLargerThanOnePointIsLive() {
        let barely = CGSize(width: CGFloat(1).nextUp, height: CGFloat(1).nextUp)
        XCTAssertTrue(GroupDrag.leavesSheet(CGPoint(x: 40, y: 40), sheet: barely))
        XCTAssertTrue(GroupDrag.leavesSheet(CGPoint(x: -0.5, y: 0.5), sheet: barely))
        XCTAssertFalse(GroupDrag.leavesSheet(CGPoint(x: 0.5, y: 0.5), sheet: barely),
                       "a point inside even a sliver of a sheet stays")
        XCTAssertFalse(GroupDrag.leavesSheet(.zero, sheet: barely))
    }

    /// A negative extent cannot describe a sheet at all - an inverted or
    /// not-yet-valid frame - and the only safe reading of nonsense geometry is
    /// the non-destructive one.
    func testANegativeSheetSizeKeepsEveryIcon() {
        for sheet in [CGSize(width: -300, height: -120), CGSize(width: -300, height: 120),
                      CGSize(width: 300, height: -120)] {
            XCTAssertFalse(leaves(40, 40, sheet), "\(sheet)")
            XCTAssertFalse(leaves(-40, -40, sheet), "\(sheet)")
        }
    }

    /// A non-finite measurement must not eject either. Every comparison
    /// against NaN is false, so a NaN size fails the guard and keeps the icon;
    /// an infinite size passes the guard but contains every finite point,
    /// which lands on the same non-destructive answer by a different route.
    func testANonFiniteSheetSizeNeverEjectsAtAPositionInsideIt() {
        let notMeasured = CGSize(width: CGFloat.nan, height: CGFloat.nan)
        XCTAssertFalse(leaves(40, 40, notMeasured))
        XCTAssertFalse(leaves(-40, -40, notMeasured))

        let unbounded = CGSize(width: CGFloat.infinity, height: CGFloat.infinity)
        XCTAssertFalse(leaves(40, 40, unbounded))
        XCTAssertFalse(leaves(1e9, 1e9, unbounded))
        XCTAssertTrue(leaves(-1, 40, unbounded), "a negative coordinate is still out of bounds")
    }

    // MARK: leavesSheet - non-finite and far-away pointers

    /// An unknown pointer position is not an eject. A NaN coordinate compares
    /// false against every bound, so it reads as inside - the same direction
    /// every other unusable input resolves to, which keeps "we do not know
    /// where the pointer is" from destroying the group.
    func testANonFinitePointerPositionNeverEjectsAnIcon() {
        XCTAssertFalse(leaves(.nan, 60))
        XCTAssertFalse(leaves(150, .nan))
        XCTAssertFalse(leaves(.nan, .nan))
    }

    func testAnInfinitelyDistantPointerLeaves() {
        XCTAssertTrue(leaves(.infinity, 60))
        XCTAssertTrue(leaves(150, .infinity))
        XCTAssertTrue(leaves(-.infinity, 60))
        XCTAssertTrue(leaves(150, -.infinity))
    }

    /// A group sheet opens above the shelf, so a pointer dragged well past it
    /// is ordinary rather than exotic - the sheet's space simply runs negative
    /// once the pointer is over the shelf itself.
    func testDeeplyNegativeCoordinatesLeave() {
        XCTAssertTrue(leaves(-1_000, -1_000))
        XCTAssertTrue(leaves(-1_000, 60))
        XCTAssertTrue(leaves(150, -1_000))
    }

    // MARK: offset - the icon's centre is the pointer

    /// The defining property, stated as the identity the shelf depends on:
    /// displacing the icon by this offset puts its centre exactly under the
    /// cursor. Everything else about the drag - which slot the icon reads as
    /// hovering, where the eject fires - is measured from the pointer, so any
    /// residual here is a permanent disagreement between what the user sees
    /// and what the gesture acts on.
    func testTheOffsetPutsTheIconCentreUnderTheCursor() {
        let pairs: [(CGPoint, CGPoint)] = [
            (CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 0)),
            (CGPoint(x: 150, y: 60), CGPoint(x: 38, y: 60)),
            (CGPoint(x: 38, y: 60), CGPoint(x: 150, y: 60)),
            (CGPoint(x: -40, y: -90), CGPoint(x: 38, y: 60)),
            (CGPoint(x: 38, y: 60), CGPoint(x: -40, y: -90)),
            (CGPoint(x: -40, y: -90), CGPoint(x: -400, y: -900)),
            (CGPoint(x: 0.5, y: -0.5), CGPoint(x: -0.25, y: 0.125)),
            (CGPoint(x: 1e6, y: -1e6), CGPoint(x: -1e6, y: 1e6)),
            (CGPoint(x: 300, y: 120), CGPoint(x: 300, y: 120)),
        ]
        for (cursor, centre) in pairs {
            let offset = GroupDrag.offset(cursor: cursor, centre: centre)
            XCTAssertEqual(centre.x + offset.width, cursor.x, accuracy: 1e-6,
                           "cursor \(cursor) centre \(centre)")
            XCTAssertEqual(centre.y + offset.height, cursor.y, accuracy: 1e-6,
                           "cursor \(cursor) centre \(centre)")
        }
    }

    /// An icon whose centre is already under the pointer must not budge, or
    /// picking one up would jog the row by a point or two before the drag
    /// proper began.
    func testTheOffsetVanishesWhenTheCursorIsAlreadyAtTheCentre() {
        for point in [CGPoint(x: 0, y: 0), CGPoint(x: 150, y: 60),
                      CGPoint(x: -40, y: -90), CGPoint(x: -0.0, y: -0.0)] {
            let offset = GroupDrag.offset(cursor: point, centre: point)
            XCTAssertEqual(offset.width, 0, accuracy: 0, "\(point)")
            XCTAssertEqual(offset.height, 0, accuracy: 0, "\(point)")
        }
    }

    /// The regression, and the reason this is a function of the *centre*
    /// rather than of the drag: offsetting by the translation leaves the icon
    /// displaced by however far the press landed from its centre, for the
    /// whole gesture. Grab an icon by its corner and it trails the pointer by
    /// half its own width until you let go.
    ///
    /// The pinned offset depends only on where the pointer is now, so every
    /// press point across the icon's face produces the same result.
    func testTheOffsetDoesNotDependOnWhereWithinTheIconThePressLanded() {
        let centre = CGPoint(x: 100, y: 100)
        let side: CGFloat = 64
        let cursor = CGPoint(x: 250, y: 60)
        let expected = GroupDrag.offset(cursor: cursor, centre: centre)

        for dx in stride(from: -side / 2, through: side / 2, by: 8) {
            for dy in stride(from: -side / 2, through: side / 2, by: 8) {
                let press = CGPoint(x: centre.x + dx, y: centre.y + dy)
                XCTAssertEqual(GroupDrag.offset(cursor: cursor, centre: centre), expected,
                               "press at \(press) changed the offset")
                // What the regressed version produced, for contrast: the icon
                // ends up short of the pointer by the press's own eccentricity.
                let byTranslation = CGSize(width: cursor.x - press.x, height: cursor.y - press.y)
                XCTAssertEqual(byTranslation.width - expected.width, -dx, accuracy: 1e-9)
                XCTAssertEqual(byTranslation.height - expected.height, -dy, accuracy: 1e-9)
            }
        }
    }

    /// The worst case of that regression, as a number: a press on the corner
    /// of a 64pt icon left it 32pt short on both axes for the entire drag,
    /// which is most of an icon's width of visible lag.
    func testGrabbingAnIconByItsCornerDoesNotMakeItTrailThePointer() {
        let centre = CGPoint(x: 100, y: 100)
        let press = CGPoint(x: 132, y: 132)             // bottom-trailing corner
        let cursor = CGPoint(x: 250, y: 60)

        let pinned = GroupDrag.offset(cursor: cursor, centre: centre)
        XCTAssertEqual(centre.x + pinned.width, cursor.x, accuracy: 1e-9)
        XCTAssertEqual(centre.y + pinned.height, cursor.y, accuracy: 1e-9)

        let byTranslation = CGSize(width: cursor.x - press.x, height: cursor.y - press.y)
        XCTAssertEqual(centre.x + byTranslation.width, cursor.x - 32, accuracy: 1e-9)
        XCTAssertEqual(centre.y + byTranslation.height, cursor.y - 32, accuracy: 1e-9)
    }

    /// Pinning is a difference, so it is blind to where the sheet itself sits:
    /// shifting the whole coordinate space - a repositioned window, a scrolled
    /// row, a group opened above a shelf on another screen - leaves the offset
    /// untouched. Anything that made the offset depend on absolute position
    /// would show up as an icon that drifts as the sheet moves.
    func testTheOffsetDependsOnlyOnTheSeparationOfCursorAndCentre() {
        let cursor = CGPoint(x: 250, y: 60)
        let centre = CGPoint(x: 100, y: 100)
        let expected = GroupDrag.offset(cursor: cursor, centre: centre)

        for shift in [CGPoint(x: 0, y: 0), CGPoint(x: 1_000, y: 40), CGPoint(x: -2_560, y: -300),
                      CGPoint(x: -0.5, y: 0.5)] {
            let moved = GroupDrag.offset(cursor: CGPoint(x: cursor.x + shift.x, y: cursor.y + shift.y),
                                         centre: CGPoint(x: centre.x + shift.x, y: centre.y + shift.y))
            XCTAssertEqual(moved.width, expected.width, accuracy: 1e-9, "shift \(shift)")
            XCTAssertEqual(moved.height, expected.height, accuracy: 1e-9, "shift \(shift)")
        }
    }

    /// The icon tracks the pointer one to one: move the cursor by a vector and
    /// the icon moves by exactly that vector, with no gain and no lag. A
    /// translation-derived offset satisfies this too, which is precisely why
    /// the regression was hard to see in motion - it tracked correctly while
    /// sitting at a constant distance from the pointer.
    func testTheIconTracksThePointerOneToOne() {
        let centre = CGPoint(x: 100, y: 100)
        func pointer(atStep step: Int) -> CGPoint {
            CGPoint(x: CGFloat(step) * 3.5 - 60, y: 120 - CGFloat(step) * 1.25)
        }
        var previous = GroupDrag.offset(cursor: pointer(atStep: 0), centre: centre)
        for step in 1...50 {
            let cursor = pointer(atStep: step)
            let offset = GroupDrag.offset(cursor: cursor, centre: centre)
            let moved = CGPoint(x: offset.width - previous.width, y: offset.height - previous.height)
            XCTAssertEqual(moved.x, 3.5, accuracy: 1e-9, "step \(step)")
            XCTAssertEqual(moved.y, -1.25, accuracy: 1e-9, "step \(step)")
            previous = offset
        }
    }

    func testTheOffsetIsAntisymmetricInItsTwoPoints() {
        for (a, b) in [(CGPoint(x: 250, y: 60), CGPoint(x: 100, y: 100)),
                       (CGPoint(x: -40, y: -90), CGPoint(x: 0, y: 0)),
                       (CGPoint(x: 7, y: 7), CGPoint(x: 7, y: 7))] {
            let forward = GroupDrag.offset(cursor: a, centre: b)
            let backward = GroupDrag.offset(cursor: b, centre: a)
            XCTAssertEqual(forward.width, -backward.width, accuracy: 1e-9)
            XCTAssertEqual(forward.height, -backward.height, accuracy: 1e-9)
        }
    }

    /// Displays to the left of or above the main one have negative origins, so
    /// a group opened there runs its whole drag in negative coordinates. The
    /// pin must hold there identically - a sign assumption anywhere in this
    /// arithmetic would break dragging out of a group on a secondary screen
    /// while working on the primary.
    func testAnIconOnADisplayLeftOfTheMainOneStillPinsToThePointer() {
        let centre = CGPoint(x: -1_840, y: -420)
        for cursor in [CGPoint(x: -1_900, y: -500), CGPoint(x: -1_000, y: -100),
                       CGPoint(x: 120, y: 60), CGPoint(x: -1_840, y: -420)] {
            let offset = GroupDrag.offset(cursor: cursor, centre: centre)
            XCTAssertEqual(centre.x + offset.width, cursor.x, accuracy: 1e-6, "\(cursor)")
            XCTAssertEqual(centre.y + offset.height, cursor.y, accuracy: 1e-6, "\(cursor)")
        }
    }

    // MARK: the two together

    /// The two halves must agree about where the icon is. Because the offset
    /// pins the centre to the cursor, testing the pointer against the sheet
    /// and testing the dragged icon's centre against it are the same question
    /// - so the icon is never seen inside the sheet while the gesture has
    /// decided it left, or the reverse. Under a translation-based offset these
    /// diverge by the press's eccentricity, which is what made the eject fire
    /// while the icon was still visibly over the sheet.
    func testAPinnedIconLeavesTheSheetExactlyWhenThePointerDoes() {
        let centre = CGPoint(x: 38, y: 60)
        for x in stride(from: CGFloat(-30), through: 330, by: 6) {
            for y in stride(from: CGFloat(-30), through: 150, by: 6) {
                let cursor = CGPoint(x: x, y: y)
                let offset = GroupDrag.offset(cursor: cursor, centre: centre)
                let drawn = CGPoint(x: centre.x + offset.width, y: centre.y + offset.height)
                XCTAssertEqual(GroupDrag.leavesSheet(drawn, sheet: liveSheet),
                               GroupDrag.leavesSheet(cursor, sheet: liveSheet),
                               "icon at \(drawn) disagreed with pointer at \(cursor)")
            }
        }
    }

    /// Against an unmeasured sheet the pin must still work - the icon follows
    /// the pointer normally - while nothing ejects. The two guards are
    /// independent: the earlier bug froze the gesture *and* ejected, and
    /// fixing the eject must not have cost the tracking.
    func testAnIconStillFollowsThePointerInsideAnUnmeasuredSheet() {
        let centre = CGPoint(x: 38, y: 60)
        for cursor in [CGPoint(x: 0, y: 0), CGPoint(x: 400, y: 400), CGPoint(x: -400, y: -400)] {
            let offset = GroupDrag.offset(cursor: cursor, centre: centre)
            XCTAssertEqual(centre.x + offset.width, cursor.x, accuracy: 1e-9)
            XCTAssertEqual(centre.y + offset.height, cursor.y, accuracy: 1e-9)
            XCTAssertFalse(GroupDrag.leavesSheet(cursor, sheet: .zero), "\(cursor)")
        }
    }
}
