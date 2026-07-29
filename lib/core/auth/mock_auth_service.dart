import 'dart:async';
import 'app_user.dart';
import 'auth_service.dart';

/// A mock implementation of [AuthService] for offline demo & UI testing
/// when running with [useMockRepo]. Prevents network timeouts on sign-in / sign-up.
class MockAuthService implements AuthService {
  AppUser? _user;
  final StreamController<AppUser?> _controller =
      StreamController<AppUser?>.broadcast();

  MockAuthService() {
    // Default to a signed-in mock user for seamless demo browsing
    _user = const AppUser(
      id: 'mock_user_1',
      email: 'demo@sporve.com',
      name: 'Demo Parent',
      role: 'searcher',
    );
  }

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> get authStateChanges async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  Future<AppUser?> resolveCurrentUser() async => _user;

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
    String? captchaToken,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _user = AppUser(
      id: 'mock_user_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      name: email.contains('@') ? email.split('@').first : 'Demo User',
      role: 'searcher',
    );
    _controller.add(_user);
    return AuthResult.signedIn(_user!);
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
    await Future.delayed(const Duration(milliseconds: 400));
    _user = AppUser(
      id: 'mock_user_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      name: name.isNotEmpty ? name : 'Demo User',
      role: role,
    );
    _controller.add(_user);
    return AuthResult.signedIn(_user!);
  }

  @override
  Future<void> signInWithGoogle({String? role}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _user = AppUser(
      id: 'mock_google_user',
      email: 'google.demo@sporve.com',
      name: 'Google Demo User',
      role: role ?? 'searcher',
    );
    _controller.add(_user);
  }

  @override
  Future<void> signInAnonymously() async {
    _user = const AppUser(
      id: 'mock_anon_user',
      isAnonymous: true,
      role: 'searcher',
    );
    _controller.add(_user);
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  @override
  Future<bool> sendPasswordReset(String email) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return true;
  }

  @override
  Future<bool> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return true;
  }
}
