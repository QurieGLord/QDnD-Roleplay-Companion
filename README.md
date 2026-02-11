<div align="center">

# 🎲 QD&D - Your Roleplay Companion

### Your faithful companion in the world of Dungeons & Dragons 5e

*Manage characters. Cast spells. Defeat dragons.*

[![Flutter](https://img.shields.io/badge/Flutter-3.5+-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?style=for-the-badge&logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

[Download](https://github.com/QurieGLord/QDnD-Roleplay-Companion/releases) • [Documentation](docs/) • [Report Bug](https://github.com/QurieGLord/QDnD-Roleplay-Companion/issues)

</div>

---

## 🌟 About

**QD&D** (Quick D&D) is a mobile app for managing D&D 5th Edition characters, created with love for tabletop role-playing games. Forget paper character sheets and endless tables — everything you need for the game is now in your pocket!

Whether you're an experienced adventurer or a beginning hero, QD&D will become your reliable companion at the gaming table. Create characters, manage spells, track inventory, and conduct combat — all in one beautifully designed app.

---

## ✨ Key Features

### 🎨 Design & Customization
- **Themes:** Choose from 6 stunning color schemes (QMonokai, Gruvbox, Catppuccin, etc.) with Light/Dark modes.
- **Visuals:** Material 3 Expressive design with rich animations and vibrant accents.
- **Dice Roller:** 3D-like physics animations for satisfying rolls.

### 🎭 Character Management
- **Creation Wizard:** Step-by-step character creation with instant feature preview.
- **Level Up Wizard:** Interactive leveling with choice support (Subclass, Fighting Style).
- **Universal System:** Supports all 13 official classes via data-driven architecture.
- **Fight Club 5 Import:** Seamlessly migrate your characters from XML.

### ⚔️ Combat System
- **Combat Tracker:** Initiative, rounds, and turn management with a visual dashboard.
- **Vitality:** Quick HP adjustments with shake animations, Death Saves, and Temporary HP.
- **Conditions:** Track all 13 conditions with detailed tooltips.

### 🔮 Magic & Spells
- **Spellbook:** Manage known and prepared spells with filtering.
- **Spell Slots:** Interactive trackers that auto-scale with level.
- **Class Features:** Smart tracking of resources (e.g., Lay on Hands) and active abilities.

### 🎒 Inventory & Adventure
- **Equipment:** Visual slots for weapons/armor with auto AC calculation.
- **The Forge:** Powerful Item Creator with live preview, icon picker, and visual stats editor.
- **Adventure Journal:** Rich text notes and quest tracking.
- **Offline First:** 100% functional without internet.

### 📚 External Content Management (DLC)
- **Library Manager:** Import external content packs via XML (FC5 format).
- **Unified Database:** Seamlessly merges built-in SRD content with your imported libraries.
- **Source Tracking:** View items/spells by source pack with instant reload capabilities.
- **Cleanup:** Easily remove specific compendiums without losing other data.

### 🌍 Localization
- **Bilingual:** Full support for English and Russian languages (UI and Content).
- **Smart Parsing:** Automatically detects and separates bilingual text in imported files (e.g. `English text ---RU--- Русский текст`).
- **Dynamic Translation:** Automatically formats units (lb/kg, ft/m) and terms based on your preference.

---

## 🛠️ Architecture & Data Flow

QD&D is built on a **Data-Driven Architecture**. The codebase acts as an engine, processing data fuels (JSON/XML) to generate gameplay mechanics dynamically.

### 🔄 ETL Pipeline (Extract, Transform, Load)
We use custom Dart scripts in `tool/` to generate optimized assets for the app:
- **`tool/generate_features.dart`**: The core ETL script. It reads SRD data, applies hardcoded logic (e.g., Monk Ki consumption, Paladin resource pools), injects virtual actions (like "Use Lay on Hands"), and outputs a unified registry.
- **Output:** `assets/data/features/srd_features.json`. This file contains the "truth" for all class features.

### 🏗️ Data Models
The `CharacterFeature` model (`lib/core/models/character_feature.dart`) is the backbone of the class system. Key fields include:
- **`usageCostId`**: Links an Action (e.g., "Flurry of Blows") to a Resource Pool (e.g., "Ki"). The UI automatically handles the deduction logic.
- **`usageInputMode`**: Defines the UI for spending resources (e.g., `'slider'` for granular spending like Lay on Hands, or simple tap for fixed costs).
- **`consumption`**: Defines complex costs (e.g., "Spend 5 points").

### 🧩 Content Injection
- **Add Classes/Features:** Simply drop JSON files into `assets/data/features/`.
- **Add Spells/Items:** Extend the database with your own homebrew content via JSON.
- **Localization:** Built-in support for bilingual content (English/Russian).

---

## 📱 Screenshots

<div align="center">

| Character Sheet | Combat Tracker | Spells |
|:-:|:-:|:-:|
| ![Character Sheet](docs/screenshots/character_sheet.png) | ![Combat Tracker](docs/screenshots/combat.png) | ![Spells](docs/screenshots/spells.png) |

| Journal | Inventory | Level Up |
|:-:|:-:|:-:|
| ![Journal](docs/screenshots/journal.png) | ![Inventory](docs/screenshots/inventory.png) | ![Level Up](docs/screenshots/levelup.png) |

</div>

---

## 🚀 Getting Started

### Installation

1. **Download APK** from [Releases](https://github.com/QurieGLord/QDnD-Roleplay-Companion/releases)
2. **Install** on Android device (Android 7.0+)
3. **Launch** and start your adventure!

### Building from Source

```bash
# Clone the repository
git clone https://github.com/QurieGLord/QDnD-Roleplay-Companion.git

# Install dependencies
flutter pub get

# Generate code (Hive adapters & Localization)
flutter pub run build_runner build --delete-conflicting-outputs
flutter gen-l10n

# Run
flutter run

```

---

## 🗺️ Roadmap

### ✅ v0.11 (Inventory & Polish)
- **Inventory:** Encumbrance visualizer (Weight limit) & Attunement tracker.
- **UX:** Swipe-to-delete items, better item details.
- **Combat System:** Redesigned Combat Tracker with integrated Magic Sheet.
- **Magic System:** Adaptive Spell Slots (Icons/Chips) & Preparation Logic.
- **Level Up:** Strict feature filtering and subclass support.
- **Localization:** Full EN/RU support.

### ✅ v0.13.0 (Class Features & Terminology)
- **Improved FC5 Import:** Robust parsing of bilingual subclasses (English/Russian) and class features.
- **D&D 5e Compliance:** Dynamic terminology for subclasses (Primal Path, Sacred Oath, Arcane Tradition, etc.).
- **Smart Spell Eligibility:** Spells now correctly link to classes via standardized IDs.
- **Bug Fixes:** Corrected "Passive" tag localization and subclass selection UI.

### ✅ v0.12 (Content & Creativity)
- **The Forge:** Custom Item Creator with visual preview and full stat control.
- **Library Manager:** Import/Delete external content packs (XML) to expand your game.
- **Unified Database:** Mix built-in content with your own homebrew seamlessly.
- **Smart Parsing:** Auto-detects bilingual content (English/Russian) in imported files.

### ✅ v0.14 (The Wizard Update)
- **Spell Manager:** Strict limits for Cantrips/Spells Known (Bard, Sorcerer, etc.).
- **Subclass UX:** Subclass selection to Features step of Character creating wizard.  Level 1 support for Clerics/Warlocks.
- **Features using:** Features using UI with resource points spending on character's Spells tab.
- **Bug fixes:** Fixed some translation bugs.

### ✅ v0.15 (Expertise & Choices)
- **Expertise System:** Full support for Double Proficiency (Rogue/Bard) with distinct visual indicators (Double Ring).
- **Complex Choices:** UI for selecting sub-options within features (Fighting Style, Draconic Ancestry) during character creation.
- **Skill Engine:** Correct calculation of 2x Proficiency bonuses in the Stats tab.

### 🔮 v0.2.0 (Class Abilities Factory) - *Current Work*

### 🔮 v1.0 (Planned)
- [ ] Cloud Sync (Google Drive)
- [ ] PDF Export (Character Sheet)
- [ ] Multiclassing UI
- [ ] DM Tools (Encounter Builder)

---

## 📜 License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.

---

<div align="center">

**Developed by [Qurie](https://github.com/QurieGLord)**

*May your d20 always land on a natural 20!* 🎲✨

</div>
