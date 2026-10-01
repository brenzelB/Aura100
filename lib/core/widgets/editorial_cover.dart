import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/motion.dart';

/// Locally bundled artwork; no network, ticker, blur or gesture interception.
/// Text has its own solid surface, never over a photograph.
class EditorialCover extends StatefulWidget {
  const EditorialCover(
      {super.key,
      required this.title,
      required this.subtitle,
      this.chapter = 'THE DAILY EDIT',
      this.compact = false});
  final String title, subtitle, chapter;
  final bool compact;
  @override
  State<EditorialCover> createState() => _EditorialCoverState();
}

class _EditorialCoverState extends State<EditorialCover> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final text = Theme.of(context).textTheme;
    return StaggeredEntrance(
        child: Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        final copy = Padding(
          padding: EdgeInsets.all(wide ? 28 : 20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.auto_awesome, color: AppColors.accentText, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(widget.chapter,
                      style: text.labelSmall?.copyWith(
                          letterSpacing: 1.8, color: AppColors.accentText))),
            ]),
            const SizedBox(height: 14),
            Semantics(
                header: true,
                child: Text(widget.title,
                    style: widget.compact || !wide
                        ? text.displaySmall
                        : text.displayMedium)),
            const SizedBox(height: 12),
            Text(widget.subtitle, style: text.bodyMedium),
            const SizedBox(height: 20),
            Container(width: 48, height: 4, color: AppColors.accentText),
          ]),
        );
        final art = ExcludeSemantics(
            child: RepaintBoundary(
                child: ClipRRect(
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(64), bottomRight: Radius.circular(32)),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: AnimatedScale(
              scale: _hover && !reduced ? 1.035 : 1,
              duration:
                  reduced ? Duration.zero : const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              child: Image.asset(
                'assets/editorial/growth_${dark ? 'night' : 'day'}.webp',
                width: double.infinity,
                height: wide
                    ? (widget.compact ? 210 : 300)
                    : (widget.compact ? 120 : 180),
                fit: BoxFit.cover,
                alignment: const Alignment(.45, 0),
                cacheWidth: wide ? 960 : 768,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        )));
        return DecoratedBox(
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(32)),
              border: Border.all(color: AppColors.outline)),
          child: wide
              ? Row(children: [Expanded(child: copy), Expanded(child: art)])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [copy, art]),
        );
      }),
    ));
  }
}

class EditorialSectionHeading extends StatelessWidget {
  const EditorialSectionHeading(
      {super.key, required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}
