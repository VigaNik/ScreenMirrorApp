package com.screenmirror

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.util.Log
import android.view.Surface
import java.nio.ByteBuffer

class H264Decoder(
    private val surface: Surface,
    private val onError: (String) -> Unit
) {
    private var mediaCodec: MediaCodec? = null
    private var isConfigured = false

    companion object {
        private const val TAG = "H264Decoder"
        private const val MIME_TYPE = MediaFormat.MIMETYPE_VIDEO_AVC
        private const val TIMEOUT_US = 10000L
    }

    init {
        try {
            setupDecoder()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize decoder", e)
            onError("Decoder initialization failed: ${e.message}")
        }
    }

    private fun setupDecoder() {
        // Create MediaCodec decoder for H.264
        mediaCodec = MediaCodec.createDecoderByType(MIME_TYPE)

        // Configure format with low latency settings
        val format = MediaFormat.createVideoFormat(MIME_TYPE, 1920, 1200).apply {
            // Low latency mode
            setInteger(MediaFormat.KEY_LOW_LATENCY, 1)
            setInteger(MediaFormat.KEY_PRIORITY, 0) // Real-time priority

            // Color format for output
            setInteger(
                MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface
            )
        }

        mediaCodec?.configure(format, surface, null, 0)
        mediaCodec?.start()
        isConfigured = true

        Log.d(TAG, "Decoder configured and started")
    }

    fun feedData(data: ByteArray, offset: Int, size: Int, isKeyFrame: Boolean) {
        if (!isConfigured) {
            Log.w(TAG, "Decoder not configured, skipping frame")
            return
        }

        try {
            val codec = mediaCodec ?: return

            // Get input buffer
            val inputBufferIndex = codec.dequeueInputBuffer(TIMEOUT_US)
            if (inputBufferIndex >= 0) {
                val inputBuffer = codec.getInputBuffer(inputBufferIndex)
                inputBuffer?.clear()
                inputBuffer?.put(data, offset, size)

                // Set flags for key frames (IDR frames)
                val flags = if (isKeyFrame) {
                    MediaCodec.BUFFER_FLAG_KEY_FRAME
                } else {
                    0
                }

                codec.queueInputBuffer(
                    inputBufferIndex,
                    0,
                    size,
                    System.nanoTime() / 1000,
                    flags
                )
            }

            // Release output buffers
            val bufferInfo = MediaCodec.BufferInfo()
            var outputBufferIndex = codec.dequeueOutputBuffer(bufferInfo, 0)

            while (outputBufferIndex >= 0) {
                // Render the frame to the surface
                codec.releaseOutputBuffer(outputBufferIndex, true)

                // Check for more output buffers
                outputBufferIndex = codec.dequeueOutputBuffer(bufferInfo, 0)
            }

            when (outputBufferIndex) {
                MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    val newFormat = codec.outputFormat
                    Log.d(TAG, "Output format changed: $newFormat")
                }
                MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    // No output available yet
                }
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error feeding data to decoder", e)
            onError("Decode error: ${e.message}")
        }
    }

    fun release() {
        try {
            mediaCodec?.stop()
            mediaCodec?.release()
            mediaCodec = null
            isConfigured = false
            Log.d(TAG, "Decoder released")
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing decoder", e)
        }
    }
}
