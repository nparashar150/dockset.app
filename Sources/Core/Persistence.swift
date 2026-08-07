import Foundation

/// Reads and writes the single `state.json` that holds everything Plinth knows.
///
/// No database, no sync, no migration framework — one JSON file the user can
/// read, back up, and delete. `version` exists so a future format change can
/// refuse to silently misread an old file.
public struct Store: Sendable {
    public let url: URL

    public init(bundleID: String = Bundle.main.bundleIdentifier ?? "com.namanparashar.plinth") {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: bundleID, directoryHint: .isDirectory)
        self.url = base.appending(path: "state.json")
    }

    public func load() -> PersistedState {
        guard let data = try? Data(contentsOf: url) else { return PersistedState() }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let state = try decoder.decode(PersistedState.self, from: data)
            // A file from a newer Plinth would decode partially and silently
            // drop what it doesn't understand; refusing is the honest move.
            guard state.version <= PersistedState.currentVersion else { return PersistedState() }
            return state
        } catch {
            // Keep the unreadable file rather than overwriting it — it is the
            // user's only copy of their setup.
            try? FileManager.default.moveItem(at: url, to: url.appendingPathExtension("corrupt"))
            return PersistedState()
        }
    }

    public func save(_ state: PersistedState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        // Atomic: a crash mid-write must not leave a truncated state file.
        try data.write(to: url, options: .atomic)
    }
}
