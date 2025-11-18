# QD&D - Список файлов проекта

**Дата**: 2025-11-06  
**Session**: 1 (из 8)

## 📁 Структура проекта

### 🔑 Ключевые файлы

| Файл | Размер | Описание |
|------|--------|----------|
| `README.md` | 6.0K | Главный README с быстрым стартом |
| `PROJECT_BRIEF.md` | 14K | Полный обзор проекта и целей |
| `SESSION1_SUMMARY.md` | 4.3K | Summary Session 1 |
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

### 📱 Приложение

| Файл | Размер | Описание |
|------|--------|----------|
| `lib/main.dart` | ~8K | Основной код (290 строк) |
| `build/app/outputs/flutter-apk/app-debug.apk` | 140M | Готовый APK |

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
└── fc5_examples/    # Примеры FC5 XML
    └── pal_example.xml
```

## 🎨 Assets структура

```
assets/
├── data/            # JSON данные (будущее)
│   └── fc5_examples/
│       └── pal_example.xml (2.9M)
└── images/          # Изображения
    └── icon.svg (5.4K)
```

## 📋 Session 0 файлы (перенесены)

Все файлы из Session 0 успешно перенесены в `~/Dev/Flutter/qd_and_d`:

✅ PROJECT_BRIEF.md  
✅ docs/ARCHITECTURE.md  
✅ docs/DEVELOPMENT_PLAN.md  
✅ assets/data/fc5_examples/pal_example.xml  
✅ assets/images/icon.svg  
✅ environment_report.md

## 📦 Deliverables

### Session 0
- ✅ Вся документация создана
- ✅ Архитектура спроектирована
- ✅ План на 8 сессий составлен

### Session 1
- ✅ Окружение настроено
- ✅ Flutter проект создан
- ✅ Material 3 UI реализован
- ✅ **APK собран** (140MB)

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

- **Всего файлов документации**: 6
- **Размер документации**: ~65K
- **Assets**: 2 файла (3MB)
- **Код**: 290 строк (main.dart)
- **APK размер**: 140MB

## 🗂️ Старая директория

Директория `~/Dev/Flutter/qd_n_d` содержит только Session 0 файлы и может быть удалена после подтверждения, что все важные данные перенесены.

---

**Все файлы Session 0 успешно перенесены в актуальную директорию проекта!** ✅
