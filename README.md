# QD&D - Quick D&D: Your Roleplay Companion

**Comprehensive D&D 5th Edition companion app для Android/iOS**

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/QurieGLord/qd_and_d)
[![Status](https://img.shields.io/badge/status-in%20development-green.svg)](https://github.com/QurieGLord/qd_and_d)
[![Flutter](https://img.shields.io/badge/Flutter-3.35.7-02569B?logo=flutter)](https://flutter.dev)

---

## 📊 Статус проекта

- **Версия**: 1.0.0+1
- **Прогресс**: 75% (Session 6 из 8)
- **Текущая сессия**: Session 6 (Inventory & Equipment) 🔄 **требует исправления критических багов**
- **APK**:
  - Debug: 99.7 MB
  - Release: 53.4 MB
- **Строк кода**: 11,829 lines (50 Dart файлов)

---

## ⚠️ Критические проблемы (Session 6)

> **ВАЖНО**: Перед продолжением разработки необходимо исправить следующие баги:

1. 🔴 **Предметы не сохраняются** в инвентарь (`character.dart:138` - const list)
2. 🟡 **Стартовая экипировка не добавляется** при создании персонажа
3. 🟠 **UI инвентаря перегружен** фильтрами и чипами
4. 🟡 **Предметы - простые карточки** (нет иконок, редкости, характеристик)
5. 🟡 **Нет кастомных предметов** (только из базы данных)

**Подробности**: См. [SESSION_SUMMARY.md](SESSION_SUMMARY.md) раздел "КРИТИЧЕСКИЕ ПРОБЛЕМЫ"

---

## 🎯 О проекте

**QD&D** - это комплексное приложение-компаньон для D&D 5e, построенное на принципе **"Build once, populate infinitely"**. Универсальная data-driven архитектура позволяет добавлять новый контент (классы, заклинания, предметы) ТОЛЬКО через JSON файлы, БЕЗ изменений кода.

### Основная философия

> Если добавление нового класса D&D (например, Artificer с Infusions) требует ЛЮБЫХ изменений кода - архитектура провалена.

---

## ✨ Реализованные возможности

### Текущий функционал (Sessions 0-6)

- ✅ **Material 3 Expressive UI** с цветовой схемой Monokai
- ✅ **Character List** с карточками персонажей
- ✅ **Character Sheet** с 4 табами:
  - Overview (stats, skills, features)
  - Spells (slots, prepared/known, Spell Almanac)
  - Inventory (52 предмета, фильтры, сортировка, поиск)
  - Journal (placeholder)
- ✅ **FC5 XML Import** - импорт персонажей из Fight Club 5
- ✅ **Character Creation Wizard** - multi-step wizard с 7 шагами
- ✅ **Spell System**:
  - Spell slots tracker
  - Prepared vs known spells
  - Spell Almanac (searchable database)
  - Spell filtering по классу/уровню
- ✅ **CRUD операции** для персонажей
- ✅ **Hive Storage** - offline-first локальное хранилище

### Reference персонаж

Приложение включает импортированного персонажа **"Кюри"** (Paladin Lv4, Oath of Conquest) из `assets/data/fc5_examples/pal_example.xml` для тестирования функциональности.

---

## 🚀 Быстрый старт

### Предварительные требования

- **Flutter**: 3.35.7+
- **Dart**: 3.9.4+
- **Java**: OpenJDK 17
- **Android SDK**: Build-Tools 35, Platform 36, NDK r29

### Установка окружения

```bash
# Установить JAVA_HOME (добавить в ~/.bashrc)
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
export PATH=$JAVA_HOME/bin:$PATH
```

### Команды разработки

```bash
# Получить зависимости
flutter pub get

# Запустить на подключенном устройстве
flutter run

# Собрать debug APK
flutter build apk --debug

# Собрать release APK
flutter build apk --release

# Очистить проект (при проблемах с кэшем)
flutter clean
```

### Работа с Hive (генерация адаптеров)

```bash
# Генерировать Hive type adapters после изменения моделей
flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode (автоматическая регенерация)
flutter pub run build_runner watch --delete-conflicting-outputs
```

**КРИТИЧЕСКИ ВАЖНО**: После добавления или изменения моделей с `@HiveType` и `@HiveField` ОБЯЗАТЕЛЬНО запустить build_runner.

---

## 🏗️ Архитектура

### Основная философия
**"Build once, populate infinitely"** - универсальная data-driven архитектура, требующая ТОЛЬКО добавления JSON данных для нового контента, БЕЗ изменений кода.

### Технический стек

- **Framework**: Flutter 3.35.7
- **Language**: Dart 3.9.4
- **State Management**: Provider
- **Storage**: Hive 2.2.3 (offline-first)
- **Design**: Material 3 Expressive
- **Fonts**: Google Fonts (Inter)
- **Build System**: Gradle 8.11.1 + AGP 8.9.1

### Зависимости

**UI & Theming**:
- google_fonts: ^6.1.0
- flutter_svg: ^2.0.9
- flutter_animate: ^4.5.0

**State Management**:
- provider: ^6.1.1

**Storage**:
- hive: ^2.2.3
- hive_flutter: ^1.1.0

**Parsing & Data**:
- xml: ^6.5.0
- uuid: ^4.2.2
- path_provider: ^2.1.2
- file_picker: ^8.1.4

### Структура проекта

```
qd_and_d/
├── lib/
│   ├── core/                    # Ядро приложения
│   │   ├── constants/          # Enums (AbilityScore, CharacterClass, ItemType)
│   │   ├── models/             # Data models (Hive)
│   │   ├── services/           # Бизнес-логика
│   │   └── theme/              # Material 3 темы
│   ├── features/               # UI функции (по экранам)
│   │   ├── character_list/
│   │   ├── character_sheet/
│   │   ├── character_creation/
│   │   ├── spell_almanac/
│   │   └── settings/
│   ├── shared/                 # Общие виджеты
│   └── main.dart               # Entry point
├── assets/
│   ├── data/
│   │   ├── classes.json        # 13 классов D&D 5e
│   │   ├── races.json          # Расы
│   │   ├── backgrounds.json    # Backgrounds
│   │   ├── items.json          # 52 предмета
│   │   ├── spells/             # Spell database
│   │   └── fc5_examples/       # Reference FC5 XML
│   └── images/
├── CLAUDE.md                   # Инструкции для Claude Code
├── SESSION_SUMMARY.md          # Summary всех сессий (0-6)
└── README.md                   # Этот файл
```

---

## 📚 Документация

### Основные файлы

- **[CLAUDE.md](CLAUDE.md)** - 🔴 **КРИТИЧЕСКИ ВАЖНО** - инструкции для Claude Code
- **[SESSION_SUMMARY.md](SESSION_SUMMARY.md)** - полный статус проекта, известные проблемы, история всех сессий

### Reference Assets

- `assets/data/fc5_examples/pal_example.xml` - Paladin "Кюри" (2.9MB)
- `assets/images/icon.svg` - логотип приложения (5.4KB)
- `assets/data/items.json` - 52 предмета (weapons, armor, consumables, tools)

---

## 📅 Development Roadmap

### ✅ Завершённые сессии (0-5)

- **Session 0**: Project Brief & Architecture
- **Session 1**: Foundation & Runnable App
- **Session 2**: Data Models, Storage & FC5 Import
- **Session 3**: Character Sheet Screen
- **Session 4**: Spell System
- **Session 5**: Character Creation Wizard

### 🔄 Текущая сессия (6)

**Session 6: Inventory & Equipment** - 🔴 **требует исправления критических багов**

**Завершено**:
- ✅ База предметов (52 items)
- ✅ UI инвентаря с фильтрами
- ✅ Поиск и сортировка

**Критические проблемы**:
- 🔴 Предметы не сохраняются (const list)
- 🟡 Стартовая экипировка не добавляется
- 🟠 UI перегружен
- 🟡 Предметы не полноценные карточки
- 🟡 Нет кастомных предметов

### 🎯 Будущие сессии (7-8)

- **Session 7**: Dice Roller & Combat Tools
- **Session 8**: Polish & Release (Journal, localization, themes)

---

## 🔧 Конфигурация Android

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

---

## 📦 Установка APK

### Вариант 1: ADB
```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

### Вариант 2: Flutter
```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
flutter install --debug
```

### Вариант 3: File Manager
1. Скопировать APK на устройство
2. Открыть через File Manager
3. Разрешить установку из неизвестных источников

---

## 🎨 Material 3 Expressive

### Цветовая схема (Monokai)

- **Primary**: #FFB3D9 (pink)
- **Secondary**: #A9DC76 (green)
- **Surface**: #FCFCFC (light) / #2D2A2E (dark)
- **Background**: #FAFAFA (light) / #221F22 (dark)

---

## 📞 Контакты

- **Автор**: QurieGLord
- **Email**: tipquri@gmail.com
- **Проект**: `~/Dev/Flutter/qd_and_d`

---

## 📄 Лицензия

Частный проект

---

**QD&D** - Your ultimate D&D 5e companion 🎲✨

**Последнее обновление**: 2025-11-18
**Следующий шаг**: Исправить критические проблемы Session 6
