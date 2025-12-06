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
      duration: const Duration(milliseconds: 1200), // Longer for physics feel
      vsync: this,
    );
    
    _colorController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Spring-like rotation
    _rotationAnimation = CurvedAnimation(
      parent: _rollController,
      curve: Curves.elasticOut, // Bouncy stop
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.7).chain(CurveTween(curve: Curves.easeOut)), weight: 20), // Anticipation
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.1).chain(CurveTween(curve: Curves.easeInOut)), weight: 60), // Throw
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 20), // Land
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
    
    // Reset animations
    _rollController.reset();
    _colorController.reset();
    
    // Start roll
    _rollController.forward();
    
    // Fast number cycling
    int cycles = 0;
    final random = Random();
    
    _rollTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (mounted) {
        setState(() {
          _displayedNumber = random.nextInt(_selectedDice.sides) + 1;
        });
      }
      cycles++;
      // Slow down effect
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
    
    // Animate color to success state
    _colorController.forward();
    HapticFeedback.heavyImpact();
  }

  String _getAdvantageLabel(AppLocalizations l10n, AdvantageType type) {
    switch (type) {
      case AdvantageType.none: return l10n.normal;
      case AdvantageType.advantage: return l10n.advantage;
      case AdvantageType.disadvantage: return l10n.disadvantage;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // Colors for animation
    final baseColor = colorScheme.primaryContainer;
    final activeColor = colorScheme.tertiaryContainer; // Rolling/Success color
    final textColor = colorScheme.onPrimaryContainer;
    final activeTextColor = colorScheme.onTertiaryContainer;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)],
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.title ?? l10n.diceRoller, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                IconButton.filledTonal(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          const Divider(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  // --- THE DIE ---
                  GestureDetector(
                    onTap: _rollDice,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_rollController, _colorController]),
                      builder: (context, child) {
                        // Color interpolation
                        final currentColor = Color.lerp(baseColor, activeColor, _colorController.value)!;
                        final currentTextColor = Color.lerp(textColor, activeTextColor, _colorController.value)!;
                        
                        // Rotation (Multi-axis for "tumble" effect simulation)
                        // We rotate mostly on Z, but scale simulates depth
                        final rotation = _rotationAnimation.value * pi * 4; // 2 full rotations
                        
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..rotateZ(rotation)
                            ..scale(_scaleAnimation.value),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Glow/Shadow
                              Container(
                                width: 200, height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: currentColor.withOpacity(0.4),
                                      blurRadius: 40 * _scaleAnimation.value,
                                      spreadRadius: 10,
                                    )
                                  ],
                                ),
                              ),
                              // The Shape
                              CustomPaint(
                                size: const Size(220, 220),
                                painter: DiceShapePainter(
                                  type: _selectedDice,
                                  color: currentColor,
                                  outlineColor: currentTextColor, // Outline matches text
                                  strokeWidth: 3.0,
                                ),
                              ),
                              // The Text
                              Center(
                                child: Text(
                                  '$_displayedNumber',
                                  style: TextStyle(
                                    fontSize: _getFontSizeForDice(_selectedDice),
                                    fontWeight: FontWeight.w900,
                                    color: currentTextColor,
                                    height: 1.0, // Tight line height
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),
                  
                  // Instruction / Result text
                  AnimatedBuilder(
                    animation: _colorController,
                    builder: (context, _) {
                      return Text(
                        _isRolling 
                            ? l10n.rolling 
                            : (_history.isNotEmpty ? l10n.total(_history.first.total) : l10n.tapToRoll),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color.lerp(colorScheme.onSurfaceVariant, activeColor, _colorController.value),
                        ),
                      );
                    }
                  ),

                  const SizedBox(height: 48),

                  // --- CONTROLS ---
                  // Dice Type Selector (Grid)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('DICE TYPE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.outline, letterSpacing: 1.2)),
                  ),
                  const SizedBox(height: 12),
                  
                  // GridView for dice selection to ensure everything fits
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: DiceType.values.length,
                    itemBuilder: (context, index) {
                      final dice = DiceType.values[index];
                      final isSelected = _selectedDice == dice;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDice = dice;
                            _displayedNumber = dice.sides; // Reset preview
                            _colorController.reset(); // Reset color
                          });
                          HapticFeedback.selectionClick();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? colorScheme.primary : colorScheme.outline.withOpacity(0.2),
                              width: isSelected ? 0 : 1,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))
                            ] : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Mini Shape
                              CustomPaint(
                                size: const Size(24, 24),
                                painter: DiceShapePainter(
                                  type: dice,
                                  color: isSelected ? colorScheme.onPrimary.withOpacity(0.2) : colorScheme.onSurface.withOpacity(0.1),
                                  outlineColor: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                                  strokeWidth: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dice.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Modifier & Advantage
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Modifier
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.modifier.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.outline, letterSpacing: 1.2)),
                            const SizedBox(height: 8),
                            Container(
                              height: 48,
                              decoration: BoxDecoration(
                                border: Border.all(color: colorScheme.outlineVariant),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    onPressed: () => setState(() => _modifier--),
                                    icon: const Icon(Icons.remove, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32),
                                  ),
                                  Text(
                                    '${_modifier >= 0 ? '+' : ''}$_modifier',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  IconButton(
                                    onPressed: () => setState(() => _modifier++),
                                    icon: const Icon(Icons.add, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Advantage
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.rollType.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.outline, letterSpacing: 1.2)),
                            const SizedBox(height: 8),
                            SegmentedButton<AdvantageType>(
                              segments: [
                                ButtonSegment(value: AdvantageType.disadvantage, label: Text(l10n.disadvantage)),
                                ButtonSegment(value: AdvantageType.none, label: Text('-')), // Or short label
                                ButtonSegment(value: AdvantageType.advantage, label: Text(l10n.advantage)),
                              ],
                              selected: {_advantage},
                              onSelectionChanged: (val) => setState(() => _advantage = val.first),
                              showSelectedIcon: false,
                              style: ButtonStyle(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                textStyle: MaterialStateProperty.all(const TextStyle(fontSize: 10)), // Smaller font for long words
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getFontSizeForDice(DiceType type) {
    // Adjust font size based on shape to prevent overflow
    switch (type) {
      case DiceType.d4: return 40; // Triangle is small at top
      case DiceType.d8: return 48; // Diamond is narrow
      case DiceType.d10: return 48;
      case DiceType.d12: return 52;
      case DiceType.d20: return 52;
      case DiceType.d100: return 44; // 3 digits
      default: return 64; // Box is big
    }
  }
}

// --- CUSTOM PAINTER FOR DICE SHAPES ---

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
        // Triangle (Pointing UP)
        // Center of mass adjustment: Triangle visual center is lower than bounding box center
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
        // Rounded Square
        final rect = Rect.fromCircle(center: center, radius: radius * 0.75);
        path.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
        break;

      case DiceType.d8:
        // Diamond
        path.moveTo(center.dx, center.dy - radius);
        path.lineTo(center.dx + radius * 0.7, center.dy);
        path.lineTo(center.dx, center.dy + radius);
        path.lineTo(center.dx - radius * 0.7, center.dy);
        path.close();
        // Inner lines for 3D feel
        canvas.drawPath(path, paint);
        canvas.drawPath(path, outlinePaint);
        // Draw lines separately to ensure they are on top
        canvas.drawLine(center, Offset(center.dx, center.dy - radius), outlinePaint..strokeWidth = strokeWidth/2);
        canvas.drawLine(center, Offset(center.dx, center.dy + radius), outlinePaint..strokeWidth = strokeWidth/2);
        canvas.drawLine(Offset(center.dx - radius * 0.7, center.dy), Offset(center.dx + radius * 0.7, center.dy), outlinePaint..strokeWidth = strokeWidth/2);
        return;

      case DiceType.d10:
      case DiceType.d100:
        // Kite
        path.moveTo(center.dx, center.dy - radius);
        path.lineTo(center.dx + radius * 0.7, center.dy - radius * 0.2);
        path.lineTo(center.dx, center.dy + radius);
        path.lineTo(center.dx - radius * 0.7, center.dy - radius * 0.2);
        path.close();
        
        canvas.drawPath(path, paint);
        canvas.drawPath(path, outlinePaint);
        
        // Inner lines
        canvas.drawLine(center, Offset(center.dx, center.dy - radius), outlinePaint..strokeWidth = strokeWidth/2);
        canvas.drawLine(center, Offset(center.dx, center.dy + radius), outlinePaint..strokeWidth = strokeWidth/2);
        canvas.drawLine(Offset(center.dx - radius * 0.7, center.dy - radius * 0.2), center, outlinePaint..strokeWidth = strokeWidth/2);
        canvas.drawLine(Offset(center.dx + radius * 0.7, center.dy - radius * 0.2), center, outlinePaint..strokeWidth = strokeWidth/2);
        return;

      case DiceType.d12:
        // Pentagon
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
        // Hexagon
        final angle = pi / 6; 
        for (int i = 0; i < 6; i++) {
          final theta = angle + (i * 2 * pi / 6);
          final x = center.dx + radius * cos(theta);
          final y = center.dy + radius * sin(theta);
          if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
        }
        path.close();
        // Inner lines for d20 feel (triangle fan)
        canvas.drawPath(path, paint);
        canvas.drawPath(path, outlinePaint);
        // Draw lines to center
        /*
        for (int i = 0; i < 6; i+=2) {
           final theta = angle + (i * 2 * pi / 6);
           canvas.drawLine(center, Offset(center.dx + radius * cos(theta), center.dy + radius * sin(theta)), outlinePaint..strokeWidth = strokeWidth/2);
        }
        */
        return;
    }

    canvas.drawPath(path, paint);
    canvas.drawPath(path, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
