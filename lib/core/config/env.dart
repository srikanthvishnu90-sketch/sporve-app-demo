/// Public client configuration, injected at build/run time via
/// `--dart-define-from-file=env.json` (see CLAUDE.md › Config).
///
/// These are PUBLIC, client-safe values only. The Supabase anon/publishable key
/// is meant to ship in the client (RLS protects the data). SECRETS — Supabase
/// service_role, the hCaptcha secret, Stripe secret, Resend key — must NEVER be
/// referenced here; they live server-side only.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const hcaptchaSiteKey = String.fromEnvironment('HCAPTCHA_SITE_KEY');

  // ── Firebase Cloud Messaging (push) — public web app config (#B1) ─────────
  // All public/client-safe. The FCM SERVER credential (service account) is a
  // secret and lives only in the Edge Function, never here.
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseMessagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const firebaseProjectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const firebaseVapidKey =
      String.fromEnvironment('FIREBASE_VAPID_KEY'); // web push public key

  /// True only when the Firebase web config is present, so push code can no-op
  /// cleanly when the app hasn't been wired to a Firebase project yet.
  static bool get pushConfigured =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseProjectId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty;
}
