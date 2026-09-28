# MacServer - Руководство по использованию

## 🎯 Быстрый старт

### 1. Запуск сервера

```bash
cd MacServer
./run.sh
```

### 2. Выбор дисплея

При запуске вы увидите список доступных дисплеев:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Screen Mirror Server
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Available Displays:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
0: Display 69733382 (1512 x 982)
1: Display 2077749241 (2000 x 1200)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Enter display index to capture (0-1): 
```

**Введите номер дисплея** (например, `1` для 2K монитора) и нажмите Enter.

### 3. Подтверждение

```
✓ Selected: Display 2077749241 (2000x1200)

✓ TCP Server listening on port 5000
✓ H264Encoder initialized: 2000x1200 @ 30fps, 10Mbps
✓ Using display: 2000x1200
✓ Screen capture started: 2000x1200 @ 30fps

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Server is running
  Press Ctrl+C to stop
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Сервер работает! Теперь подключайте Android клиент.

## 📱 Использование с BetterDisplay

### Создание виртуального дисплея

1. Откройте **BetterDisplay**
2. Создайте новый виртуальный дисплей:
   - Нажмите `+` (Add Dummy Display)
   - Выберите разрешение: **2000x1200** или **2560x1600**
   - HiDPI: **Отключено** (для pixel-perfect)
   - Refresh rate: **60Hz**

3. Разместите окна на виртуальном дисплее
4. Запустите MacServer и выберите этот дисплей

### Рекомендуемые разрешения для планшетов:

| Планшет | Разрешение | BetterDisplay |
|---------|------------|---------------|
| 10" (16:10) | 2000x1200 | ✅ Идеально |
| 11" (16:10) | 2240x1400 | ✅ Отлично |
| 12" (16:10) | 2560x1600 | ✅ Отлично |
| 10" (16:9) | 1920x1080 | ✅ Хорошо |

## 🔧 Настройки

### Изменение битрейта

Для более высокого качества на 2K/4K мониторах:

**Файл**: `main.swift` (строка 77)

```swift
// Для 2K (2000x1200)
encoder = H264Encoder(width: width, height: height, fps: 30, bitrate: 15_000_000)

// Для 4K (3840x2160)
encoder = H264Encoder(width: width, height: height, fps: 30, bitrate: 20_000_000)
```

### Изменение FPS

**Файл**: `main.swift` (строка 77)

```swift
// 60 FPS для более плавной картинки
encoder = H264Encoder(width: width, height: height, fps: 60, bitrate: 15_000_000)
```

**Примечание**: Android клиент должен справляться с декодированием 60fps.

### Изменение порта

**Файл**: `main.swift` (строка 7)

```swift
private let tcpServer = TCPServer(port: 8080)  // Вместо 5000
```

Не забудьте изменить порт в Android клиенте!

## 🎮 Сценарии использования

### Сценарий 1: Второй монитор для работы

```
Mac (MacBook) → BetterDisplay (2560x1600) → MacServer → Android планшет
```

1. Создайте виртуальный дисплей 2560x1600 в BetterDisplay
2. Разместите рабочие окна (IDE, браузер, терминал)
3. Запустите MacServer, выберите виртуальный дисплей
4. Подключите планшет через USB
5. Работайте как с обычным вторым монитором

**Преимущества:**
- Pixel-perfect качество
- Низкая задержка (~100-200ms)
- Работает по USB (не нужен Wi-Fi)
- Планшет становится полноценным монитором

### Сценарий 2: Презентация на планшете

```
Mac → Основной дисплей (презентация) → MacServer → Android планшет
```

1. Откройте презентацию на основном экране
2. Запустите MacServer, выберите основной дисплей (обычно индекс 0)
3. Подключите планшет
4. Планшет показывает вашу презентацию в реальном времени

### Сценарий 3: Мониторинг через Wi-Fi

```
Mac → Любой дисплей → MacServer (Wi-Fi) → Android планшет
```

1. Узнайте IP Mac: `ifconfig | grep "inet "`
2. В Android клиенте измените host на IP Mac
3. Запустите MacServer
4. Подключите планшет через Wi-Fi

**Использование:** Удаленный мониторинг рабочего стола, дашборды, логи.

## 📊 Мониторинг производительности

### Логи сервера

Каждые 5 секунд (150 кадров) вы увидите:

```
✓ Captured 150 frames (2000x1200)
→ Sent 150 frames | Latest: P-frame (12456 bytes) | Clients: 1
```

**Что означают цифры:**
- `Captured 150 frames` - Захвачено кадров
- `(2000x1200)` - Разрешение захвата
- `P-frame (12456 bytes)` - Тип кадра и размер
- `Clients: 1` - Количество подключенных клиентов

### Типы кадров:

- **I-frame** (IDR) - Ключевой кадр (~50-120 KB для 2K)
- **P-frame** - Обычный кадр (~5-20 KB для 2K)

Если вы видите только P-frames - это хорошо (меньше трафика).

I-frames появляются:
- При запуске
- Каждые 60 кадров (2 секунды при 30fps)
- При резких изменениях картинки

### CPU Usage

Проверьте нагрузку:

```bash
# В отдельном терминале
top -pid $(pgrep ScreenMirrorServer)
```

Ожидаемые значения:
- **1080p**: 15-25% CPU
- **2K**: 20-30% CPU
- **4K**: 30-45% CPU

## 🐛 Устранение проблем

### Сервер не запускается

**Ошибка**: "No displays found"

**Решение:**
```bash
# Проверьте список дисплеев
system_profiler SPDisplaysDataType | grep Resolution
```

Если нет дисплеев - подключите монитор или создайте виртуальный в BetterDisplay.

### "Invalid display index"

Вы ввели неправильный номер. Номера начинаются с 0.

Если доступны дисплеи 0 и 1, введите `0` или `1`.

### Клиент не подключается

**Проверьте:**

1. **TCP порт открыт:**
   ```bash
   lsof -i :5000
   ```
   Должно показать `ScreenMir` в списке.

2. **adb forward настроен (для USB):**
   ```bash
   adb forward tcp:5000 tcp:5000
   adb forward --list
   ```

3. **Firewall не блокирует (для Wi-Fi):**
   ```bash
   # Временно отключите firewall для теста
   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off
   ```

### Низкое качество / артефакты

**Решения:**

1. **Увеличьте битрейт** (main.swift:77):
   ```swift
   bitrate: 15_000_000  // Вместо 10_000_000
   ```

2. **Проверьте сеть** (для Wi-Fi):
   ```bash
   ping <IP планшета>
   ```
   RTT должен быть < 10ms

3. **Используйте USB** вместо Wi-Fi для лучшего качества

### Высокая задержка

**Проверьте:**

1. **USB соединение** вместо Wi-Fi
2. **Закройте другие приложения** на Mac
3. **Уменьшите разрешение** виртуального дисплея
4. **Снизьте FPS** до 24-25 для экономии ресурсов

## 🔄 Перезапуск

### Graceful stop

Нажмите `Ctrl+C` в терминале:

```
^C
✓ Received signal 2

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Stopping server...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Screen capture stopped
✓ Server stopped
✓ Total frames sent: 4532
```

### Force stop

Если Ctrl+C не работает:

```bash
pkill ScreenMirrorServer
```

### Автоперезапуск

Создайте скрипт `auto_restart.sh`:

```bash
#!/bin/bash
while true; do
    echo "Starting MacServer..."
    ./run.sh
    echo "Server stopped. Restarting in 5 seconds..."
    sleep 5
done
```

```bash
chmod +x auto_restart.sh
./auto_restart.sh
```

## 📈 Оптимизация для разных сценариев

### Максимальное качество (для работы)

```swift
// main.swift:77
encoder = H264Encoder(
    width: width, 
    height: height, 
    fps: 30, 
    bitrate: 20_000_000  // 20 Mbps
)
```

**Требования:**
- Хорошее USB соединение или Wi-Fi 5GHz
- Достаточно мощный Android планшет

### Экономия трафика (для мониторинга)

```swift
encoder = H264Encoder(
    width: width, 
    height: height, 
    fps: 15,  // 15 FPS вместо 30
    bitrate: 5_000_000  // 5 Mbps
)
```

**Использование:**
- Удаленный мониторинг через Wi-Fi
- Просмотр статичного контента (дашборды, документы)

### Баланс (по умолчанию)

```swift
encoder = H264Encoder(
    width: width, 
    height: height, 
    fps: 30, 
    bitrate: 10_000_000  // 10 Mbps
)
```

**Подходит для:**
- Большинства сценариев
- 2K разрешение
- Стабильная работа

## 🚀 Продвинутое использование

### Запуск в фоне

```bash
# Запуск с выбором дисплея 1
echo "1" | nohup ./run.sh > server.log 2>&1 &

# Проверка логов
tail -f server.log
```

### Systemd service (Linux-style)

Для автозапуска при старте системы:

```bash
# Создайте plist файл для launchd
# ~/Library/LaunchAgents/com.screenmirror.server.plist
```

Содержимое:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.screenmirror.server</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/YOUR_USER/ScreenMirrorApp/MacServer/.build/release/ScreenMirrorServer</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
```

Загрузка:
```bash
launchctl load ~/Library/LaunchAgents/com.screenmirror.server.plist
```

## 📝 Шпаргалка команд

```bash
# Сборка
swift build -c release

# Быстрый запуск
./run.sh

# Проверка процесса
ps aux | grep ScreenMirrorServer

# Проверка порта
lsof -i :5000

# Проверка дисплеев
system_profiler SPDisplaysDataType

# Остановка
pkill ScreenMirrorServer

# Логи (если запущено в фоне)
tail -f server.log
```

---

**Готово!** Теперь вы эксперт по MacServer 🎉

Для деталей реализации см. `DISPLAY_SELECTION.md`
