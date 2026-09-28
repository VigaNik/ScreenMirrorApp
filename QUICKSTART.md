# Quick Start Guide

Быстрая инструкция для запуска Screen Mirror системы.

## Шаг 1: Подключение Android устройства

### Через USB (рекомендуется для минимальной задержки)

```bash
# Подключите планшет по USB к Mac
# Убедитесь что USB debugging включен на Android

# Проверьте подключение
adb devices

# Пробросьте порт 5000
adb forward tcp:5000 tcp:5000
```

### Через Wi-Fi (альтернатива)

1. Узнайте IP адрес Mac:
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
# Например: 192.168.1.100
```

2. Измените код в Android приложении (MainActivity.kt:89):
```kotlin
networkReceiver = NetworkReceiver(
    host = "192.168.1.100",  // Ваш IP адрес Mac
    port = 5000,
    // ...
)
```

3. Пересоберите APK и установите

## Шаг 2: Сборка MacServer

```bash
cd MacServer

# Быстрая сборка и запуск
./run.sh

# Или вручную
swift build -c release
.build/release/ScreenMirrorServer
```

### Разрешения macOS

При первом запуске macOS попросит разрешение на **Screen Recording**.

**Как дать разрешение:**
1. Откройте **System Settings** → **Privacy & Security** → **Screen Recording**
2. Найдите `ScreenMirrorServer` и включите галочку
3. Перезапустите приложение

## Шаг 3: Установка Android приложения

```bash
cd AndroidClient

# Сборка APK
./gradlew assembleDebug

# Установка на устройство
adb install app/build/outputs/apk/debug/app-debug.apk
```

Или откройте проект в Android Studio и нажмите Run.

## Шаг 4: Запуск трансляции

### На Mac:
```bash
cd MacServer
./run.sh
```

Вы увидите:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Screen Mirror Server
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ TCP Server listening on port 5000
✓ Using display: 1920x1080
✓ H264Encoder initialized: 1920x1080 @ 30fps, 10Mbps
✓ Screen capture started: 1920x1080 @ 30fps

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Server is running
  Press Ctrl+C to stop
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### На Android:
1. Запустите приложение **Screen Mirror Client**
2. Нажмите **"Connect to Server"**
3. Через 1-2 секунды вы увидите экран Mac на планшете

## Ожидаемые логи

### MacServer (после подключения клиента):
```
✓ New client connected from [::1]:52341
→ Sending SPS (25 bytes) and PPS (4 bytes) to new client
✓ SPS captured (25 bytes)
✓ PPS captured (4 bytes)
✓ Captured 150 frames (1920x1080)
→ Sent 150 frames | Latest: P-frame (15234 bytes) | Clients: 1
```

### Android Logcat:
```
D/NetworkReceiver: Connecting to localhost:5000
D/NetworkReceiver: Connected successfully
D/NALUnitParser: NAL unit: type=7, size=29, keyFrame=true
D/NALUnitParser: NAL unit: type=8, size=8, keyFrame=true
D/H264Decoder: Decoder configured and started
D/NALUnitParser: NAL unit: type=5, size=85123, keyFrame=true
```

## Остановка

### MacServer:
Нажмите `Ctrl+C` в терминале

### Android:
Нажмите кнопку **"Disconnect"** или закройте приложение

## Troubleshooting

### Черный экран на Android
- ✓ Убедитесь что MacServer работает и показывает "Client connected"
- ✓ Проверьте `adb forward tcp:5000 tcp:5000`
- ✓ Посмотрите Android logcat на наличие ошибок декодера

### "Connection refused"
- ✓ MacServer должен быть запущен **до** подключения Android
- ✓ Проверьте что порт 5000 не занят: `lsof -i :5000`
- ✓ При Wi-Fi подключении проверьте IP адрес и firewall

### "Screen Recording permission denied"
- ✓ Откройте System Settings → Privacy & Security → Screen Recording
- ✓ Добавьте ScreenMirrorServer в список разрешенных приложений
- ✓ Перезапустите MacServer

### Высокая задержка (>500ms)
- ✓ Используйте USB вместо Wi-Fi
- ✓ Закройте другие приложения на Mac/Android
- ✓ Уменьшите битрейт в H264Encoder.swift (строка 18)

### Разрывы или артефакты видео
- ✓ Проверьте стабильность USB соединения
- ✓ Увеличьте битрейт для лучшего качества
- ✓ При Wi-Fi используйте 5GHz band

## Настройка параметров

### Изменить разрешение/FPS
**MacServer** (H264Encoder.swift:18):
```swift
init(width: Int, height: Int, fps: Int32 = 30, bitrate: Int = 10_000_000)
```

### Изменить битрейт
Для более высокого качества (больше трафика):
```swift
H264Encoder(width: width, height: height, fps: 30, bitrate: 15_000_000)
```

Для экономии трафика (хуже качество):
```swift
H264Encoder(width: width, height: height, fps: 30, bitrate: 5_000_000)
```

### Изменить порт
**MacServer** (main.swift:6):
```swift
private let tcpServer = TCPServer(port: 8080)
```

**Android** (MainActivity.kt:89):
```kotlin
networkReceiver = NetworkReceiver(
    host = "localhost",
    port = 8080,  // Совпадает с MacServer
    // ...
)
```

## Производительность

Типичные показатели при 1920x1080 @ 30fps, 10Mbps:
- **CPU Usage (Mac)**: 15-25%
- **CPU Usage (Android)**: 10-20%
- **Latency**: 100-200ms (USB), 200-400ms (Wi-Fi)
- **Network Traffic**: ~1.2 MB/s
- **Frame Size**: I-frame ~50-100KB, P-frame ~5-20KB

## Полезные команды

```bash
# Мониторинг сетевых соединений
lsof -i :5000

# Логи Android в реальном времени
adb logcat | grep -E "NetworkReceiver|H264Decoder|NALUnitParser"

# Проверка что adb forward активен
adb forward --list

# Сброс всех forward правил
adb forward --remove-all

# Проверка версии Android
adb shell getprop ro.build.version.release

# Проверка поддержки H.264 decoder на Android
adb shell pm list features | grep codec
```
