import Foundation
import XCTest

/// Following the real Dock, and getting back to it.
///
/// Both overrides used to be one directional. Dragging the size grip once set
/// a flag nothing could clear, and rearranging a single mirrored app took the
/// whole list over for good. In each case the shelf stopped tracking the Dock
/// permanently, from one ordinary gesture, with nothing in the app able to
/// undo it.
final class FollowingTests: XCTestCase {

    // MARK: Size

    func testFollowingTakesTheDocksSize() {
        XCTAssertEqual(DockFollowing.scale(overridden: false, custom: 0.9,
                                           system: 0.4, following: true), 0.4)
    }

    func testAnOverrideWinsWhileStillFollowingEverythingElse() {
        XCTAssertEqual(DockFollowing.scale(overridden: true, custom: 0.9,
                                           system: 0.4, following: true), 0.9,
                       "the size is the user's; the edge and hiding are not")
    }

    func testNotFollowingUsesTheStoredSize() {
        XCTAssertEqual(DockFollowing.scale(overridden: false, custom: 0.9,
                                           system: 0.4, following: false), 0.9)
    }

    /// The fix, expressed as the thing that was impossible: clearing the flag
    /// has to put the Dock's size back, not leave the last override behind.
    func testClearingTheOverrideReturnsToTheDocksSize() {
        let overridden = DockFollowing.scale(overridden: true, custom: 0.9,
                                             system: 0.4, following: true)
        let cleared = DockFollowing.scale(overridden: false, custom: 0.9,
                                          system: 0.4, following: true)
        XCTAssertEqual(overridden, 0.9)
        XCTAssertEqual(cleared, 0.4, "resuming has to be a real return, not a no-op")
    }

    /// Clearing it keeps the stored size, so turning following off later lands
    /// back on the size the user chose rather than on a default.
    func testTheStoredSizeSurvivesResuming() {
        XCTAssertEqual(DockFollowing.scale(overridden: false, custom: 0.9,
                                           system: 0.4, following: false), 0.9)
    }

    // MARK: The stored flags

    /// `scaleOverridden` and `mirrorSystemApps` are optional so state written
    /// before they existed still decodes. Absent has to mean the pre-existing
    /// behaviour: not overridden, and mirroring on.
    func testAbsentFlagsMeanFollowing() throws {
        let json = #"{"version": 1, "customDock": {"followSystemDock": true}}"#
        let state = try JSONDecoder().decode(PersistedState.self,
                                             from: json.data(using: .utf8)!)
        XCTAssertNil(state.customDock.scaleOverridden)
        XCTAssertNil(state.customDock.mirrorSystemApps)
        XCTAssertEqual(DockFollowing.scale(overridden: state.customDock.scaleOverridden == true,
                                           custom: 0.9, system: 0.4,
                                           following: state.customDock.followSystemDock), 0.4)
    }

    func testAnExplicitFalseIsTheSameAsAbsent() throws {
        let json = #"""
        {"version": 1, "customDock": {"followSystemDock": true, "scaleOverridden": false}}
        """#
        let state = try JSONDecoder().decode(PersistedState.self,
                                             from: json.data(using: .utf8)!)
        XCTAssertEqual(state.customDock.scaleOverridden, false)
        XCTAssertEqual(DockFollowing.scale(overridden: state.customDock.scaleOverridden == true,
                                           custom: 0.9, system: 0.4, following: true), 0.4,
                       "a cleared override is a cleared override, however it was written")
    }

    // MARK: Handing the app list back

    /// Resuming mirroring has to drop the adopted copies as well as flip the
    /// flag. Leaving them would show the profile's copy and the Dock's mirror
    /// of the same app side by side.
    func testResumingMirroringRemovesTheAdoptedCopies() {
        let pinned = ["com.apple.Safari", "com.apple.finder"]
        let items = [
            app("com.apple.Safari"),
            app("com.apple.finder"),
            app("com.example.NotInTheDock"),
        ]
        let kept = items.filter { item in
            guard case .app(_, let bundleID, _) = item else { return true }
            return !pinned.contains(bundleID)
        }
        XCTAssertEqual(kept.count, 1)
        guard case .app(_, let bundleID, _) = kept[0] else { return XCTFail("expected an app") }
        XCTAssertEqual(bundleID, "com.example.NotInTheDock",
                       "an app the user added, which the Dock does not pin, has to survive")
    }

    /// Non-app items are never adopted copies of anything, so nothing may drop
    /// a widget or a folder on the way back to mirroring.
    func testResumingMirroringKeepsEverythingThatIsNotAnApp() {
        let pinned = ["com.apple.Safari"]
        let items: [DockItem] = [
            app("com.apple.Safari"),
            .widget(WidgetInstance(kind: .clock, config: WidgetConfig())),
            .spacer(id: UUID(), size: .regular),
        ]
        let kept = items.filter { item in
            guard case .app(_, let bundleID, _) = item else { return true }
            return !pinned.contains(bundleID)
        }
        XCTAssertEqual(kept.count, 2)
    }

    private func app(_ bundleID: String) -> DockItem {
        .app(id: UUID(), bundleID: bundleID,
             ref: FileRef(url: URL(fileURLWithPath: "/Applications/\(bundleID).app")))
    }
}
