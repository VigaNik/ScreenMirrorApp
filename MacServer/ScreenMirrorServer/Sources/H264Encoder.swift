import Foundation
import VideoToolbox
import CoreMedia
import CoreVideo

class H264Encoder {
    private var compressionSession: VTCompressionSession?
    private let width: Int
    private let height: Int
    private let fps: Int32
    private let bitrate: Int
    private var onEncodedData: ((Data, Bool) -> Void)?

    // Start codes for Annex B format
    private let startCode4: [UInt8] = [0x00, 0x00, 0x00, 0x01]
    private let startCode3: [UInt8] = [0x00, 0x00, 0x01]

    init(width: Int, height: Int, fps: Int32 = 60, bitrate: Int = 8_000_000) {
        self.width = width
        self.height = height
        self.fps = fps
        self.bitrate = bitrate
    }

    func start(onEncodedData: @escaping (Data, Bool) -> Void) throws {
        self.onEncodedData = onEncodedData

        var session: VTCompressionSession?

        // Create compression session with callback
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: encodingCallback,
            refcon: nil,
            compressionSessionOut: &session
        )

        guard status == noErr, let session = session else {
            throw NSError(domain: "H264Encoder", code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Failed to create compression session"
            ])
        }

        self.compressionSession = session

        // Configure encoder properties for low latency
        try setProperty(session, key: kVTCompressionPropertyKey_RealTime, value: true)
        try setProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: false)
        try setProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: 60 as CFNumber)
        try setProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: fps as CFNumber)
        try setProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: bitrate as CFNumber)

        // Set profile level - High for better compression efficiency (CABAC)
        try setProperty(
            session,
            key: kVTCompressionPropertyKey_ProfileLevel,
            value: kVTProfileLevel_H264_High_AutoLevel
        )

        // Low latency settings
        let dataRateLimits = [
            bitrate / 8 as CFNumber,
            1 as CFNumber  // 1 second window
        ] as CFArray
        try setProperty(session, key: kVTCompressionPropertyKey_DataRateLimits, value: dataRateLimits)

        // Prepare to encode
        VTCompressionSessionPrepareToEncodeFrames(session)

        print("✓ H264Encoder initialized: \(width)x\(height) @ \(fps)fps, \(bitrate/1_000_000)Mbps")
    }

    private func setProperty<T>(_ session: VTCompressionSession, key: CFString, value: T) throws {
        let status = VTSessionSetProperty(session, key: key, value: value as CFTypeRef)
        guard status == noErr else {
            throw NSError(domain: "H264Encoder", code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Failed to set property \(key)"
            ])
        }
    }

    func encode(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        guard let session = compressionSession else { return }

        var flags: VTEncodeInfoFlags = []

        // Store self reference for the callback
        let contextPointer = Unmanaged.passUnretained(self).toOpaque()

        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTime,
            duration: .invalid,
            frameProperties: nil,
            sourceFrameRefcon: contextPointer,
            infoFlagsOut: &flags
        )

        if status != noErr {
            print("✗ VTCompressionSessionEncodeFrame failed: \(status)")
        }
    }

    private let encodingCallback: VTCompressionOutputCallback = { (
        outputCallbackRefCon: UnsafeMutableRawPointer?,
        sourceFrameRefCon: UnsafeMutableRawPointer?,
        status: OSStatus,
        infoFlags: VTEncodeInfoFlags,
        sampleBuffer: CMSampleBuffer?
    ) in
        guard status == noErr, let sampleBuffer = sampleBuffer else {
            if status != noErr {
                print("✗ Encoding error: \(status)")
            }
            return
        }

        guard let refCon = sourceFrameRefCon else { return }
        let encoder = Unmanaged<H264Encoder>.fromOpaque(refCon).takeUnretainedValue()
        encoder.handleEncodedFrame(sampleBuffer)
    }

    private func handleEncodedFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]],
              let attachment = attachments.first else {
            return
        }

        // Check if this is a keyframe (IDR)
        let isKeyframe = !(attachment[kCMSampleAttachmentKey_NotSync] as? Bool ?? false)

        // Extract SPS and PPS from format description on keyframes
        if isKeyframe {
            if let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {
                extractAndSendSPSPPS(from: formatDescription)
            }
        }

        // Convert AVCC format to Annex B format
        guard let annexBData = convertToAnnexB(sampleBuffer: sampleBuffer) else {
            print("✗ Failed to convert to Annex B format")
            return
        }

        // Send encoded data
        onEncodedData?(annexBData, isKeyframe)
    }

    private func extractAndSendSPSPPS(from formatDescription: CMFormatDescription) {
        var spsSize: Int = 0
        var spsCount: Int = 0
        var nalUnitHeaderLength: Int32 = 0
        var sps: UnsafePointer<UInt8>?

        // Get SPS
        var status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            formatDescription,
            parameterSetIndex: 0,
            parameterSetPointerOut: &sps,
            parameterSetSizeOut: &spsSize,
            parameterSetCountOut: &spsCount,
            nalUnitHeaderLengthOut: &nalUnitHeaderLength
        )

        guard status == noErr, let spsPointer = sps else {
            print("✗ Failed to extract SPS")
            return
        }

        var ppsSize: Int = 0
        var ppsCount: Int = 0
        var pps: UnsafePointer<UInt8>?

        // Get PPS
        status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            formatDescription,
            parameterSetIndex: 1,
            parameterSetPointerOut: &pps,
            parameterSetSizeOut: &ppsSize,
            parameterSetCountOut: &ppsCount,
            nalUnitHeaderLengthOut: nil
        )

        guard status == noErr, let ppsPointer = pps else {
            print("✗ Failed to extract PPS")
            return
        }

        // Create Annex B formatted SPS and PPS
        var spsAnnexB = Data(startCode4)
        spsAnnexB.append(spsPointer, count: spsSize)

        var ppsAnnexB = Data(startCode4)
        ppsAnnexB.append(ppsPointer, count: ppsSize)

        // Send SPS and PPS immediately
        onEncodedData?(spsAnnexB, true)
        onEncodedData?(ppsAnnexB, true)

        print("✓ Extracted SPS (\(spsSize) bytes) and PPS (\(ppsSize) bytes)")
    }

    private func convertToAnnexB(sampleBuffer: CMSampleBuffer) -> Data? {
        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }

        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?

        let status = CMBlockBufferGetDataPointer(
            dataBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &totalLength,
            dataPointerOut: &dataPointer
        )

        guard status == noErr, let dataPointer = dataPointer else {
            return nil
        }

        var annexBData = Data()
        var offset = 0

        // Parse AVCC format and convert to Annex B
        while offset < totalLength {
            // Read 4-byte length (big endian)
            var nalLength: UInt32 = 0
            memcpy(&nalLength, dataPointer.advanced(by: offset), 4)
            nalLength = CFSwapInt32BigToHost(nalLength)

            offset += 4

            // Replace length with start code
            annexBData.append(contentsOf: startCode4)

            // Append NAL unit data
            let nalBytes = UnsafeBufferPointer(start: dataPointer.advanced(by: offset), count: Int(nalLength))
            annexBData.append(contentsOf: nalBytes.map { UInt8(bitPattern: $0) })

            offset += Int(nalLength)
        }

        return annexBData
    }

    func stop() {
        if let session = compressionSession {
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(session)
            compressionSession = nil
        }
        print("✓ H264Encoder stopped")
    }

    deinit {
        stop()
    }
}
