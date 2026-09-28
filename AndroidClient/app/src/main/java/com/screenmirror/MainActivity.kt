package com.screenmirror

import android.content.pm.ActivityInfo
import android.os.Bundle
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : AppCompatActivity() {

    private lateinit var surfaceView: SurfaceView
    private lateinit var statusText: TextView
    private lateinit var connectButton: Button
    private lateinit var orientationButton: Button

    private var videoDecoder: H264Decoder? = null
    private var networkReceiver: NetworkReceiver? = null

    private val isConnected = AtomicBoolean(false)
    // 4 orientations: Landscape → Portrait → Landscape Reverse → Portrait Reverse
    private val orientations = listOf(
        ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE         to "⟳ Portrait",
        ActivityInfo.SCREEN_ORIENTATION_PORTRAIT          to "⟳ Land. Rev",
        ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE to "⟳ Port. Rev",
        ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT  to "⟳ Landscape"
    )
    private var orientationIndex = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        // Keep screen on during streaming
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        surfaceView = findViewById(R.id.surfaceView)
        statusText = findViewById(R.id.statusText)
        connectButton = findViewById(R.id.connectButton)
        orientationButton = findViewById(R.id.orientationButton)

        setupSurfaceView()
        setupConnectButton()
        setupOrientationButton()
    }

    private fun setupSurfaceView() {
        surfaceView.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) {
                updateStatus("Surface ready")
            }

            override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
                updateStatus("Surface: ${width}x${height}")
            }

            override fun surfaceDestroyed(holder: SurfaceHolder) {
                stopStreaming()
            }
        })
    }

    private fun setupOrientationButton() {
        // Start in Landscape
        applyOrientation(0)

        orientationButton.setOnClickListener {
            orientationIndex = (orientationIndex + 1) % orientations.size
            applyOrientation(orientationIndex)
        }
    }

    private fun applyOrientation(index: Int) {
        val (orientation, nextLabel) = orientations[index]
        requestedOrientation = orientation
        orientationButton.text = nextLabel
    }

    private fun setupConnectButton() {
        connectButton.setOnClickListener {
            if (isConnected.get()) {
                stopStreaming()
            } else {
                startStreaming()
            }
        }
    }

    private fun startStreaming() {
        if (isConnected.get()) return

        try {
            updateStatus("Connecting to localhost:5000...")
            connectButton.isEnabled = false

            // Initialize decoder
            videoDecoder = H264Decoder(
                surface = surfaceView.holder.surface,
                onError = { error ->
                    runOnUiThread {
                        updateStatus("Decoder error: $error")
                        stopStreaming()
                    }
                }
            )

            // Initialize network receiver
            networkReceiver = NetworkReceiver(
                host = "localhost",
                port = 5000,
                decoder = videoDecoder!!,
                onConnected = {
                    runOnUiThread {
                        isConnected.set(true)
                        updateStatus("Connected - Streaming")
                        connectButton.text = "Disconnect"
                        connectButton.isEnabled = true
                    }
                },
                onDisconnected = {
                    runOnUiThread {
                        stopStreaming()
                    }
                },
                onError = { error ->
                    runOnUiThread {
                        updateStatus("Network error: $error")
                        stopStreaming()
                    }
                }
            )

            // Start receiving data
            networkReceiver?.start()

        } catch (e: Exception) {
            updateStatus("Failed to start: ${e.message}")
            stopStreaming()
        }
    }

    private fun stopStreaming() {
        isConnected.set(false)

        networkReceiver?.stop()
        networkReceiver = null

        videoDecoder?.release()
        videoDecoder = null

        connectButton.text = "Connect to Server"
        connectButton.isEnabled = true
        updateStatus("Disconnected")
    }

    private fun updateStatus(message: String) {
        runOnUiThread {
            statusText.text = message
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopStreaming()
    }

    override fun onPause() {
        super.onPause()
        // Keep streaming in background if needed
    }

    override fun onResume() {
        super.onResume()
    }
}
