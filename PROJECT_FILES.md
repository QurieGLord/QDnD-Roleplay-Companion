# QD&D - Список файлов проекта

## 📁 Структура проекта

### 🔑 Ключевые файлы

| Файл | Размер | Описание |
|------|--------|----------|
| `README.md` | 6.0K | Главный README с быстрым стартом |
| `PROJECT_BRIEF.md` | 14K | Полный обзор проекта и целей |
| `environment_report.md` | 3.8K | Audit окружения |

### 📚 Документация

| Файл | Размер | Описание |
|------|--------|----------|
| `docs/ARCHITECTURE.md` | 20K | Детальная архитектура системы |
| `docs/DEVELOPMENT_PLAN.md` | 19K | План разработки на 8 сессий |

### 💾 Assets

| Файл | Размер | Описание |
|------|--------|----------|
| `assets/data/fc5_examples/pal_example.xml` | 2.9M | Reference персонаж (Paladin "Кюри") |
| `assets/images/icon.svg` | 5.4K | Логотип приложения |

### 📱 Приложение (Ключевые директории и файлы)

| Путь/Файл | Описание |
|-----------|----------|
| `lib/main.dart` | Основной код приложения |
| `lib/core/utils/` | Общие утилиты (dice_utils, item_utils, spell_utils, localization_helper) |
| `lib/features/character_sheet/widgets/class_widgets/` | Динамические UI-виджеты для классов (12+ виджетов: rage_control, bard_inspiration, paladin_divine и т.д.) |
| `lib/features/character_sheet/widgets/abilities_tab.dart` | Главная вкладка умений (заменила spells_tab) |
| `build/app/outputs/flutter-apk/app-debug.apk` | Готовый APK |

### ⚙️ Конфигурация

| Файл | Описание |
|------|----------|
| `pubspec.yaml` | Зависимости проекта |
| `android/app/build.gradle.kts` | Android конфигурация |
| `android/gradle/wrapper/gradle-wrapper.properties` | Gradle 8.11.1 |
| `analysis_options.yaml` | Lint rules |

## 📂 Директории данных

Структура для будущих JSON данных:

```
assets/data/
├── backgrounds/     # Backgrounds (предыстории)
├── classes/         # Классы (13 классов D&D 5e)
├── feats/           # Feats (черты)
├── items/           # Предметы и снаряжение
├── races/           # Расы
├── spells/          # Заклинания
├── subclasses/      # Подклассы
```

## 🔧 Технические файлы

### Android
- `android/app/build.gradle.kts` - compileSdk 36, targetSdk 34, minSdk 24
- `android/gradle/wrapper/gradle-wrapper.properties` - Gradle 8.11.1
- `android/local.properties` - Local SDK paths
- `android/settings.gradle.kts` - Project settings

### iOS
- `ios/Runner/Info.plist` - iOS configuration
- `ios/Runner.xcodeproj/` - Xcode project

### Flutter
- `pubspec.yaml` - Dependencies (google_fonts, flutter_svg, provider)
- `pubspec.lock` - Locked versions
- `analysis_options.yaml` - Lint configuration

## 📊 Статистика

- **Всего файлов документации**: 
- **Размер документации**: ~
- **Assets**: 
- **Код**: 
- **APK размер**:

---
