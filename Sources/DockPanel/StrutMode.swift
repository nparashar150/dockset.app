import AppKit

/// Borrows Apple's Dock reserved strip so zoomed windows stop at the shelf.
///
/// See `DockStrut` for why this is the only route that works. The short of it
/// is that the Dock is the only thing that can reserve screen space, so the
/// shelf stops competing with it and sits on top of it instead.
///
/// Everything here is about giving it back. Docket is changing settings that
/// belong to the user and that no other app will repair, so the rules are:
/// ask before the first time, write down what was there before changing
/// anything, and treat a recorded snapshot as a debt that gets paid at the
/// next opportunity however the app went away last time.
@MainActor
public enum StrutMode {

    /// Whether the shelf should be borrowing the strip right now.
    public static func wanted(for setup: DockSetup) -> Bool { setup == .customReplacement }

    // MARK: Entering

    /// Takes the strip, if the user agrees, and reports the thickness reserved.
    ///
    /// Returns nil when nothing was claimed, which the caller should treat as
    /// "stay in the previous mode" rather than as a failure to report.
    public static func enter(edge: DockPosition,
                             wanting thickness: CGFloat,
                             state: PersistedState,
                             record: (DockPrefs) -> Void) async -> CGFloat? {
        // Already borrowed. Re-measure rather than re-ask: the Dock may have
        // been restarted by something else since.
        if state.borrowedDockPrefs != nil {
            return DockStrut.thickness(on: edge)
        }
        guard consent(edge: edge) else { return nil }

        // Recorded before anything is written, so an interruption between here
        // and the write still leaves a correct restore.
        let before = DockStrut.snapshot()
        record(before)

        return await DockStrut.claim(edge: edge, tileSize: tileSize(forStrip: thickness))
    }

    // MARK: Leaving

    /// Puts the Dock back, and clears the debt only once that has happened.
    public static func leave(state: PersistedState, clear: @escaping () -> Void) async {
        guard let borrowed = state.borrowedDockPrefs else { return }
        await DockStrut.release(borrowed)
        clear()
    }

    /// Called at launch. A snapshot still recorded means the app went away
    /// without putting the Dock back, so it is put back now.
    ///
    /// Deliberately unconditional on the current mode: if the user has since
    /// switched away from the replacement setup, the debt is still owed.
    public static func repayIfOwed(state: PersistedState,
                                   clear: @escaping () -> Void) async {
        guard state.borrowedDockPrefs != nil, !wanted(for: state.setup) else { return }
        await leave(state: state, clear: clear)
    }

    // MARK: Sizing

    /// See `DockStrutMetrics`, which is where the sizing lives so it can be
    /// tested without building a shelf.
    static func tileSize(forStrip strip: CGFloat) -> Double {
        DockStrutMetrics.tileSize(forStrip: strip)
    }

    // MARK: Consent

    /// Asked once, plainly, because the honest description of this is
    /// "Docket would like to change your Dock settings".
    private static func consent(edge: DockPosition) -> Bool {
        // A modal alert cannot be answered by a test harness, and this is the
        // one path in the app that blocks on a person. The same escape hatch
        // the library and settings windows already use.
        if ProcessInfo.processInfo.environment["DOCKET_STRUT_CONSENT"] != nil { return true }

        let alert = NSAlert()
        alert.messageText = "Let Docket manage your Dock?"
        alert.informativeText = """
            Windows only stop at the shelf if the Dock reserves the space, and \
            only the Dock can do that. Docket will move Apple's Dock to the \
            \(edge.rawValue) edge, stop it hiding, and size it to match the \
            shelf, then cover it.

            Your current Dock settings are saved and put back when you turn \
            this off or quit.
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Manage My Dock")
        alert.addButton(withTitle: "Cancel")
        // An accessory app has no windows of its own to be modal to, and the
        // alert has to come forward or it is answered blind.
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }
}
