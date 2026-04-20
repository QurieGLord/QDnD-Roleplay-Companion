import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../core/models/character.dart';
import 'character_roster_visuals.dart';

class CharacterCard extends StatefulWidget {
  const CharacterCard({
    super.key,
    required this.character,
    required this.onTap,
    required this.onLongPress,
  });

  final Character character;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<CharacterCard> createState() => _CharacterCardState();
}

class _CharacterCardState extends State<CharacterCard> {
  bool _pressed = false;
  bool _hovered = false;

  void _handleLongPress() {
    HapticFeedback.mediumImpact();
    widget.onLongPress();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final localizedRaceName =
        getLocalizedRaceName(context, widget.character.race);
    final localizedClassName =
        getLocalizedClassName(context, widget.character.characterClass);
    final localizedSubclass = widget.character.subclass != null
        ? getLocalizedSubclassName(
            context,
            widget.character.characterClass,
            widget.character.subclass!,
          )
        : null;
    final accent =
        resolveClassAccent(colorScheme, widget.character.characterClass);
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(
        color: (_hovered ? accent : colorScheme.outlineVariant)
            .withValues(alpha: _hovered ? 0.32 : 0.56),
      ),
    );

    return MouseRegion(
      onEnter: (_) {
        if (!_hovered && !disableAnimations) {
          setState(() => _hovered = true);
        }
      },
      onExit: (_) {
        if (_hovered && !disableAnimations) {
          setState(() => _hovered = false);
        }
      },
      child: AnimatedScale(
        scale: disableAnimations
            ? 1
            : _pressed
                ? 0.985
                : (_hovered ? 1.01 : 1),
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: disableAnimations
              ? Offset.zero
              : (_hovered ? const Offset(0, -0.012) : Offset.zero),
          duration: disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Material(
            color: colorScheme.surfaceContainerLow,
            elevation: _hovered ? 2 : 0,
            shadowColor: accent.withValues(alpha: 0.14),
            surfaceTintColor: accent,
            shape: cardShape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onLongPress: _handleLongPress,
              onSecondaryTap: _handleLongPress,
              onHighlightChanged: (value) {
                if (_pressed != value && !disableAnimations) {
                  setState(() => _pressed = value);
                }
              },
              hoverColor: accent.withValues(alpha: 0.04),
              splashColor: accent.withValues(alpha: 0.08),
              highlightColor: accent.withValues(alpha: 0.04),
              customBorder: cardShape,
              child: Stack(
                children: [
                  Positioned(
                    top: -32,
                    right: -24,
                    child: _CardGlow(
                      size: 100,
                      color: accent.withValues(alpha: 0.13),
                    ),
                  ),
                  Positioned(
                    left: -18,
                    bottom: -36,
                    child: _CardGlow(
                      size: 92,
                      color: colorScheme.secondary.withValues(alpha: 0.07),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _AvatarBlock(
                          character: widget.character,
                          accent: accent,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: _IdentityBadge(
                                  text: localizedRaceName,
                                  accent: accent,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.character.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.05,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${l10n.levelShort} ${widget.character.level} $localizedClassName',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.82),
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (localizedSubclass != null) ...[
                                const SizedBox(height: 8),
                                _SubclassSurface(
                                  label: localizedSubclass,
                                  accent: accent,
                                ),
                              ],
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _MetricChip(
                                    icon: Icons.favorite_rounded,
                                    label: l10n.hpShort,
                                    value:
                                        '${widget.character.currentHp}/${widget.character.maxHp}',
                                    accent: colorScheme.error,
                                  ),
                                  _MetricChip(
                                    icon: Icons.shield_rounded,
                                    label: l10n.armorClassAC,
                                    value: '${widget.character.armorClass}',
                                    accent: colorScheme.secondary,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _TrailingAffordance(
                          accent: accent,
                          hovered: _hovered,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarBlock extends StatelessWidget {
  const _AvatarBlock({
    required this.character,
    required this.accent,
  });

  final Character character;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Hero(
      tag: 'character-avatar-${character.id}',
      child: Container(
        width: 74,
        height: 74,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                accent.withValues(alpha: 0.22),
                colorScheme.surfaceContainerHighest,
              ),
              Color.alphaBlend(
                colorScheme.secondary.withValues(alpha: 0.14),
                colorScheme.surfaceContainer,
              ),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: character.avatarPath != null
                    ? Image.file(
                        File(character.avatarPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _FallbackAvatar(
                            icon: getClassIcon(character.characterClass),
                            accent: accent,
                          );
                        },
                      )
                    : _FallbackAvatar(
                        icon: getClassIcon(character.characterClass),
                        accent: accent,
                      ),
              ),
            ),
            Positioned(
              top: 7,
              right: 7,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.88),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accent.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(
                  getClassIcon(character.characterClass),
                  size: 14,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({
    required this.icon,
    required this.accent,
  });

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              accent.withValues(alpha: 0.2),
              colorScheme.primaryContainer,
            ),
            Color.alphaBlend(
              colorScheme.tertiary.withValues(alpha: 0.12),
              colorScheme.secondaryContainer,
            ),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 28,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _IdentityBadge extends StatelessWidget {
  const _IdentityBadge({
    required this.text,
    required this.accent,
  });

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: 0.12),
          colorScheme.surfaceContainerHighest,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _SubclassSurface extends StatelessWidget {
  const _SubclassSurface({
    required this.label,
    required this.accent,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: 0.1),
          colorScheme.surfaceContainerHighest,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 12,
            color: accent,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: 0.12),
          colorScheme.surfaceContainerHighest,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 12,
              color: accent,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label $value',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrailingAffordance extends StatelessWidget {
  const _TrailingAffordance({
    required this.accent,
    required this.hovered,
  });

  final Color accent;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: MediaQuery.maybeOf(context)?.disableAnimations ?? false
          ? Duration.zero
          : const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: 36,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: hovered
            ? Color.alphaBlend(
                accent.withValues(alpha: 0.14),
                colorScheme.surfaceContainerHighest,
              )
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (hovered ? accent : colorScheme.outlineVariant)
              .withValues(alpha: hovered ? 0.24 : 0.48),
        ),
      ),
      child: Center(
        child: Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: hovered
              ? accent
              : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _CardGlow extends StatelessWidget {
  const _CardGlow({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: size,
              spreadRadius: size / 4,
            ),
          ],
        ),
        child: SizedBox.square(dimension: size),
      ),
    );
  }
}
