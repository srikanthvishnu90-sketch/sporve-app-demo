/// A small, UI-facing user model. Deliberately plain so the rest of the app
/// never depends on Supabase's `User` type — the auth backend stays swappable.
class AppUser {
  final String id;
  final String? email;

  /// 'searcher' | 'provider'. Live auth resolves this from `profiles`.
  final String role;
  final String? name;

  /// True for a Supabase anonymous (guest) session. A guest has a real
  /// `auth.uid()` but has NOT verified an identity — used to gate the three
  /// auth-on-action triggers (book / message / save) per the auth spec §1.3/§3.
  final bool isAnonymous;

  const AppUser({
    required this.id,
    this.email,
    required this.role,
    this.name,
    this.isAnonymous = false,
  });
}
