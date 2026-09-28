# Git Setup Guide

Инструкция по инициализации Git репозитория для проекта Screen Mirror.

## Быстрая инициализация

```bash
cd ~/ScreenMirrorApp

# Инициализация репозитория
git init

# Добавление всех файлов
git add .

# Первый коммит
git commit -m "Initial commit: Screen Mirror macOS to Android

- MacServer (Swift): ScreenCaptureKit + VideoToolbox + AVCC→Annex B
- AndroidClient (Kotlin): MediaCodec + NAL parser
- Low latency H.264 streaming over TCP
- Complete documentation"

# Создание основной ветки
git branch -M main
```

## Подключение к удаленному репозиторию (опционально)

### GitHub

```bash
# Создайте репозиторий на github.com, затем:
git remote add origin https://github.com/YOUR_USERNAME/screen-mirror.git
git push -u origin main
```

### GitLab

```bash
git remote add origin https://gitlab.com/YOUR_USERNAME/screen-mirror.git
git push -u origin main
```

### Другой Git сервер

```bash
git remote add origin git@your-server.com:path/to/repo.git
git push -u origin main
```

## Структура веток (рекомендуется)

```bash
# Основная ветка для стабильного кода
main (или master)

# Ветка разработки
git checkout -b develop

# Ветки для фич
git checkout -b feature/audio-streaming
git checkout -b feature/adaptive-bitrate
git checkout -b feature/touch-input

# Ветки для исправлений
git checkout -b fix/decoder-crash
git checkout -b fix/memory-leak

# Ветка для документации
git checkout -b docs/update-readme
```

## Полезные команды

```bash
# Проверка статуса
git status

# Просмотр изменений
git diff

# Добавление конкретных файлов
git add MacServer/ScreenMirrorServer/Sources/H264Encoder.swift
git add AndroidClient/app/src/main/java/com/screenmirror/MainActivity.kt

# Коммит с сообщением
git commit -m "feat: add adaptive bitrate control"

# Просмотр истории
git log --oneline --graph --all

# Создание тега для релиза
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

## Рекомендуемый формат коммитов

Используйте [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: добавление новой функции
fix: исправление бага
docs: изменения в документации
style: форматирование кода (без изменения логики)
refactor: рефакторинг кода
perf: улучшение производительности
test: добавление или изменение тестов
build: изменения в системе сборки
ci: изменения в CI/CD конфигурации
chore: другие изменения (обновление зависимостей и т.д.)
```

### Примеры:

```bash
git commit -m "feat: add SPS/PPS auto-resend on client reconnect"
git commit -m "fix: prevent memory leak in NAL parser buffer"
git commit -m "perf: optimize AVCC to Annex B conversion with zero-copy"
git commit -m "docs: add troubleshooting section to README"
git commit -m "refactor: extract NAL type detection to separate method"
```

## Что игнорируется

См. `.gitignore` файл. Основные категории:

- **Build артефакты**: `.build/`, `build/`, `*.apk`, `*.ipa`
- **IDE файлы**: `.idea/`, `*.iml`, `xcuserdata/`, `.vscode/`
- **Зависимости**: `Packages/`, `.gradle/`, `node_modules/`
- **OS файлы**: `.DS_Store`, `Thumbs.db`
- **Временные файлы**: `*.tmp`, `*.log`, `*.swp`
- **Секреты**: `*.keystore`, `*.pem`, `.env`

## Git hooks (опционально)

Создайте `.git/hooks/pre-commit` для автоматических проверок:

```bash
#!/bin/bash
# Pre-commit hook для проверки кода

echo "Running pre-commit checks..."

# Проверка Swift кода
if command -v swiftlint &> /dev/null; then
    echo "Running SwiftLint..."
    cd MacServer && swiftlint || exit 1
fi

# Проверка Kotlin кода
if command -v ktlint &> /dev/null; then
    echo "Running ktlint..."
    cd AndroidClient && ktlint || exit 1
fi

echo "Pre-commit checks passed!"
```

## GitHub Actions CI/CD (пример)

Создайте `.github/workflows/build.yml`:

```yaml
name: Build and Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build-macos:
    runs-on: macos-13
    steps:
      - uses: actions/checkout@v3
      - name: Build MacServer
        run: |
          cd MacServer
          swift build -c release

  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up JDK 17
        uses: actions/setup-java@v3
        with:
          java-version: '17'
          distribution: 'temurin'
      - name: Build Android
        run: |
          cd AndroidClient
          ./gradlew assembleDebug
```

## .gitignore проверка

```bash
# Убедитесь что важные файлы НЕ игнорируются
git check-ignore -v MacServer/Package.swift
git check-ignore -v AndroidClient/app/build.gradle

# Должно вернуть пустой результат (файлы НЕ игнорируются)

# Убедитесь что build артефакты игнорируются
git check-ignore -v MacServer/.build
git check-ignore -v AndroidClient/build

# Должно показать правило из .gitignore
```

## Размер репозитория

После первого коммита:

```bash
# Проверка размера репозитория
du -sh .git

# Примерный размер: ~100-200 KB (только исходный код)
```

## License (опционально)

Добавьте LICENSE файл:

```bash
# MIT License (пример)
cat > LICENSE << 'EOF'
MIT License

Copyright (c) 2026 Screen Mirror Project

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

git add LICENSE
git commit -m "docs: add MIT license"
```

## Best Practices

1. **Коммитьте часто** - маленькие, атомарные коммиты
2. **Пишите понятные сообщения** - объясняйте "почему", а не "что"
3. **Используйте ветки** - не работайте напрямую в main
4. **Делайте pull request** - для code review
5. **Добавляйте теги** - для релизов (v1.0.0, v1.1.0)
6. **Обновляйте .gitignore** - при добавлении новых зависимостей

## Восстановление из Git (для новой машины)

```bash
# Клонирование репозитория
git clone https://github.com/YOUR_USERNAME/screen-mirror.git
cd screen-mirror

# Сборка MacServer
cd MacServer
swift build -c release

# Сборка AndroidClient
cd ../AndroidClient
./gradlew assembleDebug
```

Готово! Репозиторий настроен и готов к работе.
