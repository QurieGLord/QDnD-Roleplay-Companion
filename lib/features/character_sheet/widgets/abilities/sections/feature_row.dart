import 'package:flutter/material.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';

/// A row of an ability list (prototype `.frow`): a tinted icon tile, the
/// name with one quiet line under it, and a trailing control or chevron.
class FeatureRow extends StatelessWidget {
  const FeatureRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.accent,
    this.muted = false,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? accent;
  final bool muted;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final tint = accent ?? c.secondary;
    return Pressable(
      onTap: onTap,
      scale: .99,
      semanticLabel: title,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: muted ? c.onSurface.withValues(alpha: .06) : Color.lerp(c.surfaceContainer, tint, .16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: muted ? c.onSurfaceVariant : tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontFamily: AppType.body, fontSize: 15, fontWeight: FontWeight.w600, height: 1.25)),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: AppType.body, fontSize: 12.5, height: 1.3, color: c.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(width: 10),
          if (trailing != null)
            Flexible(child: trailing!)
          else
            Icon(Icons.chevron_right_rounded, size: 20, color: c.onSurfaceVariant),
        ]),
      ),
    );
  }
}

/// The rounded list that holds feature rows (prototype `.list`).
class FeatureList extends StatelessWidget {
  const FeatureList({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(28)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

/// A section title of the abilities page (prototype `.sec-title`).
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.count, this.trailing});
  final String title;
  final String? count;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
      child: Row(children: [
        Expanded(
          child: Text(title,
              style: TextStyle(fontFamily: AppType.display, fontSize: 20, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: -.3, color: c.onSurface)),
        ),
        if (count != null) Text(count!, style: TextStyle(fontFamily: AppType.body, fontSize: 13, fontWeight: FontWeight.w500, color: c.onSurfaceVariant)),
        if (trailing != null) ...[const SizedBox(width: 6), trailing!],
      ]),
    );
  }
}
