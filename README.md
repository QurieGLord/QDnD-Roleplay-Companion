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

### 🎭 Character Management
- **Character Creation Wizard** — step-by-step creation with validation.
- **Full Customization** — edit avatar, appearance, traits, and backstory.
- **Universal System** — supports all 13 official classes (via JSON data).
- **Fight Club 5 Import** — seamlessly import characters from XML.

### ⚔️ Combat System
- **Combat Tracker** — initiative, rounds, and turn management.
- **HP Management** — quick damage/heal, temporary HP.
- **Conditions** — track all 13 conditions with descriptions.
- **Death Saves** — automatic tracking of successes/failures.

### 🔮 Magic & Spells
- **Spellbook** — manage known and prepared spells.
- **Spell Slots** — interactive trackers for all levels.
- **Spell Almanac** — searchable database of 300+ spells.
- **Filtering** — filter by class, level, and school.

### 🎒 Inventory & Equipment
- **Equipment Slots** — visual management of weapons and armor.
- **Auto AC** — Armor Class calculated automatically based on gear.
- **Encumbrance** — weight tracking with status indicators.
- **Item Database** — hundreds of standard items included.

### 📔 Adventure Journal (New in v1.0)
- **Notes** — rich text notes with images and tags.
- **Quests** — track objectives, progress, and status.
- **Motivational Quotes** — daily inspiration for adventurers.

### 🎲 Tools
- **Dice Roller** — 3D physics-based dice (d4, d6, d8, d10, d12, d20).
- **Offline First** — works entirely without internet.
- **Material 3 Design** — modern, expressive, and beautiful UI.

---

## 📱 Screenshots

<div align="center">

| Character Sheet | Combat Tracker | Spells |
|:-:|:-:|:-:|
| ![Character Sheet](docs/screenshots/character_sheet.png) | ![Combat Tracker](docs/screenshots/combat.png) | ![Spells](docs/screenshots/spells.png) |

| Journal | Inventory | Dice Roller |
|:-:|:-:|:-:|
| ![Journal](docs/screenshots/journal.png) | ![Inventory](docs/screenshots/inventory.png) | ![Dice Roller](docs/screenshots/dice.png) |

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

# Generate code (Hive adapters)
flutter pub run build_runner build --delete-conflicting-outputs

# Run
flutter run
```

---

## 🗺️ Roadmap

### ✅ v1.0 (Released)
- Core character sheet
- Spell system
- Inventory & Equipment
- Combat Tracker
- Adventure Journal
- FC5 Import

### 🔮 v2.0 (Planned)
- [ ] Level Up System
- [ ] Multiclassing Support
- [ ] Cloud Sync (Google Drive)
- [ ] PDF Export
- [ ] Homebrew Content Creator

---

## 📜 License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.

---

<div align="center">

**Developed by [Qurie](https://github.com/QurieGLord)**

*May your d20 always land on a natural 20!* 🎲✨

</div>