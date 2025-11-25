class SpellSlotsTable {
  // Standard 5e Spell Slot Progression
  static const List<List<int>> _fullCasterSlots = [
    [2], // Level 1
    [3], // Level 2
    [4, 2], // Level 3
    [4, 3], // Level 4
    [4, 3, 2], // Level 5
    [4, 3, 3], // Level 6
    [4, 3, 3, 1], // Level 7
    [4, 3, 3, 2], // Level 8
    [4, 3, 3, 3, 1], // Level 9
    [4, 3, 3, 3, 2], // Level 10
    [4, 3, 3, 3, 2, 1], // Level 11
    [4, 3, 3, 3, 2, 1], // Level 12
    [4, 3, 3, 3, 2, 1, 1], // Level 13
    [4, 3, 3, 3, 2, 1, 1], // Level 14
    [4, 3, 3, 3, 2, 1, 1, 1], // Level 15
    [4, 3, 3, 3, 2, 1, 1, 1], // Level 16
    [4, 3, 3, 3, 2, 1, 1, 1, 1], // Level 17
    [4, 3, 3, 3, 3, 1, 1, 1, 1], // Level 18
    [4, 3, 3, 3, 3, 2, 1, 1, 1], // Level 19
    [4, 3, 3, 3, 3, 2, 2, 1, 1], // Level 20
  ];

  // Warlock progression is tricky because slots upgrade level.
  // TODO: Handle Warlock pact magic specifically if needed.

  /// Get spell slots for a given class level and caster type
  static List<int> getSlots(int level, String casterType) {
    if (level < 1 || level > 20) return [];

    switch (casterType.toLowerCase()) {
      case 'full':
        return _fullCasterSlots[level - 1];
      
      case 'half':
        // Paladins and Rangers start at level 2
        if (level < 2) return [];
        
        // Formula: ceil(level / 2) equivalent in full caster table
        final mappedLevel = (level / 2).ceil();
        return _fullCasterSlots[mappedLevel - 1];

      case 'third':
        // Eldritch Knight / Arcane Trickster
        // Start at level 3
        if (level < 3) return [];
        final mappedLevel = (level / 3).ceil();
        return _fullCasterSlots[mappedLevel - 1];
        
      case 'pact':
        // Simplified Warlock
         // TODO: Implement proper warlock logic
        return [];

      default:
        return [];
    }
  }
}