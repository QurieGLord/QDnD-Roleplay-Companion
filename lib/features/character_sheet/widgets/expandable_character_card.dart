import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/models/character.dart';
import '../../character_level_up/level_up_screen.dart';

class ExpandableCharacterCard extends StatefulWidget {
  final Character character;
  final bool isExpanded;
  final VoidCallback onDicePressed;
  final ValueChanged<bool>? onDetailsToggled;

  ExpandableCharacterCard({
    super.key,
    required this.character,
    required this.isExpanded,
    required this.onDicePressed,
    this.onDetailsToggled,
  });

  @override
  State<ExpandableCharacterCard> createState() => _ExpandableCharacterCardState();
}

class _ExpandableCharacterCardState extends State<ExpandableCharacterCard> {
  bool _showDetails = false;

  void _openLevelUpWizard() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LevelUpScreen(character: widget.character),
      ),
    );

    if (result == true) {
      setState(() {
        // Refresh UI to show new level
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasPersonalityData = widget.character.personalityTraits != null ||
        widget.character.ideals != null ||
        widget.character.bonds != null ||
        widget.character.flaws != null ||
        widget.character.backstory != null ||
        widget.character.age != null;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              // Main content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Avatar with custom image or icon
                    Hero(
                      tag: 'character-avatar-${widget.character.id}',
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: widget.character.avatarPath == null
                              ? colorScheme.surface
                              : null,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: widget.character.avatarPath != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(
                                  File(widget.character.avatarPath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      _getClassIcon(widget.character.characterClass),
                                      size: 40,
                                      color: colorScheme.onSurface,
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                _getClassIcon(widget.character.characterClass),
                                size: 40,
                                color: colorScheme.onSurface,
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Info
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 48.0), // Avoid overlap with dice button
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.character.name,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            
                            // Level Up Trigger
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: Material(
                                color: colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(12),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () {
                                    print("🔧 Level Up Tapped");
                                    _openLevelUpWizard();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.keyboard_double_arrow_up,
                                          size: 20,
                                          color: colorScheme.onTertiaryContainer,
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'LEVEL ${widget.character.level}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: colorScheme.onTertiaryContainer,
                                                fontSize: 12,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            Text(
                                              'TAP TO UPGRADE',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: colorScheme.onTertiaryContainer.withOpacity(0.7),
                                                fontSize: 9,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            Text(
                              widget.character.characterClass,
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (widget.character.subclass != null)
                              Text(
                                widget.character.subclass!,
                                style: TextStyle(
                                  color: colorScheme.onPrimaryContainer.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Dice button (top-right)
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  onPressed: widget.onDicePressed,
                  icon: Icon(
                    Icons.casino,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surface.withOpacity(0.3),
                  ),
                ),
              ),
            ],
          ),

          // Expandable personality section
          if (hasPersonalityData)
            InkWell(
              onTap: () {
                setState(() {
                  _showDetails = !_showDetails;
                });
                widget.onDetailsToggled?.call(_showDetails);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.onPrimaryContainer.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _showDetails ? 'Hide Details' : 'Show Character Details',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _showDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 16,
                      color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                    ),
                  ],
                ),
              ),
            ),

          // Expanded personality details
          if (_showDetails && hasPersonalityData)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(0.3),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Physical appearance
                  if (widget.character.age != null ||
                      widget.character.gender != null ||
                      widget.character.height != null ||
                      widget.character.weight != null ||
                      widget.character.eyes != null ||
                      widget.character.hair != null ||
                      widget.character.skin != null) ...[
                    _buildSectionTitle('Physical Appearance', Icons.face),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (widget.character.age != null)
                          _buildInfoChip('Age: ${widget.character.age}'),
                        if (widget.character.gender != null)
                          _buildInfoChip('Gender: ${widget.character.gender}'),
                        if (widget.character.height != null)
                          _buildInfoChip('Height: ${widget.character.height}'),
                        if (widget.character.weight != null)
                          _buildInfoChip('Weight: ${widget.character.weight}'),
                        if (widget.character.eyes != null)
                          _buildInfoChip('Eyes: ${widget.character.eyes}'),
                        if (widget.character.hair != null)
                          _buildInfoChip('Hair: ${widget.character.hair}'),
                        if (widget.character.skin != null)
                          _buildInfoChip('Skin: ${widget.character.skin}'),
                      ],
                    ),
                    if (widget.character.appearanceDescription != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.character.appearanceDescription!,
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],

                  // Personality
                  if (widget.character.personalityTraits != null) ...[
                    _buildSectionTitle('Personality Traits', Icons.psychology),
                    const SizedBox(height: 4),
                    Text(
                      widget.character.personalityTraits!,
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (widget.character.ideals != null) ...[
                    _buildSectionTitle('Ideals', Icons.star_outline),
                    const SizedBox(height: 4),
                    Text(
                      widget.character.ideals!,
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (widget.character.bonds != null) ...[
                    _buildSectionTitle('Bonds', Icons.favorite_outline),
                    const SizedBox(height: 4),
                    Text(
                      widget.character.bonds!,
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (widget.character.flaws != null) ...[
                    _buildSectionTitle('Flaws', Icons.warning_amber_outlined),
                    const SizedBox(height: 4),
                    Text(
                      widget.character.flaws!,
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (widget.character.backstory != null) ...[
                    _buildSectionTitle('Backstory', Icons.auto_stories),
                    const SizedBox(height: 4),
                    Text(
                      widget.character.backstory!,
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  IconData _getClassIcon(String className) {
    final lowerClass = className.toLowerCase();
    if (lowerClass.contains('paladin')) return Icons.shield_outlined;
    if (lowerClass.contains('wizard')) return Icons.auto_fix_high;
    if (lowerClass.contains('fighter')) return Icons.sports_martial_arts;
    if (lowerClass.contains('rogue')) return Icons.visibility_off;
    if (lowerClass.contains('cleric')) return Icons.health_and_safety;
    if (lowerClass.contains('barbarian')) return Icons.fitness_center;
    if (lowerClass.contains('bard')) return Icons.music_note;
    if (lowerClass.contains('druid')) return Icons.nature;
    if (lowerClass.contains('monk')) return Icons.self_improvement;
    if (lowerClass.contains('ranger')) return Icons.terrain;
    if (lowerClass.contains('sorcerer')) return Icons.bolt;
    if (lowerClass.contains('warlock')) return Icons.dark_mode;
    return Icons.person;
  }
}
