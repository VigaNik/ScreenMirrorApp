# Screen Mirror Server (macOS)

macOS приложение для захвата экрана и трансляции H.264 видео через TCP сокеты.

## Архитектура

### Основные компоненты:

1. **main.swift** - Точка входа, координация всех компонентов
2. **ScreenCapture.swift** - Захват экрана через ScreenCaptureKit
3. **H264Encoder.swift** - Аппаратное сжатие H.264 через VideoToolbox + конвертация AVCC → Annex B
4. **TCPServer.swift** - TCP сервер на Network.framework

## Критические особенности реализации

### 1. Конвертация AVCC → Annex B

VideoToolbox выдает H.264 в формате **AVCC** (length-prefixed):
```
[4 bytes length][NAL unit data][4 bytes length][NAL unit data]...
```

Android MediaCodec требует формат **Annex B** (start codes):
```
[00 00 00 01][NAL unit data][00 00 00 01][NAL unit data]...
```

**H264Encoder.swift:231** реализует конвертацию:
- Читает 4-байтовую длину (big endian)
- Заменяет на start code `00 00 00 01`
- Копирует NAL unit data

### 2. Отправка SPS/PPS

Для корректной работы MediaCodec необходимо:
1. Извлечь SPS (NAL type 7) и PPS (NAL type 8) из `CMFormatDescription`
2. Добавить start code `00 00 00 01` к каждому
3. Отправить клиенту **до первого I-frame**

**Реализация:**
- `H264Encoder.swift:152` - извлечение SPS/PPS через `CMVideoFormatDescriptionGetH264ParameterSetAtIndex`
- `TCPServer.swift:66` - сохранение SPS/PPS для новых клиентов
- `TCPServer.swift:41` - автоматическая отправка при подключении

### 3. Low Latency настройки

**VideoToolbox (H264Encoder.swift:70-91):**
- `kVTCompressionPropertyKey_RealTime = true`
- `kVTCompressionPropertyKey_AllowFrameReordering = false` (без B-frames)
- `kVTProfileLevel_H264_Baseline_AutoLevel` (совместимость)
- Битрейт 10 Mbps

**Network (TCPServer.swift:22-26):**
- `noDelay = true` (отключен Nagle)
- `enableKeepalive = true`

**ScreenCaptureKit (ScreenCapture.swift:26-30):**
- `queueDepth = 3` (минимальная буферизация)
- 30 FPS через `minimumFrameInterval`
- NV12 pixel format

## Сборка и запуск

```bash
cd MacServer

# Сборка через Swift Package Manager
swift build -c release

# Запуск
.build/release/ScreenMirrorServer
```

### Альтернатива: Xcode

```bash
# Открыть в Xcode
open Package.swift

# Или создать Xcode проект
swift package generate-xcodeproj
open ScreenMirrorServer.xcodeproj
```

## Разрешения macOS

При первом запуске macOS запросит разрешения:
- **Screen Recording** - для захвата экрана
- **Network** - для TCP сервера (обычно не требуется для localhost)

Проверить: **System Settings → Privacy & Security → Screen Recording**

## Использование

1. Запустите сервер на Mac
2. Подключите Android устройство по USB
3. Выполните `adb forward tcp:5000 tcp:5000`
4. Запустите Android клиент и нажмите "Connect"

## Системные требования

- macOS 13.0 (Ventura) или новее
- Apple Silicon или Intel Mac с аппаратным кодированием H.264

## Протокол передачи

```
[New client connects]
→ Server sends: SPS (with start code)
→ Server sends: PPS (with start code)
→ Server sends: I-frame (IDR, NAL type 5)
→ Server sends: P-frames (NAL type 1)
... continuous stream ...
```

## NAL Unit типы

- **7** - SPS (Sequence Parameter Set)
- **8** - PPS (Picture Parameter Set)
- **5** - IDR (Instantaneous Decoder Refresh) - ключевой кадр
- **1** - Non-IDR (P-frame, B-frame)

## Отладка

Логи показывают:
- Подключения клиентов
- Размеры SPS/PPS
- Счетчик фреймов (каждые 5 секунд)
- Тип фреймов (I-frame/P-frame)

## Производительность

Типичные значения при 1920x1080 @ 30fps:
- I-frame: ~50-100 KB
- P-frame: ~5-20 KB
- Latency: ~100-200ms (зависит от сети)

## Ограничения

- Захватывается только основной дисплей (первый в списке)
- Фиксированный битрейт 10 Mbps
- Один поток кодирования (один экран)
