import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../home/application/activity_summary.dart';

/// Shell around the four main tabs (Home, Quests, Friends, Profile).
///
/// go_router's [StatefulNavigationShell] gives us the current tab index
/// and a `goBranch` method that switches tabs while preserving each
/// tab's own navigation stack (like Instagram / TikTok tab behavior).
class DashboardShell extends ConsumerWidget {
  const DashboardShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(activitySummaryProvider).count;
    Widget homeIcon(bool selected) => count == 0
        ? Icon(selected ? Icons.home : Icons.home_outlined)
        : Semantics(
            label: '$count new activities',
            child: Badge(
              key: selected ? const ValueKey('home-activity-badge') : null,
              backgroundColor: AppColors.danger,
              textColor: readableOn(AppColors.danger),
              label: Text(count > 99 ? '99+' : '$count'),
              child: Icon(selected ? Icons.home : Icons.home_outlined),
            ),
          );
    final icons = [
      homeIcon(false),
      const Icon(Icons.emoji_events_outlined),
      const Icon(Icons.group_outlined),
      const Icon(Icons.person_outline),
    ];
    final selectedIcons = [
      homeIcon(true),
      const Icon(Icons.emoji_events),
      const Icon(Icons.group),
      const Icon(Icons.person),
    ];
    const labels = ['Home', 'Quests', 'Friends', 'Profile'];
    void select(int index) => navigationShell.goBranch(index,
        initialLocation: index == navigationShell.currentIndex);

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 840) {
        final extended = constraints.maxWidth >= 1200;
        return Scaffold(
          body: Row(children: [
            SafeArea(
              child: NavigationRail(
                extended: extended,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: select,
                backgroundColor: AppColors.surface,
                destinations: [
                  for (var i = 0; i < labels.length; i++)
                    NavigationRailDestination(
                        icon: icons[i],
                        selectedIcon: selectedIcons[i],
                        label: Text(labels[i])),
                ],
              ),
            ),
            VerticalDivider(width: 1, color: AppColors.outline),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: navigationShell),
              ),
            ),
          ]),
        );
      }
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.outline, width: 2))),
            child: NavigationBar(
              animationDuration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: select,
              destinations: [
                for (var i = 0; i < labels.length; i++)
                  NavigationDestination(
                      icon: icons[i],
                      selectedIcon: selectedIcons[i],
                      label: labels[i]),
              ],
            )),
      );
    });
  }
}
