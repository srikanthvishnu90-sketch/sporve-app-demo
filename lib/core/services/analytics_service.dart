import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Analytics Service for Sporve Funnel & Usage Instrumentation
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Track a funnel or user action event
  Future<void> logEvent(
    String eventName, {
    Map<String, dynamic>? properties,
  }) async {
    final payload = {
      'event_name': eventName,
      'properties': properties ?? {},
      'user_id': _supabase?.auth.currentUser?.id,
      'timestamp': DateTime.now().toIso8601String(),
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    };

    if (kDebugMode) {
      developer.log('📊 [Analytics] Event: $eventName | Payload: $properties');
    }

    try {
      final client = _supabase;
      if (client != null) {
        await client.from('analytics_events').insert({
          'event_name': eventName,
          'user_id': client.auth.currentUser?.id,
          'properties': properties ?? {},
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      // Analytics should never crash the app
      if (kDebugMode) {
        developer.log('⚠️ [Analytics] Failed to persist event: $e');
      }
    }
  }

  // --- Client Funnel Shortcuts ---

  void logSearch({required String query, String? sport, String? location}) {
    logEvent('funnel_client_search', properties: {
      'query': query,
      'sport': sport,
      'location': location,
    });
  }

  void logProfileView({required String coachId, required String coachName}) {
    logEvent('funnel_client_profile_view', properties: {
      'coach_id': coachId,
      'coach_name': coachName,
    });
  }

  void logBookingStart({required String coachId, required String sport}) {
    logEvent('funnel_client_booking_start', properties: {
      'coach_id': coachId,
      'sport': sport,
    });
  }

  void logAuthCompleted({required String userId, required String role}) {
    logEvent('funnel_auth_completed', properties: {
      'user_id': userId,
      'role': role,
    });
  }

  void logPaymentStart({required String bookingId, required int amountCents}) {
    logEvent('funnel_client_payment_start', properties: {
      'booking_id': bookingId,
      'amount_cents': amountCents,
    });
  }

  void logBookingConfirmed({required String bookingId, required String coachId}) {
    logEvent('funnel_client_booking_confirmed', properties: {
      'booking_id': bookingId,
      'coach_id': coachId,
    });
  }

  // --- Coach Funnel Shortcuts ---

  void logCoachSignup({required String email}) {
    logEvent('funnel_coach_signup', properties: {'email': email});
  }

  void logBackgroundCheckSubmitted({required String coachId}) {
    logEvent('funnel_coach_bg_check', properties: {'coach_id': coachId});
  }

  void logStripeConnectCompleted({required String coachId}) {
    logEvent('funnel_coach_stripe_connect', properties: {'coach_id': coachId});
  }

  void logFirstListingCreated({required String coachId, required String sport}) {
    logEvent('funnel_coach_first_listing', properties: {
      'coach_id': coachId,
      'sport': sport,
    });
  }

  void logFirstBookingReceived({required String coachId, required String bookingId}) {
    logEvent('funnel_coach_first_booking', properties: {
      'coach_id': coachId,
      'booking_id': bookingId,
    });
  }
}
