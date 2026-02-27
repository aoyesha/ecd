import 'package:flutter/material.dart';
import '../../core/constants.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionTitle({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 6,
            height: 22,
            decoration: BoxDecoration(
                color: AppColors.maroon,
                borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 10),
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800))),
        if (trailing != null) trailing!,
      ],
    );
  }
}
