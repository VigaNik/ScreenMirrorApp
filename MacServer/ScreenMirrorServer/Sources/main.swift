import Foundation
import CoreMedia
import ScreenCaptureKit

@available(macOS 13.0, *)
class ScreenMirrorServer {
    private let tcpServer = TCPServer(port: 5000)
    private var screenCapture: ScreenCapture?
    private var encoder: H264Encoder?

    private var isRunning = false
    private var spsData: Data?
    private var ppsData: Data?
    private var frameCount = 0

    func start() async throws {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("  Screen Mirror Server")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("")

        // Get available displays
        let content = try await SCShareableContent.current

        guard !content.displays.isEmpty else {
            throw NSError(
                domain: "ScreenMirrorServer",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No displays found"]
            )
        }

        // Display list of available displays
        print("Available Displays:")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        for (index, display) in content.displays.enumerated() {
            // Try to get a friendly name, fallback to generic
            let displayName = "Display \(display.displayID)"
            print("\(index): \(displayName) (\(display.width) x \(display.height))")
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("")

        // Ask user to select a display
        print("Enter display index to capture (0-\(content.displays.count - 1)): ", terminator: "")
        fflush(stdout)

        guard let input = readLine(),
              let selectedIndex = Int(input),
              selectedIndex >= 0,
              selectedIndex < content.displays.count else {
            throw NSError(
                domain: "ScreenMirrorServer",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid display index"]
            )
        }

        let selectedDisplay = content.displays[selectedIndex]
        print("✓ Selected: Display \(selectedDisplay.displayID) (\(selectedDisplay.width)x\(selectedDisplay.height))")
        print("")

        // Start TCP server
        try tcpServer.start { [weak self] in
            print("✓ Client connected. Active clients: \(self?.tcpServer.clientCount ?? 0)")

            // Send stored SPS/PPS to new client
            if let sps = self?.spsData, let pps = self?.ppsData {
                self?.tcpServer.storeSPSPPS(sps: sps, pps: pps)
            }
        }

        let width = selectedDisplay.width
        let height = selectedDisplay.height

        // Initialize encoder with selected display dimensions (60 FPS for smooth cursor)
        encoder = H264Encoder(width: width, height: height, fps: 60, bitrate: 8_000_000)

        var isFirstSPS = true

        try encoder?.start { [weak self] data, isKeyframe in
            guard let self = self else { return }

            // Detect SPS and PPS (they come before IDR frames)
            let nalType = self.getNALType(from: data)

            if nalType == 7 {  // SPS
                self.spsData = data
                if isFirstSPS {
                    print("✓ SPS captured (\(data.count) bytes)")
                    isFirstSPS = false
                }
                return  // Don't broadcast yet
            } else if nalType == 8 {  // PPS
                self.ppsData = data
                print("✓ PPS captured (\(data.count) bytes)")

                // Store SPS/PPS in server for new clients
                if let sps = self.spsData, let pps = self.ppsData {
                    self.tcpServer.storeSPSPPS(sps: sps, pps: pps)
                }
                return  // Don't broadcast yet
            }

            // Broadcast frame data to all clients
            self.tcpServer.broadcast(data: data)

            self.frameCount += 1
            if self.frameCount % 150 == 0 {  // Log every 5 seconds
                let frameType = isKeyframe ? "I-frame" : "P-frame"
                print("→ Sent \(self.frameCount) frames | Latest: \(frameType) (\(data.count) bytes) | Clients: \(self.tcpServer.clientCount)")
            }
        }

        // Start screen capture with selected display
        screenCapture = ScreenCapture()
        try await screenCapture?.start(display: selectedDisplay, onFrameCaptured: { [weak self] pixelBuffer, presentationTime in
            self?.encoder?.encode(pixelBuffer: pixelBuffer, presentationTime: presentationTime)
        })

        isRunning = true

        print("")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("  Server is running at 60 FPS")
        print("  Resolution: \(width)x\(height)")
        print("  Bitrate: 8 Mbps")
        print("  Press Ctrl+C to stop")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("")

        // Keep running indefinitely using Task.sleep
        // This prevents the function from returning while server is active
        while isRunning {
            try await Task.sleep(nanoseconds: 1_000_000_000) // Sleep 1 second
        }
    }

    private func getNALType(from data: Data) -> UInt8 {
        // Skip start code (4 bytes: 00 00 00 01)
        guard data.count > 4 else { return 0 }
        let nalHeaderByte = data[4]
        return nalHeaderByte & 0x1F  // Lower 5 bits = NAL type
    }

    func stop() async {
        guard isRunning else { return }

        print("")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("  Stopping server...")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        await screenCapture?.stop()
        encoder?.stop()
        tcpServer.stop()

        isRunning = false

        print("✓ Server stopped")
        print("✓ Total frames sent: \(frameCount)")
    }
}

// Signal handling for graceful shutdown
var server: ScreenMirrorServer?

func signalHandler(signal: Int32) {
    print("\n✓ Received signal \(signal)")

    Task {
        await server?.stop()
        exit(0)
    }
}

// Main entry point
if #available(macOS 13.0, *) {
    signal(SIGINT, signalHandler)
    signal(SIGTERM, signalHandler)

    server = ScreenMirrorServer()

    Task {
        do {
            try await server?.start()
        } catch {
            print("✗ Fatal error: \(error)")
            exit(1)
        }
    }

    RunLoop.main.run()
} else {
    print("✗ This application requires macOS 13.0 or later")
    exit(1)
}
