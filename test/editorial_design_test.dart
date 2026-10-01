import 'dart:ui' as ui;
import 'package:aura_quest/core/theme/app_colors.dart';
import 'package:aura_quest/core/theme/app_theme.dart';
import 'package:aura_quest/core/widgets/app_theme_background.dart';
import 'package:aura_quest/core/widgets/editorial_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final (family, file) in [
      ('Editorial Display', 'DMSerifDisplay-Regular.ttf'),
      ('Editorial Body', 'PlusJakartaSans.ttf'),
    ]) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/editorial/fonts/$file'));
      await loader.load();
    }
  });
  tearDown(
      () => AppColors.apply(AppThemeType.neoBrutalist, AppThemeMode.light));

  test('editorial readable text and controls have accessible contrast', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
    }

    for (final mode in AppThemeMode.values) {
      final p = paletteFor(AppThemeType.editorial, mode);
      for (final background in [p.background, p.surface, p.surfaceLight]) {
        for (final ink in [
          p.textPrimary,
          p.textSecondary,
          p.accentText,
          p.successText,
          p.warningText,
          p.danger
        ]) {
          expect(contrast(ink, background), greaterThanOrEqualTo(4.5));
        }
        expect(contrast(p.inputOutline, background), greaterThanOrEqualTo(3));
      }
      expect(contrast(p.neonCyan, p.onAccent), greaterThanOrEqualTo(4.5));
    }
  });

  for (final mode in AppThemeMode.values) {
    for (final width in [320.0, 390.0, 768.0, 1440.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('editorial ${mode.name} / $width / text $scale',
            (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          AppColors.apply(AppThemeType.editorial, mode);
          await tester.pumpWidget(MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(AppThemeType.editorial, mode),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true),
                child: AppThemeBackground(
                    themeType: AppThemeType.editorial, child: child!)),
            home: const _Preview(),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (var i = 0; i < 4; i++) {
            await tester.drag(
                find.byType(Scrollable).first, const Offset(0, -400));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await tester.drag(
              find.byType(Scrollable).first, const Offset(0, 4000));
          await tester.pumpAndSettle();
          if (scale == 1 && (width == 390 || width == 1440)) {
            await expectLater(
                find.byType(MaterialApp),
                matchesGoldenFile(
                    'goldens/editorial_${mode.name}_${width.toInt()}.png'));
          }
        });
      }
    }
  }

  testWidgets('hover settles and reduced motion disables cover transformations',
      (tester) async {
    AppColors.apply(AppThemeType.editorial, AppThemeMode.light);
    for (final reduced in [false, true]) {
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: const Scaffold(
                  body: SingleChildScrollView(
                      child: EditorialCover(
                          title: 'Keep growing.',
                          subtitle: 'One step at a time.'))))));
      await tester.pumpAndSettle();
      final mouse =
          await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(Image)));
      await tester.pumpAndSettle();
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, reduced ? 1 : 1.035);
      expect(tester.binding.transientCallbackCount, 0);
      await mouse.removePointer();
      await tester.pumpAndSettle();
    }
  });
}

/// Uses production theme and cover; illustrative content, no network or account.
class _Preview extends StatelessWidget {
  const _Preview();
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Aura Quest'), actions: [
        IconButton(
            onPressed: () {}, icon: const Icon(Icons.add), tooltip: 'New quest')
      ]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const EditorialCover(
            title: 'Small steps.\nWild possibilities.',
            chapter: 'THE DAILY EDIT / @ALEX',
            subtitle: '2 quests waiting · 1/3 complete'),
        Text('Make today count.', style: text.headlineLarge),
        const SizedBox(height: 16),
        Container(
            padding: const EdgeInsets.all(20),
            decoration: AppColors.panelDecoration(accent: AppColors.neonCyan),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('01 / MIND & BODY',
                  style:
                      text.labelSmall?.copyWith(color: AppColors.accentText)),
              const SizedBox(height: 12),
              Text('A little movement.', style: text.headlineMedium),
              const SizedBox(height: 8),
              const Text(
                  'Twenty minutes outside. A clearer head. Your own pace.'),
              const SizedBox(height: 16),
              const LinearProgressIndicator(value: .66),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, children: [
                ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.check),
                    label: const Text('CHECK IN')),
                OutlinedButton(onPressed: () {}, child: const Text('PERKS'))
              ]),
            ])),
        const SizedBox(height: 20),
        ListTile(
            leading: Icon(Icons.notifications_active_outlined,
                color: AppColors.accentText),
            title: const Text('Activity'),
            subtitle: const Text('One invitation. A new adventure.'),
            trailing: Badge(
                label: const Text('1'), backgroundColor: AppColors.danger)),
      ]),
      bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined), label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.emoji_events_outlined), label: 'Quests'),
            NavigationDestination(
                icon: Icon(Icons.people_outline), label: 'Friends'),
            NavigationDestination(
                icon: Icon(Icons.person_outline), label: 'Profile'),
          ]),
    );
  }
}
