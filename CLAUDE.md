# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Язык общения

**ВСЕ общение в этом проекте ведётся на русском языке.**

## ⚠️ КРИТИЧЕСКИ ВАЖНО: Git Workflow

**Проект использует Git Worktree для изоляции веток:**

### 📁 Структура worktree:
```
/home/qurie/Dev/Flutter/
├── qd_and_d-main/       # main branch (stable)
├── qd_and_d-claude/     # claude branch (работаем здесь!) ⚠️
└── qd_and_d-gemini/     # gemini branch (Gemini AI)
```

### 🎯 Текущая рабочая директория
**Путь**: `/home/qurie/Dev/Flutter/qd_and_d-claude`
**Ветка**: `claude` (всегда)

### ПРАВИЛА РАБОТЫ:
1. **ВСЕГДА работать ТОЛЬКО в `/home/qurie/Dev/Flutter/qd_and_d-claude`**
2. **НИКОГДА не переходить в другие worktree директории**
3. **Все изменения делать ТОЛЬКО здесь**
4. **Ветка автоматически `claude` - переключение не требуется**
5. **Не мержить в `main` без разрешения пользователя**

### Проверка текущего worktree:
```bash
pwd
# Должно быть: /home/qurie/Dev/Flutter/qd_and_d-claude

git branch
# Должно быть: * claude
```

### Преимущества worktree:
- ✅ Нет случайного переключения на другие ветки
- ✅ Изолированная рабочая среда
- ✅ Можно работать с несколькими ветками одновременно
- ✅ Быстрое переключение между версиями (просто `cd`)

**Подробнее**: См. [WORKTREE_INFO.md](WORKTREE_INFO.md)

---

## Обзор проекта

**QD&D (Quick D&D: Your Roleplay Companion)** - комплексное Flutter-приложение для управления персонажами D&D 5e на Android/iOS. Проект следует принципу **"Build once, populate infinitely"**: универсальная data-driven архитектура, требующая ТОЛЬКО добавления JSON данных для нового контента, БЕЗ изменений кода.

### Текущий статус
- **Версия**: 1.0.0+1
- **Ветка**: `claude` (работаем здесь!)
- **Прогресс**: 75% - Session 6 из 8 завершена (Inventory & Equipment)

### Основная философия

> **"Build once, populate infinitely"**
> Если добавление нового класса D&D (например, Artificer с Infusions) требует ЛЮБЫХ изменений кода - архитектура провалена.

---

## Команды разработки

### Предварительные требования
```bash
# Установить переменные окружения (добавить в ~/.bashrc)
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
export PATH=$JAVA_HOME/bin:$PATH
```

**Требования**:
- Flutter 3.35.7+
- Dart 3.9.4+
- Java OpenJDK 17
- Android SDK (Build-Tools 35, Platform 36, NDK r29)

### Основные команды

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

# Watch mode (автоматическая регенерация при изменениях)
flutter pub run build_runner watch --delete-conflicting-outputs
```

**КРИТИЧЕСКИ ВАЖНО**: После добавления или изменения моделей с `@HiveType` и `@HiveField` ОБЯЗАТЕЛЬНО запустить build_runner, иначе приложение не соберётся.

---

## Архитектура кодовой базы

### Структура директорий

```
lib/
├── core/                           # Ядро приложения
│   ├── constants/
│   │   └── enums.dart             # AbilityScore, CharacterClass, ItemType, etc.
│   ├── models/                     # Data models (Hive)
│   │   ├── character.dart         # Главная модель персонажа
│   │   ├── ability_scores.dart    # STR, DEX, CON, INT, WIS, CHA + modifiers
│   │   ├── spell.dart             # Заклинания
│   │   ├── character_spell.dart   # Связь персонаж-заклинание
│   │   ├── character_feature.dart # Universal feature system
│   │   ├── item.dart              # Предметы и снаряжение
│   │   ├── class_data.dart        # JSON-based class definitions
│   │   ├── race_data.dart         # JSON-based race definitions
│   │   └── background_data.dart   # JSON-based background definitions
│   ├── services/                   # Бизнес-логика
│   │   ├── storage_service.dart   # Hive CRUD операции
│   │   ├── fc5_parser.dart        # FC5 XML парсинг (import)
│   │   ├── import_service.dart    # Оркестрация импорта
│   │   ├── spell_service.dart     # Работа с заклинаниями
│   │   ├── spellcasting_service.dart # Spell slots, preparation
│   │   ├── spell_eligibility_service.dart # Spell filtering
│   │   ├── feature_service.dart   # Class features
│   │   ├── item_service.dart      # Инвентарь
│   │   └── character_data_service.dart # Races, classes, backgrounds
│   └── theme/
│       └── app_theme.dart         # Material 3 темы (light/dark)
│
├── features/                       # UI функции (по экранам)
│   ├── splash/
│   │   └── splash_screen.dart     # Splash с анимацией (1.5s)
│   ├── character_list/
│   │   ├── character_list_screen.dart  # Список персонажей
│   │   └── widgets/
│   │       ├── character_card.dart     # Карточка персонажа
│   │       └── empty_state.dart        # Empty state UI
│   ├── character_sheet/
│   │   ├── character_sheet_screen.dart # Детальный просмотр
│   │   ├── widgets/
│   │   │   ├── expandable_character_card.dart
│   │   │   ├── overview_tab.dart       # Stats, skills, features
│   │   │   ├── spells_tab.dart         # Spell slots, prepared spells
│   │   │   └── stats_tab.dart
│   │   └── tabs/
│   │       └── inventory_tab.dart      # Inventory UI
│   ├── character_creation/
│   │   ├── character_creation_wizard.dart  # Multi-step wizard
│   │   ├── character_creation_state.dart
│   │   └── steps/
│   │       ├── basic_info_step.dart
│   │       ├── race_class_step.dart
│   │       ├── ability_scores_step.dart
│   │       ├── skills_step.dart
│   │       ├── equipment_step.dart
│   │       ├── background_step.dart
│   │       └── review_step.dart
│   ├── character_edit/
│   │   └── character_edit_screen.dart
│   ├── spell_almanac/
│   │   └── spell_almanac_screen.dart   # Searchable spell database
│   └── settings/
│       └── settings_screen.dart        # Настройки (theme, language)
│
├── shared/                        # Общие виджеты
│   └── widgets/
│       └── dice_roller_modal.dart # Dice roller UI
│
└── main.dart                      # Entry point

assets/data/
├── classes.json                    # 13 классов D&D 5e
├── races.json                      # Расы
├── backgrounds.json                # Backgrounds
├── items.json                      # Предметы (weapons, armor, gear)
├── spells/                         # Spell database (JSON files)
│   ├── paladin.json               # Paladin spells
│   ├── wizard.json                # Wizard spells
│   └── ...
└── fc5_examples/                   # Reference FC5 XML files
    └── pal_example.xml             # "Кюри" - Paladin Lv4 (2.9MB)
```

---

## Особенности разработки

### Hive Models

При создании/изменении моделей:
1. Добавить `@HiveType(typeId: X)` к классу (выбрать УНИКАЛЬНЫЙ typeId!)
2. Добавить `part 'model_name.g.dart'` в начало файла
3. Добавить `@HiveField(N)` к каждому полю
4. Зарегистрировать adapter в `StorageService.init()`
5. **Запустить**: `flutter pub run build_runner build --delete-conflicting-outputs`

**ВАЖНО**: TypeId должен быть УНИКАЛЬНЫМ во всём проекте!

### Работа с Hive списками

**КРИТИЧЕСКИ ВАЖНО**: Hive возвращает неизменяемые списки. Всегда создавайте копию:

```dart
// ❌ НЕПРАВИЛЬНО
character.inventory.add(item);

// ✅ ПРАВИЛЬНО
character.inventory = List.from(character.inventory)..add(item);
character.save();
```

### Локализация

Все UI строки должны поддерживать EN/RU:

```dart
Map<String, String> localizedName = {
  'en': 'Rage',
  'ru': 'Ярость'
};
```

### Material 3 Expressive

- Цветовая схема: Monokai (primary #FFB3D9 pink, secondary #A9DC76 green)
- Анимации: physics-based, easeInOut 300-400ms
- Шрифты: Google Fonts (Inter)

---

## Технический стек

### Flutter & Dart
- Flutter: 3.35.7
- Dart SDK: 3.9.4
- Minimum SDK: Android 7.0 (API 24), iOS 12.0

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

**Dev Dependencies**:
- hive_generator: ^2.0.1
- build_runner: ^2.4.13
- flutter_lints: ^4.0.0

### Android Configuration
- compileSdk: 36
- targetSdk: 34
- minSdk: 24
- NDK: 29.0.14206865
- Java: 17
- Gradle: 8.11.1
- AGP: 8.9.1

---

## Документация

### Основные файлы
- **[README.md](README.md)** - quick start, команды, текущий статус
- **[CLAUDE.md](CLAUDE.md)** - этот файл, инструкции для Claude Code
- **[PROJECT_BRIEF.md](PROJECT_BRIEF.md)** - обзор проекта, архитектура, план разработки

### Reference Assets
- `assets/data/fc5_examples/pal_example.xml` - Paladin "Кюри" для тестирования FC5 импорта (2.9MB)
- `assets/images/icon.svg` - логотип приложения (5.4KB)

---

## Git Workflow для Claude

### Перед началом работы

```bash
# 1. Проверить текущую ветку
git branch

# 2. Если не в claude - переключиться
git checkout claude

# 3. Убедиться, что working tree чистый
git status
```

### При коммите изменений

```bash
# 1. Проверить изменения
git status
git diff

# 2. Добавить файлы
git add <files>

# 3. Создать коммит с понятным сообщением
git commit -m "Краткое описание изменений

Детали:
- Что было сделано
- Почему это было нужно
- Какие файлы затронуты

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"

# 4. При необходимости - push в remote
git push origin claude
```

### НИКОГДА не делать:

- ❌ `git checkout main` или `git checkout gemini`
- ❌ `git merge` без разрешения пользователя
- ❌ `git push --force`
- ❌ Коммитить в другие ветки кроме `claude`

---

## Приоритеты при работе над проектом

### 1. ВСЕГДА проверять ветку перед работой
```bash
git branch  # Должно быть: * claude
```

### 2. Читать актуальную документацию
- [README.md](README.md) - текущий статус проекта
- [PROJECT_BRIEF.md](PROJECT_BRIEF.md) - детальный план

### 3. Следовать data-driven архитектуре
Новый контент = JSON файлы, НЕ код.

### 4. Тестировать изменения в Hive моделях
После изменения моделей:
- Запустить build_runner
- Протестировать сохранение/загрузку
- Проверить, что списки изменяемые

---

## Контакты

- **Автор**: QurieGLord
- **Email**: tipquri@gmail.com
- **Путь проекта**: `~/Dev/Flutter/qd_and_d`
- **GitHub**: Ветка `claude`

---

**Последнее обновление**: 2025-11-19
**Ветка**: `claude` ⚠️ (работаем только здесь!)
**Текущая сессия**: Session 6 завершена
**Следующий шаг**: Session 7 - Dice Roller & Combat Tools
