import 'package:flutter/material.dart';

import 'ui_feedback.dart';

class UnsavedGuard extends StatelessWidget {
  final bool hasUnsavedChanges;
  final Widget child;

  const UnsavedGuard({
    super.key,
    required this.hasUnsavedChanges,
    required this.child,
  });

  Future<bool> _confirmLeave(BuildContext context) async {
    if (!hasUnsavedChanges) return true;
    final res = await AppFeedback.showConfirmDialog(
      context,
      title: 'Unsaved changes',
      message: 'You have unsaved changes. Leave without saving?',
      confirmLabel: 'Leave',
      cancelLabel: 'Stay',
      tone: AppFeedbackTone.warning,
    );
    return res;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final ok = await _confirmLeave(context);
        if (ok && context.mounted) Navigator.pop(context);
      },
      child: child,
    );
  }
}
