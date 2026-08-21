import 'package:flutter_test/flutter_test.dart';
import 'package:sporve_app/core/utils/map_geography.dart';

void main() {
  test('empty listing set falls back to Chicago', () {
    final center = listingBoundsCenter(const []);
    expect(center.latitude, kChicagoLatitude);
    expect(center.longitude, kChicagoLongitude);
  });

  test('listing center is the midpoint of the full bounding box', () {
    final center = listingBoundsCenter(const [
      (latitude: 41.6, longitude: -88.0),
      (latitude: 42.0, longitude: -87.4),
      (latitude: 41.9, longitude: -87.9),
    ]);
    expect(center.latitude, closeTo(41.8, 0.000001));
    expect(center.longitude, closeTo(-87.7, 0.000001));
  });
}
