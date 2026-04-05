import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

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

  static Future<void> showHelpDialog(BuildContext context) {
    const demoVideoUrl = 'https://drive.google.com/drive/u/0/folders/14avfolE2EkJXUq-T4cE_FfdKIyZT7Vzt';
    
    Future<void> openUrl() async {
      try {
        if (Platform.isWindows) {
          // Windows: use start command
          await Process.run('cmd', ['/c', 'start', demoVideoUrl], runInShell: true);
        } else if (Platform.isMacOS) {
          // macOS: use open command
          await Process.run('open', [demoVideoUrl]);
        } else if (Platform.isLinux) {
          // Linux: try xdg-open
          await Process.run('xdg-open', [demoVideoUrl]);
        } else {
          // Fallback: use url_launcher
          final Uri url = Uri.parse(demoVideoUrl);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        }
      } catch (e) {
        // Silently handle error
      }
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.maroon.withValues(alpha: 0.15),
                          AppColors.maroon.withValues(alpha: 0.08),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.maroon.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        '?',
                        style: TextStyle(
                          color: AppColors.maroon,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Need Help?',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Access tutorials, documentation, and sample templates to get started.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.maroon,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      openUrl();
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.help_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'View Resources',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        color: AppColors.maroon,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
