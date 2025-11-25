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
      duration: const Duration(seconds: 1),
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
      
      // Delay slightly to show result before moving on
      Future.delayed(const Duration(milliseconds: 800), () {
        widget.onRoll(finalRoll);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final avgValue = (widget.hitDie / 2).floor() + 1;
    final totalAvg = avgValue + widget.conMod;
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Increase Hit Points',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how to increase your maximum HP.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          
          const Spacer(),
          
          // Dice Display
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.casino, // Placeholder for dice icon
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  _isRolling ? '$_currentRollDisplay' : 'd${widget.hitDie}',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          Text(
            'Constitution Modifier: ${widget.conMod >= 0 ? '+' : ''}${widget.conMod}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          
          const Spacer(),
          
          if (!_isRolling)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onAverage,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Column(
                      children: [
                        const Text('Take Average'),
                        const SizedBox(height: 4),
                        Text(
                          '$totalAvg HP', 
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text('($avgValue + ${widget.conMod})', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _startRoll,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Column(
                      children: [
                        const Text('Roll Dice'),
                        const SizedBox(height: 4),
                        Text(
                          '1d${widget.hitDie} + ${widget.conMod}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Text('(Risk it!)', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
          if (_isRolling)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Rolling...', style: TextStyle(fontSize: 18)),
            ),
            
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
