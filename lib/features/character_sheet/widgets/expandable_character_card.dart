import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/services/character_data_service.dart';
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

class _ExpandableCharacterCardState extends State<ExpandableCharacterCard> with SingleTickerProviderStateMixin {

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

  String _getLocalizedClassName(BuildContext context, String className) {
    try {
      final locale = Localizations.localeOf(context).languageCode;
      final classData = CharacterDataService.getClassById(className);
      return classData?.getName(locale) ?? className;
    } catch (e) {
      return className;
    }
  }

  String _getLocalizedSubclassName(BuildContext context, String className, String subclassName) {
    try {
      final locale = Localizations.localeOf(context).languageCode;
      final classData = CharacterDataService.getClassById(className);
      if (classData != null) {
        final subclass = classData.subclasses.firstWhere(
          (s) => s.id == subclassName || s.name.values.contains(subclassName),
          orElse: () => throw Exception('Subclass not found'),
        );
        return subclass.getName(locale);
      }
      return subclassName;
    } catch (e) {
      return subclassName;
    }
  }

  String _getLocalizedValue(AppLocalizations l10n, String value) {
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'male': return l10n.genderMale;
      case 'female': return l10n.genderFemale;
      case 'other': return l10n.genderOther;
      case 'amber': return l10n.colorAmber;
      case 'blue': return l10n.colorBlue;
      case 'brown': return l10n.colorBrown;
      case 'gray': return l10n.colorGray;
      case 'green': return l10n.colorGreen;
      case 'hazel': return l10n.colorHazel;
      case 'red': return l10n.colorRed;
      case 'violet': return l10n.colorViolet;
      case 'auburn': return l10n.colorAuburn;
      case 'black': return l10n.colorBlack;
      case 'blonde': return l10n.colorBlonde;
      case 'white': return l10n.colorWhite;
      case 'bald': return l10n.colorBald;
      case 'pale': return l10n.skinPale;
      case 'fair': return l10n.skinFair;
      case 'light': return l10n.skinLight;
      case 'medium': return l10n.skinMedium;
      case 'tan': return l10n.skinTan;
      case 'dark': return l10n.skinDark;
      case 'ebony': return l10n.skinEbony;
      default: return value;
    }
  }

  String _formatValue(AppLocalizations l10n, String? value) {
    if (value == null) return '';
    var result = value.trim();
    if (result.endsWith('cm')) result = result.replaceAll('cm', ' ${l10n.unitCm}');
    else if (result.endsWith('kg')) result = result.replaceAll('kg', ' ${l10n.unitKg}');
    else if (result.endsWith('years')) result = result.replaceAll('years', ' ${l10n.ageYears}');
    else if (result.endsWith('lb') || result.endsWith('lbs')) result = result.replaceAll(RegExp(r'lbs?'), ' ${l10n.weightUnit}');
    else if (result.endsWith('ft')) result = result.replaceAll('ft', ' ${l10n.unitCm}');
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final hasPersonalityData = widget.character.personalityTraits != null ||
        widget.character.ideals != null ||
        widget.character.bonds != null ||
        widget.character.flaws != null ||
        widget.character.backstory != null ||
        widget.character.age != null;

    final localizedClassName = _getLocalizedClassName(context, widget.character.characterClass);
    final localizedSubclass = widget.character.subclass != null 
        ? _getLocalizedSubclassName(context, widget.character.characterClass, widget.character.subclass!)
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer, // Accent color background
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.15), // Soft glow
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: colorScheme.onPrimaryContainer.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Content with Stack for Dice Button
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Avatar
                    Hero(
                      tag: 'character-avatar-${widget.character.id}',
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colorScheme.onPrimaryContainer.withOpacity(0.2)),
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
                                      color: colorScheme.primary,
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                _getClassIcon(widget.character.characterClass),
                                size: 40,
                                color: colorScheme.primary,
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Info
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 40.0), // Space for dice button
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.character.name,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.onPrimaryContainer,
                                    height: 1.1,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            
                            // Level Badge (Capsule Style)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0, bottom: 6.0),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _openLevelUpWizard,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surface, // Distinct form background
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.keyboard_double_arrow_up,
                                          size: 14,
                                          color: colorScheme.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${l10n.levelShort} ${widget.character.level}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.primary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            Text(
                              localizedClassName,
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (localizedSubclass != null)
                              Text(
                                localizedSubclass,
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

              // Dice Button (Top Right)
              Positioned(
                top: 12,
                right: 12,
                child: IconButton.filledTonal(
                  onPressed: widget.onDicePressed,
                  icon: const Icon(Icons.casino),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surface,
                    foregroundColor: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),

          // Expandable Trigger
          if (hasPersonalityData)
            InkWell(
              onTap: () {
                widget.onDetailsToggled?.call(!widget.isExpanded);
              },
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: Column(
                children: [
                  Divider(height: 1, color: colorScheme.onPrimaryContainer.withOpacity(0.1)),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Icon(
                      widget.isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 20,
                      color: colorScheme.onPrimaryContainer.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),

          // Animated Details Section
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: hasPersonalityData ? Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.character.age != null || widget.character.gender != null || widget.character.height != null ||
                      widget.character.weight != null || widget.character.eyes != null || widget.character.hair != null ||
                      widget.character.skin != null) ...[
                    _buildSectionTitle(l10n.physicalAppearance, Icons.face),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (widget.character.age != null) _buildInfoChip('${l10n.age}: ${_formatValue(l10n, widget.character.age)}'),
                        if (widget.character.gender != null) _buildInfoChip('${l10n.gender}: ${_getLocalizedValue(l10n, widget.character.gender!)}'),
                        if (widget.character.height != null) _buildInfoChip('${l10n.height}: ${_formatValue(l10n, widget.character.height)}'),
                        if (widget.character.weight != null) _buildInfoChip('${l10n.weight}: ${_formatValue(l10n, widget.character.weight)}'),
                        if (widget.character.eyes != null) _buildInfoChip('${l10n.eyes}: ${_getLocalizedValue(l10n, widget.character.eyes!)}'),
                        if (widget.character.hair != null) _buildInfoChip('${l10n.hair}: ${_getLocalizedValue(l10n, widget.character.hair!)}'),
                        if (widget.character.skin != null) _buildInfoChip('${l10n.skin}: ${_getLocalizedValue(l10n, widget.character.skin!)}'),
                      ],
                    ),
                    if (widget.character.appearanceDescription != null) ...[
                      const SizedBox(height: 8),
                      Text(widget.character.appearanceDescription!, style: TextStyle(color: colorScheme.onPrimaryContainer.withOpacity(0.9), fontSize: 13)),
                    ],
                    const SizedBox(height: 16),
                  ],
                  if (widget.character.personalityTraits != null) ...[_buildSectionTitle(l10n.traits, Icons.psychology), const SizedBox(height: 4), Text(widget.character.personalityTraits!, style: TextStyle(color: colorScheme.onPrimaryContainer.withOpacity(0.9), fontSize: 13)), const SizedBox(height: 12)],
                  if (widget.character.ideals != null) ...[_buildSectionTitle(l10n.ideals, Icons.star_outline), const SizedBox(height: 4), Text(widget.character.ideals!, style: TextStyle(color: colorScheme.onPrimaryContainer.withOpacity(0.9), fontSize: 13)), const SizedBox(height: 12)],
                  if (widget.character.bonds != null) ...[_buildSectionTitle(l10n.bonds, Icons.favorite_outline), const SizedBox(height: 4), Text(widget.character.bonds!, style: TextStyle(color: colorScheme.onPrimaryContainer.withOpacity(0.9), fontSize: 13)), const SizedBox(height: 12)],
                  if (widget.character.flaws != null) ...[_buildSectionTitle(l10n.flaws, Icons.warning_amber_outlined), const SizedBox(height: 4), Text(widget.character.flaws!, style: TextStyle(color: colorScheme.onPrimaryContainer.withOpacity(0.9), fontSize: 13)), const SizedBox(height: 12)],
                  if (widget.character.backstory != null) ...[_buildSectionTitle(l10n.backstory, Icons.auto_stories), const SizedBox(height: 4), Text(widget.character.backstory!, style: TextStyle(color: colorScheme.onPrimaryContainer.withOpacity(0.9), fontSize: 13))],
                ],
              ),
            ) : const SizedBox.shrink(),
            crossFadeState: widget.isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.onPrimaryContainer),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colorScheme.onPrimaryContainer)),
      ],
    );
  }

  Widget _buildInfoChip(String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.w500)),
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
