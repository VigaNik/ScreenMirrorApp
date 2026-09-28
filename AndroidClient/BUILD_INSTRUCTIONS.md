# Android Client Build Instructions

## ✅ Исправления выполнены

### 1. Конфликт репозиториев - ИСПРАВЛЕН

**Файл**: `settings.gradle` (строка 10)

**Было**:
```gradle
repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
```

**Стало**:
```gradle
repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)
```

**Причина**: Конфликт между репозиториями в `settings.gradle` и `build.gradle`.

### 2. Gradle/AGP совместимость - ОБНОВЛЕНО

**Файл**: `build.gradle`

**Обновления**:
- Android Gradle Plugin: `8.1.0` → `8.7.3` (совместим с Gradle 9.3)
- Kotlin: `1.9.20` → `2.1.0` (совместим с Gradle 9.3)
- Удален устаревший блок `allprojects`
- Обновлен `clean` task для использования `layout.buildDirectory`

## Требования для сборки

### Вариант 1: Android Studio (рекомендуется)

1. **Установите Android Studio**:
   - Скачайте с https://developer.android.com/studio
   - Запустите установку и дождитесь загрузки Android SDK

2. **Откройте проект**:
   ```bash
   # Откройте Android Studio и выберите "Open"
   # Выберите папку: ~/ScreenMirrorApp/AndroidClient
   ```

3. **Дождитесь синхронизации Gradle**:
   - Android Studio автоматически загрузит зависимости
   - При первом открытии может запросить установку SDK компонентов

4. **Соберите проект**:
   - Нажмите `Build` → `Make Project` (или Cmd+F9)
   - Или нажмите `Build` → `Build Bundle(s) / APK(s)` → `Build APK(s)`

5. **APK будет в**:
   ```
   AndroidClient/app/build/outputs/apk/debug/app-debug.apk
   ```

### Вариант 2: Командная строка (требует установки SDK)

#### Шаг 1: Установите Android SDK

**Через Homebrew** (macOS):
```bash
# Установите Android SDK command line tools
brew install --cask android-commandlinetools

# Настройте ANDROID_HOME
echo 'export ANDROID_HOME=$HOME/Library/Android/sdk' >> ~/.zshrc
echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools' >> ~/.zshrc
source ~/.zshrc

# Установите необходимые компоненты
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
```

**Или скачайте вручную**:
1. Скачайте Command Line Tools: https://developer.android.com/studio#command-line-tools-only
2. Разархивируйте в `~/Library/Android/sdk/cmdline-tools/latest`
3. Настройте переменные окружения (см. выше)

#### Шаг 2: Создайте local.properties

```bash
cd AndroidClient
echo "sdk.dir=$HOME/Library/Android/sdk" > local.properties
```

#### Шаг 3: Соберите проект

```bash
# Используйте gradle wrapper (если настроен)
./gradlew assembleDebug

# Или системный gradle
gradle assembleDebug
```

#### Шаг 4: Найдите APK

```bash
ls -lh app/build/outputs/apk/debug/app-debug.apk
```

### Вариант 3: Использование Docker (кросс-платформенное решение)

Создайте `Dockerfile` в корне AndroidClient:

```dockerfile
FROM openjdk:17-slim

# Установка Android SDK
RUN apt-get update && apt-get install -y wget unzip
RUN mkdir -p /opt/android-sdk
WORKDIR /opt/android-sdk

RUN wget https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip
RUN unzip commandlinetools-linux-9477386_latest.zip
RUN yes | cmdline-tools/bin/sdkmanager --sdk_root=/opt/android-sdk "platform-tools" "platforms;android-34" "build-tools;34.0.0"

ENV ANDROID_HOME=/opt/android-sdk
ENV PATH=$PATH:$ANDROID_HOME/platform-tools

WORKDIR /project
COPY . .

RUN echo "sdk.dir=/opt/android-sdk" > local.properties
RUN gradle assembleDebug

CMD ["cp", "app/build/outputs/apk/debug/app-debug.apk", "/output/"]
```

Затем:
```bash
docker build -t screen-mirror-android .
docker run -v $(pwd)/output:/output screen-mirror-android
```

## Проверка сборки

После успешной сборки вы должны увидеть:

```
BUILD SUCCESSFUL in XXs
XX actionable tasks: XX executed

BUILD SUCCESSFUL
```

APK файл будет находиться в:
```
app/build/outputs/apk/debug/app-debug.apk
```

Размер APK: ~2-3 MB

## Установка на Android устройство

### Через adb (USB или Wi-Fi)

```bash
# Подключите устройство по USB
adb devices

# Установите APK
adb install app/build/outputs/apk/debug/app-debug.apk

# Или для переустановки
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

### Через файловый менеджер

1. Скопируйте APK на устройство
2. Откройте файловый менеджер на Android
3. Нажмите на app-debug.apk
4. Разрешите установку из неизвестных источников (если требуется)
5. Нажмите "Установить"

## Текущее состояние проекта

✅ **Конфигурация исправлена**:
- `settings.gradle`: `PREFER_PROJECT` вместо `FAIL_ON_PROJECT_REPOS`
- `build.gradle`: AGP 8.7.3, Kotlin 2.1.0
- Совместимость с Gradle 9.3

⚠️ **Для сборки требуется**:
- Android SDK (API 34)
- Build Tools 34.0.0
- Platform Tools (adb)
- Java/OpenJDK 17

## Troubleshooting

### "SDK location not found"

**Решение**:
```bash
echo "sdk.dir=$ANDROID_HOME" > local.properties
```

Или установите Android Studio, которая настроит SDK автоматически.

### "Could not resolve dependencies"

**Решение**:
```bash
# Очистите кэш Gradle
gradle clean
rm -rf ~/.gradle/caches

# Пересоберите
gradle assembleDebug
```

### "Unsupported class file major version"

Означает несовместимость версий Java.

**Решение**:
```bash
# Проверьте версию Java
java -version  # Должно быть 17 или выше

# Если нужно, установите Java 17
brew install openjdk@17
```

### Build успешен, но нет APK

**Решение**:
```bash
# Проверьте все возможные пути
find . -name "*.apk"

# APK должен быть в:
# app/build/outputs/apk/debug/app-debug.apk
```

## Альтернатива: Использование GitHub Actions

Вы можете настроить автоматическую сборку APK через GitHub Actions.

Создайте `.github/workflows/android-build.yml`:

```yaml
name: Android Build

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - name: Set up JDK 17
      uses: actions/setup-java@v3
      with:
        java-version: '17'
        distribution: 'temurin'

    - name: Setup Android SDK
      uses: android-actions/setup-android@v2

    - name: Build APK
      run: |
        cd AndroidClient
        gradle assembleDebug

    - name: Upload APK
      uses: actions/upload-artifact@v3
      with:
        name: app-debug
        path: AndroidClient/app/build/outputs/apk/debug/app-debug.apk
```

После push в GitHub, Actions автоматически соберет APK, который можно скачать из раздела "Actions".

## Итоговая команда сборки

**После установки Android SDK**:

```bash
cd ~/ScreenMirrorApp/AndroidClient

# Создайте local.properties (один раз)
echo "sdk.dir=$ANDROID_HOME" > local.properties

# Соберите проект
gradle assembleDebug

# Найдите APK
ls -lh app/build/outputs/apk/debug/app-debug.apk
```

**Ожидаемый вывод**:
```
BUILD SUCCESSFUL in 45s
42 actionable tasks: 42 executed

-rw-r--r--  1 user  staff   2.1M  app/build/outputs/apk/debug/app-debug.apk
```
