import 'package:flutter/material.dart';

import 'constants.dart';

class AppDialogOption<T> {
  final T value;
  final String title;
  final String? subtitle;
  final IconData icon;

  const AppDialogOption({
    required this.value,
    required this.title,
    required this.icon,
    this.subtitle,
  });
}

class AppDialogs {
  static Future<T?> showChoiceDialog<T>(
    BuildContext context, {
    required String title,
    required String message,
    required List<AppDialogOption<T>> options,
  }) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.maroon.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: AppColors.maroon,
              size: 28,
            ),
          ),
          title: Text(title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 16),
                for (final option in options) ...[
                  _DialogChoiceTile<T>(option: option),
                  if (option != options.last) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}

class _DialogChoiceTile<T> extends StatelessWidget {
  final AppDialogOption<T> option;

  const _DialogChoiceTile({required this.option});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).pop(option.value),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFFF8F2F2),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8D9DA)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(option.icon, color: AppColors.maroon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF241617),
                      ),
                    ),
                    if (option.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        option.subtitle!,
                        style: const TextStyle(
                          color: Color(0xFF6A5859),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Color(0xFF8D7375),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
