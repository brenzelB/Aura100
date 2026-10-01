import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
// Google Fonts exposes its asset manifest specifically for offline tests.
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as fonts;
import 'package:aura_quest/core/theme/app_colors.dart';
import 'package:aura_quest/core/theme/app_theme.dart';
import 'package:aura_quest/core/widgets/app_theme_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Goldens were generated from the pre-redesign HEAD theme sources, then
/// verified against the redesign. Keep them unchanged for Editorial work.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    fonts.assetManifest = _FixtureFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final path = utf8.decode(message!.buffer
          .asUint8List(message.offsetInBytes, message.lengthInBytes));
      final file = File(path.startsWith('test/fixtures/')
          ? path
          : 'build/unit_test_assets/$path');
      return file.existsSync()
          ? ByteData.sublistView(file.readAsBytesSync())
          : null;
    });
  });
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final type in [AppThemeType.neoBrutalist, AppThemeType.auralis]) {
    for (final mode in AppThemeMode.values) {
      testWidgets('${type.name} ${mode.name} unchanged', (tester) async {
        tester.view.physicalSize = const Size(600, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        AppColors.apply(type, mode);
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(type, mode),
          builder: (_, child) =>
              AppThemeBackground(themeType: type, child: child!),
          home: Scaffold(
            appBar: AppBar(title: const Text('MY QUESTS')),
            body: ListView(padding: const EdgeInsets.all(20), children: [
              Builder(
                  builder: (context) => Text('Your next chapter',
                      style: Theme.of(context).textTheme.headlineLarge)),
              const SizedBox(height: 16),
              Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppColors.panelDecoration(
                      accent: AppColors.neonPurple, glow: true),
                  child: const Text('Morning movement · +100 Aura')),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () {}, child: const Text('CHECK IN')),
              OutlinedButton(onPressed: () {}, child: const Text('PERKS')),
              const TextField(
                  decoration: InputDecoration(labelText: 'Quest name')),
              const SizedBox(height: 16),
              const Wrap(spacing: 8, children: [
                Chip(label: Text('Classic')),
                Chip(label: Text('3 per week'))
              ]),
              const LinearProgressIndicator(value: .6),
              const ListTile(
                  title: Text('Activity'),
                  subtitle: Text('One new invitation')),
            ]),
            bottomNavigationBar: NavigationBar(destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
            ]),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
                'goldens/unchanged_${type.name}_${mode.name}.png'));
      });
    }
  }
}

class _FixtureFonts implements AssetManifest {
  @override
  List<String> listAssets() => Directory('test/fixtures/theme_fonts')
      .listSync()
      .whereType<File>()
      .map((file) => file.path.replaceAll('\\', '/'))
      .toList();
  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}
