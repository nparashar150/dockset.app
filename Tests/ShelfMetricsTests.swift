import AppKit
import XCTest

/// The shelf is centred inside a panel longer than itself, so every
/// conversion between a panel position and a slot in the row goes through
/// that inset - outwards for the hover label, inwards for the drop gap. The
/// two directions disagreeing about it is the single defect this shelf has
/// shipped most often, and always silently.
final class ShelfMetricsTests: XCTestCase {

    // MARK: Fixtures

    private let length: CGFloat = 40
    private let gap: CGFloat = 2

    /// Rest centres of `count` equal tiles, built with the same function the
    /// shelf itself uses so the fixture cannot drift from the real row.
    private func centres(_ count: Int) -> [Double] {
        DockMagnification.restCenters(lengths: Array(repeating: length, count: count), gap: gap)
            .map { Double($0) }
    }

    /// A row of `count` tiles, each budgeting the gap that follows it - which
    /// is how the shelf measures its own rest length.
    private func restLength(_ count: Int) -> CGFloat {
        CGFloat(count) * (length + gap)
    }

    private let plate: CGFloat = 600
    private let reserve: CGFloat = 110

    // MARK: inset

    /// The shelf is centred, so whatever room is left over is split evenly
    /// between the two ends.
    ///
    /// Both conversions treat the inset as the *only* difference between panel
    /// and row coordinates. Measuring it against the plate alone - forgetting
    /// that the panel is `plateLength + longReserve` long, because the reserve
    /// is invisible until something magnifies into it - leaves half the reserve
    /// unaccounted for in every position derived from it.
    func testTheShelfIsCentredInThePanelItSitsIn() {
        for reserve in [CGFloat(0), 40, 110] {
            for extra in [CGFloat(0), 17, 60] {
                let inset = ShelfMetrics.inset(plateLength: plate, longReserve: reserve,
                                               restLength: 420, totalExtra: extra,
                                               overflowing: false)
                XCTAssertEqual(inset * 2 + 420 + extra, plate + reserve, accuracy: 1e-9,
                               "reserve \(reserve), extra \(extra) was not centred")
            }
        }
    }

    /// An overflowing row is as long as its plate and no longer, so it is the
    /// plate that gets centred in the panel.
    func testAnOverflowingShelfIsCentredOnItsPlateLength() {
        for extra in [CGFloat(0), 17, 60] {
            let inset = ShelfMetrics.inset(plateLength: plate, longReserve: reserve,
                                           restLength: 4_000, totalExtra: extra,
                                           overflowing: true)
            XCTAssertEqual(inset * 2 + plate, plate + reserve, accuracy: 1e-9, "extra \(extra)")
        }
    }

    /// The regression that made the hover label drift as the pointer moved.
    ///
    /// `totalExtra` is the length magnification is currently adding, so it
    /// changes on every pointer sample. An overflowing row is pinned to the
    /// plate and does not grow at all, so an inset that still consumed
    /// `totalExtra` there slid the whole coordinate system out from under a row
    /// that had not moved.
    func testMagnificationCannotMoveAnOverflowingRow() {
        let base = ShelfMetrics.inset(plateLength: plate, longReserve: reserve,
                                      restLength: 4_000, totalExtra: 0, overflowing: true)
        for extra in stride(from: CGFloat(0), through: 300, by: 3) {
            XCTAssertEqual(ShelfMetrics.inset(plateLength: plate, longReserve: reserve,
                                              restLength: 4_000, totalExtra: extra,
                                              overflowing: true),
                           base, accuracy: 1e-12,
                           "the inset tracked magnification at extra \(extra)")
        }
    }

    /// A row that fits does grow, and grows from its middle: half the growth
    /// goes each way, so the inset gives back exactly half of every point.
    func testARowThatFitsGivesBackHalfOfEveryPointItGrows() {
        let base = ShelfMetrics.inset(plateLength: plate, longReserve: reserve,
                                      restLength: 420, totalExtra: 0, overflowing: false)
        for extra in stride(from: CGFloat(0), through: 120, by: 3) {
            XCTAssertEqual(ShelfMetrics.inset(plateLength: plate, longReserve: reserve,
                                              restLength: 420, totalExtra: extra,
                                              overflowing: false),
                           base - extra / 2, accuracy: 1e-9, "extra \(extra)")
        }
    }

    /// The two branches have to meet where the row exactly fills its plate.
    ///
    /// That is the moment the flag flips, and with magnification off there is
    /// nothing else left to distinguish them: an unmagnified row that is as
    /// long as its plate is the same row either way. A mismatch here is a
    /// coordinate system that jumps the instant one more icon is added.
    func testTheOverflowBranchesMeetWhereTheRowExactlyFillsThePlate() {
        let fits = ShelfMetrics.inset(plateLength: plate, longReserve: reserve,
                                      restLength: plate, totalExtra: 0, overflowing: false)
        let pinned = ShelfMetrics.inset(plateLength: plate, longReserve: reserve,
                                        restLength: plate, totalExtra: 0, overflowing: true)
        XCTAssertEqual(fits, pinned, accuracy: 1e-12)
        XCTAssertEqual(fits, reserve / 2, accuracy: 1e-12)
    }

    /// Away from that boundary the flag still decides everything, even with
    /// magnification off: a short row pinned to the plate would be mis-centred
    /// by half the slack between the two.
    func testTheOverflowFlagStillMattersWithMagnificationOff() {
        let fits = ShelfMetrics.inset(plateLength: plate, longReserve: reserve,
                                      restLength: 420, totalExtra: 0, overflowing: false)
        let pinned = ShelfMetrics.inset(plateLength: plate, longReserve: reserve,
                                        restLength: 420, totalExtra: 0, overflowing: true)
        XCTAssertEqual(fits - pinned, (plate - 420) / 2, accuracy: 1e-9)
    }

    /// With magnification off there is no reserve either, and then the panel
    /// *is* the plate.
    func testAZeroReserveCentresTheRowOnThePlateAlone() {
        XCTAssertEqual(ShelfMetrics.inset(plateLength: plate, longReserve: 0,
                                          restLength: 420, totalExtra: 0, overflowing: false),
                       (plate - 420) / 2, accuracy: 1e-12)
    }

    /// The reserve is headroom at both ends, so it can only ever contribute
    /// half of itself to the inset.
    func testTheReserveOnlyEverPushesTheRowInByHalfOfItself() {
        let base = ShelfMetrics.inset(plateLength: plate, longReserve: 0,
                                      restLength: 420, totalExtra: 0, overflowing: false)
        for reserve in [CGFloat(0), 1, 40, 110, 333] {
            XCTAssertEqual(ShelfMetrics.inset(plateLength: plate, longReserve: reserve,
                                              restLength: 420, totalExtra: 0,
                                              overflowing: false) - base,
                           reserve / 2, accuracy: 1e-9, "reserve \(reserve)")
        }
    }

    /// An empty shelf has no length to centre, so the whole panel is inset -
    /// and the figure must still be halved, because the add button and grip it
    /// leaves behind are positioned through the same conversion.
    func testAnEmptyRowIsCentredWithNothingInIt() {
        XCTAssertEqual(ShelfMetrics.inset(plateLength: plate, longReserve: reserve,
                                          restLength: 0, totalExtra: 0, overflowing: false),
                       (plate + reserve) / 2, accuracy: 1e-12)
    }

    /// A row longer than its panel reports a *negative* inset rather than
    /// clamping at zero: it hangs out of both ends, and the two conversions
    /// stay inverses of each other only while the inset keeps its sign.
    func testARowLongerThanItsPanelHangsOutOfBothEnds() {
        XCTAssertEqual(ShelfMetrics.inset(plateLength: plate, longReserve: 0,
                                          restLength: 900, totalExtra: 0, overflowing: false),
                       -150, accuracy: 1e-12)
    }

    // MARK: panelPosition

    /// Each of the three offsets must be added exactly once.
    ///
    /// Dropping one, or adding it twice, is invisible on a short unscrolled
    /// shelf because padding, scroll and inset are all small or zero there. It
    /// only appears once the shelf is scrolled or properly centred, which is
    /// how a label came to point at a neighbouring icon.
    func testEachOffsetMovesASlotByExactlyItsOwnAmount() {
        let base = ShelfMetrics.panelPosition(slotCentre: 104, padding: 8, scroll: -16, inset: 55)
        XCTAssertEqual(ShelfMetrics.panelPosition(slotCentre: 105, padding: 8, scroll: -16, inset: 55),
                       base + 1, accuracy: 1e-9)
        XCTAssertEqual(ShelfMetrics.panelPosition(slotCentre: 104, padding: 9, scroll: -16, inset: 55),
                       base + 1, accuracy: 1e-9)
        XCTAssertEqual(ShelfMetrics.panelPosition(slotCentre: 104, padding: 8, scroll: -15, inset: 55),
                       base + 1, accuracy: 1e-9)
        XCTAssertEqual(ShelfMetrics.panelPosition(slotCentre: 104, padding: 8, scroll: -16, inset: 56),
                       base + 1, accuracy: 1e-9)
        XCTAssertEqual(ShelfMetrics.panelPosition(slotCentre: 105, padding: 9, scroll: -15, inset: 56),
                       base + 4, accuracy: 1e-9)
    }

    func testASlotWithNoOffsetsSitsAtItsOwnCentre() {
        XCTAssertEqual(ShelfMetrics.panelPosition(slotCentre: 62, padding: 0, scroll: 0, inset: 0),
                       62, accuracy: 1e-12)
    }

    /// The row is rigid: scrolling and centring move every slot together, so
    /// the distance between two slots never depends on where the row currently
    /// sits. A per-slot correction - re-centring on the nearest item, say -
    /// would show up here as a pitch that changes along the row.
    func testTheRowIsRigidUnderScrollingAndCentring() {
        let centres = centres(6)
        for scroll in [CGFloat(0), -37, -400, 12] {
            for inset in [CGFloat(0), 55, -150] {
                let positions = centres.map {
                    ShelfMetrics.panelPosition(slotCentre: $0, padding: 8, scroll: scroll, inset: inset)
                }
                for index in 1..<positions.count {
                    XCTAssertEqual(positions[index] - positions[index - 1], Double(length + gap),
                                   accuracy: 1e-9, "scroll \(scroll), inset \(inset), slot \(index)")
                }
            }
        }
    }

    /// The shelf scrolls negative - the row slides leading-edge-first out of
    /// the panel - so a negative scroll must carry slots towards the panel's
    /// start, not away from it.
    func testANegativeScrollMovesTheRowTowardsThePanelsStart() {
        XCTAssertLessThan(ShelfMetrics.panelPosition(slotCentre: 104, padding: 8,
                                                     scroll: -120, inset: 55),
                          ShelfMetrics.panelPosition(slotCentre: 104, padding: 8,
                                                     scroll: 0, inset: 55))
    }

    // MARK: slot as an insertion index

    func testAPositionBeforeEveryCentreInsertsAtTheFront() {
        let centres = centres(5)
        let first = ShelfMetrics.panelPosition(slotCentre: centres[0], padding: 8,
                                               scroll: -16, inset: 55)
        for position in [first - 1e-6, first - 1, first - 10_000] {
            XCTAssertEqual(ShelfMetrics.slot(atPanelPosition: position, centres: centres,
                                             padding: 8, scroll: -16, inset: 55),
                           0, "position \(position)")
        }
    }

    /// Past the last centre there is no slot left to land in, so the answer is
    /// one past the end - an append, and the largest index the caller may
    /// legally insert at.
    func testAPositionPastEveryCentreAppendsToTheEnd() {
        let centres = centres(5)
        let last = ShelfMetrics.panelPosition(slotCentre: centres[4], padding: 8,
                                              scroll: -16, inset: 55)
        for position in [last, last + 1e-6, last + 10_000] {
            XCTAssertEqual(ShelfMetrics.slot(atPanelPosition: position, centres: centres,
                                             padding: 8, scroll: -16, inset: 55),
                           centres.count, "position \(position)")
        }
    }

    /// A position exactly on a centre inserts *after* that tile.
    ///
    /// The comparison is a strict `<`, so the positions belonging to slot `i`
    /// are the half-open span from centre `i-1` up to centre `i`: the spans
    /// tile the axis with no overlap and no gap, and every position belongs to
    /// exactly one of them. Which side the tie falls on matters far less than
    /// it falling on the same side in both directions - a `<=` here against a
    /// `<` in the outward conversion is precisely how the gap and the label
    /// came to disagree by one tile.
    func testAPositionExactlyOnACentreInsertsAfterThatTile() {
        let centres = centres(7)
        for (index, centre) in centres.enumerated() {
            let position = ShelfMetrics.panelPosition(slotCentre: centre, padding: 8,
                                                      scroll: -16, inset: 55)
            XCTAssertEqual(ShelfMetrics.slot(atPanelPosition: position, centres: centres,
                                             padding: 8, scroll: -16, inset: 55),
                           index + 1, "on the centre of slot \(index)")
            XCTAssertEqual(ShelfMetrics.slot(atPanelPosition: position - 1e-6, centres: centres,
                                             padding: 8, scroll: -16, inset: 55),
                           index, "a hair before the centre of slot \(index)")
        }
    }

    /// A pointer in the gap between two tiles inserts between them.
    func testAPointerBetweenTwoTilesInsertsBetweenThem() {
        let centres = centres(7)
        for index in 1..<centres.count {
            let middle = (centres[index - 1] + centres[index]) / 2
            let position = ShelfMetrics.panelPosition(slotCentre: middle, padding: 8,
                                                      scroll: -16, inset: 55)
            XCTAssertEqual(ShelfMetrics.slot(atPanelPosition: position, centres: centres,
                                             padding: 8, scroll: -16, inset: 55),
                           index, "between slots \(index - 1) and \(index)")
        }
    }

    /// Sweeping the pointer along the panel must walk the slots in order, one
    /// at a time, and never leave the range the caller can insert at - the
    /// result indexes an array of tiles. A sign error in any of the three
    /// offsets shows up here as an index that runs backwards.
    func testTheSlotIndexRisesInStepAcrossTheWholePanel() {
        let centres = centres(8)
        let inset = ShelfMetrics.inset(plateLength: plate, longReserve: reserve,
                                       restLength: restLength(8), totalExtra: 0,
                                       overflowing: false)
        var previous = 0
        var position = -200.0
        while position <= 900 {
            let slot = ShelfMetrics.slot(atPanelPosition: position, centres: centres,
                                         padding: 8, scroll: -16, inset: inset)
            XCTAssertGreaterThanOrEqual(slot, previous, "ran backwards at \(position)")
            XCTAssertLessThanOrEqual(slot - previous, 1, "skipped a slot at \(position)")
            XCTAssertTrue((0...centres.count).contains(slot), "\(slot) at \(position)")
            previous = slot
            position += 0.25
        }
        XCTAssertEqual(previous, centres.count, "the sweep never reached the end of the row")
    }

    /// An empty row still has the one slot everything is inserted at, whatever
    /// the pointer says - an empty shelf is the state the app launches in, and
    /// a drop onto it must not index past zero.
    func testAnEmptyRowHasOnlyTheOneSlotThereIsToInsertInto() {
        for position in [-10_000.0, -1, 0, 1, 314, 10_000, .nan] {
            XCTAssertEqual(ShelfMetrics.slot(atPanelPosition: position, centres: [],
                                             padding: 8, scroll: -16, inset: 55),
                           0, "position \(position)")
        }
    }

    /// One tile still has two insertion points: before it and after it.
    func testASingleCentreSplitsThePanelInTwo() {
        let centres = centres(1)
        let insertion = { (position: Double) in
            ShelfMetrics.slot(atPanelPosition: position, centres: centres,
                              padding: 8, scroll: 0, inset: 55)
        }
        let centre = ShelfMetrics.panelPosition(slotCentre: centres[0], padding: 8,
                                                scroll: 0, inset: 55)
        XCTAssertEqual(insertion(centre - 1_000), 0)
        XCTAssertEqual(insertion(centre - 1e-6), 0)
        XCTAssertEqual(insertion(centre), 1)
        XCTAssertEqual(insertion(centre + 1_000), 1)
    }

    /// The answer indexes the caller's own array of tiles, so it has to stay
    /// insertable however strange the pointer is. A drag can report a position
    /// before the shelf has laid out, and an infinity or a NaN must land at one
    /// of the two ends rather than anywhere out of range.
    func testANonFinitePositionStillYieldsAnInsertableIndex() {
        let centres = centres(5)
        for position in [Double.nan, .infinity, -.infinity, .greatestFiniteMagnitude] {
            let slot = ShelfMetrics.slot(atPanelPosition: position, centres: centres,
                                         padding: 8, scroll: -16, inset: 55)
            XCTAssertTrue((0...centres.count).contains(slot), "\(position) produced \(slot)")
        }
        XCTAssertEqual(ShelfMetrics.slot(atPanelPosition: -.infinity, centres: centres,
                                         padding: 8, scroll: -16, inset: 55), 0)
        XCTAssertEqual(ShelfMetrics.slot(atPanelPosition: .infinity, centres: centres,
                                         padding: 8, scroll: -16, inset: 55), centres.count)
    }

    /// And an unmeasured panel must not poison it either: the inset is a
    /// difference of measured lengths halved, so an unmeasured window makes it
    /// NaN, and the comparison it feeds is then false for every centre.
    func testANaNInsetCannotProduceAnOutOfRangeSlot() {
        let centres = centres(5)
        let inset = ShelfMetrics.inset(plateLength: .nan, longReserve: reserve,
                                       restLength: restLength(5), totalExtra: 0,
                                       overflowing: false)
        XCTAssertTrue(inset.isNaN, "precondition: an unmeasured panel gives a NaN inset")
        for position in [0.0, 314, -10_000, 10_000] {
            let slot = ShelfMetrics.slot(atPanelPosition: position, centres: centres,
                                         padding: 8, scroll: -16, inset: inset)
            XCTAssertTrue((0...centres.count).contains(slot), "\(position) produced \(slot)")
        }
    }

    // MARK: The round trip

    /// The property that would have caught all three misplacements.
    ///
    /// The hover label converts a slot centre outwards to a panel position and
    /// the drop target converts the pointer back inwards; they are the same map
    /// run in opposite directions, and every one of those bugs was the two
    /// disagreeing about one of its terms. A slot's own centre must therefore
    /// come back as that slot for every row length, both overflow states, and
    /// every combination of padding and scrolling - the insertion index a hair
    /// before the centre, since exactly on it belongs to the tile after.
    func testASlotCentreComesBackAsThatSlot() {
        for count in 1...12 {
            let centres = centres(count)
            for overflowing in [false, true] {
                let inset = ShelfMetrics.inset(plateLength: plate, longReserve: reserve,
                                               restLength: restLength(count), totalExtra: 48,
                                               overflowing: overflowing)
                for padding in [CGFloat(0), 8, 21] {
                    for scroll in [CGFloat(0), -37, -400, 12] {
                        for (index, centre) in centres.enumerated() {
                            let position = ShelfMetrics.panelPosition(slotCentre: centre,
                                                                      padding: padding,
                                                                      scroll: scroll,
                                                                      inset: inset)
                            XCTAssertEqual(
                                ShelfMetrics.slot(atPanelPosition: position - 1e-6,
                                                  centres: centres, padding: padding,
                                                  scroll: scroll, inset: inset),
                                index,
                                """
                                slot \(index) of \(count), overflowing \(overflowing), \
                                padding \(padding), scroll \(scroll)
                                """)
                        }
                    }
                }
            }
        }
    }

    /// Whatever the offsets are, they cancel: the recovered slot depends on the
    /// row alone.
    ///
    /// This is the shape of the defect rather than an instance of it. The label
    /// was corrected for the inset while the drop target was not, so the gap
    /// opened a fixed distance from the pointer - a distance that was nearly
    /// nothing on a full shelf and most of a tile on a short one, which is why
    /// it read as intermittent instead of as an off-by-one.
    func testTheOffsetsCancelSoTheAnswerDependsOnlyOnTheSlot() {
        let centres = centres(9)
        for padding in [CGFloat(0), 8, 21] {
            for scroll in [CGFloat(0), -37, -400, 12] {
                for inset in [CGFloat(0), 55, 79, 355, -150] {
                    for (index, centre) in centres.enumerated() {
                        let position = ShelfMetrics.panelPosition(slotCentre: centre,
                                                                  padding: padding,
                                                                  scroll: scroll, inset: inset)
                        XCTAssertEqual(
                            ShelfMetrics.slot(atPanelPosition: position, centres: centres,
                                              padding: padding, scroll: scroll, inset: inset),
                            index + 1,
                            "slot \(index), padding \(padding), scroll \(scroll), inset \(inset)")
                    }
                }
            }
        }
    }

    /// With magnification off and the shelf unscrolled, the inset is the only
    /// offset there is - which is exactly why forgetting it survived review for
    /// so long. The round trip has to hold when the one correction in play is
    /// the one that was missing.
    func testTheRoundTripHoldsWhenTheInsetIsTheOnlyOffset() {
        for count in [1, 2, 5, 9] {
            let centres = centres(count)
            let inset = ShelfMetrics.inset(plateLength: plate, longReserve: 0,
                                           restLength: restLength(count), totalExtra: 0,
                                           overflowing: false)
            XCTAssertGreaterThan(inset, length + gap,
                                 "precondition: the shelf is inset by more than a tile")
            for (index, centre) in centres.enumerated() {
                let position = ShelfMetrics.panelPosition(slotCentre: centre, padding: 0,
                                                          scroll: 0, inset: inset)
                XCTAssertEqual(ShelfMetrics.slot(atPanelPosition: position - 1e-6,
                                                 centres: centres, padding: 0,
                                                 scroll: 0, inset: inset),
                               index, "slot \(index) of \(count)")
            }
        }
    }

    /// Every chrome metric is scaled by the size slider, so the real numbers
    /// are never tidy. The inverse must hold for arbitrary geometry and not
    /// only for figures whose arithmetic happens to be exact.
    func testTheRoundTripSurvivesFractionalGeometry() {
        let centres = DockMagnification.restCenters(lengths: [37.3, 41.9, 40.55, 40.5, 39.05],
                                                    gap: 2.4).map { Double($0) }
        let inset = ShelfMetrics.inset(plateLength: 512.7, longReserve: 96.4,
                                       restLength: 211.9, totalExtra: 21.35,
                                       overflowing: false)
        for (index, centre) in centres.enumerated() {
            let position = ShelfMetrics.panelPosition(slotCentre: centre, padding: 7.3,
                                                      scroll: -19.85, inset: inset)
            XCTAssertEqual(ShelfMetrics.slot(atPanelPosition: position - 1e-6, centres: centres,
                                             padding: 7.3, scroll: -19.85, inset: inset),
                           index, "slot \(index)")
        }
    }

    /// A widget is several icons wide, so its neighbours' centres are nowhere
    /// near an even pitch. Nothing in either direction may assume one.
    func testTheRoundTripHoldsWithAWideWidgetInTheRow() {
        let lengths: [CGFloat] = [40, 40, 40, 134, 40, 180, 40]
        let centres = DockMagnification.restCenters(lengths: lengths, gap: gap).map { Double($0) }
        let rest = lengths.reduce(0, +) + CGFloat(lengths.count) * gap
        for overflowing in [false, true] {
            let inset = ShelfMetrics.inset(plateLength: plate, longReserve: reserve,
                                           restLength: rest, totalExtra: 36,
                                           overflowing: overflowing)
            for (index, centre) in centres.enumerated() {
                let position = ShelfMetrics.panelPosition(slotCentre: centre, padding: 8,
                                                          scroll: -24, inset: inset)
                XCTAssertEqual(ShelfMetrics.slot(atPanelPosition: position - 1e-6,
                                                 centres: centres, padding: 8,
                                                 scroll: -24, inset: inset),
                               index, "slot \(index), overflowing \(overflowing)")
            }
        }
    }

    /// The tests above have teeth: the two insets really are far enough apart
    /// to matter.
    ///
    /// A magnified overflowing row is pinned to its plate, so the pinned inset
    /// is the true one. Converting outwards with it and back with the growing
    /// formula - one direction corrected for magnification and the other not -
    /// moves the answer by more than a whole tile, which is the drop gap
    /// opening beside the icon under the pointer rather than at it.
    func testMismatchedInsetsLandOnTheWrongSlot() {
        let centres = centres(12)
        let pinned = ShelfMetrics.inset(plateLength: plate, longReserve: reserve,
                                        restLength: restLength(12), totalExtra: 200,
                                        overflowing: true)
        let growing = ShelfMetrics.inset(plateLength: plate, longReserve: reserve,
                                         restLength: restLength(12), totalExtra: 200,
                                         overflowing: false)
        XCTAssertGreaterThan(abs(pinned - growing), length + gap,
                             "precondition: the two insets differ by more than a tile")

        let position = ShelfMetrics.panelPosition(slotCentre: centres[5], padding: 8,
                                                  scroll: -20, inset: pinned)
        let agreed = ShelfMetrics.slot(atPanelPosition: position, centres: centres,
                                       padding: 8, scroll: -20, inset: pinned)
        let mismatched = ShelfMetrics.slot(atPanelPosition: position, centres: centres,
                                           padding: 8, scroll: -20, inset: growing)
        XCTAssertEqual(agreed, 6)
        XCTAssertNotEqual(mismatched, agreed)
    }

    /// The bug as the user met it: hold the pointer still over an overflowing
    /// shelf and the gap must stay where it is.
    ///
    /// Magnification changes `totalExtra` continuously as the pointer moves,
    /// and the row it is magnifying cannot grow because it is already pinned to
    /// the plate. A row that *can* grow really does move under the same sweep,
    /// which is the whole reason the flag exists.
    func testAFixedPointerKeepsItsSlotWhileAnOverflowingRowMagnifies() {
        let centres = centres(20)
        var pinned: Set<Int> = []
        var growing: Set<Int> = []
        for extra in stride(from: CGFloat(0), through: 300, by: 7) {
            for overflowing in [true, false] {
                let inset = ShelfMetrics.inset(plateLength: plate, longReserve: reserve,
                                               restLength: restLength(20), totalExtra: extra,
                                               overflowing: overflowing)
                let slot = ShelfMetrics.slot(atPanelPosition: 314, centres: centres,
                                             padding: 8, scroll: -120, inset: inset)
                if overflowing { pinned.insert(slot) } else { growing.insert(slot) }
            }
        }
        XCTAssertEqual(pinned.count, 1, "the gap moved under a stationary pointer")
        XCTAssertGreaterThan(growing.count, 1,
                             "precondition: magnification does move a row that can grow")
    }
}
