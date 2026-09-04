import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/auth_providers.dart';

/// The steps this screen can be on.
///
/// Sign-in, sign-up, confirmation and password reset all live here rather
/// than on routes of their own: they are one conversation about getting
/// into the app, and a half-finished reset is not a place worth being able
/// to navigate back to.
enum _Stage {
  /// Sign in or create an account.
  form,

  /// Account created, waiting for the code from the confirmation mail.
  confirmSignup,

  /// Reset requested, waiting for the code from the recovery mail.
  resetCode,

  /// Code accepted — choose the new password.
  newPassword,
}

/// Login / sign-up screen backed by Supabase Auth.
///
/// Two modes toggled in place: "sign in" and "create account", plus the
/// mail-code steps that follow from either. While Supabase is unconfigured
/// (offline skeleton mode) the buttons simply navigate to the dashboard so
/// the flow stays walkable.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();

  /// false = sign in, true = create account.
  bool _isSignUp = false;

  /// Which step the screen is on.
  _Stage _stage = _Stage.form;

  /// The address the current step is about — named in the panels and used
  /// for resending. Null only on [_Stage.form].
  String? _pendingEmail;

  /// Seconds left before the resend button comes back. GoTrue rate-limits
  /// resends anyway; this only makes the wait visible instead of turning
  /// a tap into a server error.
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  /// Sends the mail for the current step again — a confirmation on
  /// [_Stage.confirmSignup], a recovery code on [_Stage.resetCode].
  Future<void> _resendMail() async {
    final email = _pendingEmail;
    if (email == null) return;
    final controller = ref.read(authControllerProvider.notifier);
    final sent = _stage == _Stage.resetCode
        ? await controller.sendPasswordReset(email)
        : await controller.resendConfirmation(email);
    if (!mounted || !sent) return; // failures surface via ref.listen
    _showSnack('Sent again to $email.', color: AppColors.surfaceLight);
    _startCooldown();
  }

  void _backToForm() {
    _cooldownTimer?.cancel();
    _codeController.clear();
    _newPasswordController.clear();
    // An abandoned reset must not leave the router pinned to this screen.
    ref.read(passwordRecoveryInProgressProvider.notifier).state = false;
    setState(() {
      _stage = _Stage.form;
      _pendingEmail = null;
      _cooldown = 0;
    });
  }

  /// Starts a password reset for whatever address is in the email field.
  ///
  /// Reports success even for addresses that have no account: telling the
  /// difference would turn this button into a way of checking who is
  /// registered here.
  Future<void> _startPasswordReset() async {
    if (_handleUnconfigured()) return;
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Enter your email address first, then tap again.');
      return;
    }

    final sent = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(email);
    if (!mounted || !sent) return;
    _codeController.clear();
    setState(() {
      _pendingEmail = email;
      _stage = _Stage.resetCode;
    });
    _startCooldown();
  }

  /// Redeems the recovery code and moves on to choosing a password.
  ///
  /// The flag goes up BEFORE the call: the code creates a session, the
  /// router reacts to that within the same frame, and without the flag
  /// already set it would redirect to the dashboard.
  Future<void> _submitRecoveryCode() async {
    final email = _pendingEmail;
    final code = _codeController.text.trim();
    if (email == null || code.length != 6) return;

    ref.read(passwordRecoveryInProgressProvider.notifier).state = true;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .verifyRecoveryCode(email: email, code: code);
    if (!mounted) return;
    if (!ok) {
      ref.read(passwordRecoveryInProgressProvider.notifier).state = false;
      _codeController.clear();
      return;
    }
    _cooldownTimer?.cancel();
    setState(() => _stage = _Stage.newPassword);
  }

  /// Saves the new password and finishes the reset.
  Future<void> _submitNewPassword() async {
    final password = _newPasswordController.text;
    if (password.length < 8) {
      _showSnack('Password needs at least 8 characters');
      return;
    }

    final ok = await ref
        .read(authControllerProvider.notifier)
        .updatePassword(password);
    if (!mounted || !ok) return;

    // Lower the flag first — the router is free to move once the reset is
    // genuinely over, and it is the router that owns navigation here.
    ref.read(passwordRecoveryInProgressProvider.notifier).state = false;
    _showSnack('Password changed. You are signed in.',
        color: AppColors.surfaceLight);
    context.go(AppRoutes.home);
  }

  /// Confirms the account with the six-digit code from the mail.
  ///
  /// GoTrue hands back a session on success, so there is no second login
  /// step — the router notices the session and moves on by itself.
  Future<void> _submitCode() async {
    final email = _pendingEmail;
    final code = _codeController.text.trim();
    if (email == null || code.length != 6) return;

    final ok = await ref
        .read(authControllerProvider.notifier)
        .confirmSignupWithCode(email: email, code: code);
    if (!mounted) return;
    if (!ok) {
      // Wrong or expired code: clear the field so the next attempt starts
      // clean instead of appending to six characters that already failed.
      _codeController.clear();

      // An expired token here almost always means the LINK in the same
      // mail was clicked first — link and code are one token, and using
      // one spends the other. The account is then already confirmed and
      // the only thing left is to sign in. Repeating the server's
      // "token has expired" would send the player looking for a problem
      // that no longer exists.
      final error = ref.read(authControllerProvider).error;
      final expired = error is AuthException &&
          (error.code == 'otp_expired' ||
              error.message.toLowerCase().contains('expired'));
      if (expired) {
        _backToForm();
        _showSnack(
          'That code is used up — you probably tapped the link already. '
          'Your account should be ready: just sign in.',
          color: AppColors.surfaceLight,
        );
      }
      return; // other messages come from ref.listen
    }
    _cooldownTimer?.cancel();
    context.go(AppRoutes.home);
  }

  void _showSnack(String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color ?? AppColors.danger),
    );
  }

  /// Offline skeleton mode: skip auth entirely, keep the flow walkable.
  bool _handleUnconfigured() {
    if (SupabaseConfig.isConfigured) return false;
    _showSnack(
      'Supabase not configured — skipping auth (skeleton mode).',
      color: AppColors.surfaceLight,
    );
    context.go(AppRoutes.home);
    return true;
  }

  Future<void> _submitEmailForm() async {
    if (_handleUnconfigured()) return;
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(authControllerProvider.notifier);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = _isSignUp
        ? await controller.signUpWithEmail(
            email: email,
            password: password,
            username: _usernameController.text.trim(),
          )
        : await controller.signInWithEmail(email: email, password: password);

    if (!mounted || !success) return; // errors surface via ref.listen below

    final hasSession =
        ref.read(authRepositoryProvider).currentSession != null;
    if (hasSession) {
      // The router redirect would also catch this — explicit go() just
      // makes the transition immediate.
      context.go(AppRoutes.home);
    } else {
      // Sign-up with email confirmation enabled: no session until the
      // user confirms. The mail has just gone out, so the resend cooldown
      // starts here rather than on first tap.
      _codeController.clear();
      setState(() {
        _pendingEmail = email;
        _stage = _Stage.confirmSignup;
      });
      _startCooldown();
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_handleUnconfigured()) return;
    // Opens the browser; on return, the router's auth listener navigates.
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    // Surface auth errors (wrong password, rate limit...) as SnackBars.
    ref.listen(authControllerProvider, (_, next) {
      final error = next.error;
      if (error == null) return;

      // Signing in with an account that never confirmed its address is the
      // same dead end as a fresh sign-up, so it gets the same way out
      // instead of a message the user can do nothing about.
      if (error is AuthException && error.code == 'email_not_confirmed') {
        final email = _emailController.text.trim();
        // ref.listen can fire mid-build; defer the rebuild by a frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _codeController.clear();
          setState(() {
            _pendingEmail = email;
            _stage = _Stage.confirmSignup;
          });
        });
        return;
      }

      final message =
          error is AuthException ? error.message : 'Something went wrong.';
      _showSnack(message);
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Hero / branding ──────────────────────────
                Text(
                  'AURA\nQUEST',
                  textAlign: TextAlign.center,
                  style: textTheme.displayMedium
                      ?.copyWith(color: AppColors.accentText),
                ),
                const SizedBox(height: 16),
                Text(
                  'Level up your habits. Outshine your friends.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 48),

                // Form and "check your inbox" occupy the same spot. The
                // switch is a soft fade rather than a cut: the account was
                // just created, and a hard swap reads as an error.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: const Cubic(0.23, 1, 0.32, 1),
                  switchOutCurve: const Cubic(0.23, 1, 0.32, 1),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.97, end: 1)
                          .animate(animation),
                      child: child,
                    ),
                  ),
                  child: switch (_stage) {
                    _Stage.form => _buildForm(textTheme, isLoading),
                    _Stage.confirmSignup =>
                      _buildCodePanel(textTheme, isLoading, recovery: false),
                    _Stage.resetCode =>
                      _buildCodePanel(textTheme, isLoading, recovery: true),
                    _Stage.newPassword =>
                      _buildNewPasswordPanel(textTheme, isLoading),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The sign-in / sign-up form.
  ///
  /// Wrapped in a KeyedSubtree because AnimatedSwitcher tells its children
  /// apart by key, while the Form's own key has to stay [_formKey] for
  /// validation to work.
  Widget _buildForm(TextTheme textTheme, bool isLoading) {
    return KeyedSubtree(
      key: const ValueKey('form'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
                  // ── Username (sign-up only) ──────────────────
                  // Stored in auth metadata; the handle_new_user DB
                  // trigger uses it to create the profile row.
                  if (_isSignUp) ...[
                    TextFormField(
                      controller: _usernameController,
                      maxLength: 24,
                      // Autocorrect turns handles into words ("denzel" →
                      // "dense"), and the capital first letter breaks a
                      // name the user has to type identically next time.
                      autofillHints: const [AutofillHints.newUsername],
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'Username',
                        counterText: '', // hide the maxLength counter
                      ),
                      validator: (value) {
                        if ((value?.trim().length ?? 0) < 3) {
                          return 'Username needs at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Email + password ─────────────────────────
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.none,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: 'Email'),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty || !email.contains('@')) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    // newPassword tells the password manager to OFFER one
                    // on sign-up instead of trying to fill an old one.
                    autofillHints: [
                      _isSignUp
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!isLoading) _submitEmailForm();
                    },
                    decoration: const InputDecoration(hintText: 'Password'),
                    validator: (value) {
                      if ((value ?? '').length < 8) {
                        return 'Password needs at least 8 characters';
                      }
                      return null;
                    },
                  ),

                  // ── Forgotten password ───────────────────────
                  // Sign-in only: during sign-up there is no password to
                  // have forgotten yet.
                  if (!_isSignUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: isLoading ? null : _startPasswordReset,
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  SizedBox(height: _isSignUp ? 24 : 8),

                  // ── Actions ──────────────────────────────────
                  ElevatedButton.icon(
                    onPressed: isLoading ? null : _submitEmailForm,
                    icon: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.mail_outline),
                    label: Text(
                      _isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN WITH EMAIL',
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : _signInWithGoogle,
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('CONTINUE WITH GOOGLE'),
                  ),
                  const SizedBox(height: 24),

                  // ── Mode toggle ──────────────────────────────
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Sign in'
                          : 'New here? Create an account',
                      style:  TextStyle(color: AppColors.neonPink),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  /// The six-digit code step, used by both mails.
  ///
  /// Sign-up confirmation and password recovery differ only in wording and
  /// in what the code buys — one panel keeps the two in step, so a fix to
  /// the paste behaviour or the cooldown can never land in one and not the
  /// other.
  ///
  /// It replaces the form instead of flashing a SnackBar: the next step
  /// happens in another app entirely, so the instruction has to survive
  /// the user switching away and coming back.
  Widget _buildCodePanel(
    TextTheme textTheme,
    bool isLoading, {
    required bool recovery,
  }) {
    final email = _pendingEmail ?? '';
    final waiting = _cooldown > 0;

    return Container(
      key: ValueKey(recovery ? 'reset-code' : 'confirm'),
      padding: const EdgeInsets.all(22),
      decoration: AppColors.panelDecoration(accent: AppColors.accentText),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            recovery ? Icons.lock_reset : Icons.mark_email_unread_outlined,
            size: 34,
            color: AppColors.accentText,
          ),
          const SizedBox(height: 14),
          Text(
            recovery ? 'RESET YOUR PASSWORD' : 'CHECK YOUR INBOX',
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall
                ?.copyWith(color: AppColors.accentText),
          ),
          const SizedBox(height: 10),
          Text(
            recovery
                ? 'If that address has an account, a code is on its way to'
                : 'We sent a six-digit code to',
            textAlign: TextAlign.center,
            style:
                textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),

          // The code is the primary path, not a fallback: it works no
          // matter which device the mail was opened on. The link in the
          // same mail only reaches the app on the phone itself.
          TextField(
            controller: _codeController,
            enabled: !isLoading,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: textTheme.headlineSmall?.copyWith(letterSpacing: 8),
            decoration: const InputDecoration(
              hintText: '••••••',
              counterText: '',
            ),
            // Six digits is the whole input — waiting for a button press
            // after the last one would be asking for a tap that carries
            // no information.
            onChanged: (value) {
              if (value.length != 6 || isLoading) return;
              recovery ? _submitRecoveryCode() : _submitCode();
            },
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: isLoading
                ? null
                : (recovery ? _submitRecoveryCode : _submitCode),
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(recovery ? 'CONTINUE' : 'CONFIRM'),
          ),
          const SizedBox(height: 14),
          Text(
            // Sagt ausdruecklich, dass Link UND Code derselbe Token sind.
            // Genau diese Information fehlte - und ihr Fehlen liess einen
            // erfolgreichen Vorgang wie einen Fehlschlag aussehen.
            'The mail also has a link — use one or the other, not both. '
            'Nothing after a minute? Look in spam.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: (isLoading || waiting) ? null : _resendMail,
            icon: const Icon(Icons.refresh, size: 18),
            // The countdown is the honest reason the button is dead —
            // a greyed-out button with no explanation reads as a bug.
            label: Text(waiting ? 'RESEND IN ${_cooldown}s' : 'RESEND CODE'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: isLoading ? null : _backToForm,
            child: Text(
              recovery ? 'Back to sign in' : 'Use a different address',
              style: TextStyle(color: AppColors.neonPink),
            ),
          ),
        ],
      ),
    );
  }

  /// The final step of a reset: choose the new password.
  ///
  /// The user already holds a session at this point, so this is a plain
  /// change of password — no old password required, because proving access
  /// to the mailbox was the proof.
  Widget _buildNewPasswordPanel(TextTheme textTheme, bool isLoading) {
    return Container(
      key: const ValueKey('new-password'),
      padding: const EdgeInsets.all(22),
      decoration: AppColors.panelDecoration(accent: AppColors.successText),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.lock_open, size: 34, color: AppColors.successText),
          const SizedBox(height: 14),
          Text(
            'NEW PASSWORD',
            textAlign: TextAlign.center,
            style:
                textTheme.headlineSmall?.copyWith(color: AppColors.successText),
          ),
          const SizedBox(height: 10),
          Text(
            'Code accepted. Pick a new password and you are back in.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _newPasswordController,
            enabled: !isLoading,
            autofocus: true,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!isLoading) _submitNewPassword();
            },
            decoration: const InputDecoration(hintText: 'New password'),
          ),
          const SizedBox(height: 6),
          Text(
            'At least 8 characters.',
            style: textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: isLoading ? null : _submitNewPassword,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('SET PASSWORD'),
          ),
        ],
      ),
    );
  }
}
