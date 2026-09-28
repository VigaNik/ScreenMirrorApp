# Screen Mirror Android Client

Android приложение для приема H.264 видеопотока с macOS через TCP сокеты.

## Архитектура

### Основные компоненты:

1. **MainActivity.kt** - Главный экран с SurfaceView и управлением подключением
2. **H264Decoder.kt** - Аппаратный декодер на базе MediaCodec с низкой задержкой
3. **NetworkReceiver.kt** - TCP клиент для приема данных
4. **NALUnitParser.kt** - Парсер NAL-юнитов из байтового потока

## Особенности реализации

### Low Latency настройки:
- `MediaFormat.KEY_LOW_LATENCY = 1` - режим низкой задержки в декодере
- `tcpNoDelay = true` - отключение алгоритма Nagle
- Прямой рендеринг на Surface без буферизации

### Парсинг потока:
- Поиск NAL start codes (0x00000001 или 0x000001)
- Определение типа NAL-юнита (IDR, SPS, PPS)
- Автоматическое определение ключевых кадров

### Безопасность:
- Проверка на переполнение буфера (100KB threshold)
- Graceful shutdown при ошибках
- Thread-safe операции с AtomicBoolean

## Сборка и установка

```bash
# Сборка APK
cd AndroidClient
./gradlew assembleDebug

# Установка на устройство
adb install app/build/outputs/apk/debug/app-debug.apk

# Проброс порта для локального подключения
adb forward tcp:5000 tcp:5000
```

## Использование

1. Подключите Android планшет по USB
2. Выполните `adb forward tcp:5000 tcp:5000`
3. Запустите приложение на планшете
4. Нажмите "Connect to Server"
5. Запустите MacServer на macOS

## Системные требования

- Android 7.0 (API 24) или выше
- Поддержка аппаратного декодирования H.264
- Разрешение экрана: минимум 1280x720

## Порт подключения

По умолчанию: `localhost:5000` (через adb forward)
Для Wi-Fi подключения измените host в MainActivity.kt на IP адрес Mac.
