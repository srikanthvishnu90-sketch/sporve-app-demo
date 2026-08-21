import 'package:flutter/material.dart';
import 'package:sporve_app/core/theme/app_typography.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../controllers/plan_provider.dart';
import '../../authentication/controllers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/sport_colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/motion_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../../widgets/sporve_image.dart';
import '../widgets/best_match_card.dart';
import '../../../core/utils/session_time.dart';
import '../../../core/utils/provider_trust.dart';
import 'search_screen.dart'; // To access Opportunity model
import 'support_modal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().fetchAllAthleteData();
      // Load the athlete's goal + server-ranked proposals so Home can surface a
      // personalized "best for your goal" rail. Safe for guests (no athlete →
      // no goal → the rail simply doesn't render).
      context.read<PlanProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    final plan = context.watch<PlanProvider>();
    final auth = context.watch<AuthProvider>();
    final categories = ['All', 'Facilities', 'Training', 'Camps', 'Programs'];

    return GradientScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Section with Padding
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: SporveImage(
                              (homeProvider.userProfile != null &&
                                      homeProvider
                                              .userProfile!['profileImage'] !=
                                          null)
                                  ? homeProvider.userProfile!['profileImage']
                                  : '',
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              fallbackIcon: Icons.person,
                              semanticLabel: 'Your profile',
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            SporveIconButton(
                              Icons.help_outline_rounded,
                              semanticLabel: 'Support',
                              onTap: () => SupportModal.show(context),
                              iconSize: 22,
                            ),
                            const SizedBox(width: 8),
                            SporveIconButton(
                              Icons.notifications_outlined,
                              semanticLabel: 'Notifications',
                              onTap: () =>
                                  Get.toNamed(AppRoutes.notificationSettings),
                              iconSize: 22,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Hello!',
                      style: AppTypography.font(
                        color: AppColors.textGrey,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      () {
                        final p = homeProvider.userProfile;
                        final first =
                            (p?['firstName'] as String?)?.trim() ?? '';
                        final last = (p?['lastName'] as String?)?.trim() ?? '';
                        final full = '$first $last'.trim();
                        if (full.isNotEmpty) return full;
                        // fallback: use email username before the '@'
                        final email = (p?['email'] as String?) ?? '';
                        if (email.contains('@')) return email.split('@').first;
                        return 'Athlete';
                      }(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.font(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    CustomSearchField(
                      // "Ask Sporve to find a coach…" opens the AI concierge:
                      // whatever the family types is parsed, matched against the
                      // real verified roster, and answered with the best-fit
                      // coaches + reasons — not a plain filter search.
                      onTap: () => Get.toNamed(AppRoutes.aiAssistant),
                    ),
                  ],
                ),
              ),

              // Horizontal Categories (Full Width Scroll)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: categories
                      .map(
                        (cat) => Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: CategoryChip(
                            label: cat,
                            isSelected: homeProvider.selectedCategory == cat,
                            onTap: () => homeProvider.setCategory(cat),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

              // Middle Banner & Cards with Padding
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Personalized "best for your goal" rail — the concierge
                    // engine's goal-ranked proposals. Its header reads "Based on
                    // your goal…", so it renders ONLY when the athlete actually
                    // has a goal. Signed-in families without a goal see a slim
                    // banner inviting them to set one; guests just browse below.
                    Builder(
                      builder: (_) {
                        final personalized = plan.hasGoal
                            ? plan.proposals
                                  .map((p) => p['program'])
                                  .whereType<Map>()
                                  .map((p) => Map<String, dynamic>.from(p))
                                  .toList()
                            : <Map<String, dynamic>>[];
                        if (personalized.isNotEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 32),
                            child: BestMatchCarousel(matches: personalized),
                          );
                        }
                        if (auth.isVerified && !plan.hasGoal) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: _buildGoalBanner(),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    _buildBanner(),
                    const SizedBox(height: 32),
                    if (_nextUpcomingBooking(homeProvider.bookings) !=
                        null) ...[
                      _buildComingUpCard(
                        _nextUpcomingBooking(homeProvider.bookings)!,
                        homeProvider.programs,
                      ),
                      const SizedBox(height: 32),
                    ],
                    if (homeProvider.bookings.isNotEmpty) ...[
                      _buildBookAgainCard(homeProvider),
                      const SizedBox(height: 24),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            '${homeProvider.stats['sessions']}',
                            'SESSIONS',
                            Icons.calendar_today,
                            AppColors.slateText,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            '${homeProvider.stats['upcoming']}',
                            'UPCOMING',
                            Icons.schedule,
                            AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            '${homeProvider.stats['saved']}',
                            'SAVED',
                            Icons.favorite,
                            AppColors.slateText,
                          ),
                        ),
                      ],
                    ),
                    // "Near You" rail only when there are programs to show.
                    if (homeProvider.programs.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      Text(
                        'NEAR YOU',
                        style: AppTypography.font(
                          color: AppColors.textGrey,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Horizontal Near You Cards (Full Width Scroll) — hidden when empty.
              if (homeProvider.programs.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: homeProvider.programs.take(3).map((program) {
                      final gallery = program['gallery'];
                      final coverImg = program['coverImage']?.toString().trim();
                      final progImg = program['image']?.toString().trim();
                      final provider = program['providerId'];
                      final provImg = provider is Map
                          ? provider['profileImage']?.toString().trim()
                          : null;
                      final sportType = program['sportType']?.toString();
                      final rawImage = (coverImg != null && coverImg.isNotEmpty)
                          ? coverImg
                          : (progImg != null && progImg.isNotEmpty)
                          ? progImg
                          : (gallery is List &&
                                gallery.isNotEmpty &&
                                gallery[0].toString().isNotEmpty)
                          ? gallery[0].toString()
                          : (provImg != null && provImg.isNotEmpty)
                          ? provImg
                          : '';
                      final image = rawImage.isNotEmpty
                          ? rawImage
                          : SportColors.fallbackImageOf(sportType);
                      // Grounded: a real rating or an honest "New" — never a
                      // fabricated 5.0★.
                      final avgRating = program['averageRating'];
                      final rating = (avgRating is num && avgRating > 0)
                          ? avgRating.toString()
                          : 'New';

                      final opp = Opportunity(
                        id: 0,
                        programId: program['_id']?.toString(),
                        title: program['title'] ?? 'Program',
                        coach:
                            program['providerId']?['businessName'] ?? 'Academy',
                        price: '\$${program['price'] ?? 0}',
                        rating: rating,
                        image: image,
                        spotsLeft: 'AVAILABLE',
                        isVerified: providerTrusted(program),
                        bookingTrend: 'Trending now',
                        top: 0,
                        team:
                            program['providerId']?['businessName'] ?? 'Academy',
                        rawData: program,
                      );

                      return NearYouCard(
                        title: opp.title,
                        subtitle: opp.coach,
                        price: opp.price,
                        rating: opp.rating,
                        image: opp.image,
                        sport: program['sportType']?.toString(),
                        onTap: () => Get.toNamed(
                          AppRoutes.sessionDetails,
                          arguments: opp,
                        ),
                      );
                    }).toList(),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${homeProvider.programs.length} Programs Available',
                          style: AppTypography.font(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Get.toNamed(AppRoutes.map),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: AppColors.textGrey,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Map',
                                style: AppTypography.font(
                                  color: AppColors.textGrey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (homeProvider.isLoadingPrograms)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: SkeletonList(),
                        ),
                      )
                    else if (homeProvider.programsError)
                      ErrorRetry(onRetry: () => homeProvider.fetchPrograms())
                    else if (homeProvider.programs.isEmpty)
                      EmptyState(
                        icon: Icons.sports_soccer_outlined,
                        title: 'No programs near you yet.',
                        message:
                            'Check back soon, or widen your search to find coaches.',
                        actionLabel: 'Search programs',
                        onAction: () => Get.toNamed(AppRoutes.search),
                      )
                    else
                      ...homeProvider.programs.map((program) {
                        final gallery = program['gallery'];
                        final coverImg = program['coverImage']
                            ?.toString()
                            .trim();
                        final progImg = program['image']?.toString().trim();
                        final provider = program['providerId'];
                        final provImg = provider is Map
                            ? provider['profileImage']?.toString().trim()
                            : null;
                        final sportType = program['sportType']?.toString();
                        final rawImage =
                            (coverImg != null && coverImg.isNotEmpty)
                            ? coverImg
                            : (progImg != null && progImg.isNotEmpty)
                            ? progImg
                            : (gallery is List &&
                                  gallery.isNotEmpty &&
                                  gallery[0].toString().isNotEmpty)
                            ? gallery[0].toString()
                            : (provImg != null && provImg.isNotEmpty)
                            ? provImg
                            : '';
                        final image = rawImage.isNotEmpty
                            ? rawImage
                            : SportColors.fallbackImageOf(sportType);
                        // Grounded: a real rating or an honest "New" — never a
                        // fabricated 0.0★.
                        final avgRating = program['averageRating'];
                        final rating = (avgRating is num && avgRating > 0)
                            ? avgRating.toString()
                            : 'New';

                        final opp = Opportunity(
                          id: 0,
                          programId: program['_id']?.toString(),
                          title: program['title'] ?? 'Program',
                          coach:
                              (provider is Map
                                  ? provider['businessName']
                                  : null) ??
                              'Academy',
                          price: '\$${program['price'] ?? 0}',
                          rating: rating,
                          image: image,
                          spotsLeft: 'AVAILABLE',
                          isVerified: providerTrusted(program),
                          bookingTrend: 'Trending now',
                          top: 0,
                          team:
                              program['providerId']?['businessName'] ??
                              'Academy',
                          rawData: program,
                        );

                        return ProgramListItem(
                          title: opp.title,
                          subtitle:
                              program['sportType']?.toString() ?? 'General',
                          price: opp.price,
                          rating: opp.rating,
                          schedule: program['sportType'] ?? 'General',
                          image: opp.image,
                          sport: program['sportType']?.toString(),
                          onTap: () => Get.toNamed(
                            AppRoutes.sessionDetails,
                            arguments: opp,
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Slim, non-blocking invite for signed-in families without a goal — tapping
  // opens the concierge goal-intake, which then personalizes this Home feed.
  Widget _buildGoalBanner() {
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.goalIntake),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.slateTint,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.tile),
              ),
              child: const Icon(
                Icons.flag_outlined,
                color: AppColors.slateText,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Set your athlete's goal",
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Personalize your best-match trainers.',
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward,
              color: AppColors.slateText,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.nearbySession),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            Image.asset(
              'assets/images/marketeq_goal.png',
              width: 32,
              height: 32,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.auto_awesome,
                color: AppColors.slateText,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find a session near you.',
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'AI-PERSONALIZED FOR YOU',
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            SlateCircleButton(
              onTap: () => Get.toNamed(AppRoutes.nearbySession),
            ),
          ],
        ),
      ),
    );
  }

  static const List<String> _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const List<String> _monthShort = [
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

  /// The soonest booking whose session starts today or later (not the most
  /// recently created). Returns null when there are no upcoming bookings.
  Map<String, dynamic>? _nextUpcomingBooking(List bookings) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    Map<String, dynamic>? best;
    DateTime? bestStart;
    for (final b in bookings) {
      if (b is! Map) continue;
      final session = b['sessionId'] is Map ? b['sessionId'] : null;
      final start = parseSessionStart(session);
      if (start == null) continue;
      final startDay = DateTime(start.year, start.month, start.day);
      if (startDay.isBefore(today)) continue; // skip past sessions
      if (bestStart == null || start.isBefore(bestStart)) {
        bestStart = start;
        best = Map<String, dynamic>.from(b);
      }
    }
    return best;
  }

  /// A human relative-day label: Today / Tomorrow / weekday (this week) / date.
  String _relativeDay(DateTime start) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(start.year, start.month, start.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff > 1 && diff < 7) return _weekdayNames[start.weekday - 1];
    return '${_monthShort[start.month - 1]} ${start.day}';
  }

  Widget _buildComingUpCard(dynamic nextBooking, List programs) {
    final session = nextBooking['sessionId'] is Map
        ? nextBooking['sessionId']
        : null;

    // programId may be a full object OR just an id string (mock data is inconsistent).
    // Resolve the full program from the loaded list so we get sport + provider,
    // and never index a String with a map key (that was the crash).
    final rawBookingProgram = nextBooking['programId'];
    final rawSessionProgram = session?['programId'];
    String? programId;
    if (rawBookingProgram is Map) {
      programId = rawBookingProgram['_id']?.toString();
    } else if (rawBookingProgram is String) {
      programId = rawBookingProgram;
    } else if (rawSessionProgram is Map) {
      programId = rawSessionProgram['_id']?.toString();
    } else if (rawSessionProgram is String) {
      programId = rawSessionProgram;
    }

    Map? program;
    if (programId != null) {
      for (final p in programs) {
        if (p is Map && p['_id']?.toString() == programId) {
          program = p;
          break;
        }
      }
    }
    program ??= rawBookingProgram is Map
        ? rawBookingProgram
        : (rawSessionProgram is Map ? rawSessionProgram : null);

    final startTime = parseSessionStart(session);
    final sport = program?['sportType']?.toString() ?? 'Soccer';
    final sportColor = SportColors.of(sport);

    // Card with a 3px sport bar down the left edge + a sport-tint header wash.
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.hairline),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: sportColor),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [SportColors.washOf(sport), Colors.transparent],
                      stops: const [0.0, 0.75],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'COMING UP NEXT',
                            style: AppTypography.font(
                              color: sportColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            startTime == null
                                ? 'Time unavailable'
                                : '${_relativeDay(startTime)}, ${formatTime12h(startTime)}',
                            style: AppTypography.font(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          SportIconTile(sport, size: 48),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  program?['title']?.toString() ??
                                      'Training Session',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.font(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  (program?['providerId'] is Map)
                                      ? (program!['providerId']['businessName']
                                                ?.toString() ??
                                            'Academy')
                                      : 'Coach',
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
                          OutlinePill('VIEW', color: sportColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Book again" from the user's REAL most-recent booking. Only called when
  /// there is at least one booking; resolves the program from the loaded list.
  Widget _buildBookAgainCard(HomeProvider homeProvider) {
    // Most recent booking by createdAt (falls back to list order).
    Map<String, dynamic>? last;
    DateTime? lastTs;
    for (final b in homeProvider.bookings) {
      if (b is! Map) continue;
      final ts = DateTime.tryParse(b['createdAt']?.toString() ?? '');
      if (last == null ||
          (ts != null && (lastTs == null || ts.isAfter(lastTs)))) {
        last = Map<String, dynamic>.from(b);
        lastTs = ts;
      }
    }
    if (last == null) return const SizedBox.shrink();

    // Resolve the booking's program from the loaded programs list.
    final session = last['sessionId'] is Map ? last['sessionId'] : null;
    final rawProg = last['programId'];
    String? pid;
    if (rawProg is Map) {
      pid = rawProg['_id']?.toString();
    } else if (rawProg is String) {
      pid = rawProg;
    } else if (session?['programId'] is String) {
      pid = session!['programId'] as String;
    }
    Map? program;
    for (final p in homeProvider.programs) {
      if (p is Map && p['_id']?.toString() == pid) {
        program = p;
        break;
      }
    }
    program ??= rawProg is Map ? rawProg : null;
    if (program == null) return const SizedBox.shrink();

    final sport = program['sportType']?.toString() ?? 'Soccer';
    final title = program['title']?.toString() ?? 'Training Session';
    final coach = (program['providerId'] is Map)
        ? (program['providerId']['businessName']?.toString() ?? 'Academy')
        : 'Academy';
    final gallery = program['gallery'];
    final image = (gallery is List && gallery.isNotEmpty)
        ? gallery[0].toString()
        : '';

    final opp = Opportunity(
      id: 0,
      programId: program['_id']?.toString(),
      title: title,
      coach: coach,
      price: '\$${program['price'] ?? 0}',
      // Grounded: a real rating or an honest "New" — never a fabricated 0.0★.
      rating: (program['averageRating'] is num && program['averageRating'] > 0)
          ? program['averageRating'].toString()
          : 'New',
      image: image,
      spotsLeft: 'AVAILABLE',
      isVerified: providerTrusted(program),
      bookingTrend: 'Book again',
      top: 0,
      team: coach,
      rawData: Map<String, dynamic>.from(program),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          SporveImage(
            image,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            radius: AppRadii.tile,
            fallbackIcon: Icons.sports,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Book again: $title',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.font(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '$sport • $coach',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.font(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SporveButton(
            'Rebook',
            onPressed: () =>
                Get.toNamed(AppRoutes.sessionDetails, arguments: opp),
            variant: SporveButtonVariant.primary,
            size: SporveButtonSize.compact,
            fullWidth: false,
            color: SportColors.of(sport),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTypography.font(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: AppTypography.font(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
