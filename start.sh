#!/bin/bash

export PATH="$PATH:$HOME/Library/Android/sdk/platform-tools"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Screen Mirror - Запуск"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Убиваем старые процессы на порту 5000
echo "→ Освобождаем порт 5000..."
lsof -ti :5000 | xargs kill -9 2>/dev/null || true

# Проверяем устройство
echo "→ Проверяем подключение планшета..."
DEVICES=$(adb devices | grep -v "List of" | grep "device$")
if [ -z "$DEVICES" ]; then
    echo "✗ Планшет не найден! Подключи по USB и разреши USB debugging."
    exit 1
fi
echo "✓ Планшет подключён"

# Настраиваем adb reverse
echo "→ Настраиваем adb reverse..."
adb reverse tcp:5000 tcp:5000
echo "✓ adb reverse tcp:5000 tcp:5000"

echo ""
echo "→ Запускаем MacServer..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd MacServer && ./run.sh
