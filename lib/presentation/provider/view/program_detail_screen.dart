import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/sport_colors.dart';
import '../controllers/provider_controller.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../../widgets/sporve_image.dart';

class ProgramDetailScreen extends StatefulWidget {
  final ProviderListing listing;

  const ProgramDetailScreen({super.key, required this.listing});

  @override
  State<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends State<ProgramDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProviderController>().fetchProgramSessions(
        widget.listing.id,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final spots = widget.listing.maxCapacity - widget.listing.enrolledCount;
    final spotsColor = spots <= 0
        ? AppColors.negative
        : spots <= 3
        ? AppColors.warning
        : AppColors.slateText;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            leading: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.share_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: () {
                    // No public deep-link scheme exists yet, so share the real
                    // program title and id rather than a canned placeholder.
                    final l = widget.listing;
                    Clipboard.setData(
                      ClipboardData(
                        text:
                            'Check out "${l.title}" on Sporve (program ${l.id}).',
                      ),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Program details copied to clipboard'),
                        backgroundColor: AppColors.slateText,
                      ),
                    );
                  },
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Hero Cover ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: _HeroCover(
                  listing: widget.listing,
                  spotsColor: spotsColor,
                  spots: spots,
                ),
              ),

              // ── Content ────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 24),

                    // Title + provider
                    FadeInUp(
                      duration: const Duration(milliseconds: 400),
                      child: _TitleSection(listing: widget.listing),
                    ),
                    const SizedBox(height: 20),

                    // Stat row
                    FadeInUp(
                      delay: const Duration(milliseconds: 100),
                      duration: const Duration(milliseconds: 400),
                      child: _StatRow(
                        listing: widget.listing,
                        spotsColor: spotsColor,
                        spots: spots,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Description
                    FadeInUp(
                      delay: const Duration(milliseconds: 150),
                      duration: const Duration(milliseconds: 400),
                      child: _SectionCard(
                        title: 'ABOUT THIS PROGRAM',
                        child: Text(
                          widget.listing.description.isNotEmpty
                              ? widget.listing.description
                              : 'No description provided.',
                          style: AppTypography.font(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            height: 1.7,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Program details
                    FadeInUp(
                      delay: const Duration(milliseconds: 200),
                      duration: const Duration(milliseconds: 400),
                      child: _SectionCard(
                        title: 'PROGRAM DETAILS',
                        child: Column(
                          children: [
                            _InfoRow(
                              icon: Icons.sports,
                              label: 'Sport',
                              value: widget.listing.sportType,
                            ),
                            _InfoRow(
                              icon: Icons.bar_chart_rounded,
                              label: 'Skill Level',
                              value: _capitalize(widget.listing.skillLevel),
                            ),
                            _InfoRow(
                              icon: Icons.group_outlined,
                              label: 'Age Group',
                              value: widget.listing.ageGroup.toUpperCase(),
                            ),
                            _InfoRow(
                              icon: Icons.cake_outlined,
                              label: 'Age Range',
                              value:
                                  '${widget.listing.minimumAge} – ${widget.listing.maximumAge} years',
                            ),
                            _InfoRow(
                              icon: Icons.language_outlined,
                              label: 'Language',
                              value: widget.listing.language,
                            ),
                            _InfoRow(
                              icon: Icons.sell_outlined,
                              label: 'Pricing Model',
                              value: widget.listing.pricingModel
                                  .replaceAll('_', ' ')
                                  .toUpperCase(),
                            ),
                            _InfoRow(
                              icon: Icons.policy_outlined,
                              label: 'Cancellation',
                              value: _capitalize(
                                widget.listing.cancellationPolicy,
                              ),
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Capacity card
                    FadeInUp(
                      delay: const Duration(milliseconds: 250),
                      duration: const Duration(milliseconds: 400),
                      child: _CapacityCard(
                        listing: widget.listing,
                        spotsColor: spotsColor,
                        spots: spots,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sessions Section
                    FadeInUp(
                      delay: const Duration(milliseconds: 280),
                      duration: const Duration(milliseconds: 400),
                      child: _SessionsCard(listing: widget.listing),
                    ),
                    const SizedBox(height: 16),

                    // Location
                    FadeInUp(
                      delay: const Duration(milliseconds: 300),
                      duration: const Duration(milliseconds: 400),
                      child: _SectionCard(
                        title: 'LOCATION',
                        child: Column(
                          children: [
                            _InfoRow(
                              icon: Icons.location_on_outlined,
                              label: 'Address',
                              value: [
                                widget.listing.addressLine1,
                                widget.listing.city,
                                widget.listing.state,
                                widget.listing.zip,
                                widget.listing.country,
                              ].where((s) => s.isNotEmpty).join(', '),
                            ),
                            if (widget.listing.coordinates.length == 2)
                              _InfoRow(
                                icon: Icons.gps_fixed,
                                label: 'Coordinates',
                                value:
                                    '${widget.listing.coordinates[1].toStringAsFixed(4)}, ${widget.listing.coordinates[0].toStringAsFixed(4)}',
                                isLast: true,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // What's included
                    if (widget.listing.whatsIncluded.isNotEmpty) ...[
                      FadeInUp(
                        delay: const Duration(milliseconds: 350),
                        duration: const Duration(milliseconds: 400),
                        child: _SectionCard(
                          title: "WHAT'S INCLUDED",
                          child: Column(
                            children: widget.listing.whatsIncluded
                                .map((item) => _CheckRow(text: item))
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Gallery
                    if (widget.listing.gallery.isNotEmpty) ...[
                      FadeInUp(
                        delay: const Duration(milliseconds: 400),
                        duration: const Duration(milliseconds: 400),
                        child: _GallerySection(gallery: widget.listing.gallery),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 100), // bottom CTA space
                  ]),
                ),
              ),
            ],
          ),

          // ── Bottom CTA ─────────────────────────────────────────────
          bottomNavigationBar: _BottomCTA(listing: widget.listing),
        ),
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Cover
// ─────────────────────────────────────────────────────────────────────────────
class _HeroCover extends StatelessWidget {
  const _HeroCover({
    required this.listing,
    required this.spotsColor,
    required this.spots,
  });
  final ProviderListing listing;
  final Color spotsColor;
  final int spots;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Image
        SizedBox(
          height: 320,
          width: double.infinity,
          child: listing.image.isNotEmpty
              ? SporveImage(
                  listing.image,
                  width: double.infinity,
                  height: 320,
                  fit: BoxFit.cover,
                )
              : _PlaceholderCover(listing: listing),
        ),
        // Gradient overlay
        Container(
          height: 320,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.3),
                Colors.black.withValues(alpha: 0.85),
              ],
              stops: const [0.3, 0.6, 1.0],
            ),
          ),
        ),
        // Sport-color scrim at the bottom of the cover (sport identity wash).
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    SportColors.scrimOf(listing.sportType),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Status badge
        Positioned(
          bottom: 20,
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: listing.status == 'published'
                  ? AppColors.slateText.withValues(alpha: 0.9)
                  : Colors.white24,
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  listing.status == 'published'
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: listing.status == 'published'
                      ? AppColors.onSlate
                      : Colors.white,
                  size: 11,
                ),
                const SizedBox(width: 5),
                Text(
                  listing.status.toUpperCase(),
                  style: AppTypography.font(
                    color: listing.status == 'published'
                        ? AppColors.onSlate
                        : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Price badge
        Positioned(
          bottom: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.slateText,
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
            child: Text(
              '\$${listing.price.toStringAsFixed(0)} ${listing.currency}',
              style: AppTypography.font(
                color: AppColors.onSlate,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  const _PlaceholderCover({required this.listing});
  final ProviderListing listing;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Center(
        child: Icon(
          SportColors.iconOf(listing.sportType),
          size: 72,
          color: SportColors.of(listing.sportType),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Title Section
// ─────────────────────────────────────────────────────────────────────────────
class _TitleSection extends StatelessWidget {
  const _TitleSection({required this.listing});
  final ProviderListing listing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sport tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: SportColors.tintOf(listing.sportType),
            borderRadius: BorderRadius.circular(AppRadii.chip),
            border: Border.all(
              color: SportColors.of(listing.sportType).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                SportColors.iconOf(listing.sportType),
                size: 13,
                color: SportColors.of(listing.sportType),
              ),
              const SizedBox(width: 6),
              Text(
                listing.sportType.toUpperCase(),
                style: AppTypography.font(
                  color: SportColors.of(listing.sportType),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          listing.title,
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),
        if (listing.providerName.isNotEmpty)
          Row(
            children: [
              Icon(
                listing.providerVerified
                    ? Icons.verified
                    : Icons.store_outlined,
                size: 15,
                color: listing.providerVerified
                    ? AppColors.slateText
                    : AppColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  listing.providerName,
                  style: AppTypography.font(
                    color: listing.providerVerified
                        ? AppColors.slateText
                        : AppColors.textTertiary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (listing.providerVerified) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.slateTint,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
                  child: Text(
                    'Verified',
                    style: AppTypography.font(
                      color: AppColors.slateText,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat Row
// ─────────────────────────────────────────────────────────────────────────────
class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.listing,
    required this.spotsColor,
    required this.spots,
  });
  final ProviderListing listing;
  final Color spotsColor;
  final int spots;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          icon: Icons.star_rounded,
          iconColor: AppColors.warning,
          value: listing.rating,
          label: '${listing.totalReviews} reviews',
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.people_alt_outlined,
          iconColor: spotsColor,
          value: '${listing.enrolledCount}/${listing.maxCapacity}',
          label: 'enrolled',
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.event_seat_outlined,
          iconColor: spotsColor,
          value: spots <= 0 ? 'FULL' : '$spots',
          label: spots <= 0 ? 'no spots' : 'spots left',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.hairlineSoft),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: AppTypography.font(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.font(
                color: AppColors.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Capacity Bar Card
// ─────────────────────────────────────────────────────────────────────────────
class _CapacityCard extends StatelessWidget {
  const _CapacityCard({
    required this.listing,
    required this.spotsColor,
    required this.spots,
  });
  final ProviderListing listing;
  final Color spotsColor;
  final int spots;

  @override
  Widget build(BuildContext context) {
    final pct = listing.maxCapacity > 0
        ? (listing.enrolledCount / listing.maxCapacity).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ENROLLMENT',
            style: AppTypography.font(
              color: AppColors.textGrey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${listing.enrolledCount} enrolled',
                style: AppTypography.font(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                '${listing.maxCapacity} max',
                style: AppTypography.font(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.chip),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: AppColors.surface2,
              valueColor: AlwaysStoppedAnimation<Color>(spotsColor),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            spots <= 0
                ? 'This program is fully booked.'
                : '$spots ${spots == 1 ? 'spot' : 'spots'} remaining',
            style: AppTypography.font(
              color: spotsColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Card wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.font(
              color: AppColors.textGrey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info Row
// ─────────────────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.slateText, size: 18),
              const SizedBox(width: 14),
              SizedBox(
                width: 110,
                child: Text(
                  label,
                  style: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value.isNotEmpty ? value : '—',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(color: AppColors.hairlineSoft, height: 1),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Check Row (What's Included)
// ─────────────────────────────────────────────────────────────────────────────
class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: Icon(
              Icons.check_circle,
              color: AppColors.slateText,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTypography.font(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gallery Section
// ─────────────────────────────────────────────────────────────────────────────
class _GallerySection extends StatelessWidget {
  const _GallerySection({required this.gallery});
  final List<String> gallery;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'GALLERY',
            style: AppTypography.font(
              color: AppColors.textGrey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: gallery.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => SporveImage(
              gallery[i],
              width: 110,
              height: 110,
              fit: BoxFit.cover,
              radius: AppRadii.card,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom CTA
// ─────────────────────────────────────────────────────────────────────────────
class _BottomCTA extends StatelessWidget {
  const _BottomCTA({required this.listing});
  final ProviderListing listing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.ink,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          // Price summary
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '\$${listing.price.toStringAsFixed(0)}',
                style: AppTypography.font(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                listing.pricingModel.replaceAll('_', ' '),
                style: AppTypography.font(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          // Edit button
          Expanded(
            child: SporveButton(
              'Edit program',
              onPressed: () {
                final controller = context.read<ProviderController>();
                final index = controller.listings.indexWhere(
                  (l) => l.id == listing.id,
                );
                Navigator.of(context).pop(index);
              },
              variant: SporveButtonVariant.primary,
              color: SportColors.of(listing.sportType), // sport-context CTA
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionsCard extends StatelessWidget {
  final ProviderListing listing;
  const _SessionsCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    return Consumer<ProviderController>(
      builder: (context, controller, child) {
        final sessions = controller.programSessions;
        final loading = controller.sessionsLoading;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.hairlineSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sessions are auto-scheduled when the program is created and
              // managed from the calendar — no manual "list a session" step.
              Text(
                'SCHEDULED SESSIONS',
                style: AppTypography.font(
                  color: AppColors.textGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              if (loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.slateText,
                    ),
                  ),
                )
              else if (sessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No sessions scheduled for this program.',
                      style: AppTypography.font(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) =>
                      const Divider(color: AppColors.hairlineSoft, height: 24),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final startDateStr = session['startDate'] ?? '';
                    final startTime = session['startTime'] ?? '';
                    final endTime = session['endTime'] ?? '';
                    final instructor = session['instructor'] ?? '';
                    final coachTip = session['coachTip'] ?? '';
                    final capacity = session['maxCapacity'] ?? 0;

                    DateTime? startDate;
                    try {
                      startDate = DateTime.parse(startDateStr);
                    } catch (e) {
                      debugPrint('program_detail: bad session startDate '
                          '"$startDateStr": $e');
                    }

                    final dateLabel = startDate != null
                        ? '${_weekdayName(startDate.weekday)}, ${_monthName(startDate.month)} ${startDate.day}'
                        : 'Unknown Date';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dateLabel,
                                    style: AppTypography.font(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$startTime - $endTime',
                                    style: AppTypography.font(
                                      color: AppColors.slateText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface2,
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.chip,
                                    ),
                                  ),
                                  child: Text(
                                    'Capacity: $capacity',
                                    style: AppTypography.font(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SporveIconButton(
                                  Icons.edit,
                                  size: 28,
                                  iconSize: 12,
                                  onTap: () => _showAddSessionBottomSheet(
                                    context,
                                    listing,
                                    controller,
                                    existingSession: session,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (instructor.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.person_outline,
                                color: AppColors.textTertiary,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Instructor: $instructor',
                                  style: AppTypography.font(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (coachTip.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.lightbulb_outline,
                                color: AppColors.warning,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Tip: $coachTip',
                                  style: AppTypography.font(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  String _weekdayName(int day) {
    switch (day) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }

  String _monthName(int month) {
    switch (month) {
      case 1:
        return 'Jan';
      case 2:
        return 'Feb';
      case 3:
        return 'Mar';
      case 4:
        return 'Apr';
      case 5:
        return 'May';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Aug';
      case 9:
        return 'Sep';
      case 10:
        return 'Oct';
      case 11:
        return 'Nov';
      case 12:
        return 'Dec';
      default:
        return '';
    }
  }
}

void _showAddSessionBottomSheet(
  BuildContext context,
  ProviderListing listing,
  ProviderController controller, {
  Map<String, dynamic>? existingSession,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      DateTime selectedDate =
          existingSession != null && existingSession['startDate'] != null
          ? (DateTime.tryParse(existingSession['startDate'].toString()) ??
                DateTime.now())
          : DateTime.now();
      String startTime = existingSession != null
          ? (existingSession['startTime'] ?? '09:00')
          : '09:00';
      String endTime = existingSession != null
          ? (existingSession['endTime'] ?? '10:30')
          : '10:30';
      final capacityController = TextEditingController(
        text: existingSession != null
            ? (existingSession['maxCapacity'] ?? '').toString()
            : '',
      );
      final instructorController = TextEditingController(
        text: existingSession != null
            ? (existingSession['instructor'] ?? '')
            : '',
      );
      final tipController = TextEditingController(
        text: existingSession != null
            ? (existingSession['coachTip'] ?? '')
            : '',
      );
      String? selectedTimezone = existingSession != null
          ? existingSession['timezone']
          : null;
      final listCoords =
          existingSession != null && existingSession['location'] != null
          ? existingSession['location']['coordinates']
          : null;
      final latVal = listCoords != null && listCoords.length == 2
          ? listCoords[1].toString()
          : (listing.coordinates.length == 2
                ? listing.coordinates[1].toString()
                : '');
      final lngVal = listCoords != null && listCoords.length == 2
          ? listCoords[0].toString()
          : (listing.coordinates.length == 2
                ? listing.coordinates[0].toString()
                : '');
      final addressVal = [
        listing.addressLine1,
        listing.city,
        listing.state,
        listing.zip,
        listing.country,
      ].where((s) => s.isNotEmpty).join(', ');
      final defaultAddress = addressVal.isNotEmpty ? addressVal : '';
      final existingLine1 =
          existingSession != null && existingSession['address'] != null
          ? existingSession['address']['line1']?.toString()
          : null;
      final latController = TextEditingController(text: latVal);
      final lngController = TextEditingController(text: lngVal);
      final addressController = TextEditingController(
        text: existingLine1 ?? '',
      );
      bool waitlistEnabled = existingSession != null
          ? (existingSession['waitlistEnabled'] ?? false)
          : false;
      bool isSubmitting = false;
      bool locationFetched = existingSession != null;

      Future<void> fetchCurrentLocation(
        void Function(void Function()) setModalState,
      ) async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Location services are disabled on your device.'),
                backgroundColor: AppColors.warning,
              ),
            );
            return;
          }

          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
            if (permission == LocationPermission.denied) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Location permission was denied.'),
                  backgroundColor: AppColors.negative,
                ),
              );
              return;
            }
          }
          if (permission == LocationPermission.deniedForever) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Location permission is permanently denied.'),
                backgroundColor: AppColors.negative,
              ),
            );
            return;
          }

          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 7),
            ),
          );
          setModalState(() {
            latController.text = position.latitude.toString();
            lngController.text = position.longitude.toString();
          });
        } catch (e) {
          debugPrint("Error fetching location: $e");
          messenger.showSnackBar(
            SnackBar(
              content: Text('Could not fetch location: $e'),
              backgroundColor: AppColors.negative,
            ),
          );
        }
      }

      return StatefulBuilder(
        builder: (context, setModalState) {
          if (!locationFetched) {
            locationFetched = true;
            Future.delayed(
              Duration.zero,
              () => fetchCurrentLocation(setModalState),
            );
          }

          Future<void> pickDate() async {
            final date = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppColors.slateText,
                      onPrimary: AppColors.onSlate,
                      surface: AppColors.surface,
                      onSurface: AppColors.textPrimary,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              setModalState(() {
                selectedDate = date;
              });
            }
          }

          Future<void> pickTime(bool isStart) async {
            final initialTime = isStart
                ? const TimeOfDay(hour: 9, minute: 0)
                : const TimeOfDay(hour: 10, minute: 30);
            final time = await showTimePicker(
              context: context,
              initialTime: initialTime,
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppColors.slateText,
                      onPrimary: AppColors.onSlate,
                      surface: AppColors.surface,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (time != null) {
              final formattedTime =
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
              setModalState(() {
                if (isStart) {
                  startTime = formattedTime;
                } else {
                  endTime = formattedTime;
                }
              });
            }
          }

          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadii.card),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              24,
              20,
              24,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.hairline,
                        borderRadius: BorderRadius.circular(AppRadii.chip),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    existingSession != null
                        ? 'Update Session'
                        : 'Schedule New Session',
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Date selector
                  Text(
                    'DATE',
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                            style: AppTypography.font(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                          const Icon(
                            Icons.calendar_today,
                            color: AppColors.slateText,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Times
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'START TIME',
                              style: AppTypography.font(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => pickTime(true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface2,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.tile,
                                  ),
                                  border: Border.all(color: AppColors.hairline),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      startTime,
                                      style: AppTypography.font(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.access_time,
                                      color: AppColors.textTertiary,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'END TIME',
                              style: AppTypography.font(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => pickTime(false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface2,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.tile,
                                  ),
                                  border: Border.all(color: AppColors.hairline),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      endTime,
                                      style: AppTypography.font(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.access_time,
                                      color: AppColors.textTertiary,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Max Capacity
                  Text(
                    'MAX CAPACITY',
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: capacityController,
                    keyboardType: TextInputType.number,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. ${listing.maxCapacity}',
                      hintStyle: AppTypography.font(
                        color: AppColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: AppColors.surface2,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                        borderSide: const BorderSide(color: AppColors.hairline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                        borderSide: const BorderSide(
                          color: AppColors.slateText,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Instructor
                  Text(
                    'INSTRUCTOR (OPTIONAL)',
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: instructorController,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Coach John Doe',
                      hintStyle: AppTypography.font(
                        color: AppColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: AppColors.surface2,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                        borderSide: const BorderSide(color: AppColors.hairline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                        borderSide: const BorderSide(
                          color: AppColors.slateText,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Timezone
                  Text(
                    'TIMEZONE',
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTimezone,
                    dropdownColor: AppColors.surface2,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    iconEnabledColor: AppColors.textSecondary,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface2,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                        borderSide: const BorderSide(color: AppColors.hairline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                        borderSide: const BorderSide(
                          color: AppColors.slateText,
                        ),
                      ),
                    ),
                    hint: Text(
                      'Select Timezone',
                      style: AppTypography.font(
                        color: AppColors.textTertiary,
                        fontSize: 14,
                      ),
                    ),
                    items: _allTimezones.map((tz) {
                      return DropdownMenuItem<String>(
                        value: tz,
                        child: Text(tz),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setModalState(() {
                        selectedTimezone = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Address
                  Text(
                    'ADDRESS (OPTIONAL)',
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: addressController,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. $defaultAddress',
                      hintStyle: AppTypography.font(
                        color: AppColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: AppColors.surface2,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                        borderSide: const BorderSide(color: AppColors.hairline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                        borderSide: const BorderSide(
                          color: AppColors.slateText,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Lat / Lng Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'LATITUDE (OPTIONAL)',
                                  style: AppTypography.font(
                                    color: AppColors.textTertiary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      fetchCurrentLocation(setModalState),
                                  behavior: HitTestBehavior.opaque,
                                  child: const Padding(
                                    padding: EdgeInsets.only(
                                      left: 12,
                                      bottom: 4,
                                    ),
                                    child: Icon(
                                      Icons.my_location,
                                      color: AppColors.slateText,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: latController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: AppTypography.font(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'e.g. $latVal',
                                hintStyle: AppTypography.font(
                                  color: AppColors.textTertiary,
                                ),
                                filled: true,
                                fillColor: AppColors.surface2,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.tile,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.hairline,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.tile,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.slateText,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LONGITUDE (OPTIONAL)',
                              style: AppTypography.font(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: lngController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: AppTypography.font(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'e.g. $lngVal',
                                hintStyle: AppTypography.font(
                                  color: AppColors.textTertiary,
                                ),
                                filled: true,
                                fillColor: AppColors.surface2,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.tile,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.hairline,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.tile,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.slateText,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Coach Tip
                  Text(
                    'COACH TIP (OPTIONAL)',
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: tipController,
                    maxLines: 2,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Please wear non-marking shoes.',
                      hintStyle: AppTypography.font(
                        color: AppColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: AppColors.surface2,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                        borderSide: const BorderSide(color: AppColors.hairline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                        borderSide: const BorderSide(
                          color: AppColors.slateText,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Waitlist switch
                  SwitchListTile(
                    title: Text(
                      'Enable Waitlist',
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    value: waitlistEnabled,
                    activeThumbColor: AppColors.slateText,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setModalState(() {
                        waitlistEnabled = val;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: SporveButton(
                          'Cancel',
                          onPressed: () => Navigator.of(context).pop(),
                          variant: SporveButtonVariant.tertiary,
                          onDark: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SporveButton(
                          existingSession != null ? 'Update' : 'Schedule',
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final cap =
                                      int.tryParse(capacityController.text) ??
                                      listing.maxCapacity;

                                  // Formatting DateTimes — parse defensively so a
                                  // non-numeric time (e.g. "9:00 AM") can never
                                  // crash the sheet with a FormatException.
                                  int? hm(String t, int i) {
                                    final p = t.split(':');
                                    return p.length > i
                                        ? int.tryParse(
                                            p[i].replaceAll(RegExp(r'[^0-9]'), ''))
                                        : null;
                                  }

                                  final startHour = hm(startTime, 0);
                                  final startMin = hm(startTime, 1);
                                  final endHour = hm(endTime, 0);
                                  final endMin = hm(endTime, 1);
                                  if (startHour == null ||
                                      startMin == null ||
                                      endHour == null ||
                                      endMin == null) {
                                    Get.snackbar('Invalid time',
                                        'Please pick a valid start and end time.');
                                    return;
                                  }
                                  final dtStart = DateTime(
                                    selectedDate.year,
                                    selectedDate.month,
                                    selectedDate.day,
                                    startHour,
                                    startMin,
                                  );
                                  final dtEnd = DateTime(
                                    selectedDate.year,
                                    selectedDate.month,
                                    selectedDate.day,
                                    endHour,
                                    endMin,
                                  );

                                  if (dtEnd.isBefore(dtStart)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'End time must be after start time.',
                                        ),
                                        backgroundColor: AppColors.negative,
                                      ),
                                    );
                                    return;
                                  }

                                  if (selectedTimezone == null ||
                                      selectedTimezone!.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please select a timezone.',
                                        ),
                                        backgroundColor: AppColors.negative,
                                      ),
                                    );
                                    return;
                                  }

                                  final latStr = latController.text.trim();
                                  final lngStr = lngController.text.trim();
                                  if (latStr.isEmpty || lngStr.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please provide coordinates or fetch current location.',
                                        ),
                                        backgroundColor: AppColors.negative,
                                      ),
                                    );
                                    return;
                                  }

                                  final line1Val =
                                      addressController.text.trim().isNotEmpty
                                      ? addressController.text.trim()
                                      : (listing.addressLine1.isNotEmpty
                                            ? listing.addressLine1
                                            : '');
                                  if (line1Val.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please enter an address.',
                                        ),
                                        backgroundColor: AppColors.negative,
                                      ),
                                    );
                                    return;
                                  }

                                  setModalState(() {
                                    isSubmitting = true;
                                  });

                                  final lat =
                                      double.tryParse(latStr) ??
                                      (listing.coordinates.length == 2
                                          ? listing.coordinates[1]
                                          : 0.0);
                                  final lng =
                                      double.tryParse(lngStr) ??
                                      (listing.coordinates.length == 2
                                          ? listing.coordinates[0]
                                          : 0.0);

                                  final body = {
                                    'programId': listing.id,
                                    'startDate': dtStart
                                        .toUtc()
                                        .toIso8601String(),
                                    'endDate': dtEnd.toUtc().toIso8601String(),
                                    'startTime': startTime,
                                    'endTime': endTime,
                                    'timezone': selectedTimezone,
                                    'maxCapacity': cap,
                                    'instructor': instructorController.text
                                        .trim(),
                                    'waitlistEnabled': waitlistEnabled,
                                    'coachTip': tipController.text.trim(),
                                    'location': {
                                      'type': 'Point',
                                      'coordinates': [lng, lat],
                                    },
                                    'address': {
                                      'line1': line1Val,
                                      'city': listing.city.isNotEmpty
                                          ? listing.city
                                          : '',
                                      'state': listing.state.isNotEmpty
                                          ? listing.state
                                          : '',
                                      'zip': listing.zip.isNotEmpty
                                          ? listing.zip
                                          : '',
                                      'country': listing.country.isNotEmpty
                                          ? listing.country
                                          : '',
                                    },
                                    // Flat fields at root level in case the backend DTO uses flat fields
                                    'latitude': lat,
                                    'longitude': lng,
                                    'lat': lat,
                                    'lng': lng,
                                    'addressLine1': line1Val,
                                    'city': listing.city.isNotEmpty
                                        ? listing.city
                                        : '',
                                    'state': listing.state.isNotEmpty
                                        ? listing.state
                                        : '',
                                    'zip': listing.zip.isNotEmpty
                                        ? listing.zip
                                        : '',
                                    'country': listing.country.isNotEmpty
                                        ? listing.country
                                        : '',
                                  };

                                  debugPrint('📤 Sending payload: $body');
                                  final navigator = Navigator.of(context);
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  final bool success;
                                  if (existingSession != null) {
                                    success = await controller
                                        .updateProgramSession(
                                          existingSession['_id'].toString(),
                                          listing.id,
                                          body,
                                        );
                                  } else {
                                    success = await controller
                                        .createProgramSession(body);
                                  }

                                  if (success) {
                                    navigator.pop();
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          existingSession != null
                                              ? 'Session updated successfully!'
                                              : 'Session scheduled successfully!',
                                        ),
                                        backgroundColor: AppColors.slateText,
                                      ),
                                    );
                                  } else {
                                    setModalState(() {
                                      isSubmitting = false;
                                    });
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          existingSession != null
                                              ? 'Failed to update session. Please try again.'
                                              : 'Failed to schedule session. Please try again.',
                                        ),
                                        backgroundColor: AppColors.negative,
                                      ),
                                    );
                                  }
                                },
                          variant: SporveButtonVariant.primary,
                          loading: isSubmitting,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

const List<String> _allTimezones = [
  'Africa/Abidjan',
  'Africa/Accra',
  'Africa/Algiers',
  'Africa/Bissau',
  'Africa/Cairo',
  'Africa/Casablanca',
  'Africa/Johannesburg',
  'Africa/Khartoum',
  'Africa/Lagos',
  'Africa/Maputo',
  'Africa/Monrovia',
  'Africa/Nairobi',
  'America/Adak',
  'America/Anchorage',
  'America/Asuncion',
  'America/Bogota',
  'America/Buenos_Aires',
  'America/Caracas',
  'America/Chicago',
  'America/Denver',
  'America/El_Salvador',
  'America/Guatemala',
  'America/Halifax',
  'America/Havana',
  'America/Indianapolis',
  'America/Jamaica',
  'America/Lima',
  'America/Los_Angeles',
  'America/Managua',
  'America/Mexico_City',
  'America/Montevideo',
  'America/New_York',
  'America/Phoenix',
  'America/Santiago',
  'America/Santo_Domingo',
  'America/Sao_Paulo',
  'America/St_Johns',
  'America/Tegucigalpa',
  'Asia/Almaty',
  'Asia/Amman',
  'Asia/Anadyr',
  'Asia/Baghdad',
  'Asia/Baku',
  'Asia/Bangkok',
  'Asia/Beirut',
  'Asia/Colombo',
  'Asia/Damascus',
  'Asia/Dhaka',
  'Asia/Dubai',
  'Asia/Gaza',
  'Asia/Hong_Kong',
  'Asia/Jakarta',
  'Asia/Jerusalem',
  'Asia/Kabul',
  'Asia/Karachi',
  'Asia/Kathmandu',
  'Asia/Kolkata',
  'Asia/Kuala_Lumpur',
  'Asia/Kuwait',
  'Asia/Manila',
  'Asia/Muscat',
  'Asia/Nicosia',
  'Asia/Riyadh',
  'Asia/Seoul',
  'Asia/Shanghai',
  'Asia/Singapore',
  'Asia/Taipei',
  'Asia/Tashkent',
  'Asia/Tbilisi',
  'Asia/Tehran',
  'Asia/Tokyo',
  'Asia/Ulaanbaatar',
  'Asia/Vladivostok',
  'Asia/Yerevan',
  'Atlantic/Azores',
  'Atlantic/Bermuda',
  'Atlantic/Canary',
  'Atlantic/Cape_Verde',
  'Atlantic/Faroe',
  'Atlantic/Reykjavik',
  'Australia/Adelaide',
  'Australia/Brisbane',
  'Australia/Darwin',
  'Australia/Hobart',
  'Australia/Melbourne',
  'Australia/Perth',
  'Australia/Sydney',
  'Europe/Amsterdam',
  'Europe/Andorra',
  'Europe/Athens',
  'Europe/Belgrade',
  'Europe/Berlin',
  'Europe/Brussels',
  'Europe/Bucharest',
  'Europe/Budapest',
  'Europe/Copenhagen',
  'Europe/Dublin',
  'Europe/Gibraltar',
  'Europe/Helsinki',
  'Europe/Istanbul',
  'Europe/Kiev',
  'Europe/Lisbon',
  'Europe/London',
  'Europe/Luxembourg',
  'Europe/Madrid',
  'Europe/Monaco',
  'Europe/Moscow',
  'Europe/Oslo',
  'Europe/Paris',
  'Europe/Prague',
  'Europe/Rome',
  'Europe/Sofia',
  'Europe/Stockholm',
  'Europe/Tallinn',
  'Europe/Vienna',
  'Europe/Vilnius',
  'Europe/Warsaw',
  'Europe/Zurich',
  'Pacific/Auckland',
  'Pacific/Chatham',
  'Pacific/Fakaofo',
  'Pacific/Fiji',
  'Pacific/Guam',
  'Pacific/Honolulu',
  'Pacific/Midway',
  'Pacific/Noumea',
  'Pacific/Pago_Pago',
  'Pacific/Port_Moresby',
  'Pacific/Rarotonga',
  'Pacific/Tahiti',
  'UTC',
];
