# Dockset — Consolidated Product Spec

*Reverse-engineered from five area analyses; reconciled into one implementable build target. Swift 6.3 / SwiftUI + AppKit.*

---

## 1. Product summary

Dockset is a non-sandboxed macOS menu-bar agent that does two separate things under one name: it **saves and applies layouts for Apple's own Dock** (pinned apps + spacers, written to `com.apple.dock` and applied with a Dock restart), and it **draws its own floating "Custom Dock"** — a Liquid-Glass/Frosted shelf pinned to a screen edge that holds apps, folders, files, links, spacers, and a library of 24 first-party widgets.

Each surface has its own independently-selected *profile*; a global three-way **Dock setup** (`macOS Dock only` / `Both` / `Custom Dock + auto-hide macOS Dock`) decides which surfaces exist. Profiles switch from the menu bar, a global hotkey (≥2 modifiers), a two-finger cross-axis swipe over the Dock, or a macOS Focus Filter.

Widgets range from self-contained (clock, timer, sticky note, system activity) to permission-gated (Calendar, Reminders, Now Playing) to network-backed revenue dashboards (Stripe, Paddle, Shopify) and AI-allowance meters (Codex, Claude, Grok).

Everything is local: no account, no cloud sync, no analytics. Credentials live in Keychain, profiles in Application Support, transfer is a manual **Back Up… / Restore…** file. It's a one-time purchase (1/2/3 device slots) validated against a hashed license + hashed random installation id.

---

## 2. Feature inventory

Legend: **CORE** = product is meaningless without it · **MAJOR** = a headline feature users bought it for · **NICE** = polish or long-tail.

### 2.1 Custom Dock

| Feature | Tier | Notes |
|---|---|---|
| Floating borderless Dock window on a chosen screen edge | CORE | `NSPanel`, `.nonactivatingPanel`, level above Apple's Dock |
| Position: Left / Bottom / Right (**no Top**) | CORE | drives vertical vs horizontal tile geometry |
| Display picker (which `NSScreen`) | CORE | exactly one Custom Dock visible at a time regardless of profile count |
| Item kinds: app, folder, file, link, spacer, widget | CORE | add menu: `Widget… / Apps… / Folders… / Files… / Link… / Spacer` |
| Drag reorder + keyboard reorder (Option + arrows) | CORE | a11y label: "Drag to reorder, or use Alt and arrow keys." |
| Size: slider 25–150 % **and** drag-the-grip resize | CORE | scale 0.25…1.5, default 0.35, stored per profile |
| Show running apps (unpinned, after a separator) + running dot | CORE | `running`, default true |
| Keep in Dock / Remove from Dock context actions | CORE | appends deduplicated to active profile |
| Automatically hide + edge reveal | MAJOR | default **true** for new replacement-mode Docks, else false |
| Show handle when hidden (reveal pill) | MAJOR | `revealHandle`, default true; only meaningful with auto-hide on |
| Hide when macOS Dock appears | MAJOR | `hideWithNative`, default false; same-edge cohabitation only |
| Window fitting (maximized windows leave room) | MAJOR | requires Accessibility; auto-hide off only |
| Use as desktop widget (render **behind** app windows) | MAJOR | v0.2.3; desktop window level |
| Item overflow scrolling along the long axis | MAJOR | distinct from the cross-axis profile swipe |
| Show Trash (native empty/full icons, Open + Empty) | NICE | polled, not observed |
| App badges mirrored from Apple's Dock | NICE | separate Accessibility opt-in; labels only |
| Magnification (gentler for widgets) | NICE | v0.2.5, off by default; curve undocumented |
| Folder icon customization (tint + 1 character + Reset) | NICE | Dockset-drawn only, never touches disk |
| Files droppable onto tiles (AirDrop) | NICE | makes the Dock an external drag destination |
| Fullscreen priority over Apple's Dock + dwell-to-reveal | NICE | v0.2.2 |

### 2.2 Native (macOS) Dock layouts

| Feature | Tier | Notes |
|---|---|---|
| Create from Current Dock (non-destructive capture) | CORE | apps + spacers only |
| Apply a saved layout to `com.apple.dock` + Dock restart | CORE | `persistent-apps`, `killall Dock` |
| Small / Regular spacer tiles | CORE | `small-spacer-tile` / `spacer-tile` |
| "No profile" — leave the live Dock untouched | CORE | |
| Queued, ordered application; verify after restart; rollback on failure | MAJOR | v0.1.2 / v0.2.0 |
| Replace with Current Dock… (overwrite a profile, confirmed) | MAJOR | |
| Automatically save Dock changes (live Dock → active profile) | MAJOR | default off (inferred) |
| Smooth switching (wallpaper still held over the restart) | NICE | Screen Recording, macOS 14+, strictly optional |
| Finder cannot be removed from the macOS Dock | NICE | special-case the context menu |

### 2.3 Profiles (shared by both surfaces)

| Feature | Tier | Notes |
|---|---|---|
| Two independent kinds + two independent active selections | CORE | `macOSDock`, `customDock` |
| Name + color (10-swatch palette) | CORE | colored dot in the menu |
| New profile → macOS Dock \| Custom Dock | CORE | |
| Inline rename (click name, Return commits, Esc cancels) | CORE | |
| Save Changes / Apply Changes / Use this profile state machine | CORE | saving an inactive profile never switches the Mac |
| Per-profile scale travels with the Custom Dock profile | MAJOR | selecting a profile writes its scale into the live value |
| Delete / Duplicate | MAJOR | implied but undocumented — build it |
| First-run: Create from Current Dock \| Start Empty | MAJOR | |
| First-time walkthrough (setup → widgets → preview), replayable from About | NICE | v0.2.4 |

### 2.4 Widgets

| Feature | Tier | Notes |
|---|---|---|
| Widget library: categories + substring search, preview-variant cards | CORE | one card per (kind, previewLayout) |
| Per-widget config persisted inside the profile item | CORE | deep-copied from catalog defaults on instantiation |
| Tile render path vs detail-popup render path vs customization form | CORE | "only the tile scales; detail controls stay full size" |
| Compact/expanded collapse (`supportsCompact`) | MAJOR | |
| 24 widget kinds | MAJOR each | see §3 |
| Widgets exist **only** on Custom Docks | CORE constraint | top troubleshooting question |
| Apple/WidgetKit widgets explicitly unsupported | CORE constraint | |

### 2.5 Integrations (Business + AI)

| Feature | Tier | Notes |
|---|---|---|
| Stripe (restricted key, Balance:Read + Subscriptions:Read) | MAJOR | 6 metrics, 10 periods, USD/EUR/GBP |
| Paddle Billing (`metrics.read`) | MAJOR | 3 metrics, 6 periods, UTC days, Classic unsupported |
| Shopify custom app (`read_orders`, client id + secret + shop domain) | MAJOR | 12 metrics, 8 periods, store timezone, 10 000-order ceiling |
| Multi-account per provider; name (≤80) + 8-swatch tint | MAJOR | |
| 5-minute auto refresh while active + manual Refresh | MAJOR | stale values stay visible on failure |
| Dithered Bayer chart (tile + 332×110 popup) | MAJOR | |
| Keychain storage, Disconnect deletes locally, never exported | CORE | |
| AI Usage: Codex / Claude / Grok allowance windows | MAJOR | |
| AI Usage local Activity (sessions / tool calls / tokens, 4 periods) | NICE | Codex + Claude only |
| Claude status-line hook install/restore + Desktop cookie fallback | NICE | highest-risk integration in the product |

### 2.6 Appearance

| Feature | Tier | Notes |
|---|---|---|
| Material: Frosted (default) / Liquid Glass (macOS 26+) | MAJOR | per Custom Dock, never migrated |
| Glass style: Regular / Clear (Liquid Glass only) | MAJOR | full transparency needs both |
| App appearance: System / Light / Dark (app-wide, not in profiles) | MAJOR | |
| Honour Reduce transparency (force opaque) + Increase contrast, live | MAJOR | and *explain* the override in the troubleshooting copy |
| Scaled chrome geometry (padding, radius, gaps, grip) | MAJOR | see §5 |

### 2.7 Automation / Focus / Input

| Feature | Tier | Notes |
|---|---|---|
| Menu bar `NSStatusItem` with profile sections + Manage Docks…/Settings…/Add widgets…/Activate Dockset… | CORE | |
| Menu bar label modes: none / native / custom / both (`A · B`) | NICE | collapses when setup leaves `.both` |
| Global shortcut per profile, ≥2 modifiers, Esc/Delete clears | MAJOR | |
| Two-finger cross-axis swipe switches profiles; mouse wheel must **not** | MAJOR | precise deltas + phase required |
| Right-click Dock → Switch Profile | MAJOR | |
| Focus Filter "Switch Dock" (`SetFocusFilterIntent`) | MAJOR | applies **saved** items; deactivation is a deliberate no-op |

### 2.8 Licensing / distribution

| Feature | Tier | Notes |
|---|---|---|
| Activation window + `Activate Dockset…` menu item | CORE (commercially) | |
| Random per-installation UUID, sent hashed — never IOPlatformUUID/serial/hostname | CORE | stated privacy commitment |
| Device limit 1/2/3, server-enforced, unlink frees a slot | MAJOR | identical features across tiers |
| Periodic check + limited offline grace + revoked handling | MAJOR | grace length unspecified |
| Update eligibility = 1 year from purchase | NICE | updater technology unnamed |
| DMG, Developer ID + notarized, universal, **not sandboxed** | CORE | |

### 2.9 Backup

| Feature | Tier | Notes |
|---|---|---|
| Back Up… → file with both profile kinds (names, colors, items, widget config) | MAJOR | |
| Restore… → **append-only**, never replaces, never switches active Dock | MAJOR | repeated restores duplicate |
| Excluded: credentials, license, shortcuts, app-wide appearance | MAJOR | |
| Post-restore repair checklist surfaced in Manage Docks | NICE | dead paths should be visible, not silently dropped |

---

## 3. Widget catalog

All sizes in **native points**, as `W×H (compact W)`. Effective rendered size: horizontal Dock → `expanded ? W : compact` wide × **62 tall always**; vertical Dock → **76 wide always** × `expanded ? H : 62`. `expanded = item.expanded || !supportsCompact`.

| # | Kind | Name / Category | Natural size | Variants (library previews) | Options | Data source | Net | Permission | Self-contained |
|---|---|---|---|---|---|---|:-:|---|:-:|
| 1 | `clock` | Clock / Clocks | 168×132 (88) | — | none | system clock | — | — | ✅ |
| 2 | `world` | World Clock / Clocks | 168×132 (88) | — | `city`, `zone` (picker lives in detail) | IANA tz db | — | — | ✅ |
| 3 | `stopwatch` | Stopwatch / Clocks | 168×80 (120) | — | none | local timer | — | — | ✅ |
| 4 | `timer` | Focus Timer / Clocks | 168×124 (88) | — | work/break/longBreak/sessions, color, alerts | local | — | Notifications | ✅ |
| 5 | `progress` | Time Progress / Clocks | bars 176×78 · ring 148×76 · pct 112×62 (88) | Bars / Ring / Percentage | `period` day\|month\|year | calendar math | — | — | ✅ |
| 6 | `countdown` | Countdown / Clocks | 140×72, no compact | — | duration, name, presets[] | local | — | Notifications | ✅ |
| 7 | `alarm` | Alarm / Clocks | 168×124, no compact | — | `time` HH:mm, `name` | local | — | Notifications | ✅ |
| 8 | `hydration` | Hydration / Reminders | 168×124, no compact | — | `duration` (default 2700 s) | local | — | Notifications | ✅ |
| 9 | `calendar` | Calendar / Calendar | date 88×76 · nextEvent 168×132 (88) · dateAndEvent 244×132 · agenda 300×132 | Next event / Date + next event / Date + agenda / Date | `layout`, `allDay`, `showCallButton`, `calendars[]` | EventKit | (join link) | **Calendars (full)** | ❌ |
| 10 | `reminders` | Reminders / Reminders | list 220×132 · next 180×132 · count 88×76 (88 except count) | List / Next reminder / Count | `layout`, `list` (or "All lists") | EventKit (read **+ write**) | — | **Reminders (full)** | ❌ |
| 11 | `notes` | Sticky Note / Notes→"Sticky Notes" | 160×100, no compact | — | `text` (16 KiB JSON cap), `color` (6 papers) | local | — | — | ✅ |
| 12 | `music` | Now Playing / Media | mini 64×62 · full 264×132, no compact | Full / Mini | sources (spotify, apple), previous/next/backward/forward, `skip` 5\|10\|15\|30\|60, hideWhenClosed | AppleEvents → Spotify / Music | artwork URL | **Automation** (per app) | ❌ |
| 13 | `battery` | Battery / System | 1 device+status: 168×132 (88); else `n*44+(n-1)*8+20` × (n>2 ? 116 : 62), no compact | Status / Percentage ring / Icon only | `devices[]` mac, pods, case, keyboard | IOKit power + Bluetooth | — | — | ✅ |
| 14 | `system` | System Activity / System | bars: 168 wide; else `n*(rings?66:70)` × `n*(rings?60:46)+16` (88) | Numbers / Rings / Bars | `metrics[]` cpu, memory, disk (≥1) | host_statistics / sysctl / URLResource | — | — | ✅ |
| 15 | `network` | Network Activity / System | chart 160×84 · plain 100×62 (110); compact only when chart | Numbers only / With chart | `display` both\|download\|upload, `chart`, `popupChart` | `getifaddrs` counters | — | — | ✅ |
| 16 | `ai-usage` | AI Usage / System | 192×132 (88) | Numbers / Rings / Bars | `providers[]` (≥1), `activityPeriod` | Codex local server, Claude status-line + Desktop cookies, Grok CLI | ✅ | **Keychain prompt** (Claude Desktop) | ❌ |
| 17 | `shortcut` | Shortcut / System | 140×76, no compact | — | `name` (detail-only UI) | Shortcuts.app | — | inherits shortcut's own | ⚠️ |
| 18 | `airdrop` | AirDrop / System | 100×76, no compact | — | none | `NSSharingService(.sendViaAirDrop)` | — | — | ✅ |
| 19 | `weather` | Weather / Weather | hourly 216×132 · else 148×132 (88) | Current / Conditions / Hourly forecast | `city`, `zone`, `fahrenheit`, `layout` | MET Norway Locationforecast | ✅ | **Location** (optional) | ❌ |
| 20 | `stripe` | Stripe / Business | chart 200×144 · plain 148×108, no compact | With chart / Number only | metric ×6, period ×10, currency USD\|EUR\|GBP, chart, popupChart, account, color | Stripe API (restricted key) | ✅ | Keychain only | ❌ |
| 21 | `paddle` | Paddle / Business | chart 200×144 · plain 148×108, no compact | With chart / Number only | metric ×3, period ×6, chart, popupChart, account | Paddle Billing metrics | ✅ | Keychain only | ❌ |
| 22 | `shopify` | Shopify / Business | **200×132 always**, no compact | With chart / Number only | metric ×12, period ×8, chart, popupChart, account, color | Shopify Admin API | ✅ | Keychain only | ❌ |
| 23 | `stock` | Stock / Stocks | 192×132 (88) | (style/metric driven) | `symbols[1]`, `names{}`, `period`, `refresh` 300 s, `metric` percentage\|price\|marketCap, `currency`, `reference`, `volume`, `chart`, `style` dithered, `sort` | quote provider (unnamed) | ✅ | — | ❌ |
| 24 | `watchlist` | Watchlist / Stocks | 276×176, no compact | (same as stock) | same config, `symbols[AAPL,MSFT,NVDA]` | quote provider | ✅ | — | ❌ |

**Self-contained set (ship first, zero permissions, zero network):** clock, world, stopwatch, timer, progress, countdown, alarm, hydration, notes, battery, system, network, airdrop. That's **13 of 24** — a genuinely useful v1 widget library with no TCC surface at all.

**Category order:** Clocks, Reminders, Calendar, Notes (displayed "Sticky Notes"), Media, System, Weather, Business, Stocks, plus pseudo-category `All`.

---

## 4. Data model

### 4.1 Top level

```swift
enum DockSetup: String, Codable {
    case macOSDockOnly = "native"   // Apple's Dock only; no widgets possible
    case both                       // both surfaces; recommended default
    case customReplacement = "custom" // custom Dock + Apple's Dock auto-hidden
}

enum DockPosition: String, Codable, CaseIterable {
    case left, bottom, right        // no .top
    var isVertical: Bool { self != .bottom }
}

enum ProfileKind: String, Codable { case macOSDock, customDock }

enum AppAppearance: String, Codable { case system, light, dark }   // app-wide, not backed up

enum DockMaterial: String, Codable { case liquidGlass, frosted }   // default .frosted
enum GlassStyle:  String, Codable { case regular, clear }          // ignored when .frosted

enum MenuBarLabelMode: String, Codable { case none, native, custom, both }

enum SpacerSize: String, Codable {
    case small, regular
    var dockTileType: String { self == .small ? "small-spacer-tile" : "spacer-tile" }
}
```

### 4.2 Palettes

```swift
enum PaletteColor: String, Codable, CaseIterable {
    case orange, yellow, pink, purple, blue, green, graphite, indigo, red, teal
    var hex: String {
        switch self {
        case .orange:   "#FF8D28"
        case .yellow:   "#FFCC00"
        case .pink:     "#FF2D55"
        case .purple:   "#CB30E0"
        case .blue:     "#0088FF"
        case .green:    "#34C759"
        case .graphite: "#8E8E93"
        case .indigo:   "#6155F5"
        case .red:      "#FF383C"
        case .teal:     "#00C3D0"
        }
    }
    /// The 8-swatch picker used by Focus Timer colour and every Business widget accent.
    static let picker: [PaletteColor] = [.orange, .red, .pink, .purple, .indigo, .blue, .teal, .green]
}

enum PaperColor: String, Codable, CaseIterable {
    case yellow, orange, pink, purple, blue, green, graphite
    var hex: String {
        switch self {
        case .yellow:   "#F5D15C"
        case .orange:   "#FFB36E"
        case .pink:     "#F5A3BA"
        case .purple:   "#C7ADEE"
        case .blue:     "#96C7F5"
        case .green:    "#ADD985"
        case .graphite: "#CFCCC2"   // exists but is NOT offered in the note picker
        }
    }
    static let picker: [PaperColor] = [.yellow, .orange, .pink, .purple, .blue, .green]
}

enum MetricColor {  // System Activity
    static let cpu     = "#CE32E3"
    static let memory  = "#078AFF"
    static let storage = "#FF9F0A"
    static let batteryPresent = "#34C759"
    static let netDownload = "#078AFF"     // solid, width 1.5 tile / 2 detail
    static let netUpload   = "#AF52DE"     // dashed 3 2
}
```

### 4.3 Profiles and items

```swift
struct DockProfile: Codable, Identifiable, Hashable {
    var id: UUID
    var kind: ProfileKind
    var name: String                  // inline-editable, Return commits, Esc cancels
    var color: PaletteColor
    var items: [DockItem]             // ordered; macOSDock may only hold .app and .spacer
    var scale: Double = 0.35          // 0.25…1.5, travels with a customDock profile
    var shortcut: KeyCombo?           // >= 2 modifiers
    var focusFilterID: String?        // linked macOS Focus (not confirmed to be backed up)
}

enum DockItem: Codable, Identifiable, Hashable {
    case app(bundleID: String, bookmark: Data)
    case folder(bookmark: Data, icon: FolderIcon?)
    case file(bookmark: Data)
    case link(url: URL, title: String)
    case spacer(SpacerSize)
    case widget(WidgetInstance)
    // Running-but-unpinned apps are appended AFTER `items` as transient entries
    // and are only persisted once the user picks "Keep in Dock".
}

struct FolderIcon: Codable, Hashable {
    var color: PaletteColor?          // nil == "System color"
    var letter: Character?            // exactly 1 letter or digit; "Reset icon" clears both
}

struct WidgetInstance: Codable, Identifiable, Hashable {
    var id: UUID
    var kind: WidgetKind
    var expanded: Bool = true         // new widgets always start expanded
    var config: WidgetConfig          // DEEP-copied from the catalog default on creation
}
```

### 4.4 Settings

```swift
struct CustomDockSettings: Codable {
    var profileID: UUID?                  // nil -> the Custom Dock renders NOTHING
    var position: DockPosition = .bottom
    var displayID: CGDirectDisplayID?
    var scale: Double = 0.35              // live value; mirrors the active profile's scale
    var material: DockMaterial = .frosted
    var glass: GlassStyle = .regular
    var autoHide: Bool = false            // true by default for NEW replacement-mode Docks
    var showHandleWhenHidden: Bool = true
    var useAsDesktopWidget: Bool = false
    var hideWhenMacOSDockAppears: Bool = false
    var showRunningApps: Bool = true
    var showTrash: Bool = false
    var showAppBadges: Bool = true        // requires Accessibility
    var magnification: Bool = false
}

struct MacOSDockSettings: Codable {
    var profileID: UUID?                  // nil == "No profile": leave the live Dock alone
    var smoothSwitching: Bool = false     // needs Screen Recording, macOS 14+
    var autoSaveLiveDockChanges: Bool = false
}

struct MenuBarSettings: Codable {
    var showIcon: Bool = true
    var label: MenuBarLabelMode = .custom
}

struct PersistedState: Codable {
    var version: Int = 4                  // schema version for migration
    var setup: DockSetup = .both
    var appearance: AppAppearance = .system
    var custom: CustomDockSettings
    var native: MacOSDockSettings
    var menuBar: MenuBarSettings
    var profiles: [UUID: DockProfile]
    var widgets: [UUID: WidgetInstance]
}

struct BackupBundle: Codable {
    var formatVersion: Int
    var profiles: [DockProfile]   // both kinds, incl. widget configuration
    // Excludes: Keychain credentials, license/installation id, shortcuts, app appearance.
    // Restore ALWAYS appends copies with fresh UUIDs; never merges, never switches active Dock.
}
```

### 4.5 Widget kinds and per-kind config

```swift
enum WidgetKind: String, Codable, CaseIterable {
    // Registry order drives library order.
    case clock, world, stopwatch, timer, progress, countdown, alarm
    case hydration, calendar, reminders, notes, music, battery, system
    case network, aiUsage = "ai-usage", shortcut, airdrop, weather
    case stripe, paddle, stock, watchlist, shopify
}

enum WidgetCategory: String, Codable {
    case clocks = "Clocks", reminders = "Reminders", calendar = "Calendar"
    case notes = "Notes"          // displayed in the library as "Sticky Notes"
    case media = "Media", system = "System", weather = "Weather"
    case business = "Business", stocks = "Stocks"
}
```

```swift
// --- Clocks ------------------------------------------------------------
struct WorldConfig: Codable { var city = "London"; var zone = "Europe/London" }

enum TimerPhase: String, Codable { case focus, `break`, long }
struct TimerState: Codable {           // SHARED state, not per-instance config
    var work = 25, breakMin = 5, longBreak = 15, sessions = 4   // min 1; max 180/60/180/12
    var phase: TimerPhase = .focus
    var completed = 0
    var color: PaletteColor = .indigo
    var alerts = true
    var deadline: Date?; var paused: TimeInterval?; var duration: TimeInterval?
}

enum ProgressPeriod: String, Codable { case day, month, year }
enum ProgressLayout: String, Codable { case bars, percentage, ring }
struct ProgressConfig: Codable { var layout: ProgressLayout = .bars; var period: ProgressPeriod = .year }

struct CountdownPreset: Codable, Hashable { var name: String; var duration: TimeInterval }
struct CountdownConfig: Codable {
    var duration: TimeInterval = 300; var name = ""            // name max 80
    var deadline: Date?; var paused: TimeInterval?
    var presets: [CountdownPreset] = []
}

struct AlarmConfig: Codable { var time = "14:30"; var name = "Call Alex"; var deadline: Date? }
struct HydrationConfig: Codable { var duration: TimeInterval = 2700; var deadline: Date?; var paused: TimeInterval? }

// --- Calendar / Reminders ---------------------------------------------
enum CalendarLayout: String, Codable { case date, nextEvent, dateAndEvent, agenda }
struct CalendarConfig: Codable {
    var layout: CalendarLayout = .nextEvent
    var allDay = true
    var showCallButton = true          // evaluated as `!= false`
    var calendars: [String] = []       // EKCalendar identifiers; default = all
}
enum CallProvider: String, Codable { case googleMeet, zoom, microsoftTeams }

enum ReminderLayout: String, Codable { case list, next, count }
struct RemindersConfig: Codable {
    var layout: ReminderLayout = .list
    var list = "Personal"              // or the sentinel "All lists"
}

// --- Notes / Media -----------------------------------------------------
struct NotesConfig: Codable {
    var text = "Pick up coffee\nCall Alex"
    var color: PaperColor = .yellow
    var isValid: Bool {                // hard 16 KiB ceiling on the encoded pair
        (try? JSONEncoder().encode(self))?.count ?? .max <= 16_384
    }
}

enum SkipInterval: Int, Codable, CaseIterable { case s5 = 5, s10 = 10, s15 = 15, s30 = 30, s60 = 60 }
struct MusicConfig: Codable {
    var mini = false
    var previous = true, next = true, backward = false, forward = false
    var skip: SkipInterval = .s15
    var spotify = true, apple = true
    var hideWhenClosed = false          // key name inferred
}

// --- System ------------------------------------------------------------
enum BatteryLayout: String, Codable { case status, gauge, icon }
enum BatteryDevice: String, Codable, CaseIterable { case mac, pods, case_ = "case", keyboard }
struct BatteryConfig: Codable { var layout: BatteryLayout = .status; var devices: [BatteryDevice] = BatteryDevice.allCases }

enum SystemLayout: String, Codable { case numbers, rings, bars }
enum SystemMetric: String, Codable { case cpu, memory, disk }   // titles CPU / Memory / Storage
struct SystemConfig: Codable { var layout: SystemLayout = .numbers; var metrics: [SystemMetric] = [.cpu, .memory] }  // >= 1

enum NetworkDisplay: String, Codable { case both, download, upload }
struct NetworkConfig: Codable { var display: NetworkDisplay = .both; var chart = false; var popupChart = true }

enum AIUsageLayout: String, Codable { case numbers, rings, bars }
enum AIProvider: String, Codable, CaseIterable { case codex = "Codex", claude = "Claude", grok = "Grok" }
enum ActivityPeriod: String, Codable {
    case today, last7, last30, month
    var title: String { ["today":"Today","last7":"Last 7 days","last30":"Last 30 days","month":"This month"][rawValue]! }
    var days: Int { switch self { case .today: 1; case .last7: 7; case .last30: 30
                                  case .month: Calendar.current.component(.day, from: .now) } }
}
struct AIUsageConfig: Codable {
    var layout: AIUsageLayout = .numbers
    var providers: [AIProvider] = AIProvider.allCases   // INVARIANT: never empty
    var activityPeriod: ActivityPeriod = .today
}
struct UsageWindow { var label: String; var percentRemaining: Int; var resetsAt: Date }
struct ActivityDay { var date: Date; var sessions: Int; var tools: Int; var tokens: Int }
struct ClaudeConnection {
    var statusLineHookInstalled = false
    var previousStatusLineCommand: String?   // restored on disconnect only if unchanged
    var desktopFallbackEnabled = false
    static let desktopRefresh: TimeInterval = 300
    static let stalenessCutoff: TimeInterval = 600   // older -> render "-"
}

struct ShortcutConfig: Codable { var name = "My shortcut" }

// --- Weather -----------------------------------------------------------
enum WeatherLayout: String, Codable { case current, conditions, hourly }
struct WeatherConfig: Codable {
    var layout: WeatherLayout = .current
    var fahrenheit = false
    var city = "Oslo"; var zone: String?          // IANA, stored with the picked place
    var latitude: Double?; var longitude: Double? // needed for MET Norway
}

// --- Business ----------------------------------------------------------
enum BusinessProvider: String, Codable { case stripe, paddle, shopify }

enum StripeMetric: String, Codable, CaseIterable { case revenue, net, mrr, arr, subscribers, arpu }
enum PaddleMetric: String, Codable, CaseIterable { case revenue, mrr, arr }   // .revenue titled "Net revenue"
enum ShopifyMetric: String, Codable, CaseIterable {
    case sales, netSales, orders, averageOrderValue, returns, visitors
    case sessions, pageviews, conversionRate, addedToCart, reachedCheckout, completedCheckout
}

enum BusinessPeriod: String, Codable {
    case today, week, month, thirtyDays, fourWeeks, sixtyDays, ninetyDays
    case sixMonths, twelveMonths, quarter, year, lastYear, allTime
}

let businessPeriods: [BusinessProvider: [BusinessPeriod]] = [
    .shopify: [.today, .week, .month, .thirtyDays, .sixtyDays, .ninetyDays, .year, .lastYear],
    .stripe:  [.today, .week, .thirtyDays, .fourWeeks, .sixMonths, .twelveMonths, .month, .quarter, .year, .allTime],
    .paddle:  [.today, .week, .month, .thirtyDays, .year, .twelveMonths]
]

struct BusinessWidgetConfig: Codable {
    var accountID: UUID?
    var account: String                 // display name, max 80
    var color: PaletteColor?            // nil -> stripe .indigo, shopify .green, paddle .yellow
    var metric: String                  // provider-specific raw value
    var period: BusinessPeriod
    var currency = "USD"                // Stripe only: USD | EUR | GBP
    var chart = true                    // "Chart in Dock"
    var popupChart = true               // "Chart in popup"
    var updated: Date?
}

struct BusinessAccount: Codable, Identifiable {
    let id: UUID
    var provider: BusinessProvider
    var name: String
    var color: PaletteColor
    var isSandbox: Bool                 // surfaced in the UI; never shows live sales
    // Credentials live in Keychain keyed by `id`, never here, never in a backup.
}

enum BusinessError: Error {
    case permissionDenied(missingScope: String)
    case credentialsRejected
    case keyExpiredOrRevoked
    case rateLimited
    case serviceError
    case network
    case reportTooLarge(limit: Int = 10_000)      // Shopify: error, never a partial total
    case metricNotCalculable(explanation: String) // Stripe complex pricing/tax
}

enum BusinessConnectionState {
    case disconnected
    case connecting
    case connected(lastUpdated: Date, series: BusinessSeries)
    case staleWithError(lastUpdated: Date, lastGood: BusinessSeries, error: BusinessError)
    case unavailable(explanation: String)
}

// --- Stocks ------------------------------------------------------------
struct StockConfig: Codable {
    var symbols: [String] = ["AAPL"]          // watchlist default ["AAPL","MSFT","NVDA"]
    var names: [String: String] = [:]
    var name = ""
    var period = "1D"
    var refresh: TimeInterval = 300
    var metric = "percentage"                 // percentage | price | marketCap
    var currency = false, reference = true, volume = false, chart = true
    var style = "dithered"
    var sort = "manual"
}
```

### 4.6 Licensing

```swift
enum LicenseState {
    case unactivated
    case activated(entitledUntil: Date)
    case offlineGrace(since: Date)       // length NOT documented
    case deviceLimitExceeded
    case revoked                         // refund / chargeback / breach
}

struct LicenseClient {
    let keyHash: String                  // one-way hash of the license key
    let installationID: UUID             // RANDOM, generated by Dockset, persisted locally
                                         // NEVER IOPlatformUUID, serial, or host name
    var lastSuccessfulCheck: Date?
}

enum DeviceTier: Int { case one = 1, two = 2, three = 3 }   // identical features per tier
```

---

## 5. Interaction & motion constants

### 5.1 Scaling

```swift
/// Widget content grows at double rate below 50 %, half rate above. Continuous at s = 0.5 -> 1.0.
func contentScale(_ s: Double) -> Double { s < 0.5 ? 2 * s : 0.75 + 0.5 * s }

let scaleRange: ClosedRange<Double> = 0.25...1.5   // slider shows 25 %…150 %
let defaultScale = 0.35                            // sample profiles: 0.30, 0.35
```

### 5.2 Icon geometry (native points)

```swift
struct IconGeometry { let width, height, icon, dot, dotOffset, dotBottom, factor: Double }

func iconGeometry(scale: Double, vertical: Bool, hasWidgets: Bool = true) -> IconGeometry {
    let f = hasWidgets ? contentScale(scale) : scale
    return .init(width:     (vertical ? 62 : 50) * f,
                 height:    (vertical ? 50 : 62) * f,
                 icon:      48 * f,
                 dot:        4 * f,
                 dotOffset: 28 * f,
                 dotBottom: 24 * f,
                 factor: f)
}
```

Running dot placement: `x = -28*f` (left Dock), `x = +28*f` (right Dock), `y = 24*f` (bottom Dock). Icon nudge on a bottom Dock: `y -= 4*f`.
Widget tile cross-axis: **62 pt tall** on a bottom Dock, **76 pt wide** on a side Dock.

### 5.3 Chrome metrics

| Metric | Formula |
|---|---|
| Dock padding | `(8 + 2 / min(1, scale)) * scale` |
| Shelf corner radius | `22 / clamp(scale, 0.5, 1) * scale` |
| Item gap | `4 * scale / min(1, scale)` |
| Adjacent (widget-touching) gap | `-scale / min(1, scale)` |
| Grip long axis | `28 * sqrt(scale)` |
| Grip short axis | `4 * sqrt(scale)` |
| Grip cross extent | `max(52 * scale, 28)` — grips stay 24 pt wide below 50 % |
| Running-apps separator | `28 * factor × 1 pt`, 3 pt margins |
| Reveal strip (side Dock) | 18 pt thick × 72 pt long, edge-centred |
| Reveal handle pill | 40×4 pt (4×40 vertical), radius 5, white α 0.69 |

### 5.4 Drag-resize solver

```swift
func resizedScale(_ scale: Double, delta: Double,
                  position: DockPosition, hasWidgets: Bool = true) -> Double {
    guard hasWidgets else {
        return min(max(scale + delta / (position == .bottom ? 86 : 112), 0.25), 1.5)
    }
    let cross  = position == .bottom ? 62.0 : 76.0
    let extent = cross * contentScale(scale) + 24 * scale + delta
    let s = extent < cross + 12
        ? extent / (2 * cross + 24)
        : (extent - 0.75 * cross) / (0.5 * cross + 24)
    return min(max(s, 0.25), 1.5)
}
```
Drag delta measurement: bottom Dock `start.y - event.y`; right Dock `start.x - event.x`; left Dock `event.x - start.x`.
Keyboard on the focused grip: `↑/→ +0.05`, `↓/← −0.05`, `Home → 0.25`, `End → 1.5`. VoiceOver value: `round(scale * 100)` %.

### 5.5 Magnification (macOS Dock only in the port; the Custom Dock toggle is new)

```
targetScale = 1 + dockInfluence(|pointer − itemCenter|, radius: 110) * 0.35
```
Integrated with a spring step, `dt` clamped ≤ 0.032 s, disabled under Reduce Motion. The port's comment is explicit: *"The custom Dock never magnifies."* The v0.2.5 Custom-Dock magnification toggle has **no documented curve** — start from this spring with a reduced peak (~0.20) for widget tiles.

### 5.6 Material render values

| Material | Blur | Saturation | Fill (light / dark) | Extras |
|---|---|---|---|---|
| Frosted | 24 | — | `#EFEFEF` α .90 / `#292929` α .90 | inset 1 px `#FFF` α .69 rim; shadow `0 5 18 rgba(0,0,0,.10)` |
| Liquid Glass · Regular | 18 | 1.4 | `#FFFFFF` α .46 | inset top `#FFF` α .87, bottom `#FFF` α .47; shadow `0 5 20 rgba(27,22,53,.13)` |
| Liquid Glass · Clear | 8 | 1.35 | `#FFFFFF` α .21 / `#222222` α .50 | — |

**Reduce transparency ⇒ opaque fill regardless of glass style.** Increase contrast alters the Liquid Glass look. Both observed live via `NSWorkspace.accessibilityDisplayOptionsDidChangeNotification`.

### 5.7 Business chart (`BusinessChart.swift`, ordered Bayer dither)

```swift
enum BusinessChartGeometry {
    static let popupSize  = CGSize(width: 332, height: 110)
    static let tileSize   = CGSize(width: 82,  height: 20)   // 56×24 in a vertical Dock
    static let pitch:   CGFloat = 3     // 2 compact
    static let dotSize: CGFloat = 1     // 1.1 compact
    static let inset:   CGFloat = 0     // 3 compact
    static let bayer: [Int] = [0,8,2,10, 12,4,14,6, 3,11,1,9, 15,7,13,5]  // threshold = v/16
    static let densityBase  = 0.18      // 0.20 compact
    static let densityRange = 0.47      // 0.65 compact
    static let densityCap   = 0.65      // 0.85 compact
}
```
Domain: `low = min(values, reference ?? 0)`, `high = max(values, reference ?? 0)`, `padding = max((high-low) * 0.12, reference == nil ? 1 : 0.01)`. Without a reference the domain is `[low-padding, high+padding]` and the baseline is y-of-zero; with a reference it is `[max(0, low-padding), high+padding]` and the baseline is the bottom edge. Density per row: `min(cap, base + |rowY - baseline| / depth * range)` where `depth` = the largest vertical distance from any vertex to the baseline.

### 5.8 Series lengths

| Period | Points | | Period | Points |
|---|---|---|---|---|
| today | 1 day (24 hourly points for Stripe/Paddle) | | sixtyDays | 60 |
| week | 7 | | ninetyDays | 90 |
| month | day-of-month so far | | sixMonths | 180 |
| thirtyDays | 30 | | twelveMonths | 365 |
| fourWeeks | 28 | | quarter | days since quarter start |
| year | days since Jan 1 | | lastYear | 365 |
| allTime | 730 | | *unknown* | 30 |

Headline value = **last point** for recurring metrics (`mrr, arr, subscribers, arpu`) and for Shopify `averageOrderValue` / `conversionRate`; **sum of points** otherwise. Period caption on a recurring widget: `"Now"` (Stripe/Shopify) / `"Latest"` (Paddle); detail subcaption `"Current"` / `"Latest reported"`.

Period short codes: `Today, L7, MTD, L30, YTD, L12M, L4W, L6M, QTD, All, L60, L90, L365`.

### 5.9 Widget-specific constants

| Widget | Constants |
|---|---|
| Clock face | SVG 30×30 viewBox, rim r 14.1 α .25, 4 ticks α .35, hour hand 6.45 @ `hour*30 + minute/2`, minute hand 9.75 @ `minute*6`, stroke 1.65 round cap |
| World clock | 4 preferred cities first, then all IANA zones; search caps at 30 results; empty query returns nothing |
| Stopwatch face | vertical+expanded ≥3600 s splits value/extra; ≥360000 s → `Nd` + `Nh`; non-expanded ≥36000 s → `Nh MMm` |
| Focus Timer | presets 15/25/45/60 min; ring 100 % when idle; break tint `#34C759`; paused = 50 % mix + pause glyph; `formatFocusTime` is always `m:ss` |
| Time Progress | day dots = `(end-start)/3600000`; month dots = days in month; year dots = 52; elapsed α 1.0, remaining α 0.18; ring 40 pt stroke 2.4 (tile) / 100 pt stroke 2.4 (detail) |
| Countdown | H/M/S fields max 24/59/59; name max 80; `Repeat <duration>` when finished |
| Alarm | `/^(?:[01]\d|2[0-3]):[0-5]\d$/`; snooze = +300 000 ms; font 20 pt → 15 pt when the string exceeds 5 chars, 18 pt for idle "Alarm"; labels `in Ns` / `in Nm` / `in Nh` / `Hh Mm` (no "in " prefix on the last) |
| Hydration | `--water-level` = `clamp(remaining/duration, 0, 1)`; `--wave-strength = min(1, level*8)`; two sine layers, 120 segments over a 200×100 box, amplitude 50 |
| Calendar | agenda caps at 3 events (2 vertical); all-day events sort last; list colours Work `#FF8D20`, Personal `#34C759`, Team `#078AFF` |
| Reminders | new-reminder field maxlength 512; undo strip shows the most recent completion |
| Sticky Note | 16 384-byte cap on `JSON({text, color})` |
| Battery | ring stroke 2.7; sizes 30 (wide) / 22 (compact) single, 28–42 multi; detail rings 40 pt |
| System Activity | rings 38 pt stroke 3.6; detail rings 72 pt stroke 2; "Memory" → "RAM" in vertical tiles |
| Network | 61-sample rolling window at 1 Hz keyed by wall clock; y-max = `1.1 × largest drawn sample`; viewBox 332×110 stretched non-uniformly |
| AI Usage | tile value = `min(windows)`; ring 38 pt (32 when not wide and >1 provider) stroke 3.5, tint `#0088FF`; reset offsets +8400 s (5-hour) / +259200 s (weekly); chart bar height `max(2, 28 * tokens / maxTokens)` px, `dense` class beyond 7 bars |
| Weather | 3 forecast hours on the tile, 6 in the popup; `°F = round(°C * 9/5 + 32)`; city search minlength 2 |
| Stock | direction classes `stock-loss` (<0), `stock-gain` (>0), `stock-neutral` (0); mini chart 88×34 |

### 5.10 Cadences

| Thing | Interval |
|---|---|
| Stripe / Paddle / Shopify | 300 s while active + manual Refresh |
| Codex | 60 s |
| Grok | 60 s |
| Claude Desktop fallback | 300 s (Claude Code path is push-only, via status line) |
| Claude staleness → renders `-` | > 600 s |
| Stock / Watchlist | `refresh` config, default 300 s |
| Network Activity | 1 Hz |
| Trash fullness | polled, deliberately infrequent (v0.2.5 CPU fix) |

---

## 6. macOS integration matrix

| # | Capability | Framework / API | Permission or entitlement | Difficulty |
|---|---|---|---|---|
| 1 | Menu bar agent | `NSStatusItem`, `LSUIElement` / `.accessory` | — | easy |
| 2 | Custom Dock window | `NSPanel` `.nonactivatingPanel`, level ≥ `CGWindowLevelForKey(.dockWindow)`, `collectionBehavior [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]` | — | **medium** — `.fullScreenAuxiliary` is required or popovers/menus die over fullscreen apps |
| 3 | Desktop-widget window level | `kCGDesktopIconWindowLevel` / `.backstopMenu` | — | easy |
| 4 | Multi-display placement | `NSScreen.screens`, `deviceDescription[.screenNumber]`, `didChangeScreenParametersNotification` | — | easy (disconnect handling is the fiddly part) |
| 5 | Edge reveal / auto-hide | thin always-on edge `NSWindow` + `NSTrackingArea`; or `NSEvent.addGlobalMonitorForEvents(.mouseMoved)` | — (global monitor works without AX for mouse-moved) | medium |
| 6 | Trackpad cross-axis profile swipe | `NSEvent.scrollWheel` + `hasPreciseScrollingDeltas` + `phase` | — | medium — the hard requirement is that a **non-precise mouse wheel must never switch profiles** |
| 7 | Enumerate running apps + icons | `NSWorkspace.runningApplications`, KVO, launch/terminate notifications | — | easy |
| 8 | Launch / open items | `NSWorkspace.openApplication`, `NSWorkspace.open(URL)` | — | easy |
| 9 | Folder/file item durability | Security-scoped bookmarks (`URL.bookmarkData(options: .withSecurityScope)`) | — (non-sandboxed, but bookmarks still survive moves better than paths) | easy |
| 10 | Drop files onto tiles → AirDrop | `.onDrop` / `NSDraggingDestination` + `NSSharingService(named: .sendViaAirDrop)` | — | easy |
| 11 | **Read/write macOS Dock layout** | `CFPreferences` on `com.apple.dock` → `persistent-apps` / `persistent-others`; spacers `{"tile-type" = "spacer-tile"}` / `"small-spacer-tile"`; apply via `killall Dock` | not sandboxable | **hard** — undocumented format, `tile-data` dict shape is fragile, must queue writes, verify after restart, and roll back. Put it behind one adapter with an OS-version check. |
| 12 | Auto-hide Apple's Dock | `com.apple.dock` `autohide` bool + restore the original on quit / setup change | — | easy (the *restore* discipline is the real work) |
| 13 | Detect Apple's Dock becoming visible | AX observation of the Dock process, or `NSScreen.visibleFrame` deltas | Accessibility (for the AX route) | **hard** — no documented API; heuristic |
| 14 | Window fitting around an always-visible Dock | `AXUIElement` set `kAXPositionAttribute` / `kAXSizeAttribute` on other apps' windows | **Accessibility** (`AXIsProcessTrustedWithOptions`) | **hard** — per-app quirks, fights with tiling, easy to make windows jitter |
| 15 | App badge labels | `AXUIElement` walk of the Dock's tiles → `AXStatusLabel` | **Accessibility** (separate opt-in) | **hard / fragile** — reading another process's AX tree for a private-ish attribute; breaks between releases |
| 16 | Wallpaper hold during Dock restart | `SCScreenshotManager` (ScreenCaptureKit) or `CGWindowListCreateImage` | **Screen Recording** (`CGRequestScreenCaptureAccess`), macOS 14+ | medium |
| 17 | Global hotkeys (≥2 modifiers) | `RegisterEventHotKey` (Carbon) or a CGEvent tap + recorder UI | — for RegisterEventHotKey; **Input Monitoring** for a tap | easy with Carbon, hard with a tap — **use Carbon** |
| 18 | Focus Filter "Switch Dock" | App Intents `SetFocusFilterIntent` + `AppEntity`/`EntityQuery` | — | medium — `perform()` on activation only; deactivation is deliberately a no-op |
| 19 | Liquid Glass material | SwiftUI `.glassEffect` / `NSGlassEffectView` | — | easy, **macOS 26+ only** |
| 20 | Frosted material | `NSVisualEffectView` | — | easy |
| 21 | Accessibility display prefs | `NSWorkspace.accessibilityDisplayShouldReduceTransparency` / `...ShouldIncreaseContrast` + change notification | — | easy |
| 22 | Calendar events | EventKit `requestFullAccessToEvents`, `EKEventStoreChangedNotification` | **NSCalendarsFullAccessUsageDescription** | easy |
| 23 | Reminders read/create/complete | EventKit `requestFullAccessToReminders`, `EKReminder` | **NSRemindersFullAccessUsageDescription** | easy |
| 24 | Meeting-link detection | `NSDataDetector` / regex over `url`, `location`, `notes` | — | easy |
| 25 | Spotify / Apple Music control | ScriptingBridge or `NSAppleScript`; `AEDeterminePermissionToAutomateTarget` for state | **NSAppleEventsUsageDescription** + per-target **Automation** | medium — browser playback is explicitly unsupported; do **not** reach for MediaRemote |
| 26 | Weather geocoding + location | `CLGeocoder` / `MKLocalSearch`, `CLLocationManager` | **NSLocationWhenInUseUsageDescription** (optional) | easy |
| 27 | Forecast | `URLSession` → api.met.no Locationforecast | identifying User-Agent required by MET; CC BY 4.0 attribution required **in UI** | easy |
| 28 | Enumerate / run Shortcuts | `Process` → `shortcuts list` / `shortcuts run`, or `shortcuts://run-shortcut?name=` | — (the shortcut's own actions carry their own prompts) | easy |
| 29 | System metrics | `host_statistics64`, `sysctl`, `URLResourceValues.volumeAvailableCapacityForImportantUsage` | — | easy |
| 30 | Battery + accessory levels | IOKit `IOPSCopyPowerSourcesInfo`; accessories via IORegistry `BatteryPercent` / CoreBluetooth | — | medium (AirPods case level is the unreliable one) |
| 31 | Network throughput | `getifaddrs` byte counters, delta per second | — | easy |
| 32 | Trash state | `FileManager` on `~/.Trash`, `NSWorkspace` recycler icons, Empty via Finder AppleScript | Automation (Finder) for Empty Trash | easy |
| 33 | Notifications | `UNUserNotificationCenter.requestAuthorization` | **Notifications** (request lazily, on first fire) | easy |
| 34 | Keychain for integration keys | `kSecClassGenericPassword`, service per provider, account = account UUID, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` | — | easy |
| 35 | Stripe / Paddle / Shopify HTTP | `URLSession` direct from the Mac (no Dockset backend) | `com.apple.security.network.client` if ever sandboxed | easy — the **metric maths** is the work, not the transport |
| 36 | Codex allowance | locate the Codex CLI (incl. the app's bundled copy), query its local app server | — | medium |
| 37 | Claude allowance via Claude Code | write a status-line hook into Claude Code's settings JSON; preserve & restore any pre-existing command | — | medium — mutating another tool's config is a support liability |
| 38 | Claude allowance via Claude Desktop | `SecItemCopyMatching` for "Claude Safe Storage" → decrypt Desktop cookies **in memory** → `URLSession` to claude.ai | macOS **Keychain access prompt** (user-facing, not TCC) | **hard + fragile** — undocumented, breaks on any Claude Desktop change, and background checks must never trigger the prompt |
| 39 | Grok allowance | read Grok CLI's existing local login, usage request without a prompt | — | medium |
| 40 | Local AI activity counters | parse CLI session/log files, cache daily rollups | — | medium |
| 41 | Backup export/import | `NSSavePanel` / `NSOpenPanel` (or `.fileExporter`/`.fileImporter`) + a custom `UTType` | — | easy |
| 42 | License activation + periodic check | `URLSession` → Cloudflare-hosted service; hashed key + hashed random installation UUID | — | medium |
| 43 | Updates | Sparkle (or a custom appcast) gated on server-reported eligibility | Sparkle needs its own entitlements if sandboxed | easy |
| 44 | Packaging | universal binary, Developer ID signing, notarization, DMG | Apple Developer Program ($99/yr) | easy — but **notarization is mandatory** or item 11 users will be blocked |

**Nothing here requires a private API.** The three things that *feel* private are #11 (`com.apple.dock` internals — public prefs domain, undocumented schema), #15 (badge labels via AX — public AX API, non-guaranteed attribute), and #38 (another app's Keychain item — public API, undocumented item). All three are legal and shippable, and all three will break without warning on an OS or vendor update.

**Not achievable at all as specified:** "Dockset takes priority over the macOS Dock in fullscreen" is not a guarantee any API provides — it is a window-level race you can usually win and never guarantee.

---

## 7. Build phases

Each phase ends with something you can actually launch and use. Ordered so the two defining surfaces land before anything optional.

### Phase 0 — Skeleton (1–2 days)
Menu-bar agent (`.accessory`), `PersistedState` v4 in `~/Library/Application Support/<bundle-id>/state.json`, Settings window, appearance (System/Light/Dark), profile CRUD with name + color, an empty Manage Docks window.
**Runnable:** a menu bar icon that creates and renames profiles that survive a relaunch.

### Phase 1 — The Custom Dock shelf (1–2 weeks) ← *the defining feature*
`NSPanel` on a chosen screen + edge; Frosted material only; app items with real icons; drag reorder; spacers; running-apps section + running dot; Keep in Dock / Remove from Dock; the full scale model (§5.1–5.4) with slider **and** grip drag; click-to-launch. No auto-hide, no widgets, no Liquid Glass.
**Runnable:** a usable second Dock. Ship this to yourself and live on it for a week before writing another line.
**Hard bits:** getting window level right so it sits above app windows but below menus; making the grip drag feel correct (the two-branch inverse in `resizedScale` exists for exactly that reason — don't "simplify" it to a linear map).

### Phase 2 — Widgets: the self-contained thirteen (2–3 weeks)
`WidgetKind` registry, `dimensions(item:vertical:)` resolver, tile / detail / customization render split, the library browser with categories + substring search + preview-variant cards. Implement clock, world, stopwatch, **timer**, progress, countdown, alarm, hydration, notes, battery, system, network, airdrop.
**Runnable:** a genuinely differentiated Dock with a real widget library, **zero TCC prompts, zero network**.
**Why here:** this is the highest value-per-risk work in the whole product. Everything from here on adds permission surface.

### Phase 3 — Native Dock layouts (1–2 weeks) ← *the other half of the name*
`com.apple.dock` adapter: read `persistent-apps`, capture apps + spacers, write, `killall Dock`, verify after restart, roll back on failure, queue writes so rapid switches apply in order. First-run "Create from Current Dock / Start Empty". The Save / Apply / Use-this-profile state machine. Finder special case.
**Runnable:** both surfaces working, both switchable.
**Honest warning:** this is the most brittle code in the product and the only part that can visibly damage a user's setup. Always snapshot the live Dock before the first write. Never write without a verified read-back. Behind one file, one adapter, one OS-version check.

### Phase 4 — Switching everywhere (1 week)
Global hotkeys via Carbon `RegisterEventHotKey` with a recorder enforcing ≥2 modifiers (Esc/Delete clears). Two-finger cross-axis swipe (precise deltas + phase only). Menu bar profile sections + label modes. Right-click → Switch Profile. Focus Filter `SetFocusFilterIntent`.
**Runnable:** the product as advertised on the box.
**Hard bit:** the mouse-wheel exclusion. Test with an actual mouse, not just a trackpad.

### Phase 5 — Appearance & hiding (1 week)
Liquid Glass (`#available(macOS 26)`) + Glass style Regular/Clear; Reduce transparency / Increase contrast live observation **with explanatory copy**, not silent override. Auto-hide + edge reveal + reveal handle. Hide-when-macOS-Dock-appears. Use as desktop widget. Item overflow scrolling.
**Runnable:** looks like the shipped product.

### Phase 6 — Permissioned widgets (1–2 weeks)
Calendar + Reminders (EventKit full access, per-widget on-demand prompts, denied-recovery deep links). Now Playing (Automation, per-target Connect buttons). Weather (CoreLocation optional + MET Norway + mandatory attribution). Shortcut widget. Notifications for timer/alarm/countdown/hydration.
**Runnable:** the complete non-commercial widget set.
**Rule:** never prompt at launch. Every prompt fires from the widget that needs it, and every denial has a visible path back.

### Phase 7 — Licensing + backup + distribution (1 week)
Random installation UUID, hashed activation, periodic check, offline grace, revoked/over-limit states, `Activate Dockset…`. Back Up… / Restore… with an embedded `formatVersion` and strict append-only semantics. Universal build, Developer ID signing, notarization, DMG.
**Runnable:** shippable.
**Decide explicitly:** what a revoked check does. Recommendation — drop to the activation window, keep every local profile intact, never delete user data.

### Phase 8 — Business integrations (2 weeks)
Keychain account store, Stripe / Paddle / Shopify connect flows with per-provider scope copy, the metric/period/currency matrix, per-provider timezone bucketing (**local / UTC / store** — a shared calendar is a bug), the Bayer dither chart, 5-minute refresh with last-good-values-on-failure, Disconnect, About-this-metric copy verbatim.
**Runnable:** the paid-tier headline widgets.
**Hard bits:** Stripe MRR/ARR/subscribers/ARPU are *computed client-side* from subscriptions — pagination limits, multi-currency separation, and "cannot be calculated reliably" explanations are all yours to design. Shopify's 10 000-order ceiling must produce an error, never a partial total.

### Phase 9 — AI Usage (1–2 weeks)
Codex (local app server), Grok (CLI login), Claude Code (status-line hook with preserve/restore), local Activity counters + token chart.
**Defer or drop: the Claude Desktop cookie fallback.** It decrypts another app's Keychain item to call an undocumented endpoint. It will break, it will generate support load, and it is the one feature in this spec I would ship last or not at all.

### Phase 10 — The Accessibility tier (open-ended, do last)
App badges via AX on the Dock's tiles. Window fitting for an always-visible Dock. Hide-when-macOS-Dock-appears via AX. Magnification. Show Trash. Fullscreen dwell-reveal. Smooth switching (Screen Recording wallpaper hold). Folder icon customization. First-run walkthrough.
**Everything here is optional by design** — the docs say so explicitly ("You do not need every optional permission to start using Dockset"). Each item must degrade to *nothing happens*, never to a broken Dock.

**Realistic total: 3–4 months solo for phases 0–7. Phases 8–10 are open-ended** because each depends on a third party that can change without notice.

---

## 8. Risks & unknowns

### 8.1 Will break without warning (accepted, mitigable)

| Risk | Impact | Mitigation |
|---|---|---|
| `com.apple.dock` `persistent-apps` schema changes | Native profiles stop applying; worst case a user's Dock is wiped | One adapter file. Snapshot before every write. Verify by read-back after the restart. Roll back on mismatch. Version-gate. The docs already carry Apple's disclaimer — surface it in the UI. |
| `AXStatusLabel` on Dock tiles disappears | Badges silently stop | Feature is already optional and opt-in. Degrade to no badges, never to an error dialog. |
| Claude Desktop Keychain item / cookie format changes | AI Usage Claude column dies | Treat the Desktop fallback as best-effort. The status-line path must work standalone. |
| Claude Code settings JSON schema changes | Hook install corrupts another tool's config | Read-modify-write with a backup of the original value; never blind-overwrite; restore only if unchanged since connect. |
| Codex / Grok CLI local endpoints change | Those columns die | Same: last-known value + explicit "Configure usage" affordance. |
| Shopify metrics beyond orders | **`read_orders` alone cannot supply visitors / sessions / pageviews / conversionRate / addedToCart / reachedCheckout / completedCheckout.** The catalog lists 12 metrics; the documented scope supports 5. | Either add `read_analytics`/ShopifyQL and document it, or ship only the order-derived metrics. Do **not** ship pickers for metrics that always return nothing. |

### 8.2 Genuinely undefined in the source material

| Unknown | Recommendation |
|---|---|
| Magnification curve for the Custom Dock (no factor, radius, or default) | Reuse the macOS spring at radius 110, peak 0.35 for apps, ~0.20 for widget tiles. Ship off by default. Make it tunable. |
| Auto-hide reveal and hide delays ("hides sooner", "hold briefly in fullscreen") | Pick 0 ms reveal on the desktop, ~250 ms dwell in fullscreen, ~120 ms hide delay. **Leave these as constants you can tune** — they are the single biggest determinant of whether the Dock feels good, and no formula will tell you the right number. |
| Per-profile vs global scale reconciliation | The port copies `profile.scale` into the live value on selection. Make the profile the owner; the slider writes back into the active profile. |
| Backup file format / extension / schema versioning | Define a `UTType`, JSON payload, embedded `formatVersion`, reject unknown-newer with a clear message. |
| Offline grace length and periodic-check interval | Both stated to exist, neither quantified. Suggest: check every 24 h, 14-day grace, then degrade to the activation window with all data intact. |
| Where the unlink/deactivate action lives | Terms say unlinking frees a slot; no UI path is documented. Build "Deactivate this Mac" into the activation window. |
| `Automatically save Dock changes` default | Default **off**. It silently mutates a saved profile; opt-in is correct. |
| Does `Use as desktop widget` coexist with auto-hide? | Undefined. Make them mutually exclusive and grey out auto-hide — a hidden desktop-level Dock is unreachable. |
| Trash position in the item order | Pin it to the end like Apple's Dock. Freely draggable Trash is a bug factory. |
| Spacer sizes on the Custom Dock | Custom add menu shows one "Spacer"; macOS shows two. Ship both sizes everywhere; the native tile types already require both. |
| "Previous track" vs "Restart track" | Setting label says previous, accessible label says restart, demo seeks to 0. Implement Spotify/Music semantics: restart if >3 s elapsed, else previous. |
| Stripe API source (balance_transactions vs charges), pagination ceiling | Unspecified. Pick `balance_transactions` for revenue/net; page subscriptions with a hard object cap and surface `metricNotCalculable` when exceeded. |
| Stripe subscription chart history "starts when you connect" | Implies a locally persisted time series with undefined retention. Cap at 2 years (`allTime` = 730 points), key by account UUID, survive rename. |
| Link item icon (favicon / custom / globe?) | Undocumented. Ship a generic globe + first letter; add favicon fetch later if asked. |
| Dead paths after restore | Docs only say "re-add items whose paths have changed." Render them greyed with a repair affordance. **Never silently drop a user's item.** |
| Retry/backoff after a failed business refresh | Undocumented. Keep the 5-minute timer, add jitter, stop retrying after 3 consecutive failures until a manual Refresh. |
| Watchlist widget detail | **The source material was truncated mid-definition.** Known: kind `watchlist`, category Stocks, 276×176, no compact, config identical to `stock` with `symbols: ["AAPL","MSFT","NVDA"]`. Row rendering, sorting, and per-row chart behaviour are unspecified. |
| Stock/Watchlist quote provider | **Named nowhere in any source.** Needs a licensed market-data vendor. Treat as a separate product decision with real cost implications. |

### 8.3 Things a solo/hobby developer should know up front

- **Not sandboxable.** Writing `com.apple.dock`, arbitrary file/folder items, Accessibility, and Apple Events all preclude the App Sandbox — which means **no Mac App Store**, which means you own distribution, signing, notarization, updates, and licensing yourself. That's Phase 7's real cost.
- **Apple Developer Program membership ($99/yr) is mandatory**, not optional — unnotarized DMGs are blocked on modern macOS.
- **No private APIs are needed anywhere in this spec.** What you need instead is tolerance for three undocumented-but-public surfaces (Dock prefs, AX badge labels, another app's Keychain item) and a habit of degrading gracefully when each one breaks.
- **The deployment-target decision is unresolved in the source.** The docs say macOS 13 Ventura; the brief says build on macOS 26. Targeting **macOS 26 minimum** buys you `.glassEffect`, modern EventKit, `SetFocusFilterIntent`, `@Observable`, and clean Swift 6 concurrency with no `#available` gates — at the cost of every Ventura/Sonoma/Sequoia user. Targeting 13 means availability-gating roughly eight APIs and shipping a Frosted-only fallback appearance. **Pick 26 unless you have a specific reason not to** — the whole Liquid Glass story is otherwise dead weight.
- **The two halves of this product are separable.** Phases 1–2 (Custom Dock + self-contained widgets) are a complete, shippable, permission-free product on their own. Phase 3 (native Dock layouts) is the risky half. If time is short, ship the first half and treat the second as v2.