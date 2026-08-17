import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Trust & Safety Utilities, FCRA Adverse Action Templates, and Incident SOP.
class TrustSafetySop {
  // ── 1. INCIDENT RESPONSE SOP (1-Page Written Standard) ────────────────────
  static const String incidentResponseSop = '''
SPORVE INCIDENT RESPONSE SOP (STANDARD OPERATING PROCEDURE)
------------------------------------------------------------
1. IMMEDIATE ACTION UPON ALLEGATION OF HARM:
   - Immediately suspend the accused coach account (set account_status = 'suspended').
   - Freeze all active and upcoming bookings for the coach.
   - Lock messaging channels while preserving all historical chat logs and booking records.

2. EVIDENCE PRESERVATION:
   - Export and archive complete database snapshots of messaging, session notes, and audit logs.
   - Do NOT delete or modify any records.

3. NOTIFICATION & MANDATED REPORTING:
   - Notify legal counsel immediately.
   - If allegation involves a minor or physical harm, file mandated report with local law enforcement & child protective services within 24 hours.

4. COMMUNICATION PROTOCOL:
   - Issue factual, concise communication to affected family: "The coach's account has been suspended pending safety review. A full refund for upcoming sessions has been processed."
   - Do NOT speculate or make statements regarding liability.
''';

  // ── 2. FCRA ADVERSE ACTION NOTICE TEMPLATES ────────────────────────────────
  static const String fcraPreAdverseActionNotice = '''
SUBJECT: Important Notice Regarding Your Sporve Coach Application

Dear Applicant,

Thank you for your interest in providing coaching services through the Sporve platform.

In connection with your application, a consumer background report was requested from Checkr, Inc. Enclosed/attached is a copy of the background check report as well as a summary of your rights under the Fair Credit Reporting Act (FCRA).

Sporve is reviewing this report and considering a decision that may adversely affect your eligibility to coach on the Sporve platform.

You have the right to dispute the accuracy or completeness of any information in the report directly with Checkr, Inc. within five (5) business days before any final decision is made.

Checkr, Inc.
Website: https://checkr.com/applicant-info
Phone: (840) 888-2435

Sincerely,
Sporve Trust & Safety Team
''';

  static const String fcraFinalAdverseActionNotice = '''
SUBJECT: Notice of Adverse Action - Sporve Application

Dear Applicant,

Following our pre-adverse action notice dated five business days ago, this letter serves as formal notice that Sporve is unable to approve your application for a coach profile on the Sporve platform based in whole or in part on information contained in your Checkr consumer background report.

Checkr, Inc. provided the background check report but did not make this decision and is unable to provide specific reasons for the decision.

You have the right to obtain a free copy of your report from Checkr, Inc. within 60 days and to dispute any inaccurate information.

Sincerely,
Sporve Trust & Safety Team
''';

  // ── 3. TOS HONESTY & ANNUAL RE-CHECK POLICY ─────────────────────────────
  static const String tosVerificationDisclaimer = '''
BACKGROUND CHECK & VERIFICATION DISCLAIMER:
- Sporve background checks are conducted independently by Checkr, Inc. and cover national criminal database searches, sex offender registries, and SSN trace at the time of onboarding.
- Background checks reflect historical records as of the completed date and do NOT guarantee future conduct or absolute safety.
- All coaches agree to annual re-verification in accordance with the Sporve Terms of Service.
- Parents are encouraged to observe sessions in public venues.
''';

  // ── 4. REPORT & BLOCK LOGGING ─────────────────────────────────────────────
  static final List<Map<String, dynamic>> _safetyReports = [];

  static List<Map<String, dynamic>> get safetyReports =>
      List.unmodifiable(_safetyReports);

  /// Submits a safety report (≤ 2 taps) and logs it for daily monitoring.
  static Future<void> submitReport({
    required String reporterId,
    required String reportedUserOrCoachId,
    required String reason,
    String? details,
  }) async {
    final report = {
      'id': 'rpt_${DateTime.now().millisecondsSinceEpoch}',
      'reporterId': reporterId,
      'reportedId': reportedUserOrCoachId,
      'reason': reason,
      'details': details ?? '',
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'pending_review',
    };
    _safetyReports.add(report);
    debugPrint('SAFETY REPORT FILED: $report');

    try {
      final client = Supabase.instance.client;
      await client.from('safety_reports').insert({
        'reporter_id': reporterId,
        'reported_id': reportedUserOrCoachId,
        'reason': reason,
        'details': details ?? '',
        'status': 'pending_review',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error persisting safety report to Supabase: $e');
    }
  }
}
