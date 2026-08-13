import SwiftUI
import AppKit

/// The shelf's backing surface.
///
/// Two materials. **Liquid Glass** uses macOS 26's real `glassEffect` — an
/// earlier version of this file approximated it with a blur plus stacked white
/// overlays, which produced a flat milky slab with none of the refraction or
/// specular edge that makes the genuine material read as glass. **Frosted** is
/// an `NSVisualEffectView`, which is what Apple's own Dock uses.
///
/// Reduce Transparency wins over both: the accessibility setting is not a
/// style preference.
struct MaterialBackground: View {
    var material: DockMaterial
    var glass: GlassStyle
    var radius: CGFloat

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    var body: some View {
        surface
            .overlay {
                // A hairline top rim is what stops the shelf reading as a flat
                // cut-out against a busy wallpaper. Glass supplies its own, so
                // this is only for the frosted material.
                if material == .frosted && !reduceTransparency {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(scheme == .dark ? 0.22 : 0.65),
                                     .white.opacity(scheme == .dark ? 0.04 : 0.15)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                }
            }
            .compositingGroup()
            .shadow(color: .black.opacity(scheme == .dark ? 0.34 : 0.18), radius: 9, x: 0, y: 4)
    }

    @ViewBuilder
    private var surface: some View {
        if reduceTransparency {
            shape.fill(scheme == .dark ? Color(hex: "#1C1C1C") : Color(hex: "#F2F2F2"))
        } else {
            switch material {
            case .frosted: frosted
            case .liquidGlass: liquid
            }
        }
    }

    /// What Apple's Dock is: a blurred, vibrant plate sampling the desktop.
    ///
    /// The tint is deliberately light. A 90%-opaque fill (which the web
    /// reference uses, because a browser has no vibrancy to work with) would
    /// throw away the blur entirely and leave a plain grey rectangle.
    private var frosted: some View {
        VisualEffectPlate(material: .hudWindow, blending: .behindWindow)
            .overlay {
                shape.fill(scheme == .dark
                           ? Color.black.opacity(0.16)
                           : Color.white.opacity(0.14))
            }
            .clipShape(shape)
    }

    /// The real macOS 26 material, shape-matched to the shelf.
    ///
    /// Glass samples whatever is behind the window, so over a white page it
    /// turns white — and the shelf's labels, which follow the *system*
    /// appearance, stayed white and vanished into it. Measured against the
    /// real Dock in the same screenshot: the Dock holds ~47 luminance units of
    /// separation from its backdrop, this held 23. The scrim floors that
    /// separation so the plate can never wash out to match its own text.
    private var liquid: some View {
        Color.clear
            .glassEffect(glass == .clear ? .clear : .regular, in: shape)
            .overlay { shape.fill(scrim) }
    }

    /// Pulls the plate *away* from the label colour, whichever way that is:
    /// white labels need a floor, black labels need a ceiling.
    private var scrim: Color {
        scheme == .dark ? .black.opacity(0.22) : .white.opacity(0.26)
    }
}

/// `NSVisualEffectView` bridge — SwiftUI's `.ultraThinMaterial` samples only
/// within the window, and a floating shelf needs what is *behind* it.
private struct VisualEffectPlate: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blending: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        view.material = material
        view.blendingMode = blending
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
    }
}
