import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../config/env.dart';
import '../data/app_repository.dart';

/// Registers the signed-in user's device for FCM push and stores the token via
/// [AppRepository.savePushToken]. Fully guarded: if the Firebase web config
/// isn't set ([Env.pushConfigured] == false) or permission is denied, every call
/// is a silent no-op — the app runs identically without a Firebase project.
///
/// Call [register] AFTER the user is authenticated (savePushToken needs a
/// session). Safe to call repeatedly.
class PushService {
  final AppRepository _repo;
  PushService(this._repo);

  static bool _firebaseReady = false;

  String get _platform => kIsWeb ? 'web' : defaultTargetPlatform.name;

  Future<void> register() async {
    // Web needs the JS config from Env. Mobile reads the native config files
    // (android/app/google-services.json, ios GoogleService-Info.plist), so we
    // attempt registration there and let initializeApp() no-op via catch if the
    // config isn't present yet.
    if (kIsWeb && !Env.pushConfigured) return;
    try {
      if (!_firebaseReady) {
        if (kIsWeb) {
          await Firebase.initializeApp(
            options: FirebaseOptions(
              apiKey: Env.firebaseApiKey,
              appId: Env.firebaseAppId,
              messagingSenderId: Env.firebaseMessagingSenderId,
              projectId: Env.firebaseProjectId,
            ),
          );
        } else {
          // Native platforms: options come from the bundled config files.
          await Firebase.initializeApp();
        }
        _firebaseReady = true;
      }

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = kIsWeb
          ? await messaging.getToken(
              vapidKey:
                  Env.firebaseVapidKey.isEmpty ? null : Env.firebaseVapidKey,
            )
          : await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _repo.savePushToken(token, platform: _platform);
      }

      // Keep the stored token fresh across rotations.
      messaging.onTokenRefresh.listen((t) {
        if (t.isNotEmpty) _repo.savePushToken(t, platform: _platform);
      });
    } catch (e) {
      debugPrint('PushService.register failed: $e');
    }
  }
}
