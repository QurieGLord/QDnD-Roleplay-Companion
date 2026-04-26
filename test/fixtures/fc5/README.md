# FC5 Import/Export Fixtures

Small XML fixtures for developing Fight Club 5e compatible import/export.

These files are intentionally tiny and synthetic. They model public FC5 XML
shapes observed in community tooling, but they do not bundle full rulebooks or
third-party compendiums. Use them for parser and round-trip tests.

References checked while creating these fixtures:

- https://github.com/kinkofer/FightClub5eXML
- https://github.com/kinkofer/FightClub5eXML/blob/master/Utilities/compendium.xsd
- https://github.com/ceryliae/DnDAppFiles
- https://www.dndbeyond.com/srd/
- https://open5e.com/
- https://github.com/5e-bits/5e-srd-api

## Files

- `characters/fc5_pc_minimal_paladin.xml`
  Minimal player-character export shape currently accepted by `FC5Parser`.
- `characters/fc5_pc_rich_export_shape.xml`
  Richer player-character export shape with inventory, spells, notes, and
  quest-like notes. This documents target coverage for future parser work.
- `characters/fc5_gm_players.xml`
  Game Master style wrapper with multiple `<npc>` player entries.
- `compendiums/fc5_srd_2014_minimal_compendium.xml`
  Minimal SRD-style compendium with race, class, background, feat, item, and
  spell entries in the public FC5 compendium shape.

## Current Expected Behavior

The current parser should import the minimal paladin and parse the minimal
compendium. The rich character fixture is expected to lose data today because
inventory, notes, selected spells, currency, and character-local features are
not yet mapped by `parseCharacter`.
