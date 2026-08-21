import 'package:flutter_test/flutter_test.dart';
import 'package:sporve_app/core/utils/location_text.dart';

void main() {
  test('structured address includes each component once', () {
    expect(
      locationText({
        'line1': '123 S State St',
        'city': 'Chicago',
        'state': 'IL',
      }),
      '123 S State St, Chicago, IL',
    );
  });

  test('preformatted line does not duplicate its city and state', () {
    expect(
      locationText({'line1': 'Chicago, IL', 'city': 'Chicago', 'state': 'IL'}),
      'Chicago, IL',
    );
  });

  test('falls back honestly when structured data is empty', () {
    expect(locationText(const {}, fallback: 'Evanston, IL'), 'Evanston, IL');
    expect(locationText(null), 'Location TBD');
  });

  test('short state codes are matched as tokens, not substrings', () {
    expect(
      locationText({'line1': '100 Main St', 'city': 'Carmel', 'state': 'IN'}),
      '100 Main St, Carmel, IN',
    );
  });
}
