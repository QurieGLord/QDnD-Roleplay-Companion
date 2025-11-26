# Инструкции для Gemini

*   **Язык общения:** Используй русский язык для коммуникации.
*   **Качество работы:** Стремись к высокому качеству выполнения задач, доводя дело до конца.
*   **Контекст проекта:** Мы разрабатываем масштабный D&D проект, который должен качественно реализовывать все многообразие механик и баз данных D&D 5e.

# GEMINI.md

## Project Overview

"QD&D" is a comprehensive Dungeons & Dragons 5th Edition companion app for Android and iOS. It is built with Flutter and follows a "data-driven" architecture. This means new content like classes, spells, and items can be added by simply including new JSON files in the `assets/data` directory, without needing to change the application's source code.

The application aims to support all 13 official D&D 5e classes, features Fight Club 5 XML import/export, and is designed to be fully functional offline.

## Data-Driven Architecture

### Adding New Content
The application is designed to be extensible without code changes.
*   **Classes:** Add `assets/data/classes/<class_id>.json`.
*   **Features:** Add `assets/data/features/<class_id>_features.json`. The `FeatureService` automatically scans this directory.
    *   **Important:** Ensure new JSON files are included in `pubspec.yaml` assets section if they are in new directories!
*   **Races/Backgrounds:** Similar JSON structure in respective folders.

### Class Features System
*   **Model:** `CharacterFeature` (Hive TypeId: 4). Supports active, passive, and resource-based features.
*   **Loading:** `FeatureService` dynamically loads all JSONs from `assets/data/features/` using `AssetManifest`.
*   **Paladin Implementation:** Complete implementation of Paladin (lvl 1-20) features exists in `paladin_features.json`. Other classes have skeleton files ready for population.

### Multiclassing Support
*   **Model:** `Character` model has been migrated to support `List<CharacterClass> classes` (Hive TypeId: 25) instead of single fields.
*   **Backward Compatibility:** The `Character` constructor automatically migrates legacy single-class data to the new list format.
*   **Level Up:** The Level Up Wizard is designed to handle class progression based on data, though UI for *taking* a new class (multiclassing) needs final polish.

## Building and Running

### Prerequisites

*   Flutter 3.35.7+
*   Dart 3.9.4+
*   Java OpenJDK 17
*   Android SDK (Build-Tools 35, Platform 36)

### Environment Setup

```bash
# Set JAVA_HOME (example path)
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
export PATH=$JAVA_HOME/bin:$PATH
```

### Key Commands

*   **Get dependencies:**
    ```bash
    flutter pub get
    ```
*   **Run the app:**
    ```bash
    flutter run
    ```
*   **Build Release APK:**
    ```bash
    flutter build apk --release
    ```
*   **Regenerate Hive Adapters (Required after model changes):**
    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```

## Development Conventions

*   **State Management:** `provider`.
*   **Storage:** `Hive` (NoSQL). Adapters must be registered in `StorageService`. **Always check TypeId uniqueness!**
*   **Design:** Material 3 Expressive. Focus on rich UI (cards, animations).
*   **Imports:** Use **absolute package imports** (`package:qd_and_d/...`) for Release build stability. Relative imports can cause resolution issues.
*   **Localization:** Bilingual (EN/RU) support via JSON data fields.

## Current Status (v1.1 - "Paladin Update")
*   **Implemented:**
    *   Complete Paladin class (1-20) with all official subclasses.
    *   Level Up Wizard (Interactive, Data-Driven, Choice support).
    *   Character Creation Wizard (Features preview step added).
    *   FC5 Import (Robust XML parsing + auto-feature assignment).
    *   Spells Tab (Categorized features: Resources, Active, Passive; Smart "Channel Divinity" buttons).
*   **To Do / Next Steps:**
    *   Populate other classes (Wizard, Rogue, etc.) in `assets/data/features/`.
    *   Enhance Multiclassing UI (Add "Add Class" button in Level Up).
    *   Implement Spell Selection logic in Character Wizard (currently placeholder).