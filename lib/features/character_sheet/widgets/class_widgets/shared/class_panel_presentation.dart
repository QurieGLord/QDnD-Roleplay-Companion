import '../../../../../shared/widgets/subclass_details_sheet.dart';
import 'package:flutter/material.dart';
import '../../../../../core/models/character.dart';
import '../../../../../core/models/character_feature.dart';
import '../../../../../core/progression/character_class_context.dart';
import '../../../../../core/ui/companion_surface.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../session/expressive_hold_surface.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

String classRecoveryLabel(AppLocalizations l, RecoveryType type) =>
    switch (type) {
      RecoveryType.shortRest => l.shortRest,
      RecoveryType.longRest => l.longRest,
      RecoveryType.dawn => l.recoveryDawn,
      RecoveryType.perTurn => l.recoveryEachTurn,
      RecoveryType.recharge => l.recoveryRecharge,
      RecoveryType.manual => l.recoveryManual,
    };

CompanionContour classContour(String id) => switch (id) {
      'fighter' || 'barbarian' => CompanionContour.facet,
      'bard' || 'monk' => CompanionContour.cadence,
      'warlock' || 'cleric' => CompanionContour.seal,
      'wizard' || 'rogue' => CompanionContour.fold,
      'ranger' || 'paladin' => CompanionContour.focus,
      _ => CompanionContour.soft,
    };

class ClassSubclassLink extends StatefulWidget {
  const ClassSubclassLink(
      {super.key, required this.character, required this.classId});
  final Character character;
  final String classId;
  @override
  State<ClassSubclassLink> createState() => _ClassSubclassLinkState();
}

class _ClassSubclassLinkState extends State<ClassSubclassLink> {
  @override
  Widget build(BuildContext context) {
    final owner = CharacterClassContext(widget.character, widget.classId);
    final locale = Localizations.localeOf(context).languageCode;
    final name = owner.subclassName(locale);
    if (name == null || name.isEmpty) return const SizedBox.shrink();
    return ListTile(
        dense: true,
        minTileHeight: 40,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: Text(name,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Theme.of(context).colorScheme.secondary)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () async {
          await showClassSubclassDetails(
              context, widget.character, widget.classId);
          if (mounted) {
            setState(() {});
          }
        });
  }
}

class ClassPanelFrame extends StatelessWidget {
  const ClassPanelFrame(
      {super.key,
      required this.character,
      required this.classId,
      required this.child});
  final Character character;
  final String classId;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final owner = CharacterClassContext(character, classId);
    if (owner.level == 0) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context).languageCode;
    return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
              child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(owner.name(locale),
                        style: t.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.1,
                            color: c.onSurface)),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                            color: c.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(AppRadii.xl)),
                        child: Text(
                            '${AppLocalizations.of(context)!.level} ${owner.level}',
                            style: t.textTheme.labelLarge)),
                  ])),
          AnimatedSize(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              alignment: Alignment.topCenter,
              curve: Curves.easeInOutCubic,
              child: child),
        ]));
  }
}

/// A real resource/action, never a decorative counter or a free recovery.
class ClassPrimaryControl extends StatelessWidget {
  const ClassPrimaryControl(
      {super.key,
      required this.classId,
      required this.title,
      required this.child,
      this.current,
      this.maximum,
      this.onTap,
      this.onEdit,
      this.tone,
      this.footer,
      this.active = false,
      this.marks = false,
      this.busy = false,
      this.onDetails,
      this.trailing});
  final String classId, title;
  final Widget child;
  final int? current, maximum;
  final VoidCallback? onTap, onEdit, onDetails;
  final Widget? trailing;
  final Color? tone;
  final String? footer;
  final bool active, marks, busy;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final l = AppLocalizations.of(context)!;
    final showMarks = marks &&
        current != null &&
        maximum != null &&
        maximum! > 0 &&
        maximum! <= 10;
    final content = CompanionSurface(
        contour: classContour(classId),
        raised: true,
        color: tone ?? (active ? c.primaryContainer : c.secondaryContainer),
        padding: const EdgeInsets.all(18),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Text(title,
                    style: t.textTheme.titleLarge?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.08,
                        letterSpacing: -.65,
                        color: c.onSurface))),
            if (current != null && maximum != null) ...[
              const SizedBox(width: 12),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                      color: c.surface.withValues(alpha: .8),
                      borderRadius: BorderRadius.circular(AppRadii.xl)),
                  child:
                      CompanionReserve(current: current!, maximum: maximum!)),
            ],
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            if (onDetails != null && footer == null && !showMarks)
              IconButton(
                  onPressed: onDetails,
                  tooltip: l.advancementDetails,
                  icon: const Icon(Icons.info_outline_rounded, size: 20)),
          ]),
          const SizedBox(height: 16),
          child,
          if (footer != null || showMarks) ...[
            const SizedBox(height: 14),
            Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  if (showMarks)
                    CompanionReserveMarks(
                        current: current!,
                        maximum: maximum!,
                        contour: classContour(classId)),
                  if (footer != null)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.restore_rounded,
                          size: 15, color: c.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Flexible(
                          child: Text(footer!,
                              style: t.textTheme.bodySmall?.copyWith(
                                  color: c.onSurfaceVariant, fontSize: 13))),
                    ]),
                  if (onDetails != null)
                    IconButton(
                        onPressed: onDetails,
                        tooltip: l.advancementDetails,
                        icon: const Icon(Icons.info_outline_rounded, size: 20)),
                ]),
          ],
        ]));
    return ExpressiveHoldSurface(
        enabled: !busy,
        onTap: onTap,
        onHold: onEdit,
        semanticLabel:
            '$title${current != null && maximum != null ? '. ${l.sheetCounterDescription(current!, maximum!)}' : ''}',
        hint: onEdit == null ? null : l.sheetHoldToEdit,
        child: content);
  }
}

class ClassFacts extends StatelessWidget {
  const ClassFacts({super.key, required this.facts});
  final List<({String label, String value})> facts;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        final columns = bounds.maxWidth >= 280 &&
                MediaQuery.textScalerOf(context).scale(1) <= 1.3
            ? 2
            : 1;
        final width = (bounds.maxWidth - (columns - 1) * 16) / columns;
        final t = Theme.of(context);
        return Wrap(spacing: 16, runSpacing: 14, children: [
          for (final fact in facts)
            SizedBox(
                width: width,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fact.label,
                          style: t.textTheme.bodySmall?.copyWith(
                              color: t.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 5),
                      Text(fact.value,
                          style: t.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800))
                    ])),
        ]);
      });
}
