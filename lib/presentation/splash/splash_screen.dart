import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ambient_surface.dart';
import '../../core/constants/app_assets.dart';
import 'package:provider/provider.dart';
import '../authentication/controllers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Snapshotted once at boot: is this the return leg of a web OAuth redirect?
  // Drives BOTH the routing wait and the visual — on an OAuth return we must NOT
  // replay the brand splash (that reads as "the app reset"); we show a quiet
  // "signing you in" state and hand off to home the moment the session lands.
  bool _oauthReturn = false;

  @override
  void initState() {
    super.initState();
    _oauthReturn = _isOAuthCallbackPending;
    _navigateToNext();
  }

  /// True when this cold boot is the RETURN LEG of a web OAuth redirect —
  /// "Continue with Google" does a full-page redirect back to `/app/?code=…`,
  /// which reboots the whole web app into this splash. supabase_flutter is
  /// exchanging that PKCE `code` (a network round-trip) for a real session right
  /// now, so we must WAIT for it. A cancelled/failed return carries `error=` and
  /// is NOT pending — we let it fall through to guest browse.
  bool get _isOAuthCallbackPending {
    if (!kIsWeb) return false;
    final u = Uri.base;
    final q = u.queryParameters;
    final f = u.fragment;
    if (q.containsKey('error') || f.contains('error=')) return false;
    return q.containsKey('code') ||
        q.containsKey('access_token') ||
        f.contains('access_token=') ||
        f.contains('code=');
  }

  void _navigateToNext() async {
    final oauthPending = _oauthReturn;

    // Brief hold so a normal cold-start session check resolves — but on an OAuth
    // return we skip the artificial hold entirely and hand off the instant the
    // session lands, so the return feels continuous instead of a fresh boot.
    if (!oauthPending) {
      await Future.delayed(const Duration(milliseconds: 1600));
    }
    if (!mounted) return;

    // Route guard: logged-out browsing (Airbnb / Uber model, spec §0.2/§1.2/
    // §3.1). A returning VERIFIED user goes straight to their role home. Anyone
    // else — brand-new or a guest with an anonymous session — lands directly in
    // the client browse experience. We NEVER route a new user to the auth wall;
    // auth is triggered only on an action (book / message / save).
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Restore can be SLOW: on a cold start supabase_flutter rehydrates the
    // session asynchronously, so `isVerified` may still be false right after the
    // fixed hold. On an OAuth RETURN it additionally has to finish a network
    // code-exchange. Poll for the real session before deciding the route — much
    // longer on an OAuth return — and, crucially, NEVER fall through to the
    // guest/anonymous browse while that exchange is still in flight. That
    // premature fall-through is exactly the "app resets after Google sign-in"
    // bug: the real session arrives a beat later but the user is already dumped
    // in guest browse instead of their home.
    if (!authProvider.isVerified) {
      const pollInterval = Duration(milliseconds: 200);
      final maxPolls = oauthPending ? 75 : 17; // ~15s vs ~3.4s
      for (var i = 0; i < maxPolls && !authProvider.isVerified; i++) {
        await Future.delayed(pollInterval);
        if (!mounted) return;
      }
    }

    if (authProvider.isVerified) {
      final nextRoute = await authProvider.determineNextRoute();
      if (!mounted) return;
      Get.offAllNamed(nextRoute);
    } else {
      // Not an OAuth return (or the exchange genuinely failed/was cancelled) →
      // guest / brand-new: best-effort anonymous session (swallows failure when
      // anonymous sign-in is disabled, e.g. the offline mock demo), then route
      // to browse REGARDLESS of session state.
      await authProvider.signInAnonymously();
      if (!mounted) return;
      Get.offAllNamed(AppRoutes.mainNav);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Returning from a Google/OAuth redirect: DON'T replay the brand splash —
    // that reads as "the app reset." Show a quiet, near-invisible "signing you
    // in" state on the app canvas and hand off to home the moment the session
    // resolves.
    if (_oauthReturn) {
      return const Scaffold(
        backgroundColor: AppColors.ink,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.slateText),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Signing you in…',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Normal cold start: static brand logo only — no float, no fade, no spinner.
    return Scaffold(
      // Ambient treatment over the unchanged slate wall — the glow sits behind
      // the logo mark. Static; no motion.
      body: AmbientSurface(
        baseGradient: AppColors.slateWall,
        focal: Alignment.center,
        radius: 1.1,
        glowOpacity: 0.06,
        child: Center(
          // Transparent S figure rendered WHITE on the slate wall. Static — no
          // motion.
          child: ColorFiltered(
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            child: Image.asset(AppAssets.appLogo, width: 104, height: 104),
          ),
        ),
      ),
    );
  }
}
