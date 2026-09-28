import Foundation
import ScreenCaptureKit
import CoreMedia
import CoreVideo

@available(macOS 13.0, *)
class ScreenCapture: NSObject {
    private var stream: SCStream?
    private var onFrameCaptured: ((CVPixelBuffer, CMTime) -> Void)?
    private var frameCount: Int64 = 0
    private let fps: Int32 = 60

    func start(display: SCDisplay, onFrameCaptured: @escaping (CVPixelBuffer, CMTime) -> Void) async throws {
        self.onFrameCaptured = onFrameCaptured

        print("✓ Using display: \(display.width)x\(display.height)")

        // Configure stream with exact display dimensions
        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        config.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange  // NV12 format
        config.queueDepth = 3  // Low latency
        config.showsCursor = true

        // Create filter for the display
        let filter = SCContentFilter(display: display, excludingWindows: [])

        // Create stream
        stream = SCStream(filter: filter, configuration: config, delegate: self)

        // Add stream output
        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)

        // Start capture
        try await stream?.startCapture()

        print("✓ Screen capture started: \(config.width)x\(config.height) @ \(fps)fps")
    }

    func stop() async {
        if let stream = stream {
            do {
                try await stream.stopCapture()
                print("✓ Screen capture stopped")
            } catch {
                print("✗ Error stopping capture: \(error)")
            }
        }
        stream = nil
    }
}

@available(macOS 13.0, *)
extension ScreenCapture: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("✗ Stream stopped with error: \(error)")
    }
}

@available(macOS 13.0, *)
extension ScreenCapture: SCStreamOutput {
    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen else { return }

        // Get pixel buffer from sample buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // Get presentation time
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Invoke callback with pixel buffer
        onFrameCaptured?(pixelBuffer, presentationTime)

        frameCount += 1

        // Log stats every 5 seconds
        if frameCount % (Int64(fps) * 5) == 0 {
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            print("✓ Captured \(frameCount) frames (\(width)x\(height))")
        }
    }
}
