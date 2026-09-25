import AppKit
import SwiftUI

@main
struct PlinthMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Agent app: no Dock tile of our own, no menu bar of our own. Plinth's
        // only permanent UI is its status item.
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var state: AppState!
    private var shelf: DockPanelController!
    private var menuBar: MenuBarController!
    private var observation: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let state = AppState()
        self.state = state

        // A first run with nothing saved should still show something, or the
        // app looks broken. An empty shelf with a visible Add Widget affordance
        // is better than no window at all.
        state.installDefaultProfile()

        // Widgets write their own state through here — see WidgetWriter. An
        // open detail panel holds the instance by value, so it is redrawn from
        // the same funnel rather than left showing what the tile used to say.
        WidgetWriter.update = { [state] instance in
            state.updateWidget(instance)
            WidgetDetailWindow.shared.refresh(instance)
        }

        shelf = DockPanelController(app: state)
        menuBar = MenuBarController(app: state)
        menuBar.onShelfSettingsChanged = { [weak self] in self?.shelf.refresh() }

        applyAppearance()
        if state.state.setup != .macOSDockOnly {
            shelf.show()
        }

        if ProcessInfo.processInfo.environment["PLINTH_OPEN_LIBRARY"] != nil {
            LibraryWindow.shared.show(app: state)
        }
        if let tab = ProcessInfo.processInfo.environment["PLINTH_OPEN_SETTINGS"] {
            SettingsWindow.shared.show(app: state, tab: tab.isEmpty ? "General" : tab)
        }
        if ProcessInfo.processInfo.environment["PLINTH_PROBE_LOCATION"] != nil {
            SettingsWindow.shared.show(app: state)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                LocationService.shared.start()
            }
        }
        SystemDockSettings.shared.start()
        SystemMetrics.shared.start()
        NetworkMetrics.shared.start()
        BatteryMetrics.shared.start()

        observation = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.shelf.refresh() }
        }

        // The Dock's own preferences drive our edge and hiding, so follow them.
        NotificationCenter.default.addObserver(
            forName: Notification.Name("com.apple.dock.prefchanged"), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.shelf.refresh() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        state?.saveNow()
    }

    private func applyAppearance() {
        NSApp.appearance = switch state.state.appearance {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}
