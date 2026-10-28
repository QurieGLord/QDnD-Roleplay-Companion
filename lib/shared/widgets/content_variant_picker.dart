import 'package:flutter/material.dart';
import '../../core/content/content_catalog.dart';
import '../../core/services/storage_service.dart';
import '../../core/ui/companion_surface.dart';
import '../../core/ui/sheet_drag_region.dart';

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

Future<T?> showContentVariantPicker<T>(
        BuildContext context, ContentFamily<T> family,
        {required String title,
        required String Function(T) summary,
        required String Function(T) description,
        Set<String> preferredIds = const {},
        String? preferredLabel}) =>
    showResponsiveSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) {
          final ru = Localizations.localeOf(context).languageCode == 'ru',
              t = Theme.of(context),
              c = t.colorScheme;
          return ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .86),
              child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(title,
                            style: t.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.6)),
                        const SizedBox(height: 10),
                        Text(
                            ru
                                ? 'Доступны разные версии. Выбери правила для своей игры.'
                                : 'Different versions are available. Choose the rules for your game.',
                            style: t.textTheme.bodyMedium),
                        const SizedBox(height: 20),
                        for (final variant in family.variants)
                          Builder(builder: (context) {
                            final records = variant.records.toList()
                              ..sort((a, b) {
                                final ak = preferredIds.contains(a.id),
                                    bk = preferredIds.contains(b.id);
                                if (ak != bk) return ak ? -1 : 1;
                                if ((a.sourceId == null) !=
                                    (b.sourceId == null)) {
                                  return a.sourceId == null ? -1 : 1;
                                }
                                return a.id.compareTo(b.id);
                              });
                            final record = records.first,
                                books = records
                                    .map((r) =>
                                        contentSourceName(context, r.sourceId))
                                    .toSet()
                                    .join(' · '),
                                text = description(record.entity);
                            return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: CompanionSurface(
                                    quiet: !preferredIds.contains(record.id),
                                    contour: CompanionContour.focus,
                                    onTap: () =>
                                        Navigator.pop(context, record.entity),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (preferredIds.contains(record.id))
                                            Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 8),
                                                child: Text(
                                                    preferredLabel ??
                                                        (ru
                                                            ? 'Уже в листе'
                                                            : 'Already on your sheet'),
                                                    style: t
                                                        .textTheme.labelMedium
                                                        ?.copyWith(
                                                            color:
                                                                c.secondary))),
                                          Text(summary(record.entity),
                                              style: t.textTheme.titleMedium
                                                  ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800)),
                                          const SizedBox(height: 8),
                                          Text(books,
                                              style: t.textTheme.bodySmall
                                                  ?.copyWith(
                                                      color: c.secondary)),
                                          if (text.trim().isNotEmpty) ...[
                                            const SizedBox(height: 12),
                                            Text(text,
                                                maxLines: 4,
                                                overflow: TextOverflow.ellipsis,
                                                style: t.textTheme.bodyMedium
                                                    ?.copyWith(height: 1.35))
                                          ],
                                          const SizedBox(height: 12),
                                          Align(
                                              alignment: Alignment.centerRight,
                                              child: Icon(
                                                  Icons.arrow_forward_rounded,
                                                  color: c.secondary)),
                                        ])));
                          }),
                      ])));
        });
