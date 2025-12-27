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
    *   **UI Integration:** Custom widgets (like `ExpandableCharacterCard`) bind to semantic slots:
        *   `secondaryContainer`: Used for the Character Card and Navbar background (Accent color).
        *   `onSecondaryContainer`: Used for text/icons on the card.
        *   `secondary`: Used for Glow effects and active highlights.
        *   `primary`: Used for main actions (FAB, Buttons).
    *   **Glow Effects:** Achieved via `BoxShadow` using `colorScheme.secondary.withOpacity(0.15)`.

### C. Character Model & Multiclassing (`feat/core`)
*   **Migration:** The `Character` model was refactored to support multiclassing.
    *   **Legacy Fields:** `characterClass` and `subclass` (Strings) are kept for backward compatibility and UI display of the "Primary" class.
    *   **New Field:** `List<CharacterClass> classes` (Hive TypeId 25).
    *   **Auto-Migration:** The `Character` constructor detects if `classes` is empty but legacy fields exist, and automatically populates the list.

### D. Localization (`feat/l10n`)
*   **Architecture:** `flutter_localizations` + `intl` (ARB based).
*   **Configuration:** `l10n.yaml` -> `lib/l10n/`.
*   **Dynamic Translation:**
    *   **Helpers:** `_getLocalizedValue`, `_formatValue` (in widgets) translate data-driven strings (e.g., "Blue" -> "Голубой", "lb" -> "фунт") without altering the English data model.
    *   **Keys:** `AppLocalizations` keys match standardized D&D terms (e.g., `abilityStr`, `skillStealth`).

### E. UI/UX Polish (`feat/ui`)
*   **Expandable Character Card:**
    *   **Gestures:** Swipe Down on card to Expand. Swipe Up on card to Collapse.
    *   **Smart Scroll:** Swiping the card halts the parent `NestedScrollView` to prevent "flying away".
    *   **Animation:** Smooth `AnimatedSize` transition when switching tabs (card collapses upwards).
    *   **Visibility:** Card is only interactive on Overview tab but persists in tree for animation.
    *   **Scroll Reset:** Returning to Overview tab automatically smooth-scrolls to top (`_scrollToTop`).

## 3. Building and Running

### Prerequisites
*   Flutter 3.35.7+
*   Dart 3.9.4+
*   **Build Runner:**
    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```
*   **Localization Gen:**
    ```bash
    flutter gen-l10n
    ```

## 4. Current Status (v1.6 - "Wizard Localization Finalized")

### Recent Localization Efforts (Retrospective)
*   **Spell Almanac:**
    *   **FIXED:** `_getLocalizedValue` logic order corrected (Concentration duration bug).
*   **Character Creation Wizard:**
    *   **FIXED (UI):** `FeaturesSpellsStep` features now use styled Chips. `EquipmentStep` description wrapping improved.
    *   **FIXED (Basic Info):** Gender picker refactored to use text-only SegmentedButton (M/F/Oth) with correct localized keys. Physical appearance grid layout improved for responsiveness.
    *   **FIXED (Race & Class):** Added full localization for Races (Languages, Traits headers) and Classes (Skills, Armor, Weapons). Added mapping for snake_case weapon names from JSON data.

### Pending High-Priority Fixes
1.  **Data Population:**
    *   *Correction:* `barbarian.json`, `fighter.json`, `rogue.json` have content (check if localized).
    *   *Empty Files:* `bard.json`, `cleric.json`, `druid.json`, `monk.json`, `ranger.json`, `sorcerer.json`, `warlock.json`, `wizard.json` are currently empty placeholders (3 bytes).
    *   **Task:** Populate these files with D&D 5e SRD data (English first, then Russian keys).

### Operational Guidelines (User Mandates)

### A. Bilingual Content Mandate (CRITICAL)
*   **All new content** (Classes, Races, Spells, Items, Features) added to JSON files **MUST** be localized in both English (`en`) and Russian (`ru`).
*   **Structure:** Use `{"en": "Text", "ru": "Текст"}` for names and descriptions.
*   **Keys:** Ensure `AppLocalizations` has keys for any new UI terms.

### B. Definition of Done (DoD)
Before confirming a task completion, you MUST:
1.  **Summary:** Briefly list changed files and logic.
2.  **Verification:** Autonomous execution of `flutter build apk --release`.
3.  **Result:**
    *   *Failure:* Fix silently and retry.
    *   *Success:* Append the last lines of the build log to the response.

### B. Merge Protocol
Upon user confirmation ("Success"/"Accepted"):
1.  **Update Docs:** Update `GEMINI.md` (this file), `docs/DEVELOPMENT_PLAN.md`, and `README.md` (if applicable).
2.  **Git:**
    *   `git add .`
    *   `git commit -m "feat(scope): message"`
    *   `git push origin gemini`
3.  **Next:** Proceed to the next backlog item.