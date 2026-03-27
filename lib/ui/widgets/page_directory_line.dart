import 'package:flutter/material.dart';

import '../../core/constants.dart';

class PageDirectoryLine extends StatelessWidget {
  final List<String> segments;
  final EdgeInsetsGeometry? padding;

  const PageDirectoryLine({
    super.key,
    required this.segments,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final items = segments.where((segment) => segment.trim().isNotEmpty).toList();
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (int i = 0; i < items.length; i++) ...[
              Text(
                items[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: i == items.length - 1
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: i == items.length - 1
                      ? AppColors.maroon
                      : Colors.black54,
                  letterSpacing: 0.1,
                ),
              ),
              if (i != items.length - 1)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: Colors.black38,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
