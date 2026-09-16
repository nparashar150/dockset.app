import AppKit
import Observation

/// An icon being dragged out of an opened group.
///
/// The group sheet and the shelf are two separate `NSWindow`s, so they share
/// no SwiftUI hierarchy — no `Namespace`, no `matchedGeometryEffect`, no
/// gesture that spans both. This is the channel between them: the sheet
/// publishes where the icon currently is, and the shelf reads it to open a
/// gap under it, so the drag reads as one gesture across two windows.
@MainActor
@Observable
final class DragOut {
    static let shared = DragOut()

    /// The item in flight, or nil when nothing is being dragged out.
    private(set) var item: DockItem?
    /// The group it came from.
    private(set) var group: UUID?
    /// Where the pointer is, in screen coordinates.
    private(set) var location: CGPoint = .zero
    /// Whether the pointer has left the sheet — only then does the shelf make
    /// room, or an icon nudged inside its own folder would part the row.
    private(set) var outside = false

    private init() {}

    func begin(_ item: DockItem, from group: UUID) {
        self.item = item
        self.group = group
    }

    func update(location: CGPoint, outside: Bool) {
        self.location = location
        self.outside = outside
    }

    func end() {
        item = nil
        group = nil
        outside = false
    }

    var isCarrying: Bool { item != nil && outside }
}
