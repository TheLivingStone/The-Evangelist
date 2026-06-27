import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers.dart';
import 'supabase.dart';
import 'theme.dart';

/// True when the signed-in user is anonymous (a guest session created at launch
/// so the app opens without a login wall). Real (email/Google/Apple) users are
/// false. Watches the auth stream so it flips the instant a guest upgrades.
final isAnonymousProvider = Provider<bool>((ref) {
  ref.watch(authStateProvider);
  final user = supabase.auth.currentUser;
  // No user at all (e.g. anonymous sign-ins disabled) is treated as "not a real
  // account" so gated actions still prompt sign-in.
  if (user == null) return true;
  return user.isAnonymous;
});

/// Gate a real-account-only action. Returns true if the user already has a real
/// account (proceed); otherwise shows the "create your account" sheet and
/// returns true only if they finished upgrading. Anonymous data carries over
/// because we link credentials to the SAME user rather than creating a new one.
///
/// Usage at any gated entry point:
/// ```dart
/// if (!await requireAccount(context, ref)) return;
/// // ... proceed with the real-account-only action
/// ```
Future<bool> requireAccount(BuildContext context, WidgetRef ref) async {
  if (!ref.read(isAnonymousProvider)) return true;
  final upgraded = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _UpgradeAccountSheet(),
  );
  return upgraded ?? false;
}

/// Bottom sheet that turns the current anonymous guest into a real account by
/// attaching an email + password (and name) to the SAME user, so everything
/// they did as a guest is kept.
class _UpgradeAccountSheet extends ConsumerStatefulWidget {
  const _UpgradeAccountSheet();
  @override
  ConsumerState<_UpgradeAccountSheet> createState() =>
      _UpgradeAccountSheetState();
}

class _UpgradeAccountSheetState extends ConsumerState<_UpgradeAccountSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final email = _email.text.trim();
    final name = _name.text.trim();
    if (email.isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter an email and password to continue.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Link credentials to the existing (anonymous) user. This keeps the same
      // user id, so all their guest data stays theirs. Name is stored in
      // user metadata; the profile row already exists from the guest signup.
      await supabase.auth.updateUser(
        UserAttributes(
          email: email,
          password: _password.text,
          data: name.isEmpty ? null : {'full_name': name},
        ),
      );
      // Reflect the new name on the profile row too (best-effort).
      if (name.isNotEmpty) {
        try {
          await ref.read(profileRepoProvider).update({'full_name': name});
        } catch (_) {
          /* non-fatal */
        }
      }
      ref.invalidate(myProfileProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not save your account. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Sign in with Apple exists only on iOS/macOS (native sheet).
  bool get _appleAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Upgrade the guest to a real account via Apple. signInWithIdToken on an
  /// anonymous session links the Apple identity to the SAME user, so all guest
  /// data is kept (same flow as the main auth screen).
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
      // Apple only sends the name on first authorization — seed it if present.
      final given = credential.givenName?.trim() ?? '';
      final family = credential.familyName?.trim() ?? '';
      final fullName = [given, family].where((s) => s.isNotEmpty).join(' ');
      if (fullName.isNotEmpty) {
        try {
          await supabase.auth.updateUser(
            UserAttributes(data: {'full_name': fullName}),
          );
          await ref.read(profileRepoProvider).update({'full_name': fullName});
        } catch (_) {/* non-fatal */}
      }
      ref.invalidate(myProfileProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on SignInWithAppleAuthorizationException catch (e) {
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
    final surface = Theme.of(context).colorScheme.surface;
    return Padding(
      // Lift above the keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          Dims.xl,
          Dims.m,
          Dims.xl,
          Dims.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Dims.muted(context).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: Dims.l),
            // Accent badge — keeps the Bold Refined identity.
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(Dims.rMd),
                ),
                child: const Icon(
                  Icons.bookmark_added_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: Dims.l),
            const Text(
              'Create your account',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Save your progress so nothing is lost. Everything you\'ve done '
              'so far stays with you.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Dims.muted(context)),
            ),
            const SizedBox(height: Dims.xl),
            _field(_name, 'Full name', Icons.person_outline_rounded,
                cap: TextCapitalization.words),
            const SizedBox(height: Dims.m),
            _field(_email, 'Email', Icons.mail_outline_rounded,
                keyboard: TextInputType.emailAddress, autocorrect: false),
            const SizedBox(height: Dims.m),
            _field(_password, 'Password', Icons.lock_outline_rounded,
                obscure: true),
            if (_error != null) ...[
              const SizedBox(height: Dims.m),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFFE5484D)),
              ),
            ],
            const SizedBox(height: Dims.xl),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Save & continue'),
              ),
            ),
            // Apple is the fastest upgrade path on iOS — offer it alongside
            // email. Linking keeps the same user id, so guest data is retained.
            if (_appleAvailable) ...[
              const SizedBox(height: Dims.m),
              Row(
                children: [
                  Expanded(
                    child: Divider(color: Dims.border(context), height: 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Dims.m),
                    child: Text('or',
                        style: TextStyle(
                            fontSize: 12.5, color: Dims.muted(context))),
                  ),
                  Expanded(
                    child: Divider(color: Dims.border(context), height: 1),
                  ),
                ],
              ),
              const SizedBox(height: Dims.m),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _apple,
                  icon: const Icon(Icons.apple, size: 22),
                  label: const Text('Continue with Apple',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    side: BorderSide(
                        color: Dims.border(context), width: Dims.hairline),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Dims.rSm)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: Dims.s),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                child: Text(
                  'Not now',
                  style: TextStyle(color: Dims.muted(context)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String hint,
    IconData icon, {
    bool obscure = false,
    bool autocorrect = true,
    TextInputType? keyboard,
    TextCapitalization cap = TextCapitalization.none,
  }) {
    return TextField(
      controller: c,
      obscureText: obscure,
      autocorrect: autocorrect,
      keyboardType: keyboard,
      textCapitalization: cap,
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
