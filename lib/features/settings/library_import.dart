import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/fc5_compendium_zip_service.dart';
import '../../core/services/fc5_parser.dart';
import '../../core/services/import_service.dart';
import '../../core/theme/app_palettes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/companion_kit.dart';
import '../../core/ui/expressive_kit.dart';
import '../../core/ui/page_kit.dart';
import 'library_shelf.dart';

/// Putting a book on the shelf (wave 5): the device's file picker, then for
/// a ZIP the «Что внутри» sheet, then the import read like a book — each
/// module's pages flip while its counts roll up. Returns the shelf id of
/// the new book (`zip:<archive>` or the source id), or null.
Future<String?> importLibrary(BuildContext context) async {
  final picked = await FilePicker.platform
      .pickFiles(type: FileType.custom, allowedExtensions: ['xml', 'zip']);
  if (!context.mounted || picked == null || picked.files.single.path == null) {
    return null;
  }
  final file = File(picked.files.single.path!);
  final ext = (picked.files.single.extension ?? file.path.split('.').last)
      .toLowerCase();
  if (ext == 'zip') return _importZip(context, file);
  final name = file.uri.pathSegments.last.replaceAll(RegExp(r'\.xml$'), '');
  final job =
      _ReadJob(name, () => ImportService.importCompendiumFileDetailed(file));
  final run = _ReadRun([job]);
  await _readingSheet(context, run, kind: 'XML', title: name);
  return run.firstSourceId;
}

Future<String?> _importZip(BuildContext context, File file) async {
  final s = Tr(context);
  final scan = ValueNotifier<FC5CompendiumZipScanProgress?>(null);
  final closed = Completer<void>();
  // A short sheet while the archive is read; it gives way to «Что внутри».
  unawaited(showCompanionSheet<void>(context,
          builder: (_) => _ScanSheet(progress: scan))
      .then((_) => closed.complete()));
  FC5CompendiumZipPreview preview;
  try {
    preview = await FC5CompendiumZipService.previewFile(file,
        onProgress: (p) => scan.value = p);
  } catch (e) {
    if (context.mounted) {
      if (!closed.isCompleted) Navigator.of(context).pop();
      final message = e is FC5CompendiumZipException ? e.message : '$e';
      AppSnackBar.error(context,
          s.t('Не удалось прочитать: $message', 'Could not read it: $message'));
    }
    return null;
  } finally {
    scan.dispose();
  }
  if (!context.mounted) return null;
  if (!closed.isCompleted) Navigator.of(context).pop();
  if (preview.entries.isEmpty) {
    AppSnackBar.warning(
        context,
        s.t('В архиве нет подходящих XML', 'No suitable XML in the archive'));
    return null;
  }
  var size = 0;
  try {
    size = await file.length();
  } catch (_) {}
  if (!context.mounted) return null;
  final chosen = await showCompanionSheet<List<FC5CompendiumZipEntryPreview>>(
      context,
      builder: (_) => ZipChoiceSheet(preview: preview, fileBytes: size));
  if (chosen == null || chosen.isEmpty || !context.mounted) return null;
  final archiveId = const Uuid().v4();
  final run = _ReadRun([
    for (final e in chosen)
      _ReadJob(e.displayName, () async {
        final xml = await FC5CompendiumZipService.readXmlEntry(file, e.rawPath);
        return ImportService.importCompendiumXmlContentDetailed(xml,
            sourceName: e.displayPath,
            archiveId: archiveId,
            archiveName: preview.archiveName,
            moduleName: e.displayName,
            modulePath: e.displayPath,
            sourceKind: 'zip_module');
      }, monsters: e.monsters),
  ]);
  await _readingSheet(context, run, kind: 'ZIP', title: preview.archiveName);
  return run.imported > 0 ? 'zip:$archiveId' : null;
}

String _bytes(Tr s, int bytes) {
  final mb = bytes / 1024 / 1024;
  if (mb >= .1) {
    final v = mb.toStringAsFixed(1);
    return s.t('${v.replaceAll('.', ',')} МБ', '$v MB');
  }
  final kb = math.max(1, (bytes / 1024).round());
  return s.t('$kb КБ', '$kb KB');
}

/// «заклинания 120 · предметы 40».
String _entryStats(Tr s, List<int> counts) => [
      for (final k in ShelfKind.values)
        if (counts[k.index] > 0)
          '${k.label(s).toLowerCase()} ${s.group(counts[k.index])}'
    ].join(' · ');

List<int> _entryCounts(FC5CompendiumZipEntryPreview e) =>
    [e.items, e.spells, e.races, e.classes, e.backgrounds, e.feats];

class _ScanSheet extends StatelessWidget {
  const _ScanSheet({required this.progress});
  final ValueNotifier<FC5CompendiumZipScanProgress?> progress;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final s = Tr(context);
    return ValueListenableBuilder<FC5CompendiumZipScanProgress?>(
      valueListenable: progress,
      builder: (context, p, _) {
        final frac = p == null || p.total <= 0 ? null : p.current / p.total;
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageSheetHead(
                  kicker: 'ZIP',
                  title: s.t('Смотрим, что внутри', 'Looking inside'),
                  sub: p == null || p.total <= 0
                      ? s.t('Открываем архив…', 'Opening the archive…')
                      : s.t('XML ${p.current} из ${p.total}',
                          'XML ${p.current} of ${p.total}')),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _FlippingBook(open: true),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        _Bar(value: frac, color: c.secondary),
                        const SizedBox(height: 8),
                        Text(p?.path ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontFeatures: AppType.tabular,
                                color: c.onSurfaceVariant)),
                      ]),
                ),
              ]),
            ]);
      },
    );
  }
}

/// «Что внутри»: every XML of the archive as a row to pick, quick picks,
/// and a footer whose totals roll as the choice changes.
class ZipChoiceSheet extends StatefulWidget {
  const ZipChoiceSheet(
      {super.key, required this.preview, required this.fileBytes});
  final FC5CompendiumZipPreview preview;
  final int fileBytes;
  @override
  State<ZipChoiceSheet> createState() => _ZipChoiceSheetState();
}

class _ZipChoiceSheetState extends State<ZipChoiceSheet> {
  late Set<String> _pick = _recommended();
  final _stamp = <String, int>{};

  FC5CompendiumZipPreview get _p => widget.preview;

  Set<String> _recommended() {
    final suggested = _p.suggestedEntry;
    if (suggested != null && suggested.isCombinedCandidate) {
      return {suggested.rawPath};
    }
    return {
      for (final e in _p.entries)
        if (e.canImport) e.rawPath
    };
  }

  bool _isRecommended(FC5CompendiumZipEntryPreview e) {
    final suggested = _p.suggestedEntry;
    return suggested != null &&
        suggested.isCombinedCandidate &&
        suggested.rawPath == e.rawPath;
  }

  void _quick(String q) {
    HapticFeedback.lightImpact();
    setState(() {
      _stamp[q] = (_stamp[q] ?? 0) + 1;
      _pick = switch (q) {
        'rec' => _recommended(),
        'all' => {
            for (final e in _p.entries)
              if (e.canImport) e.rawPath
          },
        _ => <String>{},
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final a = AppAccents.of(context);
    final s = Tr(context);
    final sel = [
      for (final e in _p.entries)
        if (_pick.contains(e.rawPath)) e
    ];
    final totals = List.filled(6, 0);
    var monsters = 0;
    for (final e in sel) {
      final n = _entryCounts(e);
      for (var i = 0; i < 6; i++) {
        totals[i] += n[i];
      }
      monsters += e.monsters;
    }
    final dup = sel.any((e) => e.isCombinedCandidate) &&
        sel.any((e) => !e.isCombinedCandidate && e.canImport);
    final files = _p.entries.length + _p.ignoredFileCount;
    const gap = SizedBox(height: 14);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
              begin: const Alignment(-.5, -1),
              end: const Alignment(.5, 1),
              stops: const [
                0,
                .75
              ],
              colors: [
                pageMix(a.at(1), .14 * AppCalm.of(context).glow,
                    c.surfaceContainerLow),
                c.surfaceContainerLow
              ]),
        ),
        child: Row(children: [
          PageSeal('zip', accent: a.at(1), size: PageSealSize.lg),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PageCap(
                  'ZIP · ${s.plural(files, const [
                        'файл',
                        'файла',
                        'файлов'
                      ], const [
                        'file',
                        'files'
                      ])}'
                  '${widget.fileBytes > 0 ? ' · ${_bytes(s, widget.fileBytes)}' : ''}',
                  accent: a.at(1)),
              const SizedBox(height: 4),
              Text(_p.archiveName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 19,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: c.onSurface)),
            ]),
          ),
        ]),
      ),
      gap,
      PageSheetHead(
          title: s.t('Что внутри', 'What is inside'),
          sub: s.t(
              'Найдено XML: ${_p.entries.length}, прочих файлов пропущено: ${_p.ignoredFileCount}. Отметьте, что поставить на полку.',
              'XML found: ${_p.entries.length}, other files skipped: ${_p.ignoredFileCount}. Mark what goes on the shelf.')),
      gap,
      Wrap(spacing: 6, runSpacing: 6, children: [
        _QuickPick(
            stamp: _stamp['rec'] ?? 0,
            icon: 'star',
            label: s.t('Рекомендуемое', 'Recommended'),
            onTap: () => _quick('rec')),
        _QuickPick(
            stamp: _stamp['all'] ?? 0,
            icon: 'layers',
            label: s.t('Всё', 'All'),
            onTap: () => _quick('all')),
        _QuickPick(
            stamp: _stamp['none'] ?? 0,
            icon: 'x',
            label: s.t('Ничего', 'None'),
            onTap: () => _quick('none')),
      ]),
      gap,
      for (final e in _p.entries) ...[
        _ZipRow(
          entry: e,
          on: _pick.contains(e.rawPath),
          recommended: _isRecommended(e),
          onTap: e.canImport
              ? () {
                  HapticFeedback.selectionClick();
                  setState(() => _pick.contains(e.rawPath)
                      ? _pick.remove(e.rawPath)
                      : _pick.add(e.rawPath));
                }
              : null,
        ),
        const SizedBox(height: 6),
      ],
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: c.onSurface.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(22)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                RollingNumber(sel.length,
                    style: TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 30,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        fontFeatures: AppType.tabular,
                        color: c.onSurface)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      s.plural(
                          sel.length,
                          const [
                            'модуль выбран',
                            'модуля выбрано',
                            'модулей выбрано'
                          ],
                          const ['module chosen', 'modules chosen'],
                          number: false),
                      style:
                          TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
                ),
              ]),
          const SizedBox(height: 12),
          PageGrid3(gap: 6, children: [
            for (final k in ShelfKind.values)
              PageCount(
                  value: totals[k.index],
                  label: k.label(s),
                  accent: a.at(k.index),
                  size: 17,
                  base: Colors.transparent,
                  dimZero: true),
          ]),
          PageReveal(
            open: monsters > 0,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: PageNote(s.t(
                  'Монстры пока не поддерживаются и будут пропущены: $monsters.',
                  'Monsters are not supported yet and will be skipped: $monsters.')),
            ),
          ),
          PageReveal(
            open: dup,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: PageNote(
                  s.t('Общий compendium пересекается с отдельными модулями. Можно взять оба — смысловые дубли пропустятся.',
                      'The combined compendium overlaps the separate modules. You can take both — duplicates will be skipped.'),
                  icon: 'warn',
                  accent: a.at(1)),
            ),
          ),
        ]),
      ),
      gap,
      ToneButton(
        label: s.t('Поставить на полку', 'Put on the shelf'),
        icon: LineIcon('download', size: 20, color: c.onPrimary),
        kind: ToneKind.primary,
        height: 56,
        fontSize: 15,
        expand: true,
        onPressed: sel.isEmpty ? null : () => Navigator.of(context).pop(sel),
      ),
    ]);
  }
}

class _QuickPick extends StatelessWidget {
  const _QuickPick(
      {required this.stamp,
      required this.icon,
      required this.label,
      required this.onTap});
  final int stamp;
  final String icon, label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Pressable(
      scale: .95,
      onTap: onTap,
      child: _Stamp(
        stamp: stamp,
        child: Container(
          height: 38,
          padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
          decoration: BoxDecoration(
              color: c.onSurface.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(19)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            LineIcon(icon, size: 16, color: c.secondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.onSurface)),
          ]),
        ),
      ),
    );
  }
}

/// stamp5: lands from a little larger, dips under its size and settles.
class _Stamp extends StatefulWidget {
  const _Stamp({required this.stamp, required this.child});
  final int stamp;
  final Widget child;
  @override
  State<_Stamp> createState() => _StampState();
}

class _StampState extends State<_Stamp> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420), value: 1);

  @override
  void didUpdateWidget(_Stamp old) {
    super.didUpdateWidget(old);
    if (old.stamp != widget.stamp && !MediaQuery.disableAnimationsOf(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value;
          final scale = t < .6
              ? 1.25 + (.96 - 1.25) * (t / .6)
              : .96 + .04 * ((t - .6) / .4);
          return Opacity(
              opacity: t < .6 ? .4 + .6 * (t / .6) : 1,
              child: Transform.scale(scale: scale, child: child));
        },
        child: widget.child,
      );
}

class _ZipRow extends StatelessWidget {
  const _ZipRow(
      {required this.entry,
      required this.on,
      required this.recommended,
      required this.onTap});
  final FC5CompendiumZipEntryPreview entry;
  final bool on, recommended;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final a = AppAccents.of(context);
    final s = Tr(context);
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    final off = !entry.canImport;
    final counts = _entryCounts(entry);
    Widget badge(String text, Color? accent) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
              color: accent == null
                  ? c.onSurface.withValues(alpha: .08)
                  : accent.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(999)),
          child: Text(text,
              style: TextStyle(
                  fontSize: 10.5,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: accent == null
                      ? c.onSurfaceVariant
                      : Color.lerp(c.onSurface, accent, .75))),
        );
    final row = AnimatedContainer(
      duration: dur,
      curve: AppMotion.standard,
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: on
            ? pageMix(c.secondary, .12, c.surfaceContainerLow)
            : c.surfaceContainerLow,
        borderRadius: BorderRadius.circular(on ? 18 : 22),
        border: Border.all(
            color: c.secondary.withValues(alpha: on ? .45 : 0),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Stamp(
          stamp: on ? 1 : 0,
          child: AnimatedContainer(
            duration: dur,
            curve: AppMotion.standard,
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? c.secondary : c.secondary.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(on ? 8 : 13),
              border: Border.all(
                  color: on ? c.secondary : c.outline,
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignInside),
            ),
            child: AnimatedOpacity(
              duration:
                  AppMotion.of(context, const Duration(milliseconds: 200)),
              opacity: on ? 1 : 0,
              child: LineIcon('check', size: 16, color: c.surface),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(entry.displayName,
                      style: TextStyle(
                          fontSize: 15,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          color: c.onSurface)),
                  if (recommended)
                    badge(s.t('рекомендуется', 'recommended'), a.at(3)),
                  if (entry.isCombinedCandidate)
                    badge(s.t('общий', 'combined'), a.at(5)),
                  if (off)
                    badge(s.t('не поддерживается', 'not supported'), null),
                ]),
            const SizedBox(height: 5),
            Text(entry.displayPath,
                style: TextStyle(
                    fontSize: 12.5,
                    fontFeatures: AppType.tabular,
                    color: c.onSurfaceVariant)),
            const SizedBox(height: 5),
            if (off)
              Text(
                  s.t('Нет поддерживаемого контента · монстры ${entry.monsters}',
                      'No supported content · monsters ${entry.monsters}'),
                  style: TextStyle(fontSize: 12.5, color: c.onSurfaceVariant))
            else ...[
              AnimatedOpacity(
                duration:
                    AppMotion.of(context, const Duration(milliseconds: 260)),
                opacity: on ? 1 : .45,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: ShelfBars(counts: counts, height: 6),
                ),
              ),
              const SizedBox(height: 5),
              Text(_entryStats(s, counts),
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: c.onSurface.withValues(alpha: .72))),
            ],
          ]),
        ),
      ]),
    );
    return Opacity(
      opacity: off ? .55 : 1,
      child: Semantics(
        checked: on,
        enabled: !off,
        child: onTap == null
            ? row
            : Pressable(scale: .985, onTap: onTap, child: row),
      ),
    );
  }
}

/// The make-up of a book or a module: a bar per kind, as wide as its share.
class ShelfBars extends StatelessWidget {
  const ShelfBars({super.key, required this.counts, this.height = 8});
  final List<int> counts;
  final double height;
  @override
  Widget build(BuildContext context) {
    final a = AppAccents.of(context);
    final total = counts.fold(0, (t, n) => t + n);
    if (total == 0) return SizedBox(height: height);
    final bars = <Widget>[
      for (var i = 0; i < counts.length; i++)
        if (counts[i] > 0)
          Expanded(
            flex: math.max(1, (counts[i] * 1000 / total).round()),
            child: Container(
                constraints: const BoxConstraints(minWidth: 6),
                decoration: BoxDecoration(
                    color: a.at(i),
                    borderRadius: BorderRadius.circular(height / 2))),
          ),
    ];
    return SizedBox(
      height: height,
      child: Row(children: [
        for (var i = 0; i < bars.length; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          bars[i],
        ],
      ]),
    );
  }
}

class _ReadJob {
  _ReadJob(this.name, this.run, {this.monsters = 0});
  final String name;
  final Future<CompendiumImportResult> Function() run;
  final int monsters;
  CompendiumImportResult? result;
  Object? error;
  bool started = false, done = false;
}

/// Runs the import one module after another, independent of the sheet:
/// closing the sheet early does not stop the reading.
class _ReadRun extends ChangeNotifier {
  _ReadRun(this.jobs);
  final List<_ReadJob> jobs;
  final totals = List.filled(6, 0);
  final diagnostics = FC5ParseDiagnostics();
  int duplicates = 0, unsupported = 0, imported = 0, failed = 0;
  bool finished = false, _started = false;

  int get monsters => jobs.fold(0, (n, j) => n + j.monsters);
  String? get firstSourceId {
    for (final j in jobs) {
      if (j.result != null) return j.result!.sourceId;
    }
    return null;
  }

  bool get hasDetails => diagnostics.entries.any(_visible);

  static bool _visible(FC5Diagnostic entry) {
    if (entry.severity != FC5DiagnosticSeverity.info) return true;
    return const {
      'duplicates_skipped',
      'unsupported_nodes_skipped',
      'class_overlays_aggregated',
    }.contains(entry.code);
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    for (final j in jobs) {
      j.started = true;
      notifyListeners();
      // Each module takes at least a moment, so its pages are seen to turn.
      final pause = Future<void>.delayed(const Duration(milliseconds: 700));
      try {
        final r = await j.run();
        j.result = r;
        imported++;
        final parsed = r.parseResult;
        final n = [
          parsed.items.length,
          parsed.spells.length,
          parsed.races.length,
          parsed.classes.length,
          parsed.backgrounds.length,
          parsed.feats.length
        ];
        for (var i = 0; i < 6; i++) {
          totals[i] += n[i];
        }
        duplicates += r.skippedDuplicateCount;
        unsupported += r.skippedUnsupportedCount;
        diagnostics.merge(r.diagnostics);
      } catch (e) {
        j.error = e;
        if (e is ImportServiceException) {
          diagnostics.merge(e.diagnostics);
          if (e.diagnostics.entries.any((d) => d.code == 'duplicate_source')) {
            duplicates++;
          }
        } else {
          diagnostics.error('zip_entry_import_failed', 'Failed to import: $e',
              context: j.name);
        }
        failed++;
      }
      await pause;
      j.done = true;
      HapticFeedback.selectionClick();
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 160));
    }
    finished = true;
    HapticFeedback.mediumImpact();
    notifyListeners();
  }
}

Future<void> _readingSheet(BuildContext context, _ReadRun run,
    {required String kind, required String title}) async {
  await showCompanionSheet<void>(context,
      builder: (_) => _ReadingSheet(run: run, kind: kind, title: title));
  // The sheet may be closed early; the import still finishes.
  if (!run.finished) {
    final done = Completer<void>();
    void check() {
      if (run.finished && !done.isCompleted) done.complete();
    }

    run.addListener(check);
    await done.future;
    run.removeListener(check);
  }
}

class _ReadingSheet extends StatefulWidget {
  const _ReadingSheet(
      {required this.run, required this.kind, required this.title});
  final _ReadRun run;
  final String kind, title;
  @override
  State<_ReadingSheet> createState() => _ReadingSheetState();
}

class _ReadingSheetState extends State<_ReadingSheet> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 300), widget.run.start);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final a = AppAccents.of(context);
    final s = Tr(context);
    return ListenableBuilder(
      listenable: widget.run,
      builder: (context, _) {
        final run = widget.run;
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageSheetHead(
                  kicker: widget.kind,
                  title: s.t(
                      'Читаем «${widget.title}»', 'Reading «${widget.title}»')),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _FlippingBook(open: !run.finished),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(children: [
                    for (final j in run.jobs) ...[
                      _ReadRow(job: j),
                      const SizedBox(height: 8),
                    ],
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              PageGrid3(gap: 6, children: [
                for (final k in ShelfKind.values)
                  PageCount(
                      value: run.totals[k.index],
                      label: k.label(s),
                      accent: a.at(k.index),
                      size: 17,
                      base: Colors.transparent),
              ]),
              PageReveal(
                open: run.finished &&
                    (run.duplicates > 0 || run.monsters > 0 || run.failed > 0),
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: PageNote(
                      [
                        s.t('Пропущено дублей: ${run.duplicates}; монстров: ${run.monsters}.',
                            'Duplicates skipped: ${run.duplicates}; monsters: ${run.monsters}.'),
                        if (run.failed > 0)
                          s.t('Не прочитано модулей: ${run.failed}.',
                              'Modules not read: ${run.failed}.'),
                      ].join(' '),
                      accent: run.failed > 0 ? a.at(1) : null,
                      icon: run.failed > 0 ? 'warn' : 'info'),
                ),
              ),
              if (run.finished && run.hasDetails) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ToneButton(
                    label: s.t('Подробности импорта', 'Import details'),
                    icon: LineIcon('info', size: 18, color: c.onSurface),
                    height: 40,
                    onPressed: () => showCompanionSheet<void>(context,
                        builder: (_) => _DiagnosticsSheet(run.diagnostics)),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              ToneButton(
                label: s.t('Готово', 'Done'),
                kind: ToneKind.primary,
                height: 54,
                fontSize: 15,
                expand: true,
                onPressed: run.finished
                    ? () => Navigator.of(context).maybePop()
                    : null,
              ),
            ]);
      },
    );
  }
}

class _ReadRow extends StatelessWidget {
  const _ReadRow({required this.job});
  final _ReadJob job;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final a = AppAccents.of(context);
    final s = Tr(context);
    final r = job.result?.parseResult;
    final status = !job.started
        ? s.t('ждёт', 'waiting')
        : !job.done
            ? s.t('читаем…', 'reading…')
            : job.error != null
                ? s.t('не прочитано', 'not read')
                : (r == null
                    ? ''
                    : _entryStats(s, [
                        r.items.length,
                        r.spells.length,
                        r.races.length,
                        r.classes.length,
                        r.backgrounds.length,
                        r.feats.length
                      ]));
    return AnimatedOpacity(
      duration: AppMotion.of(context, const Duration(milliseconds: 300)),
      opacity: job.started ? 1 : .5,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageTitle(job.name, status.isEmpty ? s.t('пусто', 'empty') : status),
        const SizedBox(height: 6),
        _Bar(
          value: job.done ? 1 : (job.started ? null : 0),
          color:
              job.done ? (job.error != null ? a.at(0) : a.at(3)) : c.secondary,
          height: 5,
        ),
      ]),
    );
  }
}

/// A thin bar: a known share, or a fill that runs while the work goes on.
class _Bar extends StatefulWidget {
  const _Bar({required this.value, required this.color, this.height = 5});
  final double? value;
  final Color color;
  final double height;
  @override
  State<_Bar> createState() => _BarState();
}

class _BarState extends State<_Bar> with SingleTickerProviderStateMixin {
  late final _run = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Bar old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.value == null) {
      // Fills over the module's moment and waits near the end.
      if (!_run.isAnimating && _run.value == 0) {
        _run.animateTo(.92, curve: const Cubic(.4, 0, .2, 1));
      }
    } else {
      _run.animateTo(widget.value!,
          duration: const Duration(milliseconds: 240),
          curve: AppMotion.standard);
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.height / 2),
      child: SizedBox(
        height: widget.height,
        child: ColoredBox(
          color: c.onSurface.withValues(alpha: .1),
          child: AnimatedBuilder(
            animation: _run,
            builder: (context, _) => Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: _run.value,
                heightFactor: 1,
                child: AnimatedContainer(
                    duration: AppMotion.of(context, AppMotion.medium),
                    decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius:
                            BorderRadius.circular(widget.height / 2))),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A book whose pages turn while it is being read; it shuts when done.
class _FlippingBook extends StatefulWidget {
  const _FlippingBook({required this.open});
  final bool open;
  @override
  State<_FlippingBook> createState() => _FlippingBookState();
}

class _FlippingBookState extends State<_FlippingBook>
    with SingleTickerProviderStateMixin {
  late final _t = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_FlippingBook old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.open && !MediaQuery.disableAnimationsOf(context)) {
      if (!_t.isAnimating) _t.repeat();
    } else {
      _t.stop();
      _t.value = 0;
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final cover = AppAccents.of(context).at(1);
    final paper = pageMix(c.onSurface, .85, c.surface);
    Widget page(Color color, double turn) => Transform(
          alignment: Alignment.centerLeft,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 1 / 300)
            ..rotateY(-math.pi * turn),
          child: Container(
            width: 32,
            height: 84,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(2), right: Radius.circular(6)),
              border: Border.all(color: Colors.black.withValues(alpha: .12)),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SizedBox(
        width: 64,
        height: 84,
        child: AnimatedBuilder(
          animation: _t,
          builder: (context, _) {
            double phase(double delay) {
              if (!widget.open) return 0;
              final v = (_t.value - delay) % 1;
              return const Cubic(.4, 0, .2, 1).transform(v < 0 ? v + 1 : v);
            }

            return Stack(children: [
              Positioned(
                left: 0,
                child: Container(
                  width: 32,
                  height: 84,
                  decoration: BoxDecoration(
                      color: cover,
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(6), right: Radius.circular(2))),
                ),
              ),
              Positioned(left: 32, child: page(paper, phase(0))),
              Positioned(left: 32, child: page(paper, phase(1 / 3))),
              Positioned(left: 32, child: page(cover, phase(2 / 3))),
            ]);
          },
        ),
      ),
    );
  }
}

class _DiagnosticsSheet extends StatelessWidget {
  const _DiagnosticsSheet(this.diagnostics);
  final FC5ParseDiagnostics diagnostics;
  @override
  Widget build(BuildContext context) {
    final a = AppAccents.of(context);
    final c = Theme.of(context).colorScheme;
    final s = Tr(context);
    final entries = diagnostics.entries.where(_ReadRun._visible).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageSheetHead(
          kicker: s.t('Импорт', 'Import'),
          title: s.t('Подробности', 'Details'),
          sub: s.plural(
              entries.length,
              const ['замечание', 'замечания', 'замечаний'],
              const ['note', 'notes'])),
      const SizedBox(height: 14),
      for (final e in entries) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: c.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18)),
          child: PageNote(
              e.context == null ? e.message : '${e.message}\n${e.context}',
              icon: e.severity == FC5DiagnosticSeverity.info ? 'info' : 'warn',
              accent: switch (e.severity) {
                FC5DiagnosticSeverity.error => a.at(0),
                FC5DiagnosticSeverity.warning => a.at(1),
                _ => null,
              }),
        ),
        const SizedBox(height: 8),
      ],
    ]);
  }
}
