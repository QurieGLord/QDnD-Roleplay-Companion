import 'package:flutter/material.dart';

class ClassToolsLayoutBuilder extends StatelessWidget {
  final List<Widget?> children;
  final double spacing;
  final EdgeInsetsGeometry padding;

  const ClassToolsLayoutBuilder({
    super.key,
    required this.children,
    this.spacing = 12.0,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    // Filter out null widgets or empty SizedBoxes to prevent extra spacing
    final validChildren = children.where((child) {
      if (child == null) {
        return false;
      }
      if (child is SizedBox &&
          child.width == null &&
          child.height == null &&
          child.child == null) {
        return false;
      }
      return true;
    }).toList();

    if (validChildren.isEmpty) return const SizedBox.shrink();

    // Insert spacing only between valid children
    final spacedChildren = <Widget>[];
    for (int i = 0; i < validChildren.length; i++) {
      spacedChildren.add(validChildren[i]!);
      if (i < validChildren.length - 1) {
        spacedChildren.add(SizedBox(height: spacing));
      }
    }

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: spacedChildren,
      ),
    );
  }
}
