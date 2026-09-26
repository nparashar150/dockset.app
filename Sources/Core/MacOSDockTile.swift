import Foundation

/// One tile in Apple's Dock.
///
/// The whole original dictionary is kept verbatim as a binary plist. Apple's
/// tile dicts carry opaque fields - alias `book` blobs, `GUID`, `file-mod-date`
/// - that we have no business synthesizing. Capturing and replaying them
/// unchanged is both simpler and far safer than modelling them.
public struct MacOSDockTile: Codable, Hashable, Sendable {
    public var tileType: String
    public var label: String?
    public var bundleID: String?
    public var urlString: String?
    /// Binary plist of the complete tile dictionary.
    public var raw: Data

    public var isSpacer: Bool { tileType.hasSuffix("spacer-tile") }

    /// Stable identity for verifying a write survived the Dock restart.
    public var signature: String { "\(tileType)|\(bundleID ?? urlString ?? "")" }

    public init?(dictionary: [String: Any]) {
        guard let type = dictionary["tile-type"] as? String,
              let data = try? PropertyListSerialization.data(fromPropertyList: dictionary,
                                                             format: .binary, options: 0)
        else { return nil }
        let tileData = dictionary["tile-data"] as? [String: Any] ?? [:]
        self.tileType = type
        self.label = tileData["file-label"] as? String
        self.bundleID = tileData["bundle-identifier"] as? String
        self.urlString = (tileData["file-data"] as? [String: Any])?["_CFURLString"] as? String
        self.raw = data
    }

    public func dictionary() -> [String: Any]? {
        try? PropertyListSerialization.propertyList(from: raw, options: [], format: nil) as? [String: Any]
    }

    /// Synthesize a tile for an app the user pinned inside Docket rather than
    /// one captured from the live Dock. The Dock fills in the rest itself.
    public static func app(url: URL, bundleID: String?, label: String) -> MacOSDockTile? {
        var tileData: [String: Any] = [
            "file-data": [
                "_CFURLString": url.absoluteString,
                "_CFURLStringType": 15,
            ],
            "file-label": label,
            "file-type": 169,
        ]
        if let bundleID { tileData["bundle-identifier"] = bundleID }
        return MacOSDockTile(dictionary: ["tile-data": tileData, "tile-type": "file-tile"])
    }

    public static func spacer(_ size: SpacerSize) -> MacOSDockTile? {
        MacOSDockTile(dictionary: ["tile-data": [String: Any](), "tile-type": size.dockTileType])
    }
}
