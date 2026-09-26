import SwiftUI

/// Presentational for now - the drop target lands with file handling.
struct AirDropTile: View {
    var instance: WidgetInstance
    var context: WidgetContext

    var body: some View {
        // A column is narrower, not different: same glyph over the same
        // caption, just sized for 56pt of usable width.
        let column = context.position.isVertical
        return WidgetSurface {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(colors: [Color(hex: "#3FA9FF"), Color(hex: "#0A7CFF")],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: column ? 32 : 34, height: column ? 32 : 34)
                    .overlay {
                        // SF Symbols has no AirDrop glyph; this is the closest.
                        Image(systemName: "dot.radiowaves.up.forward")
                            .font(.system(size: column ? 16 : 17, weight: .medium))
                            .foregroundStyle(.white)
                    }
                Text("AirDrop")
                    .font(WidgetStyle.label(column ? 12 : 15))
                    .foregroundStyle(WidgetStyle.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}
