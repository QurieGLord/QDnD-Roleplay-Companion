import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/character.dart';
import '../../core/services/gameplay_actions_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_palettes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/companion_kit.dart';
import '../../core/ui/expressive_kit.dart';
import '../../core/ui/page_kit.dart';
import '../../core/ui/sheet_drag_region.dart' show KeyboardPadding;
import '../character_list/hero_transfer.dart' show SheetListRow;
import '../character_list/widgets/character_roster_visuals.dart';
import '../character_sheet/widgets/class_widgets/instrument/instrument_kit.dart'
    show showNumberKeypad;
import '../journal/journal_kit.dart';

/// The hero's card (wave 5, «Анкета героя»): a portrait in the class colour,
/// the name written large, the look told as one sentence and picked on
/// tiles, the four sides of the character as cards that light up while
/// written in, and the story.
class CharacterEditScreen extends StatefulWidget {
  const CharacterEditScreen({super.key, required this.character});
  final Character character;

  @override
  State<CharacterEditScreen> createState() => _CharacterEditScreenState();
}

/// A choice of the look: the stored key (kept in English, as the creation
/// wizard stores it), its names and its colour.
typedef _Swatch = (String key, String ru, String en, Color? color);

const List<_Swatch> _eyes = [
  ('Amber', 'Янтарные', 'Amber', Color(0xFFFFBF00)),
  ('Blue', 'Голубые', 'Blue', Color(0xFF4169E1)),
  ('Brown', 'Карие', 'Brown', Color(0xFF8B4513)),
  ('Gray', 'Серые', 'Gray', Color(0xFF808080)),
  ('Green', 'Зелёные', 'Green', Color(0xFF228B22)),
  ('Hazel', 'Ореховые', 'Hazel', Color(0xFFA0785A)),
  ('Red', 'Красные', 'Red', Color(0xFFDC143C)),
  ('Violet', 'Фиолетовые', 'Violet', Color(0xFF8B00FF)),
];
const List<_Swatch> _skin = [
  ('Pale', 'Бледная', 'Pale', Color(0xFFFFF0E1)),
  ('Fair', 'Светлая', 'Fair', Color(0xFFFFE4C4)),
  ('Light', 'Персиковая', 'Light', Color(0xFFFFDDB3)),
  ('Medium', 'Оливковая', 'Medium', Color(0xFFE8B98A)),
  ('Tan', 'Загорелая', 'Tan', Color(0xFFD2A574)),
  ('Brown', 'Смуглая', 'Brown', Color(0xFFA67C52)),
  ('Dark', 'Тёмная', 'Dark', Color(0xFF8B6F47)),
  ('Ebony', 'Эбеновая', 'Ebony', Color(0xFF4A3728)),
];
const List<_Swatch> _hair = [
  ('Auburn', 'Каштановые', 'Auburn', Color(0xFFA52A2A)),
  ('Black', 'Чёрные', 'Black', Color(0xFF1A1A1A)),
  ('Blonde', 'Светлые', 'Blonde', Color(0xFFFAF0BE)),
  ('Brown', 'Русые', 'Brown', Color(0xFF654321)),
  ('Gray', 'Седые', 'Gray', Color(0xFF808080)),
  ('Red', 'Рыжие', 'Red', Color(0xFFE2421B)),
  ('White', 'Белые', 'White', Color(0xFFF5F5F5)),
  ('Bald', 'Без волос', 'Bald', null),
];

enum _Look { eyes, skin, hair }

enum _Num { age, height, weight }

enum _Side { traits, ideals, bonds, flaws }

class _CharacterEditScreenState extends State<CharacterEditScreen> {
  late final _name = TextEditingController(text: widget.character.name);
  late final _story = TextEditingController(text: widget.character.backstory);
  late final _sides = {
    _Side.traits:
        TextEditingController(text: widget.character.personalityTraits),
    _Side.ideals: TextEditingController(text: widget.character.ideals),
    _Side.bonds: TextEditingController(text: widget.character.bonds),
    _Side.flaws: TextEditingController(text: widget.character.flaws),
  };
  final _nameFocus = FocusNode();
  final _scroll = ScrollController();

  late String? _avatar = widget.character.avatarPath;
  late final _nums = {
    _Num.age: _digits(widget.character.age),
    _Num.height: _digits(widget.character.height),
    _Num.weight: _digits(widget.character.weight),
  };
  late final _looks = {
    _Look.eyes: _clean(widget.character.eyes),
    _Look.skin: _clean(widget.character.skin),
    _Look.hair: _clean(widget.character.hair),
  };
  bool _dirty = false;
  int _saveStamp = 0;

  static int? _digits(String? v) {
    final n = int.tryParse((v ?? '').replaceAll(RegExp(r'[^\d]'), ''));
    return n == null || n <= 0 ? null : n;
  }

  static String? _clean(String? v) =>
      v == null || v.trim().isEmpty ? null : v.trim();

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _story, ..._sides.values]) {
      c.addListener(_touch);
    }
    _nameFocus.addListener(() {
      if (_nameFocus.hasFocus) HapticFeedback.selectionClick();
    });
  }

  void _touch() {
    if (!_dirty) {
      setState(() {
        _dirty = true;
        _saveStamp++;
      });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _story, ..._sides.values]) {
      c.dispose();
    }
    _nameFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = Tr(context);
    final h = widget.character;
    // An emptied name keeps the old one rather than blocking the save.
    final typed = _name.text.trim();
    final name = typed.isEmpty ? h.name : typed;
    try {
      // In the hero's write queue; a failed write puts the card back as it was.
      await GameplayActionsService.serializeCharacter(h, () async {
        final before = (h.name, h.avatarPath, h.age, h.height, h.weight, h.eyes,
            h.skin, h.hair, h.backstory, h.personalityTraits, h.ideals, h.bonds,
            h.flaws, h.updatedAt);
        h
          ..name = name
          ..avatarPath = _avatar
          ..age = _nums[_Num.age]?.toString()
          ..height = _nums[_Num.height] == null
              ? null
              : '${_nums[_Num.height]} ${s.t('см', 'cm')}'
          ..weight = _nums[_Num.weight] == null
              ? null
              : '${_nums[_Num.weight]} ${s.t('кг', 'kg')}'
          ..eyes = _looks[_Look.eyes]
          ..skin = _looks[_Look.skin]
          ..hair = _looks[_Look.hair]
          ..backstory = _story.text.trim()
          ..personalityTraits = _sides[_Side.traits]!.text.trim()
          ..ideals = _sides[_Side.ideals]!.text.trim()
          ..bonds = _sides[_Side.bonds]!.text.trim()
          ..flaws = _sides[_Side.flaws]!.text.trim()
          ..updatedAt = DateTime.now();
        try {
          await StorageService.saveCharacter(h);
        } catch (_) {
          h
            ..name = before.$1
            ..avatarPath = before.$2
            ..age = before.$3
            ..height = before.$4
            ..weight = before.$5
            ..eyes = before.$6
            ..skin = before.$7
            ..hair = before.$8
            ..backstory = before.$9
            ..personalityTraits = before.$10
            ..ideals = before.$11
            ..bonds = before.$12
            ..flaws = before.$13
            ..updatedAt = before.$14;
          rethrow;
        }
      });
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _dirty = false;
      Navigator.of(context).pop(true);
      AppSnackBar.success(
          context, s.t('Анкета сохранена', 'The card is saved'));
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
            context, s.t('Не удалось сохранить: $e', 'Could not save: $e'));
      }
    }
  }

  /// Closing with changes asks first.
  Future<void> _close() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final s = Tr(context);
    final drop = await showCompanionSheet<bool>(context, builder: (sheet) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageSheetHead(
            kicker: s.t('Анкета героя', 'The hero\'s card'),
            title: s.t('Оставить изменения?', 'Keep the changes?'),
            sub: s.t('Можно вернуться к анкете или закрыть её без сохранения.',
                'Go back to the card or close it without saving.')),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: ToneButton(
                label: s.t('Не сохранять', 'Discard'),
                height: 50,
                expand: true,
                onPressed: () => Navigator.of(sheet).pop(true)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ToneButton(
                label: s.t('Продолжить', 'Keep editing'),
                kind: ToneKind.primary,
                height: 50,
                expand: true,
                onPressed: () => Navigator.of(sheet).pop(false)),
          ),
        ]),
      ]);
    });
    if (drop == true && mounted) {
      _dirty = false;
      Navigator.of(context).pop();
    }
  }

  Future<void> _portrait() async {
    final s = Tr(context);
    final a = AppAccents.of(context);
    final choice = await showCompanionSheet<String>(context, builder: (sheet) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageSheetHead(
            kicker: s.t('Анкета', 'Card'), title: s.t('Портрет', 'Portrait')),
        const SizedBox(height: 14),
        SheetListRow(
            leading: PageSeal('image', accent: a.at(4)),
            title: s.t('Из галереи', 'From the gallery'),
            subtitle: s.t('Картинка с устройства', 'A picture from the device'),
            onTap: () => Navigator.of(sheet).pop('pick')),
        if (_avatar != null) ...[
          const SizedBox(height: 6),
          SheetListRow(
              leading: PageSeal('trash', accent: a.at(0)),
              title: s.t('Убрать портрет', 'Remove the portrait'),
              subtitle:
                  s.t('Вернётся буква имени', 'The name\'s letter returns'),
              onTap: () => Navigator.of(sheet).pop('del')),
        ],
      ]);
    });
    if (!mounted || choice == null) return;
    if (choice == 'del') {
      setState(() => _avatar = null);
      _touch();
      return;
    }
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.image);
      final path = r?.files.firstOrNull?.path;
      if (path == null || !mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _avatar = path);
      _touch();
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
            context, s.t('Не удалось открыть: $e', 'Could not open it: $e'));
      }
    }
  }

  Future<void> _pickNumber(_Num k) async {
    final s = Tr(context);
    final (title, min, max, fallback) = switch (k) {
      _Num.age => (s.t('Возраст', 'Age'), 1, 999, 25),
      _Num.height => (s.t('Рост', 'Height'), 50, 250, 170),
      _Num.weight => (s.t('Вес', 'Weight'), 10, 300, 70),
    };
    final unit = _unit(s, k, _nums[k] ?? fallback);
    final v = await showCompanionSheet<int>(context,
        builder: (_) => _DrumSheet(
            title: title,
            min: min,
            max: max,
            value: (_nums[k] ?? fallback).clamp(min, max),
            unit: unit));
    if (!mounted || v == null) return;
    setState(() => _nums[k] = v.clamp(min, max));
    _touch();
  }

  Future<void> _pickLook(_Look k) async {
    final s = Tr(context);
    final (title, list) = switch (k) {
      _Look.eyes => (s.t('Глаза', 'Eyes'), _eyes),
      _Look.skin => (s.t('Кожа', 'Skin'), _skin),
      _Look.hair => (s.t('Волосы', 'Hair'), _hair),
    };
    final v = await showCompanionSheet<String>(context,
        builder: (_) =>
            _SwatchSheet(title: title, options: list, value: _looks[k]));
    if (!mounted || v == null) return;
    setState(() => _looks[k] = v.isEmpty ? null : v);
    _touch();
  }

  static String _unit(Tr s, _Num k, int n) => switch (k) {
        _Num.age => s.plural(
            n, const ['год', 'года', 'лет'], const ['year', 'years'],
            number: false),
        _Num.height => s.t('см', 'cm'),
        _Num.weight => s.t('кг', 'kg'),
      };

  static _Swatch? _swatchOf(List<_Swatch> list, String? v) =>
      list.where((x) => x.$1 == v || x.$2 == v || x.$3 == v).firstOrNull;

  String _lookName(Tr s, _Look k) {
    final v = _looks[k];
    if (v == null) return s.t('Не указано', 'Not set');
    final list = switch (k) {
      _Look.eyes => _eyes,
      _Look.skin => _skin,
      _Look.hair => _hair,
    };
    final sw = _swatchOf(list, v);
    return sw == null ? v : s.t(sw.$2, sw.$3);
  }

  /// «34 года · 182 см · 84 кг · карие глаза · смуглая кожа · чёрные волосы».
  String _sentence(Tr s) {
    String? look(_Look k, String ru, String en) {
      if (_looks[k] == null) return null;
      if (k == _Look.hair && _swatchOf(_hair, _looks[k])?.$1 == 'Bald') {
        return s.t('без волос', 'bald');
      }
      return '${_lookName(s, k).toLowerCase()} ${s.t(ru, en)}';
    }

    return [
      if (_nums[_Num.age] != null)
        '${_nums[_Num.age]} ${_unit(s, _Num.age, _nums[_Num.age]!)}',
      if (_nums[_Num.height] != null)
        '${_nums[_Num.height]} ${s.t('см', 'cm')}',
      if (_nums[_Num.weight] != null)
        '${_nums[_Num.weight]} ${s.t('кг', 'kg')}',
      look(_Look.eyes, 'глаза', 'eyes'),
      look(_Look.skin, 'кожа', 'skin'),
      look(_Look.hair, 'волосы', 'hair'),
    ].whereType<String>().join(' · ');
  }

  int get _told => [
        _name.text.trim().isNotEmpty,
        ..._nums.values.map((v) => v != null),
        ..._looks.values.map((v) => v != null),
        ..._sides.values.map((c) => c.text.trim().isNotEmpty),
        _story.text.trim().isNotEmpty,
      ].where((b) => b).length;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final a = AppAccents.of(context);
    final s = Tr(context);
    final h = widget.character;
    final acc =
        a.forClass(h.classes.isEmpty ? h.characterClass : h.classes.first.id);
    final top = MediaQuery.paddingOf(context).top;
    final told = _told;
    final line = _sentence(s);
    final words = RegExp(r'\S+').allMatches(_story.text).length;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: c.surface,
        resizeToAvoidBottomInset: false,
        body: Stack(children: [
          KeyboardPadding(
            child: SingleChildScrollView(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(20, top + 80, 20, 60),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The portrait, the name and what is told about the hero.
                    Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          Positioned(
                            top: -40,
                            child: IgnorePointer(
                              child: Container(
                                width: 340,
                                height: 260,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(stops: const [
                                    0,
                                    .66
                                  ], colors: [
                                    acc.withValues(
                                        alpha: .26 * AppCalm.of(context).glow),
                                    acc.withValues(alpha: 0),
                                  ]),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
                            child: Column(children: [
                              _Portrait(
                                  name: _name.text,
                                  path: _avatar,
                                  accent: acc,
                                  onTap: _portrait),
                              const SizedBox(height: 16),
                              // Only the name's own underline answers its
                              // focus; the page is not rebuilt for it.
                              ListenableBuilder(
                                listenable: _nameFocus,
                                builder: (context, field) => AnimatedContainer(
                                  duration: AppMotion.of(context,
                                      const Duration(milliseconds: 200)),
                                  decoration: BoxDecoration(
                                    color: _nameFocus.hasFocus
                                        ? c.onSurface.withValues(alpha: .04)
                                        : c.onSurface.withValues(alpha: 0),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(14),
                                        bottom: Radius.circular(4)),
                                    border: Border(
                                        bottom: BorderSide(
                                            color: _nameFocus.hasFocus
                                                ? acc.withValues(alpha: .6)
                                                : acc.withValues(alpha: 0),
                                            width: 1.5)),
                                  ),
                                  child: field,
                                ),
                                child: TextField(
                                  controller: _name,
                                  focusNode: _nameFocus,
                                  textAlign: TextAlign.center,
                                  textCapitalization: TextCapitalization.words,
                                  cursorColor: acc,
                                  style: TextStyle(
                                      fontFamily: AppType.display,
                                      fontSize: 34,
                                      height: 1.05,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -1.02,
                                      color: c.onSurface),
                                  decoration: InputDecoration(
                                    isCollapsed: true,
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    hintText: s.t('Имя героя', 'Hero\'s name'),
                                    hintStyle: TextStyle(
                                        color:
                                            c.onSurface.withValues(alpha: .38)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              PageCap(
                                  '${getLocalizedRaceName(context, h.race)} · '
                                  '${getCharacterClassSummary(context, h)} ${h.level}',
                                  accent: acc),
                              if (line.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(line,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 14,
                                          height: 1.5,
                                          color: c.onSurfaceVariant)),
                                ),
                              ],
                              const SizedBox(height: 14),
                              _FillMeter(told: told, accent: acc),
                            ]),
                          ),
                        ]),
                    PageSection(s.t('Облик', 'Look'),
                        note: s.t('касание — выбрать', 'touch to pick')),
                    const SizedBox(height: 12),
                    PageGrid3(children: [
                      for (final (k, icon, label, accent) in [
                        (_Num.age, 'hourglass', s.t('Возраст', 'Age'), a.at(1)),
                        (_Num.height, 'ruler', s.t('Рост', 'Height'), a.at(4)),
                        (_Num.weight, 'scale', s.t('Вес', 'Weight'), a.at(3)),
                      ])
                        _NumTile(
                          icon: icon,
                          label: label,
                          accent: accent,
                          value: _nums[k],
                          unit: _unit(s, k, _nums[k] ?? 0),
                          onTap: () => _pickNumber(k),
                        ),
                      for (final (k, label, list) in [
                        (_Look.eyes, s.t('Глаза', 'Eyes'), _eyes),
                        (_Look.skin, s.t('Кожа', 'Skin'), _skin),
                        (_Look.hair, s.t('Волосы', 'Hair'), _hair),
                      ])
                        _LookTile(
                          label: label,
                          name: _lookName(s, k),
                          set: _looks[k] != null,
                          color: _swatchOf(list, _looks[k])?.$4,
                          bald: _swatchOf(list, _looks[k])?.$1 == 'Bald',
                          onTap: () => _pickLook(k),
                        ),
                    ]),
                    PageSection(s.t('Личность', 'Personality')),
                    const SizedBox(height: 12),
                    for (final (side, icon, accent, title, hint, ideas) in [
                      (
                        _Side.traits,
                        'spark',
                        a.at(3),
                        s.t('Черты характера', 'Traits'),
                        s.t('Как герой держится и что выдаёт его привычки',
                            'How the hero carries themself and what their habits give away'),
                        [
                          s.t('Говорит мало, но всегда по делу',
                              'Speaks little, but always to the point'),
                          s.t('Не может пройти мимо чужой беды',
                              'Cannot walk past someone in trouble'),
                        ]
                      ),
                      (
                        _Side.ideals,
                        'star',
                        a.at(2),
                        s.t('Идеалы', 'Ideals'),
                        s.t('Во что герой верит, даже когда это дорого',
                            'What the hero believes in, even when it costs'),
                        [
                          s.t('Клятва важнее жизни',
                              'An oath matters more than life'),
                          s.t('Слабых нужно защищать',
                              'The weak must be protected'),
                        ]
                      ),
                      (
                        _Side.bonds,
                        'link',
                        a.at(4),
                        s.t('Привязанности', 'Bonds'),
                        s.t('Кто и что держит героя',
                            'Who and what holds the hero'),
                        [
                          s.t('Отец, которого я не знал',
                              'A father I never knew'),
                          s.t('Орден, вырастивший меня',
                              'The order that raised me'),
                        ]
                      ),
                      (
                        _Side.flaws,
                        'drop',
                        a.at(0),
                        s.t('Слабости', 'Flaws'),
                        s.t('Что может его подвести', 'What may let them down'),
                        [
                          s.t('Не прощает ложь — даже малую',
                              'Never forgives a lie, even a small one'),
                          s.t('Бросается в бой раньше, чем думает',
                              'Charges in before thinking'),
                        ]
                      ),
                    ]) ...[
                      _SideCard(
                        controller: _sides[side]!,
                        icon: icon,
                        accent: accent,
                        title: title,
                        hint: hint,
                        ideas: ideas,
                      ),
                      const SizedBox(height: 8),
                    ],
                    PageSection(s.t('Предыстория', 'Backstory')),
                    const SizedBox(height: 12),
                    _SideCard(
                      controller: _story,
                      icon: 'book',
                      accent: a.at(5),
                      title: s.t('Путь героя', 'The hero\'s path'),
                      hint: s.t(
                          'Откуда герой, что его привело и что он оставил позади',
                          'Where the hero comes from, what brought them here and what they left behind'),
                      note: s.plural(words, const ['слово', 'слова', 'слов'],
                          const ['word', 'words']),
                      minLines: 5,
                      story: true,
                    ),
                  ]),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: JournalTopBar(
              titled: true,
              title: s.t('Анкета героя', 'The hero\'s card'),
              leading: JournalRound(
                  icon: 'x', label: s.t('Закрыть', 'Close'), onTap: _close),
              actions: [
                _Pop(
                  stamp: _saveStamp,
                  child: ToneButton(
                    label: s.t('Сохранить', 'Save'),
                    kind: ToneKind.primary,
                    height: 40,
                    onPressed: _dirty ? _save : null,
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// popin: grows in from a little smaller when the save first wakes up.
class _Pop extends StatelessWidget {
  const _Pop({required this.stamp, required this.child});
  final int stamp;
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        key: ValueKey(stamp),
        tween: Tween(
            begin:
                stamp == 0 || MediaQuery.disableAnimationsOf(context) ? 1 : .7,
            end: 1),
        duration: AppMotion.of(context, AppMotion.snappySettle),
        curve: AppMotion.snappyCurve,
        builder: (context, v, child) => Transform.scale(scale: v, child: child),
        child: child,
      );
}

class _Portrait extends StatelessWidget {
  const _Portrait(
      {required this.name,
      required this.path,
      required this.accent,
      required this.onTap});
  final String name;
  final String? path;
  final Color accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final s = Tr(context);
    final calm = AppCalm.of(context);
    final file = path == null ? null : File(path!);
    final hasImage = file != null && file.existsSync();
    return Semantics(
      button: true,
      label: s.t('Портрет', 'Portrait'),
      child: Pressable(
        scale: .96,
        haptic: true,
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(45),
              color: c.surface,
              border: Border.all(color: accent.withValues(alpha: .5), width: 2),
              boxShadow: [
                BoxShadow(
                    color: accent.withValues(alpha: calm.glow),
                    blurRadius: 40,
                    spreadRadius: -18,
                    offset: const Offset(0, 20)),
              ],
            ),
            padding: const EdgeInsets.all(5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(38),
              child: hasImage
                  ? Image.file(file, fit: BoxFit.cover)
                  : ColoredBox(
                      color: accent,
                      child: Center(
                        child: Text(
                            name.trim().isEmpty
                                ? '?'
                                : name.trim().characters.first.toUpperCase(),
                            style: TextStyle(
                                fontFamily: AppType.display,
                                fontSize: 54,
                                height: 1,
                                fontWeight: FontWeight.w600,
                                color: pageOnAccent(c))),
                      ),
                    ),
            ),
          ),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.surface,
                  border: Border.all(
                      color: c.onSurface.withValues(alpha: .12), width: 2)),
              child: LineIcon('camera', size: 19, color: c.onSurface),
            ),
          ),
        ]),
      ),
    );
  }
}

/// «Рассказано N из 12»: a bar that fills as the card is told.
class _FillMeter extends StatelessWidget {
  const _FillMeter({required this.told, required this.accent});
  final int told;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final s = Tr(context);
    final heal = AppAccents.of(context).at(3);
    return SizedBox(
      width: 200,
      child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 6,
            color: c.onSurface.withValues(alpha: .1),
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: told / 12),
              duration:
                  AppMotion.of(context, const Duration(milliseconds: 600)),
              curve: AppMotion.standard,
              builder: (context, v, _) => FractionallySizedBox(
                widthFactor: v.clamp(0.0, 1.0),
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: LinearGradient(colors: [accent, heal])),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
            told == 12
                ? s.t('Анкета заполнена целиком', 'The card is complete')
                : s.t('Рассказано $told из 12', '$told of 12 told'),
            style: TextStyle(
                fontSize: 11.5,
                height: 1,
                fontWeight: FontWeight.w600,
                letterSpacing: .23,
                color: c.onSurfaceVariant)),
      ]),
    );
  }
}

class _TileShell extends StatelessWidget {
  const _TileShell(
      {required this.accent, required this.onTap, required this.child});
  final Color accent;
  final VoidCallback onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Pressable(
      scale: .96,
      haptic: true,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 86),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
              begin: const Alignment(-.5, -1),
              end: const Alignment(.5, 1),
              stops: const [
                0,
                .7
              ],
              colors: [
                pageMix(accent, .13 * AppCalm.of(context).glow,
                    c.surfaceContainerLow),
                c.surfaceContainerLow
              ]),
        ),
        child: child,
      ),
    );
  }
}

Widget _tileHead(
    BuildContext context, String icon, String label, Color accent) {
  final c = Theme.of(context).colorScheme;
  return Row(children: [
    LineIcon(icon, size: 16, color: accent),
    const SizedBox(width: 6),
    Expanded(
      child: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 11.5,
              height: 1,
              fontWeight: FontWeight.w600,
              letterSpacing: .46,
              color: c.onSurfaceVariant)),
    ),
  ]);
}

class _NumTile extends StatelessWidget {
  const _NumTile(
      {required this.icon,
      required this.label,
      required this.accent,
      required this.value,
      required this.unit,
      required this.onTap});
  final String icon, label, unit;
  final Color accent;
  final int? value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return _TileShell(
      accent: accent,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _tileHead(context, icon, label, accent),
        const SizedBox(height: 10),
        Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (value == null)
                Text('—',
                    style: TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 26,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: c.onSurfaceVariant))
              else
                RollingNumber(value!,
                    style: TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 26,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        fontFeatures: AppType.tabular,
                        color: c.onSurface)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(unit,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: c.onSurfaceVariant)),
              ),
            ]),
      ]),
    );
  }
}

/// A round colour sample; no colour draws a hatch.
class _Dot extends StatelessWidget {
  const _Dot({this.color, this.size = 22, this.hatch = false});
  final Color? color;
  final double size;
  final bool hatch;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hatch ? null : (color ?? c.outline),
        border:
            Border.all(color: c.onSurface.withValues(alpha: .2), width: 1.5),
      ),
      child: hatch
          ? ClipOval(
              child: CustomPaint(
                  painter: _Hatch(c.onSurface.withValues(alpha: .25))))
          : null,
    );
  }
}

class _Hatch extends CustomPainter {
  const _Hatch(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (var x = -size.height; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(_Hatch old) => old.color != color;
}

class _LookTile extends StatelessWidget {
  const _LookTile(
      {required this.label,
      required this.name,
      required this.set,
      required this.color,
      required this.bald,
      required this.onTap});
  final String label, name;
  final bool set, bald;
  final Color? color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final accent = color ?? c.outline;
    return _TileShell(
      accent: accent,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _tileHead(context, 'swatch', label, accent),
        const SizedBox(height: 10),
        Row(children: [
          _Dot(color: color, hatch: bald || (set && color == null)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.5,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: set ? c.onSurface : c.onSurfaceVariant)),
          ),
        ]),
      ]),
    );
  }
}

/// A side of the character. While written in, the card lights up in its
/// accent, lifts a little and its seal fills and turns; an empty card
/// offers two ideas to start from.
class _SideCard extends StatefulWidget {
  const _SideCard(
      {required this.controller,
      required this.icon,
      required this.accent,
      required this.title,
      required this.hint,
      this.ideas = const [],
      this.note,
      this.minLines = 1,
      this.story = false});
  final TextEditingController controller;
  final String icon, title, hint;
  final Color accent;
  final List<String> ideas;
  final String? note;
  final int minLines;
  final bool story;
  @override
  State<_SideCard> createState() => _SideCardState();
}

class _SideCardState extends State<_SideCard> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) HapticFeedback.selectionClick();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final calm = AppCalm.of(context);
    final a = widget.accent;
    final on = _focus.hasFocus;
    final empty = widget.controller.text.trim().isEmpty;
    // Only colours move, briefly: nothing lifts, turns or reshapes while
    // the keyboard slides in, so the card stays steady under the finger.
    final dur = AppMotion.of(context, const Duration(milliseconds: 200));
    final low = c.surfaceContainerLow;
    final rest = empty && !widget.story;
    final List<Color> fill = on
        ? [pageMix(a, .09 * calm.glow, low), low]
        : rest
            ? [low.withValues(alpha: 0), low.withValues(alpha: 0)]
            : [pageMix(a, .1 * calm.glow, low), low];
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _focus.requestFocus,
      child: RepaintBoundary(
        child: AnimatedContainer(
          duration: dur,
          curve: AppMotion.standard,
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: const Alignment(-.5, -1),
                end: const Alignment(.5, 1),
                stops: const [0, .7],
                colors: fill),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: on
                    ? a.withValues(alpha: .5)
                    : c.onSurface.withValues(alpha: rest ? .1 : 0),
                width: 1.5,
                strokeAlign: BorderSide.strokeAlignInside),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              AnimatedContainer(
                duration: dur,
                curve: AppMotion.standard,
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? a : pageMix(a, .2, c.surfaceContainer),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: LineIcon(widget.icon,
                    size: 16, color: on ? pageOnAccent(c) : a),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.title,
                    style: TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: c.onSurface)),
              ),
              if (widget.note != null)
                Text(widget.note!,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFeatures: AppType.tabular,
                        color: c.onSurfaceVariant)),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: widget.controller,
              focusNode: _focus,
              minLines: widget.minLines,
              maxLines: null,
              cursorColor: a,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              style: TextStyle(fontSize: 15.5, height: 1.5, color: c.onSurface),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                hintText: widget.hint,
                hintMaxLines: 3,
                hintStyle: TextStyle(color: c.onSurface.withValues(alpha: .38)),
              ),
            ),
            PageReveal(
              open: empty && widget.ideas.isNotEmpty,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final idea in widget.ideas)
                    Pressable(
                      scale: .95,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.controller.text = '$idea.';
                      },
                      child: JournalDashed(
                        radius: 17,
                        color: a.withValues(alpha: .6),
                        width: 1.4,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 34),
                          padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            LineIcon('plus', size: 14, color: a),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(idea,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.3,
                                      fontWeight: FontWeight.w500,
                                      color: c.onSurface)),
                            ),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A drum of numbers: dragged or flicked, it settles on a value with a
/// tick for every number passed.
class _DrumSheet extends StatefulWidget {
  const _DrumSheet(
      {required this.title,
      required this.min,
      required this.max,
      required this.value,
      required this.unit});
  final String title, unit;
  final int min, max, value;
  @override
  State<_DrumSheet> createState() => _DrumSheetState();
}

class _DrumSheetState extends State<_DrumSheet> {
  late final _wheel =
      FixedExtentScrollController(initialItem: widget.value - widget.min);
  late int _value = widget.value;

  @override
  void dispose() {
    _wheel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final s = Tr(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageSheetHead(kicker: s.t('Облик', 'Look'), title: widget.title),
      const SizedBox(height: 8),
      SizedBox(
        height: 250,
        child: Stack(alignment: Alignment.center, children: [
          Positioned(
            left: 24,
            right: 24,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                  color: pageMix(c.secondary, .14, c.surfaceContainerLow),
                  borderRadius: BorderRadius.circular(18)),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: _wheel,
            itemExtent: 52,
            perspective: .004,
            diameterRatio: 1.6,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (i) {
              HapticFeedback.selectionClick();
              setState(() => _value = widget.min + i);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: widget.max - widget.min + 1,
              builder: (context, i) {
                final v = widget.min + i;
                final on = v == _value;
                return Center(
                  child: AnimatedDefaultTextStyle(
                    duration: AppMotion.of(context, AppMotion.short),
                    style: TextStyle(
                        fontFamily: AppType.display,
                        fontSize: on ? 36 : 30,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        fontFeatures: AppType.tabular,
                        color: on ? c.onSurface : c.onSurfaceVariant),
                    child: Text('$v'),
                  ),
                );
              },
            ),
          ),
          Positioned(
            right: 46,
            child: IgnorePointer(
              child: Text(widget.unit,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.onSurfaceVariant)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: ToneButton(
            label: s.t('Ввести', 'Type'),
            icon: LineIcon('edit', size: 19, color: c.onSurface),
            height: 50,
            expand: true,
            onPressed: () async {
              final n = await showNumberKeypad(context,
                  title: widget.title, kicker: s.t('Облик', 'Look'));
              if (n == null || !context.mounted) return;
              Navigator.of(context).pop(n.clamp(widget.min, widget.max));
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ToneButton(
            label: s.t('Готово', 'Done'),
            kind: ToneKind.primary,
            height: 50,
            expand: true,
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop(_value);
            },
          ),
        ),
      ]),
    ]);
  }
}

/// Eight colours to pick from, or the hero's own words.
class _SwatchSheet extends StatefulWidget {
  const _SwatchSheet(
      {required this.title, required this.options, required this.value});
  final String title;
  final List<_Swatch> options;
  final String? value;
  @override
  State<_SwatchSheet> createState() => _SwatchSheetState();
}

class _SwatchSheetState extends State<_SwatchSheet> {
  late String? _picked = widget.options
      .where((o) =>
          o.$1 == widget.value || o.$2 == widget.value || o.$3 == widget.value)
      .firstOrNull
      ?.$1;
  late final _own =
      TextEditingController(text: _picked == null ? (widget.value ?? '') : '');

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final s = Tr(context);
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageSheetHead(kicker: s.t('Облик', 'Look'), title: widget.title),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (context, box) {
        final w = (box.maxWidth - 3 * 8) / 4;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final o in widget.options)
            SizedBox(
              width: w,
              child: Pressable(
                scale: .94,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _picked = o.$1;
                    _own.clear();
                  });
                  Future.delayed(
                      AppMotion.of(context, const Duration(milliseconds: 260)),
                      () {
                    if (context.mounted) Navigator.of(context).pop(o.$1);
                  });
                },
                child: AnimatedContainer(
                  duration: dur,
                  curve: AppMotion.standard,
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
                  decoration: BoxDecoration(
                    color: c.surfaceContainerLow,
                    borderRadius:
                        BorderRadius.circular(_picked == o.$1 ? 14 : 20),
                    border: Border.all(
                        color: c.secondary
                            .withValues(alpha: _picked == o.$1 ? 1 : 0),
                        width: 2,
                        strokeAlign: BorderSide.strokeAlignInside),
                  ),
                  child: Column(children: [
                    _Dot(color: o.$4, size: 40, hatch: o.$4 == null),
                    const SizedBox(height: 8),
                    Text(s.t(o.$2, o.$3),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            color: c.onSurface)),
                  ]),
                ),
              ),
            ),
        ]);
      }),
      const SizedBox(height: 14),
      JournalField(
        controller: _own,
        label: s.t('Своё', 'Your own'),
        hint: s.t('Например: разные — зелёный и серый',
            'For example: odd — one green, one gray'),
      ),
      const SizedBox(height: 14),
      ToneButton(
        label: s.t('Готово', 'Done'),
        kind: ToneKind.primary,
        height: 52,
        expand: true,
        onPressed: () {
          final own = _own.text.trim();
          Navigator.of(context).pop(own.isNotEmpty ? own : (_picked ?? ''));
        },
      ),
    ]);
  }
}
