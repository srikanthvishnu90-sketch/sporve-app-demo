import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/app_repository.dart';
import '../../authentication/controllers/auth_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/session_time.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/sport_colors.dart';
import '../controllers/home_controller.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../widgets/add_child_sheet.dart';
import '../widgets/multi_booking_sheet.dart';

class BookingFlowScreen extends StatefulWidget {
  const BookingFlowScreen({super.key});

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  // Offline demo has no Stripe backend — mirror main.dart's repo switch.
  static const bool _useMockRepo = bool.fromEnvironment(
    'USE_MOCK_REPO',
    defaultValue: false,
  );

  int _currentStep =
      1; // Step 1: Book Slot, Step 2: Review & Pay, Step 3: Getting Ready, Step 4: Confirmed
  int _selectedDay = 4;
  String _selectedTime = '10:30 AM';
  bool _bookingSaved = false; // guard against double-persist

  // Real booking id + payment status. The booking is created UNPAID, then the
  // existing "Confirm & Pay" button drives Stripe hosted Checkout (#20b).
  String? _realBookingId;
  String _paymentStatus = 'unpaid';
  bool _checkoutLoading = false;

  // Real session + child selection (E). Bookings attach to the session the user
  // actually picks, and always carry a chosen athlete_id.
  List<Map<String, dynamic>> _programSessions = [];
  Map<String, dynamic>? _selectedSession;
  List<Map<String, dynamic>> _athletes = [];
  String? _selectedAthleteId;
  String? _selectedAthleteName;

  // Booksy trainer picker: the org's bookable (verified + active) roster. Empty
  // = solo provider, and the picker is hidden entirely. null selection = "Any
  // available trainer" (the org assigns whoever). The chosen trainer is recorded
  // on the booking for attribution — it never changes the price/charge.
  List<Map<String, dynamic>> _trainers = [];
  String? _selectedTrainerId;
  String? _selectedTrainerName;

  // Calendar shows the real current month.
  late int _calYear;
  late int _calMonth;

  static const List<String> _monthNames = [
    'JANUARY',
    'FEBRUARY',
    'MARCH',
    'APRIL',
    'MAY',
    'JUNE',
    'JULY',
    'AUGUST',
    'SEPTEMBER',
    'OCTOBER',
    'NOVEMBER',
    'DECEMBER',
  ];
  static const List<String> _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  int get _daysInMonth => DateTime(_calYear, _calMonth + 1, 0).day;
  // Sunday-first offset: how many blank cells before day 1.
  int get _leadingBlanks => DateTime(_calYear, _calMonth, 1).weekday % 7;

  // e.g. "Wednesday, Jun 18" for the selected date.
  String get _selectedDateLabel {
    final d = DateTime(_calYear, _calMonth, _selectedDay);
    final weekday = _weekdayNames[d.weekday - 1];
    final month = _monthNames[_calMonth - 1];
    final monthShort = (month[0] + month.substring(1).toLowerCase()).substring(
      0,
      3,
    );
    return '$weekday, $monthShort $_selectedDay';
  }

  // The full weekday name of the currently selected booking date.
  String get _selectedWeekday =>
      _weekdayNames[DateTime(_calYear, _calMonth, _selectedDay).weekday - 1];

  // ── Month navigation ────────────────────────────────────────────────────
  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _calYear == now.year && _calMonth == now.month;
  }

  void _prevMonth() {
    if (_isCurrentMonth) return; // never go before this month
    setState(() {
      if (_calMonth == 1) {
        _calMonth = 12;
        _calYear--;
      } else {
        _calMonth--;
      }
      _clampSelectedDay();
    });
  }

  void _nextMonth() {
    setState(() {
      if (_calMonth == 12) {
        _calMonth = 1;
        _calYear++;
      } else {
        _calMonth++;
      }
      _clampSelectedDay();
    });
  }

  // Keep _selectedDay valid for the visible month: not before today in the
  // current month, and not past the month's last day.
  void _clampSelectedDay() {
    final now = DateTime.now();
    final firstSelectable = _isCurrentMonth ? now.day : 1;
    final lastDay = _daysInMonth;
    if (_selectedDay < firstSelectable) _selectedDay = firstSelectable;
    if (_selectedDay > lastDay) _selectedDay = lastDay;
  }

  // Booking context passed from the session-details screen.
  Map<String, dynamic>? _program;
  String _sessionTitle = 'Training Session';
  String _coach = 'Academy';
  String _tier = 'STANDARD';

  // Concierge attribution (Prompt 3): when this booking is made by APPROVING a
  // plan_proposal, we store bookings.plan_proposal_id for attribution. The
  // signed Stripe webhook accepts the proposal only after verified payment.
  String? _planProposalId;

  // Sport identity of the booked program — themes the sport-context CTAs,
  // selections, and icon tile with the sport's color (exterior accent). Generic
  // chrome stays slate.
  String get _sport => (_program?['sportType'] ?? 'basketball').toString();
  Color get _sportColor => SportColors.of(_sport);

  // Pricing — provider-set price from the selected tier (falls back to 75).
  late double _sessionPrice;
  // Price integrity: the parent pays EXACTLY the session price shown here, which
  // is also what stripe-create-checkout charges. Sporve charges providers by
  // workspace subscription, so no Sporve booking fee is added or deducted.
  double get _total => _sessionPrice;
  String _money(double v) => '\$${v.toStringAsFixed(2)}';

  // The booked start as a real DateTime (selected date + parsed 12h time).
  DateTime _bookingStart() {
    final m = RegExp(
      r'(\d{1,2}):(\d{2})\s*([AaPp][Mm])?',
    ).firstMatch(_selectedTime);
    int hour = 9, minute = 0;
    if (m != null) {
      hour = int.tryParse(m.group(1)!) ?? 9;
      minute = int.tryParse(m.group(2)!) ?? 0;
      final period = m.group(3)?.toUpperCase();
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
    }
    return DateTime(_calYear, _calMonth, _selectedDay, hour, minute);
  }

  // Opens a Google Calendar event template (HTTPS — no platform scheme config).
  Future<void> _addToCalendar() async {
    final start = _bookingStart();
    final end = start.add(const Duration(hours: 1));
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}T${d.hour.toString().padLeft(2, '0')}'
        '${d.minute.toString().padLeft(2, '0')}00';

    String location = '';
    final address = _program?['address'];
    if (address is Map) {
      location = [
        address['line1'],
        address['city'],
        address['state'],
      ].where((p) => p != null && p.toString().trim().isNotEmpty).join(', ');
    }

    final url = Uri.parse(
      'https://calendar.google.com/calendar/render?action=TEMPLATE'
      '&text=${Uri.encodeComponent(_sessionTitle)}'
      '&dates=${fmt(start)}/${fmt(end)}'
      '&details=${Uri.encodeComponent('Booked via Sporve')}'
      '${location.isNotEmpty ? '&location=${Uri.encodeComponent(location)}' : ''}',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calYear = now.year;
    _calMonth = now.month;
    _selectedDay = now.day;

    final args = Get.arguments;
    if (args is Map) {
      _program = args['program'] is Map
          ? Map<String, dynamic>.from(args['program'])
          : null;
      _sessionTitle = (args['title'] ?? _program?['title'] ?? _sessionTitle)
          .toString();
      _coach = (args['coach'] ?? _coach).toString();
      _tier = (args['tier'] ?? _tier).toString();
      _planProposalId = args['planProposalId']?.toString();
      _sessionPrice = (args['price'] is num)
          ? (args['price'] as num).toDouble()
          : 75.0;

      // "Book again / same time next week" pre-fill: when the caller passes a
      // prefillDate (DateTime) + prefillTime (e.g. "10:30 AM") we jump the
      // calendar straight to that date and pre-select the time slot so the
      // user only needs to confirm — no manual hunting.
      final prefill = args['prefillDate'];
      if (prefill is DateTime) {
        _calYear = prefill.year;
        _calMonth = prefill.month;
        _selectedDay = prefill.day;
      }
      final prefillTime = args['prefillTime'];
      if (prefillTime is String && prefillTime.isNotEmpty) {
        _selectedTime = prefillTime;
      }
    } else {
      _sessionPrice = 75.0;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookable();
      _handleStripeReturn();
    });
  }


  /// Stripe Checkout return handler (web). After a payment the browser lands
  /// back on a hash-route fragment like `…/#/booking-flow?b=<id>&status=success`
  /// (set as successUrl in [_handleConfirmAndPay]). Read that fragment and, on a
  /// success return, re-fetch the booking's paymentStatus and jump straight to
  /// the Confirmed step (Step 4) instead of sitting on unpaid/pending — the fix
  /// for "I paid but nothing happened". A cancel return just leaves the user in
  /// the flow to retry; the booking stays unpaid.
  ///
  /// FOLLOW-UP (out of this single-file scope): whether a cold load actually
  /// resolves this fragment to BookingFlowScreen depends on the app-launch
  /// router (splash/auth gate reading `Uri.base.fragment`). Wiring that deep
  /// link so `/#/booking-flow?b=…&status=success` reaches this screen after the
  /// redirect is the remaining piece; this handler covers the case where it does
  /// (e.g. an already-mounted screen) and is a no-op everywhere else.
  Future<void> _handleStripeReturn() async {
    final fragment = Uri.base.fragment; // "/booking-flow?b=<id>&status=success"
    if (fragment.isEmpty) return;
    final params = Uri.tryParse(fragment)?.queryParameters ?? const {};
    final status = params['status'];
    final bookingId = params['b'];
    if (status != 'success' || bookingId == null || bookingId.isEmpty) return;

    final home = context.read<HomeProvider>();
    await home.fetchBookings(); // re-read paymentStatus from the backend
    if (!mounted) return;
    final saved = home.bookingById(bookingId);
    final paid = saved?['paymentStatus']?.toString() == 'paid';
    setState(() {
      _realBookingId = bookingId;
      _paymentStatus =
          saved?['paymentStatus']?.toString() ?? _paymentStatus;
      if (paid) _currentStep = 4; // show the in-app Confirmed screen
    });
  }

  /// Load the program's REAL upcoming sessions + the searcher's children so the
  /// booking attaches to a real session and always sets athlete_id.
  Future<void> _loadBookable() async {
    final home = context.read<HomeProvider>();
    await home.fetchAthletes();
    final sessions = await home.sessionsForProgram(
      _program?['_id']?.toString(),
    );
    // The org's bookable roster (verified + active only). Empty for solo
    // providers → the picker never renders. providerRowId is the org uuid.
    final trainers = await home.trainersForProvider(
      _program?['providerRowId']?.toString(),
    );
    if (!mounted) return;
    setState(() {
      _trainers = trainers;
      _programSessions = sessions
          .whereType<Map>()
          .map((s) => Map<String, dynamic>.from(s))
          .toList();
      _athletes = home.athletes
          .whereType<Map>()
          .map((a) => Map<String, dynamic>.from(a))
          .toList();
      if (_selectedSession == null && _programSessions.isNotEmpty) {
        _selectSession(_programSessions.first, notify: false);
      }
      if (_athletes.length == 1) {
        _selectedAthleteId = _athletes.first['_id']?.toString();
        _selectedAthleteName = _athleteName(_athletes.first);
      }
    });
  }

  String _athleteName(dynamic a) =>
      (a is Map ? (a['fullName'] ?? a['firstName']) : null)?.toString() ??
      'Athlete';

  /// Pick a real session and sync the calendar/time display to it.
  void _selectSession(Map<String, dynamic> s, {bool notify = true}) {
    final start = parseSessionStart(s);
    void apply() {
      _selectedSession = s;
      _calYear = start.year;
      _calMonth = start.month;
      _selectedDay = start.day;
      _selectedTime = (s['startTime']?.toString().isNotEmpty ?? false)
          ? s['startTime'].toString()
          : formatTime12h(start);
      _sessionTitle = s['title']?.toString() ?? _sessionTitle;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.negative),
    );
  }

  // Gate Step 1 -> Step 2: must have a real session, chosen child, and eligible coach.
  void _onContinueFromStep1() {
    if (_programSessions.isEmpty) {
      _snack('No upcoming sessions for this program yet.');
      return;
    }
    if (_selectedSession == null) {
      _snack('Please choose a session.');
      return;
    }
    if (_athletes.isEmpty) {
      _snack('Add a child in your profile before booking.');
      return;
    }
    if (_selectedAthleteId == null) {
      _snack('Please select a child first.');
      return;
    }

    // QA Day 07: Block booking if coach failed Stripe Connect KYC or payouts disabled
    final prov = _program?['providerId'];
    if (prov is Map) {
      final kyc = (prov['kycStatus'] ?? prov['verificationStatus'] ?? '').toString().toLowerCase();
      final chargesEnabled = prov['stripeChargesEnabled'] == true || prov['stripe_charges_enabled'] == true;
      if (kyc == 'rejected' || kyc == 'failed') {
        _snack('Bookings paused: This coach failed Stripe Connect KYC verification.');
        return;
      }
      if (prov.containsKey('stripeChargesEnabled') && !chargesEnabled && kyc == 'unverified') {
        _snack('Bookings paused: Coach Stripe payout setup is incomplete.');
        return;
      }
    }

    // QA Day 07: 1:1 Coaching requires selecting a named trainer (never "Any available")
    final isOneOnOne = (_program?['pricingModel'] ?? '').toString() == 'single_session';
    if (isOneOnOne && _trainers.isNotEmpty && _selectedTrainerId == null) {
      _snack('Please select a specific coach for 1:1 coaching.');
      return;
    }

    setState(() => _currentStep = 2);
  }

  // Opens the in-app "Add a child" sheet, then refreshes so the new child is
  // selectable — no more dead-ending on an empty profile.
  Future<void> _addChild() async {
    final added = await showAddChildSheet(context);
    if (!mounted || !added) return;
    final home = context.read<HomeProvider>();
    await home.fetchAthletes();
    if (!mounted) return;
    setState(() {
      _athletes = home.athletes
          .whereType<Map>()
          .map((a) => Map<String, dynamic>.from(a))
          .toList();
      if (_athletes.length == 1) {
        _selectedAthleteId = _athletes.first['_id']?.toString();
        _selectedAthleteName = _athleteName(_athletes.first);
      }
    });
  }

  // "Who's attending" — pick one of the searcher's children (sets athlete_id).
  Widget _buildChildSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHO\'S ATTENDING',
          style: AppTypography.font(
            color: AppColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        if (_athletes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No children on your profile yet. Add one to book.',
                  style: AppTypography.font(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                SporveButton(
                  'Add a child',
                  onPressed: _addChild,
                  variant: SporveButtonVariant.secondary,
                  size: SporveButtonSize.compact,
                  fullWidth: false,
                  icon: Icons.add,
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _athletes.map((a) {
              final id = a['_id']?.toString();
              final name = _athleteName(a);
              final selected = _selectedAthleteId == id;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedAthleteId = id;
                  _selectedAthleteName = name;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                    border: Border.all(
                      color: selected ? _sportColor : AppColors.hairline,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selected ? Icons.check_circle : Icons.person_outline,
                        color: selected ? _sportColor : AppColors.textTertiary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        name,
                        style: AppTypography.font(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  // Read a trainer's display fields out of the roster row's trainer_profile.
  String _trainerName(Map<String, dynamic> t) {
    final p = (t['trainer_profile'] as Map?) ?? const {};
    final n = (p['display_name'] ?? '').toString().trim();
    return n.isNotEmpty ? n : 'Trainer';
  }

  String _trainerSpecialty(Map<String, dynamic> t) {
    final p = (t['trainer_profile'] as Map?) ?? const {};
    return (p['specialty'] ?? p['bio'] ?? '').toString().trim();
  }

  String _trainerPhoto(Map<String, dynamic> t) {
    final p = (t['trainer_profile'] as Map?) ?? const {};
    return (p['photo_url'] ?? '').toString().trim();
  }

  // Booksy staff picker — appears only when the org has a bookable roster.
  // "Any available" (null) is restricted to Camps/Clinics — for 1:1 coaching,
  // parents must select a specific named trainer.
  Widget _buildTrainerPicker() {
    if (_trainers.isEmpty) return const SizedBox.shrink();
    final isOneOnOne = (_program?['pricingModel'] ?? '').toString() == 'single_session';
    final allowAny = !isOneOnOne;
    final totalCards = allowAny ? _trainers.length + 1 : _trainers.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isOneOnOne ? 'SELECT YOUR COACH' : 'CHOOSE A TRAINER',
          style: AppTypography.font(
            color: AppColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: totalCards,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (allowAny && index == 0) {
                return _trainerCard(
                  selected: _selectedTrainerId == null,
                  name: 'Any available',
                  specialty: 'We assign a coach',
                  photoUrl: '',
                  isAny: true,
                  onTap: () => setState(() {
                    _selectedTrainerId = null;
                    _selectedTrainerName = null;
                  }),
                );
              }
              final trainerIdx = allowAny ? index - 1 : index;
              final t = _trainers[trainerIdx];
              final id = t['id']?.toString();
              return _trainerCard(
                selected: _selectedTrainerId == id,
                name: _trainerName(t),
                specialty: _trainerSpecialty(t),
                photoUrl: _trainerPhoto(t),
                isAny: false,
                onTap: () => setState(() {
                  _selectedTrainerId = id;
                  _selectedTrainerName = _trainerName(t);
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _trainerCard({
    required bool selected,
    required String name,
    required String specialty,
    required String photoUrl,
    required bool isAny,
    required VoidCallback onTap,
  }) {
    final initials = name.trim().isNotEmpty
        ? name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join()
        : '?';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 128,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(
            color: selected ? _sportColor : AppColors.hairline,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.surface2,
                  backgroundImage:
                      photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isNotEmpty
                      ? null
                      : (isAny
                          ? Icon(
                              Icons.groups_outlined,
                              size: 20,
                              color: AppColors.textTertiary,
                            )
                          : Text(
                              initials.toUpperCase(),
                              style: AppTypography.font(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            )),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  size: 18,
                  color: selected ? _sportColor : AppColors.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.font(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (specialty.isNotEmpty)
              Text(
                specialty,
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
    );
  }

  // Real upcoming sessions for this program — the user books one of these.
  Widget _buildSessionPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHOOSE A SESSION',
          style: AppTypography.font(
            color: AppColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        if (_programSessions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Text(
              'No upcoming sessions for this program yet.',
              style: AppTypography.font(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          )
        else
          ..._programSessions.map((s) {
            final start = parseSessionStart(s);
            final selected = _selectedSession?['_id'] == s['_id'];
            final label =
                '${_weekdayNames[start.weekday - 1]}, '
                '${_monthNames[start.month - 1].substring(0, 3)} ${start.day}';
            final time = (s['startTime']?.toString().isNotEmpty ?? false)
                ? s['startTime'].toString()
                : formatTime12h(start);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _selectSession(s),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                    border: Border.all(
                      color: selected ? _sportColor : AppColors.hairline,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: selected ? _sportColor : AppColors.textTertiary,
                        size: 20,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          label,
                          style: AppTypography.font(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        time,
                        style: AppTypography.mono(
                          color: AppColors.textSecondary,
                          size: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        const SizedBox(height: 28),
      ],
    );
  }

  /// Minimal entry point into the multi-booking sheet (group seat / recurring
  /// claim / pack credit — docs/PROVIDER-UI-FOLLOWUPS.md #1). Only renders
  /// once the program is wired to a `serviceId` (the Provider-Model-Rebuild
  /// service, not this legacy "program"); hidden otherwise so nothing changes
  /// for today's demo data. Deliberately NOT part of the existing booking
  /// flow's write path — it opens a self-contained sheet with its own state.
  Widget _buildMultiBookingEntryPoint() {
    final serviceId = _program?['serviceId']?.toString();
    if (serviceId == null || serviceId.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => showMultiBookingSheet(
            context,
            providerId: _program?['providerRowId']?.toString() ?? '',
            serviceId: serviceId,
            serviceTitle: _sessionTitle,
          ),
          icon: const Icon(
            Icons.grid_view_rounded,
            size: 16,
            color: AppColors.slateText,
          ),
          label: Text(
            'More booking options',
            style: AppTypography.font(
              color: AppColors.slateText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
        ),
      ),
    );
  }

  // Build a booking from the user's selections and persist it so it appears on
  // Home "Coming Up" and the Schedule calendar.
  Future<void> _persistBooking() async {
    if (_bookingSaved && _realBookingId != null) return; // already created

    final now = DateTime.now();
    // The calendar shows the real current month, so use the selected date directly.
    final isoDate =
        '${_calYear.toString().padLeft(4, '0')}-${_calMonth.toString().padLeft(2, '0')}-${_selectedDay.toString().padLeft(2, '0')}T00:00:00.000Z';

    // Use the REAL session the user picked (carries a uuid _id) so the booking
    // attaches to it directly; fall back to a synthetic shape only if somehow
    // none was selected.
    final session =
        _selectedSession ??
        {
          '_id': 'sess_${now.millisecondsSinceEpoch}',
          'title': _sessionTitle,
          'startDate': isoDate,
          'date': isoDate,
          'startTime': _selectedTime,
          'programId': _program?['_id'],
        };

    final booking = <String, dynamic>{
      '_id': 'book_${now.millisecondsSinceEpoch}',
      'programId':
          _program, // full object so Home/Schedule resolve sport + coach
      'sessionId': session,
      'athleteId': _selectedAthleteId, // chosen child (RLS sets searcher_id)
      'athleteName': _selectedAthleteName, // denormalized display for provider
      // Booksy attribution — null when "Any available" is chosen. Recorded on
      // the booking; never affects price/charge. The name is denormalized so
      // the offline mock demo can display it without a join.
      if (_selectedTrainerId != null) 'assignedMemberId': _selectedTrainerId,
      if (_selectedTrainerName != null)
        'assignedTrainerName': _selectedTrainerName,
      'selectedTier': _tier,
      'originalPrice': _sessionPrice,
      'finalPrice': _total,
      'currency': 'USD',
      'status': 'pending',
      // Real payment happens via Stripe Checkout (#20b) — start unpaid.
      'paymentStatus': 'unpaid',
      if (_planProposalId != null) 'planProposalId': _planProposalId,
      'createdAt': now.toIso8601String(),
    };

    // addBooking rethrows the real PostgrestException on a DB failure so the
    // caller can show the exact reason instead of a generic message.
    final homeProvider = context.read<HomeProvider>();
    final id = await homeProvider.addBooking(booking);

    if (!mounted) return;
    // Re-read the persisted booking so paymentStatus reflects the backend.
    final saved = homeProvider.bookingById(id);
    setState(() {
      _realBookingId = id;
      _paymentStatus = (saved?['paymentStatus'] ?? 'unpaid').toString();
    });
    _bookingSaved = id != null; // only block re-create once it truly succeeded
  }

  /// THE payment moment ("Confirm & Pay"): create the UNPAID booking, then open
  /// Stripe hosted Checkout via the `stripe-create-checkout` Edge Function
  /// (invoke attaches the user's JWT). Non-2xx throws FunctionException — surface
  /// the real reason from its details instead of failing silently.
  Future<void> _handleConfirmAndPay() async {
    if (_checkoutLoading) return; // Prevent double-tap / double-submit
    final messenger = ScaffoldMessenger.of(context);
    // Defense-in-depth: never persist a booking without a chosen athlete, no
    // matter how this action is reached (the step-gate is not the only path).
    if (_selectedAthleteId == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _athletes.isEmpty
                ? 'Add a child in your profile before booking.'
                : 'Please select a child for this session.',
          ),
          backgroundColor: AppColors.negative,
        ),
      );
      return;
    }
    setState(() => _checkoutLoading = true);
    try {
      await _persistBooking();
      final id = _realBookingId;
      if (id == null) {
        // Not a DB exception (those rethrow + show below) — this means we
        // couldn't find a real, bookable session for this program.
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'No bookable session is available for this program yet.',
            ),
            backgroundColor: AppColors.negative,
          ),
        );
        return;
      }

      // OFFLINE DEMO (USE_MOCK_REPO): there is no Stripe backend — mark the
      // booking paid + confirmed and drive the in-app success screens end to
      // end (Getting Ready → Confirmed), instead of erroring on a live call.
      if (_useMockRepo) {
        if (!mounted) return;
        final home = context.read<HomeProvider>();
        await home.markBookingPaid(id);
        if (_planProposalId != null && mounted) {
          await context.read<AppRepository>().updateProposalStatus(
            _planProposalId!,
            'accepted',
          );
        }
        if (!mounted) return;
        setState(() {
          _paymentStatus = 'paid';
          _currentStep = 3;
        });
        await Future.delayed(const Duration(milliseconds: 1400));
        if (!mounted) return;
        setState(() => _currentStep = 4);
        return;
      }

      // Distinct return destinations so a completed payment and an abandoned
      // one are no longer indistinguishable (the old bug: both pointed at
      // Uri.base.origin, dumping the user at the app root with no confirmation).
      // Flutter web uses hash routing, so we return to a hash-route fragment the
      // app can read on launch. Success carries the booking id + status=success
      // (so the return handler can re-fetch paymentStatus and show Confirmed);
      // cancel returns to the flow with status=cancelled.
      final origin = Uri.base.origin;
      final successUrl =
          '$origin/#${AppRoutes.bookingFlow}?b=$id&status=success';
      final cancelUrl = '$origin/#${AppRoutes.bookingFlow}?status=cancelled';

      final res = await Supabase.instance.client.functions
          .invoke(
            'stripe-create-checkout',
            body: {
              'bookingId': id,
              'idempotencyKey': 'chk_$id',
              'successUrl': successUrl,
              'cancelUrl': cancelUrl,
            },
          )
          // Never let a slow/cold-starting edge function freeze the pay button
          // forever — fail after 20s with a retry message instead of an
          // infinite spinner (the classic "payment froze" complaint).
          .timeout(const Duration(seconds: 20));
      final data = (res.data as Map?) ?? {};
      if (data['error'] != null) {
        debugPrint('stripe-create-checkout ${data['error']}');
        messenger.showSnackBar(
          SnackBar(
            content: Text(data['error'].toString()),
            backgroundColor: AppColors.negative,
          ),
        );
        return;
      }
      final checkoutUrl = data['checkoutUrl'] as String?;
      if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
        await launchUrl(Uri.parse(checkoutUrl), webOnlyWindowName: '_self');
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not start checkout. Please try again.'),
            backgroundColor: AppColors.negative,
          ),
        );
      }
    } on FunctionException catch (e) {
      final d = e.details;
      final msg = (d is Map && d['error'] != null)
          ? d['error'].toString()
          : 'Payment error (status ${e.status})';
      debugPrint('FN stripe-create-checkout -> ${e.status} ${e.details}');
      messenger.showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.negative),
      );
    } on TimeoutException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Checkout is taking too long — please try again.'),
          backgroundColor: AppColors.negative,
        ),
      );
    } catch (e) {
      debugPrint('FN stripe-create-checkout -> $e');
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.negative),
      );
    } finally {
      if (mounted) setState(() => _checkoutLoading = false);
    }
  }

  final List<String> _timeSlots = [
    '09:00 AM',
    '10:30 AM',
    '11:30 AM',
    '12:00 PM',
    '01:00 PM',
    '02:30 PM',
    '04:00 PM',
    '05:30 PM',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildCurrentStepView(),
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar() {
    if (_currentStep == 3) {
      // Step 3 has custom close button / back button
      return AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: SporveIconButton(
            Icons.arrow_back,
            onTap: () {
              setState(() {
                _currentStep = 2;
              });
            },
          ),
        ),
      );
    }
    if (_currentStep == 4) {
      // Step 4 has close button on right
      return AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          SporveIconButton(
            Icons.close,
            onTap: () => Get.offAllNamed(AppRoutes.mainNav),
            color: AppColors.negative,
          ),
          const SizedBox(width: 16),
        ],
      );
    }

    // Step 1 and Step 2 AppBar
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: SporveIconButton(
          Icons.arrow_back,
          onTap: () {
            if (_currentStep == 2) {
              setState(() {
                _currentStep = 1;
              });
            } else {
              Get.back();
            }
          },
        ),
      ),
      title: Text(
        'STEP $_currentStep OF 2',
        style: AppTypography.font(
          color: AppColors.textTertiary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AppColors.hairline, height: 1),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 1:
        return _buildStep1BookSlot();
      case 2:
        return _buildStep2ReviewAndPay();
      case 3:
        return _buildStep3GettingReady();
      case 4:
        return _buildStep4Confirmed();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- STEP 1: BOOK SLOT ---
  Widget _buildStep1BookSlot() {
    return Column(
      key: const ValueKey(1),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Book Slot',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _buildChildSelector(),
                _buildTrainerPicker(),
                _buildSessionPicker(),
                _buildMultiBookingEntryPoint(),
                // Month header with prev/next navigation. Prev is disabled +
                // dimmed in the current month so users can't book in the past.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SporveIconButton(
                      Icons.arrow_back,
                      iconSize: 16,
                      onTap: _isCurrentMonth ? null : _prevMonth,
                      color: _isCurrentMonth
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                    ),
                    Text(
                      '${_monthNames[_calMonth - 1]} $_calYear',
                      style: AppTypography.font(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SporveIconButton(
                      Icons.arrow_forward,
                      iconSize: 16,
                      onTap: _nextMonth,
                      color: AppColors.textPrimary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Calendar Weekday Headers
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
                    return SizedBox(
                      width: 40,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: AppTypography.font(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                // Calendar Days Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: _leadingBlanks + _daysInMonth,
                  itemBuilder: (context, index) {
                    // Leading blank cells to align day 1 to the right weekday.
                    if (index < _leadingBlanks) return const SizedBox.shrink();
                    final day = index - _leadingBlanks + 1;
                    final now = DateTime.now();
                    final isPast =
                        _calYear == now.year &&
                        _calMonth == now.month &&
                        day < now.day;
                    final isSelected = _selectedDay == day;
                    return GestureDetector(
                      onTap: isPast
                          ? null
                          : () {
                              // The picked real session is the source of truth
                              // for the booking date. When one is selected,
                              // re-anchor to it so the displayed/persisted date
                              // can't diverge from the booked sessionId. Only
                              // allow free editing in the (fallback) no-session
                              // case.
                              if (_selectedSession != null) {
                                _selectSession(_selectedSession!);
                              } else {
                                setState(() {
                                  _selectedDay = day;
                                });
                              }
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected ? _sportColor : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$day',
                          style: AppTypography.font(
                            color: isPast
                                ? AppColors.textTertiary
                                : (isSelected
                                      ? SportColors.onColorOf(_sport)
                                      : AppColors.textPrimary),
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                Text(
                  'AVAILABLE TIMES',
                  style: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Time slots grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: _timeSlots.length,
                  itemBuilder: (context, index) {
                    final slot = _timeSlots[index];
                    final isSelected = _selectedTime == slot;
                    return GestureDetector(
                      onTap: () {
                        // Keep the time pinned to the real session's start
                        // (source of truth) so the booked slot always matches
                        // the chosen sessionId. Free editing only applies to
                        // the fallback no-session case.
                        if (_selectedSession != null) {
                          _selectSession(_selectedSession!);
                        } else {
                          setState(() {
                            _selectedTime = slot;
                          });
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected ? _sportColor : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.tile),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : AppColors.hairline,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          slot,
                          style: AppTypography.font(
                            // Contrast-correct on any sport color (white on dark
                            // sports, near-black on yellow/lime).
                            color: isSelected
                                ? SportColors.onColorOf(_sport)
                                : AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                Text(
                  'NOTES (OPTIONAL)',
                  style: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Notes Input Box
                TextField(
                  maxLines: 3,
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  cursorColor: AppColors.slateText,
                  decoration: InputDecoration(
                    hintText: 'Any goals, injuries, or special requests...',
                    hintStyle: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                      borderSide: const BorderSide(
                        color: AppColors.hairline,
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                      borderSide: const BorderSide(
                        color: AppColors.hairline,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                      borderSide: const BorderSide(
                        color: AppColors.slateBorder,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Step 1 Footer Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: const BoxDecoration(
            color: Colors.transparent,
            border: Border(
              top: BorderSide(color: AppColors.hairline, width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _money(_sessionPrice),
                      style: AppTypography.mono(
                        color: AppColors.textPrimary,
                        size: 26,
                        weight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '60 MIN',
                      style: AppTypography.mono(
                        color: AppColors.textTertiary,
                        size: 11,
                        weight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: SporveButton(
                    'Continue',
                    variant: SporveButtonVariant.primary,
                    color: _sportColor, // sport-context CTA carries sport color
                    onPressed: _onContinueFromStep1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- STEP 2: REVIEW & PAY ---
  Widget _buildStep2ReviewAndPay() {
    return Column(
      key: const ValueKey(2),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review & Pay',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // Details Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Date & Time Row
                      Row(
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(
                                AppRadii.tile,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.calendar_today,
                              color: AppColors.slateText,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DATE & TIME',
                                  style: AppTypography.font(
                                    color: AppColors.textTertiary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$_selectedDateLabel at $_selectedTime',
                                  style: AppTypography.mono(
                                    color: AppColors.textPrimary,
                                    weight: FontWeight.bold,
                                    size: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Divider(color: AppColors.hairline, height: 1),
                      ),

                      // Session Row
                      Row(
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              // Sport identity tile (the one exterior color on
                              // this screen) — sanctioned icon-tile, not chrome.
                              color: SportColors.tileTintOf(_sport),
                              borderRadius: BorderRadius.circular(
                                AppRadii.tile,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              SportColors.iconOf(_sport),
                              color: _sportColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SESSION',
                                  style: AppTypography.font(
                                    color: AppColors.textTertiary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _sessionTitle,
                                  style: AppTypography.font(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                if (_selectedTrainerName != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'with $_selectedTrainerName',
                                    style: AppTypography.font(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                Text(
                  'PAYMENT',
                  style: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Honest payment line: card entry happens on Stripe's hosted
                // checkout page, so we never show a fake in-app saved card here.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        color: AppColors.slateText,
                        size: 22,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Continue to Stripe checkout',
                              style: AppTypography.font(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "You'll enter your payment details on Stripe's hosted checkout page.",
                              style: AppTypography.font(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Cancellation Policy Block ──────────────────────────────
                // Shown at checkout so the parent knows the refund terms before
                // paying (Airbnb model). Policy comes from the program's
                // cancellationPolicy field ('flexible' | 'moderate' | 'strict').
                Builder(builder: (_) {
                  final policy = (_program?['cancellationPolicy'] as String? ??
                          'flexible')
                      .toLowerCase();
                  final (label, lines) = switch (policy) {
                    'strict' => (
                        'STRICT CANCELLATION',
                        [
                          '• Free cancellation ≥ 48 hours before the session',
                          '• 50% refund if cancelled < 48 hours before',
                          '• No refund if cancelled < 2 hours or no-show',
                        ]
                      ),
                    'moderate' => (
                        'MODERATE CANCELLATION',
                        [
                          '• Free cancellation ≥ 24 hours before the session',
                          '• 50% refund if cancelled < 24 hours before',
                          '• No refund if cancelled < 2 hours or no-show',
                        ]
                      ),
                    _ => (
                        'FLEXIBLE CANCELLATION',
                        [
                          '• Free cancellation up to 4 hours before the session',
                          '• 50% refund if cancelled < 4 hours before',
                          '• No refund for no-shows',
                        ]
                      ),
                  };
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.policy_outlined,
                              color: AppColors.slateText,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              label,
                              style: AppTypography.font(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...lines.map(
                          (line) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              line,
                              style: AppTypography.font(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // Secured by Stripe pad banner

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.slateTint,
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock,
                        color: AppColors.slateText,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Payment details are handled by Stripe. Your total is shown above.',
                          style: AppTypography.font(
                            color: AppColors.slateText,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Step 2 Footer button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.transparent,
            border: Border(
              top: BorderSide(color: AppColors.hairline, width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'By booking, you agree to Sporve\'s Terms of Service and the Coach Participation & Assumption of Risk Waiver for your athlete.',
                    textAlign: TextAlign.center,
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
                SporveButton(
                  'Confirm & Pay ${_money(_total)}',
                  variant: SporveButtonVariant.primary,
                  color: _sportColor, // sport-context CTA carries sport color
                  icon: Icons.lock_outline,
                  loading: _checkoutLoading,
                  // Guests can reach this screen and pick a slot, but PAYING requires
                  // an account. requireAuth shows the dismissible sign-in popup and,
                  // on sign-in, resumes _handleConfirmAndPay exactly once.
                  onPressed: _checkoutLoading
                      ? null
                      : () => context
                          .read<AuthProvider>()
                          .requireAuth(_handleConfirmAndPay),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- STEP 3: GETTING READY LOADER ---
  Widget _buildStep3GettingReady() {
    return Container(
      key: const ValueKey(3),
      width: double.infinity,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Circular progress ring spinner
          const SizedBox(
            height: 60,
            width: 60,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.slateText),
              strokeWidth: 4.5,
            ),
          ),
          const SizedBox(height: 32),

          Text(
            'GETTING YOU READY',
            style: AppTypography.font(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'PERSONALIZING YOUR SESSION',
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 48),

          // Coach message box card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Text(
              '"Arrive 10 minutes early to warm up and prepare mentally."',
              textAlign: TextAlign.center,
              style: AppTypography.font(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 4: CONFIRMED SCREEN ---
  Widget _buildStep4Confirmed() {
    return Container(
      key: const ValueKey(4),
      width: double.infinity,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(),

          // Large Check Icon
          Container(
            height: 72,
            width: 72,
            decoration: const BoxDecoration(
              color: AppColors.slateText,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.check, color: AppColors.onSlate, size: 36),
          ),
          const SizedBox(height: 32),

          Text(
            'Confirmed.',
            style: AppTypography.font(
              color: AppColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Locked Info Text
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppTypography.font(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
              children: [
                const TextSpan(text: 'Your slot is locked for '),
                TextSpan(
                  text: _selectedWeekday,
                  style: AppTypography.font(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const TextSpan(text: ' at '),
                TextSpan(
                  text: _selectedTime,
                  style: AppTypography.font(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Payment status line — only claim "charged" once actually paid.
          if (_paymentStatus == 'paid')
            Text(
              '${_money(_total)} paid',
              style: AppTypography.mono(
                color: AppColors.slateText,
                size: 12,
                weight: FontWeight.bold,
              ),
            ),

          const Spacer(),

          // Confirmed Page Buttons
          SporveButton(
            'Back to Home',
            variant: _paymentStatus == 'paid'
                ? SporveButtonVariant.primary
                : SporveButtonVariant.secondary,
            onPressed: () => Get.offAllNamed(AppRoutes.mainNav),
          ),
          const SizedBox(height: 12),
          SporveButton(
            'Add to Calendar',
            variant: SporveButtonVariant.secondary,
            icon: Icons.calendar_today_outlined,
            onPressed: _addToCalendar,
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
