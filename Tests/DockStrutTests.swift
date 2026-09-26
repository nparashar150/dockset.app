import AppKit
import XCTest

/// Sizing for the strip Apple's Dock reserves on the shelf's behalf.
///
/// The shelf only stops covering zoomed windows if the strip it draws in is
/// one the Dock actually reserved, so the arithmetic that decides "how big a
/// Dock do I ask for" and "how much of what I got may I use" is the part worth
/// pinning down.
final class DockStrutTests: XCTestCase {

    // MARK: Asking for a strip

    func testATileSizeIsDerivedFromTheStripWanted() {
        // The one measured point: tile size 38 reserved 58 points.
        XCTAssertEqual(DockStrutMetrics.tileSize(forStrip: 58), 38, accuracy: 0.001)
    }

    func testATinyShelfCannotAskForATileSmallerThanMacOSAllows() {
        XCTAssertEqual(DockStrutMetrics.tileSize(forStrip: 0),
                       DockStrutMetrics.tileRange.lowerBound)
        XCTAssertEqual(DockStrutMetrics.tileSize(forStrip: 25),
                       DockStrutMetrics.tileRange.lowerBound,
                       "25 less the padding is under the floor, so it clamps")
    }

    func testAHugeShelfAsksForTheLargestTileAndNoMore() {
        XCTAssertEqual(DockStrutMetrics.tileSize(forStrip: 400),
                       DockStrutMetrics.tileRange.upperBound)
    }

    func testEveryStripMapsIntoTheRangeMacOSAccepts() {
        for strip in stride(from: CGFloat(0), through: 600, by: 7) {
            let size = DockStrutMetrics.tileSize(forStrip: strip)
            XCTAssertTrue(DockStrutMetrics.tileRange.contains(size),
                          "\(strip) produced \(size), which macOS would reject")
        }
    }

    // MARK: Living within it

    /// The whole point of the mode. Drawing past the reservation is the defect
    /// it exists to fix, so the shelf gives way, never the strip.
    func testTheShelfIsClampedToWhatWasActuallyReserved() {
        XCTAssertEqual(DockStrutMetrics.shelfThickness(wanting: 150, reserved: 90), 90)
    }

    func testAShelfSmallerThanTheStripKeepsItsOwnSize() {
        XCTAssertEqual(DockStrutMetrics.shelfThickness(wanting: 60, reserved: 90), 60,
                       "a reservation is a ceiling, not a height to grow into")
    }

    /// Nothing reserved means the Dock is hidden or gone, which is the ordinary
    /// un-borrowed state. The shelf keeps its own size rather than collapsing.
    func testNoReservationLeavesTheShelfAlone() {
        XCTAssertEqual(DockStrutMetrics.shelfThickness(wanting: 62, reserved: 0), 62)
    }

    func testClampingIsNeverAnIncrease() {
        for wanted in stride(from: CGFloat(20), through: 300, by: 11) {
            for reserved in stride(from: CGFloat(0), through: 200, by: 13) {
                let got = DockStrutMetrics.shelfThickness(wanting: wanted, reserved: reserved)
                XCTAssertLessThanOrEqual(got, wanted,
                                         "borrowing a strip must not grow the shelf")
            }
        }
    }

    // MARK: The debt

    /// `DockPrefs` is what gets written back, so it has to survive the round
    /// trip through the state file intact. A snapshot that decodes wrong is a
    /// Dock restored wrong.
    func testTheSnapshotSurvivesEncoding() throws {
        let before = DockPrefs(autoHide: true, tileSize: 38, orientation: "left")
        let data = try JSONEncoder().encode(before)
        let after = try JSONDecoder().decode(DockPrefs.self, from: data)
        XCTAssertEqual(before, after)
    }

    /// A state file written before this existed has no snapshot, and that must
    /// read as "owes nothing" rather than failing to load at all.
    func testAStateFileWithNoSnapshotOwesNothing() throws {
        let json = #"{"version": 1, "customDock": {"position": "bottom"}}"#
        let state = try JSONDecoder().decode(PersistedState.self,
                                             from: json.data(using: .utf8)!)
        XCTAssertNil(state.borrowedDockPrefs)
    }

    func testARecordedSnapshotDecodesBack() throws {
        let json = """
        {"version": 1, "borrowedDockPrefs":
          {"autoHide": false, "tileSize": 64, "orientation": "bottom"}}
        """
        let state = try JSONDecoder().decode(PersistedState.self,
                                             from: json.data(using: .utf8)!)
        XCTAssertEqual(state.borrowedDockPrefs?.tileSize, 64)
        XCTAssertEqual(state.borrowedDockPrefs?.orientation, "bottom")
    }
}
