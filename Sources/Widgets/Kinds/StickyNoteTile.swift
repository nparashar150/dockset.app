import SwiftUI

/// A scrap of paper on the shelf (160×100, always expanded).
///
/// The paper is writable in place: click it and type. The words land in `text`
/// in the widget's own config on Return and when the caret leaves, so a note
/// survives a relaunch and follows the widget between profiles.
struct StickyNoteTile: View {
    var instance: WidgetInstance
    var context: WidgetContext

    /// Every `PaperColor` is a light swatch in both appearances, so the ink is
    /// deliberately fixed dark rather than semantic — `Color.primary` would go
    /// white in dark mode and vanish into the paper.
    private static let ink = Color(hex: "#1C1C1E")

    /// What is being typed, kept apart from the stored note so the profile is
    /// written once the sentence is finished rather than once per keystroke.
    @State private var draft = ""
    @FocusState private var writing: Bool

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
            note(column: column)
                .font(.system(size: column ? 10 : 13, weight: .semibold))
                .foregroundStyle(Self.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(column ? 5 : 4)
                .padding(.vertical, column ? 8 : 9)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background {
                    // A short note leaves most of the paper blank, and blank
                    // paper is where people aim. This sits *behind* the field
                    // so a click on the words still reaches it directly —
                    // which matters: the shelf is a non-activating panel and
                    // only takes key status when the click lands on something
                    // that asks for it.
                    Color.clear
                        .contentShape(.rect)
                        .onTapGesture { beginWriting() }
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(stored.isEmpty ? "Empty note" : "Note: \(stored)")
        }
    }

    /// The library renders the same tile as a static sample, where a caret
    /// would be both editable and pointless.
    @ViewBuilder
    private func note(column: Bool) -> some View {
        if context.isPreview {
            Text(text)
                .minimumScaleFactor(column ? 0.8 : 1)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            // Unadorned so the paper looks the same whether or not the caret
            // is in it. No prompt either: grey placeholder words on a sticky
            // note read as a note someone already wrote.
            TextField("", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .focused($writing)
                .onSubmit {
                    commit()
                    writing = false
                }
                .onChange(of: writing) { _, active in if !active { commit() } }
                // Switching profiles swaps the instance underneath us; take
                // the new note unless the user is mid-sentence in the old one.
                .onChange(of: stored) { _, note in if !writing { draft = note } }
                .onAppear { draft = stored }
        }
    }

    private func beginWriting() {
        guard !context.isPreview else { return }
        writing = true
    }

    /// Focus leaves the paper far more often than the words change, and every
    /// write is a profile save.
    private func commit() {
        guard !context.isPreview, draft != stored else { return }
        WidgetWriter.write(instance) { config in
            config.set("text", .string(draft))
        }
    }
}
