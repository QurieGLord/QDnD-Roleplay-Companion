import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_info.dart';
import '../../core/models/character.dart';
import '../../core/models/compendium_source.dart';
import '../../core/services/locale_provider.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/theme_provider.dart';
import '../../core/theme/app_palettes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/companion_kit.dart';
import '../../core/ui/expressive_kit.dart';
import '../../core/ui/page_kit.dart';
import '../character_list/hero_transfer.dart';
import '../character_list/widgets/character_roster_visuals.dart';
import '../character_sheet/widgets/class_widgets/instrument/instrument_kit.dart';
import '../journal/journal_kit.dart';
import 'library_manager_screen.dart';
import 'library_shelf.dart';

/// Settings as a stage (wave 5, variant A «Витрина»): a live preview of a
/// hero's sheet sits on top and every palette, mode or Basic mode change
/// morphs the whole app — the preview is the app itself.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _scroll = ScrollController();
  bool _titled = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final titled = _scroll.offset > 64;
      if (titled != _titled) setState(() => _titled = titled);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final theme = context.watch<ThemeProvider>();
    final locale = context.watch<LocaleProvider>();
    final s = Tr(context);
    final accents = AppAccents.of(context);
    final canPop = Navigator.of(context).canPop();
    final top = MediaQuery.paddingOf(context).top;
    const gap = SizedBox(height: 14);
    return Scaffold(
      backgroundColor: c.surface,
      body: Stack(children: [
        SingleChildScrollView(
          key: const Key('settings_scroll_view'),
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(0, top + 80, 0, 60),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final child in <Widget>[
              PageMasthead(
                  cap: 'QDnD · ${AppInfo.short}',
                  title: s.t('Настройки', 'Settings')),
              gap,
              const _Stage(),
              gap,
              _PaletteName(basic: theme.isBasicMode, preset: theme.colorPreset),
              const SizedBox(height: 6),
              _PaletteStrip(
                selected: theme.colorPreset,
                basic: theme.isBasicMode,
                onPick: (p) {
                  if (p == theme.colorPreset) return;
                  pageTick();
                  theme.setColorPreset(p);
                },
              ),
              const SizedBox(height: 8),
              _Modes(
                key: const Key('settings_theme_segmented'),
                mode: theme.themeMode,
                onPick: (m) {
                  if (m == theme.themeMode) return;
                  pageTick();
                  theme.setThemeMode(m);
                },
              ),
              const SizedBox(height: 22),
              PageRow(
                key: const Key('settings_basic_mode_toggle'),
                leading: PageSeal('calm', accent: accents.at(3)),
                title: s.t('Базовый режим', 'Basic mode'),
                subtitle: s.t(
                    'Та же палитра, но тише: меньше пестроты, больше контраста и читаемости, без свечений',
                    'The same palette, quieter: less colour, more contrast and readability, no glows'),
                trailing: PageSwitch(value: theme.isBasicMode),
                toggled: theme.isBasicMode,
                onTap: () {
                  pageTick();
                  theme.setBasicMode(!theme.isBasicMode);
                },
              ),
              const SizedBox(height: 8),
              PageRow(
                leading: PageSeal('globe', accent: accents.at(4)),
                title: s.t('Язык', 'Language'),
                subtitle: s.t(
                    'Интерфейс и названия правил', 'Interface and rule names'),
                trailing: _LanguagePill(
                  key: const Key('settings_language_segmented'),
                  code: locale.locale.languageCode,
                  onPick: (code) {
                    if (code == locale.locale.languageCode) return;
                    pageTick();
                    locale.setLocale(Locale(code));
                  },
                ),
              ),
              PageSection(s.t('Контент', 'Content')),
              gap,
              const _LibraryTile(),
              const SizedBox(height: 8),
              PageRow(
                leading: PageSeal('share', accent: accents.at(1)),
                title: s.t('Перенос героев', 'Move heroes'),
                subtitle: s.t(
                    'Файл QDnD для другого устройства или XML для других приложений',
                    'A QDnD file for another device or XML for other apps'),
                chevron: true,
                onTap: () => showHeroTransferPicker(context),
              ),
              PageSection(s.t('О приложении', 'About')),
              gap,
              const _About(),
              const SizedBox(height: 14),
              const _Footer(),
            ])
              // The palette strip runs from edge to edge.
              child is _PaletteStrip
                  ? child
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: child),
          ]),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: JournalTopBar(
            titled: _titled,
            title: s.t('Настройки', 'Settings'),
            leading: canPop
                ? JournalRound(
                    icon: 'back',
                    label: s.t('Назад', 'Back'),
                    onTap: () => Navigator.of(context).maybePop())
                : null,
          ),
        ),
      ]),
    );
  }
}

/// The live stage: a hero's card, their health, a few chips and a line of
/// text, all in the current palette.
class _Stage extends StatelessWidget {
  const _Stage();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final a = AppAccents.of(context);
    final calm = AppCalm.of(context);
    final s = Tr(context);
    Character? hero;
    try {
      final all = StorageService.getAllCharacters();
      hero = all.isEmpty ? null : all.first;
    } catch (_) {
      hero = null;
    }
    final name = hero?.name ?? s.t('Элиан', 'Elian');
    final line = hero == null
        ? s.t('Человек · Паладин 18', 'Human · Paladin 18')
        : '${getLocalizedRaceName(context, hero.race)} · '
            '${getCharacterClassSummary(context, hero)} ${hero.level}';
    final hp = hero?.currentHp ?? 132;
    final maxHp = math.max(1, hero?.maxHp ?? 164);
    final ac = hero?.armorClass ?? 19;
    final acc = hero == null
        ? a.at(1)
        : a.forClass(
            hero.classes.isEmpty ? hero.characterClass : hero.classes.first.id);
    final heal = a.at(3);
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: const Alignment(-.5, -1),
          end: const Alignment(.5, 1),
          stops: const [0, .7],
          colors: [
            pageMix(a.at(1), .14 * calm.glow, c.surfaceContainerLow),
            c.surfaceContainerLow
          ],
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .8),
              blurRadius: 44,
              spreadRadius: -32,
              offset: const Offset(0, 22)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
              color: pageMix(acc, .14, c.surfaceContainer),
              borderRadius: BorderRadius.circular(22)),
          child: Stack(children: [
            Positioned(
              right: -30,
              top: -40,
              child: Container(
                width: 140,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(stops: const [
                    0,
                    .7
                  ], colors: [
                    acc.withValues(alpha: .3 * calm.glow),
                    acc.withValues(alpha: 0),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: acc, borderRadius: BorderRadius.circular(18)),
                  child: Text(name.isEmpty ? '?' : name.characters.first,
                      style: TextStyle(
                          fontFamily: AppType.display,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: pageOnAccent(c))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PageTitle(name, line),
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  RollingNumber(hp,
                      from: 0,
                      style: TextStyle(
                          fontFamily: AppType.display,
                          fontSize: 26,
                          height: 1,
                          fontWeight: FontWeight.w600,
                          fontFeatures: AppType.tabular,
                          color: heal)),
                  const SizedBox(height: 2),
                  Text('/ $maxHp',
                      style: TextStyle(
                          fontSize: 12,
                          fontFeatures: AppType.tabular,
                          color: c.onSurfaceVariant)),
                ]),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Stack(children: [
              Positioned.fill(
                  child: ColoredBox(color: c.onSurface.withValues(alpha: .1))),
              FractionallySizedBox(
                widthFactor: (hp / maxHp).clamp(0.0, 1.0),
                child: Container(
                    decoration: BoxDecoration(
                        color: heal, borderRadius: BorderRadius.circular(4))),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _StageChip(
              icon: 'spark',
              accent: a.at(0),
              label: s.t('Вдохновение', 'Inspiration')),
          _StageChip(
              icon: 'shield', accent: a.at(4), label: s.t('КД $ac', 'AC $ac')),
          _StageChip(icon: 'heart', accent: heal, label: s.t('Отдых', 'Rest')),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LineIcon('quote', size: 16, color: a.at(1)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                s.t('Привет, герой. Так выглядит твой лист.',
                    'Hello, hero. This is how your sheet looks.'),
                style: TextStyle(
                    fontSize: 13.5, height: 1.35, color: c.onSurfaceVariant)),
          ),
        ]),
      ]),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip(
      {required this.icon, required this.accent, required this.label});
  final String icon, label;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      height: 34,
      padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
      decoration: BoxDecoration(
          color: pageMix(accent, .18, c.surfaceContainer),
          borderRadius: BorderRadius.circular(17)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        LineIcon(icon, size: 16, color: accent),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: AppType.tabular,
                color: c.onSurface)),
      ]),
    );
  }
}

class _PaletteName extends StatelessWidget {
  const _PaletteName({required this.basic, required this.preset});
  final bool basic;
  final AppColorPreset preset;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final s = Tr(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageCap(
            basic
                ? s.t('Палитра · базовый режим', 'Palette · basic mode')
                : s.t('Палитра', 'Palette'),
            accent: AppAccents.of(context).at(1)),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: AppMotion.of(context, AppMotion.medium),
          layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.centerLeft,
              children: [...previous, if (current != null) current]),
          child: Text(preset.label,
              key: ValueKey(preset),
              style: TextStyle(
                  fontFamily: AppType.display,
                  fontSize: 32,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.96,
                  color: c.onSurface)),
        ),
      ]),
    );
  }
}

String _paletteNote(Tr s, AppColorPreset p) => switch (p) {
      AppColorPreset.monokai => s.t('Тёплые поверхности, неоновые акценты',
          'Warm surfaces, neon accents'),
      AppColorPreset.gruvbox =>
        s.t('Ретро: охра, мох и кирпич', 'Retro: ochre, moss and brick'),
      AppColorPreset.catppuccin => s.t('Мягкая пастель', 'Soft pastel'),
      AppColorPreset.nord =>
        s.t('Сдержанная северная синева', 'Restrained arctic blue'),
      AppColorPreset.everforest =>
        s.t('Хвоя и тёплый свет', 'Pine and warm light'),
      AppColorPreset.roseOfDune =>
        s.t('Песок, специи и пыльная роза', 'Sand, spice and dusty rose'),
    };

/// Every palette as a small card from edge to edge; the chosen one is
/// brought into view and its corners firm up with a ring of primary.
class _PaletteStrip extends StatefulWidget {
  const _PaletteStrip(
      {required this.selected, required this.basic, required this.onPick});
  final AppColorPreset selected;
  final bool basic;
  final ValueChanged<AppColorPreset> onPick;
  @override
  State<_PaletteStrip> createState() => _PaletteStripState();
}

class _PaletteStripState extends State<_PaletteStrip> {
  final _keys = {for (final p in AppColorPreset.values) p: GlobalKey()};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(false));
  }

  void _reveal(bool animate) {
    final ctx = _keys[widget.selected]?.currentContext;
    if (ctx == null || !mounted) return;
    final box = ctx.findRenderObject();
    if (box == null) return;
    // Only the strip moves: the page itself stays where it is.
    Scrollable.of(ctx).position.ensureVisible(box,
        alignment: .5,
        duration:
            animate ? AppMotion.of(context, AppMotion.long) : Duration.zero,
        curve: AppMotion.standard);
  }

  @override
  void didUpdateWidget(_PaletteStrip old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final s = Tr(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      // Every card as tall as the tallest, whatever its note's length.
      child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final p in AppColorPreset.values) ...[
          if (p != AppColorPreset.values.first) const SizedBox(width: 10),
          _PaletteCard(
            key: Key('settings_palette_${p.name}'),
            anchor: _keys[p]!,
            preset: p,
            brightness: brightness,
            basic: widget.basic,
            note: _paletteNote(s, p),
            selected: widget.selected == p,
            onTap: () => widget.onPick(p),
          ),
        ],
      ])),
    );
  }
}

class _PaletteCard extends StatelessWidget {
  const _PaletteCard(
      {super.key,
      required this.anchor,
      required this.preset,
      required this.brightness,
      required this.basic,
      required this.note,
      required this.selected,
      required this.onTap});
  final GlobalKey anchor;
  final AppColorPreset preset;
  final Brightness brightness;
  final bool basic, selected;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    var p = AppPalettes.getScheme(preset, brightness);
    var acc = AppPalettes.accents(preset, brightness);
    if (basic) {
      p = AppPalettes.calmScheme(p);
      acc = AppPalettes.calmAccents(acc);
    }
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    return Semantics(
      selected: selected,
      button: true,
      label: preset.label,
      child: Pressable(
        scale: .96,
        onTap: onTap,
        child: AnimatedContainer(
          key: anchor,
          duration: dur,
          curve: AppMotion.standard,
          width: 148,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          decoration: BoxDecoration(
            color: c.surfaceContainerLow,
            borderRadius: BorderRadius.circular(selected ? 18 : 24),
            border: Border.all(
                color: selected ? c.primary : c.primary.withValues(alpha: 0),
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside),
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                height: 78,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: p.surface, borderRadius: BorderRadius.circular(16)),
                child: Stack(children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FractionallySizedBox(
                          widthFactor: .5,
                          child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                  color: p.onSurface.withValues(alpha: .8),
                                  borderRadius: BorderRadius.circular(4))),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: p.surfaceContainer,
                              borderRadius: BorderRadius.circular(9)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FractionallySizedBox(
                                  widthFactor: .7,
                                  child: Container(
                                      height: 5,
                                      decoration: BoxDecoration(
                                          color: p.primary,
                                          borderRadius:
                                              BorderRadius.circular(3))),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                    height: 5,
                                    decoration: BoxDecoration(
                                        color:
                                            p.onSurface.withValues(alpha: .35),
                                        borderRadius:
                                            BorderRadius.circular(3))),
                              ]),
                        ),
                      ]),
                  // Accent dots overlapping a little, each ringed in the
                  // palette's surface.
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: SizedBox(
                      width: 16 + 9.0 * (acc.colors.length - 1),
                      height: 16,
                      child: Stack(children: [
                        for (var i = 0; i < acc.colors.length; i++)
                          Positioned(
                            left: 9.0 * i,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: acc.colors[i],
                                  border:
                                      Border.all(color: p.surface, width: 2)),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 6),
              Text(preset.label,
                  style: TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 15,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      color: c.onSurface)),
              const SizedBox(height: 6),
              Text(note,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5, height: 1.3, color: c.onSurfaceVariant)),
            ]),
            Positioned(
              top: 6,
              right: 6,
              child: AnimatedScale(
                scale: selected ? 1 : 0,
                duration: dur,
                curve: AppMotion.snappyCurve,
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: c.primary),
                  child: LineIcon('check', size: 15, color: c.onPrimary),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// System, light, dark: the chosen tile firms into a rounded square and
/// its glyph fills with the secondary colour.
class _Modes extends StatelessWidget {
  const _Modes({super.key, required this.mode, required this.onPick});
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onPick;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final s = Tr(context);
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    final items = [
      (ThemeMode.system, 'auto', s.t('Как в системе', 'System')),
      (ThemeMode.light, 'sun', s.t('Светлая', 'Light')),
      (ThemeMode.dark, 'moon', s.t('Тёмная', 'Dark')),
    ];
    return Row(children: [
      for (final (m, icon, label) in items) ...[
        if (m != ThemeMode.system) const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            selected: mode == m,
            button: true,
            child: Pressable(
              scale: .95,
              onTap: () => onPick(m),
              child: AnimatedContainer(
                duration: dur,
                curve: AppMotion.standard,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                decoration: BoxDecoration(
                  color: mode == m
                      ? pageMix(c.secondary, .16, c.surfaceContainerLow)
                      : c.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(mode == m ? 16 : 22),
                ),
                child: Column(children: [
                  AnimatedContainer(
                    duration: dur,
                    curve: AppMotion.standard,
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: mode == m
                          ? c.secondary
                          : c.onSurface.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(mode == m ? 13 : 20),
                    ),
                    child: LineIcon(icon,
                        size: 21,
                        color: mode == m ? c.surface : c.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                          color: mode == m ? c.onSurface : c.onSurfaceVariant)),
                ]),
              ),
            ),
          ),
        ),
      ],
    ]);
  }
}

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({super.key, required this.code, required this.onPick});
  final String code;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: c.onSurface.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final (v, label) in const [('ru', 'Рус'), ('en', 'Eng')])
          Semantics(
            selected: code == v,
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onPick(v),
              child: AnimatedContainer(
                duration:
                    AppMotion.of(context, const Duration(milliseconds: 220)),
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: code == v
                        ? c.secondary
                        : c.secondary.withValues(alpha: 0),
                    borderRadius: BorderRadius.circular(999)),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: code == v ? c.surface : c.onSurfaceVariant)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// The libraries as a tiny shelf of spines with the count beside it.
class _LibraryTile extends StatelessWidget {
  const _LibraryTile();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final a = AppAccents.of(context);
    final calm = AppCalm.of(context);
    final s = Tr(context);
    Widget tile(List<ShelfBook> books) => Pressable(
          key: const Key('settings_manage_libraries_tile'),
          scale: .98,
          haptic: true,
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const LibraryManagerScreen())),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: const Alignment(-.5, -1),
                end: const Alignment(.5, 1),
                stops: const [0, .7],
                colors: [
                  pageMix(a.at(1), .12 * calm.glow, c.surfaceContainerLow),
                  c.surfaceContainerLow
                ],
              ),
            ),
            child: Row(children: [
              SizedBox(
                width: 76,
                height: 56,
                child: Stack(children: [
                  Positioned(
                    left: 6,
                    right: 6,
                    bottom: 4,
                    top: 0,
                    child: ClipRect(
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 0; i < books.length; i++) ...[
                              if (i > 0) const SizedBox(width: 3),
                              _MiniSpine(
                                accent: books[i].builtIn
                                    ? c.primary
                                    : a.at(books[i].accent),
                                dim: !books[i].enabled,
                                height: 36.0 + (i * 13) % 20,
                                width: 10.0 +
                                    math.min(
                                        14,
                                        (math.log(books[i].total + 1) /
                                                math.ln10 *
                                                4)
                                            .roundToDouble()),
                              ),
                            ],
                          ]),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                            color: c.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(2))),
                  ),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: PageTitle(
                      s.t('Библиотеки', 'Libraries'), shelfSummary(s, books))),
              const SizedBox(width: 8),
              LineIcon('forward', size: 18, color: c.onSurfaceVariant),
            ]),
          ),
        );
    try {
      return ValueListenableBuilder<Box<CompendiumSource>>(
        valueListenable: StorageService.getSourcesListenable(),
        builder: (context, box, _) => tile(shelfBooks(box.values)),
      );
    } catch (_) {
      return tile(const []);
    }
  }
}

class _MiniSpine extends StatelessWidget {
  const _MiniSpine(
      {required this.accent,
      required this.height,
      required this.width,
      this.dim = false});
  final Color accent;
  final double height, width;
  final bool dim;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      foregroundDecoration: dim
          ? BoxDecoration(
              color: c.surfaceContainerLow.withValues(alpha: .6),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4), bottom: Radius.circular(2)))
          : null,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(4), bottom: Radius.circular(2)),
        gradient: LinearGradient(
            colors: [pageMix(accent, .7, c.surfaceContainer), accent]),
      ),
    );
  }
}

class _About extends StatelessWidget {
  const _About();

  Future<void> _open(BuildContext context, String url) async {
    final failed =
        Tr(context).t('Не удалось открыть ссылку', 'Unable to open the link');
    final ok = await launchUrl(Uri.parse(url),
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        webOnlyWindowName: '_blank');
    if (!ok && context.mounted) AppSnackBar.error(context, failed);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final s = Tr(context);
    Widget cell(String label, String value, {VoidCallback? onTap}) {
      final body = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: c.onSurface.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .66,
                  color: c.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: c.onSurface)),
        ]),
      );
      return Expanded(
          child: onTap == null
              ? body
              : Pressable(scale: .97, haptic: true, onTap: onTap, child: body));
    }

    Widget link(String icon, String label, String url) => Pressable(
          scale: .95,
          haptic: true,
          onTap: () => unawaited(_open(context, url)),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
                color: c.onSurface.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              LineIcon(icon, size: 17, color: c.onSurface),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: c.onSurface)),
            ]),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: c.surfaceContainerLow,
          borderRadius: BorderRadius.circular(26)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SvgPicture.asset('assets/images/icon.svg',
              width: 48,
              height: 48,
              colorFilter: ColorFilter.mode(c.primary, BlendMode.srcIn)),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(AppInfo.name,
                  style: TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 17,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: c.onSurface)),
              const SizedBox(height: 3),
              Text('${AppInfo.version} · ${AppInfo.channel.toLowerCase()}',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontFeatures: AppType.tabular,
                      color: c.onSurfaceVariant)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          cell(s.t('Разработчик', 'Developer'), 'Qurie'),
          const SizedBox(width: 8),
          cell(s.t('Лицензия', 'License'), 'MIT',
              onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'QD&D',
                  applicationVersion: AppInfo.version,
                  applicationLegalese: '© 2025 Qurie')),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          link('code', 'GitHub',
              'https://github.com/QurieGLord/QDnD-Roleplay-Companion'),
          link('send', 'Telegram', 'https://t.me/qdnd_companion'),
        ]),
      ]),
    );
  }
}

/// A d20 at the bottom of the page that rolls when touched.
class _Footer extends StatefulWidget {
  const _Footer();
  @override
  State<_Footer> createState() => _FooterState();
}

class _FooterState extends State<_Footer> {
  final _rnd = math.Random();
  var _roll = 0;
  var _value = 20;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final s = Tr(context);
    return Center(
      child: Semantics(
        button: true,
        label: s.t('Бросить к20', 'Roll a d20'),
        child: Pressable(
          scale: .96,
          onTap: () => setState(() {
            _roll++;
            _value = 1 + _rnd.nextInt(20);
          }),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              TumbleDie(
                shape: DieShape.d20,
                label: '$_value',
                sides: 20,
                natural: _roll == 0 ? null : _value,
                accent: c.primary,
                size: 44,
                rollKey: _roll,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                    s.t('Готово к следующему броску', 'Ready for the next roll'),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: c.onSurfaceVariant)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
