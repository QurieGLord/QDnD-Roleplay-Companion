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
    *   **Resource Consumption:** Features can now link to a resource pool via `usageCostId`. For example, "Turn the Unholy" (Action) automatically consumes "Channel Divinity" (Resource).

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

## 4. Operational Guidelines (User Mandates)

### A. Definition of Done (DoD)
Before confirming a task completion, you MUST:
1.  **Summary:** Briefly list changed files and logic.
2.  **Verification:** Autonomous execution of `flutter build apk --release`.
3.  **Result:**
    *   *Failure:* Fix and retry.
    *   *Success:* Append the last lines of the build log to the response.

### B. Core Rules (Constitution)
1.  **Prime Directive:** Do NOT generate `git` commands (add, commit, push) automatically. The user handles version control.
2.  **Environment:** Assume Windows environment.
3.  **D&D Glossary:** Adhere to standard 5e terminology (SRD).
