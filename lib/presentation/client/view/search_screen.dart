import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/session_time.dart';
import '../controllers/home_controller.dart';
import '../controllers/search_provider.dart';
import '../../authentication/controllers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/routes/app_routes.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/motion_widgets.dart';
import '../../../core/theme/sport_colors.dart';
import '../../widgets/sporve_button.dart';
import '../../widgets/sporve_image.dart';

class Opportunity {
  final int id;

  /// The REAL program id (Supabase uuid) this card represents. Used for
  /// favorites + carried into the booking flow. Null only for non-program cards.
  final String? programId;
  final String title;
  final String coach;
  final String price;
  final String rating;
  final String image;
  final String spotsLeft;
  final bool isVerified;
  final String bookingTrend;
  final double top;
  final String team;
  final double? left;
  final double? right;
  final double? bottom;
  final Map<String, dynamic>? rawData;

  /// Program coordinates (from `location.coordinates` = [lng, lat]). Null when
  /// the row has no geo — distance is then simply not shown.
  final double? latitude;
  final double? longitude;

  const Opportunity({
    required this.id,
    this.programId,
    required this.title,
    required this.coach,
    required this.price,
    required this.rating,
    required this.image,
    required this.spotsLeft,
    required this.isVerified,
    required this.bookingTrend,
    required this.top,
    required this.team,
    this.left,
    this.right,
    this.bottom,
    this.rawData,
    this.latitude,
    this.longitude,
  });
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<dynamic> _list(dynamic value) => value is List ? value : const [];

  Map<dynamic, dynamic>? _map(dynamic value) => value is Map ? value : null;

  int? _selectedOpportunityIndex;
  // default (Best fit) | distance_asc (Closest) | price_asc (Cheapest) |
  // rating_desc (Top rated).
  String _browseSort = 'default';
  final TextEditingController _searchController = TextEditingController();

  // Reference point for distance. No live location yet (Geolocator is out of a
  // lib-only scope), so we fall back to the Chicago area — the same anchor the
  // goal-intake constraints default to — until a real location is wired.
  static const double _refLat = 41.8781;
  static const double _refLng = -87.6298;

  /// Great-circle distance (km) from the reference point to [o], or null when
  /// the program has no coordinates. Never fabricated.
  double? _distanceKm(Opportunity o) {
    final lat = o.latitude, lng = o.longitude;
    if (lat == null || lng == null) return null;
    const r = 6371.0; // Earth radius, km
    double rad(double d) => d * math.pi / 180.0;
    final dLat = rad(lat - _refLat);
    final dLng = rad(lng - _refLng);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(_refLat)) *
            math.cos(rad(lat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// Grounded "next available" line for [dt], or null when there's no upcoming
  /// session. Reads today / tomorrow / this-week / a dated day.
  String? _nextAvailableLabel(DateTime? dt) {
    if (dt == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = day.difference(today).inDays;
    final t = formatTime12h(dt);
    if (diff <= 0) return 'Next: today · $t';
    if (diff == 1) return 'Next: tomorrow · $t';
    final w = _weekdays[dt.weekday - 1];
    if (diff < 7) return 'Next: $w · $t';
    return 'Next: $w, ${_months[dt.month - 1]} ${dt.day}';
  }

  List<Opportunity> _applyBrowseSort(List<Opportunity> items) {
    final list = List<Opportunity>.from(items);
    int priceOf(Opportunity o) =>
        int.tryParse(o.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    double ratingOf(Opportunity o) =>
        double.tryParse(o.rating.split(' ').first) ?? 0;
    switch (_browseSort) {
      case 'price_asc':
        list.sort((a, b) => priceOf(a).compareTo(priceOf(b)));
      case 'rating_desc':
        list.sort((a, b) => ratingOf(b).compareTo(ratingOf(a)));
      case 'distance_asc':
        list.sort((a, b) {
          // Rows without coordinates sort last, never above real distances.
          final da = _distanceKm(a) ?? double.infinity;
          final db = _distanceKm(b) ?? double.infinity;
          return da.compareTo(db);
        });
    }
    return list;
  }

  PopupMenuItem<String> _sortItem(String value, String label) => PopupMenuItem(
    value: value,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _browseSort == value ? Icons.check : Icons.sort,
          color: _browseSort == value
              ? AppColors.slateText
              : AppColors.textTertiary,
          size: 16,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppTypography.font(color: AppColors.textPrimary, fontSize: 13),
        ),
      ],
    ),
  );

  // Controls the draggable map sheet so the grab-handle can snap it between
  // collapsed and full-screen at high speed.
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  static const double _sheetCollapsed = 0.35;
  static const double _sheetFull = 1.0;

  /// Tap the handle → snap the sheet to full-screen or back, fast + springy.
  void _toggleSheet() {
    final size = _sheetController.isAttached
        ? _sheetController.size
        : _sheetCollapsed;
    final target = size < 0.7 ? _sheetFull : _sheetCollapsed;
    _sheetController.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    final String query = _searchController.text.trim().toLowerCase();

    // 1. Map dynamic programs to Opportunity objects for the map view
    final List<Opportunity> dynamicOpportunities = homeProvider.programs
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final program = entry.value;
          final gallery = _list(program['gallery']);
          final image = gallery.isNotEmpty ? gallery.first.toString() : '';
          final provider = _map(program['providerId']);
          final providerName =
              provider?['businessName']?.toString().trim() ?? '';
          final coach = providerName.isEmpty ? 'Academy' : providerName;

          // location.coordinates = [lng, lat]; guard nulls so cards without
          // geo simply omit distance.
          final loc = program['location'];
          final coords = (loc is Map && loc['coordinates'] is List)
              ? loc['coordinates'] as List
              : null;
          double? asDouble(Object? v) =>
              v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
          final lng = (coords != null && coords.isNotEmpty)
              ? asDouble(coords[0])
              : null;
          final lat = (coords != null && coords.length > 1)
              ? asDouble(coords[1])
              : null;

          return Opportunity(
            id: index,
            programId: program['_id']?.toString(),
            title: program['title']?.toString() ?? 'Program',
            coach: coach,
            price: '\$${program['price'] ?? 0}',
            rating: (program['averageRating'] is num &&
                    (program['averageRating'] as num) > 0)
                ? '${program['averageRating']} (${program['totalReviews'] ?? 0})'
                : 'New', // grounded — real rating (real count) or honest "New", no fake 5.0
            image: image,
            spotsLeft: 'AVAILABLE',
            isVerified: provider?['verificationStatus'] == 'verified',
            bookingTrend: 'Trending now',
            top: 200.0 + (index * 100), // map pin layout positions
            left: index % 2 == 0 ? 100.0 : null,
            right: index % 2 != 0 ? 80.0 : null,
            team: coach,
            rawData: program,
            latitude: lat,
            longitude: lng,
          );
        })
        .toList();

    // 2. Filter opportunities based on search bar text
    final List<Opportunity> filteredOpportunities = dynamicOpportunities.where((
      opp,
    ) {
      if (query.isEmpty) return true;
      return opp.title.toLowerCase().contains(query) ||
          opp.coach.toLowerCase().contains(query) ||
          opp.team.toLowerCase().contains(query);
    }).toList();

    // 2. Sort, then select display items based on selected map pin or list
    final sortedOpportunities = _applyBrowseSort(filteredOpportunities);
    final displayedItems = _selectedOpportunityIndex == null
        ? sortedOpportunities
        : sortedOpportunities
              .where((opp) => opp.id == _selectedOpportunityIndex)
              .toList();

    return GradientScaffold(
      body: Stack(
        children: [
          // Simulated Map Background (markers from real programs)
          _buildSimulatedMap(filteredOpportunities),

          // Floating Top Search Bar & Recent Searches row
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Back Button
                      SporveIconButton(
                        Icons.arrow_back_ios_new,
                        semanticLabel: 'Back',
                        onTap: () => Get.back(),
                        size: 56,
                        iconSize: 20,
                        circle: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.tile),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          child: Row(
                            children: [
                              // AI is the way you search — not a side feature.
                              const Icon(
                                Icons.auto_awesome,
                                color: AppColors.slateText,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                  cursorColor: AppColors.slateText,
                                  onChanged: (val) => setState(() {}),
                                  onSubmitted: (val) {
                                    if (val.trim().isNotEmpty) {
                                      context
                                          .read<HomeProvider>()
                                          .addPastSearch(val);
                                      // Run AI discovery: NL query -> editable
                                      // constraint chips -> ranked results.
                                      context.read<SearchProvider>().runSearch(
                                        val.trim(),
                                      );
                                      setState(() {});
                                    }
                                  },
                                  decoration: InputDecoration(
                                    hintText:
                                        'Ask Sporve — find a coach or session…',
                                    hintStyle: AppTypography.font(
                                      color: AppColors.textTertiary,
                                      fontSize: 14,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                Semantics(
                                  button: true,
                                  label: 'Clear search',
                                  child: GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      context.read<SearchProvider>().reset();
                                      setState(() {});
                                    },
                                    child: const Icon(
                                      Icons.close,
                                      color: AppColors.textSecondary,
                                      size: 18,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SporveIconButton(
                        Icons.tune,
                        semanticLabel: 'Filters',
                        onTap: () => Get.toNamed(AppRoutes.filters),
                        size: 56,
                        iconSize: 24,
                        circle: true,
                      ),
                      const SizedBox(width: 12),
                      // Real map of nearby companies/coaches.
                      SporveIconButton(
                        Icons.map_outlined,
                        semanticLabel: 'Map view',
                        onTap: () => Get.toNamed(AppRoutes.map),
                        size: 56,
                        iconSize: 22,
                        circle: true,
                      ),
                      const SizedBox(width: 12),
                      // Guided AI matching ("Find your coach") — structured
                      // athlete profile -> safety-gated, ranked coaches.
                      SporveIconButton(
                        Icons.auto_awesome,
                        semanticLabel: 'Find your coach',
                        onTap: () => Get.toNamed(AppRoutes.findCoach),
                        size: 56,
                        iconSize: 22,
                        circle: true,
                        filled: true,
                      ),
                    ],
                  ),

                  // Dynamic "Recent Searches" scrolling tag bar
                  Consumer<HomeProvider>(
                    builder: (context, homeProvider, child) {
                      if (homeProvider.pastSearches.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 12, left: 4),
                        child: SizedBox(
                          height: 36,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: homeProvider.pastSearches.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    right: 8,
                                    top: 8,
                                  ),
                                  child: Text(
                                    'Recents:',
                                    style: AppTypography.font(
                                      color: AppColors.textTertiary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }
                              final search =
                                  homeProvider.pastSearches[index - 1];
                              return GestureDetector(
                                onTap: () {
                                  _searchController.text = search;
                                  homeProvider.addPastSearch(search);
                                  setState(() {});
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.chip,
                                    ),
                                    border: Border.all(
                                      color: AppColors.hairline,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.history,
                                        color: AppColors.textTertiary,
                                        size: 11,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        search,
                                        style: AppTypography.font(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Draggable Bottom Sheet — snaps between collapsed and full-screen.
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: _sheetCollapsed,
            minChildSize: 0.15,
            maxChildSize: _sheetFull,
            snap: true,
            snapSizes: const [_sheetCollapsed],
            snapAnimationDuration: const Duration(milliseconds: 220),
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadii.card),
                  ),
                  border: Border(top: BorderSide(color: AppColors.hairline)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Consumer<HomeProvider>(
                  builder: (context, homeProvider, child) {
                    final recommendations = homeProvider.getRecommendations(
                      dynamicOpportunities,
                    );
                    final hasQuery = _searchController.text.trim().isNotEmpty;
                    final search = context.watch<SearchProvider>();
                    // Show AI discovery results once a search has run and the
                    // market is ready; a gated result falls back to browse.
                    final showAi = search.hasSearched && !search.gated;

                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 40),
                      children: [
                        // Grab handle — tap to snap the sheet full-screen / back.
                        GestureDetector(
                          onTap: _toggleSheet,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 2),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 44,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: AppColors.slateText,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                AnimatedBuilder(
                                  animation: _sheetController,
                                  builder: (_, _) {
                                    final expanded =
                                        _sheetController.isAttached &&
                                        _sheetController.size > 0.7;
                                    return AnimatedRotation(
                                      turns: expanded ? 0.5 : 0.0,
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      child: const Icon(
                                        Icons.keyboard_arrow_up_rounded,
                                        color: AppColors.textTertiary,
                                        size: 18,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Load failure -> retry (instead of a misleading "no results").
                        if (homeProvider.programsError) ...[
                          const SizedBox(height: 24),
                          ErrorRetry(
                            message:
                                "We couldn't load programs. Check your connection and try again.",
                            onRetry: () => homeProvider.fetchPrograms(),
                          ),
                        ],

                        // ── AI discovery: editable chips + ranked results ────
                        if (search.hasSearched) ..._buildAiSection(search),

                        // Browse (recommendations + list) — shown until an AI
                        // search runs; a gated market also falls back here.
                        if (!showAi) ...[
                          // 1. Recommended Carousel Section (When no active query and no pin details selected)
                          if (!hasQuery &&
                              _selectedOpportunityIndex == null &&
                              recommendations.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Recommended for You',
                                    style: AppTypography.font(
                                      color: AppColors.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const AIBadge(label: 'AI Recommend'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 190,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                itemCount: recommendations.length,
                                itemBuilder: (context, index) {
                                  return _buildRecommendedCard(
                                    recommendations[index],
                                    homeProvider,
                                  );
                                },
                              ),
                            ),
                          ],

                          // Named above-the-fold sections (unfiltered only).
                          // Every row is already gated (drawn from the loaded
                          // program set), so browse can't surface anything the
                          // concierge wouldn't.
                          if (!hasQuery && _selectedOpportunityIndex == null)
                            ..._buildDiscoverySections(
                              dynamicOpportunities,
                              homeProvider,
                            ),

                          // 2. Main List Title Section
                          const SizedBox(height: 28),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedOpportunityIndex == null
                                      ? (hasQuery
                                            ? 'Search Results'
                                            : 'Top Opportunities')
                                      : 'Selected Session',
                                  style: AppTypography.font(
                                    color: AppColors.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_selectedOpportunityIndex != null)
                                  SporveButton(
                                    'Show all',
                                    onPressed: () => setState(
                                      () => _selectedOpportunityIndex = null,
                                    ),
                                    variant: SporveButtonVariant.tertiary,
                                    size: SporveButtonSize.compact,
                                    fullWidth: false,
                                    onDark: true,
                                  )
                                else
                                  PopupMenuButton<String>(
                                    icon: const Icon(
                                      Icons.sort,
                                      color: AppColors.slateText,
                                    ),
                                    color: AppColors.surface2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.tile,
                                      ),
                                    ),
                                    onSelected: (v) =>
                                        setState(() => _browseSort = v),
                                    itemBuilder: (_) => [
                                      _sortItem('default', 'Best fit'),
                                      _sortItem('distance_asc', 'Closest'),
                                      _sortItem('price_asc', 'Cheapest'),
                                      _sortItem('rating_desc', 'Top rated'),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 3. Main Opportunities List (or empty state)
                          if (displayedItems.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 40,
                              ),
                              child: Center(
                                child: Text(
                                  'No matches — try adjusting your filters.',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.font(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: displayedItems.length,
                                itemBuilder: (context, index) {
                                  return _buildOpportunityCard(
                                    displayedItems[index],
                                    homeProvider,
                                  );
                                },
                              ),
                            ),
                        ], // end browse (!showAi)
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedCard(Opportunity opp, HomeProvider homeProvider) {
    final bool isTeamMatch =
        opp.team.toLowerCase() == homeProvider.athleteTeam.toLowerCase();

    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.sessionDetails, arguments: opp),
      child: Container(
        width: 290,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: isTeamMatch
                ? AppColors.blue.withValues(alpha: 0.5)
                : AppColors.hairline,
            width: isTeamMatch ? 1.5 : 1,
          ),
          boxShadow: isTeamMatch
              ? [
                  BoxShadow(
                    color: AppColors.blue.withValues(alpha: 0.15),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Left image thumbnail
            Stack(
              children: [
                SporveImage(
                  opp.image,
                  width: 90,
                  height: 166,
                  fit: BoxFit.cover,
                  radius: AppRadii.tile,
                ),
                if (isTeamMatch)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.blueTint,
                        borderRadius: BorderRadius.circular(AppRadii.chip),
                        border: Border.all(
                          color: AppColors.blue.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        'TEAM',
                        style: AppTypography.font(
                          color: AppColors.blueText,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            // Right info section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.negative.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadii.chip),
                        ),
                        child: Text(
                          opp.spotsLeft.split(
                            ' ',
                          )[0], // shows e.g. "2" or "FILLS"
                          style: AppTypography.font(
                            color: AppColors.negative,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: AppColors.textPrimary,
                            size: 10,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            opp.rating.split(' ')[0],
                            style: AppTypography.font(
                              color: AppColors.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    opp.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    opp.coach,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  if (isTeamMatch) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.people,
                          color: AppColors.blueText,
                          size: 10,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Same Team',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.font(
                              color: AppColors.blueText,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        opp.price.split('/')[0],
                        style: AppTypography.font(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.slateText,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward,
                          color: AppColors.onSlate,
                          size: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Named discovery sections (Available this week / Top rated / New) ───────
  List<Widget> _buildDiscoverySections(
    List<Opportunity> opps,
    HomeProvider homeProvider,
  ) {
    if (opps.isEmpty) return const [];

    // Available this week — a real upcoming session within 7 days.
    final availableThisWeek = <Opportunity>[];
    for (final o in opps) {
      final next = homeProvider.nextSessionStartForProgram(o.programId);
      if (next == null) continue;
      final days = DateTime(next.year, next.month, next.day)
          .difference(
            DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
            ),
          )
          .inDays;
      if (days >= 0 && days < 7) availableThisWeek.add(o);
    }

    double ratingOf(Opportunity o) =>
        double.tryParse(o.rating.split(' ').first) ?? 0;

    // Top rated near you — real ratings only, best first, nearest as tiebreak.
    final topRated = opps.where((o) => ratingOf(o) > 0).toList()
      ..sort((a, b) {
        final byRating = ratingOf(b).compareTo(ratingOf(a));
        if (byRating != 0) return byRating;
        return (_distanceKm(a) ?? double.infinity).compareTo(
          _distanceKm(b) ?? double.infinity,
        );
      });

    // New to Sporve — genuinely unreviewed (verified but no reviews yet).
    final newToSporve = opps.where((o) {
      final reviews = (o.rawData?['totalReviews'] as num?)?.toInt() ?? 0;
      return reviews == 0;
    }).toList();

    final sections = <Widget>[];
    if (availableThisWeek.isNotEmpty) {
      sections.addAll(
        _horizontalSection(
          'Available this week',
          availableThisWeek,
          homeProvider,
        ),
      );
    }
    if (topRated.isNotEmpty) {
      sections.addAll(
        _horizontalSection('Top rated near you', topRated, homeProvider),
      );
    }
    if (newToSporve.isNotEmpty) {
      sections.addAll(
        _horizontalSection('New to Sporve', newToSporve, homeProvider),
      );
    }
    return sections;
  }

  List<Widget> _horizontalSection(
    String title,
    List<Opportunity> items,
    HomeProvider homeProvider,
  ) {
    return [
      const SizedBox(height: 24),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          title,
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 214,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: items.length > 8 ? 8 : items.length,
          itemBuilder: (context, index) =>
              _buildDiscoveryCard(items[index], homeProvider),
        ),
      ),
    ];
  }

  Widget _buildDiscoveryCard(Opportunity opp, HomeProvider homeProvider) {
    final dist = _distanceKm(opp);
    final next = _nextAvailableLabel(
      homeProvider.nextSessionStartForProgram(opp.programId),
    );
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.sessionDetails, arguments: opp),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SporveImage(
              opp.image,
              width: 220,
              height: 96,
              fit: BoxFit.cover,
              radius: 0,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          opp.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.font(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (opp.isVerified) ...[
                        const SizedBox(width: 6),
                        _goldCheck(opp.rawData),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        opp.price.split('/').first,
                        style: AppTypography.mono(
                          size: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (dist != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          '${dist.toStringAsFixed(dist < 10 ? 1 : 0)} km',
                          style: AppTypography.mono(
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (next != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      next,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.font(
                        color: AppColors.slateText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The gold trust check (decision #7). Tap explains the background check and,
  /// only when the row carries a real date, when it completed.
  Widget _goldCheck(Map<String, dynamic>? data) => GestureDetector(
    onTap: () => _showVerificationDetails(data),
    behavior: HitTestBehavior.opaque,
    child: const Icon(
      Icons.verified_user,
      color: AppColors.trustGold,
      size: 16,
    ),
  );

  // Tap-through for the gold trust check. The date is shown only when a real
  // value exists on the provider row — never fabricated.
  void _showVerificationDetails(Map<String, dynamic>? data) {
    final prov = data?['providerId'] is Map
        ? data!['providerId'] as Map
        : (data?['provider'] is Map ? data!['provider'] as Map : null);
    final rawDate =
        data?['backgroundCheckCompletedAt'] ??
        data?['background_check_completed_at'] ??
        prov?['backgroundCheckCompletedAt'] ??
        prov?['background_check_completed_at'];
    String? dateLabel;
    if (rawDate != null) {
      final parsed = DateTime.tryParse(rawDate.toString());
      if (parsed != null) {
        dateLabel = '${_months[parsed.month - 1]} ${parsed.year}';
      }
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.verified_user,
                color: AppColors.trustGold,
                size: 28,
              ),
              const SizedBox(height: 14),
              Text(
                'Background check verified by Sporve',
                style: AppTypography.font(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                dateLabel != null
                    ? "This coach passed Sporve's identity and background check — $dateLabel."
                    : "This coach passed Sporve's identity and background check.",
                style: AppTypography.font(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimulatedMap(List<Opportunity> opps) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.ink,
      child: Stack(
        children: opps.map((opp) {
          return Positioned(
            top: opp.top,
            left: opp.left,
            right: opp.right,
            child: _buildMapMarker(opp),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMapMarker(Opportunity opp) {
    final bool isSelected = _selectedOpportunityIndex == opp.id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedOpportunityIndex = opp.id;
        });
      },
      child: AnimatedScale(
        scale: isSelected ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.slateText : AppColors.ink,
                borderRadius: BorderRadius.circular(AppRadii.chip),
                border: Border.all(
                  color: isSelected ? AppColors.slateText : AppColors.hairline,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.slateText.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Text(
                opp.price,
                style: AppTypography.font(
                  color: isSelected ? AppColors.onSlate : AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Icon(
              Icons.location_on,
              color: isSelected ? AppColors.slateText : AppColors.textSecondary,
              size: isSelected ? 28 : 24,
            ),
          ],
        ),
      ),
    );
  }

  // ── AI discovery rendering (parse -> chips -> ranked results) ──────────────

  String _cap(Object? s) {
    final str = s?.toString() ?? '';
    if (str.isEmpty) return str;
    return str[0].toUpperCase() + str.substring(1);
  }

  List<Widget> _buildAiSection(SearchProvider search) {
    return [
      const SizedBox(height: 24),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Text(
              'AI Results',
              style: AppTypography.font(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            const AIBadge(label: 'AI'),
          ],
        ),
      ),
      // Editable constraint chips — tap × to drop one and re-rank.
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        child: _buildConstraintChips(search),
      ),
      const SizedBox(height: 16),

      if (search.isBusy)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: SkeletonList()),
        )
      else if (search.error != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ErrorRetry(
            message: search.error!,
            onRetry: () => search.reExecute(),
          ),
        )
      else if (search.isEmptyResult) ...[
        if (search.relax != null) _buildRelaxBanner(search),
        const EmptyState(
          icon: Icons.search_off_outlined,
          title: 'No matches yet',
          message: 'Try removing a filter above, or widen your search.',
        ),
      ] else
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              for (final r in search.results)
                if (r is Map) _buildAiResultCard(r),
            ],
          ),
        ),
    ];
  }

  Widget _buildConstraintChips(SearchProvider search) {
    final c = search.constraints;
    void dropKey(String key) {
      search.clearConstraint(key);
      search.reExecute();
    }

    final chips = <Widget>[];
    if (c['sport'] != null) {
      chips.add(_chip(_cap(c['sport']), () => dropKey('sport')));
    }
    if (c['athlete_age'] != null) {
      chips.add(_chip('Age ${c['athlete_age']}', () => dropKey('athlete_age')));
    }
    if (c['max_price'] is num) {
      chips.add(
        _chip(
          'Under \$${(c['max_price'] as num).round()}',
          () => dropKey('max_price'),
        ),
      );
    }
    if (c['radius_miles'] is num) {
      chips.add(
        _chip(
          '${(c['radius_miles'] as num).round()} mi',
          () => dropKey('radius_miles'),
        ),
      );
    }
    final soft = (c['soft_attributes'] as List?) ?? const [];
    for (final s in soft) {
      chips.add(
        _chip(s.toString(), () {
          search.setConstraint(
            'soft_attributes',
            soft.where((x) => x != s).toList(),
          );
          search.reExecute();
        }),
      );
    }

    if (chips.isEmpty) {
      return Text(
        'No specific filters detected — showing the best overall matches.',
        style: AppTypography.font(color: AppColors.textTertiary, fontSize: 12),
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _chip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.slateTint,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: AppColors.slateBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.font(
              color: AppColors.slateText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 14,
              color: AppColors.slateText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelaxBanner(SearchProvider search) {
    final msg = search.relax?['message']?.toString();
    if (msg == null || msg.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.slateTint,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.slateBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.tips_and_updates_outlined,
            color: AppColors.slateText,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: AppTypography.font(
                color: AppColors.slateText,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Opportunity _opportunityFromResult(Map r) {
    final price = r['price'];
    return Opportunity(
      id: 0,
      programId: r['program_id']?.toString(),
      title: r['title']?.toString() ?? 'Program',
      coach: r['specialty']?.toString() ?? '',
      price: '\$${price is num ? price.round() : (price ?? 0)}',
      rating: '${r['rating'] ?? ''}',
      image: '',
      spotsLeft: '',
      isVerified: false,
      bookingTrend: '',
      top: 0,
      team: '',
      rawData: Map<String, dynamic>.from(r),
    );
  }

  Widget _buildAiResultCard(Map r) {
    final title = r['title']?.toString() ?? 'Program';
    final specialty = r['specialty']?.toString() ?? '';
    final price = r['price'];
    final rating = r['rating'];
    final why = r['why']?.toString();
    return GestureDetector(
      onTap: () => Get.toNamed(
        AppRoutes.sessionDetails,
        arguments: _opportunityFromResult(r),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          // Sport-color left accent (measured color, Kalshi-style category cue).
          border: Border(
            left: BorderSide(color: SportColors.of(specialty), width: 3),
            top: const BorderSide(color: AppColors.hairline),
            right: const BorderSide(color: AppColors.hairline),
            bottom: const BorderSide(color: AppColors.hairline),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.font(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (specialty.isNotEmpty) ...[
                  SportTag(_cap(specialty)),
                  const SizedBox(width: 10),
                ],
                if (price != null)
                  Text(
                    '\$${price is num ? price.round() : price}',
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (rating != null &&
                    '$rating'.isNotEmpty &&
                    '$rating' != '0') ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.star, color: AppColors.slateText, size: 13),
                  const SizedBox(width: 2),
                  Text(
                    '$rating',
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            if (why != null && why.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.slateTint,
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: AppColors.slateText,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        why,
                        style: AppTypography.font(
                          color: AppColors.slateText,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOpportunityCard(Opportunity opp, HomeProvider homeProvider) {
    final dist = _distanceKm(opp);
    final nextAvailable = _nextAvailableLabel(
      homeProvider.nextSessionStartForProgram(opp.programId),
    );
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.sessionDetails, arguments: opp),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SporveImage(
                  opp.image,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  radius: AppRadii.card,
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.negative,
                      borderRadius: BorderRadius.circular(AppRadii.chip),
                    ),
                    child: Text(
                      opp.spotsLeft,
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Consumer<HomeProvider>(
                    builder: (context, homeProvider, child) {
                      final isFav = homeProvider.isFavorite(opp.programId);
                      return GestureDetector(
                        onTap: () {
                          // Soft gate (spec §3.2): guests get a few free saves.
                          // Intent preservation (§3.3.3): past the allowance,
                          // defer the save so it applies itself after sign-in.
                          // `homeProvider` is the app-level Consumer instance —
                          // safe to call from the deferred callback.
                          if (context.read<AuthProvider>().allowSave(
                            isCurrentlySaved: isFav,
                            onAuthed: () =>
                                homeProvider.toggleFavorite(opp.programId),
                          )) {
                            homeProvider.toggleFavorite(opp.programId);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav
                                ? AppColors.slateText
                                : AppColors.textPrimary,
                            size: 24,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        opp.price.startsWith('\$1')
                            ? opp.price
                            : '${opp.price}+',
                        style: AppTypography.font(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: AppColors.textPrimary,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            opp.rating,
                            style: AppTypography.font(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    opp.title,
                    style: AppTypography.font(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    opp.coach,
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  if (opp.rawData?['sportType'] != null) ...[
                    const SizedBox(height: 10),
                    SportTag(_cap(opp.rawData!['sportType'])),
                  ],
                  // Distance + next-available — grounded, mono for data.
                  if (dist != null || nextAvailable != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (dist != null) ...[
                          const Icon(
                            Icons.location_on_outlined,
                            color: AppColors.textTertiary,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${dist.toStringAsFixed(dist < 10 ? 1 : 0)} km',
                            style: AppTypography.mono(
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (dist != null && nextAvailable != null)
                          const SizedBox(width: 14),
                        if (nextAvailable != null)
                          Flexible(
                            child: Text(
                              nextAvailable,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.font(
                                color: AppColors.slateText,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (opp.isVerified) ...[
                        _buildGoldVerifiedChip(opp.rawData),
                        const SizedBox(width: 8),
                      ],
                      _buildTag(
                        Icons.calendar_today,
                        opp.bookingTrend,
                        AppColors.slateText,
                      ),
                      const Spacer(),
                      SporveButton(
                        'Details',
                        onPressed: () => Get.toNamed(
                          AppRoutes.sessionDetails,
                          arguments: opp,
                        ),
                        variant: SporveButtonVariant.primary,
                        size: SporveButtonSize.compact,
                        icon: Icons.arrow_forward_ios,
                        fullWidth: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Gold trust-check pill (decision #7) — tap explains the background check.
  Widget _buildGoldVerifiedChip(Map<String, dynamic>? data) {
    return GestureDetector(
      onTap: () => _showVerificationDetails(data),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.trustGold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.verified_user,
              color: AppColors.trustGold,
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              'Verified',
              style: AppTypography.font(
                color: AppColors.trustGold,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.font(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
