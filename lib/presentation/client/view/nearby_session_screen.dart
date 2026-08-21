import 'package:flutter/material.dart';
import 'package:sporve_app/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/sport_colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/provider_trust.dart';
import '../controllers/home_controller.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import 'search_screen.dart'; // Opportunity model (carries real program _id)

/// A nearby field derived from a REAL program. The map ETA/traffic theatre was
/// removed — there is no routing backend, so we never fabricate travel times.
/// What's real: name, address, coach, sport, and a Maps deep-link.
class _NearbyField {
  final int index;
  final String name;
  final String address;
  // Whether [address] is a real, geocodable address (vs a placeholder). Gates
  // the "Open in Maps" deep-link so we never launch a useless placeholder query.
  final bool hasAddress;
  final String coach;
  final String sport;
  final Opportunity opp; // for "View details" -> booking flow
  final double top;
  final double? left;
  final double? right;

  const _NearbyField({
    required this.index,
    required this.name,
    required this.address,
    required this.hasAddress,
    required this.coach,
    required this.sport,
    required this.opp,
    required this.top,
    this.left,
    this.right,
  });
}

class NearbySessionScreen extends StatefulWidget {
  const NearbySessionScreen({super.key});

  @override
  State<NearbySessionScreen> createState() => _NearbySessionScreenState();
}

class _NearbySessionScreenState extends State<NearbySessionScreen> {
  int _selectedIndex = 0;

  List<_NearbyField> _fieldsFrom(List programs) {
    final trustedPrograms = programs
        .where((program) => program is Map && providerTrusted(program))
        .toList();
    return trustedPrograms.asMap().entries.map((e) {
      final i = e.key;
      final p = e.value as Map;
      final addr = p['address'];
      final addressStr = (addr is Map)
          ? [addr['line1'], addr['city'], addr['state'], addr['zip']]
                .where((s) => s != null && s.toString().trim().isNotEmpty)
                .join(', ')
          : '';
      final coach = (p['providerId'] is Map)
          ? (p['providerId']['businessName']?.toString() ?? 'Academy')
          : 'Academy';
      final gallery = p['gallery'];
      final image = (gallery is List && gallery.isNotEmpty)
          ? gallery[0].toString()
          : '';
      return _NearbyField(
        index: i,
        name: p['title']?.toString() ?? 'Program',
        address: addressStr.isEmpty ? 'Address not provided' : addressStr,
        hasAddress: addressStr.isNotEmpty,
        coach: coach,
        sport: p['sportType']?.toString() ?? 'Soccer',
        opp: Opportunity(
          id: i,
          programId: p['_id']?.toString(),
          title: p['title']?.toString() ?? 'Program',
          coach: coach,
          price: '\$${p['price'] ?? 0}',
          rating: (p['averageRating'] is num && (p['averageRating'] as num) > 0)
              ? p['averageRating'].toString()
              : 'New', // grounded — real rating or honest "New", no fake 0.0
          image: image,
          spotsLeft: 'AVAILABLE',
          isVerified: providerTrusted(p),
          bookingTrend: 'Near you',
          top: 0,
          team: coach,
          rawData: Map<String, dynamic>.from(p),
        ),
        top: 240.0 + (i * 96),
        left: i.isEven ? 70.0 : null,
        right: i.isOdd ? 60.0 : null,
      );
    }).toList();
  }

  Future<void> _openInMaps(String address) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    final fields = _fieldsFrom(homeProvider.programs);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          _buildMapArea(fields),

          // Top header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SporveIconButton(
                    Icons.arrow_back,
                    onTap: () => Get.back(),
                    iconSize: 20,
                  ),
                  Text(
                    'Near you',
                    style: AppTypography.font(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
            ),
          ),

          // Empty state when there are no programs
          if (fields.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_off_outlined,
                      color: AppColors.textGrey,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No nearby sessions yet.',
                      style: AppTypography.font(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _buildBottomSheet(
              fields[_selectedIndex.clamp(0, fields.length - 1)],
            ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(_NearbyField field) {
    final sportColor = SportColors.of(field.sport);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.card),
          ),
          border: Border(top: BorderSide(color: AppColors.hairline)),
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 30,
              offset: Offset(0, -10),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(28, 14, 28, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                SportIconTile(field.sport, size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.font(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        field.coach,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.font(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.slateText,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    field.address,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                // Only offer Maps when there's a real address — a placeholder
                // query launches a useless "Address not provided" search.
                if (field.hasAddress) ...[
                  Expanded(
                    flex: 12,
                    child: SporveButton(
                      'Open in Maps',
                      icon: Icons.directions_outlined,
                      onPressed: () => _openInMaps(field.address),
                      variant: SporveButtonVariant.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 10,
                  child: SporveButton(
                    'View details',
                    onPressed: () => Get.toNamed(
                      AppRoutes.sessionDetails,
                      arguments: field.opp,
                    ),
                    variant: SporveButtonVariant.dark,
                    color: sportColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapArea(List<_NearbyField> fields) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.ink,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: GridPaper(
                color: Colors.white,
                divisions: 1,
                subdivisions: 1,
                interval: 80,
              ),
            ),
          ),
          ...fields.map((field) {
            final isSelected = _selectedIndex == field.index;
            return Positioned(
              top: field.top,
              left: field.left,
              right: field.right,
              child: GestureDetector(
                onTap: () => setState(() => _selectedIndex = field.index),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isSelected ? 1.0 : 0.0,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.chip),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Text(
                          field.name,
                          style: AppTypography.font(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    AnimatedScale(
                      scale: isSelected ? 1.25 : 1.0,
                      duration: const Duration(milliseconds: 250),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.slateText
                              : AppColors.surface2,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.slateText
                                : AppColors.hairline,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: isSelected
                              ? AppColors.onSlate
                              : AppColors.textSecondary,
                          size: isSelected ? 20 : 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
