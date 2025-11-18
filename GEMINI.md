# Инструкции для Gemini

*   **Язык общения:** Используй русский язык для коммуникации.
*   **Качество работы:** Стремись к высокому качеству выполнения задач, доводя дело до конца.
*   **Контекст проекта:** Мы разрабатываем масштабный D&D проект, который должен качественно реализовывать все многообразие механик и баз данных D&D 5e.

# GEMINI.md

## Project Overview

"QD&D" is a comprehensive Dungeons & Dragons 5th Edition companion app for Android and iOS. It is built with Flutter and follows a "data-driven" architecture. This means new content like classes, spells, and items can be added by simply including new JSON files in the `assets/data` directory, without needing to change the application's source code.

The application aims to support all 13 official D&D 5e classes, features Fight Club 5 XML import/export, and is designed to be fully functional offline.

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
*   **Run the app on a connected device:**
    ```bash
    flutter run
    ```
*   **Build a debug APK:**
    ```bash
    flutter build apk --debug
    ```
*   **Build a release APK:**
    ```bash
    flutter build apk --release
    ```
*   **Clean the project:**
    ```bash
    flutter clean
    ```

## Development Conventions

*   **State Management:** The project uses the `provider` package for state management.
*   **Storage:** `Hive` is used for local, offline-first data storage. Character data and other application state are persisted on the device.
*   **Design:** The application follows the Material 3 Expressive design language, with a focus on animations and a tactile user experience.
*   **Internationalization:** The app is bilingual (English and Russian). All user-facing strings are managed through JSON files to support multiple languages.
*   **Architecture:** The core philosophy is **"Build once, populate infinitely."** The architecture is designed to be extensible through a universal `CharacterFeature` system that can represent any class ability, racial trait, or item effect. All game data is stored in JSON files located in the `assets/data` directory. New content should be added by creating new JSON files, not by modifying the Dart code.
*   **Code Style:** The project adheres to the `flutter_lints` package for code style and analysis.
