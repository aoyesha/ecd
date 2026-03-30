import 'package:flutter/material.dart';

import 'constants.dart';

enum AppFeedbackTone { info, success, warning, error }

class AppFeedback {
  static void showSnackBar(
    BuildContext context,
    String message, {
    AppFeedbackTone tone = AppFeedbackTone.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final colors = _colorsFor(tone);
    final icon = _iconFor(tone);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.background,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        duration: duration,
        content: Row(
          children: [
            Icon(icon, color: colors.foreground, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: colors.foreground,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    AppFeedbackTone tone = AppFeedbackTone.warning,
  }) async {
    final colors = _colorsFor(tone);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(_iconFor(tone), color: colors.accent, size: 30),
          title: Text(title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(message),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(cancelLabel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  static Future<void> showMessageDialog(
    BuildContext context, {
    required String title,
    required String message,
    String actionLabel = 'OK',
    AppFeedbackTone tone = AppFeedbackTone.info,
  }) {
    final colors = _colorsFor(tone);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(_iconFor(tone), color: colors.accent, size: 30),
          title: Text(title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(message),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
  }

  static _AppFeedbackColors _colorsFor(AppFeedbackTone tone) {
    switch (tone) {
      case AppFeedbackTone.success:
        return const _AppFeedbackColors(
          background: Color(0xFFE9F7EF),
          foreground: Color(0xFF194D2F),
          accent: Color(0xFF2E7D4F),
        );
      case AppFeedbackTone.warning:
        return const _AppFeedbackColors(
          background: Color(0xFFFFF4E3),
          foreground: Color(0xFF7A4B00),
          accent: Color(0xFFCC8A00),
        );
      case AppFeedbackTone.error:
        return const _AppFeedbackColors(
          background: Color(0xFFFDECEC),
          foreground: Color(0xFF7A1E22),
          accent: AppColors.maroon,
        );
      case AppFeedbackTone.info:
        return const _AppFeedbackColors(
          background: Color(0xFFEEF4FF),
          foreground: Color(0xFF1E3A5F),
          accent: Color(0xFF3467A8),
        );
    }
  }

  static IconData _iconFor(AppFeedbackTone tone) {
    switch (tone) {
      case AppFeedbackTone.success:
        return Icons.check_circle_rounded;
      case AppFeedbackTone.warning:
        return Icons.warning_amber_rounded;
      case AppFeedbackTone.error:
        return Icons.error_rounded;
      case AppFeedbackTone.info:
        return Icons.info_rounded;
    }
  }
}

class _AppFeedbackColors {
  final Color background;
  final Color foreground;
  final Color accent;

  const _AppFeedbackColors({
    required this.background,
    required this.foreground,
    required this.accent,
  });
}
