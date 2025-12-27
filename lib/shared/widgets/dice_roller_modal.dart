import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

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

  const DiceRollerModal({
    super.key,
    this.title,
    this.initialModifier = 0,
    this.initialDice = DiceType.d20,
  });

  @override
  State<DiceRollerModal> createState() => _DiceRollerModalState();
}

class _DiceRollerModalState extends State<DiceRollerModal> with TickerProviderStateMixin {
  late DiceType _selectedDice;
  late int _modifier;
  AdvantageType _advantage = AdvantageType.none;
  final List<DiceRoll> _history = [];

  // Animation
  late AnimationController _rollController;
  late AnimationController _colorController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  
  bool _isRolling = false;
  int _displayedNumber = 1;
  Timer? _rollTimer;

  @override
  void initState() {
    super.initState();
    _selectedDice = widget.initialDice;
    _modifier = widget.initialModifier;
    _displayedNumber = widget.initialDice.sides;

    _rollController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _colorController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _rotationAnimation = CurvedAnimation(
      parent: _rollController,
      curve: Curves.elasticOut,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.7).chain(CurveTween(curve: Curves.easeOut)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.1).chain(CurveTween(curve: Curves.easeInOut)), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 20),
    ]).animate(_rollController);
  }

  @override
  void dispose() {
    _rollController.dispose();
    _colorController.dispose();
    _rollTimer?.cancel();
    super.dispose();
  }

  void _rollDice() async {
    if (_isRolling) return;

    setState(() {
      _isRolling = true;
    });
    
    HapticFeedback.selectionClick();
    _rollController.reset();
    _colorController.reset();
    _rollController.forward();
    
    int cycles = 0;
    final random = Random();
    
    _rollTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (mounted) {
        setState(() {
          _displayedNumber = random.nextInt(_selectedDice.sides) + 1;
        });
      }
      cycles++;
      if (cycles > 15) {
         timer.cancel();
         _slowDownTicks(random);
      }
    });
  }

  void _slowDownTicks(Random random) async {
    await Future.delayed(const Duration(milliseconds: 80));
    if (mounted) setState(() => _displayedNumber = random.nextInt(_selectedDice.sides) + 1);
    
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) setState(() => _displayedNumber = random.nextInt(_selectedDice.sides) + 1);

    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) _finalizeRoll(random);
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
      resultVal = _advantage == AdvantageType.advantage ? rolls.reduce(max) : rolls.reduce(min);
    }

    setState(() {
      _displayedNumber = resultVal;
      _isRolling = false;
      
      _history.insert(0, DiceRoll(
        result: resultVal,
        total: resultVal + _modifier,
        type: _selectedDice,
        modifier: _modifier,
        rawRolls: rolls,
        advantage: _advantage,
        timestamp: DateTime.now(),
      ));
    });
    
    _colorController.forward();
    HapticFeedback.heavyImpact();
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
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)],
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
                  Expanded(child: Text(widget.title ?? l10n.diceRoller, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
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
                  
                  // THE DIE
                  GestureDetector(
                    onTap: _rollDice,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_rollController, _colorController]),
                      builder: (context, child) {
                        final currentColor = Color.lerp(baseColor, activeColor, _colorController.value)!;
                        final currentTextColor = Color.lerp(textColor, activeTextColor, _colorController.value)!;
                        final rotation = _rotationAnimation.value * pi * 4;
                        
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateZ(rotation)..scale(_scaleAnimation.value),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: const Size(180, 180), // Reduced size
                                painter: DiceShapePainter(
                                  type: _selectedDice,
                                  color: currentColor,
                                  outlineColor: currentTextColor,
                                  strokeWidth: 3.0,
                                ),
                              ),
                              Center(
                                child: Text(
                                  '$_displayedNumber',
                                  style: TextStyle(
                                    fontSize: _getFontSizeForDice(_selectedDice) * 0.85, // Adjusted scale
                                    fontWeight: FontWeight.w900,
                                    color: currentTextColor,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  // Result Text
                  AnimatedBuilder(
                    animation: _colorController,
                    builder: (context, _) {
                      return Text(
                        _isRolling 
                            ? l10n.rolling 
                            : (_history.isNotEmpty ? l10n.total(_history.first.total) : l10n.tapToRoll),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color.lerp(colorScheme.onSurfaceVariant, activeColor, _colorController.value),
                        ),
                      );
                    }
                  ),
                  
                  const Spacer(flex: 2),
                ],
              ),
            ),

            // Controls Panel
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  // Row 1: Modifier & Advantage
                  Row(
                    children: [
                      // Modifier
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colorScheme.outlineVariant),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(l10n.modifier, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Row(
                                children: [
                                  InkWell(onTap: () => setState(() => _modifier--), child: const Icon(Icons.remove_circle_outline, size: 20)),
                                  const SizedBox(width: 8),
                                  Text('${_modifier >= 0 ? '+' : ''}$_modifier', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(width: 8),
                                  InkWell(onTap: () => setState(() => _modifier++), child: const Icon(Icons.add_circle_outline, size: 20)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Advantage
                      SegmentedButton<AdvantageType>(
                        segments: const [
                          ButtonSegment(value: AdvantageType.disadvantage, icon: Icon(Icons.keyboard_double_arrow_down, size: 16)),
                          ButtonSegment(value: AdvantageType.none, label: Text('-')),
                          ButtonSegment(value: AdvantageType.advantage, icon: Icon(Icons.keyboard_double_arrow_up, size: 16)),
                        ],
                        selected: {_advantage},
                        onSelectionChanged: (val) => setState(() => _advantage = val.first),
                        showSelectedIcon: false,
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: MaterialStateProperty.all(EdgeInsets.zero),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Row 2: Dice Selector
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
                              color: isSelected ? colorScheme.primary : colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              dice.label,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
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
      case DiceType.d4: return 40;
      case DiceType.d8: return 48;
      case DiceType.d10: return 48;
      case DiceType.d12: return 52;
      case DiceType.d20: return 52;
      case DiceType.d100: return 44;
      default: return 64;
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
        final angle = -pi / 2; 
        for (int i = 0; i < 3; i++) {
          final theta = angle + (i * 2 * pi / 3);
          final x = adjustedCenter.dx + radius * cos(theta);
          final y = adjustedCenter.dy + radius * sin(theta);
          if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
        }
        path.close();
        break;

      case DiceType.d6:
        final rect = Rect.fromCircle(center: center, radius: radius * 0.75);
        path.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
        break;

      case DiceType.d8:
        path.moveTo(center.dx, center.dy - radius);
        path.lineTo(center.dx + radius * 0.7, center.dy);
        path.lineTo(center.dx, center.dy + radius);
        path.lineTo(center.dx - radius * 0.7, center.dy);
        path.close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, outlinePaint);
        canvas.drawLine(center, Offset(center.dx, center.dy - radius), outlinePaint..strokeWidth = strokeWidth/2);
        canvas.drawLine(center, Offset(center.dx, center.dy + radius), outlinePaint..strokeWidth = strokeWidth/2);
        canvas.drawLine(Offset(center.dx - radius * 0.7, center.dy), Offset(center.dx + radius * 0.7, center.dy), outlinePaint..strokeWidth = strokeWidth/2);
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
        canvas.drawLine(center, Offset(center.dx, center.dy - radius), outlinePaint..strokeWidth = strokeWidth/2);
        canvas.drawLine(center, Offset(center.dx, center.dy + radius), outlinePaint..strokeWidth = strokeWidth/2);
        canvas.drawLine(Offset(center.dx - radius * 0.7, center.dy - radius * 0.2), center, outlinePaint..strokeWidth = strokeWidth/2);
        canvas.drawLine(Offset(center.dx + radius * 0.7, center.dy - radius * 0.2), center, outlinePaint..strokeWidth = strokeWidth/2);
        return;

      case DiceType.d12:
        final angle = -pi / 2;
        for (int i = 0; i < 5; i++) {
          final theta = angle + (i * 2 * pi / 5);
          final x = center.dx + radius * cos(theta);
          final y = center.dy + radius * sin(theta);
          if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
        }
        path.close();
        break;

      case DiceType.d20:
        final angle = pi / 6; 
        for (int i = 0; i < 6; i++) {
          final theta = angle + (i * 2 * pi / 6);
          final x = center.dx + radius * cos(theta);
          final y = center.dy + radius * sin(theta);
          if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
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