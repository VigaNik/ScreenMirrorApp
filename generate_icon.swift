#!/usr/bin/env swift
import AppKit
import CoreGraphics

let resDir = "./AndroidClient/app/src/main/res"
let sizes: [(String, Int)] = [
    ("mipmap-mdpi",    48),
    ("mipmap-hdpi",    72),
    ("mipmap-xhdpi",   96),
    ("mipmap-xxhdpi",  144),
    ("mipmap-xxxhdpi", 192)
]

func generateIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let img = NSImage(size: NSSize(width: s, height: s))

    img.lockFocus()

    let ctx = NSGraphicsContext.current!.cgContext

    // ── Background: dark gradient ──────────────────────────────────────
    let bgColors = [
        NSColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1).cgColor,
        NSColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 1).cgColor
    ]
    let grad = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: bgColors as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(grad,
        start: CGPoint(x: 0, y: s),
        end:   CGPoint(x: s, y: 0),
        options: [])

    // ── Monitor outline ────────────────────────────────────────────────
    let pad      = s * 0.12
    let mW       = s - pad * 2
    let mH       = mW * 0.62
    let mX       = pad
    let mY       = s * 0.52 - mH / 2
    let corner   = s * 0.08
    let stroke   = s * 0.045

    // Screen fill (dark blue tint)
    let screenPath = CGMutablePath()
    screenPath.addRoundedRect(
        in: CGRect(x: mX + stroke/2, y: mY + stroke/2,
                   width: mW - stroke, height: mH - stroke),
        cornerWidth: corner, cornerHeight: corner)
    ctx.setFillColor(NSColor(red: 0.05, green: 0.12, blue: 0.25, alpha: 1).cgColor)
    ctx.addPath(screenPath)
    ctx.fillPath()

    // Screen border (cyan)
    let borderPath = CGMutablePath()
    borderPath.addRoundedRect(
        in: CGRect(x: mX + stroke/2, y: mY + stroke/2,
                   width: mW - stroke, height: mH - stroke),
        cornerWidth: corner, cornerHeight: corner)
    ctx.setStrokeColor(NSColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 1).cgColor)
    ctx.setLineWidth(stroke)
    ctx.addPath(borderPath)
    ctx.strokePath()

    // Stand base
    let baseW = mW * 0.35
    let baseH = s * 0.05
    let baseX = mX + (mW - baseW) / 2
    let baseY = mY - baseH - s * 0.02
    let basePath = CGMutablePath()
    basePath.addRoundedRect(
        in: CGRect(x: baseX, y: baseY, width: baseW, height: baseH),
        cornerWidth: baseH/2, cornerHeight: baseH/2)
    ctx.setFillColor(NSColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 0.7).cgColor)
    ctx.addPath(basePath)
    ctx.fillPath()

    // Stand neck
    let neckW  = baseW * 0.18
    let neckH  = s * 0.07
    let neckX  = mX + mW/2 - neckW/2
    let neckY  = mY
    ctx.setFillColor(NSColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 0.7).cgColor)
    ctx.fill(CGRect(x: neckX, y: neckY, width: neckW, height: neckH))

    // ── Text: "Mac Display" ────────────────────────────────────────────
    let fontSize = s * 0.155
    let textColor = NSColor.white

    let paraStyle = NSMutableParagraphStyle()
    paraStyle.alignment = .center

    let topAttrs: [NSAttributedString.Key: Any] = [
        .font:            NSFont.boldSystemFont(ofSize: fontSize),
        .foregroundColor: textColor,
        .paragraphStyle:  paraStyle
    ]
    let botAttrs: [NSAttributedString.Key: Any] = [
        .font:            NSFont.systemFont(ofSize: fontSize * 0.72, weight: .light),
        .foregroundColor: NSColor(white: 0.75, alpha: 1),
        .paragraphStyle:  paraStyle
    ]

    let line1 = "Mac" as NSString
    let line2 = "Display" as NSString

    let h1 = line1.size(withAttributes: topAttrs).height
    let h2 = line2.size(withAttributes: botAttrs).height
    let totalH = h1 + h2 + s * 0.01
    let textTop = mY + mH * 0.55 + totalH / 2

    line1.draw(in: CGRect(x: mX, y: textTop - h1,         width: mW, height: h1 + 2), withAttributes: topAttrs)
    line2.draw(in: CGRect(x: mX, y: textTop - h1 - h2 - s * 0.01, width: mW, height: h2 + 2), withAttributes: botAttrs)

    img.unlockFocus()
    return img
}

for (dir, size) in sizes {
    let img = generateIcon(size: size)
    let path = "\(resDir)/\(dir)/ic_launcher.png"
    guard let tiff = img.tiffRepresentation,
          let rep  = NSBitmapImageRep(data: tiff),
          let png  = rep.representation(using: .png, properties: [:]) else {
        print("✗ Failed for \(dir)")
        continue
    }
    do {
        try png.write(to: URL(fileURLWithPath: path))
        print("✓ \(dir)/ic_launcher.png  (\(size)×\(size))")
    } catch {
        print("✗ \(dir): \(error)")
    }
}
print("")
print("Done.")
