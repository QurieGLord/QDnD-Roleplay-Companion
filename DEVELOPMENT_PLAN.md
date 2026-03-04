# Development Plan

## Completed Milestones

### Phase 1: Foundation (v0.1 - v0.10)
- [x] Basic Character Sheet (Stats, Skills, Saves)
- [x] Spellbook & Spell Slots
- [x] Combat Tracker (Initiative, HP, Conditions)
- [x] Inventory Management
- [x] Dice Roller
- [x] Localization (EN/RU)

### Phase 2: Content Management (v0.11 - v0.12)
- [x] "The Forge" - Custom Item Creator
- [x] Library Manager - XML Import (FC5)
- [x] Unified Database (Built-in + Homebrew)
- [x] Bilingual Support in Imports

### Phase 3: Class Mechanics & Refinement (v0.13.0) - CURRENT
- [x] **UI/UX & Architecture Overhauls:**
    - [x] Replaced `spellstab` with `abilitiestab` featuring dynamic content rendering for all classes.
    - [x] Major improvements to Character Creation and Level-Up wizards.
    - [x] **Data-Driven Approach:** Moved aggressively towards JSON-driven logic for skills, abilities, and expertise aggregation.
- [x] **Class Polish (Round 1):**
    - [x] Barbarian, Bard, Cleric, Paladin (Completed primary UI polish, data structure changes, data validation, and gameplay flow testing).
    - [x] Implemented dynamic rendering of features through `class_widgets` directory.
- [x] **Improved FC5 Import & Logic:**
    - [x] Fix parsing of bilingual subclass names (`name_ru` fallback).
    - [x] Normalize Class IDs for correct spell linking.
    - [x] Spell eligibility logic (ID based).
    - [x] Localization key fallback patches.

## Next Steps (v0.14+)

### Complete Core Classes
- [ ] **Remaining 8 Classes:** Complete primary UI polish, logic integration, and data structuring for the rest of the SRD classes (including Druid Wild Shape stat blocks).

### Architecture & Mechanics
- [ ] **Multiclassing Architecture:** Prepare data structures, state management, and UI to support selecting multiple classes, aggregating spell slots, and combining features.
- [ ] **Rest Mechanics:** Short/Long rest automation (recovering resources).

### Export & Sync
- [ ] **PDF Export:** Generate printable character sheets.
- [ ] **Cloud Sync:** Google Drive / iCloud backup.

### DM Tools (Future)
- [ ] Encounter Builder
- [ ] Monster Manual Browser
