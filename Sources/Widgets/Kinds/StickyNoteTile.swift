import SwiftUI

/// A scrap of paper on the shelf (160×100, always expanded).
///
/// The words are only shown here; they are written in the note's detail panel,
/// on paper the size of something you write on rather than glance at. A field
/// on the tile cannot coexist with that: the caret would swallow the click that
/// opens the panel, and the shelf is a non-activating panel, so a click on the
/// paper had to beg for key status before a single letter could land.
struct StickyNoteTile: View {
    var instance: WidgetInstance
    var context: WidgetContext

    /// Every `PaperColor` is a light swatch in both appearances, so the ink is
    /// deliberately fixed dark rather than semantic - `Color.primary` would go
    /// white in dark mode and vanish into the paper.
    private static let ink = Color(hex: "#1C1C1E")

    private var paper: Color {
        let stored = instance.config.string("color", default: "yellow")
        return WidgetStyle.paper(PaperColor(rawValue: stored) ?? .yellow)
    }

    private var stored: String { instance.config.string("text") }

    private var text: String {
        guard stored.isEmpty else { return stored }
        // An empty note on the shelf stays empty; the library needs something
        // to show.
        return context.isPreview ? "Pick up coffee\nCall Alex" : ""
    }

    var body: some View {
        // A column is the same paper card, just narrower and taller: smaller
        // ink, one more line, and the text shrinks a little rather than
        // trailing off in an ellipsis inside 56pt of usable width.
        let column = context.position.isVertical
        return WidgetSurface(fill: paper) {
            // No prompt on an empty note: grey placeholder words on a sticky
            // note read as a note someone already wrote.
            Text(text)
                .font(.system(size: column ? 10 : 13, weight: .semibold))
                .foregroundStyle(Self.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(column ? 5 : 4)
                .minimumScaleFactor(column ? 0.8 : 1)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, column ? 8 : 9)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                // No button trait: the note itself is read, not activated -
                // writing is its own control and the card belongs to the shelf.
                .accessibilityLabel(stored.isEmpty ? "Empty note" : "Note: \(stored)")
        }
    }
}
