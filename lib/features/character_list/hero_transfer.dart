import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/character.dart';
import '../../core/services/fc5_export_service.dart';
import '../../core/services/fc5_parser.dart';
import '../../core/services/import_service.dart';
import '../../core/services/qdnd_bundle_export_service.dart';
import '../../core/services/qdnd_bundle_file_service.dart';
import '../../core/services/qdnd_bundle_import_service.dart';
import '../../core/services/qdnd_bundle_schema.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_palettes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/companion_kit.dart';
import '../../core/ui/page_kit.dart';
import 'widgets/character_roster_visuals.dart';

/// Moving heroes between devices and apps (wave 5): the transfer sheet with
/// two formats, the incoming hero sheet, and the hero picker of Settings.

Color _heroAccent(BuildContext context, Character h) => AppAccents.of(context)
    .forClass(h.classes.isEmpty ? h.characterClass : h.classes.first.id);

String _heroLine(BuildContext context, Character h) =>
    '${getLocalizedRaceName(context, h.race)} · '
    '${getCharacterClassSummary(context, h)} ${h.level}';

String _fileStem(String name) {
  final s = name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9а-яё]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return s.isEmpty ? 'character' : s;
}

/// A hero's letter in a rounded square of their accent.
class HeroBadge extends StatelessWidget {
  const HeroBadge(
      {super.key, required this.name, required this.accent, this.size = 52});
  final String name;
  final Color accent;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: accent, borderRadius: BorderRadius.circular(size * .35)),
      child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: TextStyle(
              fontFamily: AppType.display,
              fontSize: size * .43,
              fontWeight: FontWeight.w600,
              color: pageOnAccent(c))),
    );
  }
}

/// A row of a sheet's list: a leading mark, a title with a line, a chevron.
class SheetListRow extends StatelessWidget {
  const SheetListRow(
      {super.key,
      required this.leading,
      required this.title,
      required this.subtitle,
      this.onTap,
      this.accent,
      this.index});
  final Widget leading;
  final String title, subtitle;
  final VoidCallback? onTap;

  /// A faint wash of the row's colour from its leading corner.
  final Color? accent;

  /// Its place in the list: rows arrive one after another.
  final int? index;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final tint = accent;
    final row = Opacity(
      opacity: onTap == null ? .5 : 1,
      child: Pressable(
        scale: .98,
        haptic: true,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
              color: tint == null ? c.surfaceContainerLow : null,
              gradient: tint == null
                  ? null
                  : LinearGradient(
                      begin: const Alignment(-1, -.6),
                      end: const Alignment(1, .6),
                      stops: const [0, .55],
                      colors: [
                        pageMix(tint, .1 * AppCalm.of(context).glow,
                            c.surfaceContainerLow),
                        c.surfaceContainerLow
                      ]),
              borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            leading,
            const SizedBox(width: 12),
            Expanded(child: PageTitle(title, subtitle)),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              LineIcon('forward', size: 18, color: c.onSurfaceVariant),
            ],
          ]),
        ),
      ),
    );
    return index == null ? row : PageEntrance(index: index!, child: row);
  }
}

/// From Settings: which hero to move, or bring one in from a file.
Future<void> showHeroTransferPicker(BuildContext context) {
  final s = Tr(context);
  List<Character> heroes;
  try {
    heroes = StorageService.getAllCharacters();
  } catch (_) {
    heroes = const [];
  }
  return showCompanionSheet<void>(context, builder: (sheet) {
    final a = AppAccents.of(sheet);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageSheetHead(
          kicker: s.t('Перенос', 'Move'),
          title: s.t('Какого героя?', 'Which hero?')),
      const SizedBox(height: 14),
      for (final (i, h) in heroes.indexed) ...[
        SheetListRow(
          accent: _heroAccent(sheet, h),
          index: i,
          leading:
              HeroBadge(name: h.name, accent: _heroAccent(sheet, h), size: 40),
          title: h.name,
          subtitle: _heroLine(sheet, h),
          onTap: () {
            Navigator.of(sheet).pop();
            Future.microtask(() {
              if (context.mounted) showHeroTransfer(context, h);
            });
          },
        ),
        const SizedBox(height: 6),
      ],
      SheetListRow(
        accent: a.at(3),
        index: heroes.length,
        leading: PageSeal('download', accent: a.at(3)),
        title: s.t('Принять героя из файла', 'Bring a hero in from a file'),
        subtitle: '.qdnd · .xml',
        onTap: () {
          Navigator.of(sheet).pop();
          Future.microtask(() {
            if (context.mounted) importHero(context);
          });
        },
      ),
    ]);
  });
}

/// The transfer sheet of one hero.
Future<void> showHeroTransfer(BuildContext context, Character hero) =>
    showCompanionSheet<void>(context, builder: (_) => _TransferSheet(hero));

enum _Format { qdnd, xml }

class _TransferSheet extends StatefulWidget {
  const _TransferSheet(this.hero);
  final Character hero;
  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  var _format = _Format.qdnd;
  var _own = true;
  var _busy = false;

  /// The saved file once it is written: its name and a line about it.
  (String, String)? _saved;
  Uint8List? _bytes;

  Future<void> _save() async {
    final s = Tr(context);
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    final qdnd = _format == _Format.qdnd;
    try {
      final file = '${_fileStem(widget.hero.name)}.${qdnd ? 'qdnd' : 'xml'}';
      final Uint8List bytes;
      String line;
      if (qdnd) {
        final r = await QdndBundleExportService.exportCharacter(widget.hero,
            options: QdndBundleExportOptions(includeUserCreatedContent: _own));
        bytes = r.bytes;
        line = _own
            ? s.t(
                'Вложено своего контента: ${r.embeddedContentCount} · ссылок на библиотеки: ${r.dependencyCount}',
                'Own content inside: ${r.embeddedContentCount} · library links: ${r.dependencyCount}')
            : s.t('Ссылок на библиотеки: ${r.dependencyCount}',
                'Library links: ${r.dependencyCount}');
      } else {
        final r = await FC5ExportService.exportCharacter(widget.hero);
        bytes = r.bytes;
        line = s.t('Лист персонажа в XML', 'Character sheet as XML');
      }
      final path = await FilePicker.platform.saveFile(
        dialogTitle: s.t('Сохранить героя', 'Save the hero'),
        fileName: file,
        type: FileType.custom,
        allowedExtensions: [qdnd ? 'qdnd' : 'xml'],
        bytes: bytes,
      );
      if (!mounted) return;
      if (path == null) {
        setState(() => _busy = false);
        return;
      }
      if (!Platform.isAndroid && !Platform.isIOS) {
        await File(path).writeAsBytes(bytes, flush: true);
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _busy = false;
        _bytes = bytes;
        _saved = (path.split(Platform.pathSeparator).last, line);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackBar.error(
          context, s.t('Не удалось сохранить: $e', 'Could not save: $e'));
    }
  }

  /// Saves one more copy elsewhere — the system's own place to put files.
  Future<void> _again() async {
    final saved = _saved, bytes = _bytes;
    if (saved == null || bytes == null) return;
    await FilePicker.platform.saveFile(fileName: saved.$1, bytes: bytes);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final a = AppAccents.of(context);
    final s = Tr(context);
    final h = widget.hero;
    final acc = _heroAccent(context, h);
    final qdnd = _format == _Format.qdnd;
    final dur = AppMotion.of(context, const Duration(milliseconds: 420));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      HeroHeadCard(name: h.name, accent: acc, cap: _heroLine(context, h)),
      const SizedBox(height: 14),
      PageSheetHead(
          title: s.t('Перенести героя', 'Move the hero'),
          sub: s.t(
              'Файл можно открыть на другом устройстве через «Добавить героя» или в другом приложении.',
              'Open the file on another device with «Add a hero» or in another app.')),
      const SizedBox(height: 14),
      AnimatedSwitcher(
        duration: dur,
        switchInCurve: AppMotion.snappyCurve,
        switchOutCurve: AppMotion.exit,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: AnimatedBuilder(
              animation: anim,
              builder: (context, child) => Transform.translate(
                  offset: Offset(0, 14 * (1 - anim.value)), child: child),
              child: child),
        ),
        layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, if (current != null) current]),
        child: _saved == null
            ? Column(
                key: const ValueKey('pick'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    _FormatCard(
                      on: qdnd,
                      accent: a.at(1),
                      icon: 'layers',
                      title: s.t('Полная копия', 'Full copy'),
                      note: s.t('.qdnd · для QDnD', '.qdnd · for QDnD'),
                      lines: [
                        (
                          s.t('Лист, ресурсы и состояния',
                              'Sheet, resources and conditions'),
                          true
                        ),
                        (
                          s.t('Журнал, задания и Атлас',
                              'Journal, quests and the Atlas'),
                          true
                        ),
                        (s.t('История развития', 'Advancement history'), true),
                        (
                          s.t('Ссылки на библиотеки', 'Links to libraries'),
                          true
                        ),
                      ],
                      onTap: () => _pick(_Format.qdnd),
                    ),
                    const SizedBox(height: 8),
                    _FormatCard(
                      on: !qdnd,
                      accent: a.at(4),
                      icon: 'file',
                      title: s.t('Лист в XML', 'Sheet as XML'),
                      note: s.t('.xml · для других приложений',
                          '.xml · for other apps'),
                      lines: [
                        (
                          s.t('Характеристики, навыки, снаряжение',
                              'Abilities, skills, equipment'),
                          true
                        ),
                        (
                          s.t('Заклинания и умения', 'Spells and features'),
                          true
                        ),
                        (
                          s.t('Журнал и история не переносятся',
                              'Journal and history stay behind'),
                          false
                        ),
                      ],
                      onTap: () => _pick(_Format.xml),
                    ),
                    PageReveal(
                      open: qdnd,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: PageRow(
                          leading: PageSeal('star', accent: a.at(1)),
                          title: s.t(
                              'Вложить свой контент', 'Pack your own content'),
                          subtitle: s.t(
                              'Свои классы, умения и предметы героя поедут вместе с ним',
                              'The hero\'s own classes, features and items travel along'),
                          trailing: PageSwitch(value: _own),
                          toggled: _own,
                          onTap: () {
                            pageTick();
                            setState(() => _own = !_own);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ToneButton(
                      label: _busy
                          ? s.t('Сохраняем…', 'Saving…')
                          : s.t('Сохранить ${qdnd ? '.qdnd' : '.xml'}',
                              'Save ${qdnd ? '.qdnd' : '.xml'}'),
                      icon: LineIcon('upload', size: 20, color: c.onPrimary),
                      kind: ToneKind.primary,
                      height: 56,
                      fontSize: 15,
                      expand: true,
                      onPressed: _busy ? null : _save,
                    ),
                  ])
            : Column(
                key: const ValueKey('saved'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    _SavedFile(
                        name: _saved!.$1,
                        line: _saved!.$2,
                        accent: qdnd ? a.at(1) : a.at(4),
                        icon: qdnd ? 'layers' : 'file'),
                    const SizedBox(height: 14),
                    PageNote(
                        s.t('Файл сохранён. Отправьте его на другое устройство и откройте там через «Добавить героя».',
                            'The file is saved. Send it to another device and open it there with «Add a hero».'),
                        icon: 'check',
                        size: 13.5),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: ToneButton(
                          label: s.t('Ещё копия', 'One more copy'),
                          icon: LineIcon('share', size: 19, color: c.onSurface),
                          height: 52,
                          expand: true,
                          onPressed: _again,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ToneButton(
                          label: s.t('Готово', 'Done'),
                          kind: ToneKind.primary,
                          height: 52,
                          expand: true,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ]),
                  ]),
      ),
    ]);
  }

  void _pick(_Format f) {
    if (_format == f) return;
    HapticFeedback.selectionClick();
    setState(() => _format = f);
  }
}

/// A hero at the head of a sheet: their letter, a caps line and the name.
class HeroHeadCard extends StatelessWidget {
  const HeroHeadCard(
      {super.key,
      required this.name,
      required this.accent,
      required this.cap,
      this.line});
  final String name, cap;
  final String? line;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
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
              pageMix(accent, .09 * AppCalm.of(context).glow,
                  c.surfaceContainerLow),
              c.surfaceContainerLow
            ]),
      ),
      child: Row(children: [
        HeroBadge(name: name, accent: accent),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PageCap(cap, accent: accent),
            const SizedBox(height: 4),
            Text(name,
                style: TextStyle(
                    fontFamily: AppType.display,
                    fontSize: 19,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: c.onSurface)),
            if (line != null) ...[
              const SizedBox(height: 3),
              Text(line!,
                  style: TextStyle(fontSize: 12.5, color: c.onSurfaceVariant)),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// A format to save in. Only the chosen one carries its colour: corners
/// firm up, a thin ring, its seal fills and turns a little. The other
/// stays neutral, so the sheet holds one accent at a time.
class _FormatCard extends StatelessWidget {
  const _FormatCard(
      {required this.on,
      required this.accent,
      required this.icon,
      required this.title,
      required this.note,
      required this.lines,
      required this.onTap});
  final bool on;
  final Color accent;
  final String icon, title, note;
  final List<(String, bool)> lines;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    return Semantics(
      selected: on,
      button: true,
      child: Pressable(
        scale: .985,
        onTap: onTap,
        child: AnimatedContainer(
          duration: dur,
          curve: AppMotion.standard,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: on
                ? pageMix(accent, .07, c.surfaceContainerLow)
                : c.surfaceContainerLow,
            borderRadius: BorderRadius.circular(on ? 18 : 26),
            border: Border.all(
                color: accent.withValues(alpha: on ? .5 : 0),
                width: 1.5,
                strokeAlign: BorderSide.strokeAlignInside),
          ),
          child: Stack(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      AnimatedRotation(
                        turns: on ? -6 / 360 : 0,
                        duration: dur,
                        curve: AppMotion.snappyCurve,
                        child: AnimatedContainer(
                          duration: dur,
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: on
                                  ? accent
                                  : c.onSurface.withValues(alpha: .07),
                              borderRadius: BorderRadius.circular(18)),
                          child: LineIcon(icon,
                              size: 26,
                              color:
                                  on ? pageOnAccent(c) : c.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: PageTitle(title, note)),
                      AnimatedScale(
                        scale: on ? 1 : 0,
                        duration: dur,
                        curve: AppMotion.snappyCurve,
                        child: Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(9)),
                          child: LineIcon('check',
                              size: 16, color: pageOnAccent(c)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(left: 64),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final (text, yes) in lines) ...[
                              Row(children: [
                                LineIcon(yes ? 'check' : 'x',
                                    size: 15,
                                    color: yes && on
                                        ? Color.lerp(c.onSurface, accent, .7)
                                        : c.onSurfaceVariant),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(text,
                                      style: TextStyle(
                                          fontSize: 13,
                                          height: 1.3,
                                          color: yes
                                              ? c.onSurface
                                                  .withValues(alpha: .82)
                                              : c.onSurfaceVariant)),
                                ),
                              ]),
                              const SizedBox(height: 5),
                            ],
                          ]),
                    ),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SavedFile extends StatelessWidget {
  const _SavedFile(
      {required this.name,
      required this.line,
      required this.accent,
      required this.icon});
  final String name, line, icon;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final heal = AppAccents.of(context).at(3);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
            begin: const Alignment(-.5, -1),
            end: const Alignment(.5, 1),
            stops: const [
              0,
              .75
            ],
            colors: [
              pageMix(accent, .09 * AppCalm.of(context).glow,
                  c.surfaceContainerLow),
              c.surfaceContainerLow
            ]),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageSeal(icon, accent: accent, size: PageSealSize.lg),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: PageTitle(name, line),
          ),
        ),
        const SizedBox(width: 8),
        JournalPopIn(
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: heal, borderRadius: BorderRadius.circular(9)),
            child: LineIcon('check', size: 16, color: c.surface),
          ),
        ),
      ]),
    );
  }
}

/// Pops a small mark in from nothing on its first frame.
class JournalPopIn extends StatelessWidget {
  const JournalPopIn({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(
            begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0, end: 1),
        duration: AppMotion.of(context, AppMotion.snappySettle),
        curve: AppMotion.snappyCurve,
        builder: (context, v, child) => Transform.scale(scale: v, child: child),
        child: child,
      );
}

/// Bringing a hero in: picks a file, shows who arrives and what they need,
/// and adds them to the party. [qdnd] null lets the file decide.
Future<Character?> importHero(BuildContext context, {bool? qdnd}) async {
  final s = Tr(context);
  try {
    final picked = await FilePicker.platform.pickFiles(
      type: qdnd == false ? FileType.custom : FileType.any,
      allowedExtensions: qdnd == false ? ['xml'] : null,
      withReadStream: qdnd != false,
    );
    if (picked == null || picked.files.isEmpty || !context.mounted) return null;
    final f = picked.files.single;
    final isXml = qdnd == false ||
        (qdnd == null &&
            (f.extension ?? f.name.split('.').last).toLowerCase() == 'xml');
    if (isXml) {
      final file = File(f.path!);
      final xml = await file.readAsString();
      final parsed = FC5Parser.parseCharacters(xml);
      if (!context.mounted) return null;
      if (parsed.candidates.isEmpty) {
        AppSnackBar.error(
            context,
            s.t('В файле нет героя, которого можно принять',
                'No hero to bring in found in the file'));
        return null;
      }
      final hero = parsed.candidates.first.character;
      final warnings = [
        for (final d in parsed.diagnostics.entries)
          if (d.severity != FC5DiagnosticSeverity.info) d.message
      ];
      final ok = await showCompanionSheet<bool>(context,
          builder: (_) => _IncomingSheet(
              kicker: s.t('Лист персонажа · .xml', 'Character sheet · .xml'),
              cap: s.t('Лист персонажа', 'Character sheet'),
              hero: hero,
              warnings: warnings));
      if (ok != true || !context.mounted) return null;
      final result = await ImportService.importCharactersFromFC5File(file);
      if (!context.mounted) return null;
      HapticFeedback.mediumImpact();
      final first = result.characters.first;
      AppSnackBar.success(context,
          s.t('${first.name} в отряде', '${first.name} joined the party'));
      return first;
    }
    final bytes = await QdndBundleFileService.readPlatformFile(f);
    final preview = await QdndBundleImportService.previewBytes(bytes);
    if (!context.mounted) return null;
    final ok = await showCompanionSheet<bool>(context,
        builder: (_) => _IncomingSheet(
                kicker: s.t('Файл QDnD · .qdnd', 'QDnD file · .qdnd'),
                cap: s.t('Полная копия', 'Full copy'),
                preview: preview,
                warnings: [
                  if (preview.missingDependencyCount > 0)
                    s.t('Чего-то из библиотек героя у вас нет (${preview.missingDependencyCount}) — оно сохранится текстом',
                        'Some of the hero\'s library content is missing here (${preview.missingDependencyCount}) — it is kept as text'),
                ]));
    if (ok != true || !context.mounted) return null;
    final result = await QdndBundleImportService.importBytes(bytes);
    if (!context.mounted) return null;
    HapticFeedback.mediumImpact();
    final warns = result.diagnostics
        .where((d) => d.severity == QdndBundleDiagnosticSeverity.warning)
        .length;
    final name = result.character.name;
    AppSnackBar.success(
        context,
        warns > 0
            ? s.t('$name в отряде · замечаний: $warns',
                '$name joined the party · notes: $warns')
            : s.t('$name в отряде', '$name joined the party'));
    return result.character;
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.error(
          context,
          s.t('Не удалось принять героя: $e',
              'Could not bring the hero in: $e'));
    }
    return null;
  }
}

class _IncomingSheet extends StatelessWidget {
  const _IncomingSheet(
      {required this.kicker,
      required this.cap,
      this.hero,
      this.preview,
      this.warnings = const []});
  final String kicker, cap;
  final Character? hero;
  final QdndBundleImportPreview? preview;
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final a = AppAccents.of(context);
    final s = Tr(context);
    final h = hero;
    final p = preview;
    final name = h?.name ?? p?.characterName ?? '?';
    final acc = h != null
        ? _heroAccent(context, h)
        : a.forClass(p?.classes.firstOrNull ?? '');
    final line = h != null
        ? _heroLine(context, h)
        : [
            if (p != null && p.classes.isNotEmpty) p.classes.join(' / '),
            if (p != null) s.t('ур. ${p.level}', 'level ${p.level}'),
          ].join(' · ');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageSheetHead(
          kicker: kicker, title: s.t('Принять героя', 'Bring the hero in')),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
              begin: const Alignment(-.5, -1),
              end: const Alignment(.5, 1),
              stops: const [
                0,
                .7
              ],
              colors: [
                pageMix(
                    acc, .16 * AppCalm.of(context).glow, c.surfaceContainerLow),
                c.surfaceContainerLow
              ]),
        ),
        child: Row(children: [
          HeroBadge(name: name, accent: acc, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PageCap(cap, accent: acc),
              const SizedBox(height: 4),
              Text(name,
                  style: TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 20,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: c.onSurface)),
              const SizedBox(height: 3),
              Text(line,
                  style: TextStyle(fontSize: 12.5, color: c.onSurfaceVariant)),
            ]),
          ),
        ]),
      ),
      if (p != null) ...[
        const SizedBox(height: 14),
        PageGrid3(children: [
          PageCount(
              value: p.embeddedContentCount,
              label: s.t('вложено', 'packed in'),
              accent: a.at(3),
              tint: .12),
          PageCount(
              value: p.resolvedDependencyCount,
              label: s.t('найдено в библиотеках', 'found in libraries'),
              accent: a.at(4),
              tint: .12),
          PageCount(
              value: p.missingDependencyCount,
              label: s.t('нет у вас', 'missing here'),
              accent: a.at(0),
              tint: .12),
        ]),
      ],
      if (warnings.isNotEmpty) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: a.at(1).withValues(alpha: .09),
              borderRadius: BorderRadius.circular(22)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              LineIcon('warn',
                  size: 18, color: Color.lerp(c.onSurface, a.at(1), .75)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    s.plural(warnings.length, const [
                      'поле требует внимания',
                      'поля требуют внимания',
                      'полей требуют внимания'
                    ], const [
                      'field needs attention',
                      'fields need attention'
                    ]),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color.lerp(c.onSurface, a.at(1), .75))),
              ),
            ]),
            for (final w in warnings.take(6)) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(w,
                    style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: c.onSurface.withValues(alpha: .84))),
              ),
            ],
          ]),
        ),
      ],
      const SizedBox(height: 14),
      ToneButton(
        label: s.t('Добавить в отряд', 'Add to the party'),
        icon: LineIcon('plus', size: 20, color: c.onPrimary),
        kind: ToneKind.primary,
        height: 54,
        fontSize: 15,
        expand: true,
        onPressed: () => Navigator.of(context).pop(true),
      ),
    ]);
  }
}
