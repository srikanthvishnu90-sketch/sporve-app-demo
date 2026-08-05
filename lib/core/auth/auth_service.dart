import 'app_user.dart';

/// The outcome of a sign-in / sign-up attempt. Keeps the UI from having to know
/// anything about the auth backend's exceptions or session objects.
enum AuthStatus { signedIn, emailConfirmationRequired, error }

class AuthResult {
  final AuthStatus status;

  /// Friendly, user-displayable message — only set when [status] is error.
  final String? message;

  /// The signed-in user — only set when [status] is signedIn.
  final AppUser? user;

  const AuthResult._(this.status, {this.message, this.user});

  factory AuthResult.signedIn(AppUser user) =>
      AuthResult._(AuthStatus.signedIn, user: user);

  factory AuthResult.emailConfirmationRequired() =>
      const AuthResult._(AuthStatus.emailConfirmationRequired);

  factory AuthResult.error(String message) =>
      AuthResult._(AuthStatus.error, message: message);
}

/// The single seam the app uses for authentication. Kept separate from the data
/// repository (#16) on purpose: auth and data are different concerns. The
/// concrete [SupabaseAuthService] is the only place the Supabase SDK is touched.
abstract class AuthService {
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String role, // 'searcher' | 'provider'
    required String name,
    String? phone,
    String? captchaToken,
  });

  Future<AuthResult> signIn({
    required String email,
    required String password,
    String? captchaToken,
  });

  /// Starts the Google OAuth flow. On web this REDIRECTS the page to Google and
  /// returns before completion — the session arrives on redirect-back via
  /// [authStateChanges] (the app re-enters through the splash route guard).
  ///
  /// [role] is the intended role ('searcher' | 'provider') chosen on the
  /// auth-entry screen. It is forwarded on the authorization request so the
  /// choice is EXPLICIT rather than silently defaulting to 'searcher' — a coach
  /// signing up via Google must not be dropped into the client app.
  Future<void> signInWithGoogle({String? role});

  /// Best-effort anonymous (guest) sign-in so a logged-out visitor has a real
  /// `auth.uid()` for saved-coach drafts and continuity (auth spec §1.3). MUST
  /// NOT throw — if anonymous sign-in is disabled on the project, or the network
  /// is down, implementations log and swallow so browse still works.
  Future<void> signInAnonymously();

  Future<void> signOut();

  /// The currently signed-in user, or null. Read synchronously from the
  /// persisted session (no network).
  AppUser? get currentUser;

  /// Resolves the current user from the authoritative application profile.
  /// Backends without a remote profile may use the synchronous session value.
  Future<AppUser?> resolveCurrentUser() async => currentUser;

  /// Emits on every auth change (sign-in, sign-out, token refresh). Null means
  /// signed out.
  Stream<AppUser?> get authStateChanges;

  // ── Password reset (#18 "email/pw + reset") ──────────────────────────────
  /// Sends a password-recovery email. Returns true if the request was accepted.
  Future<bool> sendPasswordReset(String email);

  /// Verifies a recovery code and sets a new password. Returns true on success.
  Future<bool> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  });

  /// Permanently deletes the user account in-app (anonymizes/deletes PII,
  /// children, messages while keeping required financial/booking audit records).
  Future<bool> deleteAccount();
}
