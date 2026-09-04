/// Supabase connection settings.
///
/// Both values come from `--dart-define`, so the same source tree can be
/// pointed at the local dev stack, the NAS, or the hosted project without
/// editing code:
///
/// ```
/// flutter build apk \
///   --dart-define=SUPABASE_URL=https://your-domain.example \
///   --dart-define=SUPABASE_ANON_KEY=<anon key of that stack>
/// ```
///
/// With no defines it targets the SELF-HOSTED stack on NAS-BRA through its
/// public address, which is where this app now lives. The old local
/// `supabase start` stack is still usable for throwaway experiments — pass
/// the two defines to reach it:
///   --dart-define=SUPABASE_URL=http://10.0.2.2:54321
///
/// NOTE: the anon key is safe to ship in the client — access control is
/// enforced by Row Level Security on the database. The SERVICE ROLE key
/// is NOT safe and must never appear here: it bypasses every RLS policy.
abstract class SupabaseConfig {
  /// Base URL of the Supabase API gateway (Kong).
  ///
  ///  * self-hosted NAS : `https://api.brenzel.uk` — default, reachable
  ///    from anywhere through a Cloudflare Tunnel that terminates TLS and
  ///    forwards to Kong inside the NAS network. No port is open on the
  ///    router; the tunnel dials outward.
  ///  * same stack, LAN : `http://192.168.178.123:8000` — bypasses the
  ///    tunnel. Useful only for debugging when the tunnel is suspect.
  ///  * local dev stack : `http://10.0.2.2:54321` (emulator)
  ///  * hosted project  : `https://lbsikwxrkjwaqxjlmlds.supabase.co`
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://api.brenzel.uk',
  );

  /// Anon (publishable) key of the SAME stack as [url].
  ///
  /// Each stack signs its own keys from its own JWT secret, so a key from
  /// one environment will always be rejected by another.
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzg1MjI0ODU4LCJleHAiOjIxMDA1ODQ4NTh9.NG2dlqwopz7RL8xWG4vaKv_UUuWQMForz62iO6JVekA',
  );

  /// Deep link the browser uses to hand control back to the app after
  /// an OAuth flow (Google sign-in) on mobile.
  ///
  /// Must be registered in TWO places (see README → "Google OAuth setup"):
  ///  1. The auth config of whichever stack [url] points at
  ///     (hosted: dashboard → Authentication → URL Configuration;
  ///      self-hosted: `ADDITIONAL_REDIRECT_URLS` in the stack's `.env`)
  ///  2. AndroidManifest.xml / Info.plist as a custom URL scheme
  static const String oauthRedirectUri =
      'io.supabase.auraquest://login-callback/';

  /// Where the confirmation link in the sign-up mail lands.
  ///
  /// A WEB page, not the deep link — deliberately. The deep link only
  /// resolves on a phone that has the app; opened on a laptop it fails
  /// silently. And because GoTrue's link and its six-digit code are the
  /// SAME token, that silent failure consumed the token: the code then
  /// answered "token has expired", which reads as "registration broken"
  /// when in truth the account was already confirmed.
  ///
  /// The page confirms in plain words and offers the deep link as a
  /// button, so a phone still jumps straight into the app.
  static const String confirmRedirectUrl =
      'https://legal.brenzel.uk/confirmed.html';

  /// True once real credentials have been filled in.
  ///
  /// Lets the app run in "offline skeleton mode" without crashing on a
  /// bogus network call at startup.
  static bool get isConfigured =>
      !url.contains('YOUR_') && !anonKey.contains('YOUR_');
}
