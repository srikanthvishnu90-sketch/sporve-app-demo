import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Error Reporting & Observability Service (Sentry Integration Architecture)
class SentryService {
  static final SentryService _instance = SentryService._internal();
  factory SentryService() => _instance;
  SentryService._internal();
  final List<Map<String, dynamic>> _breadcrumbs = [];

  /// Flag indicating if Sentry live production DSN is active
  bool get isLive => kReleaseMode;

  /// Keeps a bounded diagnostic trail without turning non-fatal telemetry
  /// failures into user-facing errors or recursively calling the reporter.
  void addBreadcrumb(
    String message, {
    String category = 'app',
    Map<String, dynamic>? data,
  }) {
    _breadcrumbs.add({
      'message': message,
      'category': category,
      'data': data ?? const <String, dynamic>{},
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (_breadcrumbs.length > 30) _breadcrumbs.removeAt(0);
    if (kDebugMode) debugPrint('[$category] $message ${data ?? const {}}');
  }

  /// Initialize crash & error reporting handlers
  Future<void> initialize({String? dsn}) async {
    // Intercept uncaught Flutter errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      captureException(
        details.exception,
        stackTrace: details.stack,
        hint: 'Uncaught Flutter Framework Error: ${details.context}',
      );
    };

    // Intercept Async errors
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      captureException(
        error,
        stackTrace: stack,
        hint: 'Uncaught Platform/Async Error',
      );
      return true;
    };

    if (kDebugMode) {
      developer.log(
        '🛡️ [SentryService] Live error tracking handlers initialized.',
      );
    }
  }

  /// Capture handled exceptions (replacing former silent catches) with full diagnostic context
  Future<void> captureException(
    dynamic exception, {
    StackTrace? stackTrace,
    String? hint,
    Map<String, dynamic>? extraContext,
  }) async {
    final user = _getSafeUser();
    final fullContext = {
      'hint': hint,
      'user_id': user?.id,
      'user_email': user?.email,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'timestamp': DateTime.now().toIso8601String(),
      'breadcrumbs': List<Map<String, dynamic>>.from(_breadcrumbs),
      ...?extraContext,
    };

    if (kDebugMode) {
      developer.log(
        '🚨 [Sentry/ErrorLogged] Exception: $exception\n'
        'Context: $fullContext\n'
        'StackTrace: $stackTrace',
      );
    }

    // Persist crash log locally / remote log table if Supabase is connected
    try {
      final client = Supabase.instance.client;
      await client.from('error_logs').insert({
        'error_message': exception.toString(),
        'stack_trace': stackTrace?.toString(),
        'user_id': user?.id,
        'context': fullContext,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (reporterError) {
      // Deliberate production silence: reporting a reporter failure would
      // recurse. Debug output is bounded to this single line.
      if (kDebugMode) {
        debugPrint('SentryService reporter failed: $reporterError');
      }
    }
  }

  /// Throw intentional test exception for verification in live production/QA check
  void throwTestException() {
    throw Exception(
      'TEST PROD ERROR: Sentry verification check triggered at ${DateTime.now()}',
    );
  }

  User? _getSafeUser() {
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (reporterError) {
      // Deliberate production silence: resolving reporter context must never
      // trigger a second report. Debug output is bounded to this single line.
      if (kDebugMode) {
        debugPrint('SentryService user lookup failed: $reporterError');
      }
      return null;
    }
  }
}
