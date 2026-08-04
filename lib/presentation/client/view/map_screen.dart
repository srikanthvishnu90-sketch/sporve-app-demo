import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/sport_colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../widgets/common_widgets.dart';
import '../controllers/home_controller.dart';
import '../controllers/search_provider.dart';
import 'search_screen.dart' show Opportunity;

/// Real map of nearby companies/coaches — each published program is a
/// sport-colored PRICE PIN at its real lat/lng (OpenStreetMap dark tiles, no
/// API key). Reflects the active sport filter, shows the user's live location
/// with a recenter control and distance-to-you, a list⇄map sheet, and an empty
/// state. Tapping a pin (or list row) surfaces a card that opens the listing.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _map = MapController();
  Map<String, dynamic>? _selected;
  LatLng? _userLatLng;

  static const LatLng _miami = LatLng(25.7617, -80.1918);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
  }

  Future<void> _locate() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() => _userLatLng = LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      // No location available — the map simply stays centered on the listings.
    }
  }

  String? _sportFilter(SearchProvider search) {
    final arg = Get.arguments;
    if (arg is Map && arg['sport'] != null) return arg['sport'].toString();
    return search.constraints['sport']?.toString();
  }

  List<_Pin> _pins(List<dynamic> programs, String? sport) {
    final pins = <_Pin>[];
    for (final p in programs) {
      if (p is! Map) continue;
      if (sport != null &&
          !(p['sportType']?.toString().toLowerCase().contains(
                sport.toLowerCase(),
              ) ??
              false)) {
        continue;
      }
      final coords = p['location']?['coordinates'];
      if (coords is! List || coords.length < 2) continue;
      final lng = (coords[0] as num?)?.toDouble();
      final lat = (coords[1] as num?)?.toDouble();
      if (lat == null || lng == null || (lat == 0 && lng == 0)) continue;
      pins.add(_Pin(LatLng(lat, lng), Map<String, dynamic>.from(p)));
    }
    return pins;
  }

  static double _rad(num d) => d * math.pi / 180.0;
  static num _km(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  DateTime? _lastPinTap;

  void _select(_Pin pin) {
    _lastPinTap = DateTime.now();
    setState(() => _selected = pin.data);
    _map.move(pin.pos, math.max(_map.camera.zoom, 13));
  }

  void _recenter(List<_Pin> pins) {
    final target = _userLatLng ?? (pins.isNotEmpty ? pins.first.pos : _miami);
    _map.move(target, _userLatLng != null ? 13 : 11.5);
  }

  @override
  Widget build(BuildContext context) {
    final programs = context.watch<HomeProvider>().programs;
    final search = context.watch<SearchProvider>();
    final sport = _sportFilter(search);
    final pins = _pins(programs, sport);
    final center = pins.isNotEmpty ? pins.first.pos : _miami;

    return GradientScaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 11.5,
              onTap: (_, _) {
                if (_lastPinTap != null &&
                    DateTime.now().difference(_lastPinTap!).inMilliseconds <
                        400) {
                  return;
                }
                setState(() => _selected = null);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sporve.app',
              ),
              MarkerLayer(
                markers: [
                  if (_userLatLng != null)
                    Marker(
                      point: _userLatLng!,
                      width: 24,
                      height: 24,
                      child: const _UserDot(),
                    ),
                  for (final pin in pins)
                    Marker(
                      point: pin.pos,
                      width: 78,
                      height: 34,
                      child: GestureDetector(
                        onTap: () => _select(pin),
                        child: _PricePin(
                          sport: pin.data['sportType']?.toString(),
                          price: pin.data['price'],
                          selected: _selected != null &&
                              (_selected!['_id'] != null &&
                                  _selected!['_id'] == pin.data['_id']),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Text(
                        sport != null
                            ? '${pins.length} ${sport[0].toUpperCase()}${sport.substring(1)} ${pins.length == 1 ? 'coach' : 'coaches'}'
                            : '${pins.length} ${pins.length == 1 ? 'coach' : 'coaches'} on the map',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.font(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SporveIconButton(
                    Icons.view_list_rounded,
                    semanticLabel: 'List view',
                    onTap: pins.isEmpty ? null : () => _openList(pins),
                    filled: true,
                  ),
                ],
              ),
            ),
          ),

          // Empty state
          if (pins.isEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_off_outlined,
                      color: AppColors.textTertiary,
                      size: 28,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      sport != null
                          ? 'No $sport coaches on the map yet'
                          : 'No coaches to show here',
                      textAlign: TextAlign.center,
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try a different sport or widen your search.',
                      textAlign: TextAlign.center,
                      style: AppTypography.font(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Recenter FAB
          Positioned(
            right: 16,
            bottom: _selected != null
                ? MediaQuery.of(context).padding.bottom + 150
                : MediaQuery.of(context).padding.bottom + 32,
            child: _RoundButton(
              icon: _userLatLng != null
                  ? Icons.my_location
                  : Icons.center_focus_strong,
              onTap: () => _recenter(pins),
            ),
          ),

          if (_selected != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 24,
              child: _ListingCard(
                program: _selected!,
                distanceKm: _userLatLng == null
                    ? null
                    : _distanceTo(_selected!),
              ),
            ),
        ],
      ),
    );
  }

  num? _distanceTo(Map<String, dynamic> program) {
    final coords = program['location']?['coordinates'];
    if (_userLatLng == null || coords is! List || coords.length < 2) return null;
    final lng = (coords[0] as num?)?.toDouble();
    final lat = (coords[1] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return _km(_userLatLng!, LatLng(lat, lng));
  }

  void _openList(List<_Pin> pins) {
    // Sort by distance to the user when known.
    final ordered = [...pins];
    if (_userLatLng != null) {
      ordered.sort((a, b) => _km(_userLatLng!, a.pos).compareTo(
            _km(_userLatLng!, b.pos),
          ));
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scroll) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.slateText,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${ordered.length} ${ordered.length == 1 ? 'coach' : 'coaches'}',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scroll,
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: ordered.length,
                separatorBuilder: (_, _) => const Hairline(),
                itemBuilder: (_, i) {
                  final pin = ordered[i];
                  return _ListRow(
                    program: pin.data,
                    distanceKm:
                        _userLatLng == null ? null : _km(_userLatLng!, pin.pos),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _select(pin); // list → map sync
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pin {
  final LatLng pos;
  final Map<String, dynamic> data;
  _Pin(this.pos, this.data);
}

/// Airbnb-style price pin — sport-colored, price shown, fills when selected.
class _PricePin extends StatelessWidget {
  final String? sport;
  final dynamic price;
  final bool selected;
  const _PricePin({
    required this.sport,
    required this.price,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final c = SportColors.of(sport);
    final label = '\$${price is num ? price.round() : (price ?? 0)}';
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c : AppColors.ink,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c, width: selected ? 2 : 1.5),
          boxShadow: selected
              ? SportColors.glowOf(sport)
              : const [BoxShadow(color: Colors.black54, blurRadius: 6)],
        ),
        child: Text(
          label,
          style: AppTypography.font(
            color: selected ? SportColors.onColorOf(sport) : AppColors.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: AppColors.slate,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(color: AppColors.slate.withValues(alpha: 0.6), blurRadius: 10),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.hairline),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
        ),
        child: Icon(icon, color: AppColors.slateText, size: 22),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  final Map<String, dynamic> program;
  final num? distanceKm;
  final VoidCallback onTap;
  const _ListRow({
    required this.program,
    required this.distanceKm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sport = program['sportType']?.toString();
    final title = program['title']?.toString() ?? 'Program';
    final coach = (program['providerId'] is Map
            ? program['providerId']['businessName']
            : null)
        ?.toString() ??
        'Academy';
    final price = program['price'];
    // Grounded: a real rating (with ★) or an honest "New" — never a fake 0.0★.
    final hasRating =
        program['averageRating'] is num && (program['averageRating'] as num) > 0;
    final rating = hasRating ? '${program['averageRating']}★' : 'New';
    return ListTile(
      onTap: onTap,
      leading: SportIconTile(sport ?? '', size: 44),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.font(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        distanceKm != null
            ? '$coach · ${distanceKm!.round()} km · $rating'
            : '$coach · $rating',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.font(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: Text(
        '\$${price is num ? price.round() : (price ?? 0)}',
        style: AppTypography.font(
          color: SportColors.of(sport),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final Map<String, dynamic> program;
  final num? distanceKm;
  const _ListingCard({required this.program, required this.distanceKm});

  @override
  Widget build(BuildContext context) {
    final sport = program['sportType']?.toString();
    final title = program['title']?.toString() ?? 'Program';
    final coach = (program['providerId'] is Map
            ? program['providerId']['businessName']
            : null)
        ?.toString() ??
        'Academy';
    final price = program['price'];
    // Grounded: a real rating or an honest "New" — never a fabricated 0.0★.
    final hasRating =
        program['averageRating'] is num && (program['averageRating'] as num) > 0;
    final rating = hasRating ? program['averageRating'].toString() : 'New';

    return GestureDetector(
      onTap: () => Get.toNamed(
        AppRoutes.sessionDetails,
        arguments: _opportunity(program),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.hairlineStrong),
          boxShadow: const [
            BoxShadow(
              color: Colors.black87,
              blurRadius: 16,
              spreadRadius: 2,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 42,
              decoration: BoxDecoration(
                color: SportColors.of(sport),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            SportIconTile(sport ?? '', size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    distanceKm != null
                        ? '$coach · ${distanceKm!.round()} km away'
                        : coach,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (hasRating) ...[
                        const Icon(Icons.star, color: AppColors.textPrimary, size: 12),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        rating,
                        style: AppTypography.font(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '\$${price is num ? price.round() : (price ?? 0)}',
                        style: AppTypography.font(
                          color: SportColors.of(sport),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  Opportunity _opportunity(Map<String, dynamic> p) => Opportunity(
    id: 0,
    programId: p['_id']?.toString(),
    title: p['title']?.toString() ?? 'Program',
    coach: (p['providerId'] is Map ? p['providerId']['businessName'] : null)
            ?.toString() ??
        'Academy',
    price:
        '\$${p['price'] is num ? (p['price'] as num).round() : (p['price'] ?? 0)}',
    rating: (p['averageRating'] is num && (p['averageRating'] as num) > 0)
        ? p['averageRating'].toString()
        : 'New', // grounded — real rating or honest "New", no fake 0.0
    image: '',
    spotsLeft: '',
    isVerified: false,
    bookingTrend: '',
    top: 0,
    team: '',
    rawData: p,
  );
}
