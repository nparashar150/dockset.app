import SwiftUI

/// Settings for the widgets actually on the shelf.
///
/// Built from each kind's catalog defaults rather than hand-written per kind:
/// the type of a default decides its control, so every widget gets settings
/// and a new one gets them for free. The Widgets tab previously claimed each
/// widget "keeps its own settings" on the Dock, which was not true anywhere -
/// the twenty-odd show/hide options in the catalog had no UI at all.
struct WidgetSettingsSections: View {
    @Binding var state: PersistedState

    var body: some View {
        if instances.isEmpty {
            Section("Widgets") {
                Label("No widgets on the Dock yet - add one with the + button at the end of it.",
                      systemImage: "square.grid.2x2")
                    .foregroundStyle(.secondary)
            }
        } else {
            ForEach(configurable, id: \.instance.id) { pair in
                Section(pair.entry.name) {
                    if !pair.entry.variants.isEmpty {
                        stylePicker(pair.entry, pair.instance)
                    }
                    ForEach(options(for: pair.entry), id: \.self) { key in
                        control(key, entry: pair.entry, instance: pair.instance)
                    }
                }
            }
        }
    }

    // MARK: Model

    private var profileIndex: Int? {
        guard let id = state.customDock.profileID else { return nil }
        return state.profiles.firstIndex { $0.id == id }
    }

    private var instances: [WidgetInstance] {
        guard let index = profileIndex else { return [] }
        return state.profiles[index].items.compactMap(\.widget)
    }

    /// Only widgets that actually have something to configure.
    ///
    /// A section with nothing in it draws as a lone heading, which reads as a
    /// control that failed to load rather than a widget with no options.
    private var configurable: [(instance: WidgetInstance, entry: WidgetCatalog.Entry)] {
        instances.compactMap { instance in
            guard let entry = WidgetCatalog.entry(instance.kind) else { return nil }
            let hasControls = !entry.variants.isEmpty || !options(for: entry).isEmpty
            return hasControls ? (instance, entry) : nil
        }
    }

    private func write(_ instance: WidgetInstance, _ change: (inout WidgetConfig) -> Void) {
        guard let p = profileIndex,
              let i = state.profiles[p].items.firstIndex(where: { $0.id == instance.id })
        else { return }
        var updated = instance
        change(&updated.config)
        state.profiles[p].items[i] = .widget(updated)
    }

    /// Everything configurable except `layout`, which the style picker owns.
    private func options(for entry: WidgetCatalog.Entry) -> [String] {
        WidgetCatalog.configurableKeys(entry.kind)
    }

    // MARK: Controls

    /// Keyed on the variant's title, not its layout.
    ///
    /// "Numbers" and "Numbers + graph" are both `layout: "numbers"` and differ
    /// only by `chart`, so tagging by layout gave two rows the same tag and
    /// the picker could neither tell them apart nor show the right one.
    private func stylePicker(_ entry: WidgetCatalog.Entry, _ instance: WidgetInstance) -> some View {
        Picker("Style", selection: Binding(
            get: { selectedVariant(entry, instance) },
            set: { title in
                guard let variant = entry.variants.first(where: { $0.title == title }) else { return }
                write(instance) { config in
                    for (key, value) in variant.overrides { config.set(key, value) }
                }
            })) {
                ForEach(entry.variants.indices, id: \.self) { index in
                    Text(entry.variants[index].title).tag(entry.variants[index].title)
                }
            }
    }

    /// The variant whose every override the widget currently matches.
    private func selectedVariant(_ entry: WidgetCatalog.Entry,
                                 _ instance: WidgetInstance) -> String {
        WidgetCatalog.variantTitle(matching: instance.config, kind: entry.kind) ?? ""
    }

    @ViewBuilder
    private func control(_ key: String, entry: WidgetCatalog.Entry,
                         instance: WidgetInstance) -> some View {
        switch entry.defaults.values[key] {
        case .bool:
            Toggle(Self.label(key), isOn: Binding(
                get: { instance.config.bool(key) },
                set: { on in write(instance) { $0.set(key, .bool(on)) } }))

        case .number(let fallback):
            Stepper(value: Binding(
                get: { instance.config.double(key, default: fallback) },
                set: { value in write(instance) { $0.set(key, .number(value)) } }),
                in: Self.range(key), step: Self.step(key)) {
                    LabeledContent(Self.label(key)) {
                        Text(Self.format(key, instance.config.double(key, default: fallback)))
                    }
                }

        case .string:
            TextField(Self.label(key), text: Binding(
                get: { instance.config.string(key) },
                set: { text in write(instance) { $0.set(key, .string(text)) } }),
                prompt: Text(Self.prompt(key)))

        case .list:
            // A list means "which of a fixed set", and the set lives in the
            // widget, not the catalog. Only the two that matter are offered
            // rather than a generic editor nobody could use.
            if let choices = Self.choices[key] {
                ForEach(choices, id: \.value) { choice in
                    Toggle(choice.title, isOn: Binding(
                        get: { instance.config.strings(key).contains(choice.value) },
                        set: { on in
                            var list = instance.config.strings(key)
                            if on { if !list.contains(choice.value) { list.append(choice.value) } }
                            else { list.removeAll { $0 == choice.value } }
                            // Never leave it with nothing to show.
                            guard !list.isEmpty else { return }
                            write(instance) { $0.set(key, .list(list.map { .string($0) })) }
                        }))
                }
            }

        case .none:
            EmptyView()
        }
    }

    // MARK: Presentation

    private func stringValue(_ value: WidgetConfig.Value) -> String {
        if case .string(let text) = value { return text }
        return ""
    }

    /// "showCallButton" -> "Show Call Button".
    static func label(_ key: String) -> String { WidgetCatalog.optionLabel(key) }

    static func prompt(_ key: String) -> String {
        key == "city" ? "Current location" : ""
    }

    static func range(_ key: String) -> ClosedRange<Double> {
        switch key {
        case "duration": 60...14_400
        case "skip": 5...60
        default: 0...1_000
        }
    }

    static func step(_ key: String) -> Double {
        key == "duration" ? 300 : 5
    }

    static func format(_ key: String, _ value: Double) -> String {
        guard key == "duration" else { return "\(Int(value))s" }
        let minutes = Int(value) / 60
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    /// The fixed sets behind the list-valued options.
    static let choices: [String: [(title: String, value: String)]] = [
        "metrics": [("CPU", "cpu"), ("Memory", "memory"),
                    ("Disk", "disk"), ("Battery", "battery")],
        "devices": [("This Mac", "mac"), ("AirPods", "pods"),
                    ("AirPods Case", "case"), ("Keyboard", "keyboard")],
    ]
}
