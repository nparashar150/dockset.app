#!/usr/bin/env swift
//
// Draws Docket's app icon and writes every PNG the asset catalog asks for.
//
//   swift Tools/Icon/make-icon.swift [output-appiconset-dir]
//
// Everything here is geometry: there is no source image on disk, no external
// dependency and no network. The whole icon is three shapes plus an edge
// highlight, expressed as fractions of the canvas, so the 16 px and the 1024 px
// renders are literally the same drawing at two scales - which is the only way
// the small one stays honest.
//
// The shapes, and why they are these shapes: a dark squircle holds a pale
// capsule - the shelf, sitting low the way the Dock sits low - with an open
// progress ring resting on it. The ring is the widget: a gauge with a bite out
// of its upper right, the shape every live reading in the app (CPU, memory,
// battery, timer) already draws. Shelf plus one live gauge is the product in
// two marks, and at 16 px it is still a bright ring on a bright bar.

import AppKit

// MARK: - Geometry, in fractions of the canvas

// Apple's macOS icon grid does not fill the canvas: on a 1024 pt grid the icon
// body is 824 pt wide, leaving 100 pt of transparent margin on each side. That
// margin is load-bearing - it is the room the system's own highlight, shadow
// and hover scaling live in - so it is kept rather than trimmed.
let bodyFraction: CGFloat = 824.0 / 1024.0

// The macOS icon outline is a squircle: a Lamé curve (superellipse)
//
//     |x/a|^n + |y/a|^n = 1
//
// not a rounded rectangle. A rounded rect splices circular arcs onto straight
// edges, so curvature jumps from 1/r to 0 at four points on each corner and the
// eye reads the seam as "not quite an Apple icon". The superellipse's curvature
// is continuous everywhere, which is the whole point of the shape.
//
// n = 5 is the exponent that matches Apple's artwork: n = 2 is an ellipse,
// n → ∞ is a square, and the family passes through Apple's silhouette at 5.
// (n = 4 is visibly too round at the corners, n = 6 too boxy along the edges.)
// The curve is drawn from its parametric form
//
//     x = a · sign(cos t) · |cos t|^(2/n)
//     y = a · sign(sin t) · |sin t|^(2/n)
//
// which satisfies the implicit equation exactly for every t, so this is the
// real curve sampled densely - not a Bézier guess at it.
let squircleExponent: CGFloat = 5.0
let squircleSamples = 1440

// The shelf, and the ring that rests on it. One thickness is shared by both:
// the ring's stroke is exactly the shelf's height, so the two marks read as one
// object rather than two coincidental ones. At 16 px that thickness is 1.36 px
// - thick enough to survive rasterisation with colour left in it.
let barThickness: CGFloat = 0.085
let barWidth: CGFloat = 0.58
let barCenterY: CGFloat = 0.315          // measured up from the bottom edge
let ringRadius: CGFloat = 0.155          // centre line, not outer edge
let ringOverlap: CGFloat = 0.015         // ring sinks this far into the shelf

// The gauge's gap: 54° wide, centred on the upper right. Deliberately not at
// the top (an open-topped ring reads as a "U" at 16 px) and not at the bottom
// (the ring has to sit *on* the shelf, so its lowest point must be solid).
let ringGapCenter: CGFloat = 58
let ringGapWidth: CGFloat = 54

func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: a)
}

// Dark body, bright content: the one combination that holds up on a light
// desktop, a dark desktop, and against the Dock's own translucent slab.
let bodyTop = rgb(45, 52, 84)
let bodyBottom = rgb(13, 15, 26)
let shelfTop = rgb(242, 245, 255)
let shelfBottom = rgb(176, 188, 224)
let ringTop = rgb(104, 243, 208)
let ringBottom = rgb(56, 214, 246)

// MARK: - Drawing

/// The squircle, sampled from its parametric form.
func squirclePath(center: CGPoint, half: CGFloat, exponent n: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let p = 2 / n
    for i in 0..<squircleSamples {
        let t = 2 * CGFloat.pi * CGFloat(i) / CGFloat(squircleSamples)
        let c = cos(t), s = sin(t)
        let x = center.x + half * (c < 0 ? -1 : 1) * pow(abs(c), p)
        let y = center.y + half * (s < 0 ? -1 : 1) * pow(abs(s), p)
        if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
}

/// Fills `path` - or its stroked outline, if `lineWidth` is given - with a
/// vertical gradient running from `y0` (top colour) to `y1` (bottom colour).
func paint(_ ctx: CGContext, _ path: CGPath, from y0: CGFloat, to y1: CGFloat,
           _ top: CGColor, _ bottom: CGColor, lineWidth: CGFloat? = nil) {
    guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: [top, bottom] as CFArray,
                                    locations: [0, 1]) else { return }
    ctx.saveGState()
    ctx.addPath(path)
    if let lineWidth {
        ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.round)
        ctx.replacePathWithStrokedPath()
    }
    ctx.clip()
    // Gradient y runs downward, so the "top" colour is at the larger y.
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: y0), end: CGPoint(x: 0, y: y1),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}

func drawIcon(in ctx: CGContext, size s: CGFloat) {
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    let half = s * bodyFraction / 2
    let center = CGPoint(x: s / 2, y: s / 2)
    let body = squirclePath(center: center, half: half, exponent: squircleExponent)
    paint(ctx, body, from: center.y + half, to: center.y - half, bodyTop, bodyBottom)

    // A hairline of light inside the top edge, fading out by the middle. This is
    // the one thing that is *not* drawn small: below 128 px it is a sub-pixel
    // stroke that only muddies the silhouette, so it is skipped there. Same
    // drawing, better edges - not more detail.
    if s >= 128 {
        let inset = squirclePath(center: center, half: half - s * 0.004, exponent: squircleExponent)
        paint(ctx, inset, from: center.y + half, to: center.y,
              rgb(255, 255, 255, 0.26), rgb(255, 255, 255, 0), lineWidth: s * 0.007)
    }

    let thickness = s * barThickness
    let shelfCY = s * barCenterY
    let shelfRect = CGRect(x: (s - s * barWidth) / 2, y: shelfCY - thickness / 2,
                           width: s * barWidth, height: thickness)

    // The ring's outer edge lands on the shelf's top edge, less a hair of
    // overlap so the two marks touch rather than kiss at a single pixel row.
    let r = s * ringRadius
    let ringCY = shelfRect.maxY + r + thickness / 2 - s * ringOverlap
    let ring = CGMutablePath()
    let gapHalf = ringGapWidth / 2
    ring.addArc(center: CGPoint(x: s / 2, y: ringCY), radius: r,
                startAngle: (ringGapCenter + gapHalf) * .pi / 180,
                endAngle: (ringGapCenter - gapHalf + 360) * .pi / 180,
                clockwise: false)
    paint(ctx, ring, from: ringCY + r, to: ringCY - r, ringTop, ringBottom, lineWidth: thickness)

    // Shelf last: it draws over the ring's lowest arc, which is what makes the
    // ring look like it is standing on the shelf instead of crossing it.
    let shelf = CGPath(roundedRect: shelfRect, cornerWidth: thickness / 2,
                       cornerHeight: thickness / 2, transform: nil)
    paint(ctx, shelf, from: shelfRect.maxY, to: shelfRect.minY, shelfTop, shelfBottom)
}

// MARK: - Output

/// Every size macOS wants, as (point size, scale). 16 pt through 512 pt at 1x
/// and 2x, i.e. 16 px through 1024 px.
let variants: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
]

func filename(points: Int, scale: Int) -> String {
    "icon_\(points)x\(points)\(scale == 1 ? "" : "@\(scale)x").png"
}

func writePNG(pixels: Int, to url: URL) throws {
    guard let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                             bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw Failure("could not create a \(pixels)x\(pixels) bitmap context")
    }
    // Transparent everywhere the squircle is not - the corners of a macOS icon
    // must be see-through, never white and never black.
    ctx.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))
    drawIcon(in: ctx, size: CGFloat(pixels))

    guard let image = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
    else { throw Failure("could not encode \(url.lastPathComponent)") }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { throw Failure("could not write \(url.path)") }
}

struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

// Default output is this repo's catalog, found from the script's own location so
// the command works from any working directory.
let defaultOut = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()          // Tools/Icon
    .deletingLastPathComponent()          // Tools
    .deletingLastPathComponent()          // repo root
    .appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset")

let outDir = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : defaultOut

do {
    let fm = FileManager.default
    try fm.createDirectory(at: outDir, withIntermediateDirectories: true)

    for v in variants {
        let px = v.points * v.scale
        let url = outDir.appendingPathComponent(filename(points: v.points, scale: v.scale))
        try writePNG(pixels: px, to: url)
        print("  \(url.lastPathComponent)\t\(px)x\(px) px")
    }

    // Contents.json is generated from the same `variants` list that produced the
    // files, so the catalog can never disagree with what is on disk.
    let images = variants.map { v in
        """
            {
              "filename" : "\(filename(points: v.points, scale: v.scale))",
              "idiom" : "mac",
              "scale" : "\(v.scale)x",
              "size" : "\(v.points)x\(v.points)"
            }
        """
    }.joined(separator: ",\n")
    let contents = """
    {
      "images" : [
    \(images)
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }

    """
    let contentsURL = outDir.appendingPathComponent("Contents.json")
    try contents.write(to: contentsURL, atomically: true, encoding: .utf8)
    print("  Contents.json\t\(variants.count) entries")

    // The catalog root needs its own Contents.json or Xcode does not recognise
    // the directory as an asset catalog at all. Written only if absent, so an
    // existing catalog is never stomped.
    let catalogRoot = outDir.deletingLastPathComponent().appendingPathComponent("Contents.json")
    if !fm.fileExists(atPath: catalogRoot.path) {
        try """
        {
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }

        """.write(to: catalogRoot, atomically: true, encoding: .utf8)
        print("  ../Contents.json\tcatalog root (created)")
    }
} catch {
    FileHandle.standardError.write("make-icon: \(error)\n".data(using: .utf8)!)
    exit(1)
}
