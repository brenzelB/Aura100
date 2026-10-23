import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'editorial_marks.dart';

/// Compact chapter opening with flat geometric cuts, never a blocking cover.
class EditorialCover extends StatelessWidget {
  const EditorialCover(
      {super.key,
      required this.title,
      required this.subtitle,
      this.chapter = 'THE DAILY EDIT',
      this.compact = false});
  final String title, subtitle, chapter;
  final bool compact;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: compact
                  ? Theme.of(context).textTheme.headlineLarge
                  : Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: Text(subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary))),
            const SizedBox(width: 12),
            const ExcludeSemantics(
                child: EditorialMarks(
                    completed: 0, total: 3, width: 92, height: 46)),
          ]),
        ]),
      );
}

class EditorialSectionHeading extends StatelessWidget {
  const EditorialSectionHeading(
      {super.key, required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}
