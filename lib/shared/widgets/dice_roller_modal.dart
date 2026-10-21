import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/ui/expressive_kit.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

enum DiceType {
  d4(4, 'd4'),
  d6(6, 'd6'),
  d8(8, 'd8'),
  d10(10, 'd10'),
  d12(12, 'd12'),
  d20(20, 'd20'),
  d100(100, 'd100');

  final int sides;
  final String label;
  const DiceType(this.sides, this.label);
}

enum AdvantageType {
  none(Icons.remove),
  advantage(Icons.keyboard_double_arrow_up),
  disadvantage(Icons.keyboard_double_arrow_down);

  final IconData icon;
  const AdvantageType(this.icon);
}

class DiceRoll {
  final int result;
  final int total;
  final DiceType type;
  final int modifier;
  final List<int> rawRolls;
  final AdvantageType advantage;
  final DateTime timestamp;

  DiceRoll({
    required this.result,
    required this.total,
    required this.type,
    required this.modifier,
    required this.rawRolls,
    required this.advantage,
    required this.timestamp,
  });
}

void showDiceRoller(
  BuildContext context, {
  String? title,
  int modifier = 0,
  DiceType initialDice = DiceType.d20,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DiceRollerModal(
      title: title,
      initialModifier: modifier,
      initialDice: initialDice,
    ),
  );
}

class DiceRollerModal extends StatefulWidget {
  final String? title;
  final int initialModifier;
  final DiceType initialDice;

  /// Source of rolls; tests inject a fixed one.
  final Random? random;

  const DiceRollerModal({
    super.key,
    this.title,
    this.initialModifier = 0,
    this.initialDice = DiceType.d20,
    this.random,
  });

  @override
  State<DiceRollerModal> createState() => _DiceRollerModalState();
}

class _DiceRollerModalState extends State<DiceRollerModal>
    with TickerProviderStateMixin {
  late DiceType _selectedDice;
  late int _modifier;
  AdvantageType _advantage = AdvantageType.none;
  final List<DiceRoll> _history = [];

  // Motion: a low toss with a spin, a soft landing and a locked-in result.
  // Springs come from AppMotion; nothing here overshoots visibly.
  late final AnimationController _lift =
      AnimationController.unbounded(vsync: this)..addListener(_onLift);
  late final AnimationController _spin =
      AnimationController.unbounded(vsync: this);
  late final AnimationController _squash =
      AnimationController.unbounded(vsync: this);
  late final AnimationController _lock = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420), value: 1);
  late final AnimationController _glow = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));
  late final AnimationController _colorController = AnimationController(
      duration: const Duration(milliseconds: 500), vsync: this);
  bool _falling = false;

  bool _isRolling = false;
  int _displayedNumber = 1;
  Timer? _rollTimer;
  final List<Timer> _steps = [];

  @override
  void initState() {
    super.initState();
    _selectedDice = widget.initialDice;
    _modifier = widget.initialModifier;
    _displayedNumber = widget.initialDice.sides;
  }

  @override
  void dispose() {
    for (final t in _steps) {
      t.cancel();
    }
    _rollTimer?.cancel();
    _lift.dispose();
    _spin.dispose();
    _squash.dispose();
    _lock.dispose();
    _glow.dispose();
    _colorController.dispose();
    super.dispose();
  }

  void _after(Duration d, VoidCallback f) => _steps.add(Timer(d, () {
        if (mounted) f();
      }));

  void _onLift() {
    // Touchdown: a short squash, then the die settles.
    if (_falling && _lift.value >= -1) {
      _falling = false;
      _squash.value = 1;
      _squash.animateWith(SpringSimulation(AppMotion.snappy, 1, 0, 0));
      HapticFeedback.lightImpact();
    }
  }

  bool get _isCrit =>
      !_isRolling &&
      _selectedDice == DiceType.d20 &&
      _history.isNotEmpty &&
      _history.first.result == 20;
  bool get _isFumble =>
      !_isRolling &&
      _selectedDice == DiceType.d20 &&
      _history.isNotEmpty &&
      _history.first.result == 1;

  void _rollDice() {
    if (_isRolling) return;
    for (final t in _steps) {
      t.cancel();
    }
    _steps.clear();
    _rollTimer?.cancel();
    final random = widget.random ?? Random();
    final reduced = MediaQuery.disableAnimationsOf(context);
    setState(() => _isRolling = true);
    HapticFeedback.selectionClick();
    _colorController.reset();
    _glow.reset();
    if (reduced) {
      _finalizeRoll(random);
      return;
    }
    // Toss: a low lift with a spin; the shadow tightens on the table.
    _lift.animateWith(
        SpringSimulation(AppMotion.snappy, _lift.value, -20, -320));
    final turn = 2 * pi + random.nextDouble() * pi * .6;
    _spin.animateWith(SpringSimulation(
        AppMotion.gentle, _spin.value, _spin.value + turn, 19));
    // The faces flicker, each one a little slower than the last.
    var wait = 38.0;
    void flick() {
      setState(
          () => _displayedNumber = random.nextInt(_selectedDice.sides) + 1);
      wait *= 1.24;
      if (wait < 200) {
        _rollTimer = Timer(Duration(milliseconds: wait.round()), () {
          if (mounted) flick();
        });
      }
    }

    flick();
    _after(const Duration(milliseconds: 200), () {
      _falling = true;
      _lift.animateWith(
          SpringSimulation(AppMotion.snappy, _lift.value, 0, _lift.velocity));
    });
    _after(const Duration(milliseconds: 560), () {
      _rollTimer?.cancel();
      _spin.animateWith(SpringSimulation(AppMotion.gentle, _spin.value,
          (_spin.value / (2 * pi)).roundToDouble() * 2 * pi, _spin.velocity));
      _finalizeRoll(random);
    });
  }

  void _finalizeRoll(Random random) {
    final rolls = <int>[];
    int resultVal = 0;

    if (_advantage == AdvantageType.none) {
      rolls.add(random.nextInt(_selectedDice.sides) + 1);
      resultVal = rolls.first;
    } else {
      rolls.add(random.nextInt(_selectedDice.sides) + 1);
      rolls.add(random.nextInt(_selectedDice.sides) + 1);
      resultVal = _advantage == AdvantageType.advantage
          ? rolls.reduce(max)
          : rolls.reduce(min);
    }

    setState(() {
      _displayedNumber = resultVal;
      _isRolling = false;

      _history.insert(
          0,
          DiceRoll(
            result: resultVal,
            total: resultVal + _modifier,
            type: _selectedDice,
            modifier: _modifier,
            rawRolls: rolls,
            advantage: _advantage,
            timestamp: DateTime.now(),
          ));
    });

    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) {
      _colorController.value = 1;
      return;
    }
    // Lock-in: the final face settles into place and the tone warms up.
    _lock.forward(from: 0);
    _colorController.forward();
    if (_isCrit) {
      _glow.forward(from: 0);
      HapticFeedback.mediumImpact();
    } else if (_isFumble) {
      // The die sinks a little and tilts.
      _lift.animateWith(SpringSimulation(AppMotion.gentle, _lift.value, 3, 0));
      _spin.animateWith(
          SpringSimulation(AppMotion.gentle, _spin.value, _spin.value - .1, 0));
      _glow.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final baseColor = colorScheme.primaryContainer;
    final activeColor = colorScheme.tertiaryContainer;
    final textColor = colorScheme.onPrimaryContainer;
    final activeTextColor = colorScheme.onTertiaryContainer;

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadii.xlPlus)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20)
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                      child: Text(widget.title ?? l10n.diceRoller,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold))),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Main Content Area
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // THE DIE: scales down on short screens instead of overflowing.
                  Flexible(
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: GestureDetector(
                            onTap: _rollDice,
                            child: AnimatedBuilder(
                              animation: Listenable.merge([
                                _lift,
                                _spin,
                                _squash,
                                _lock,
                                _glow,
                                _colorController
                              ]),
                              builder: (context, child) {
                                final crit = _isCrit, fumble = _isFumble;
                                final warm =
                                    crit ? colorScheme.tertiary : activeColor;
                                final currentColor = fumble
                                    ? colorScheme.surfaceContainerHigh
                                    : Color.lerp(
                                        baseColor,
                                        crit
                                            ? colorScheme.tertiaryContainer
                                            : activeColor,
                                        _colorController.value)!;
                                final currentTextColor = fumble
                                    ? colorScheme.onSurfaceVariant
                                    : Color.lerp(
                                        textColor,
                                        crit
                                            ? colorScheme.tertiary
                                            : activeTextColor,
                                        _colorController.value)!;
                                final outline = fumble
                                    ? colorScheme.outline
                                    : Color.lerp(
                                        textColor, warm, crit ? 1 : 0)!;
                                final lift =
                                    (-_lift.value / 24).clamp(0.0, 1.0);
                                final sq = _squash.value;
                                final lock = AppMotion.snappyCurve
                                    .transform(_lock.value);
                                // The glow blooms, breathes once and fades.
                                final g = _glow.value;
                                final glow = g < .3
                                    ? AppMotion.enter.transform(g / .3)
                                    : g < .6
                                        ? 1 - .2 * ((g - .3) / .3)
                                        : .8 *
                                            (1 -
                                                AppMotion.standard
                                                    .transform((g - .6) / .4));
                                return SizedBox(
                                  width: 240,
                                  height: 200,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    clipBehavior: Clip.none,
                                    children: [
                                      if (_glow.isAnimating)
                                        IgnorePointer(
                                          child: Opacity(
                                            opacity: (fumble ? .55 : 1) *
                                                glow.clamp(0.0, 1.0),
                                            child: Container(
                                              width: 240,
                                              height: 240,
                                              decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient:
                                                      RadialGradient(colors: [
                                                    (fumble
                                                            ? colorScheme
                                                                .primary
                                                            : colorScheme
                                                                .tertiary)
                                                        .withValues(
                                                            alpha: fumble
                                                                ? .22
                                                                : .4),
                                                    Colors.transparent
                                                  ])),
                                            ),
                                          ),
                                        ),
                                      // Shadow on the table, tighter while the die is up.
                                      Positioned(
                                        bottom: -4,
                                        child: Opacity(
                                          opacity: 1 - .45 * lift,
                                          child: Transform.scale(
                                            scale: 1 - .3 * lift,
                                            child: Container(
                                              width: 120,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                  shape: BoxShape.rectangle,
                                                  borderRadius:
                                                      const BorderRadius.all(
                                                          Radius.elliptical(
                                                              60, 7)),
                                                  gradient:
                                                      RadialGradient(colors: [
                                                    Colors.black
                                                        .withValues(alpha: .38),
                                                    Colors.transparent
                                                  ])),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Transform(
                                        alignment: Alignment.bottomCenter,
                                        transform: Matrix4.identity()
                                          ..translateByDouble(
                                              0, _lift.value, 0, 1)
                                          ..scaleByDouble(1 + .025 * sq,
                                              1 - .035 * sq, 1, 1),
                                        child: Transform.rotate(
                                          angle: _spin.value,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              CustomPaint(
                                                size: const Size(180, 180),
                                                painter: DiceShapePainter(
                                                  type: _selectedDice,
                                                  color: currentColor,
                                                  outlineColor: outline,
                                                  strokeWidth: crit ? 3.6 : 3.0,
                                                ),
                                              ),
                                              Transform.rotate(
                                                angle: -_spin.value,
                                                child: Opacity(
                                                  opacity: .4 +
                                                      .6 * lock.clamp(0.0, 1.0),
                                                  child: Transform.scale(
                                                    scale: .86 + .14 * lock,
                                                    child: Text(
                                                      '$_displayedNumber',
                                                      style: TextStyle(
                                                        fontFamily:
                                                            AppType.display,
                                                        fontFeatures:
                                                            AppType.tabular,
                                                        fontSize:
                                                            _getFontSizeForDice(
                                                                    _selectedDice) *
                                                                0.85,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        color: currentTextColor,
                                                        height: 1.0,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ))),

                  const SizedBox(height: 8),

                  // Result: the total locks in with a rolling number.
                  AnimatedBuilder(
                      animation: _colorController,
                      builder: (context, _) {
                        final style = TextStyle(
                          fontFamily: AppType.display,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Color.lerp(
                              colorScheme.onSurfaceVariant,
                              _isCrit
                                  ? colorScheme.tertiary
                                  : colorScheme.onSurface,
                              _colorController.value),
                        );
                        final parts = l10n.total('\u0000').split('\u0000');
                        final note = _isCrit
                            ? l10n.diceNaturalTwenty
                            : _isFumble
                                ? l10n.diceNaturalOne
                                : null;
                        return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedSwitcher(
                                duration:
                                    AppMotion.of(context, AppMotion.medium),
                                switchInCurve: AppMotion.enter,
                                switchOutCurve: AppMotion.exit,
                                child: _isRolling || _history.isEmpty
                                    ? Text(
                                        _isRolling
                                            ? l10n.rolling
                                            : l10n.tapToRoll,
                                        key: ValueKey(_isRolling),
                                        style: style)
                                    : Row(
                                        key: const ValueKey('total'),
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                            Text(parts.first, style: style),
                                            RollingNumber(_history.first.total,
                                                style: style),
                                            if (parts.length > 1)
                                              Text(parts.last, style: style),
                                          ]),
                              ),
                              const SizedBox(height: 4),
                              Reveal(
                                open: note != null,
                                child: Text(note ?? '',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                        color: _isCrit
                                            ? colorScheme.tertiary
                                            : colorScheme.onSurfaceVariant)),
                              ),
                            ]);
                      }),

                  const Spacer(),
                ],
              ),
            ),

            // Controls Panel
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadii.xlPlus)),
              ),
              child: Column(
                children: [
                  // Row 1: Modifier
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.modifier,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        Row(
                          children: [
                            InkWell(
                                onTap: () => setState(() => _modifier--),
                                borderRadius:
                                    BorderRadius.circular(AppRadii.lgPlus),
                                child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(Icons.remove_circle_outline,
                                        size: 24))),
                            SizedBox(
                              width: 40,
                              child: Text(
                                  '${_modifier >= 0 ? '+' : ''}$_modifier',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20)),
                            ),
                            InkWell(
                                onTap: () => setState(() => _modifier++),
                                borderRadius:
                                    BorderRadius.circular(AppRadii.lgPlus),
                                child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(Icons.add_circle_outline,
                                        size: 24))),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Row 2: Advantage
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<AdvantageType>(
                      segments: [
                        ButtonSegment(
                            value: AdvantageType.disadvantage,
                            label: Text(l10n.disadvantage),
                            icon: const Icon(Icons.keyboard_double_arrow_down,
                                size: 16)),
                        const ButtonSegment(
                            value: AdvantageType.none, label: Text('-')),
                        ButtonSegment(
                            value: AdvantageType.advantage,
                            label: Text(l10n.advantage),
                            icon: const Icon(Icons.keyboard_double_arrow_up,
                                size: 16)),
                      ],
                      selected: {_advantage},
                      onSelectionChanged: (val) =>
                          setState(() => _advantage = val.first),
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        visualDensity: VisualDensity.standard,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(vertical: 0)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Row 3: Dice Selector
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: DiceType.values.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final dice = DiceType.values[index];
                        final isSelected = _selectedDice == dice;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDice = dice;
                              _displayedNumber = dice.sides;
                              _colorController.reset();
                            });
                            HapticFeedback.selectionClick();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 48,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.surface,
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              border: Border.all(
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.outlineVariant,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              dice.label,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getFontSizeForDice(DiceType type) {
    switch (type) {
      case DiceType.d4:
        return 40;
      case DiceType.d8:
        return 48;
      case DiceType.d10:
        return 48;
      case DiceType.d12:
        return 52;
      case DiceType.d20:
        return 52;
      case DiceType.d100:
        return 44;
      default:
        return 64;
    }
  }
}

class DiceShapePainter extends CustomPainter {
  final DiceType type;
  final Color color;
  final Color outlineColor;
  final double strokeWidth;

  DiceShapePainter({
    required this.type,
    required this.color,
    required this.outlineColor,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 * 0.9;

    final path = Path();

    switch (type) {
      case DiceType.d4:
        final adjustedCenter = Offset(center.dx, center.dy + radius * 0.2);
        const angle = -pi / 2;
        for (int i = 0; i < 3; i++) {
          final theta = angle + (i * 2 * pi / 3);
          final x = adjustedCenter.dx + radius * cos(theta);
          final y = adjustedCenter.dy + radius * sin(theta);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        break;

      case DiceType.d6:
        final rect = Rect.fromCircle(center: center, radius: radius * 0.75);
        path.addRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(AppRadii.lg)));
        break;

      case DiceType.d8:
        path.moveTo(center.dx, center.dy - radius);
        path.lineTo(center.dx + radius * 0.7, center.dy);
        path.lineTo(center.dx, center.dy + radius);
        path.lineTo(center.dx - radius * 0.7, center.dy);
        path.close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, outlinePaint);
        canvas.drawLine(center, Offset(center.dx, center.dy - radius),
            outlinePaint..strokeWidth = strokeWidth / 2);
        canvas.drawLine(center, Offset(center.dx, center.dy + radius),
            outlinePaint..strokeWidth = strokeWidth / 2);
        canvas.drawLine(
            Offset(center.dx - radius * 0.7, center.dy),
            Offset(center.dx + radius * 0.7, center.dy),
            outlinePaint..strokeWidth = strokeWidth / 2);
        return;

      case DiceType.d10:
      case DiceType.d100:
        path.moveTo(center.dx, center.dy - radius);
        path.lineTo(center.dx + radius * 0.7, center.dy - radius * 0.2);
        path.lineTo(center.dx, center.dy + radius);
        path.lineTo(center.dx - radius * 0.7, center.dy - radius * 0.2);
        path.close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, outlinePaint);
        canvas.drawLine(center, Offset(center.dx, center.dy - radius),
            outlinePaint..strokeWidth = strokeWidth / 2);
        canvas.drawLine(center, Offset(center.dx, center.dy + radius),
            outlinePaint..strokeWidth = strokeWidth / 2);
        canvas.drawLine(
            Offset(center.dx - radius * 0.7, center.dy - radius * 0.2),
            center,
            outlinePaint..strokeWidth = strokeWidth / 2);
        canvas.drawLine(
            Offset(center.dx + radius * 0.7, center.dy - radius * 0.2),
            center,
            outlinePaint..strokeWidth = strokeWidth / 2);
        return;

      case DiceType.d12:
        const angle = -pi / 2;
        for (int i = 0; i < 5; i++) {
          final theta = angle + (i * 2 * pi / 5);
          final x = center.dx + radius * cos(theta);
          final y = center.dy + radius * sin(theta);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        break;

      case DiceType.d20:
        const angle = pi / 6;
        for (int i = 0; i < 6; i++) {
          final theta = angle + (i * 2 * pi / 6);
          final x = center.dx + radius * cos(theta);
          final y = center.dy + radius * sin(theta);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        break;
    }

    canvas.drawPath(path, paint);
    canvas.drawPath(path, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
