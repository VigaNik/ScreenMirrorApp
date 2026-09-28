# ScreenMirror

Stream a Mac screen to an Android tablet over USB with low latency, so the
tablet works as a second display.

The Mac captures a display with ScreenCaptureKit, encodes it to H.264 in
hardware with VideoToolbox, and sends the stream over TCP. The Android app
decodes it with MediaCodec and draws it on a `SurfaceView`. A separate tool
creates a virtual display on the Mac at the tablet's resolution, so the
tablet shows its own desktop space rather than a copy of the main screen.

```
Mac                                              Android tablet
ScreenCaptureKit ─► VideoToolbox H.264 ─► TCP :5000 ══USB══► TCP client ─► MediaCodec ─► SurfaceView
                    (AVCC → Annex B)           (adb reverse)  (NAL parser)
```

---

## Components

**MacServer** (Swift, macOS 13+, Swift Package Manager)

| Target | Role |
|---|---|
| `ScreenMirrorServer` | Lists displays, asks which one to capture, streams it |
| `VirtualDisplayTool` | Creates a virtual display (landscape or portrait, up to 2000×1200) |
| `CGVirtualDisplayBridge` | Objective-C bridge to the `CGVirtualDisplay` classes in CoreGraphics |

**AndroidClient** (Kotlin, Android 7.0+ / API 24, target API 34)

| Class | Role |
|---|---|
| `MainActivity` | UI, connection control |
| `NetworkReceiver` | TCP client, reads the byte stream |
| `NALUnitParser` | Splits the stream on Annex B start codes, detects SPS/PPS/IDR |
| `H264Decoder` | MediaCodec in low-latency mode |

### Stream

| | |
|---|---|
| Codec | H.264, High profile, hardware encoder |
| Frame rate | 60 fps |
| Bitrate | 8 Mbit/s |
| Keyframe interval | 60 frames (1 s) |
| Encoder mode | real-time, no frame reordering |
| Transport | TCP, port 5000, `TCP_NODELAY` |
| Format on the wire | Annex B; SPS and PPS sent to each new client before the first frame |

---

## Running

### Requirements

- Mac with macOS 13 (Ventura) or later, Xcode command-line tools
- Android tablet with USB debugging enabled
- `adb` (Android SDK platform-tools)
- Screen Recording permission for the terminal you run the server from:
  System Settings → Privacy & Security → Screen Recording

### 1. Build and install the Android app

Open `AndroidClient/` in Android Studio and run it on the tablet.

The Gradle wrapper jar is not committed. To build from the command line,
generate it first with a local Gradle:

```bash
cd AndroidClient
gradle wrapper
./gradlew assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
```

### 2. (Optional) Create a virtual display

```bash
cd MacServer
./vdisplay.sh
```

Pick a resolution from the menu. Keep the tool running; the display
disappears when it exits.

### 3. Start streaming

Connect the tablet over USB and run from the repository root:

```bash
./start.sh
```

The script frees port 5000, checks that the tablet is connected, sets up
`adb reverse tcp:5000 tcp:5000`, then builds and starts the server. The server
lists the available displays and asks which one to capture.

Then open the app on the tablet and tap **Connect to Server**. The app connects to
`localhost:5000`, which `adb reverse` forwards to the Mac.

Without the script:

```bash
adb reverse tcp:5000 tcp:5000
cd MacServer && ./run.sh
```

---

## Troubleshooting

| Symptom | Check |
|---|---|
| Black screen on the tablet | Server log shows SPS and PPS captured and sent; reconnect to get a fresh keyframe |
| `start.sh`: tablet not found | `adb devices` lists the tablet; USB debugging is allowed |
| Port already in use | `start.sh` kills whatever holds port 5000; otherwise `lsof -ti :5000` |
| Capture fails at start | Screen Recording permission for the terminal, then restart the terminal |
| Stream stops | Mac went to sleep, or USB power saving on the tablet |

## Notes

- `CGVirtualDisplay` is a private macOS API. It works on current macOS versions
  but can change without notice.
- More detailed notes, in Russian: [README.ru.md](README.ru.md),
  [QUICKSTART.md](QUICKSTART.md), `MacServer/*.md`, `AndroidClient/*.md`.

## License

MIT
