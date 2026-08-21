/// Chicago is Sporve's honest fallback only when no trusted listing has a
/// readable coordinate and the user has not shared their location.
const double kChicagoLatitude = 41.8781;
const double kChicagoLongitude = -87.6298;

typedef Coordinate = ({double latitude, double longitude});

/// Centers on the midpoint of the listings' bounding box so one outlier does
/// not silently make the first database row the geographic source of truth.
Coordinate listingBoundsCenter(Iterable<Coordinate> coordinates) {
  final points = coordinates.toList(growable: false);
  if (points.isEmpty) {
    return (latitude: kChicagoLatitude, longitude: kChicagoLongitude);
  }
  var minLat = points.first.latitude;
  var maxLat = points.first.latitude;
  var minLng = points.first.longitude;
  var maxLng = points.first.longitude;
  for (final point in points.skip(1)) {
    if (point.latitude < minLat) minLat = point.latitude;
    if (point.latitude > maxLat) maxLat = point.latitude;
    if (point.longitude < minLng) minLng = point.longitude;
    if (point.longitude > maxLng) maxLng = point.longitude;
  }
  return (latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2);
}
