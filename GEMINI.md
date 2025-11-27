# Инструкции для Gemini

*   **Язык общения:** Используй русский язык для коммуникации.
*   **Качество работы:** Стремись к высокому качеству выполнения задач, доводя дело до конца.
*   **Контекст проекта:** Мы разрабатываем масштабный D&D проект, который должен качественно реализовывать все многообразие механик и баз данных D&D 5e.

# GEMINI.md

## 1. Project Overview

"QD&D" is a comprehensive Dungeons & Dragons 5th Edition companion app for Android and iOS. It utilizes a **Data-Driven Architecture** where game content (Classes, Features, Spells) is decoupled from the codebase and loaded dynamically from JSON assets.

## 2. Technical Architecture & Implementation Details

### A. Data-Driven Content System
*   **Pattern:** The app treats code as an engine and JSON files as fuel.
*   **Implementation (`FeatureService`):**
    *   Uses `AssetManifest.loadFromAssetBundle` to scan the `assets/data/features/` directory at runtime. This allows adding new class features by simply dropping a JSON file, without code changes.
    *   **Fallback:** Has a hardcoded fallback to `paladin_features.json` if the manifest scan fails (e.g., in some test environments).
    *   **Model:** Maps JSON to `CharacterFeature` (Hive TypeId 4). Handles complex fields like `resourcePool` (for Lay on Hands) and `actionEconomy` (Action/Bonus/Reaction).

### B. Theming Engine (`feat/theme`)
*   **Architecture:** `ThemeProvider` (ChangeNotifier) + `AppPalettes` (Static Data).
*   **Implementation:**
    *   **Palettes:** `lib/core/theme/app_palettes.dart` contains strictly defined `ColorScheme` definitions for 6 presets (QMonokai, Gruvbox, etc.) in both Light and Dark modes.
    *   **Strict Mapping:** We avoid `ThemeData.from(seedColor)` to maintain exact control over hex codes (critical for "QMonokai" specific shades).
    *   **UI Integration:** Custom widgets (like `ExpandableCharacterCard`) do NOT use hardcoded colors. They bind to semantic slots:
        *   `surfaceContainerHighest`: Used for card backgrounds to differentiate from the main background (`surface`).
        *   `primary/secondary`: Used for icons and accents.
        *   `tertiary`: Used for special highlights (e.g., Level Up button).
    *   **Glow Effects:** Achieved via `BoxShadow` using `colorScheme.primary.withOpacity(0.2)` rather than gradients, ensuring readability while maintaining style.

### C. Character Model & Multiclassing (`feat/core`)
*   **Migration:** The `Character` model was refactored to support multiclassing.
    *   **Legacy Fields:** `characterClass` and `subclass` (Strings) are kept for backward compatibility and UI display of the "Primary" class.
    *   **New Field:** `List<CharacterClass> classes` (Hive TypeId 25).
    *   **Auto-Migration:** The `Character` constructor detects if `classes` is empty but legacy fields exist, and automatically populates the list. This ensures old saves don't break.

### D. Dice Roller (`refactor/ui`)
*   **Rendering:** Instead of fonts/images, we use a **`CustomPainter` (`DiceShapePainter`)**.
    *   Draws geometric paths (Triangle d4, Rounded Rect d6, Pentagonal d12, Hexagonal d20) programmatically.
    *   Allows dynamic coloring (`primary` when rolling, `tertiary` on success) without managing multiple assets.
*   **Animation:** Physics-based simulation using `AnimationController`.
    *   **Tumble:** `RotationTransition` with `CurvedAnimation` (ElasticOut) for a satisfying "clunk" stop.
    *   **Pop:** `ScaleTransition` sequence (shrink -> expand -> settle) to emphasize the result.
    *   **Haptics:** Triggers `HapticFeedback.selectionClick` on roll and `heavyImpact` on result.

### E. Combat System (`feat/combat`)
*   **Tracker:** `CombatTrackerScreen` manages a separate state loop via `Timer` for round tracking.
*   **UI:** Implements a "Dashboard" layout.
    *   **HP Ring:** Huge `CircularProgressIndicator` in the center acts as the main interactive element.
    *   **Reactive Animations:** The screen uses a `ShakeAnimation` (Sine wave translation) triggered when taking damage.
    *   **State Sync:** Uses `ValueListenableBuilder` on the Hive box to react to changes made in modal bottom sheets (like damage/heal dialogs) instantly without manual `setState` chains.

## 3. Building and Running

### Prerequisites
*   Flutter 3.35.7+
*   Dart 3.9.4+
*   **Build Runner:** Must be run after any model changes:
    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```

### Important Assets
*   Ensure all new content folders (e.g., `assets/data/features/`) are explicitly listed in `pubspec.yaml`. Flutter does not recursively include folders.

## 4. Current Status (v1.2 - "Visuals Update")
*   **Completed:**
    *   Full Paladin implementation (JSON).
    *   Advanced Theming system with 6 presets.
    *   Redesigned Combat/Dice/Stats interfaces.
    *   Robust FC5 Import with error handling.
*   **Pending Technical Tasks:**
    *   **Spell Selection Logic:** `CharacterCreationWizard` needs a step to write chosen spells to `Character.knownSpells`.
    *   **Multiclass UI:** The backend supports `List<CharacterClass>`, but `LevelUpScreen` currently assumes leveling up the *primary* class. Needs a "Add New Class" flow.