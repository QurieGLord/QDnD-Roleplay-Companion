# QD&D - Quick D&D: Your Roleplay Companion

## 🎯 Project Vision

**QD&D** is a comprehensive D&D 5th Edition companion mobile application built with Flutter for Android/iOS. The app follows an **architecture-first, data-driven approach** to support ALL D&D 5e mechanics from ALL 13 official classes through a universal, extensible system.

### Core Philosophy

> **Build once, populate infinitely**
> The application must be 100% feature-complete architecturally, requiring ONLY data population (JSON files), NOT code changes, to add new content.

---

## 🎲 Target Audience

- D&D 5e players (all experience levels)
- Dungeon Masters managing NPCs
- Users of Fight Club 5 looking for a modern alternative
- Players wanting offline-first, privacy-focused character management

---

## 💡 Key Features

### 1. Universal Character System
- Support for all 13 official classes with unique mechanics
- Multiclassing support
- Custom/homebrew content extensibility
- Real-time stat calculation

### 2. Fight Club 5 Compatibility
- Full bidirectional import/export
- Reference character: "Кюри" (Paladin) from `assets/data/fc5_examples/pal_example.xml`
- No data loss during conversion

### 3. Complete D&D 5e Coverage

**Classes Supported:**
- Barbarian (Rage, Reckless Attack, Primal Paths)
- Bard (Bardic Inspiration, Jack of All Trades, Magical Secrets)
- Cleric (Channel Divinity, Domain spells)
- Druid (Wild Shape, Circle spells)
- Fighter (Action Surge, Second Wind, Battle Master Maneuvers)
- Monk (Ki Points, Martial Arts, Unarmored Defense)
- Paladin (Lay on Hands, Divine Smite, Oath spells)
- Ranger (Favored Enemy, Hunter's Mark, Beast Master)
- Rogue (Sneak Attack, Cunning Action, Arcane Trickster)
- Sorcerer (Sorcery Points, Metamagic, Draconic Bloodline)
- Warlock (Pact Magic, Invocations, Pact Boon, Hex)
- Wizard (Spellbook, Arcane Recovery, Ritual Casting)
- Artificer (Infusions, Spell-Storing Item, Homunculus)

### 4. Spell Management
- Standard spell slots (1st-9th level)
- Pact Magic slots (Warlock-specific)
- Prepared vs known spells
- Ritual casting
- Spell Almanac (searchable database)
- Sorcery Points & Metamagic integration

### 5. Inventory & Equipment
- Visual equipment slots
- Custom items with image upload
- Real-time AC/stat calculation
- Weight & encumbrance tracking
- Item categories (weapons, armor, consumables, tools, etc.)

### 6. Adventurer's Journal
- Quest log with checkboxes
- Notes system (Google Keep style)
- Session history
- Inspirational quotes with animated backgrounds

### 7. Combat Tools
- Physics-based dice roller
- Damage & healing tracker
- Conditions management
- Death saves
- Advantage/disadvantage
- Initiative tracker

### 8. Customization
- 5 color themes: Monokai (default), Gruvbox, Catppuccin, Everforest (light/dark)
- Full localization: English + Russian
- Light/dark mode
- Custom homebrew content support

---

## 🏗️ Technical Architecture

### Tech Stack
- **Framework**: Flutter 3.24.x
- **Language**: Dart 3.5.x
- **Design System**: Material 3 Expressive
- **Local Storage**: Hive (NoSQL, offline-first)
- **State Management**: Provider / Riverpod
- **Platform**: Android 7.0+ / iOS 12.0+

### Design Principles

**1. Architecture-First**
- Universal resource system fits ALL class mechanics
- No hardcoded class-specific logic in UI
- Every system extensible by design

**2. Data-Driven**
- All content in JSON format
- Bilingual from day 1 (EN/RU)
- Content changes never require code changes

**3. Offline-First**
- No authentication required
- All data stored locally
- No network dependencies
- Import/export for backups

**4. Material 3 Expressive**
- Physics-based animations
- Tactile feedback
- Smooth transitions
- Dynamic color theming

---

## 📐 Universal Feature System

Every class ability, racial trait, feat, or item effect is represented by:

```dart
abstract class CharacterFeature {
  // Identity
  String id;
  Map<String, String> localizedName;    // EN/RU
  Map<String, String> localizedDescription;
  FeatureType type;                      // passive, action, toggle, resource
  SourceType source;                     // Class, Subclass, Race, Feat, Item

  // Activation
  List<ActivationTrigger> triggers;      // When does it activate?
  ActionType? actionType;                // Action, Bonus Action, Reaction, Free

  // Resource Management
  ResourceCost? cost;                    // What does it consume?
  RecoveryType recovery;                 // Short rest, long rest, etc.

  // Effects
  List<CharacterModifier> modifiers;     // What does it change?
  List<ConditionalEffect> conditionals;  // Context-dependent effects
}
```

### Resource Pool Types
- Spell slots (standard, 1-9th level)
- Pact Magic slots (Warlock)
- Sorcery Points
- Ki Points
- Superiority Dice
- Bardic Inspiration
- Lay on Hands pool
- Rage uses
- Wild Shape uses
- Channel Divinity
- Action Surge
- Infusion slots
- Custom/homebrew resources

### Recovery Types
- Short rest
- Long rest
- Per turn
- Per minute
- Recharge on roll (5-6)
- Dawn/dusk
- On hit
- On kill
- Custom triggers

---

## 📱 Application Flow

### Navigation Structure
```
Splash Screen (1.5s)
    ↓
Character List (Main Screen)
    ↓ (tap character)
Character Sheet
    ├─ Tab: Overview
    ├─ Tab: Spells
    ├─ Tab: Inventory
    └─ Tab: Journal

Floating Actions:
- Dice Roller (modal)
- Combat Tracker (modal)
- Settings (route)
- Create Character (wizard)
```

### Main Screens

**0. Splash Screen**
- Logo animation (fade + scale)
- Tagline: "Your Roleplay Companion"
- 1.5 second duration

**1. Character List**
- Grid/list of character cards
- Empty state with tutorial
- FAB (+) for new character
- Long-press for options (edit, duplicate, delete)
- Import FC5 button

**2. Character Creation Wizard**
- Multi-step bottom nav
- Steps:
  1. Basic Info (name, portrait, level)
  2. Race & Class (with subclass)
  3. Abilities & Skills
  4. Spells & Features (auto-populated)
  5. Equipment (starting gear)
- Validation at each step
- Preview mode

**3. Character Sheet (Main View)**
- Expandable hero card
- Animated bottom navigation
- Four tabs (swipeable):
  - **Overview**: Stats, abilities, features, actions
  - **Spells**: Spell slots, prepared spells, Spell Almanac
  - **Inventory**: Equipment, items, weight
  - **Journal**: Quests, notes, history

**4. Dice Roller**
- Modal with physics animation
- Quick rolls (d20, d12, d10, d8, d6, d4, d100)
- Custom rolls with modifiers
- Advantage/disadvantage toggle
- History of recent rolls

**5. Combat Tracker**
- Damage/healing input
- Current HP display
- Temp HP management
- Conditions tracking
- Death saves interface

**6. Settings**
- Theme selector (5 themes)
- Language toggle (EN/RU)
- Light/dark mode
- Data management (backup/restore)
- About & credits

---

## 📊 Data Structure

### Directory Layout
```
assets/data/
├── classes/
│   ├── barbarian.json
│   ├── bard.json
│   ├── cleric.json
│   ├── druid.json
│   ├── fighter.json
│   ├── monk.json
│   ├── paladin.json
│   ├── ranger.json
│   ├── rogue.json
│   ├── sorcerer.json
│   ├── warlock.json
│   ├── wizard.json
│   └── artificer.json
├── subclasses/
│   ├── oath_of_conquest.json
│   ├── circle_of_the_moon.json
│   ├── battle_master.json
│   └── ... (50+ subclasses)
├── races/
│   ├── human.json
│   ├── elf.json
│   ├── dwarf.json
│   └── ... (all PHB + XGE + TCoE races)
├── spells/
│   ├── fireball.json
│   ├── cure_wounds.json
│   ├── eldritch_blast.json
│   └── ... (all 500+ spells)
├── items/
│   ├── weapons/
│   ├── armor/
│   ├── consumables/
│   └── magic_items/
├── backgrounds/
│   └── ... (13 backgrounds)
├── feats/
│   └── ... (all PHB feats)
└── fc5_examples/
    └── pal_example.xml  (reference Paladin "Кюри")
```

### JSON Format Example

```json
{
  "id": "paladin",
  "name": {
    "en": "Paladin",
    "ru": "Паладин"
  },
  "description": {
    "en": "A holy warrior bound to a sacred oath",
    "ru": "Святой воин, связанный священной клятвой"
  },
  "hitDie": 10,
  "primaryAbility": "strength",
  "savingThrows": ["wisdom", "charisma"],
  "proficiencies": {
    "armor": ["light", "medium", "heavy", "shields"],
    "weapons": ["simple", "martial"],
    "tools": []
  },
  "spellcasting": {
    "type": "standard",
    "ability": "charisma",
    "preparedSpells": true,
    "ritualCasting": false
  },
  "features": [
    {
      "level": 1,
      "featureId": "divine_sense"
    },
    {
      "level": 1,
      "featureId": "lay_on_hands"
    },
    {
      "level": 2,
      "featureId": "divine_smite"
    }
    // ... more features
  ]
}
```

---

## 🎨 Design System

### Color Themes

**1. Monokai (Default)**
- Primary: `#F92672` (pastel pink)
- Background (dark): `#272822`
- Background (light): `#F8F8F2`
- Surface: `#3E3D32`
- Accent colors: `#A6E22E`, `#66D9EF`, `#FD971F`

**2. Gruvbox**
- Primary: `#FB4934` (red)
- Background (dark): `#282828`
- Accent colors: `#B8BB26`, `#FABD2F`, `#83A598`

**3. Catppuccin**
- Primary: `#F5C2E7` (pink)
- Background (dark): `#1E1E2E`
- Accent colors: `#89B4FA`, `#A6E3A1`, `#FAB387`

**4. Everforest (Light)**
- Primary: `#E67E80` (red)
- Background: `#FDF6E3`
- Accent colors: `#A7C080`, `#DBBC7F`, `#7FBBB3`

**5. Everforest (Dark)**
- Primary: `#E67E80` (red)
- Background: `#2B3339`
- Accent colors: `#A7C080`, `#DBBC7F`, `#7FBBB3`

### Animation Guidelines

- Page transitions: 300ms easeInOut
- Card expansions: 400ms spring curve
- Dice rolls: 800ms physics simulation
- Button feedback: 100ms haptic + visual
- List scrolling: iOS-style momentum

---

## ✅ Success Criteria

The architecture is considered successful if:

1. ✅ **Adding Artificer with Infusions** requires 0 code changes, only JSON
2. ✅ **Warlock's Pact Magic** displays correctly with existing spell UI
3. ✅ **Monk's Ki Points** appear like any other resource pool
4. ✅ **Sorcerer's Metamagic** options show up automatically
5. ✅ **Battle Master Maneuvers** integrate seamlessly
6. ✅ **Custom homebrew classes** can be added via JSON
7. ✅ **FC5 import/export** works bidirectionally without data loss
8. ✅ **Both languages** fully supported (no hardcoded strings)
9. ✅ **All 13 classes** function with their unique mechanics
10. ✅ **App runs offline** with full functionality

---

## 📅 Development Timeline

**8 Sessions Total**

### Session 0: Project Brief ✅ (Current)
- Document scope and architecture
- Create reference files
- Set up tracking

### Session 1: Foundation
- Environment setup
- Flutter project initialization
- Material 3 theme implementation
- Splash screen + empty character list
- **Deliverable**: Installable app with UI

### Session 2: Data Models & FC5 Import
- Complete data models
- Hive storage setup
- FC5 XML parser
- Import "Кюри" character
- **Deliverable**: Character list with real data

### Session 3: Character Sheet
- Main character view
- Animated navigation
- Stat displays with calculations
- **Deliverable**: Full character sheet

### Session 4: Spells System
- Spell slot management
- Prepared/known spells
- Spell Almanac
- **Deliverable**: Working spell system

### Session 5: Character Creation
- Multi-step wizard
- Race/class/subclass selection
- Ability scores & skills
- **Deliverable**: Create new characters

### Session 6: Inventory & Equipment
- Equipment slots
- Item database
- AC/stat calculations
- **Deliverable**: Full inventory system

### Session 7: Dice & Combat Tools
- Physics-based dice roller
- Combat tracker
- Death saves
- **Deliverable**: Combat tools complete

### Session 8: Polish & Release
- Journal system
- Full localization
- Additional themes
- Final testing
- **Deliverable**: Production-ready app

---

## 🚨 Critical Constraints

1. **No Mock Data**: Use real imported character from `pal_example.xml`
2. **Architecture First**: Design for ALL 13 classes before coding UI
3. **Bilingual from Day 1**: All strings in EN + RU
4. **Extensibility**: Every system must support homebrew content
5. **Offline-First**: No network calls, everything local
6. **Material 3 Expressive**: Physics-based animations throughout
7. **Code Changes = Architecture Failure**: Adding new content should only require JSON

---

## 📚 Reference Character

**"Кюри" - Paladin (from FC5)**
- File: `assets/data/fc5_examples/pal_example.xml`
- Class: Paladin (Oath of Conquest)
- Level: [TBD - from XML]
- Primary use: Testing FC5 import and validating architecture

---

## 🎯 MVP Definition

**Minimum Viable Product includes:**
- ✅ Character list with create/edit/delete
- ✅ FC5 import for Paladins
- ✅ Character sheet with all stats
- ✅ Spell management (standard casting)
- ✅ Basic inventory
- ✅ Dice roller
- ✅ English language only (Russian in full release)
- ✅ Monokai theme only (others in full release)

**Full Release adds:**
- ✅ Character creation wizard
- ✅ All 13 classes with unique mechanics
- ✅ FC5 export
- ✅ Journal system
- ✅ Full Russian localization
- ✅ 4 additional themes
- ✅ Combat tracker

---

## 📞 Contact & Resources

- **Project Directory**: `/home/qurie/Dev/Flutter/qd_n_d`
- **Documentation**: `/docs/`
- **Data Assets**: `/assets/data/`
- **Reference Files**: See `docs/ARCHITECTURE.md`, `docs/DEVELOPMENT_PLAN.md`

---

**Last Updated**: Session 0 - 2025-11-06
**Status**: Planning Complete, Ready for Session 1
