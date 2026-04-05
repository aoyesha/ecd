import 'package:flutter/material.dart';

import '../../core/constants.dart';

class PageDirectoryLine extends StatelessWidget {
  final List<String> segments;
  final EdgeInsetsGeometry? padding;

  // 👇 pass which segment was clicked
  final ValueChanged<String>? onSegmentTap;

  const PageDirectoryLine({
    super.key,
    required this.segments,
    this.padding,
    this.onSegmentTap,
  });

  @override
  Widget build(BuildContext context) {
    final items =
    segments.where((segment) => segment.trim().isNotEmpty).toList();

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
              _BreadcrumbItem(
                label: items[i],
                isLast: i == items.length - 1,
                isFirst: i == 0,
                onTap: () => onSegmentTap?.call(items[i]),
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

class _BreadcrumbItem extends StatefulWidget {
  final String label;
  final bool isLast;
  final bool isFirst;
  final VoidCallback? onTap;

  const _BreadcrumbItem({
    required this.label,
    required this.isLast,
    required this.isFirst,
    this.onTap,
  });

  @override
  State<_BreadcrumbItem> createState() => _BreadcrumbItemState();
}

class _BreadcrumbItemState extends State<_BreadcrumbItem> {
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    final isClickable = widget.label == 'My Classes';

    Color color;
    if (widget.isLast) {
      color = AppColors.maroon;
    } else if (isHovering && isClickable) {
      color = AppColors.maroon;
    } else {
      color = Colors.grey;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => isHovering = true),
      onExit: (_) => setState(() => isHovering = false),
      cursor: isClickable ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: isClickable ? widget.onTap : null,
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
            widget.isLast ? FontWeight.w800 : FontWeight.w600,
            color: color,
            decoration: isClickable && isHovering
                ? TextDecoration.underline
                : TextDecoration.none,
          ),
        ),
      ),
    );
  }
}