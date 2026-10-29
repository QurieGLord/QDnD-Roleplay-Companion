import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/content/content_catalog.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/companion_kit.dart';
import '../../core/ui/page_kit.dart';

String contentSourceName(BuildContext context, String? id) {
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  if (id == null) return ru ? 'Базовая библиотека' : 'Core library';
  try {
    return StorageService.getAllSources()
            .where((s) => s.id == id)
            .firstOrNull
            ?.name ??
        (ru ? 'Подключённая книга' : 'Imported book');
  } catch (_) {
    return ru ? 'Подключённая книга' : 'Imported book';
  }
}

String contentFamilySummary<T>(BuildContext context, ContentFamily<T> family) {
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  String count(int n, String one, String few, String many) =>
      '$n ${n % 100 >= 11 && n % 100 <= 14 ? many : n % 10 == 1 ? one : n % 10 >= 2 && n % 10 <= 4 ? few : many}';
  final sources = family.sources.length, variants = family.variants.length;
  return ru
      ? '${count(sources, 'книга', 'книги', 'книг')} · ${count(variants, 'версия', 'версии', 'версий')}'
      : '$sources ${sources == 1 ? 'source' : 'sources'} · $variants ${variants == 1 ? 'version' : 'versions'}';
}

/// The versions of one concept in a sheet (wave 6 standard): a tap selects a
/// version, the glass island at the bottom takes it. Returns the chosen
/// entity, or null when the sheet is dismissed.
Future<T?> showContentVariantPicker<T>(
    BuildContext context, ContentFamily<T> family,
    {required String title,
    required String Function(T) summary,
    required String Function(T) description,
    Set<String> preferredIds = const {},
    String? preferredLabel}) {
  FocusManager.instance.primaryFocus?.unfocus();
  final c = Theme.of(context).colorScheme;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: c.surfaceContainer,
    barrierColor: const Color(0x730A0806),
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: Duration(milliseconds: 420),
            reverseDuration: Duration(milliseconds: 220)),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl))),
    builder: (_) => _VariantSheet<T>(
        family: family,
        title: title,
        summary: summary,
        description: description,
        preferredIds: preferredIds,
        preferredLabel: preferredLabel),
  );
}

class _VariantSheet<T> extends StatefulWidget {
  const _VariantSheet(
      {required this.family,
      required this.title,
      required this.summary,
      required this.description,
      required this.preferredIds,
      required this.preferredLabel});
  final ContentFamily<T> family;
  final String title;
  final String Function(T) summary, description;
  final Set<String> preferredIds;
  final String? preferredLabel;
  @override
  State<_VariantSheet<T>> createState() => _VariantSheetState<T>();
}

class _VariantSheetState<T> extends State<_VariantSheet<T>> {
  /// Each version by the record that stands for it: one already on the
  /// sheet first, then the base library, then by ID.
  late final List<(ContentRecord<T>, List<ContentRecord<T>>)> _versions = [
    for (final variant in widget.family.variants)
      () {
        final records = variant.records.toList()
          ..sort((a, b) {
            final ak = widget.preferredIds.contains(a.id),
                bk = widget.preferredIds.contains(b.id);
            if (ak != bk) return ak ? -1 : 1;
            if ((a.sourceId == null) != (b.sourceId == null)) {
              return a.sourceId == null ? -1 : 1;
            }
            return a.id.compareTo(b.id);
          });
        return (records.first, records);
      }()
  ];
  late int _picked = () {
    final i = _versions.indexWhere((v) => widget.preferredIds.contains(v.$1.id));
    return i < 0 ? -1 : i;
  }();

  bool _current(int i) => widget.preferredIds.contains(_versions[i].$1.id);

  @override
  Widget build(BuildContext context) {
    final tr = Tr(context);
    final c = Theme.of(context).colorScheme;
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final ready = _picked >= 0;
    final keep = ready && _current(_picked);
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .88),
      child: Stack(children: [
        SheetTopFade(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(
                18, SheetGrab.inset, 18, 56 + 16 + 28 + bottom),
            children: [
              PageSheetHead(
                  kicker: tr.plural(widget.family.variants.length,
                      const ['версия', 'версии', 'версий'],
                      const ['version', 'versions']),
                  title: widget.title,
                  sub: tr.t(
                      'Книги расходятся в этом месте. Выберите версию для своей игры.',
                      'The books differ here. Choose the version for your game.')),
              const SizedBox(height: 14),
              for (final (i, (record, records)) in _versions.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PageEntrance(
                    index: i,
                    child: Pressable(
                      key: ValueKey('content-variant-$i'),
                      scale: .98,
                      onTap: () {
                        if (_picked == i) return;
                        HapticFeedback.selectionClick();
                        setState(() => _picked = i);
                      },
                      child: AnimatedContainer(
                        duration: dur,
                        curve: AppMotion.snappyCurve,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        decoration: BoxDecoration(
                          color: _picked == i
                              ? Color.lerp(c.surfaceContainerHigh, c.primary, .08)
                              : c.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(_picked == i ? 18 : 26),
                          border: Border.all(
                              color: c.primary.withValues(alpha: _picked == i ? .9 : 0),
                              width: 2,
                              strokeAlign: BorderSide.strokeAlignInside),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: Text(
                                      records
                                          .map((r) => contentSourceName(context, r.sourceId))
                                          .toSet()
                                          .join(' · '),
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: c.secondary)),
                                ),
                                if (_current(i))
                                  Flexible(
                                   child: Text(
                                      widget.preferredLabel ??
                                          tr.t('Уже в листе', 'Already on your sheet'),
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: c.onSurfaceVariant)),
                                  ),
                              ]),
                              const SizedBox(height: 6),
                              Text(widget.summary(record.entity),
                                  style: TextStyle(
                                      fontFamily: AppType.display,
                                      fontSize: 16,
                                      height: 1.25,
                                      fontWeight: FontWeight.w600,
                                      color: c.onSurface)),
                              if (widget.description(record.entity).trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                // The chosen version opens its text in full.
                                AnimatedSize(
                                  duration: dur,
                                  curve: AppMotion.standard,
                                  alignment: Alignment.topCenter,
                                  child: Text(widget.description(record.entity),
                                      maxLines: _picked == i ? 14 : 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 14,
                                          height: 1.4,
                                          color: c.onSurfaceVariant)),
                                ),
                              ],
                            ]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Positioned(left: 0, right: 0, top: 0, child: SheetGrab()),
        // A glass island holds the confirm; it fills once a version is set.
        Positioned(
          left: 14,
          right: 14,
          bottom: 14 + bottom,
          child: FloatingIsland(
            child: Pressable(
              key: const ValueKey('content-variant-take'),
              scale: .97,
              onTap: !ready
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop(_versions[_picked].$1.entity);
                    },
              child: AnimatedContainer(
                duration: dur,
                curve: AppMotion.snappyCurve,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: ready && !keep ? c.primary : c.secondaryContainer,
                    borderRadius: BorderRadius.circular(ready ? 18 : 26)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                   child: Text(
                      !ready
                          ? tr.t('Выберите версию', 'Choose a version')
                          : keep
                              ? tr.t('Оставить эту', 'Keep this one')
                              : tr.t('Взять эту версию', 'Take this version'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: ready && !keep ? c.onPrimary : c.onSecondaryContainer)),
                  ),
                  const SizedBox(width: 8),
                  LineIcon('check',
                      size: 18,
                      color: ready && !keep ? c.onPrimary : c.onSecondaryContainer),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
