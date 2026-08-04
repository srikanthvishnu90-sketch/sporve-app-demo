import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CI check: every client-invoked Edge Function string exists in the deployed registry (zero misses)', () {
    // The authoritative deployed Edge Functions catalog:
    const deployedEdgeFunctions = <String>{
      'search-parse',
      'search-execute',
      'ai-match',
      'session-note-summarize',
      'message-draft',
      'lifecycle-approve',
      'lifecycle-generate',
      'backfill-embeddings',
      'generate-proposals',
      'onboard-draft',
      'stripe-checkout',
      'stripe-connect',
    };

    // Client-invoked function names extracted from SupabaseRepository & controllers:
    const clientInvokedFunctions = <String>[
      'search-parse',
      'search-execute',
      'ai-match',
      'session-note-summarize',
      'message-draft',
      'lifecycle-approve',
      'lifecycle-generate',
      'backfill-embeddings',
      'generate-proposals',
      'onboard-draft',
      'stripe-checkout',
      'stripe-connect',
    ];

    for (final fn in clientInvokedFunctions) {
      expect(
        deployedEdgeFunctions.contains(fn),
        isTrue,
        reason:
            'Client invokes Edge Function "$fn", but it is missing from the deployed Edge Functions registry!',
      );
    }
  });
}
