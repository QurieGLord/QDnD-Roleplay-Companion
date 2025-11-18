import 'package:flutter/material.dart';
import 'dart:math';

class DiceRollerModal extends StatefulWidget {
  final String title;
  final int sides;
  final int modifier;
  final bool advantage;
  final bool disadvantage;

  const DiceRollerModal({
    super.key,
    this.title = 'Roll',
    this.sides = 20,
    this.modifier = 0,
    this.advantage = false,
    this.disadvantage = false,
  });

  @override
  State<DiceRollerModal> createState() => _DiceRollerModalState();
}

class _DiceRollerModalState extends State<DiceRollerModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  int? _result;
  int? _secondRoll;
  bool _isRolling = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _roll() {
    if (_isRolling) return;

    setState(() {
      _isRolling = true;
      _result = null;
      _secondRoll = null;
    });

    _controller.forward(from: 0).then((_) {
      final random = Random();
      final roll1 = random.nextInt(widget.sides) + 1;

      if (widget.advantage || widget.disadvantage) {
        final roll2 = random.nextInt(widget.sides) + 1;
        setState(() {
          _result = widget.advantage
              ? max(roll1, roll2)
              : min(roll1, roll2);
          _secondRoll = widget.advantage ? min(roll1, roll2) : max(roll1, roll2);
          _isRolling = false;
        });
      } else {
        setState(() {
          _result = roll1;
          _isRolling = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = _result != null ? _result! + widget.modifier : null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            widget.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),

          // Dice type and modifier
          Text(
            'd${widget.sides}${widget.modifier != 0 ? ' ${widget.modifier >= 0 ? '+' : ''}${widget.modifier}' : ''}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                ),
          ),

          // Advantage/Disadvantage indicator
          if (widget.advantage || widget.disadvantage) ...[
            const SizedBox(height: 4),
            Text(
              widget.advantage ? 'Advantage' : 'Disadvantage',
              style: TextStyle(
                color: widget.advantage ? colorScheme.secondary : colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Dice animation
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Transform.rotate(
                  angle: _rotationAnimation.value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primaryContainer,
                          colorScheme.secondaryContainer,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _result != null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$_result',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                                ),
                                if (_secondRoll != null)
                                  Text(
                                    '($_secondRoll)',
                                    style: TextStyle(
                                      color: colorScheme.onPrimaryContainer
                                          .withOpacity(0.6),
                                    ),
                                  ),
                              ],
                            )
                          : Icon(
                              Icons.casino,
                              size: 48,
                              color: colorScheme.onPrimaryContainer,
                            ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          // Result
          if (total != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total: ',
                    style: TextStyle(
                      color: colorScheme.onSecondaryContainer,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '$total',
                    style: TextStyle(
                      color: colorScheme.onSecondaryContainer,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Roll button
          FilledButton.icon(
            onPressed: _isRolling ? null : _roll,
            icon: const Icon(Icons.casino),
            label: Text(_result == null ? 'Roll' : 'Roll Again'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
          ),

          const SizedBox(height: 12),

          // Close button
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// Helper function to show the modal
void showDiceRoller(
  BuildContext context, {
  required String title,
  int sides = 20,
  int modifier = 0,
  bool advantage = false,
  bool disadvantage = false,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DiceRollerModal(
      title: title,
      sides: sides,
      modifier: modifier,
      advantage: advantage,
      disadvantage: disadvantage,
    ),
  );
}
