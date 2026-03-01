<div align="center">

# 🎲 QD&D - Your Roleplay Companion

### Your faithful companion in the world of Dungeons & Dragons 5e

*Manage characters. Cast spells. Defeat dragons.*

[![Flutter](https://img.shields.io/badge/Flutter-3.5+-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?style=for-the-badge&logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

[Download](https://github.com/QurieGLord/QDnD-Roleplay-Companion/releases) • [Web Version (PWA)](https://qurieglord.github.io/QDnD-Roleplay-Companion/) • [Report Bug](https://github.com/QurieGLord/QDnD-Roleplay-Companion/issues)

</div>

---

## 🌟 About

**QD&D** (Q stands for *Qurie*, the creator!) is a mobile app for managing D&D 5th Edition characters, crafted with absolute love for tabletop role-playing games. Forget paper character sheets and endless, confusing tables — everything you need for the game is now beautifully organized right in your pocket!

Whether you're a battle-hardened adventurer or a beginning hero taking your first steps, QD&D will become your most reliable companion at the gaming table. Create characters, manage spells, track inventory, and conduct combat with unique, class-specific mechanics — all in one incredibly juicy, Material 3 Expressive app.

---

## ✨ Key Features

### 🎨 Design & Customization
- **Themes:** Choose from stunning color schemes (QMonokai, Gruvbox, Catppuccin, etc.) with Light/Dark modes.
- **Visuals:** Pure Material 3 Expressive design. Enjoy rich animations, nested surfaces, and satisfying motion-physics in every interaction.
- **Dice Roller:** Integrated 3D-like physics animations for satisfying, tactile rolls.

### 🎭 Character Management
- **Creation Wizard:** Step-by-step character creation with instant feature previews and lore integration.
- **Level Up Wizard:** Interactive leveling with smart choice support (Subclasses, Fighting Styles).
- **Universal System:** Full, bespoke support for **ALL 12 CORE CLASSES** via a powerful data-driven architecture.
- **Fight Club 5 Import:** Seamlessly migrate your characters from XML.

### ⚔️ Combat System
- **Combat Tracker:** Initiative, rounds, and turn management with a visual dashboard.
- **Bespoke Class Dashboards:** Highly interactive, custom-built UI for every class! Experience the Barbarian's Rage, Rogue's Stealth (with hilarious narrative failures), Paladin's Smite, Monk's Ki, and more.
- **Vitality:** Quick HP adjustments with shake animations, Death Saves, and Temporary HP tracking.
- **Conditions:** Track all conditions with detailed, easy-to-read tooltips.

### 🔮 Magic & Spells
- **Spellbook:** Manage known and prepared spells with smart filtering.
- **Spell Slots:** Interactive trackers that auto-scale with your level.
- **Class Features:** Smart tracking of unique resources (e.g., Sorcery Points, Bardic Inspiration) and active abilities.

### 🎒 Inventory & Adventure
- **Equipment:** Visual slots for weapons/armor with automatic AC calculation.
- **The Forge:** Powerful custom Item Creator with live preview, icon picker, and visual stats editor.
- **Adventure Journal:** Rich text notes and quest tracking.
- **Offline First:** 100% functional without an internet connection.

### 📚 External Content Management (DLC)
- **Library Manager:** Import external content packs via XML (FC5 format).
- **Unified Database:** Seamlessly merge built-in SRD content with your own homebrew libraries.
- **Bilingual & Smart Parsing:** Full support for English and Russian. Automatically detects and separates bilingual text in imported files!

---

## 📱 Screenshots

<div align="center">

| Character Sheet | Class Dashboards | Spells |
|:-:|:-:|:-:|
| ![Character Sheet](docs/screenshots/character_sheet.png) | ![Combat Tracker](docs/screenshots/combat.png) | ![Spells](docs/screenshots/spells.png) |

| Journal | Inventory | Level Up |
|:-:|:-:|:-:|
| ![Journal](docs/screenshots/journal.png) | ![Inventory](docs/screenshots/inventory.png) | ![Level Up](docs/screenshots/levelup.png) |

</div>

---

## 🚀 Getting Started

### 🤖 Android Installation
1. **Download the latest APK** from the [Releases page](https://github.com/QurieGLord/QDnD-Roleplay-Companion/releases).
2. **Install** on your Android device (Android 7.0+).
3. **Launch** and start your adventure!

### 🍏 iOS Installation (PWA via Safari)
*⚠️ Note: A full native iOS release is not yet available. However, you can use the Progressive Web App (PWA) version! Please keep in mind that PWA stability might vary compared to the native Android app.*
1. Open Safari on your iPhone/iPad.
2. Navigate to the Web App: **[QD&D Web Version](https://qurieglord.github.io/QDnD-Roleplay-Companion/)**
3. Tap the **Share** button (the square with an arrow pointing up) at the bottom of the screen.
4. Scroll down and select **"Add to Home Screen"**.
5. Tap **Add** in the top right corner. The QD&D icon will appear on your home screen, launching like a native app!

---

## 🛠️ Building from Source

```bash
# Clone the repository
git clone [https://github.com/QurieGLord/QDnD-Roleplay-Companion.git](https://github.com/QurieGLord/QDnD-Roleplay-Companion.git)

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

### ✅ Recent Triumphs
- **v0.2.5 (The Wizard's Polish):** Significant UI/UX improvements to the Character Creation and Level Up Wizards.

    - **M3 Expressive Overview:** Completely redesigned the Hero Summary screen with nested cards, a structured Appearance grid, and beautifully animated spell lists.

    - **Expressive Choice Selectors:** Replaced all clunky legacy dropdowns with premium, fully localized Modal Bottom Sheets across both wizards.

    - **Smart Spells & Localization:** Fixed prepopulated spell rendering for prepared casters and established a DRY global localization architecture for Fighting Styles.

- **v0.2.0 (The Class Abilities Factory):** Massive M3 Expressive visual overhaul. All 12 core classes received bespoke, interactive dashboards (Rage Engine, Stealth Mechanics, Ki points, etc.) with global deduplication for a flawless UI.

### 🔮 The Path Ahead
- **v0.5.0 (Many Paths):** Full implementation of the MULTICLASS system. Mix and match your favorite classes with correct spell slot scaling and feature integration.
- **v0.8.0 (The Grand Library):** Deep rework and complete overhaul of the third-party content library import system to handle any homebrew you throw at it.
- **v1.0.0 (The Ultimate Companion):** Stable release! Full implementation of SRD content with all mechanics, unique features, and flawless loading of any third-party libraries.

### 👑 Pro Version (In the distant future :D)
- **Cloud Sync:** Seamless backup and sync via Google Drive.
- **PDF Export:** Generate and print beautiful, standardized Character Sheets.
- **DM Mode!!!** The ultimate toolkit for Dungeon Masters, complete with Co-op features to sync with your players in real-time!

---

## 📜 License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.

---

<div align="center">

**Developed by [Qurie](https://github.com/QurieGLord)**

*May your d20 always land on a natural 20!* 🎲✨

</div>