import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

import 'package:provider/provider.dart';
import 'core/config/env.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_typography.dart';
import 'core/auth/auth_service.dart';
import 'core/auth/mock_auth_service.dart';
import 'core/auth/supabase_auth_service.dart';
import 'core/data/app_repository.dart';
// ignore: unused_import
import 'core/data/mock_repository.dart'; // kept for one-line rollback (see below)
import 'core/data/supabase_repository.dart';
import 'presentation/onboarding/controllers/onboarding_controller.dart';
import 'presentation/onboarding/controllers/onboard_draft_controller.dart';
import 'presentation/client/controllers/home_controller.dart';
import 'presentation/client/controllers/search_provider.dart';
import 'presentation/client/controllers/match_provider.dart';
import 'core/push/push_service.dart';
import 'presentation/client/controllers/progress_updates_controller.dart';
import 'presentation/client/controllers/athlete_timeline_controller.dart';
import 'presentation/provider/controllers/provider_controller.dart';
import 'presentation/provider/controllers/billing_controller.dart';
import 'presentation/provider/controllers/parent_update_controller.dart';
import 'presentation/provider/controllers/lifecycle_controller.dart';
import 'presentation/shared/controllers/waitlist_controller.dart';
import 'presentation/provider/controllers/recurring_slots_controller.dart';
import 'presentation/provider/controllers/supply_controller.dart';
import 'presentation/provider/controllers/coach_policies_controller.dart';
import 'presentation/provider/controllers/setup_interview_controller.dart';
import 'presentation/authentication/controllers/auth_provider.dart';
import 'presentation/shared/controllers/chat_provider.dart';
import 'presentation/client/controllers/assistant_provider.dart';
import 'presentation/client/controllers/goal_intake_provider.dart';
import 'presentation/client/controllers/plan_provider.dart';

import 'package:flutter/foundation.dart';

import 'core/services/sentry_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SentryService().initialize();
  await GetStorage.init(); // Must be called before any token read/write

  // Kill the offline demo in production (Pre-launch item 0.6):
  // USE_MOCK_REPO is force-false in kReleaseMode so fake payment paths & mock mode are unreachable in production.
  const useMockRepo = !kReleaseMode &&
      bool.fromEnvironment(
        'USE_MOCK_REPO',
        defaultValue: false,
      );

  if (!useMockRepo && (Env.supabaseUrl.isEmpty || Env.supabaseAnonKey.isEmpty)) {
    runApp(const _ConfigurationErrorApp());
    return;
  }

  if (Env.supabaseUrl.isNotEmpty && Env.supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
  } else if (useMockRepo) {
    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      publishableKey: 'mock_anon_key',
    );
  }

  final AppRepository repo = useMockRepo
      ? const MockRepository()
      : SupabaseRepository();

  final AuthService authService = useMockRepo
      ? MockAuthService()
      : SupabaseAuthService();

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<AppRepository>.value(value: repo),
        Provider<PushService>(create: (_) => PushService(repo)),
        ChangeNotifierProvider(create: (_) => OnboardingProvider(repo)),
        ChangeNotifierProvider(create: (_) => OnboardDraftProvider(repo)),
        ChangeNotifierProvider(create: (_) => HomeProvider(repo)),
        ChangeNotifierProvider(create: (_) => SearchProvider(repo)),
        ChangeNotifierProvider(create: (_) => MatchProvider(repo)),
        ChangeNotifierProvider(create: (_) => ProgressUpdatesController(repo)),
        ChangeNotifierProvider(create: (_) => AthleteTimelineController(repo)),
        ChangeNotifierProvider(create: (_) => ProviderController(repo)),
        ChangeNotifierProvider(create: (_) => BillingController(repo)),
        ChangeNotifierProvider(create: (_) => ParentUpdateController(repo)),
        ChangeNotifierProvider(create: (_) => LifecycleController(repo)),
        ChangeNotifierProvider(create: (_) => WaitlistController(repo)),
        ChangeNotifierProvider(create: (_) => RecurringSlotsController(repo)),
        ChangeNotifierProvider(create: (_) => SupplyController(repo)),
        ChangeNotifierProvider(create: (_) => CoachPoliciesController(repo)),
        ChangeNotifierProvider(create: (_) => SetupInterviewController(repo)),
        ChangeNotifierProvider(create: (_) => AuthProvider(authService)),
        ChangeNotifierProvider(create: (_) => ChatProvider(repo, authService)),
        ChangeNotifierProvider(create: (_) => AssistantProvider(repo)),
        // Outcome-first reframe (Prompts 2/3/5): goal intake + Plan home.
        ChangeNotifierProvider(create: (_) => GoalIntakeProvider(repo)),
        ChangeNotifierProvider(create: (_) => PlanProvider(repo)),
      ],
      child: const MyApp(),
    ),
  );
}

class _ConfigurationErrorApp extends StatelessWidget {
  const _ConfigurationErrorApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.settings_outlined,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sporve is not configured',
                    textAlign: TextAlign.center,
                    style: AppTypography.h1.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This build is missing its public service configuration. '
                    'Provide SUPABASE_URL and SUPABASE_ANON_KEY, then rebuild.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
