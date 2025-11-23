# QD&D - Development Plan

## 📅 8-Session Development Roadmap

### Session Overview

| Session | Focus | Deliverable | Status |
|---------|-------|-------------|--------|
| 0 | Project Brief & Architecture | Documentation & Structure | ✅ COMPLETED |
| 1 | Foundation & Runnable App | Installable app with UI | 🔜 NEXT |
| 2 | Data Models & FC5 Import | Character list with real data | ⏳ PLANNED |
| 3 | Character Sheet (Main View) | Full character sheet | ⏳ PLANNED |
| 4 | Spells System | Working spell system | ⏳ PLANNED |
| 5 | Character Creation Wizard | Create new characters | ⏳ PLANNED |
| 6 | Inventory & Equipment | Full inventory management | ⏳ PLANNED |
| 7 | Dice Roller & Combat Tools | Combat tools complete | ⏳ PLANNED |
| 8 | Journal, Polish & Localization | Production-ready app | ⏳ PLANNED |

---

## ✅ Session 0: Project Brief & Architecture
**Status**: COMPLETED ✅
**Date**: 2025-11-06

### Goals
- [x] Document complete project scope
- [x] Design universal feature architecture
- [x] Create reference documentation
- [x] Set up project tracking

### Deliverables
- [x] `PROJECT_BRIEF.md` - Complete project overview
- [x] `docs/ARCHITECTURE.md` - Detailed architectural design
- [x] `docs/DEVELOPMENT_PLAN.md` - 8-session roadmap
- [x] Directory structure created
- [x] Reference assets added (`pal_example.xml`, `icon.svg`)
- [x] Updated `CLAUDE.md` with project context

### Key Decisions Made
- **Universal Feature System**: All class mechanics fit into `CharacterFeature` base model
- **Data-Driven Architecture**: JSON for all content, zero code changes for new classes
- **Bilingual from Day 1**: EN/RU support baked into all models
- **Offline-First**: Hive for local storage, no network dependencies
- **Material 3 Expressive**: Physics-based animations throughout

### Architecture Validation
- ✅ Can represent all 13 D&D classes
- ✅ Resource pools extensible (Ki, Sorcery Points, etc.)
- ✅ Spell system handles standard + Pact Magic
- ✅ FC5 import/export planned
- ✅ Modifier system for all stat changes

---

## 🔜 Session 1: Foundation & Runnable App
**Status**: NEXT SESSION
**Estimated Duration**: 2-3 hours

### Goals
- [ ] Set up Flutter environment (verify Gradle, Java SDK)
- [ ] Initialize Flutter project with proper structure
- [ ] Implement Material 3 Expressive theme system
- [ ] Create splash screen with animated logo
- [ ] Build empty character list screen
- [ ] Implement basic settings screen
- [ ] Set up app navigation (routes)

### Deliverables
- [ ] **Runnable app** that installs on Android/iOS
- [ ] Beautiful splash screen (1.5s animation)
- [ ] Empty character list with "No characters yet" state
- [ ] Settings screen with theme selector (Monokai theme working)
- [ ] Smooth navigation between screens
- [ ] App icon configured

### Technical Tasks

#### 1. Environment Setup
```bash
# Verify Flutter installation
flutter doctor -v

# Check Java/Gradle compatibility
java --version
gradle --version

# Create Flutter project
flutter create qd_n_d --org com.qdrpg --platforms android,ios
```

#### 2. Project Structure
```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   └── router.dart
├── screens/
│   ├── splash/
│   │   └── splash_screen.dart
│   ├── character_list/
│   │   └── character_list_screen.dart
│   └── settings/
│       └── settings_screen.dart
├── theme/
│   ├── app_theme.dart
│   └── color_schemes/
│       └── monokai.dart
└── widgets/
    └── empty_state.dart
```

#### 3. Dependencies to Add
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # State Management
  provider: ^6.1.0

  # UI
  animations: ^2.0.11
  flutter_svg: ^2.0.10

  # Storage (prepare for Session 2)
  hive: ^2.2.3
  hive_flutter: ^1.1.0

  # Utilities
  path_provider: ^2.1.2
```

#### 4. Theme Implementation
- Monokai color scheme with Material 3
- Custom color seeds
- Dark mode support
- Animation curves defined

#### 5. Screens to Build
**Splash Screen**:
- SVG logo from `assets/images/icon.svg`
- Fade + scale animation (300ms delay, 800ms duration)
- "Your Roleplay Companion" subtitle
- Auto-navigate to character list after 1.5s

**Character List Screen**:
- App bar with "QD&D" title
- Settings icon button (top right)
- Empty state widget:
  - Icon (dice or character sheet)
  - "No characters yet"
  - "Tap + to create your first character"
- FloatingActionButton (+) - placeholder action

**Settings Screen**:
- Theme selector (radio buttons):
  - [x] Monokai (default)
  - [ ] Gruvbox (disabled for Session 1)
  - [ ] Catppuccin (disabled)
  - [ ] Everforest Light (disabled)
  - [ ] Everforest Dark (disabled)
- Language toggle (disabled for Session 1)
- Dark mode toggle
- About section (version, credits)

### Success Criteria
- ✅ App builds without errors
- ✅ Installs on Android device/emulator
- ✅ Splash screen plays smoothly
- ✅ Navigation works (list ↔ settings)
- ✅ Monokai theme applied correctly
- ✅ Dark mode toggles successfully
- ✅ No console errors or warnings

### Notes for Session 1
- **Focus on UI/UX**, not functionality yet
- Use placeholder text/icons where needed
- Ensure smooth animations (60 FPS)
- Test on physical device if possible
- Keep codebase clean and documented

---

## ⏳ Session 2: Data Models & FC5 Import
**Status**: PLANNED
**Estimated Duration**: 3-4 hours

### Goals
- [ ] Implement all core data models (Character, AbilityScores, etc.)
- [ ] Set up Hive storage with type adapters
- [ ] Build FC5 XML parser
- [ ] Import "Кюри" character from `pal_example.xml`
- [ ] Display imported character in list
- [ ] Character detail view (basic)

### Deliverables
- [ ] Complete data models matching `ARCHITECTURE.md`
- [ ] Hive database initialized
- [ ] FC5 parser successfully imports Paladin
- [ ] Character list shows "Кюри" with portrait
- [ ] Tap character to see basic details

### Technical Tasks

#### 1. Data Models to Implement
```dart
// Core models
- Character
- AbilityScores
- ClassLevel
- Proficiencies
- Inventory (basic)

// Hive adapters for each model
- @HiveType(typeId: 0) class Character
- @HiveType(typeId: 1) class AbilityScores
// etc.
```

#### 2. FC5 Parser
```dart
class FC5Parser {
  static Character parse(String xmlContent);

  // Extract:
  - Name, level, class, race
  - Ability scores
  - HP, AC, initiative
  - Skills, saving throws
  - Equipment (basic)
}
```

#### 3. Storage Service
```dart
class HiveService {
  Future<void> init();
  Future<void> saveCharacter(Character character);
  List<Character> getAllCharacters();
  Future<void> deleteCharacter(String id);
}
```

#### 4. Character List UI
- Character cards with:
  - Portrait (placeholder if none)
  - Name
  - Class & level
  - Race
  - HP bar
- Tap to view details
- Long-press menu (delete)

### Success Criteria
- ✅ "Кюри" character imported from XML
- ✅ Data persists across app restarts
- ✅ Character list displays real data
- ✅ All ability scores correct
- ✅ HP, AC, initiative calculated correctly

---

## ⏳ Session 3: Character Sheet (Main View)
**Status**: PLANNED
**Estimated Duration**: 3-4 hours

### Goals
- [ ] Expandable character card (hero animation)
- [ ] Animated bottom navigation (4 tabs)
- [ ] Overview tab with full stat block
- [ ] Ability score checks (tap to roll d20)
- [ ] Skills display with proficiency indicators
- [ ] Features/traits list (read-only for now)

### Deliverables
- [ ] Beautiful, animated character sheet
- [ ] 4 tabs: Overview, Spells, Inventory, Journal
- [ ] Tap-to-roll ability checks
- [ ] Smooth tab transitions

### Technical Tasks

#### 1. Character Sheet Screen
```dart
class CharacterSheetScreen extends StatelessWidget {
  - Expandable hero card (character portrait + name + class)
  - Animated bottom nav bar (slides up on scroll)
  - TabBarView for 4 sections
}
```

#### 2. Overview Tab
- **Top Section**: HP, AC, Initiative, Speed
- **Ability Scores**: 6 cards (STR, DEX, CON, INT, WIS, CHA)
  - Show score + modifier
  - Tap to roll d20 + modifier
- **Saving Throws**: List with proficiency indicators
- **Skills**: List with proficiency/expertise indicators
- **Features**: Collapsible cards

#### 3. Placeholders for Other Tabs
- Spells: "Coming in Session 4"
- Inventory: "Coming in Session 6"
- Journal: "Coming in Session 8"

### Success Criteria
- ✅ Hero animation when opening character
- ✅ Bottom nav slides up/down smoothly
- ✅ All stats display correctly
- ✅ Ability check rolls work
- ✅ Proficiency bonuses calculated correctly

---

## ⏳ Session 4: Spells System
**Status**: PLANNED
**Estimated Duration**: 3-4 hours

### Goals
- [ ] Spell data models (Spell, SpellcastingInfo)
- [ ] Load spell database from JSON
- [ ] Spell slot tracker UI
- [ ] Prepared vs known spells
- [ ] Spell detail modal
- [ ] Basic Spell Almanac (searchable list)

### Deliverables
- [ ] Working spell system for Paladins (and other casters)
- [ ] Visual spell slot tracker (circles, checkboxes, etc.)
- [ ] Cast spell (consume slot)
- [ ] Spell search/filter

### Technical Tasks

#### 1. Spell Models
```dart
class Spell {
  String id, name, description;
  int level;
  School school;
  CastingTime castingTime;
  Range range;
  Duration duration;
  bool concentration, ritual;
  // ... (see ARCHITECTURE.md)
}

class SpellcastingInfo {
  SpellcastingType type;
  AbilityType spellcastingAbility;
  Map<int, int> spellSlots;
  Map<int, int> slotsUsed;
  List<String> preparedSpells;
  // ...
}
```

#### 2. JSON Data
- Load `assets/data/spells/*.json`
- Paladin spell list
- At least 20 spells for testing

#### 3. Spells Tab UI
- **Top**: Spell slot tracker (1st-5th level for Paladin)
- **Prepared Spells**: List of currently prepared spells
- **Spell Almanac Button**: Opens searchable spell database
- **Spell Cards**: Tap to see details, long-press to cast

#### 4. Spell Slot Tracker
- Visual representation (circles or boxes)
- Filled = used, empty = available
- Tap to consume/restore

### Success Criteria
- ✅ Spell slots display correctly for Кюри's level
- ✅ Casting spell consumes slot
- ✅ Spell details show all info (range, duration, etc.)
- ✅ Spell Almanac filters by class/level
- ✅ Data persists (used slots saved)

---

## ⏳ Session 5: Character Creation Wizard
**Status**: PLANNED
**Estimated Duration**: 4-5 hours

### Goals
- [ ] Multi-step creation wizard
- [ ] Step 1: Basic Info (name, portrait)
- [ ] Step 2: Race & Class selection
- [ ] Step 3: Ability score allocation (standard array, point buy, roll)
- [ ] Step 4: Skills & proficiencies
- [ ] Step 5: Starting equipment
- [ ] Auto-populate features based on choices

### Deliverables
- [ ] Create new characters manually
- [ ] Validation at each step
- [ ] Preview mode before saving
- [ ] Templates (e.g., "Quick Fighter")

### Technical Tasks

#### 1. Wizard UI
```dart
class CharacterCreationWizard extends StatefulWidget {
  - Stepper or bottom navigation
  - "Next" / "Back" buttons
  - Progress indicator
  - Validation before advancing
}
```

#### 2. JSON Data to Load
- `assets/data/races/*.json` (Human, Elf, Dwarf, etc.)
- `assets/data/classes/*.json` (all 13 classes)
- `assets/data/backgrounds/*.json`

#### 3. Ability Score Allocation
- **Standard Array**: [15, 14, 13, 12, 10, 8] - drag to assign
- **Point Buy**: 27 points, 8-15 range
- **Roll 4d6 drop lowest**: Random generation

#### 4. Feature Auto-Population
- Based on race: add racial traits
- Based on class level 1: add starting features
- Based on background: add skill proficiencies

### Success Criteria
- ✅ Create level 1 character from scratch
- ✅ All ability scores valid
- ✅ Starting features added automatically
- ✅ Character saves to database
- ✅ Appears in character list

---

## ✅ Session 6: Inventory & Equipment
**Status**: COMPLETED
**Actual Duration**: 2 days (2025-11-18 - 2025-11-19)

### Goals
- [x] Equipment slot system (visual)
- [x] Item database (weapons, armor, consumables)
- [x] Equip/unequip items
- [x] Real-time AC calculation
- [x] Weight & encumbrance tracking
- [x] Custom item creation
- [x] Equipment package selection in character creation
- [x] Item catalog with search and filters

### Deliverables
- [x] Full inventory management
- [x] Equipment slots UI
- [x] AC updates when armor changes
- [x] Item database with search
- [x] Equipment package system (Standard/Alternative/Custom)
- [x] Item catalog dialog
- [x] Custom equipment selection

### Technical Tasks

#### 1. Inventory Models
```dart
class Inventory {
  EquipmentSlot mainHand, offHand, armor, shield;
  List<InventoryItem> backpack;
  Currency currency;

  double get totalWeight;
  int get armorClassBonus;
}

class Item {
  String id, name, description;
  ItemCategory category;
  double weight;
  int value;
  // ...
}
```

#### 2. JSON Data
- `assets/data/items/weapons/*.json`
- `assets/data/items/armor/*.json`
- `assets/data/items/consumables/*.json`

#### 3. Inventory Tab UI
- **Top**: Character silhouette with equipment slots
- **Backpack**: Scrollable list of items
- **Currency**: GP, SP, CP
- **Weight**: Current / Max (encumbrance indicator)

#### 4. AC Calculator
```dart
class ACCalculator {
  static int calculate(Character character) {
    var base = 10;
    var dexMod = character.abilityScores.dexterityModifier;
    var armorBonus = character.inventory.armorBonus;
    var shieldBonus = character.inventory.shieldBonus;
    // ... + class features (Unarmored Defense, etc.)
    return base + dexMod + armorBonus + shieldBonus;
  }
}
```

### Success Criteria
- ✅ Equip armor → AC updates immediately
- ✅ Unequip weapon → attack bonus recalculates
- ✅ Weight tracks correctly
- ✅ Custom items can be added with image upload
- ✅ Equipment packages selectable in character creation
- ✅ Item catalog searchable and filterable
- ✅ Multi-select items for custom package
- ✅ Auto-equip starting equipment

### Completed Implementation
- ✅ Item model with WeaponProperties and ArmorProperties
- ✅ ItemService for loading and managing items
- ✅ Inventory Tab with equipment slots, filters, search
- ✅ Equipment Step rewritten as StatefulWidget (990 lines)
- ✅ Item Catalog Dialog with DraggableScrollableSheet
- ✅ CharacterCreationState extended with custom equipment support
- ✅ Custom item creation dialog simplified (single-language)
- ✅ Auto-equip logic in character creation wizard

---

## ⏳ Session 7: Dice Roller & Combat Tools
**Status**: PLANNED
**Estimated Duration**: 2-3 hours

### Goals
- [ ] Physics-based dice roller modal
- [ ] Quick rolls (d20, d12, d10, d8, d6, d4, d100)
- [ ] Advantage/disadvantage
- [ ] Damage tracker (combat modal)
- [ ] Death saves interface
- [ ] Conditions tracking

### Deliverables
- [ ] Beautiful dice roller with animations
- [ ] Combat tracker modal
- [ ] Death save tracker
- [ ] Roll history

### Technical Tasks

#### 1. Dice Roller
```dart
class DiceRollerModal extends StatefulWidget {
  - AnimatedDice widget (physics simulation)
  - Quick roll buttons (d20, d12, etc.)
  - Custom roll input (2d6+3)
  - Advantage/Disadvantage toggle
  - Roll history (last 10 rolls)
}
```

#### 2. Combat Modal
```dart
class CombatTrackerModal extends StatefulWidget {
  - HP adjustment (+/- buttons, slider)
  - Temp HP input
  - Conditions checkboxes (prone, stunned, etc.)
  - Death saves (3 successes / 3 failures)
  - Initiative tracker
}
```

#### 3. Animations
- Dice roll: 800ms physics animation
- Damage flash: red screen flash
- Healing pulse: green glow

### Success Criteria
- ✅ Dice animations smooth (60 FPS)
- ✅ Advantage/disadvantage works correctly
- ✅ Damage reduces HP
- ✅ Death saves track correctly (3 strikes)
- ✅ Temp HP absorbed before real HP

---

## ⏳ Session 8: Journal, Polish & Localization
**Status**: PLANNED
**Estimated Duration**: 4-5 hours

### Goals
- [ ] Adventurer's Journal (quests, notes)
- [ ] Full Russian localization
- [ ] Add 4 additional color themes
- [ ] FC5 export functionality
- [ ] Import/export backup (JSON)
- [ ] Final polish & bug fixes
- [ ] Performance optimization

### Deliverables
- [ ] Production-ready app
- [ ] Full EN/RU support
- [ ] 5 themes working
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
```yaml
# l10n/app_en.arb
{
  "appTitle": "QD&D",
  "characterList": "Characters",
  "createCharacter": "Create Character",
  // ... (200+ strings)
}

# l10n/app_ru.arb
{
  "appTitle": "QD&D",
  "characterList": "Персонажи",
  "createCharacter": "Создать персонажа",
  // ...
}
```

#### 3. Additional Themes
- Gruvbox (light/dark)
- Catppuccin
- Everforest (light/dark)

#### 4. FC5 Export
```dart
class FC5Exporter {
  static String export(Character character) {
    // Convert Character → FC5 XML format
    return xmlString;
  }
}
```

#### 5. Backup System
```dart
class BackupService {
  Future<String> exportAllData();  // JSON
  Future<void> importBackup(String json);
}
```

### Success Criteria
- ✅ All text in both EN and RU
- ✅ All 5 themes work perfectly
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
- [x] Adventurer's journal
- [x] FC5 import/export
- [x] Backup/restore

### Quality
- [x] Zero critical bugs
- [x] 60 FPS animations
- [x] Offline-first (no network required)
- [x] Full localization (EN + RU)
- [x] 5 color themes
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

## 📊 Progress Tracking

### Metrics
- **Lines of Code**: (tracked per session)
- **Test Coverage**: Target 80%+
- **Performance**: 60 FPS on mid-range devices
- **Build Time**: < 2 minutes (debug)
- **App Size**: < 50 MB (release)

### Session Completion Checklist
After each session, verify:
- [ ] All goals achieved
- [ ] Deliverables complete
- [ ] No regressions introduced
- [ ] Code committed with clear messages
- [ ] Documentation updated
- [ ] Next session planned

---

## 🚀 Release Plan

### Alpha Release (After Session 5)
- Core character management
- FC5 import only
- English only
- Monokai theme only
- Android only

### Beta Release (After Session 7)
- Full spell/inventory systems
- Combat tools
- English + Russian
- All 5 themes
- Android + iOS

### Production Release (After Session 8)
- Complete feature set
- FC5 import/export
- Backup/restore
- Polished UI/UX
- Performance optimized
- Published to Google Play / App Store

---

## 📝 Session Notes Template

Use this template for each session:

```markdown
## Session X: [Title]
**Date**: YYYY-MM-DD
**Duration**: X hours

### Goals
- [ ] Goal 1
- [ ] Goal 2

### What Was Built
- Feature A
- Feature B

### Challenges
- Challenge 1: Solution
- Challenge 2: Solution

### Next Session Prep
- Task 1
- Task 2

### Screenshots
(Attach screenshots of UI progress)
```

---

**Last Updated**: Session 0 - 2025-11-06
**Current Session**: 0 (Planning Complete)
**Next Session**: 1 (Foundation)
**Overall Progress**: 12.5% (1/8 sessions)
