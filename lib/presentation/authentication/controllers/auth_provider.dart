import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/auth/app_user.dart';
import '../../../core/auth/auth_service.dart';
import '../auth_sheet.dart';

/// The SINGLE owner of auth state (#18). Wraps [AuthService] (Supabase behind
/// it), exposes plain state to the UI, and stays in sync via the auth stream —
/// including external sign-outs. GetX is used ONLY for routing here.
class AuthProvider extends ChangeNotifier {
  final AuthService _auth;
  StreamSubscription<AppUser?>? _sub;

  AuthProvider(this._auth) {
    _currentUser = _auth.currentUser;
    _wasVerified = isVerified;
    _sub = _auth.authStateChanges.listen((user) {
      final wasVerified = _wasVerified;
      _currentUser = user;
      final nowVerified = isVerified;
      _wasVerified = nowVerified;
      notifyListeners();
      // Intent preservation (spec §3.3.3): on a genuine guest → verified
      // transition, resume the single deferred action exactly once. Guard on
      // the transition edge (not merely "is verified") so re-emissions of an
      // already-verified session — token refreshes, tab focus — never re-fire.
      if (!wasVerified && nowVerified) {
        if (Get.isBottomSheetOpen ?? false) Get.back(); // close the auth popup
        _runPendingIntent();
      }
    });
  }

  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  String? _registrationEmail;

  /// Tracks the last-known verified state so the auth listener can detect the
  /// guest → verified EDGE (rather than firing on every verified emission).
  bool _wasVerified = false;

  /// The single action deferred while a guest was routed to sign in (spec
  /// §3.3.3). Held until the guest → verified transition resumes it, or until
  /// [clearPendingIntent] drops it.
  VoidCallback? _pendingAction;

  /// Runs the deferred action (if any) exactly once, clearing it first so it
  /// can never double-fire. Scheduled after the current frame so it lands on
  /// TOP of the sign-in flow's own "go home" navigation instead of being wiped
  /// by it (login does `Get.offAllNamed(home)` right after sign-in returns).
  void _runPendingIntent() {
    final action = _pendingAction;
    if (action == null) return;
    _pendingAction = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => action());
  }

  AppUser? get currentUser => _currentUser;

  /// True when there is ANY session (guest OR verified).
  bool get isLoggedIn => _currentUser != null;

  /// True for a Supabase anonymous (guest) session.
  bool get isAnonymous => _currentUser?.isAnonymous ?? false;

  /// True only for a real, identity-verified account — this is what the three
  /// auth-on-action triggers (book / message / save) gate on. A guest with an
  /// anonymous session is NOT verified.
  bool get isVerified => isLoggedIn && !isAnonymous;

  String? get role => _currentUser?.role;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get registrationEmail => _registrationEmail;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String? m) {
    _errorMessage = m;
    notifyListeners();
  }

  void setRegistrationEmail(String email) {
    _registrationEmail = email.trim();
    notifyListeners();
  }

  /// Home route for the authoritative profile role.
  String routeForRole(String? role) =>
      role == 'provider' ? AppRoutes.providerMainNav : AppRoutes.mainNav;

  Future<String> determineNextRoute() async {
    final resolved = await _auth.resolveCurrentUser();
    if (resolved != null) {
      _currentUser = resolved;
      notifyListeners();
    }
    return routeForRole(resolved?.role);
  }

  // ── New API (screens use these after Stage 4) ─────────────────────────────
  Future<AuthResult> signIn(
    String email,
    String password, {
    String? captchaToken,
  }) async {
    _setError(null);
    _setLoading(true);
    final res = await _auth.signIn(
      email: email.trim(),
      password: password,
      captchaToken: captchaToken,
    );
    if (res.status == AuthStatus.error) _setError(res.message);
    _setLoading(false);
    return res;
  }

  Future<AuthResult> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
    String? captchaToken,
  }) async {
    _setError(null);
    _setLoading(true);
    _registrationEmail = email.trim();
    final res = await _auth.signUp(
      email: email.trim(),
      password: password,
      role: role,
      name: name,
      phone: phone,
      captchaToken: captchaToken,
    );
    if (res.status == AuthStatus.error) _setError(res.message);
    _setLoading(false);
    return res;
  }

  /// Start Google OAuth. On web this redirects away and returns via the splash
  /// route guard, so there's no AuthResult to await here. [role] carries the
  /// auth-entry role choice ('searcher' | 'provider') so a coach isn't silently
  /// provisioned as a searcher.
  Future<void> signInWithGoogle({String? role}) async {
    _setError(null);
    _setLoading(true);
    try {
      await _auth.signInWithGoogle(role: role);
    } catch (e) {
      _setError('Could not start Google sign-in. Please try again.');
      _setLoading(false);
    }
    // Note: on success the page redirects; loading stays until navigation.
  }

  /// Best-effort guest sign-in (auth spec §1.3). Never throws — the underlying
  /// service logs and swallows any failure so browse works even when anonymous
  /// sign-in is disabled (e.g. the offline mock demo).
  Future<void> signInAnonymously() => _auth.signInAnonymously();

  // ── Auth-on-action gating (spec §3.2) ─────────────────────────────────────
  /// Guards the three action triggers. If the user is verified, runs [onAuthed]
  /// immediately and returns true. Otherwise it STORES [onAuthed] as the pending
  /// intent (spec §3.3.3), routes the guest to the auth entry screen (GetX =
  /// routing only), and returns false. After the guest verifies, the auth
  /// listener resumes [onAuthed] once — so the ORIGINAL action auto-completes
  /// instead of the user having to re-tap it. Storing a new intent replaces any
  /// earlier one (only the most recent deferred action matters).
  bool requireAuth(VoidCallback onAuthed) {
    if (isVerified) {
      onAuthed();
      return true;
    }
    _pendingAction = onAuthed;
    // Airbnb-style: a dismissible popup, NOT a blocking sign-in screen. On the
    // guest → verified edge the listener resumes [onAuthed] exactly once.
    showSporveAuthSheet();
    return false;
  }

  /// One-time, non-blocking "sign in or create an account" nudge shown when a
  /// guest first lands in the app. Fires at most once per app run and never for
  /// a verified user, so people can browse freely and dismiss it (swipe / X).
  bool _entryPromptShown = false;
  void maybeShowEntryPrompt() {
    if (_entryPromptShown || isVerified) return;
    _entryPromptShown = true;
    showSporveAuthSheet();
  }

  /// Drops any deferred action without running it. Safe to call at any time
  /// (e.g. if the user abandons sign-in); a guest who never verifies simply
  /// never resumes, and this makes that explicit.
  void clearPendingIntent() {
    _pendingAction = null;
  }

  /// Soft gate for save/favorite (spec §3.2): a guest may save up to 3 coaches
  /// before being prompted to verify. Removing a save is always allowed and
  /// never counts. Returns true if the toggle should proceed.
  ///
  /// Intent preservation (spec §3.3.3): when a guest exceeds the free allowance
  /// they're routed to sign in and false is returned. Pass [onAuthed] (the same
  /// toggle the caller would have run) so that after verifying, the save is
  /// applied automatically instead of the user having to tap the heart again.
  int _guestSaveCount = 0;
  bool allowSave({required bool isCurrentlySaved, VoidCallback? onAuthed}) {
    if (isVerified || isCurrentlySaved) return true; // verified, or un-saving
    if (_guestSaveCount < 3) {
      _guestSaveCount++;
      return true;
    }
    if (onAuthed != null) _pendingAction = onAuthed;
    Get.toNamed(AppRoutes.authEntry);
    return false;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    // The authStateChanges listener clears _currentUser and notifies.
  }

  /// Sign out + return to the auth entry screen (used by profile screens).
  Future<void> logout() async {
    await signOut();
    Get.offAllNamed(AppRoutes.authEntry);
  }

  // ── Password reset (#18 "email/pw + reset") ──────────────────────────────
  Future<bool> forgotPassword(String email) async {
    _setError(null);
    _setLoading(true);
    _registrationEmail = email.trim();
    final ok = await _auth.sendPasswordReset(email.trim());
    if (!ok) _setError('Could not send the reset email. Please try again.');
    _setLoading(false);
    return ok;
  }

  Future<bool> resetPassword(String token, String newPassword) async {
    _setError(null);
    _setLoading(true);
    final ok = await _auth.resetPassword(
      email: _registrationEmail ?? '',
      token: token,
      newPassword: newPassword,
    );
    if (!ok) _setError('Reset failed. Check the code and try again.');
    _setLoading(false);
    return ok;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
