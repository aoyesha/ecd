import 'package:flutter/material.dart';

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
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('You have unsaved changes. Leave without saving?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Leave')),
        ],
      ),
    );
    return res ?? false;
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
