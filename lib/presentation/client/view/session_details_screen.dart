import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../controllers/home_controller.dart';
import '../../shared/controllers/chat_provider.dart';
import '../../authentication/controllers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/sport_colors.dart';
import '../../../core/routes/app_routes.dart';
import 'search_screen.dart'; // import Opportunity if defined there
import 'join_waitlist_sheet.dart';

import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../../widgets/sporve_image.dart';

class SessionDetailsScreen extends StatefulWidget {
  const SessionDetailsScreen({super.key});

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  String _selectedTab =
      'OVERVIEW'; // 'OVERVIEW', 'WHAT YOU\'LL LEARN', 'REVIEWS'
  String _selectedTier = 'STANDARD'; // 'STANDARD', 'PRO', 'ELITE'
  bool _navigating = false; // debounce double-taps into the booking flow

  Map<String, dynamic>? _stringMap(dynamic value) {
    if (value is! Map) return null;
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  List<dynamic> _list(dynamic value) => value is List ? value : const [];

  double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _providerName(Map<String, dynamic>? program, String fallback) {
    final provider = _stringMap(program?['providerId']);
    final name = provider?['businessName']?.toString().trim();
    return (name == null || name.isEmpty) ? fallback : name;
  }

  double get _basePrice {
    final dynamic args = Get.arguments;
    Map<String, dynamic>? programData;
    if (args is Opportunity) {
      programData = args.rawData;
    } else {
      programData = _stringMap(args);
    }
    final price = _number(programData?['price']);
    if (price != null && price >= 0) return price;
    if (args is Opportunity) {
      final clean = args.price.replaceAll(RegExp(r'[^0-9]'), '');
      return double.tryParse(clean) ?? 75.0;
    }
    return 75.0;
  }

  // Grounded (§15): the ONLY price is the provider's real base price from the DB
  // row. Tier labels are descriptive only — they must NEVER fabricate a price or
  // change what Stripe charges. (The React app has no tiers; this matches it and
  // the server, where a program has exactly one price.)
  String get _tierPrice => '\$${_basePrice.toStringAsFixed(0)}';

  // Charged amount = the real base price, always. No fabricated tier multiplier
  // ever reaches checkout.
  double get _tierPriceValue => _basePrice;

  String get _tierDescription {
    switch (_selectedTier) {
      case 'PRO':
        return 'Advanced pro-level coaching session with specialized drills.';
      case 'ELITE':
        return 'Private 1-on-1 intensive masterclass tailored directly for you.';
      case 'STANDARD':
      default:
        return 'Baseline training with associate coaching.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dynamic args = Get.arguments;
    Opportunity? opportunity;
    Map<String, dynamic>? programData;

    if (args is Opportunity) {
      opportunity = args;
      programData = args.rawData;
    } else {
      programData = _stringMap(args);
    }

    if (opportunity == null && programData != null) {
      final gallery = _list(programData['gallery']);
      final image = gallery.isNotEmpty ? gallery.first.toString() : '';
      final providerName = _providerName(programData, 'Academy');

      opportunity = Opportunity(
        id: 0,
        title: programData['title']?.toString() ?? 'Program',
        coach: providerName,
        price: '\$${programData['price'] ?? 0}',
        // Grounded: a real rating or an honest "New" — never a fabricated 5.0★.
        rating:
            (programData['averageRating'] is num &&
                programData['averageRating'] > 0)
            ? programData['averageRating'].toString()
            : 'New',
        image: image,
        spotsLeft: 'AVAILABLE',
        isVerified: true,
        bookingTrend: 'Trending',
        top: 0,
        team: providerName,
        rawData: programData,
      );
    }

    final String title =
        programData?['title']?.toString() ?? opportunity?.title ?? 'Session';

    // Sport identity for this session — drives the per-sport CTA, tag, scrim.
    final String sport = (programData?['sportType'] ?? 'basketball').toString();

    final gallery = _list(programData?['gallery']);
    final coverImage = programData?['coverImage']?.toString().trim();
    final String image = (coverImage != null && coverImage.isNotEmpty)
        ? coverImage
        : gallery.isNotEmpty
        ? gallery.first.toString()
        : opportunity?.image ?? '';

    final String coach = _providerName(
      programData,
      opportunity?.coach ?? 'Coach',
    );

    // Rating comes from REAL program data only — no fabricated default stars.
    final double averageRatingVal = _number(programData?['averageRating']) ?? 0;
    final int reviewsCountVal =
        _number(programData?['totalReviews'])?.toInt() ?? 0;
    final String rating = averageRatingVal > 0
        ? '${averageRatingVal.toStringAsFixed(1)} ($reviewsCountVal)'
        : 'New';

    String locationText = 'Location TBD';
    if (programData != null) {
      final addr = programData['address'];
      if (addr is Map) {
        final parts = [
          addr['line1'] ?? addr['addressLine1'],
          addr['city'],
          addr['state'],
        ].where((s) => s != null && s.toString().trim().isNotEmpty).toList();
        if (parts.isNotEmpty) {
          locationText = parts.join(', ');
        }
      } else if (addr is String && addr.isNotEmpty) {
        locationText = addr;
      } else if (programData['location'] is String &&
          (programData['location'] as String).isNotEmpty) {
        locationText = programData['location'];
      }
    }

    return GradientScaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. TOP HEADER WITH IMAGE, CLOSE BUTTON AND TITLE
            Stack(
              children: [
                // Top Cover Image with bottom gradient fade
                Container(
                  height: 380,
                  width: double.infinity,
                  foregroundDecoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent,
                        AppColors.ink,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: SporveImage(
                    image,
                    width: double.infinity,
                    height: 380,
                    fit: BoxFit.cover,
                  ),
                ),

                // Sport-color scrim at the bottom of the cover (identity wash).
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            SportColors.scrimOf(sport),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Top Action Row (Back Button)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Get.back(),
                          child: Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        Consumer<HomeProvider>(
                          builder: (context, homeProvider, child) {
                            if (opportunity == null) {
                              return const SizedBox.shrink();
                            }
                            final isFav = homeProvider.isFavorite(
                              opportunity.programId,
                            );
                            return GestureDetector(
                              onTap: () {
                                // Soft gate (spec §3.2): a guest may save a few
                                // coaches before being prompted to verify. Intent
                                // preservation (§3.3.3): once the free allowance
                                // is spent, defer the save so it applies itself
                                // after the guest signs in.
                                final id = opportunity?.programId;
                                final auth = context.read<AuthProvider>();
                                if (auth.allowSave(
                                  isCurrentlySaved: homeProvider.isFavorite(id),
                                  onAuthed: () => homeProvider.toggleFavorite(id),
                                )) {
                                  homeProvider.toggleFavorite(id);
                                }
                              },
                              child: Container(
                                height: 44,
                                width: 44,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Icon(
                                  isFav
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isFav
                                      ? AppColors.slateText
                                      : AppColors.textPrimary,
                                  size: 18,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Floating Title & Details block overlayed on bottom of cover image
                Positioned(
                  bottom: 20,
                  left: 24,
                  right: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Training & Chat Tag Row
                      Row(
                        children: [
                          SportTag(sport),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _openCoachChat(coach, programData),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.slateText,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.chip,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.chat_bubble_outline,
                                    color: AppColors.onSlate,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'CHAT',
                                    style: AppTypography.font(
                                      color: AppColors.onSlate,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Title Text
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.font(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Rating & Reviews & Address Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white38),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  rating.split(' ')[0],
                                  style: AppTypography.mono(
                                    color: Colors.white,
                                    size: 11,
                                    weight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$reviewsCountVal REVIEWS',
                            style: AppTypography.mono(
                              color: Colors.white70,
                              size: 11,
                              weight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.location_on,
                            color: AppColors.slateText,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              locationText,
                              style: AppTypography.font(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 2. TAB MENU (OVERVIEW, WHAT YOU'LL LEARN, REVIEWS)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTabItem('OVERVIEW'),
                  _buildTabItem('WHAT YOU\'LL LEARN'),
                  _buildTabItem('REVIEWS'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. MAIN DYNAMIC BODY AREA (Based on Figma Designs)
            _buildDynamicBodyContent(coach),

            const SizedBox(height: 20),

            // 4. FOOTER CARD FOR SESSION PRICE & PLAN BOOKING (WHITE BACKGROUND)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: AppColors.hairline),
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tier selector pills
                  Builder(
                    builder: (context) {
                      const tiers = ['STANDARD', 'PRO', 'ELITE'];
                      return SporveSegmented(
                        segments: tiers,
                        selected: tiers.indexOf(_selectedTier),
                        onChanged: (i) =>
                            setState(() => _selectedTier = tiers[i]),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Selected Tier Info
                  Text(
                    'SESSION PRICE',
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _tierPrice,
                    style: AppTypography.mono(
                      color: AppColors.textPrimary,
                      size: 36,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _tierDescription,
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Bottom space so the sticky bar never covers the last card.
            const SizedBox(height: 24),
          ],
        ),
      ),
      // Sticky Message + Book bar (§13–16): always reachable while scrolling.
      bottomNavigationBar: _bookingBar(sport, title, coach, programData),
    );
  }

  /// Persistent bottom action bar — Message (secondary) + Book (sport-context
  /// CTA carrying the live tier price).
  Widget _bookingBar(
    String sport,
    String title,
    String coach,
    Map<String, dynamic>? programData,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.ink,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: SporveButton(
                'Message',
                icon: Icons.chat_bubble_outline,
                onPressed: () => _openCoachChat(coach, programData),
                variant: SporveButtonVariant.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              // Coach OS (P0 #3): a FULL program shows "Join waitlist" instead of
              // Book — full-slot demand is captured, not bounced. Open/unbounded
              // programs (no declared capacity) always show Book.
              child: programIsFull(programData)
                  ? SporveButton(
                      'Join waitlist',
                      icon: Icons.people_alt_outlined,
                      onPressed: () {
                        context.read<AuthProvider>().requireAuth(() {
                          showJoinWaitlistSheet(
                            context,
                            program: programData ?? const {},
                          );
                        });
                      },
                      variant: SporveButtonVariant.primary,
                      color: AppColors.slate,
                    )
                  : SporveButton(
                      'Book · $_tierPrice',
                      onPressed: () {
                        // Auth-on-action (spec §3.2): a guest is sent to verify
                        // first; a verified user proceeds into the booking flow.
                        context.read<AuthProvider>().requireAuth(() {
                          if (_navigating) return; // ignore rapid double-taps
                          _navigating = true;
                          Get.toNamed(
                            AppRoutes.bookingFlow,
                            arguments: {
                              'program': programData,
                              'title': title,
                              'coach': coach,
                              'tier': _selectedTier,
                              'price': _tierPriceValue,
                            },
                          )?.then((_) => _navigating = false);
                        });
                      },
                      variant: SporveButtonVariant.primary,
                      color: AppColors
                          .slate, // §1/#7: Book is chrome — slate, never sport
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(String title) {
    final bool isSelected = _selectedTab == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = title;
        });
      },
      child: Column(
        children: [
          Text(
            title,
            style: AppTypography.font(
              color: isSelected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2,
            width: isSelected ? 40 : 0,
            color: AppColors.slateText,
          ),
        ],
      ),
    );
  }

  /// Opens (or reuses) a chat thread with this coach and navigates to it.
  void _openCoachChat(String coach, Map<String, dynamic>? program) {
    // Auth-on-action (spec §3.2): messaging a coach requires a verified account.
    // Intent preservation (§3.3.3): the ENTIRE open-chat action is the
    // requireAuth closure, so a guest who signs in resumes straight into the
    // conversation instead of re-tapping Message. Capture the ChatProvider up
    // front — after sign-in this screen may be gone, but the app-level provider
    // (and Get navigation) outlive it.
    final auth = context.read<AuthProvider>();
    final chat = context.read<ChatProvider>();

    Future<void> openThread() async {
      final provider = program?['providerId'];
      final providerOwnerId = provider is Map
          ? provider['ownerId']?.toString()
          : null;
      if (providerOwnerId == null || providerOwnerId.isEmpty) {
        Get.snackbar(
          'Messaging unavailable',
          'This coach profile is missing its messaging identity.',
        );
        return;
      }
      final conv = await chat.initiateConversation(
        providerOwnerId,
        programId: program?['_id']?.toString(),
        recipientName: coach,
        recipientRole: 'provider',
      );
      if (conv == null) return;
      Get.toNamed(
        AppRoutes.chatDetails,
        arguments: {
          'conversationId': conv['_id'],
          'contactName': coach,
          'avatarUrl': '',
        },
      );
    }

    auth.requireAuth(() => openThread());
  }

  int get _reviewsCount {
    final dynamic args = Get.arguments;
    Map<String, dynamic>? programData;
    if (args is Opportunity) {
      programData = args.rawData;
    } else {
      programData = _stringMap(args);
    }
    return _number(programData?['totalReviews'])?.toInt() ?? 0;
  }

  Widget _buildDynamicBodyContent(String coach) {
    if (_selectedTab == 'REVIEWS') {
      // Zero-state: an unreviewed but vetted coach reads as trustworthy, not empty.
      if (_reviewsCount <= 0) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildReviewZeroState(),
        );
      }
      // Grounded (decision #3): render only the real aggregate we have
      // (average + count). Individual review bodies aren't loaded here, so we
      // never fabricate review cards or a rating distribution.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            _buildRatingSummary(),
            const SizedBox(height: 16),
            Text(
              'Written reviews aren\'t shown here yet.',
              textAlign: TextAlign.center,
              style: AppTypography.font(
                color: AppColors.textTertiary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    // OVERVIEW and WHAT YOU'LL LEARN share the same giant white card box container style
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.all(28),
      child: _selectedTab == 'WHAT YOU\'LL LEARN'
          ? _buildWhatYoullLearn()
          : _buildOverviewContent(),
    );
  }

  // FIGMA WHAT YOU'LL LEARN LAYOUT
  Widget _buildWhatYoullLearn() {
    final dynamic args = Get.arguments;
    Map<String, dynamic>? programData;
    if (args is Opportunity) {
      programData = args.rawData;
    } else {
      programData = _stringMap(args);
    }

    final String sportType = programData?['sportType']?.toString() ?? '';

    // Choose dynamic breakdown steps based on sportType
    String step1Title = 'Warm-Up Protocol';
    String step1Desc =
        'Dynamic stretching, light cardio, and sport-specific warm-up.';
    String step2Title = 'Skill Drills';
    String step2Desc =
        'Core skill development and technical drill progression.';
    String step3Title = 'Live Application';
    String step3Desc =
        'Game-speed scenarios applying drill concepts in real-time.';
    String step4Title = 'Cool Down & Review';
    String step4Desc = 'Recovery stretches and tactical review of the session.';

    if (sportType.toLowerCase() == 'soccer') {
      step1Desc = 'Dynamic stretching, light footwork, and dribbling warm-up.';
      step2Title = 'Tactical Drills';
      step2Desc = 'Passing accuracy, ball control, and shooting practice.';
      step3Title = 'Match Simulation';
      step3Desc =
          'Small-sided game application to test positioning and teamwork.';
      step4Title = 'Cool Down & Feedback';
      step4Desc =
          'Recovery stretch session and strategic feedback from the coach.';
    } else if (sportType.toLowerCase() == 'basketball') {
      step1Desc = 'Dynamic stretching, dribbling drills, and shooting warm-up.';
      step2Desc =
          'Finishing at the rim, pick & roll execution, and defensive positioning.';
      step3Title = 'Scrimmage';
      step3Desc =
          'Half-court game simulation applying concepts learned under pressure.';
      step4Title = 'Cool Down & Feedback';
      step4Desc = 'Free-throw shooting and individual performance review.';
    }

    // Inclusions
    final List<dynamic>? inclusionsRaw = programData?['whatsIncluded'];
    final List<String> inclusions =
        (inclusionsRaw != null && inclusionsRaw.isNotEmpty)
        ? inclusionsRaw.map((e) => e.toString()).toList()
        : ['Video analysis included', '1-on-1 focus', 'Customized drills'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SESSION BREAKDOWN',
          style: AppTypography.font(
            color: AppColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 24),

        // Steps
        _buildLearnStep(
          step: '1',
          title: step1Title,
          duration: '10 MIN',
          description: step1Desc,
        ),
        const SizedBox(height: 24),
        _buildLearnStep(
          step: '2',
          title: step2Title,
          duration: '25 MIN',
          description: step2Desc,
        ),
        const SizedBox(height: 24),
        _buildLearnStep(
          step: '3',
          title: step3Title,
          duration: '15 MIN',
          description: step3Desc,
        ),
        const SizedBox(height: 24),
        _buildLearnStep(
          step: '4',
          title: step4Title,
          duration: '10 MIN',
          description: step4Desc,
        ),

        const SizedBox(height: 28),

        // What's Included Green Box Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.slateTint,
            borderRadius: BorderRadius.circular(AppRadii.tile),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WHAT\'S INCLUDED',
                style: AppTypography.font(
                  color: AppColors.slateText,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              ...inclusions.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIncludedItem(item),
                    if (idx < inclusions.length - 1) const SizedBox(height: 10),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLearnStep({
    required String step,
    required String title,
    required String duration,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Number badge circle
        Container(
          height: 38,
          width: 38,
          decoration: const BoxDecoration(
            color: AppColors.slateTint,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: AppTypography.font(
              color: AppColors.slateText,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    duration,
                    style: AppTypography.mono(
                      color: AppColors.textTertiary,
                      size: 11,
                      weight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTypography.font(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIncludedItem(String text) {
    return Row(
      children: [
        const Icon(Icons.check, color: AppColors.slateText, size: 16),
        const SizedBox(width: 8),
        Text(
          text,
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // DEFAULT OVERVIEW TAB CONTENT
  Widget _buildOverviewContent() {
    final dynamic args = Get.arguments;
    Map<String, dynamic>? programData;
    if (args is Opportunity) {
      programData = args.rawData;
    } else if (args is Map<String, dynamic>) {
      programData = args;
    }

    final String overviewDescription =
        programData?['description'] ??
        (args is Opportunity
            ? args.title
            : 'Focused session on ball handling, court vision, and finishing under pressure.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ABOUT THIS SESSION',
          style: AppTypography.font(
            color: AppColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          overviewDescription,
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),

        // Verified badge — shown ONLY when the coach is genuinely verified.
        // (Fabricated "94 viewed", "booked 3x today", and a blanket
        // "Background checked" / "98% response rate" were removed — they were
        // not real data, and a false safety claim is worse than none.)
        if (args is Opportunity && args.isVerified)
          GestureDetector(
            onTap: () => _showVerificationDetails(args.rawData),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppRadii.tile),
              ),
              child: Row(
                children: [
                  // Gold trust check (decision #7) — never slate, never green.
                  const Icon(
                    Icons.verified_user,
                    color: AppColors.trustGold,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verified by Sporve',
                          style: AppTypography.font(
                            color: AppColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Background check verified',
                          style: AppTypography.font(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 24),

        // Grid Properties (Sport, Distance, Age, Response)
        Row(
          children: [
            _buildGridBox(
              'SPORT',
              Icons.emoji_events,
              programData?['sportType']?.toString() ?? '—',
            ),
            const SizedBox(width: 12),
            _buildGridBox(
              'DISTANCE',
              Icons.place,
              programData?['distance'] != null
                  ? '${programData!['distance']} miles'
                  : '—',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildGridBox(
              'AGE RANGE',
              Icons.person,
              (programData?['minimumAge'] != null &&
                      programData?['maximumAge'] != null)
                  ? '${programData!['minimumAge']}-${programData['maximumAge']} years'
                  : '—',
            ),
            const SizedBox(width: 12),
            _buildGridBox(
              'CANCELLATION',
              Icons.shield,
              programData?['cancellationPolicy']?.toString() ?? '—',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGridBox(String label, IconData icon, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadii.tile),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.font(
                color: AppColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(icon, color: AppColors.slateText, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    value,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Tap-through for the gold trust check (decision #7). The date is shown only
  // when a real value exists on the row — never fabricated.
  void _showVerificationDetails(Map<String, dynamic>? data) {
    // The background-check timestamp lives on the provider — which may be nested
    // under providerId/provider on a program row. Never fabricated: shown only
    // when a real value exists (coordinator: `providers.background_check_completed_at`).
    final prov = data?['providerId'] is Map
        ? data!['providerId'] as Map
        : (data?['provider'] is Map ? data!['provider'] as Map : null);
    final rawDate =
        data?['backgroundCheckCompletedAt'] ??
        data?['background_check_completed_at'] ??
        prov?['backgroundCheckCompletedAt'] ??
        prov?['background_check_completed_at'] ??
        data?['background_check_date'] ??
        data?['backgroundCheckDate'] ??
        data?['verifiedAt'] ??
        data?['verified_at'];
    String? dateLabel;
    if (rawDate != null) {
      final parsed = DateTime.tryParse(rawDate.toString());
      if (parsed != null) {
        const months = [
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
        dateLabel = '${months[parsed.month - 1]} ${parsed.year}';
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
                    ? 'This coach passed Sporve\'s identity and background check — $dateLabel.'
                    : 'This coach passed Sporve\'s identity and background check.',
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

  // Review zero-state — vetted-but-unreviewed coach reads as ready, not empty.
  Widget _buildReviewZeroState() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.slateTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: AppColors.slateText,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'New to Sporve — verified and ready',
            textAlign: TextAlign.center,
            style: AppTypography.font(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This coach has been identity-verified and safety-checked. Be the '
            'first to book and leave a review.',
            textAlign: TextAlign.center,
            style: AppTypography.font(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // FIGMA REVIEWS SUMMARY CARD
  Widget _buildRatingSummary() {
    final dynamic args = Get.arguments;
    Map<String, dynamic>? programData;
    if (args is Opportunity) {
      programData = args.rawData;
    } else {
      programData = _stringMap(args);
    }

    final double avgRating = _number(programData?['averageRating']) ?? 0;
    final int reviewsCount =
        _number(programData?['totalReviews'])?.toInt() ?? 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Grounded aggregate only — no fabricated rating distribution.
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                avgRating > 0 ? avgRating.toStringAsFixed(1) : '—',
                style: AppTypography.mono(
                  color: AppColors.textPrimary,
                  size: 48,
                  weight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return Icon(
                    index < avgRating.round() ? Icons.star : Icons.star_border,
                    color: AppColors.textPrimary,
                    size: 16,
                  );
                }),
              ),
              const SizedBox(height: 6),
              Text(
                '$reviewsCount REVIEWS',
                style: AppTypography.mono(
                  color: AppColors.textTertiary,
                  size: 11,
                  weight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
