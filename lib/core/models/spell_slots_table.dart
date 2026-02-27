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
      case 'pact_magic':
        return getPactSlots(level);

      default:
        return [];
    }
  }

  /// Calculates Pact Magic slots for Warlock.
  /// Warlocks have a specific number of slots, which are always at the highest available level (up to 5th).
  static List<int> getPactSlots(int level) {
    if (level < 1 || level > 20) return [];

    // Точный расчет УРОВНЯ ячейки магии договора
    int pactSlotLevel;
    if (level <= 2) {
      pactSlotLevel = 1;
    } else if (level <= 4) {
      pactSlotLevel = 2;
    } else if (level <= 6) {
      pactSlotLevel = 3;
    } else if (level <= 8) {
      pactSlotLevel = 4;
    } else {
      pactSlotLevel = 5; // Уровень ячейки НИКОГДА не превышает 5
    }

    // Точный расчет КОЛИЧЕСТВА ячеек магии договора
    int maxPactSlots;
    if (level == 1) {
      maxPactSlots = 1;
    } else if (level >= 2 && level <= 10) {
      maxPactSlots = 2;
    } else if (level >= 11 && level <= 16) {
      maxPactSlots = 3;
    } else {
      maxPactSlots = 4; // На 20 уровне их ровно 4
    }

    // Create a list representing slots.
    // The list size must be exactly 'pactSlotLevel' to represent that highest level is available.
    List<int> slots = List.filled(pactSlotLevel, 0);
    if (pactSlotLevel > 0) {
      slots[pactSlotLevel - 1] = maxPactSlots;
    }

    return slots;
  }

  /// Returns the maximum spell level a character can learn/cast.
  static int getMaxSlotLevel(int characterLevel, String casterType) {
    final slots = getSlots(characterLevel, casterType);
    if (slots.isEmpty) return 0;
    return slots.length;
  }
}
