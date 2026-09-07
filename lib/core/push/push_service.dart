import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Prefixed: the package exports a PushMessage of its own, and ours has
// to keep the name because it is what the rest of the app speaks.
import 'package:unifiedpush/unifiedpush.dart' as up;

import '../config/supabase_config.dart';
import 'push_message.dart';

/// Everything about getting a notification onto the player's screen.
///
/// Two routes run side by side on purpose:
///
///  * **UnifiedPush** — our own server, no third party, full text. Needs
///    a distributor app (ntfy) installed, so it cannot be the only route.
///  * **Firebase** — works on any phone with Play Services and is the
///    only way iOS will ever be reachable. Carries a content-free ping;
///    the text is fetched from our server before it is shown.
///
/// A device may be registered on both. The server sends to every token
/// it has, and [_seenOutboxIds] keeps the player from seeing the same
/// message twice when both arrive.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const _channelId = 'aura_quest_events';
  static const _androidChannel = AndroidNotificationChannel(
    _channelId,
    'Quest events',
    description: 'Attacks, duels, invites and quest results.',
    importance: Importance.high,
  );

  final _local = FlutterLocalNotificationsPlugin();

  /// Outbox ids already shown. Both transports may deliver the same
  /// message; whichever arrives second is dropped.
  final _seenOutboxIds = <int>{};

  /// Called when the player taps a notification. Set by the app so this
  /// file stays free of routing and widget imports.
  void Function(PushMessage message)? onOpened;

  /// Held rather than a bool, so a second caller waits for the first
  /// call to FINISH instead of racing past it. A plain `_started` flag
  /// let the auth listener call refreshRegistration() while
  /// Firebase.initializeApp() was still in flight, which failed with
  /// "No Firebase App '[DEFAULT]' has been created".
  Future<void>? _startFuture;

  /// Wires up local notifications and both transports.
  ///
  /// Safe to call more than once: every caller gets the same future.
  Future<void> start() {
    if (!SupabaseConfig.isConfigured) return Future<void>.value();
    return _startFuture ??= _start();
  }

  Future<void> _start() async {
    await _initLocalNotifications();
    await _initFirebase();
    await _initUnifiedPush();
  }

  /// True once Firebase actually came up. Everything touching
  /// FirebaseMessaging has to check this — on a phone without Play
  /// Services it stays false for good, and calling in anyway throws.
  bool _firebaseReady = false;

  // ── Local display ────────────────────────────────────────────────

  Future<void> _initLocalNotifications() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        // The permission prompt is asked for explicitly further down, at
        // a moment where the player understands what it is for.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _local.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null) return;
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          final message = PushMessage.tryParse(data);
          if (message != null) onOpened?.call(message);
        } catch (error) {
          debugPrint('⛔ [PushService] bad payload: $error');
        }
      },
    );

    // Android needs the channel to exist before the first notification,
    // otherwise the importance we ask for here is ignored.
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  /// Last known push endpoints for unregistration and session refresh.
  String? _lastUnifiedPushEndpoint;
  String? _lastFcmToken;

  /// Shows [message], fetching the real text first when the ping came
  /// through Firebase and carried none.
  Future<void> show(PushMessage message) async {
    if (Supabase.instance.client.auth.currentUser == null) {
      debugPrint('ℹ [PushService] Suppressing push: user is logged out');
      return;
    }

    if (message.outboxId != null && !_seenOutboxIds.add(message.outboxId!)) {
      return; // already shown via the other transport
    }

    final full = message.needsFetch ? await _fetchText(message) : message;

    await _local.show(
      // The outbox id doubles as the notification id, so a message that
      // somehow arrives twice replaces itself instead of stacking.
      id: full.outboxId ??
          DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: full.title,
      body: full.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(full.body),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode({
        'category': full.category,
        'refId': full.refId,
        'id': full.outboxId,
        'title': full.title,
        'message': full.body,
      }),
    );
  }

  /// Asks our own server what the notification actually says.
  ///
  /// Failure is not an error worth surfacing: the fallback text already
  /// names the category, so the player still learns something happened.
  /// Better a vague notification than none.
  Future<PushMessage> _fetchText(PushMessage message) async {
    try {
      final rows = await Supabase.instance.client.rpc<List<dynamic>>(
        'get_notification',
        params: {'p_id': message.outboxId},
      );
      if (rows.isEmpty) return message;
      final row = rows.first as Map<String, dynamic>;
      return message.withText(
        title: row['title'] as String,
        body: row['body'] as String,
      );
    } catch (error) {
      debugPrint('⚠ [PushService] could not fetch text: $error');
      return message;
    }
  }

  // ── Firebase ─────────────────────────────────────────────────────

  Future<void> _initFirebase() async {
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
      final messaging = FirebaseMessaging.instance;

      // Deliberately NOT asking for permission here. The system prompt
      // is a one-shot on Android 13+: two refusals and it can only be
      // undone in the system settings. Firing it cold over the home
      // screen, before the player knows what push is for in this app,
      // is the surest way to earn that refusal. [askPermission] is
      // called from a screen that explains itself first.

      // Tokens rotate — on reinstall, restore, or at Google's discretion.
      // Registered before the first fetch so a token that only arrives
      // after a retry still lands on the server.
      messaging.onTokenRefresh.listen((fresh) => _register('fcm', fresh));

      // Its own try: a failed token fetch (no Play Services, blocked
      // network, emulator quirk) must not skip the listeners above or
      // stop UnifiedPush from being set up afterwards.
      try {
        final token = await messaging.getToken();
        if (token != null) await _register('fcm', token);
      } catch (error) {
        debugPrint('⚠ [PushService] no FCM token: $error');
      }

      FirebaseMessaging.onMessage.listen((remote) {
        final message = PushMessage.tryParse(remote.data);
        if (message != null) show(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((remote) {
        final message = PushMessage.tryParse(remote.data);
        if (message != null) onOpened?.call(message);
      });

      // The app may have been launched by tapping a notification while
      // it was not running at all.
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        final message = PushMessage.tryParse(initial.data);
        if (message != null) onOpened?.call(message);
      }
    } catch (error) {
      // A missing google-services.json or a phone without Play Services
      // must not take the app down — UnifiedPush may still work.
      debugPrint('⚠ [PushService] Firebase unavailable: $error');
    }
  }

  // ── UnifiedPush ──────────────────────────────────────────────────

  Future<void> _initUnifiedPush() async {
    try {
      await up.UnifiedPush.initialize(
        onNewEndpoint: (endpoint, instance) {
          _register('unifiedpush', endpoint.url);
        },
        onRegistrationFailed: (reason, instance) {
          debugPrint('⚠ [PushService] UnifiedPush registration failed: $reason');
        },
        onUnregistered: (instance) {
          debugPrint('ℹ [PushService] UnifiedPush unregistered');
        },
        onMessage: (message, instance) {
          try {
            final data = jsonDecode(utf8.decode(message.content))
                as Map<String, dynamic>;
            final parsed = PushMessage.tryParse(data);
            if (parsed != null) show(parsed);
          } catch (error) {
            debugPrint('⛔ [PushService] bad UnifiedPush payload: $error');
          }
        },
      );

      // Zwei Schritte, und der zweite ist der entscheidende:
      // tryUseCurrentOrDefaultDistributor() WAEHLT nur einen Verteiler
      // aus und sagt, ob ueberhaupt einer da ist. Erst register()
      // fordert einen Endpunkt an - und muss laut Paket bei JEDEM
      // App-Start erneut aufgerufen werden, nicht nur beim ersten.
      final hasDistributor =
          await up.UnifiedPush.tryUseCurrentOrDefaultDistributor();
      if (!hasDistributor) {
        // Normalfall auf Geraeten ohne ntfy: kein Verteiler installiert.
        // Firebase traegt dann allein.
        debugPrint('ℹ [PushService] no UnifiedPush distributor installed');
        return;
      }
      await up.UnifiedPush.register();
      debugPrint('✅ [PushService] UnifiedPush endpoint requested');
    } catch (error) {
      debugPrint('⚠ [PushService] UnifiedPush unavailable: $error');
    }
  }

  // ── Permission ───────────────────────────────────────────────────

  /// What the system currently says, without asking anything.
  Future<AuthorizationStatus> permissionStatus() async {
    if (!_firebaseReady) return AuthorizationStatus.notDetermined;
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus;
    } catch (_) {
      return AuthorizationStatus.notDetermined;
    }
  }

  /// Shows the system prompt and, if granted, fetches the token that the
  /// blocked start-up could not.
  ///
  /// Call this only after the player has been told what it is for.
  Future<bool> askPermission() async {
    if (!_firebaseReady) return false;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      if (granted) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) await _register('fcm', token);
      }
      return granted;
    } catch (error) {
      debugPrint('⛔ [PushService] permission request failed: $error');
      return false;
    }
  }

  // ── Server side ──────────────────────────────────────────────────

  Future<void> _register(String provider, String token) async {
    if (provider == 'unifiedpush') {
      _lastUnifiedPushEndpoint = token;
    } else if (provider == 'fcm') {
      _lastFcmToken = token;
    }

    if (Supabase.instance.client.auth.currentSession == null) return;
    try {
      await Supabase.instance.client.rpc<void>('register_device', params: {
        'p_provider': provider,
        'p_platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        'p_token': token,
      });
      debugPrint('✅ [PushService] registered $provider device');
    } catch (error) {
      debugPrint('⛔ [PushService] register_device failed: $error');
    }
  }

  /// Drops this device's tokens so the next player to sign in here does
  /// not inherit the previous one's notifications.
  Future<void> unregisterAll() async {
    _seenOutboxIds.clear();
    final client = Supabase.instance.client;

    // 1. Unregister UnifiedPush endpoint if recorded
    if (_lastUnifiedPushEndpoint != null) {
      try {
        await client.rpc<void>('unregister_device',
            params: {'p_token': _lastUnifiedPushEndpoint});
        debugPrint('✅ [PushService] unregistered UnifiedPush endpoint');
      } catch (error) {
        debugPrint('⚠ [PushService] unregister UnifiedPush failed: $error');
      }
    }

    // 2. Unregister FCM token
    String? token = _lastFcmToken;
    if (token == null && _firebaseReady) {
      try {
        token = await FirebaseMessaging.instance.getToken();
      } catch (_) {}
    }
    if (token != null) {
      try {
        await client
            .rpc<void>('unregister_device', params: {'p_token': token});
        debugPrint('✅ [PushService] unregistered FCM token');
      } catch (error) {
        debugPrint('⚠ [PushService] unregister FCM failed: $error');
      }
    }
  }

  /// Re-registers after a sign-in. The token itself does not change, but
  /// it has to be attached to the account that now holds the session.
  Future<void> refreshRegistration() async {
    if (Supabase.instance.client.auth.currentSession == null) return;

    // 1. Re-register FCM
    if (_firebaseReady) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) await _register('fcm', token);
      } catch (error) {
        debugPrint('⚠ [PushService] refresh FCM failed: $error');
      }
    } else if (_lastFcmToken != null) {
      await _register('fcm', _lastFcmToken!);
    }

    // 2. Re-register UnifiedPush
    if (_lastUnifiedPushEndpoint != null) {
      await _register('unifiedpush', _lastUnifiedPushEndpoint!);
    } else {
      try {
        final hasDistributor =
            await up.UnifiedPush.tryUseCurrentOrDefaultDistributor();
        if (hasDistributor) {
          await up.UnifiedPush.register();
        }
      } catch (error) {
        debugPrint('⚠ [PushService] refresh UnifiedPush failed: $error');
      }
    }
  }
}

/// Handles pings that arrive while the app is not in the foreground.
///
/// This runs in its own isolate: nothing from the running app is
/// available here, not even an initialized Supabase client. Both have to
/// be set up from scratch — which is why the fetch can fail and the
/// fallback text matters.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage remote) async {
  final message = PushMessage.tryParse(remote.data);
  if (message == null) return;

  try {
    await Firebase.initializeApp();
    if (SupabaseConfig.isConfigured) {
      // Restores the stored session from disk, which is what makes the
      // text fetch possible at all.
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
      );
    }
  } catch (error) {
    debugPrint('⚠ [push background] init failed: $error');
  }

  await PushService.instance._initLocalNotifications();
  await PushService.instance.show(message);
}
