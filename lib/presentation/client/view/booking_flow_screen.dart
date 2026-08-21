import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sporve_app/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/env.dart';
import '../../../core/data/app_repository.dart';
import '../../authentication/controllers/auth_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/session_time.dart';
import '../../../core/utils/provider_trust.dart';
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

enum _PaymentReturnState { none, processing, checkBack, cancelled, failed }

class _BookingFlowScreenState extends State<BookingFlowScreen>
    with WidgetsBindingObserver {
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
  bool _checkingPayment = false;
  _PaymentReturnState _paymentReturnState = _PaymentReturnState.none;

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

  // Calendar mirrors the selected real session. It is a view of server-backed
  // availability, never a client-side slot generator.
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

  String _sessionTimeLabel(Map<String, dynamic> session) {
    final raw = session['startTime']?.toString() ?? '';
    return raw.isNotEmpty ? raw : formatTime12h(parseSessionStart(session));
  }

  Map<String, dynamic>? _firstSessionOnCalendarDay(int day) {
    for (final session in _programSessions) {
      final start = parseSessionStart(session);
      if (start != null &&
          start.year == _calYear &&
          start.month == _calMonth &&
          start.day == day) {
        return session;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> get _sessionsOnSelectedDay {
    final matches = _programSessions.where((session) {
      final start = parseSessionStart(session);
      return start != null &&
          start.year == _calYear &&
          start.month == _calMonth &&
          start.day == _selectedDay;
    }).toList();
    matches.sort(
      (a, b) => parseSessionStart(a)!.compareTo(parseSessionStart(b)!),
    );
    return matches;
  }

  List<String> get _timeSlots => _sessionsOnSelectedDay
      .map(_sessionTimeLabel)
      .toSet()
      .toList(growable: false);

  Map<String, dynamic>? _sessionAtSelectedTime(String time) {
    for (final session in _sessionsOnSelectedDay) {
      if (_sessionTimeLabel(session) == time) return session;
    }
    return null;
  }

  // Booking context passed from the session-details screen.
  Map<String, dynamic>? _program;
  String _sessionTitle = 'Training Session';
  String _coach = 'Academy';

  // Concierge attribution (Prompt 3): when this booking is made by APPROVING a
  // plan_proposal, we store bookings.plan_proposal_id for attribution. The
  // signed Stripe webhook accepts the proposal only after verified payment.
  String? _planProposalId;
  Map<String, String> _initialPaymentReturn = const {};

  // Sport identity of the booked program — themes the sport-context CTAs,
  // selections, and icon tile with the sport's color (exterior accent). Generic
  // chrome stays slate.
  String get _sport => (_program?['sportType'] ?? 'basketball').toString();
  Color get _sportColor => SportColors.of(_sport);

  // Pricing — one provider-set price. D4 removed new booking tiers.
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
    WidgetsBinding.instance.addObserver(this);
    final now = DateTime.now();
    _calYear = now.year;
    _calMonth = now.month;
    _selectedDay = now.day;

    final args = Get.arguments;
    if (args is Map) {
      final paymentReturn = args['paymentReturn'];
      if (paymentReturn is Map) {
        _initialPaymentReturn = paymentReturn.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      }
      _program = args['program'] is Map
          ? Map<String, dynamic>.from(args['program'])
          : null;
      _sessionTitle = (args['title'] ?? _program?['title'] ?? _sessionTitle)
          .toString();
      _coach = (args['coach'] ?? _coach).toString();
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _realBookingId != null &&
        _paymentStatus != 'paid') {
      _pollPaymentStatus(_realBookingId!);
    }
  }

  /// Stripe Checkout return handler (web). After a payment the browser lands
  /// back on a hash-route fragment like `…/#/booking-flow?b=<id>&status=success`
  /// (set as successUrl in [_handleConfirmAndPay]). Read that fragment and, on a
  /// success return, re-fetch the booking's paymentStatus and jump straight to
  /// the Confirmed step (Step 4) instead of sitting on unpaid/pending — the fix
  /// for "I paid but nothing happened". A cancel return just leaves the user in
  /// the flow to retry; the booking stays unpaid.
  ///
  Future<void> _handleStripeReturn() async {
    final params = _initialPaymentReturn.isNotEmpty
        ? _initialPaymentReturn
        : kIsWeb
        ? (Uri.tryParse(Uri.base.fragment)?.queryParameters ?? const {})
        : Uri.base.queryParameters;
    final status = params['status'];
    final bookingId = params['b'];
    if (bookingId == null || bookingId.isEmpty) return;
    if (status == 'cancelled') {
      if (!mounted) return;
      setState(() {
        _realBookingId = bookingId;
        _bookingSaved = true;
        _currentStep = 2;
        _paymentReturnState = _PaymentReturnState.cancelled;
      });
      return;
    }
    if (status != 'success') return;
    if (!mounted) return;
    setState(() {
      _realBookingId = bookingId;
      _bookingSaved = true;
      _currentStep = 3;
      _paymentReturnState = _PaymentReturnState.processing;
    });
    await _pollPaymentStatus(bookingId);
  }

  Future<void> _pollPaymentStatus(String bookingId) async {
    if (_checkingPayment) return;
    _checkingPayment = true;
    try {
      const delays = [
        Duration.zero,
        Duration(milliseconds: 700),
        Duration(seconds: 2),
      ];
      for (final delay in delays) {
        if (delay > Duration.zero) await Future<void>.delayed(delay);
        if (!mounted) return;
        final rows = await context.read<AppRepository>().getBookingsOrThrow();
        Map<String, dynamic>? saved;
        for (final row in rows) {
          if (row is Map && row['_id']?.toString() == bookingId) {
            saved = Map<String, dynamic>.from(row);
            break;
          }
        }
        final status = saved?['paymentStatus']?.toString() ?? 'processing';
        if (!mounted) return;
        setState(() {
          _paymentStatus = status;
          if (saved != null) _hydrateFromPersistedBooking(saved);
        });
        if (status == 'paid') {
          await context.read<HomeProvider>().fetchBookings();
          if (!mounted) return;
          setState(() {
            _paymentReturnState = _PaymentReturnState.none;
            _currentStep = 4;
          });
          return;
        }
        if (status == 'failed') {
          setState(() {
            _paymentReturnState = _PaymentReturnState.failed;
            _currentStep = 2;
          });
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _currentStep = 3;
        _paymentReturnState = _PaymentReturnState.checkBack;
      });
    } catch (error) {
      debugPrint('payment status refresh failed: $error');
      if (!mounted) return;
      setState(() {
        _currentStep = 3;
        _paymentReturnState = _PaymentReturnState.checkBack;
      });
    } finally {
      if (mounted) {
        setState(() => _checkingPayment = false);
      } else {
        _checkingPayment = false;
      }
    }
  }

  void _hydrateFromPersistedBooking(Map<String, dynamic> booking) {
    final session = booking['sessionId'];
    if (session is Map) {
      final row = Map<String, dynamic>.from(session);
      _selectedSession = row;
      _sessionTitle = (row['title'] ?? _sessionTitle).toString();
      final start = parseSessionStart(row);
      if (start != null) {
        _calYear = start.year;
        _calMonth = start.month;
        _selectedDay = start.day;
        _selectedTime =
            (row['startTime']?.toString().trim().isNotEmpty ?? false)
            ? row['startTime'].toString()
            : formatTime12h(start);
      }
    }
    final program = booking['programId'];
    if (program is Map) {
      _program = Map<String, dynamic>.from(program);
      _coach = (_program?['providerName'] ?? _program?['coachName'] ?? _coach)
          .toString();
    }
    final recordedPrice = booking['finalPrice'] ?? booking['totalAmount'];
    if (recordedPrice is num) _sessionPrice = recordedPrice.toDouble();
    _selectedAthleteName =
        booking['athleteName']?.toString() ?? _selectedAthleteName;
    _selectedTrainerName =
        booking['assignedTrainerName']?.toString() ?? _selectedTrainerName;
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
    if (start == null) {
      if (notify) _snack('This session time is unavailable. Choose another.');
      return;
    }
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

    if (_program == null || !providerTrusted(_program!)) {
      _snack(
        'Bookings are paused until this coach completes approval and their background check.',
      );
      return;
    }

    // QA Day 07: 1:1 Coaching requires selecting a named trainer (never "Any available")
    final isOneOnOne =
        (_program?['pricingModel'] ?? '').toString() == 'single_session';
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
    final isOneOnOne =
        (_program?['pricingModel'] ?? '').toString() == 'single_session';
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
                  backgroundImage: photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
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
            final label = start == null
                ? 'Date unavailable'
                : '${_weekdayNames[start.weekday - 1]}, '
                      '${_monthNames[start.month - 1].substring(0, 3)} ${start.day}';
            final time = _sessionTimeLabel(s);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: start == null ? null : () => _selectSession(s),
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

    final session = _selectedSession;
    if (session == null) {
      throw const RepositoryActionException(
        'Choose an available session before booking.',
      );
    }

    // Creation carries references only. The server owns the booking id, price,
    // currency, lifecycle status, payment status, and creation timestamp.
    final booking = <String, dynamic>{
      'programId':
          _program, // full object so Home/Schedule resolve sport + coach
      'sessionId': session,
      'athleteId': _selectedAthleteId, // chosen child (RLS sets searcher_id)
      // Booksy attribution — null when "Any available" is chosen. The server
      // validates the member and derives any display name.
      if (_selectedTrainerId != null) 'assignedMemberId': _selectedTrainerId,
      if (_planProposalId != null) 'planProposalId': _planProposalId,
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

  /// THE payment moment ("Confirm & Pay"): create the UNPAID booking, then ask
  /// the repository for a Stripe-hosted Checkout URL. The client sends no amount
  /// and never writes payment status.
  Future<void> _handleConfirmAndPay() async {
    if (_checkoutLoading) return; // Prevent double-tap / double-submit
    final messenger = ScaffoldMessenger.of(context);
    final repository = context.read<AppRepository>();
    if (_program == null || !providerTrusted(_program!)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'This provider is not currently eligible for paid bookings.',
          ),
          backgroundColor: AppColors.negative,
        ),
      );
      return;
    }
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

      final Uri successUrl;
      final Uri cancelUrl;
      if (kIsWeb) {
        final origin = Uri.parse(Uri.base.origin);
        successUrl = origin.replace(
          fragment: '${AppRoutes.bookingFlow}?b=$id&status=success',
        );
        cancelUrl = origin.replace(
          fragment: '${AppRoutes.bookingFlow}?b=$id&status=cancelled',
        );
      } else {
        final base = Uri.tryParse(Env.checkoutReturnUrl);
        if (base == null || base.scheme != 'https' || base.host.isEmpty) {
          throw const RepositoryActionException(
            'Mobile checkout return is not configured. No charge was started.',
          );
        }
        successUrl = base.replace(
          queryParameters: {
            ...base.queryParameters,
            'b': id,
            'status': 'success',
          },
        );
        cancelUrl = base.replace(
          queryParameters: {
            ...base.queryParameters,
            'b': id,
            'status': 'cancelled',
          },
        );
      }

      final checkoutUrl = await repository.createBookingCheckout(
        bookingId: id,
        successUrl: successUrl,
        cancelUrl: cancelUrl,
      );
      final launched = await launchUrl(
        checkoutUrl,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        webOnlyWindowName: kIsWeb ? '_self' : null,
      );
      if (!launched) {
        throw const RepositoryActionException(
          'Stripe Checkout could not open. Please try again.',
        );
      }
    } on RepositoryActionException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.negative),
      );
    } catch (e) {
      debugPrint('create booking checkout -> $e');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Payment could not be started. Please try again.'),
          backgroundColor: AppColors.negative,
        ),
      );
    } finally {
      if (mounted) setState(() => _checkoutLoading = false);
    }
  }

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
            semanticLabel: 'Back',
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
            semanticLabel: 'Close booking',
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
          semanticLabel: 'Back',
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
                // Dates, times, and notes are meaningful only after the server
                // has returned a real session. An empty program must not show
                // fabricated availability that the booking write will reject.
                if (_programSessions.isNotEmpty &&
                    _selectedSession != null) ...[
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      '${_monthNames[_calMonth - 1]} $_calYear',
                      style: AppTypography.font(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
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
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                    itemCount: _leadingBlanks + _daysInMonth,
                    itemBuilder: (context, index) {
                      // Leading blank cells to align day 1 to the right weekday.
                      if (index < _leadingBlanks) {
                        return const SizedBox.shrink();
                      }
                      final day = index - _leadingBlanks + 1;
                      final session = _firstSessionOnCalendarDay(day);
                      final isAvailable = session != null;
                      final isSelected = _selectedDay == day;
                      return GestureDetector(
                        onTap: session == null
                            ? null
                            : () => _selectSession(session),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _sportColor
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$day',
                            style: AppTypography.font(
                              color: isSelected
                                  ? SportColors.onColorOf(_sport)
                                  : (isAvailable
                                        ? AppColors.textPrimary
                                        : AppColors.textTertiary),
                              fontSize: 14,
                              fontWeight: isSelected || isAvailable
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
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                    itemCount: _timeSlots.length,
                    itemBuilder: (context, index) {
                      final slot = _timeSlots[index];
                      final session = _sessionAtSelectedTime(slot);
                      final isSelected = _selectedTime == slot;
                      return GestureDetector(
                        onTap: session == null
                            ? null
                            : () => _selectSession(session),
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
                    onPressed:
                        _programSessions.isEmpty || _selectedSession == null
                        ? null
                        : _onContinueFromStep1,
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
                Builder(
                  builder: (_) {
                    final policy =
                        (_program?['cancellationPolicy'] as String? ??
                                'flexible')
                            .toLowerCase();
                    final (label, lines) = switch (policy) {
                      'strict' => (
                        'STRICT CANCELLATION',
                        [
                          '• Free cancellation ≥ 48 hours before the session',
                          '• 50% refund if cancelled < 48 hours before',
                          '• No refund if cancelled < 2 hours or no-show',
                        ],
                      ),
                      'moderate' => (
                        'MODERATE CANCELLATION',
                        [
                          '• Free cancellation ≥ 24 hours before the session',
                          '• 50% refund if cancelled < 24 hours before',
                          '• No refund if cancelled < 2 hours or no-show',
                        ],
                      ),
                      _ => (
                        'FLEXIBLE CANCELLATION',
                        [
                          '• Free cancellation up to 4 hours before the session',
                          '• 50% refund if cancelled < 4 hours before',
                          '• No refund for no-shows',
                        ],
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
                  },
                ),

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

        if (_paymentReturnState == _PaymentReturnState.cancelled)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningTint,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(color: AppColors.warning),
            ),
            child: Text(
              'Checkout was cancelled. The booking is still unpaid and your slot is not confirmed.',
              style: AppTypography.font(
                color: AppColors.warning,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),

        if (_paymentReturnState == _PaymentReturnState.failed)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.negativeTint,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(color: AppColors.negative),
            ),
            child: Text(
              'Stripe reported that the payment failed. The booking remains unpaid; you can try again.',
              style: AppTypography.font(
                color: AppColors.negative,
                fontSize: 12,
                height: 1.4,
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
                  '${_bookingSaved ? 'Complete payment' : 'Confirm & Pay'} ${_money(_total)}',
                  variant: SporveButtonVariant.primary,
                  color: _sportColor, // sport-context CTA carries sport color
                  icon: Icons.lock_outline,
                  loading: _checkoutLoading,
                  // Guests can reach this screen and pick a slot, but PAYING requires
                  // an account. requireAuth shows the dismissible sign-in popup and,
                  // on sign-in, resumes _handleConfirmAndPay exactly once.
                  onPressed: _checkoutLoading
                      ? null
                      : () => context.read<AuthProvider>().requireAuth(
                          _handleConfirmAndPay,
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- STEP 3: PAYMENT WEBHOOK WAIT / CHECK-BACK ---
  Widget _buildStep3GettingReady() {
    final waiting = _paymentReturnState == _PaymentReturnState.processing;
    return Container(
      key: const ValueKey(3),
      width: double.infinity,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (waiting)
            const SizedBox(
              height: 60,
              width: 60,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.slateFg),
                strokeWidth: 4.5,
              ),
            )
          else
            const Icon(
              Icons.schedule_outlined,
              color: AppColors.warning,
              size: 60,
            ),
          const SizedBox(height: 32),

          Text(
            waiting ? 'Payment processing…' : 'Payment still processing',
            textAlign: TextAlign.center,
            style: AppTypography.font(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            waiting
                ? 'Waiting for Stripe to confirm the payment with Sporve.'
                : 'Stripe has not confirmed this booking yet. It remains unconfirmed until the server records payment.',
            textAlign: TextAlign.center,
            style: AppTypography.font(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (!waiting) ...[
            const SizedBox(height: 32),
            SporveButton(
              'Check payment status',
              onPressed: _realBookingId == null
                  ? null
                  : () {
                      setState(() {
                        _paymentReturnState = _PaymentReturnState.processing;
                      });
                      _pollPaymentStatus(_realBookingId!);
                    },
              loading: _checkingPayment,
            ),
            const SizedBox(height: 12),
            SporveButton(
              'Back to schedule',
              variant: SporveButtonVariant.secondary,
              onPressed: () => Get.offAllNamed(AppRoutes.mainNav),
            ),
          ],
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
