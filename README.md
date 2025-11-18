# QD&D - Quick D&D: Your Roleplay Companion

**Comprehensive D&D 5th Edition companion app для Android/iOS**

## Статус проекта

- **Версия**: 1.0.0+1
- **Ветка**: `claude` ⚠️ (Claude Code работает здесь)
- **Прогресс**: 25% (Session 1 из 8 завершена)
- **Текущая сессия**: Session 1 ✅ ЗАВЕРШЕНА
- **APK**: [build/app/outputs/flutter-apk/app-debug.apk](build/app/outputs/flutter-apk/app-debug.apk) (140MB)

> **Note**: Проект использует три ветки:
> - `main` - stable releases
> - `claude` - разработка с Claude Code (эта ветка)
> - `gemini` - разработка с Gemini AI

## Быстрый старт

### Предварительные требования

- Flutter 3.35.7+
- Dart 3.9.4+
- Java OpenJDK 17
- Android SDK (Build-Tools 35, Platform 36)

### Установка окружения

```bash
# Установить JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
export PATH=$JAVA_HOME/bin:$PATH
```

### Команды разработки

```bash
# Получить зависимости
flutter pub get

# Запустить на устройстве
flutter run

# Собрать debug APK
flutter build apk --debug

# Собрать release APK
flutter build apk --release

# Очистить проект
flutter clean
```

## Архитектура

### Основная философия
**"Build once, populate infinitely"** - универсальная, data-driven архитектура, требующая ТОЛЬКО добавления JSON данных для нового контента, БЕЗ изменений кода.

### Ключевые возможности

- ✅ Все 13 официальных D&D 5e классов
- ✅ Universal CharacterFeature system
- ✅ Bilingual support (Русский + English)
- ✅ Offline-first с Hive storage
- ✅ Material 3 Expressive дизайн
- ✅ FC5 XML import/export
- ✅ 5 цветовых тем (Monokai по умолчанию)

### Технический стек

- **Framework**: Flutter 3.35.7
- **Language**: Dart 3.9.4
- **State Management**: Provider
- **Storage**: Hive (offline-first)
- **Design**: Material 3 Expressive
- **Fonts**: Google Fonts (Inter)
- **Build System**: Gradle 8.11.1 + AGP 8.9.1

## Структура проекта

```
qd_and_d/
├── lib/
│   └── main.dart              # Основной код приложения (290 строк)
├── assets/
│   ├── data/
│   │   └── fc5_examples/
│   │       └── pal_example.xml  # Reference персонаж для тестов
│   └── images/
│       └── icon.svg           # Логотип приложения
├── docs/
│   ├── ARCHITECTURE.md        # Детальная архитектура
│   └── DEVELOPMENT_PLAN.md    # План на 8 сессий
├── android/                   # Android конфигурация
├── ios/                       # iOS конфигурация
├── PROJECT_BRIEF.md           # Обзор проекта
├── SESSION1_SUMMARY.md        # Summary Session 1
└── environment_report.md      # Audit окружения
```

## Документация

- **[PROJECT_BRIEF.md](PROJECT_BRIEF.md)** - полный обзор проекта и целей
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - детальная архитектура системы
- **[docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md)** - план разработки на 8 сессий
- **[SESSION1_SUMMARY.md](SESSION1_SUMMARY.md)** - результаты Session 1
- **[environment_report.md](environment_report.md)** - audit окружения

## Текущая реализация (Session 1)

### UI Компоненты

1. **SplashScreen**
   - Fade + scale анимация (1.5s)
   - Логотип приложения
   - Плавный переход к character list

2. **CharacterListScreen**
   - Beautiful empty state UI
   - Floating action button для создания персонажа
   - Placeholder для будущего списка

3. **SettingsScreen**
   - Theme selector (Light/Dark/System)
   - Language selector (English/Русский)
   - Material 3 компоненты

### Цветовая схема (Monokai)

- **Primary**: #FFB3D9 (pink)
- **Secondary**: #A9DC76 (green)
- **Surface**: #FCFCFC (light) / #2D2A2E (dark)
- **Background**: #FAFAFA (light) / #221F22 (dark)

## Следующие шаги (Session 2)

**Фокус**: Data Models & Character Creation

- [ ] Настроить Hive для локального хранилища
- [ ] Создать data models (Character, AbilityScores, Skills)
- [ ] Реализовать Character creation flow
- [ ] Базовый character sheet UI
- [ ] Ability score input и модификаторы

**Deliverable**: Возможность создать и сохранить персонажа с базовыми характеристиками

## Конфигурация Android

```kotlin
android {
    compileSdk = 36
    ndkVersion = "29.0.14206865"

    defaultConfig {
        applicationId = "com.qdnd.qd_and_d"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
```

## Зависимости

```yaml
dependencies:
  flutter:
    sdk: flutter
  google_fonts: ^6.2.1
  flutter_svg: ^2.0.14
  provider: ^6.1.2
```

## Установка APK

### Вариант 1: File Manager
1. Скопировать APK на устройство
2. Открыть через File Manager
3. Разрешить установку из неизвестных источников

### Вариант 2: ADB
```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

### Вариант 3: Flutter
```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
flutter install --debug
```

## Лицензия

Частный проект

## Контакты

- **Автор**: QurieGLord
- **Email**: tipquri@gmail.com
- **Проект**: ~/Dev/Flutter/qd_and_d

---

**QD&D** - Your ultimate D&D 5e companion 🎲✨
