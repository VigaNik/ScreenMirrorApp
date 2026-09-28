package com.screenmirror

import android.util.Log
import java.io.BufferedInputStream
import java.io.IOException
import java.net.Socket
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

class NetworkReceiver(
    private val host: String,
    private val port: Int,
    private val decoder: H264Decoder,
    private val onConnected: () -> Unit,
    private val onDisconnected: () -> Unit,
    private val onError: (String) -> Unit
) {
    private var socket: Socket? = null
    private var receiveThread: Thread? = null
    private val isRunning = AtomicBoolean(false)

    companion object {
        private const val TAG = "NetworkReceiver"
        private const val BUFFER_SIZE = 65536 // 64KB buffer
        private const val NAL_START_CODE = 0x00000001
        private const val NAL_START_CODE_3 = 0x000001
    }

    fun start() {
        if (isRunning.get()) return

        isRunning.set(true)
        receiveThread = thread(start = true) {
            connectAndReceive()
        }
    }

    private fun connectAndReceive() {
        try {
            Log.d(TAG, "Connecting to $host:$port")
            socket = Socket(host, port)
            socket?.tcpNoDelay = true // Disable Nagle's algorithm for low latency
            socket?.receiveBufferSize = BUFFER_SIZE

            Log.d(TAG, "Connected successfully")
            onConnected()

            val inputStream = BufferedInputStream(socket?.getInputStream(), BUFFER_SIZE)
            val nalParser = NALUnitParser()

            val buffer = ByteArray(BUFFER_SIZE)
            while (isRunning.get()) {
                val bytesRead = inputStream.read(buffer)
                if (bytesRead <= 0) {
                    Log.d(TAG, "Connection closed by server")
                    break
                }

                // Parse NAL units and feed to decoder
                nalParser.parse(buffer, 0, bytesRead) { nalUnit ->
                    decoder.feedData(
                        data = nalUnit.data,
                        offset = nalUnit.offset,
                        size = nalUnit.size,
                        isKeyFrame = nalUnit.isKeyFrame
                    )
                }
            }

        } catch (e: IOException) {
            Log.e(TAG, "Connection error", e)
            if (isRunning.get()) {
                onError("Connection failed: ${e.message}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected error", e)
            onError("Error: ${e.message}")
        } finally {
            cleanup()
            if (isRunning.get()) {
                onDisconnected()
            }
        }
    }

    fun stop() {
        isRunning.set(false)
        cleanup()
        receiveThread?.interrupt()
        receiveThread = null
    }

    private fun cleanup() {
        try {
            socket?.close()
            socket = null
        } catch (e: Exception) {
            Log.e(TAG, "Error closing socket", e)
        }
    }
}

/**
 * NAL Unit data holder
 */
data class NALUnit(
    val data: ByteArray,
    val offset: Int,
    val size: Int,
    val isKeyFrame: Boolean
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as NALUnit
        return offset == other.offset && size == other.size && isKeyFrame == other.isKeyFrame
    }

    override fun hashCode(): Int {
        var result = offset
        result = 31 * result + size
        result = 31 * result + isKeyFrame.hashCode()
        return result
    }
}

/**
 * Parser for H.264 NAL units from byte stream.
 *
 * Uses a plain ByteArray instead of MutableList<Byte> to avoid
 * per-byte boxing overhead. Appends chunks via System.arraycopy
 * and trims consumed bytes after each parse call.
 */
class NALUnitParser {
    private var buffer = ByteArray(0)
    private var nalStartIndex = -1

    companion object {
        private const val TAG = "NALUnitParser"
    }

    fun parse(data: ByteArray, offset: Int, length: Int, onNalUnit: (NALUnit) -> Unit) {
        // Append incoming chunk – one allocation, no boxing
        val prev = buffer
        buffer = ByteArray(prev.size + length)
        System.arraycopy(prev, 0, buffer, 0, prev.size)
        System.arraycopy(data, offset, buffer, prev.size, length)

        var searchIndex = if (nalStartIndex < 0) 0 else nalStartIndex

        while (searchIndex <= buffer.size - 3) {
            val scLen = startCodeLength(searchIndex)
            if (scLen > 0) {
                if (nalStartIndex >= 0 && searchIndex > nalStartIndex) {
                    extractNalUnit(nalStartIndex, searchIndex, onNalUnit)
                }
                nalStartIndex = searchIndex
                searchIndex += scLen
            } else {
                searchIndex++
            }
        }

        // Trim bytes before the current NAL start to keep buffer small
        if (nalStartIndex > 0) {
            buffer = buffer.copyOfRange(nalStartIndex, buffer.size)
            nalStartIndex = 0
        }
    }

    /** Returns start-code length (3 or 4) if one begins at [index], else 0. */
    private fun startCodeLength(index: Int): Int {
        val b = buffer
        return when {
            index + 3 < b.size &&
            b[index]     == 0x00.toByte() &&
            b[index + 1] == 0x00.toByte() &&
            b[index + 2] == 0x00.toByte() &&
            b[index + 3] == 0x01.toByte() -> 4

            index + 2 < b.size &&
            b[index]     == 0x00.toByte() &&
            b[index + 1] == 0x00.toByte() &&
            b[index + 2] == 0x01.toByte() -> 3

            else -> 0
        }
    }

    private fun extractNalUnit(start: Int, end: Int, onNalUnit: (NALUnit) -> Unit) {
        val scLen = startCodeLength(start)
        val nalBodyStart = start + scLen
        if (end <= nalBodyStart) return

        val nalType    = buffer[nalBodyStart].toInt() and 0x1F
        val isKeyFrame = nalType == 5 || nalType == 7 || nalType == 8

        // Slice without extra copy – reuse the existing array segment
        val nalData = buffer.copyOfRange(start, end)

        Log.d(TAG, "NAL unit: type=$nalType, size=${nalData.size}, keyFrame=$isKeyFrame")

        onNalUnit(NALUnit(data = nalData, offset = 0, size = nalData.size, isKeyFrame = isKeyFrame))
    }
}
