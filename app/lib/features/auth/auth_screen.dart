import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/env.dart';
import '../../core/supabase.dart';
import '../../core/theme.dart';

/// Email/password + native Google + Sign in with Apple, all on Supabase Auth.
/// The app's auth gate (main.dart) reacts to the auth state stream, so a
/// successful sign-in routes to the home shell automatically — this screen
/// never navigates itself.
///
/// Google and Apple both use the native flow: the platform returns an OIDC
/// identity token which we hand to Supabase via `signInWithIdToken`. No browser
/// redirect / deep link is involved (unlike `signInWithOAuth`), which is why the
/// app needs the Google client IDs (see Env) and the Sign In with Apple
/// capability rather than a custom URL scheme.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _signUp = true;
  bool _busy = false;
  String? _error;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  /// Sign in with Apple is offered only where the native sheet exists: iOS and
  /// macOS. (Android/web would need the web flow + a Services ID, which we don't
  /// set up here.) Gating the button on this keeps the screen correct on every
  /// platform the Flutter app targets.
  bool get _appleAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// True when at least one social button shows, so the "or" divider only
  /// appears when there's something below it.
  bool get _hasSocial => _appleAvailable || Env.googleSignInConfigured;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_signUp) {
        await supabase.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          // full_name flows into raw_user_meta_data; the handle_new_user DB
          // trigger reads it to populate the profiles row.
          data: {'full_name': _name.text.trim()},
        );
        // With email confirmation off, signUp returns a session immediately.
        // If for any reason it didn't, sign in to complete the flow.
        if (supabase.auth.currentSession == null) {
          await supabase.auth.signInWithPassword(
            email: _email.text.trim(),
            password: _password.text,
          );
        }
      } else {
        await supabase.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Native Google sign-in. Opens the system Google account picker, then trades
  /// the returned OIDC id token for a Supabase session via signInWithIdToken.
  /// The `serverClientId` (web client) must match the client configured in
  /// Supabase's Google provider, or Supabase rejects the token's audience.
  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final googleUser = await GoogleSignIn(
        clientId: Env.googleIosClientId,
        serverClientId: Env.googleWebClientId,
      ).signIn();
      if (googleUser == null) {
        // User dismissed the picker — not an error, just stop.
        if (mounted) setState(() => _busy = false);
        return;
      }
      final auth = await googleUser.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        throw const AuthException('Google did not return an identity token.');
      }
      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: auth.accessToken,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Sign in with Apple (required by App Store 4.8 alongside Google). Apple
  /// returns an identity token bound to a nonce; Supabase verifies the token
  /// against the SHA-256 of that nonce, so we send the raw nonce here and the
  /// hashed nonce to Apple.
  Future<void> _apple() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const AuthException('Apple did not return an identity token.');
      }
      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      // Apple only sends the name on the FIRST authorization. If present, seed
      // full_name so the profile isn't blank (the handle_new_user trigger reads
      // raw_user_meta_data on signup, but updateUser covers the OIDC path).
      final given = credential.givenName?.trim() ?? '';
      final family = credential.familyName?.trim() ?? '';
      final fullName = [given, family].where((s) => s.isNotEmpty).join(' ');
      if (fullName.isNotEmpty) {
        await supabase.auth.updateUser(
          UserAttributes(data: {'full_name': fullName}),
        );
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      // Canceled is a normal user action, not an error to surface.
      if (e.code != AuthorizationErrorCode.canceled) {
        setState(() => _error = 'Apple sign-in failed. Please try again.');
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Apple sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A cryptographically secure random nonce for the Apple flow.
  String _generateNonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final rand = Random.secure();
    return List.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Dims.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo lockup — solid accent tile (the one bold moment), with a
                // soft outer ring to feel crafted rather than flat.
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(Dims.rLg),
                    ),
                    child: const Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: Dims.l),
                const Text(
                  'The Evangelist',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'A movement you can track.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Dims.muted(context)),
                ),
                const SizedBox(height: Dims.xxl),

                // Segmented Sign in / Create toggle — clearer than the old
                // bottom text-link, and a recognisable mobile pattern.
                _SegToggle(
                  signUp: _signUp,
                  enabled: !_busy,
                  onChanged: (v) => setState(() {
                    _signUp = v;
                    _error = null;
                  }),
                ),
                const SizedBox(height: Dims.xl),

                if (_signUp) ...[
                  _Field(
                    controller: _name,
                    hint: 'Full name',
                    icon: Icons.person_outline_rounded,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: Dims.m),
                ],
                _Field(
                  controller: _email,
                  hint: 'Email',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                ),
                const SizedBox(height: Dims.m),
                _Field(
                  controller: _password,
                  hint: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                ),

                if (_error != null) ...[
                  const SizedBox(height: Dims.m),
                  _ErrorBanner(message: _error!),
                ],

                const SizedBox(height: Dims.xl),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(_signUp ? 'Create account' : 'Sign in'),
                  ),
                ),

                // "or" divider only when at least one social button follows.
                if (_hasSocial) ...[
                  const SizedBox(height: Dims.xl),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: Dims.border(context), height: 1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Dims.m),
                        child: Text(
                          'or',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Dims.muted(context),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: Dims.border(context), height: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: Dims.xl),
                ],

                // Sign in with Apple — Apple platforms only; placed first per
                // Apple's guidance that it be at least as prominent as others.
                if (_appleAvailable) ...[
                  _SocialButton(
                    icon: Icons.apple,
                    label: 'Continue with Apple',
                    onPressed: _busy ? null : _apple,
                  ),
                  const SizedBox(height: Dims.m),
                ],
                // Google — hidden unless both client IDs are configured.
                if (Env.googleSignInConfigured) ...[
                  _SocialButton(
                    icon: Icons.g_mobiledata,
                    iconSize: 28,
                    label: 'Continue with Google',
                    onPressed: _busy ? null : _google,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented two-option toggle for Sign in / Create account.
class _SegToggle extends StatelessWidget {
  const _SegToggle({
    required this.signUp,
    required this.onChanged,
    required this.enabled,
  });
  final bool signUp;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(Dims.rSm),
      ),
      child: Row(
        children: [
          _seg(context, 'Sign in', !signUp, () => onChanged(false)),
          _seg(context, 'Create account', signUp, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _seg(BuildContext c, String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? Theme.of(c).colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(Dims.s),
            border: active
                ? Border.all(color: Dims.border(c), width: Dims.hairline)
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active
                  ? Theme.of(c).colorScheme.onSurface
                  : Dims.muted(c),
            ),
          ),
        ),
      ),
    );
  }
}

/// A hairline-bordered text field with a leading icon, matching the system.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.autocorrect = true,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final bool autocorrect;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      autocorrect: autocorrect,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: Dims.muted(context)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dims.rSm),
          borderSide: BorderSide(color: Dims.border(context), width: Dims.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dims.rSm),
          borderSide: BorderSide(color: Dims.border(context), width: Dims.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dims.rSm),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
        ),
      ),
    );
  }
}

/// Hairline social sign-in button (Apple / Google), consistent with _Field.
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.iconSize = 22,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: iconSize),
        label: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          side: BorderSide(color: Dims.border(context), width: Dims.hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Dims.rSm),
          ),
        ),
      ),
    );
  }
}

/// Soft danger banner for auth errors (replaces bare red text).
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    const danger = Color(0xFFE5484D);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dims.m,
        vertical: Dims.s + 2,
      ),
      decoration: BoxDecoration(
        color: danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Dims.rSm),
        border: Border.all(color: danger.withValues(alpha: 0.30), width: Dims.hairline),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: danger),
          const SizedBox(width: Dims.s),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: danger),
            ),
          ),
        ],
      ),
    );
  }
}
