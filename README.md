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
- **Adventure Journal:** Rich text notes and quest tracking.
- **Offline First:** 100% functional without internet.

---

## 🛠️ Architecture

QD&D is built on a **Data-Driven Architecture**. This means you can add new content without writing code!

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

# Generate code (Hive adapters)
flutter pub run build_runner build --delete-conflicting-outputs

# Run
flutter run
```

---

## 🗺️ Roadmap

### ✅ v1.2 (Visuals & Themes)
- 6 Color Themes (QMonokai, Gruvbox, etc.)
- Redesigned Combat Tracker & Dice Roller
- Complete Paladin Class
- Level Up Wizard

### 🔮 v2.0 (Planned)
- [ ] Full Content Population (All Classes/Races)
- [ ] Multiclassing UI (Add Class)
- [ ] Cloud Sync (Google Drive)
- [ ] PDF Export

---

## 📜 License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.

---

<div align="center">

**Developed by [Qurie](https://github.com/QurieGLord)**

*May your d20 always land on a natural 20!* 🎲✨

</div>