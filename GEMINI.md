<<<<<<< HEAD
# Инструкции для Gemini

*   **Язык общения:** Используй русский язык для коммуникации.
*   **Качество работы:** Стремись к высокому качеству выполнения задач, доводя дело до конца.
*   **Контекст проекта:** Мы разрабатываем масштабный D&D проект, который должен качественно реализовывать все многообразие механик и баз данных D&D 5e.

=======
>>>>>>> gemini
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
<<<<<<< HEAD
=======
    *   **Resource Consumption:** Features can now link to a resource pool via `usageCostId`. For example, "Turn the Unholy" (Action) automatically consumes "Channel Divinity" (Resource).
>>>>>>> gemini

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

<<<<<<< HEAD
## 4. Current Status (v1.6 - "Wizard Localization Finalized")

### Recent Localization Efforts (Retrospective)
*   **Spell Almanac:**
    *   **FIXED:** `_getLocalizedValue` logic order corrected (Concentration duration bug).
*   **Character Creation Wizard:**
    *   **FIXED (UI):** `FeaturesSpellsStep` features now use styled Chips. `EquipmentStep` description wrapping improved.
    *   **FIXED (Basic Info):** Gender picker refactored to use text-only SegmentedButton (M/F/Oth) with correct localized keys. Physical appearance grid layout improved for responsiveness.
    *   **FIXED (Race & Class):** Added full localization for Races (Languages, Traits headers) and Classes (Skills, Armor, Weapons). Added mapping for snake_case weapon names from JSON data.
*   **Character Sheet UI Polish:**
    *   **FIXED (Dice Roller):** Localized titles for "Roll d20", "Saving Throws", and "Checks".
    *   **FIXED (Spells Tab):** Resources and Active Abilities are now interactive cards that open details sheets. Spells now open a full detail view (same as Almanac) instead of a simple toast. Refactored spell details logic into reusable `SpellDetailsSheet` and `SpellUtils`.
*   **Inventory & Catalog Polish:**
    *   **FIXED (Catalog):** Tapping an item in the "Add Item" catalog now opens a full `ItemDetailsSheet` instead of immediately asking for quantity. Users can review stats before adding.
    *   **Refactor:** Extracted item details logic to `ItemDetailsSheet` and localization logic to `ItemUtils`, removing duplication between Inventory tab and Catalog.
*   **Dice Roller & Stats:**
    *   **FIXED (Layout):** Completely redesigned `DiceRollerModal` to fit on screen without scrolling. Reduced die size (180px), created a compact control dock with horizontal dice selector and unified modifier/advantage row.
    *   **FIXED (Titles):** Changed title format for checks/saves to be more concise: "Check STR", "Save DEX" (localized as "Проверка СИЛ", "Спасбросок ЛОВ"), fixing overflow issues.
*   **Settings:**
    *   **FIXED:** Full localization of the Settings screen (Appearance, Theme, About, License). Added necessary keys to ARB files.

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
=======
## 4. Current Status (v1.3 - "Localization & Polish")

### Completed Tasks
*   **Localization:**
    *   Full Russian translation (`app_ru.arb`) for all UI elements.
    *   Dynamic formatter for units (imperial -> metric visual conversion).
    *   Locale toggler in Settings.
*   **UI Overhaul:**
    *   **Character Card:**
        *   Fixed width inconsistency (removed excess padding).
        *   Implemented `Listener`-based swipe gestures (Threshold 6px).
        *   Updated colors to use `secondaryContainer` (Cyan/Milk/Green depending on theme) for distinct visual hierarchy.
    *   **Navigation:**
        *   Navbar colors synced with Character Card.
        *   Smooth hide animation.
    *   **Scroll Physics:** Implemented scroll holding during card gestures and auto-reset on tab switch.
    *   **Class Dashboards:**
        *   **Monk (Phase 7):** Fixed logic bug where Max Ki was incorrect. Added dynamic level-based calculation. Redesigned UI with "Yin-Yang" tokens and Martial Arts Die button.
        *   **Barbarian:** Added `RageControlWidget` with Rage state toggle, visual glow effects, and Rage Damage calculator (+2 to +4).
        *   **Rogue (Phase 3):** Added `RogueToolsWidget` displaying Sneak Attack damage (Xd6).
        *   **Fighter (Phase 7):** "Command Center" Redesign. Moved to spacious list layout. Replaced traffic-light colors with strict theme coloring. Added "Lightning" and "Shield" tokens for Action Surge/Indomitable.
        *   **Integration:** Replaced generic resource rows with these dashboards in `AbilitiesTab` and implemented filtering to prevent duplicates.
*   **Features Engine:**
    *   Implemented `usageCostId` logic. Action features (e.g. "Flurry of Blows") now correctly find and consume their resource pool ("Ki") in the UI.
    *   Updated generator to map Monk features to Ki.
*   **Abilities Tab Rewrite (Phase 5, 5.5, 6):**
    *   **Safe Mode:** Implemented `try-catch` blocks and `_safeBuildWidget` to prevent crashes.
    *   **Deep Search:** Added robust feature finding.
    *   **Ghost Widget Fix:** Barbarian no longer sees Fighter dashboard.
    *   **Crash Fix:** Removed force-unwraps (`!`) to prevent NPEs.

### Pending Technical Tasks
*   **Localization QA & Fixes (High Priority):** Systematic audit of the UI to fix hardcoded strings, grammar errors, layout overflows, and incorrect dynamic formatting logic.
*   **Spell Selection Logic:** `CharacterCreationWizard` needs a step to write chosen spells to `Character.knownSpells`.
*   **Multiclass UI:** `LevelUpScreen` currently assumes leveling up the *primary* class. Needs a "Add New Class" flow.
*   **Content Population:** Fill `assets/data/features/` for remaining classes (Barbarian, Fighter, Rogue are currently empty placeholders).

## 5. Operational Guidelines (User Mandates)

### A. Definition of Done (DoD)
>>>>>>> gemini
Before confirming a task completion, you MUST:
1.  **Summary:** Briefly list changed files and logic.
2.  **Verification:** Autonomous execution of `flutter build apk --release`.
3.  **Result:**
    *   *Failure:* Fix silently and retry.
    *   *Success:* Append the last lines of the build log to the response.

<<<<<<< HEAD
### B. Merge Protocol
Upon user confirmation ("Success"/"Accepted"):
1.  **Update Docs:** Update `GEMINI.md` (this file), `docs/DEVELOPMENT_PLAN.md`, and `README.md` (if applicable).
2.  **Git:**
    *   `git add .`
    *   `git commit -m "feat(scope): message"`
    *   `git push origin gemini`
3.  **Next:** Proceed to the next backlog item.
=======
### B. Core Rules (Constitution)
1.  **Prime Directive:** Do NOT generate `git` commands (add, commit, push) automatically. The user handles version control.
2.  **Environment:** Assume Windows environment.
3.  **D&D Glossary:** Adhere to standard 5e terminology (SRD).
>>>>>>> gemini
