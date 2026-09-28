# 🎉 MacServer Update v1.1.0 - Display Selection

## Что нового

MacServer теперь позволяет **выбрать конкретный дисплей** для трансляции, включая виртуальные мониторы BetterDisplay с разрешением 2K и выше!

## ⚡ Быстрый старт

### 1. Создайте виртуальный дисплей (опционально)

**В BetterDisplay:**
- Нажмите `+` (Add Dummy Display)
- Разрешение: **2000x1200** (для планшета 10")
- HiDPI: **Отключено**
- Сохраните

### 2. Запустите сервер

```bash
cd MacServer
./run.sh
```

### 3. Выберите дисплей

```
Available Displays:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
0: Display 69733382 (1512 x 982)
1: Display 2077749241 (2000 x 1200)    ← Ваш BetterDisplay
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Enter display index to capture (0-1): 1  ← Введите номер
```

### 4. Подключите планшет

```bash
adb forward tcp:5000 tcp:5000  # USB
# Или настройте Wi-Fi в Android клиенте
```

### 5. Запустите Android клиент

Нажмите "Connect to Server" в приложении.

**Готово!** Планшет показывает pixel-perfect картинку с выбранного дисплея.

## 📋 Изменения в коде

### main.swift (строки 22-60)

```swift
// Получение всех дисплеев
let content = try await SCShareableContent.current

// Показ списка
for (index, display) in content.displays.enumerated() {
    print("\(index): Display \(display.displayID) (\(display.width) x \(display.height))")
}

// Ввод пользователя
let selectedIndex = Int(readLine()!)!
let selectedDisplay = content.displays[selectedIndex]

// Передача в ScreenCapture
try await screenCapture?.start(display: selectedDisplay, onFrameCaptured: ...)
```

### ScreenCapture.swift (строка 13)

```swift
// Было:
func start(onFrameCaptured: @escaping (CVPixelBuffer, CMTime) -> Void) async throws

// Стало:
func start(display: SCDisplay, onFrameCaptured: @escaping (CVPixelBuffer, CMTime) -> Void) async throws
```

### H264Encoder.swift

Без изменений - уже работает правильно с любым разрешением.

## 🎯 Сценарии использования

### Сценарий 1: Второй монитор для работы

```
MacBook → BetterDisplay (2560x1600) → MacServer → Android планшет
```

Разместите рабочие окна на виртуальном дисплее → получите полноценный второй монитор.

### Сценарий 2: Презентации

```
Mac → Основной дисплей (презентация) → MacServer → Планшет
```

Выберите основной дисплей (обычно `0`) → планшет показывает презентацию.

### Сценарий 3: Мониторинг удаленно

```
Mac → Любой дисплей → MacServer (Wi-Fi) → Планшет
```

Мониторинг дашбордов, логов, метрик с любого места.

## 📊 Поддерживаемые разрешения

| Разрешение | Описание | Битрейт | Статус |
|------------|----------|---------|--------|
| 1920x1080 | Full HD | 10 Mbps | ✅ Работает |
| 2000x1200 | 2K (BetterDisplay) | 10 Mbps | ✅ **Оптимально** |
| 2560x1440 | QHD | 10-15 Mbps | ✅ Работает |
| 2560x1600 | WQXGA | 10-15 Mbps | ✅ Работает |
| 3840x2160 | 4K UHD | 15-20 Mbps | ✅ Работает |

### Настройка битрейта для 4K

В `main.swift:77` измените:

```swift
encoder = H264Encoder(width: width, height: height, fps: 30, bitrate: 20_000_000)
```

## 🔍 Что проверять

После выбора дисплея убедитесь что:

```
✓ Selected: Display 2077749241 (2000x1200)      ← Правильное разрешение
✓ H264Encoder initialized: 2000x1200 @ 30fps   ← Совпадает
✓ Screen capture started: 2000x1200 @ 30fps    ← Совпадает
✓ Captured 150 frames (2000x1200)              ← Совпадает
```

Все размеры должны быть одинаковыми = pixel-perfect качество!

## 🐛 Troubleshooting

### BetterDisplay не показывается

**Проверьте:**
1. Виртуальный дисплей активен в BetterDisplay
2. Разрешение не 0x0
3. Перезапустите MacServer

### Искажения картинки

**Причина:** Разные разрешения на разных этапах

**Решение:**
Проверьте логи - все размеры должны совпадать. Если нет - перезапустите сервер.

### "No displays found"

**Решение:**
```bash
# Проверьте дисплеи
system_profiler SPDisplaysDataType | grep Resolution
```

Должен быть хотя бы один активный дисплей.

## 📚 Документация

- **DISPLAY_SELECTION.md** - Техническая документация
- **USAGE_GUIDE.md** - Полное руководство пользователя
- **CHANGELOG.md** - История изменений

## 🎁 Бонус: Автовыбор дисплея

Если вы всегда используете один дисплей, добавьте в `main.swift:44`:

```swift
// Автовыбор BetterDisplay (обычно последний)
let selectedIndex = content.displays.count - 1
print("✓ Auto-selected display \(selectedIndex)")
let selectedDisplay = content.displays[selectedIndex]

// Закомментируйте строки 45-57 (readLine)
```

Сервер будет автоматически выбирать последний дисплей без запроса.

## 💡 Рекомендации

### Для работы (кодинг, дизайн):

- **Разрешение**: 2560x1600 (16:10)
- **Битрейт**: 15 Mbps
- **Подключение**: USB

### Для мониторинга (дашборды, логи):

- **Разрешение**: 1920x1080 или 2000x1200
- **Битрейт**: 10 Mbps
- **Подключение**: Wi-Fi

### Для презентаций:

- **Разрешение**: Как у основного дисплея
- **Битрейт**: 10-15 Mbps
- **Подключение**: USB (стабильнее)

## 🚀 Что дальше

Возможные улучшения:
- [ ] CLI параметры: `./run.sh --display 1`
- [ ] Автоопределение BetterDisplay дисплеев
- [ ] Сохранение последнего выбора
- [ ] Горячая смена дисплея без перезапуска
- [ ] GUI для выбора дисплея

---

**Версия**: 1.1.0
**Дата**: 2026-01-17
**Совместимость**: macOS 13.0+

**Готово к использованию!** 🎉

Запустите `./run.sh` и наслаждайтесь pixel-perfect трансляцией вашего 2K дисплея на планшет.
