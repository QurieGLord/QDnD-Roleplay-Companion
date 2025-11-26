import 'dart:math';
import 'package:flutter/material.dart';

class HpIncreaseStep extends StatefulWidget {
  final int hitDie;
  final int conMod;
  final Function(int) onRoll;
  final VoidCallback onAverage;

  const HpIncreaseStep({
    Key? key,
    required this.hitDie,
    required this.conMod,
    required this.onRoll,
    required this.onAverage,
  }) : super(key: key);

  @override
  State<HpIncreaseStep> createState() => _HpIncreaseStepState();
}

class _HpIncreaseStepState extends State<HpIncreaseStep> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _currentRollDisplay = 1;
  bool _isRolling = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _controller.addListener(() {
      setState(() {
        _currentRollDisplay = Random().nextInt(widget.hitDie) + 1;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startRoll() {
    setState(() {
      _isRolling = true;
    });
    
    _controller.forward(from: 0).then((_) {
      final finalRoll = Random().nextInt(widget.hitDie) + 1;
      setState(() {
        _currentRollDisplay = finalRoll;
      });
      
      Future.delayed(const Duration(milliseconds: 800), () {
        widget.onRoll(finalRoll);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final avgValue = (widget.hitDie / 2).floor() + 1;
    final totalAvg = avgValue + widget.conMod;
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Text(
            'Hit Points',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your constitution modifier is ${widget.conMod >= 0 ? '+' : ''}${widget.conMod}',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          
          // Main Visual
          Center(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _isRolling 
                  ? RotationTransition(
                      turns: CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
                      child: Icon(Icons.casino, size: 80, color: colorScheme.primary),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite, size: 48, color: colorScheme.primary),
                        const SizedBox(height: 8),
                        Text('d${widget.hitDie}', style: theme.textTheme.titleLarge),
                      ],
                    ),
              ),
            ),
          ),
          
          if (_isRolling) ...[
            const SizedBox(height: 32),
            Text(
              '$_currentRollDisplay',
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ],

          const Spacer(),
          
          if (!_isRolling)
            Row(
              children: [
                // Average Option
                Expanded(
                  child: Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainer,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: widget.onAverage,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text('Average', style: theme.textTheme.labelLarge),
                            const SizedBox(height: 8),
                            Text(
                              '+$totalAvg',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('Safe choice', style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Roll Option
                Expanded(
                  child: Card(
                    elevation: 4,
                    shadowColor: colorScheme.primary.withOpacity(0.4),
                    color: colorScheme.primary,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _startRoll,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text('Roll', style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.onPrimary)),
                            const SizedBox(height: 8),
                            Icon(Icons.casino, size: 36, color: colorScheme.onPrimary),
                            const SizedBox(height: 4),
                            Text('Risk it!', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onPrimary.withOpacity(0.8))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
