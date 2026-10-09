import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/push/push_service.dart';

Future<void> main() async {
  // Required because we do async work (Supabase init) before runApp.
  WidgetsFlutterBinding.ensureInitialized();

  // The exact font files used by the two non-editorial themes are bundled as
  // assets. Keep runtime fetching off so fonts never make a network request.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final hanken = await rootBundle.loadString(
      'assets/google_fonts/OFL-HankenGrotesk.txt',
    );
    yield LicenseEntryWithLineBreaks(
      ['Hanken Grotesk'],
      hanken,
    );
    final inter = await rootBundle.loadString(
      'assets/google_fonts/OFL-Inter.txt',
    );
    yield LicenseEntryWithLineBreaks(['Inter'], inter);
  });

  // Initialize Supabase (Auth + Database).
  // Skipped while the credentials are still placeholders so the Phase 1
  // skeleton runs standalone — remove the guard once your project is set up.
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      // The SDK renamed this parameter from `anonKey` to `publishableKey`.
      // For the local stack the value is still what `supabase status`
      // prints as the "anon key" — a legacy anon JWT works fine here.
      publishableKey: SupabaseConfig.anonKey,
    );
  } else {
    debugPrint(
      '⚠ Supabase not configured yet — running in offline skeleton mode. '
      'Fill in lib/core/config/supabase_config.dart.',
    );
  }

  // Must be registered before runApp: Firebase looks the handler up by
  // name when it spawns the background isolate, and a late registration
  // means notifications arriving while the app is closed are dropped.
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

  // ProviderScope is the root of Riverpod's dependency graph.
  // Every provider in the app lives underneath it.
  runApp(const ProviderScope(child: AuraQuestApp()));
}
