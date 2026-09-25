import AppKit
import SwiftUI

/// Now Playing: artwork, track, transport and a scrubber (264×62 on a bottom
/// shelf, a stacked 76pt column on a side one, or a 64pt artwork-only chip).
///
/// Reads Spotify and Apple Music directly, and falls back to whatever video is
/// playing in a scriptable browser tab.
struct MusicTile: View {
    var instance: WidgetInstance
    var context: WidgetContext

    private var config: WidgetConfig { instance.config }
    private var isMini: Bool { config.bool("mini") }

    /// Sources the user allows, in preference order — whichever is enabled
    /// first wins when both are playing.
    private var sources: [MusicSource] {
        var list: [MusicSource] = []
        if config.bool("spotify", default: true) { list.append(.spotify) }
        if config.bool("apple", default: true) { list.append(.appleMusic) }
        return list
    }

    private var browsersEnabled: Bool { config.bool("browsers", default: true) }

    /// How often a playing track is re-read. The scrubber glides over exactly
    /// this long, so it arrives just as the next reading does.
    static let pollInterval: TimeInterval = 0.85

    /// Whichever source has something to show.
    ///
    /// A native player always wins while it is actually playing; a browser
    /// only gets a look in once Spotify and Music have nothing going on.
    private var playing: Playing? {
        if context.isPreview { return Self.sample }
        let native = MusicService.shared.nowPlaying.map(Playing.init(native:))
        let browser = browsersEnabled ? BrowserMedia.shared.track.map(Playing.init(browser:)) : nil
        if native?.isPlaying == true { return native }
        if browser?.isPlaying == true { return browser }
        return native ?? browser
    }

    /// Consent is per target app, so a browser can be blocked while Spotify is
    /// fine, and vice versa. One button clears whichever it is.
    private var needsPermission: Bool {
        guard !context.isPreview else { return false }
        return MusicService.shared.needsAutomationPermission
            || (browsersEnabled && BrowserMedia.shared.needsPermission)
    }

    private static let sample = Playing(native: NowPlaying(
        title: "Daylight", artist: "Sample artist", album: "Sample album",
        duration: 240, elapsed: 74, isPlaying: true, artwork: nil, source: .spotify
    ))

    var body: some View {
        WidgetSurface {
            content
        }
        .onAppear {
            guard !context.isPreview else { return }
            // ponytail: shared poll, start-only — the shelf is always on
            // screen, so there is nothing to stop it for.
            MusicService.shared.enabled = sources
            MusicService.shared.start()
            BrowserMedia.shared.enabled = browsersEnabled
            BrowserMedia.shared.start()
        }
        .onChange(of: sources) { _, new in
            if !context.isPreview { MusicService.shared.enabled = new }
        }
        .onChange(of: browsersEnabled) { _, new in
            if !context.isPreview { BrowserMedia.shared.enabled = new }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isMini {
            Artwork(image: playing?.artwork,
                    side: context.position.isVertical ? 52 : 44, corner: 10,
                    isPlaying: playing?.isPlaying) { if let playing { toggle(playing) } }
        } else if needsPermission, playing == nil {
            connect
        } else if let playing {
            if context.position.isVertical { column(playing) } else { strip(playing) }
        } else {
            idle
        }
    }

    // MARK: Wide, 264×62

    /// Whichever service actually owns what is on screen. Firing both meant
    /// pausing a YouTube tab also started Spotify, and the tile then jumped to
    /// a different track.
    private func toggle(_ track: Playing) {
        if track.isBrowser { BrowserMedia.shared.playPause() }
        else { MusicService.shared.playPause() }
    }

    private func strip(_ track: Playing) -> some View {
        HStack(spacing: 11) {
            Artwork(image: track.artwork, side: 38, corner: 8,
                    isPlaying: track.isPlaying) { toggle(track) }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 0) {
                        title(track, size: 15)
                        artist(track, size: 12)
                    }
                    Spacer(minLength: 0)
                    // Only shown when there is genuinely more than play/pause;
                    // that now lives on the artwork.
                    if track.hasSkipControls {
                        transport(track, size: 14, spacing: 10)
                    }
                }
                // A video with no readable duration (a live stream, or a site
                // that reports none) would draw two 0:00 clocks around an
                // empty bar, so it gets no scrubber at all.
                if track.duration > 0 || !track.isBrowser { scrubber(track) }
            }
        }
        // 52pt of content, so this must satisfy 52 + 2*padding <= the
        // catalog's card height or the surface overflows its frame and
        // `.clipped()` shaves the 14pt corner radius flat. At 7 it painted
        // 66pt inside a 62pt box, which is the "1-2px too tall" card.
        .padding(.vertical, 3)
    }

    private func scrubber(_ track: Playing) -> some View {
        HStack(spacing: 7) {
            time(MusicTime.clock(track.elapsed))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(WidgetStyle.secondary.opacity(0.3))
                    Capsule()
                        .fill(WidgetStyle.primary)
                        .frame(width: max(0, geo.size.width * track.progress))
                        // Playback advances at a constant rate, so gliding to
                        // each new reading at that rate *is* the truth — and a
                        // bar that steps once a second reads as a stutter even
                        // though the number behind it is correct. Linear, and
                        // only while playing: a seek or a pause should land.
                        .animation(track.isPlaying ? .linear(duration: MusicTile.pollInterval)
                                                   : nil,
                                   value: track.progress)
                }
                .contentShape(Rectangle())
                .onTapGesture { location in
                    // Browser playback is read-only apart from play/pause.
                    guard !context.isPreview, !track.isBrowser,
                          geo.size.width > 0, track.duration > 0 else { return }
                    let ratio = min(1, max(0, location.x / geo.size.width))
                    MusicService.shared.seek(to: ratio * track.duration)
                }
            }
            .frame(height: 4)
            time(MusicTime.clock(track.duration))
        }
    }

    private func time(_ text: String) -> some View {
        Text(text)
            .font(WidgetStyle.caption(11))
            .monospacedDigit()
            .rollingValue(text)
            .foregroundStyle(WidgetStyle.secondary)
            .lineLimit(1)
            .fixedSize()
    }

    // MARK: Column, 76pt wide

    /// No scrubber here: 56pt of usable width cannot carry two clocks and a
    /// bar, so the column spends its height on the track instead.
    private func column(_ track: Playing) -> some View {
        VStack(spacing: 3) {
            Artwork(image: track.artwork, side: 32, corner: 7)
            VStack(spacing: 0) {
                title(track, size: 10)
                artist(track, size: 9)
            }
            transport(track, size: 11, spacing: 6)
        }
        .padding(.vertical, 2)
    }

    // MARK: Shared pieces

    private func title(_ track: Playing, size: CGFloat) -> some View {
        Text(track.title)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(WidgetStyle.primary)
            .lineLimit(1)
            // Truncated, never shrunk. A video title runs long, and scaling it
            // to fit drove the most important line on the tile down to a few
            // points — smaller than the artist underneath it.
            .truncationMode(.tail)
    }

    private func artist(_ track: Playing, size: CGFloat) -> some View {
        Text(track.artist)
            .font(WidgetStyle.caption(size))
            .foregroundStyle(WidgetStyle.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    /// Browser video gets play/pause only: seeking, skipping and track changes
    /// mean nothing to a `<video>` element, and a button that does nothing is
    /// worse than one that is not there.
    @ViewBuilder
    private func transport(_ track: Playing, size: CGFloat, spacing: CGFloat) -> some View {
        if track.isBrowser {
            button(track.isPlaying ? "pause.fill" : "play.fill", size) { toggle(track) }
        } else {
            let skip = max(1, config.int("skip", default: 15))
            HStack(spacing: spacing) {
                if config.bool("backward") {
                    button(skipSymbol("gobackward", skip), size) { MusicService.shared.skip(by: -Double(skip)) }
                }
                if config.bool("previous", default: true) {
                    button("backward.end.fill", size) { MusicService.shared.previous() }
                }
                button(track.isPlaying ? "pause.fill" : "play.fill", size) { MusicService.shared.playPause() }
                if config.bool("next", default: true) {
                    button("forward.end.fill", size) { MusicService.shared.next() }
                }
                if config.bool("forward") {
                    button(skipSymbol("goforward", skip), size) { MusicService.shared.skip(by: Double(skip)) }
                }
            }
        }
    }

    /// SF Symbols only ships numbered skip glyphs for a handful of intervals;
    /// anything else falls back to the plain arrow rather than a blank square.
    private func skipSymbol(_ base: String, _ seconds: Int) -> String {
        let numbered: Set<Int> = [5, 10, 15, 30, 45, 60, 75, 90]
        return numbered.contains(seconds) ? "\(base).\(seconds)" : base
    }

    private func button(_ symbol: String, _ size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: { if !context.isPreview { action() } }) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(WidgetStyle.primary)
                .frame(minWidth: size)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Empty states

    /// Shown instead of silently failing, and it is the *only* thing that ever
    /// raises the automation consent dialog.
    private var connect: some View {
        Button {
            MusicService.shared.requestAutomationPermission()
            if browsersEnabled { BrowserMedia.shared.requestPermission() }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "music.note")
                    .font(.system(size: 14, weight: .medium))
                Text("Connect")
                    .font(WidgetStyle.label(11))
            }
            .foregroundStyle(WidgetStyle.primary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Three different empty states, because they mean different things.
    ///
    /// "Not playing" when a player is open and idle; the menu path when a
    /// browser has media tabs but will not run our JavaScript; the app names
    /// when nothing at all is open.
    private var idle: some View {
        let open = !context.isPreview && MusicService.shared.hasPlayer
        let setup = browserSetupHint
        return VStack(spacing: 2) {
            Image(systemName: setup != nil ? "switch.2" : (open ? "music.note" : "music.note.list"))
                .font(.system(size: 14, weight: .medium))
            Text(setup ?? (open ? "Not playing" : sourceNames))
                .font(WidgetStyle.caption(11))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
        }
        .foregroundStyle(WidgetStyle.secondary)
        .frame(maxWidth: .infinity)
        .help(setup.map { "A browser tab has media, but Plinth cannot read it. Turn on \($0)." }
              ?? (open ? "Nothing is playing." : "Plinth reads \(sourceNames), and video in a scriptable browser tab."))
    }

    /// The menu item the user has to switch on, or nil when nothing is asking.
    private var browserSetupHint: String? {
        guard !context.isPreview, browsersEnabled, BrowserMedia.shared.needsSetup else { return nil }
        let hint = BrowserMedia.shared.setupHint
        return hint.isEmpty ? nil : hint
    }

    /// The players this widget is configured to read, e.g. "Spotify or Music".
    private var sourceNames: String {
        let names = sources.map(\.displayName)
        guard !names.isEmpty else { return "No sources" }
        return names.count == 1 ? names[0] : names.joined(separator: " or ")
    }
}

/// One reading, whatever produced it, so the layouts do not care whether they
/// are drawing Spotify or a YouTube tab.
struct Playing {
    var title: String
    var artist: String
    var isPlaying: Bool
    var elapsed: TimeInterval
    var duration: TimeInterval
    var progress: Double
    var artwork: NSImage?
    var isBrowser: Bool

    /// Whether anything beyond play/pause is meaningful.
    ///
    /// A `<video>` element has nothing to skip to, so browser playback offers
    /// play/pause only — and that now lives on the artwork.
    var hasSkipControls: Bool { !isBrowser }

    init(native: NowPlaying) {
        title = native.title
        artist = native.artist
        isPlaying = native.isPlaying
        elapsed = native.elapsed
        duration = native.duration
        progress = native.progress
        artwork = native.artwork
        isBrowser = false
    }

    /// No artwork: browser video has none to fetch, and the tile's placeholder
    /// is the right answer rather than a gap.
    init(browser: BrowserTrack) {
        title = browser.title
        artist = browser.site
        isPlaying = browser.isPlaying
        elapsed = browser.elapsed
        duration = browser.duration
        progress = browser.progress
        artwork = nil
        isBrowser = true
    }
}

/// Album art, or a music-note placeholder when there is none — the tile must
/// never show an empty hole while artwork is still downloading.
private struct Artwork: View {
    var image: NSImage?
    var side: CGFloat
    var corner: CGFloat
    /// When set, the artwork itself toggles playback.
    var isPlaying: Bool?
    var onToggle: (() -> Void)?

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(WidgetStyle.primary.opacity(0.08))
            .overlay {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if onToggle == nil {
                    // Only when nothing else occupies the square. With the
                    // play control on top, the note showed through behind it
                    // and read as two overlapping glyphs.
                    Image(systemName: "music.note")
                        .font(.system(size: side * 0.48, weight: .medium))
                        .foregroundStyle(WidgetStyle.primary)
                }
            }
            .overlay {
                // The control lives on the artwork rather than beside it: for
                // video there is nothing to skip to, so a lone button was
                // spending width the title badly needed.
                if let isPlaying, onToggle != nil {
                    ZStack {
                        // Fixed, not hover-driven: SwiftUI's .onHover never
                        // fires in this non-activating accessory panel (see
                        // HoverCatcher), so a hover-only affordance is invisible.
                        Color.black.opacity(0.34)
                        // Full strength, and large. The artwork renders about
                        // 31pt on a default-sized shelf, so a small
                        // semi-transparent glyph over a dark placeholder was
                        // invisible in practice — it read as no control at all.
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: side * 0.46, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.6), radius: 2)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .contentShape(.rect)
            .onTapGesture { onToggle?() }
            .accessibilityAddTraits(onToggle == nil ? [] : .isButton)
            .accessibilityLabel(onToggle == nil ? "Artwork"
                                : ((isPlaying ?? false) ? "Pause" : "Play"))
    }
}
