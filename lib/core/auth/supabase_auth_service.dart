import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_user.dart';
import 'auth_service.dart';

/// Supabase-backed [AuthService]. This is the ONLY file that imports the
/// Supabase SDK for auth — everything above it speaks [AppUser]/[AuthResult].
class SupabaseAuthService implements AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Session-only fallback used before the authoritative profile is available.
  AppUser? _toAppUser(User? user) {
    if (user == null) return null;
    final meta = user.userMetadata ?? const <String, dynamic>{};
    return AppUser(
      id: user.id,
      email: user.email,
      role: (meta['role'] as String?) ?? 'searcher',
      name: meta['name'] as String?,
      isAnonymous: user.isAnonymous,
    );
  }

  Future<AppUser?> _resolveUser(User? user) async {
    if (user == null) return null;
    // The authoritative role lives in the profiles table. Retry once on a
    // transient failure, then fall back to the session's OWN metadata role —
    // NEVER hardcode 'searcher'. The old code downgraded a real provider to
    // searcher on any hiccup (`.single()` also throws on zero rows), which
    // dropped verified coaches into the client app and broke "restore my
    // account" on both email login and Google OAuth restore.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final profile = await _client
            .from('profiles')
            .select('role, first_name, last_name')
            .eq('id', user.id)
            .maybeSingle();
        if (profile == null) break; // no row yet (brand-new user mid-provision)
        final role = profile['role'] == 'provider' ? 'provider' : 'searcher';
        final first = profile['first_name']?.toString().trim() ?? '';
        final last = profile['last_name']?.toString().trim() ?? '';
        final fullName =
            [first, last].where((part) => part.isNotEmpty).join(' ');
        return AppUser(
          id: user.id,
          email: user.email,
          role: role,
          name: fullName.isEmpty ? null : fullName,
          isAnonymous: user.isAnonymous,
        );
      } catch (e) {
        debugPrint('Profile resolution attempt ${attempt + 1} failed: $e');
        // fall through to retry, then to the metadata fallback below
      }
    }
    // No profile row (mid-provision) or repeated failure → keep the session's
    // role from metadata, so a provider stays a provider on restore.
    return _toAppUser(user);
  }

  @override
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String role,
    required String name,
    String? phone,
    String? captchaToken,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        captchaToken: captchaToken,
        // -> user_metadata; handle_new_user reads role/name/phone into profiles
        // (and creates the providers row when role == 'provider').
        data: {
          'role': role,
          'name': name,
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        },
      );
      // Session present => confirmation is OFF, user is already in.
      // Session null => Supabase requires email confirmation first.
      if (res.session != null && res.user != null) {
        return AuthResult.signedIn((await _resolveUser(res.user))!);
      }
      return AuthResult.emailConfirmationRequired();
    } on AuthException catch (e) {
      return AuthResult.error(e.message);
    } catch (e) {
      debugPrint('SupabaseAuthService error: $e');
      return AuthResult.error('Something went wrong. Please try again.');
    }
  }

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
    String? captchaToken,
  }) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
        captchaToken: captchaToken,
      );
      final user = await _resolveUser(res.user);
      if (user != null) return AuthResult.signedIn(user);
      return AuthResult.error('Sign in failed. Please try again.');
    } on AuthException catch (e) {
      return AuthResult.error(e.message);
    } catch (e) {
      debugPrint('SupabaseAuthService error: $e');
      return AuthResult.error('Something went wrong. Please try again.');
    }
  }

  /// Deep-link the mobile OAuth flow returns through. Registered natively
  /// (iOS Info.plist CFBundleURLTypes + Android manifest intent-filter) and
  /// added to Supabase Auth → URL Configuration → Redirect URLs.
  static const String mobileRedirect = 'sporve://login-callback';

  /// The app's OWN url — origin + base path (e.g. `https://host/app/`). The
  /// bare origin sent users back to the marketing site at `/` after Google,
  /// which dead-ended the round-trip.
  static String get webRedirect => '${Uri.base.origin}${Uri.base.path}';

  @override
  Future<void> signInWithGoogle({String? role}) async {
    // Web returns to the app's own URL; mobile returns via the custom scheme
    // deep link. Both must be in Supabase's Redirect URLs allowlist.
    // supabase_flutter picks up the session on return; the splash route guard
    // then sends the user home.
    //
    // Role: the intended role ('searcher' | 'provider') is chosen on the
    // auth-entry screen and PERSISTED (OnboardingProvider → GetStorage), so it
    // survives the OAuth redirect round-trip. We forward it on the authorization
    // request so the intent is EXPLICIT and never silently 'searcher' — a coach
    // signing up via Google must not land in the client app. (Authoritative
    // provisioning of a brand-new Google user's profile role happens
    // server-side in handle_new_user; the client never hardcodes a downgrade.)
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? webRedirect : mobileRedirect,
      queryParams: {
        if (role != null && role.isNotEmpty) 'role': role,
      },
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
  }

  @override
  Future<void> signInAnonymously() async {
    // Best-effort (auth spec §1.3): a guest gets a real auth.uid() so saves /
    // history / analytics have continuity. If anonymous sign-in is disabled on
    // the project (e.g. the offline mock demo) or the call fails, we log and
    // swallow — logged-out browse must work regardless of session state.
    try {
      await _client.auth.signInAnonymously();
    } catch (e) {
      debugPrint('Anonymous sign-in failed (best-effort, ignored): $e');
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  AppUser? get currentUser => _toAppUser(_client.auth.currentSession?.user);

  @override
  Future<AppUser?> resolveCurrentUser() =>
      _resolveUser(_client.auth.currentSession?.user);

  @override
  Stream<AppUser?> get authStateChanges => _client.auth.onAuthStateChange
      .asyncMap((data) => _resolveUser(data.session?.user));

  @override
  Future<bool> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return true;
    } on AuthException catch (e) {
      debugPrint('SupabaseAuthService auth error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('SupabaseAuthService error: $e');
      return false;
    }
  }

  @override
  Future<bool> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return true;
    } on AuthException catch (e) {
      debugPrint('SupabaseAuthService auth error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('SupabaseAuthService error: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteAccount() async {
    try {
      await _client.functions.invoke('delete-user-account');
      await signOut();
      return true;
    } catch (e) {
      debugPrint('SupabaseAuthService deleteAccount error: $e');
      await signOut();
      return true;
    }
  }
}
