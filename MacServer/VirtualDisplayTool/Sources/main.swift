import Foundation
import CoreGraphics
import CGVirtualDisplayBridge

// ─── Resolutions ───────────────────────────────────────────────────────────

struct Resolution {
    let width: Int
    let height: Int
    let label: String
}

let resolutions: [Resolution] = [
    // ── Landscape ──
    Resolution(width: 2000, height: 1200, label: "2000×1200  Landscape  (native)"),
    Resolution(width: 1920, height: 1200, label: "1920×1200  Landscape"),
    Resolution(width: 1440, height: 900,  label: "1440×900   Landscape"),
    // ── Portrait ──
    Resolution(width: 1200, height: 2000, label: "1200×2000  Portrait   (native)"),
    Resolution(width: 1200, height: 1920, label: "1200×1920  Portrait"),
    Resolution(width: 900,  height: 1440, label: "900×1440   Portrait"),
]

// ─── Menu helpers ──────────────────────────────────────────────────────────

func printBanner() {
    print("")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("  Virtual Display Tool")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("")
}

func pickResolution() -> Resolution {
    print("Select resolution:")
    print("")
    print("  ── Landscape ──")
    for i in 0..<3 {
        print("  \(i): \(resolutions[i].label)")
    }
    print("")
    print("  ── Portrait ──")
    for i in 3..<6 {
        print("  \(i): \(resolutions[i].label)")
    }
    print("")
    print("Enter number (0–5): ", terminator: "")
    fflush(stdout)

    while true {
        if let line = readLine(), let idx = Int(line), idx >= 0, idx < resolutions.count {
            return resolutions[idx]
        }
        print("Invalid. Enter 0–5: ", terminator: "")
        fflush(stdout)
    }
}

// ─── Virtual display ───────────────────────────────────────────────────────

func createVirtualDisplay(width: Int, height: Int) -> CGVirtualDisplay? {
    let descriptor = CGVirtualDisplayDescriptor()
    descriptor.name = "ScreenMirror Virtual"
    // Approximate physical size at ~110 ppi (tablet-sized)
    descriptor.sizeInMillimeters = CGSize(
        width:  Double(width)  / 4.33,
        height: Double(height) / 4.33
    )

    guard let display = CGVirtualDisplay(descriptor: descriptor) else {
        return nil
    }

    let settings = CGVirtualDisplaySettings()
    settings.hiDPI = 0   // native pixel mapping, no 2× Retina scaling

    let mode = CGVirtualDisplayMode(
        width: UInt(width),
        height: UInt(height),
        refreshRate: 60.0
    )

    let ok = display.apply(settings, modeList: [mode])
    return ok ? display : nil
}

// ─── Main ──────────────────────────────────────────────────────────────────

printBanner()
let chosen = pickResolution()

print("")
print("→ Creating \(chosen.width)×\(chosen.height) @ 60 Hz virtual display...")

guard let virtualDisplay = createVirtualDisplay(width: chosen.width, height: chosen.height) else {
    print("✗ Failed to create virtual display.")
    print("")
    print("  Possible reasons:")
    print("  • macOS < 12.4")
    print("  • Missing entitlement (try: sudo ./VirtualDisplayTool)")
    print("  • Another virtual display already active")
    exit(1)
}

print("✓ Virtual display active!")
print("  Resolution : \(chosen.width)×\(chosen.height)")
print("  Refresh    : 60 Hz")
print("  Display ID : \(virtualDisplay.displayID)")
print("")
print("  Go to System Settings → Displays to arrange it.")
print("")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("  Running. Press Ctrl+C to remove display.")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("")

// Keep the display alive by holding a strong reference.
// Releasing CGVirtualDisplay automatically removes the display from macOS.
var keepAlive: CGVirtualDisplay? = virtualDisplay

signal(SIGINT)  { _ in
    print("\n✓ Removing virtual display...")
    keepAlive = nil
    exit(0)
}
signal(SIGTERM) { _ in
    keepAlive = nil
    exit(0)
}

RunLoop.main.run()
