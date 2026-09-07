import AppKit
import SwiftUI

/// Plinth's Settings window.
///
/// It owns no state: the app passes a binding to the single `PersistedState`
/// it already persists, so every edit here is saved by the same code path that
/// saves everything else.
struct SettingsView: View {
    @Binding var state: PersistedState
    /// Which tab opens first. The menu bar and the Dock's own menu both land
    /// on General; a caller with something specific to show can say so.
    var initialTab: String = "General"
    var onApplyMacOSProfile: () -> Void
    var onCaptureCurrentDock: () -> Void

    @State private var tab = "General"


    var body: some View {
        TabView(selection: $tab) {
            Tab("General", systemImage: "gearshape", value: "General") { general }
            Tab("Dock", systemImage: "dock.rectangle", value: "Dock") { dock }
            Tab("Widgets", systemImage: "square.grid.2x2", value: "Widgets") { widgets }
            Tab("About", systemImage: "info.circle", value: "About") { about }
        }
        .frame(width: 520, height: 460)
        .onAppear { tab = initialTab }
    }

    // MARK: - General

    private var general: some View {
        Form {
            Section("Appearance") {
                Picker("App appearance", selection: $state.appearance) {
                    ForEach(AppAppearance.allCases, id: \.self) { Text(title($0)).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Dock setup") {
                Picker("", selection: $state.setup) {
                    ForEach(DockSetup.allCases, id: \.self) { setup in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title(setup))
                            Text(detail(setup))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(setup)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                LabeledContent("macOS Dock") {
                    HStack {
                        Button("Apply Profile", action: onApplyMacOSProfile)
                            .disabled(state.activeMacOSProfile == nil)
                            .help("Write the selected macOS Dock profile to Apple's Dock.")
                        Button("Capture Current Dock…", action: onCaptureCurrentDock)
                            .help("Save Apple's Dock as it is right now into a new profile.")
                    }
                }
            }

            Section("Menu Bar") {
                Toggle("Show menu bar icon", isOn: $state.menuBar.showIcon)
                Picker("Label", selection: $state.menuBar.label) {
                    ForEach(MenuBarLabelMode.allCases, id: \.self) { Text(title($0)).tag($0) }
                }
                .help("Which active profile name is shown next to the menu bar icon.")
            }

            Section {
                HStack {
                    // wired in a later phase
                    Button("Back Up…") {}
                    Button("Restore…") {}
                }
            } header: {
                Text("Saved Docks")
            } footer: {
                Text("A backup contains your saved profiles — names, colours, items and widget configuration — not the apps or files they point to.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Dock

    private var dock: some View {
        Form {
            Section {
                Toggle("Match the macOS Dock", isOn: $state.customDock.followSystemDock)
                    .help("Use the same edge, icon size, magnification and hiding as your real Dock.")
                if state.customDock.followSystemDock {
                    LabeledContent("Currently") {
                        Text(SystemDockSettings.shared.summary)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("Turn this off to place and size Plinth independently of your Dock.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Placement") {
                Picker("Position", selection: $state.customDock.position) {
                    ForEach(DockPosition.allCases, id: \.self) { Text(title($0)).tag($0) }
                .disabled(state.customDock.followSystemDock)
                }
                .pickerStyle(.segmented)

                Picker("Display", selection: $state.customDock.displayID) {
                    Text("Active display").tag(UInt32?.none)
                    ForEach(NSScreen.screens, id: \.self) { screen in
                        if let id = screen.plinthDisplayID {
                            Text(screen.localizedName).tag(UInt32?.some(id))
                        }
                    }
                }
                .help("The Dock follows the pointer's display unless you pin it to one.")

                LabeledContent("Size") {
                    HStack {
                        Slider(value: $state.customDock.scale, in: Geometry.scaleRange)
                            .disabled(state.customDock.followSystemDock)
                        Text("\(Int((state.customDock.scale * 100).rounded()))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }

            Section("Material") {
                Picker("Material", selection: $state.customDock.material) {
                    Text("Frosted").tag(DockMaterial.frosted)
                    Text("Liquid Glass").tag(DockMaterial.liquidGlass)
                }
                .pickerStyle(.segmented)

                Picker("Glass style", selection: $state.customDock.glass) {
                    ForEach(GlassStyle.allCases, id: \.self) { Text(title($0)).tag($0) }
                }
                // Disabled rather than hidden so the section does not resize
                // every time the material changes.
                .disabled(state.customDock.material != .liquidGlass)
                .help("Clear is transparent; Regular keeps a tint. Reduce transparency in Accessibility settings overrides both.")
            }

            Section("Behaviour") {
                Toggle("Automatically hide", isOn: $state.customDock.autoHide)
                    .help("Reveal the Dock when the pointer reaches its screen edge.")
                Toggle("Show handle when hidden", isOn: $state.customDock.showHandleWhenHidden)
                    .disabled(!state.customDock.autoHide)
                    .help("A small visible handle while hidden. The edge still reveals the Dock without it.")
                Toggle("Hide when the macOS Dock appears", isOn: $state.customDock.hideWhenMacOSDockAppears)
                    .help("Gets out of the way when both Docks share a screen edge.")
                Toggle("Use as desktop widget", isOn: $state.customDock.useAsDesktopWidget)
                    .help("Keeps the Dock on the desktop, behind app windows.")
            }

            Section("Contents") {
                Toggle("Show running apps", isOn: $state.customDock.showRunningApps)
                    .help("Include open apps alongside pinned items.")
                Toggle("Show app badges", isOn: $state.customDock.showAppBadges)
                    .help("Mirrors the badges Apple's Dock shows. Requires Accessibility access.")
                Toggle("Show Trash", isOn: $state.customDock.showTrash)
                Toggle("Magnification", isOn: $state.customDock.magnification)
                    .disabled(state.customDock.followSystemDock)
                    .help("Grow icons under the pointer.")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Widgets

    private var widgets: some View {
        Form {
            WidgetSettingsSections(state: $state)

            Section {
                Stepper("Focus", value: $state.timer.work, in: 1...180)
                Stepper("Break", value: $state.timer.rest, in: 1...60)
                Stepper("Long break", value: $state.timer.longBreak, in: 1...180)
                Stepper("Sessions before a long break", value: $state.timer.sessions, in: 1...12)
                LabeledContent("Colour") { swatches }
                Toggle("Alerts", isOn: $state.timer.alerts)
                    .help("Notify when a focus session or break ends.")
            } header: {
                Text("Focus Timer")
            } footer: {
                Text("Every Focus Timer widget shares these settings — Plinth treats them as one timer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var swatches: some View {
        HStack(spacing: 10) {
            ForEach(PaletteColor.picker, id: \.self) { colour in
                Button {
                    state.timer.color = colour
                } label: {
                    Circle()
                        .fill(Color(hex: colour.hex))
                        .frame(width: 18, height: 18)
                        .overlay {
                            Circle()
                                .strokeBorder(.primary.opacity(state.timer.color == colour ? 0.7 : 0), lineWidth: 2)
                                .padding(-3)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(colour.rawValue.capitalized)
            }
        }
    }

    // MARK: - About

    private var about: some View {
        Form {
            Section {
                VStack(spacing: 6) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                    Text("Plinth").font(.title2.weight(.semibold))
                    Text("Version \(shortVersion)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Text("Plinth keeps everything on this Mac, in a single file in Application Support. Nothing is synced.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .formStyle(.grouped)
    }

    private var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}

// MARK: - Labels

private func title(_ value: AppAppearance) -> String {
    switch value {
    case .system: "System"
    case .light: "Light"
    case .dark: "Dark"
    }
}

private func title(_ value: DockSetup) -> String {
    switch value {
    case .macOSDockOnly: "macOS Dock only"
    case .both: "Both"
    case .customReplacement: "Custom Dock replaces the macOS Dock"
    }
}

private func detail(_ value: DockSetup) -> String {
    switch value {
    case .macOSDockOnly: "Save and switch layouts for Apple's Dock. No widgets."
    case .both: "Apple's Dock for apps, a custom Dock beside it for widgets."
    case .customReplacement: "Apps, widgets, folders and links in one Dock. Apple's Dock is auto-hidden."
    }
}

private func title(_ value: DockPosition) -> String {
    switch value {
    case .left: "Left"
    case .bottom: "Bottom"
    case .right: "Right"
    }
}

private func title(_ value: GlassStyle) -> String {
    switch value {
    case .regular: "Regular"
    case .clear: "Clear"
    }
}

private func title(_ value: MenuBarLabelMode) -> String {
    switch value {
    case .none: "No label"
    case .native: "macOS Dock profile"
    case .custom: "Custom Dock profile"
    case .both: "Both profiles"
    }
}

private extension NSScreen {
    /// `CGDirectDisplayID` for this screen, which is what `displayID` stores.
    var plinthDisplayID: UInt32? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32
    }
}
