import 'package:flutter_test/flutter_test.dart';
import 'package:sporve_app/core/utils/booking_tier.dart';

void main() {
  test('labels only immutable historical tiered bookings', () {
    expect(historicalBookingTierLabel(const {}), isNull);
    expect(
      historicalBookingTierLabel(const {'selectedTier': 'Standard'}),
      isNull,
    );
    expect(
      historicalBookingTierLabel(const {'selected_tier': 'PRO'}),
      'Pro tier · historical recorded price',
    );
    expect(
      historicalBookingTierLabel(const {'selectedTier': 'elite'}),
      'Elite tier · historical recorded price',
    );
  });
}
