import 'package:flutter_test/flutter_test.dart';
import 'package:sporve_app/core/utils/provider_trust.dart';

void main() {
  Map<String, dynamic> provider({
    String status = 'approved',
    String background = 'verified',
    Object? completedAt = '2026-08-20T12:00:00Z',
  }) => {
    'status': status,
    'background_check_status': background,
    'background_check_completed_at': completedAt,
  };

  test(
    'requires approval, verified check, and a valid completion timestamp',
    () {
      expect(providerTrusted(provider()), isTrue);
      expect(providerTrusted(provider(status: 'pending')), isFalse);
      expect(providerTrusted(provider(background: 'pending')), isFalse);
      expect(providerTrusted(provider(completedAt: null)), isFalse);
      expect(providerTrusted(provider(completedAt: 'not-a-date')), isFalse);
    },
  );

  test('reads the same predicate from a nested program provider', () {
    expect(
      providerTrusted({'status': 'published', 'providerId': provider()}),
      isTrue,
    );
    expect(
      providerTrusted({
        'status': 'published',
        'providerId': provider(completedAt: null),
      }),
      isFalse,
    );
  });

  test('verified without a completion date remains honestly pending', () {
    expect(
      providerTrustStatus(provider(completedAt: null)),
      'Background check pending completion',
    );
  });
}
