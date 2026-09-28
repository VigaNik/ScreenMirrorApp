# Screen Mirror Application

> Older Russian notes (January 2026). Some parameters here are out of date; see [README.md](README.md).

Система трансляции экрана с macOS на Android планшет через TCP сокеты с минимальной задержкой.

## Архитектура

```
┌──────────────────┐                    ┌──────────────────┐
│   MacBook        │                    │  Android Tablet  │
│                  │                    │                  │
│  ┌────────────┐  │                    │  ┌────────────┐  │
│  │ScreenCapture│  │                    │  │SurfaceView │  │
│  │  (SCKit)   │  │                    │  │  (Render)  │  │
│  └──────┬─────┘  │                    │  └──────▲─────┘  │
│         │        │                    │         │        │
│         ▼        │                    │         │        │
│  ┌────────────┐  │                    │  ┌────────────┐  │
│  │ H264Encoder│  │                    │  │ H264Decoder│  │
│  │ VideoToolbox│ │  TCP Stream       │  │ MediaCodec │  │
│  │ AVCC→AnnexB│  │ ───────────────►  │  │  (HW Acc)  │  │
│  └──────┬─────┘  │  Port 5000        │  └──────▲─────┘  │
│         │        │                    │         │        │
│         ▼        │                    │         │        │
│  ┌────────────┐  │                    │  ┌────────────┐  │
│  │ TCPServer  │  │                    │  │ TCPClient  │  │
│  │  (Network) │  │                    │  │  (Socket)  │  │
│  └────────────┘  │                    │  └────────────┘  │
└──────────────────┘                    └──────────────────┘
```

## Протокол передачи

### Формат данных: H.264 Annex B
```
[00 00 00 01][SPS]
[00 00 00 01][PPS]
[00 00 00 01][IDR frame (I-frame)]
[00 00 00 01][P-frame]
[00 00 00 01][P-frame]
...
```

### Последовательность инициализации:
1. Android клиент подключается к MacServer (TCP port 5000)
2. MacServer отправляет SPS и PPS параметры
3. MacServer начинает отправку видео фреймов
4. Android клиент декодирует и отображает на SurfaceView

## Компоненты

### MacServer (Swift, macOS 13+)
- **ScreenCapture** - Захват экрана через ScreenCaptureKit
- **H264Encoder** - Аппаратное сжатие H.264 + конвертация AVCC → Annex B
- **TCPServer** - TCP сервер на Network.framework

**Ключевые особенности:**
- Конвертация из AVCC (length-prefixed) в Annex B (start codes)
- Извлечение и отправка SPS/PPS перед первым кадром
- Low latency: `RealTime=true`, `AllowFrameReordering=false`
- H.264 Baseline Profile для совместимости

### AndroidClient (Kotlin, Android 7+)
- **MainActivity** - UI с SurfaceView и управлением подключением
- **H264Decoder** - MediaCodec с низкой задержкой
- **NetworkReceiver** - TCP клиент с парсингом потока
- **NALUnitParser** - Поиск NAL unit boundaries (start codes)

**Ключевые особенности:**
- MediaCodec с флагом `KEY_LOW_LATENCY`
- Парсинг NAL units из байтового потока
- Определение типа NAL (SPS/PPS/IDR/Non-IDR)
- Thread-safe операции

## Быстрый старт

### 1. Сборка MacServer
```bash
cd MacServer
swift build -c release
```

### 2. Сборка AndroidClient
```bash
cd AndroidClient
./gradlew assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
```

### 3. Подключение через USB
```bash
# Проброс порта
adb forward tcp:5000 tcp:5000
```

### 4. Запуск
```bash
# На Mac
cd MacServer
.build/release/ScreenMirrorServer

# На Android
# Запустите приложение и нажмите "Connect to Server"
```

## Альтернатива: Wi-Fi подключение

**На Mac:**
```bash
# Узнать IP адрес Mac
ifconfig | grep "inet " | grep -v 127.0.0.1
```

**В Android коде** (MainActivity.kt:89):
```kotlin
networkReceiver = NetworkReceiver(
    host = "192.168.1.XXX",  // IP адрес Mac
    port = 5000,
    // ...
)
```

## Технические детали

### Видео параметры
- **Разрешение**: Автоматически (по размеру экрана Mac)
- **Частота кадров**: 30 FPS
- **Битрейт**: 10 Mbps
- **Кодек**: H.264 Baseline Profile
- **Pixel Format**: NV12 (YUV 4:2:0)

### Network параметры
- **Протокол**: TCP
- **Порт**: 5000
- **Настройки**: TCP_NODELAY (без Nagle)
- **Буфер**: 64KB

### Задержка (Latency)
- **Захват**: ~16ms (60Hz display)
- **Кодирование**: ~10-20ms (HW accelerated)
- **Сеть (USB)**: ~5-10ms
- **Декодирование**: ~10-20ms (HW accelerated)
- **Рендеринг**: ~16ms
- **Итого**: ~100-200ms (зависит от условий)

## Отладка

### MacServer логи
```
✓ TCP Server listening on port 5000
✓ Using display: 1920x1080
✓ H264Encoder initialized: 1920x1080 @ 30fps, 10Mbps
✓ SPS captured (25 bytes)
✓ PPS captured (4 bytes)
✓ New client connected
→ Sending SPS and PPS to new client
✓ Screen capture started
→ Sent 150 frames | Latest: P-frame (15234 bytes) | Clients: 1
```

### AndroidClient логи (Logcat)
```
D/NetworkReceiver: Connecting to localhost:5000
D/NetworkReceiver: Connected successfully
D/NALUnitParser: NAL unit: type=7, size=29, keyFrame=true  # SPS
D/NALUnitParser: NAL unit: type=8, size=8, keyFrame=true   # PPS
D/H264Decoder: Decoder configured and started
D/NALUnitParser: NAL unit: type=5, size=85123, keyFrame=true  # I-frame
D/NALUnitParser: NAL unit: type=1, size=12456, keyFrame=false # P-frame
```

## Требования

### macOS
- macOS 13.0 (Ventura) или новее
- Разрешение Screen Recording в System Settings

### Android
- Android 7.0 (API 24) или новее
- Поддержка аппаратного декодирования H.264
- USB OTG или Wi-Fi подключение

## Известные проблемы

1. **Черный экран на Android**
   - Проверьте что SPS/PPS отправлены перед первым I-frame
   - Убедитесь что NAL parser правильно находит start codes

2. **Высокая задержка**
   - Уменьшите разрешение или битрейт
   - Проверьте использование USB 3.0
   - Используйте Wi-Fi 5GHz вместо 2.4GHz

3. **Разрыв соединения**
   - Проверьте что Mac не уходит в сон
   - Отключите энергосбережение USB на Android

## Лицензия

MIT License

## Автор

Created for screen mirroring with low latency H.264 streaming.
