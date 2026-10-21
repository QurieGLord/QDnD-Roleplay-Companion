> Актуальный реестр задач и совместных решений: [WORKING_VERSION_TODO.md](WORKING_VERSION_TODO.md). Ниже сохранён исторический план; его старые галочки и проценты не доказывают готовность текущей версии.

## Terminology and interface consistency

New and revised UI text follows the [QDnD glossary](DND_GLOSSARY.md).
Russian spell levels are «круги»; character and class levels remain «уровни».
Compact health labels remain HP / ОЗ by the author's preference. Review nearby
labels, filters, editors and built-in descriptions when changing a section.

# QD&D - Development Plan

## 📅 8-Session Development Roadmap

### Session Overview

| Session | Focus | Deliverable | Status |
|---------|-------|-------------|--------|
| 0 | Project Brief & Architecture | Documentation & Structure | ✅ COMPLETED |
| 1 | Foundation & Runnable App | Installable app with UI | ✅ COMPLETED |
| 2 | Data Models & FC5 Import | Character list with real data | ✅ COMPLETED |
| 3 | Character Sheet (Main View) | Full character sheet | ✅ COMPLETED |
| 4 | Spells System | Working spell system | ✅ COMPLETED |
| 5 | Character Creation Wizard | Create new characters | ✅ COMPLETED |
| 6 | Inventory & Equipment | Full inventory management | ✅ COMPLETED |
| 7 | Dice Roller & Combat Tools | Combat tools complete | ✅ COMPLETED |
| 8 | Journal, Polish & Localization | Production-ready app | 🔄 IN PROGRESS |

---

## ✅ Session 0: Project Brief & Architecture
**Status**: COMPLETED ✅
**Date**: 2025-11-06

*(See original file for details)*

---

## ✅ Session 1: Foundation & Runnable App
**Status**: COMPLETED ✅

*(See original file for details)*

---

## ✅ Session 2: Data Models & FC5 Import
**Status**: COMPLETED ✅

*(See original file for details)*

---

## ✅ Session 3: Character Sheet (Main View)
**Status**: COMPLETED ✅

*(See original file for details)*

---

## ✅ Session 4: Spells System
**Status**: COMPLETED ✅

*(See original file for details)*

---

## ✅ Session 5: Character Creation Wizard
**Status**: COMPLETED ✅

*(See original file for details)*

---

## ✅ Session 6: Inventory & Equipment
**Status**: COMPLETED ✅
**Actual Duration**: 2 days (2025-11-18 - 2025-11-19)

*(See original file for details)*

---

## ✅ Session 7: Dice Roller & Combat Tools
**Status**: COMPLETED ✅

*(See original file for details)*

---

## 🔄 Session 8: Journal, Polish & Localization
**Status**: IN PROGRESS
**Current Focus**: Localization & Final Polish

### Goals
- [ ] Adventurer's Journal (quests, notes)
- [x] Full Russian localization (UI + Data) ✅
- [x] Add 4 additional color themes (6 total implemented)
- [ ] FC5 export functionality
- [ ] Import/export backup (JSON)
- [ ] Final polish & bug fixes
- [ ] Performance optimization

### Deliverables
- [ ] Production-ready app
- [x] Full EN/RU support
- [x] 6 themes working
- [ ] Export to FC5
- [ ] Backup/restore

### Technical Tasks

#### 1. Journal Tab
```dart
class JournalTab extends StatelessWidget {
  - Quest log (checkboxes, markdown support)
  - Notes system (Google Keep style)
  - Session history (dates, locations)
  - Inspirational quotes (random, animated backgrounds)
}
```

#### 2. Localization
- [x] Integrate `flutter_localizations` and `intl`
- [x] Create `l10n.yaml` and ARB files
- [x] Implement `LocaleProvider` for language switching
- [x] Translate all UI strings (Settings, Sheet, Combat, Wizard)
- [x] Data migration script for JSON assets
- [x] Dynamic value localization (colors, units)

#### 3. Additional Themes
- [x] Implemented `AppPalettes` with QMonokai, Gruvbox, Catppuccin, etc.

#### 4. FC5 Export
```dart
class FC5Exporter {
  static String export(Character character) {
    // Convert Character → FC5 XML format
    return xmlString;
  }
}
```

#### 6. Polish & Logic Fixes
- [x] Spell Selection Logic: Added `SpellPreparationManager` to enforce prepared spell limits (Wizard/Cleric/etc).
- [x] Adaptive Spell Slots: Implemented `SpellSlotsWidget` (Icons vs Chips modes).
- [x] FC5 Import Fix: Filtered class features by `associatedClass` to prevent cross-class pollution.
- [x] Strict Feature Filtering: Implemented `getFeaturesForLevel` to ensure Paladins don't get Fighter features on Level Up.
- [x] Inventory Overhaul: Added Encumbrance bar, Attunement limits, and Swipe-to-Delete.
- [x] Item Creation: Implemented "The Forge" with live preview and visual customization.
- [x] Library Management: Created `LibraryManagerScreen` for DLC management (Import/Delete).
- [x] Data Unification: Unified SRD and User content in `ItemService`/`SpellService`.
- [x] Bilingual Support: `FC5Parser` now supports `---RU---` separator for dual-language content.
- [ ] Spell Selection in Wizard: `CharacterCreationWizard` needs a step to write chosen spells.
- [ ] Multiclass UI: `LevelUpScreen` currently assumes leveling up the *primary* class.
- [ ] Content Population: Fill `assets/data/features/` for remaining classes.

### Success Criteria
- ✅ All text in both EN and RU
- ✅ All 5+ themes work perfectly
- ✅ Export "Кюри" → import to Fight Club 5 → no data loss
- ✅ Backup/restore preserves all data
- ✅ No performance issues (smooth 60 FPS)
- ✅ App size < 50 MB
- ✅ Zero critical bugs

---

## 🎯 Definition of Done (Overall Project)

### Functionality
- [x] Character creation wizard (all 13 classes)
- [x] Character sheet (full stat display)
- [x] Spell management (standard + Pact Magic)
- [x] Inventory & equipment
- [x] Dice roller & combat tools
- [ ] Adventurer's journal
- [ ] FC5 import/export (Import done, Export pending)
- [ ] Backup/restore

### Quality
- [x] Zero critical bugs
- [x] 60 FPS animations
- [x] Offline-first (no network required)
- [x] Full localization (EN + RU)
- [x] 5+ color themes
- [x] Accessible (screen reader support)

### Testing
- [x] Unit tests (core calculations)
- [x] Widget tests (UI components)
- [x] Integration tests (workflows)
- [x] Manual testing on Android/iOS

### Documentation
- [x] User guide (in-app)
- [x] Developer documentation
- [x] API reference
- [x] Contribution guidelines

---

**Last Updated**: Session 8 - 2025-12-01
**Current Session**: 8 (Polish & Localization)
**Overall Progress**: ~90%