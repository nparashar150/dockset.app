import SwiftUI

/// The shape every inline control on these tiles wears.
///
/// A bare symbol dropped at the trailing edge of a card reads as decoration -
/// nothing about it says it can be pressed. Every compact macOS surface that
/// has to fit a control beside a readout answers this the same way, from
/// Control Center's tiles to the menu bar's Now Playing: a low-opacity disc
/// sized to the glyph, so the target is visible before the pointer finds it.
/// This is that disc and nothing more.
///
/// It is twice the glyph across, which is the hit target these tiles already
/// reserved, so a control gains its backing without any layout moving around
/// it - the 76pt column keeps the smaller glyph it was drawn with and the
/// 168pt card keeps its larger one.
///
/// The disc takes its colour from the glyph, so the Alarm's orange stays
/// orange and the Stopwatch's reset stays as quiet as its symbol, without a
/// second rule per tile.
///
/// Pressed, not hovered: `.onHover` never fires in this non-activating
/// accessory panel (see HoverCatcher), which is why the Music tile's artwork
/// control is fixed rather than revealed. A hover-only affordance here would
/// simply never be seen.
struct TileGlyph: View {
    var symbol: String
    /// Point size of the glyph; the disc follows from it.
    var size: CGFloat
    var tint: Color = WidgetStyle.primary
    /// `nil` draws the control without making it pressable, which is what the
    /// library wants: the card's own click there adds the widget, and a button
    /// that refused to act would still swallow it. Drawing nothing instead
    /// would preview a tile the shelf never shows.
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { Image(systemName: symbol) }
                .buttonStyle(TileGlyphButton(size: size, tint: tint))
        } else {
            Image(systemName: symbol).tileGlyphDisc(size: size, tint: tint, pressed: false)
        }
    }
}

/// A style rather than a modifier on the label, because the press is the only
/// feedback this panel can give and it has to reach the disc, not just the
/// glyph sitting on it.
private struct TileGlyphButton: ButtonStyle {
    var size: CGFloat
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .tileGlyphDisc(size: size, tint: tint, pressed: configuration.isPressed)
    }
}

private extension View {
    func tileGlyphDisc(size: CGFloat, tint: Color, pressed: Bool) -> some View {
        font(.system(size: size, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size * 2, height: size * 2)
            .background(Circle().fill(tint.opacity(pressed ? 0.3 : 0.13)))
            // Confined to the disc - and to the disc's own round shape, so the
            // corners of its box still belong to the card. A descendant tap
            // beats the shelf's, and the shelf's is what opens the widget.
            .contentShape(Circle())
            .scaleEffect(pressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.14), value: pressed)
    }
}
