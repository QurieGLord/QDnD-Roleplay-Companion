import 'package:flutter/material.dart';

enum AppSnackBarTone {
  info,
  success,
  warning,
  error,
}

class AppSnackBar {
  const AppSnackBar._();

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> info(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    bool clearQueue = false,
  }) {
    return show(
      context,
      message: message,
      tone: AppSnackBarTone.info,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      clearQueue: clearQueue,
    );
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> success(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    bool clearQueue = false,
  }) {
    return show(
      context,
      message: message,
      tone: AppSnackBarTone.success,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      clearQueue: clearQueue,
    );
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> warning(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    bool clearQueue = false,
  }) {
    return show(
      context,
      message: message,
      tone: AppSnackBarTone.warning,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      clearQueue: clearQueue,
    );
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> error(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    bool clearQueue = false,
  }) {
    return show(
      context,
      message: message,
      tone: AppSnackBarTone.error,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      clearQueue: clearQueue,
    );
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context, {
    required String message,
    AppSnackBarTone tone = AppSnackBarTone.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    bool clearQueue = false,
  }) {
    assert((actionLabel == null) == (onAction == null));

    final messenger = ScaffoldMessenger.of(context);
    if (clearQueue) {
      messenger.clearSnackBars();
    } else {
      messenger.hideCurrentSnackBar();
    }

    return messenger.showSnackBar(
      _build(
        context,
        message: message,
        tone: tone,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
      ),
    );
  }

  static SnackBar _build(
    BuildContext context, {
    required String message,
    required AppSnackBarTone tone,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mediaQuery = MediaQuery.maybeOf(context);
    final safePadding = mediaQuery?.padding ?? EdgeInsets.zero;
    final colors = _toneColors(colorScheme, tone);
    final effectiveDuration = duration ?? _defaultDuration(tone, onAction);

    return SnackBar(
      behavior: SnackBarBehavior.floating,
      dismissDirection: DismissDirection.horizontal,
      duration: effectiveDuration,
      margin: EdgeInsets.fromLTRB(
        16 + safePadding.left,
        0,
        16 + safePadding.right,
        16 + safePadding.bottom,
      ),
      elevation: tone == AppSnackBarTone.error ? 4 : 2,
      backgroundColor: colors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colors.border),
      ),
      content: Row(
        children: [
          Icon(colors.icon, color: colors.iconForeground, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.foreground,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ) ??
                  TextStyle(
                    color: colors.foreground,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
      action: actionLabel != null && onAction != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: colors.actionForeground,
              onPressed: onAction,
            )
          : null,
    );
  }

  static Duration _defaultDuration(
      AppSnackBarTone tone, VoidCallback? onAction) {
    final seconds = switch (tone) {
      AppSnackBarTone.info => 3,
      AppSnackBarTone.success => 3,
      AppSnackBarTone.warning => 4,
      AppSnackBarTone.error => 6,
    };

    return Duration(seconds: onAction == null ? seconds : seconds + 2);
  }

  static _SnackBarToneColors _toneColors(
    ColorScheme colorScheme,
    AppSnackBarTone tone,
  ) {
    return switch (tone) {
      AppSnackBarTone.info => _SnackBarToneColors(
          background: colorScheme.surfaceContainerHigh,
          foreground: colorScheme.onSurface,
          border: colorScheme.outlineVariant.withValues(alpha: 0.72),
          actionForeground: colorScheme.primary,
          iconForeground: colorScheme.primary,
          icon: Icons.info_rounded,
        ),
      AppSnackBarTone.success => _SnackBarToneColors(
          background: _blend(
            _successColor(colorScheme),
            colorScheme.surfaceContainerHigh,
            0.14,
          ),
          foreground: colorScheme.onSurface,
          border: _successColor(colorScheme).withValues(alpha: 0.36),
          actionForeground: _successColor(colorScheme),
          iconForeground: _successColor(colorScheme),
          icon: Icons.check_circle_rounded,
        ),
      AppSnackBarTone.warning => _SnackBarToneColors(
          background: _blend(
            colorScheme.tertiary,
            colorScheme.surfaceContainerHigh,
            0.16,
          ),
          foreground: colorScheme.onSurface,
          border: colorScheme.tertiary.withValues(alpha: 0.36),
          actionForeground: colorScheme.tertiary,
          iconForeground: colorScheme.tertiary,
          icon: Icons.warning_rounded,
        ),
      AppSnackBarTone.error => _SnackBarToneColors(
          background: _blend(
            colorScheme.error,
            colorScheme.surfaceContainerHigh,
            0.18,
          ),
          foreground: colorScheme.onSurface,
          border: colorScheme.error.withValues(alpha: 0.48),
          actionForeground: colorScheme.error,
          iconForeground: colorScheme.error,
          icon: Icons.error_rounded,
        ),
    };
  }

  static Color _successColor(ColorScheme colorScheme) {
    return colorScheme.brightness == Brightness.dark
        ? const Color(0xFFA6E22E)
        : const Color(0xFF4F7D22);
  }

  static Color _blend(Color foreground, Color background, double opacity) {
    return Color.alphaBlend(foreground.withValues(alpha: opacity), background);
  }
}

@immutable
class _SnackBarToneColors {
  const _SnackBarToneColors({
    required this.background,
    required this.foreground,
    required this.border,
    required this.actionForeground,
    required this.iconForeground,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final Color actionForeground;
  final Color iconForeground;
  final IconData icon;
}
