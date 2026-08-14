import AppKit
import Observation

public struct RunningApp: Identifiable, Sendable, Hashable {
    public var id: String          // bundle identifier
    public var name: String
    public var url: URL?
    public var isActive: Bool
}

/// Knows what is running and what things look like.
///
/// Icon lookup goes through a cache because `NSWorkspace.icon(forFile:)` hits
/// the disk, and the shelf asks for every icon on every layout pass.
@MainActor
@Observable
public final class AppCatalog {
    public static let shared = AppCatalog()

    public private(set) var running: [RunningApp] = []
    /// Membership only, for the hot path.
    ///
    /// `isRunning` is asked once per tile per render — the context menu alone
    /// calls it for every icon on every layout pass — and a linear scan of
    /// `running` there costs hundreds of string compares a frame. Observed,
    /// not ignored, so a launch or quit still invalidates the tiles.
    public private(set) var runningIDs: Set<String> = []

    @ObservationIgnored private var iconCache: [String: NSImage] = [:]
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    private init() {
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didActivateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
    }

    public func refresh() {
        running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .map {
                RunningApp(id: $0.bundleIdentifier!,
                           name: $0.localizedName ?? $0.bundleIdentifier!,
                           url: $0.bundleURL,
                           isActive: $0.isActive)
            }
        runningIDs = Set(running.map(\.id))
    }

    public func isRunning(bundleID: String) -> Bool {
        !bundleID.isEmpty && runningIDs.contains(bundleID)
    }

    /// Apps that are running but not pinned to the given profile — the shelf
    /// shows these after a separator, exactly like Apple's Dock.
    public func unpinned(from items: [DockItem]) -> [RunningApp] {
        let pinned = Set(items.compactMap { item -> String? in
            if case .app(_, let bundleID, _) = item { return bundleID }
            return nil
        })
        return running.filter { !pinned.contains($0.id) }
    }

    public func icon(for url: URL) -> NSImage {
        let key = url.path(percentEncoded: false)
        if let cached = iconCache[key] { return cached }
        let icon = NSWorkspace.shared.icon(forFile: key)
        icon.size = NSSize(width: 128, height: 128)
        iconCache[key] = icon
        return icon
    }

    public func icon(forBundleID bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return icon(for: url)
    }

    // MARK: Actions

    public func activate(bundleID: String) -> Bool {
        guard let app = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID).first else { return false }
        return app.activate(options: [])
    }

    /// Opens an item, reporting when the launch has settled.
    ///
    /// The completion is what stops a launch bounce. Polling for the app in
    /// `running` instead was wrong twice over: that list is filtered to
    /// `activationPolicy == .regular`, so anything that opens without
    /// registering as an ordinary app never satisfied it, and a path that
    /// fails to resolve launches nothing at all — both left the tile bouncing
    /// until its give-up timer while the app was plainly open.
    public func open(_ item: DockItem,
                     completion: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        func done(_ ok: Bool) { completion?(ok) }

        switch item {
        case .app(_, let bundleID, let ref):
            // Already running? Bring it forward rather than bouncing a new launch.
            if !bundleID.isEmpty, activate(bundleID: bundleID) { return done(true) }
            guard let url = ref.resolve() else { return done(false) }
            NSWorkspace.shared.openApplication(at: url, configuration: .init()) { app, _ in
                let launched = app != nil
                Task { @MainActor in completion?(launched) }
            }
        case .folder(_, let ref, _), .file(_, let ref):
            guard let url = ref.resolve() else { return done(false) }
            NSWorkspace.shared.open(url)
            done(true)
        case .link(_, let url, _):
            NSWorkspace.shared.open(url)
            done(true)
        // A group is expanded by the shelf, not opened by the workspace.
        case .spacer, .widget, .group:
            done(false)
        }
    }

    /// Opens whatever a widget points at.
    public func open(_ target: WidgetTarget) {
        switch target {
        case .app(let bundleID):
            if activate(bundleID: bundleID) { return }
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            else { return }
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        case .settings:
            guard let url = target.settingsURL else { return }
            NSWorkspace.shared.open(url)
        }
    }

    /// Asks an app to quit, the way the Dock's own menu does.
    ///
    /// `terminate()` rather than `forceTerminate()`: a document with unsaved
    /// changes must still get its chance to object.
    public func quit(bundleID: String) {
        for running in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
            running.terminate()
        }
    }

    public func reveal(_ item: DockItem) {
        guard let url = item.fileRef?.resolve() else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
