import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/sport_colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/motion_widgets.dart';
import '../../widgets/sport_glyph.dart';
import '../../widgets/sporve_button.dart';
import '../controllers/home_controller.dart';
import '../../../core/utils/session_time.dart';

class AthleteSession {
  final DateTime date;
  final String emoji;
  final String time;
  final String location;
  final String title;
  final String subtitle;
  final String? tip;
  final String? id; // booking _id (identity for rating/reviewed state)
  final Map<String, dynamic>? program; // resolved program (address/coords/etc.)

  const AthleteSession({
    required this.date,
    required this.emoji,
    required this.time,
    required this.location,
    required this.title,
    required this.subtitle,
    this.tip,
    this.id,
    this.program,
  });
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  String _selectedView = 'Month'; // Month, Week, Day
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();

  // Tracks past sessions the user has rated (by booking id).
  final Set<String> _reviewedIds = {};

  // Only dynamic sessions now
  final List<AthleteSession> _athleteSessions = [];
  // Populated each build with athlete + booked sessions; used for calendar dots.
  List<AthleteSession> _allSessions = [];

  int _getDaysInMonth(int year, int month) {
    if (month == 2) {
      if (((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0)) {
        return 29;
      }
      return 28;
    }
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month - 1];
  }

  String _formatFullDate(DateTime date) {
    final weekdays = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];

    // Convert weekday so index 0 = Sunday, 1 = Monday, etc.
    final int dayOfWeekIndex = date.weekday == 7 ? 0 : date.weekday;
    final weekdayStr = weekdays[dayOfWeekIndex];

    final String monthStr;
    switch (date.month) {
      case 1:
        monthStr = 'January';
        break;
      case 2:
        monthStr = 'February';
        break;
      case 3:
        monthStr = 'March';
        break;
      case 4:
        monthStr = 'April';
        break;
      case 5:
        monthStr = 'May';
        break;
      case 6:
        monthStr = 'June';
        break;
      case 7:
        monthStr = 'July';
        break;
      case 8:
        monthStr = 'August';
        break;
      case 9:
        monthStr = 'September';
        break;
      case 10:
        monthStr = 'October';
        break;
      case 11:
        monthStr = 'November';
        break;
      case 12:
        monthStr = 'December';
        break;
      default:
        monthStr = '';
    }

    return '$weekdayStr, $monthStr ${date.day}, ${date.year}';
  }

  // Returns a sport *name* (not an emoji). SportGlyph maps it to a line icon.
  String _getSportEmoji(String? sportType) {
    if (sportType == null) return 'running';
    return sportType;
  }

  String _formatMonthHeader(DateTime date) {
    final String monthStr;
    switch (date.month) {
      case 1:
        monthStr = 'January';
        break;
      case 2:
        monthStr = 'February';
        break;
      case 3:
        monthStr = 'March';
        break;
      case 4:
        monthStr = 'April';
        break;
      case 5:
        monthStr = 'May';
        break;
      case 6:
        monthStr = 'June';
        break;
      case 7:
        monthStr = 'July';
        break;
      case 8:
        monthStr = 'August';
        break;
      case 9:
        monthStr = 'September';
        break;
      case 10:
        monthStr = 'October';
        break;
      case 11:
        monthStr = 'November';
        break;
      case 12:
        monthStr = 'December';
        break;
      default:
        monthStr = '';
    }
    return '$monthStr ${date.year}';
  }

  void _prevMonth() {
    setState(() {
      int prevMonth = _currentMonth.month - 1;
      int prevYear = _currentMonth.year;
      if (prevMonth == 0) {
        prevMonth = 12;
        prevYear -= 1;
      }
      _currentMonth = DateTime(prevYear, prevMonth);
    });
  }

  void _nextMonth() {
    setState(() {
      int nextMonth = _currentMonth.month + 1;
      int nextYear = _currentMonth.year;
      if (nextMonth == 13) {
        nextMonth = 1;
        nextYear += 1;
      }
      _currentMonth = DateTime(nextYear, nextMonth);
    });
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();

    // Map backend bookings to AthleteSession objects (cancelled ones drop out
    // of the active set — they get their own Cancelled section below).
    bool isCancelled(dynamic b) {
      final s = (b is Map ? b['status'] : null)?.toString().toLowerCase();
      return s == 'cancelled' || s == 'canceled';
    }

    final List<AthleteSession> dynamicSessions = homeProvider.bookings
        .where((b) => !isCancelled(b))
        .map((booking) => _mapBookingToSession(booking, homeProvider))
        .toList();

    // Cancelled bookings — surfaced separately with a Book again path (§16).
    final List<AthleteSession> cancelledSessions =
        homeProvider.bookings
            .where(isCancelled)
            .map((booking) => _mapBookingToSession(booking, homeProvider))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    // Merge with static sessions for demo or use only dynamic
    final allSessions = [..._athleteSessions, ...dynamicSessions];
    // Cache so the calendar builder methods can show day dots for real bookings.
    _allSessions = allSessions;

    // Past sessions for the Archive & Rebook section (real data, newest first).
    final pastSessions =
        allSessions.where((s) => s.date.isBefore(DateTime.now())).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    final daySessions = allSessions
        .where(
          (s) =>
              s.date.year == _selectedDate.year &&
              s.date.month == _selectedDate.month &&
              s.date.day == _selectedDate.day,
        )
        .toList();

    return GradientScaffold(
      body: SafeArea(
        bottom: false,
        child: homeProvider.isLoadingBookings
            ? const Padding(
                padding: EdgeInsets.only(top: 24),
                child: SkeletonList(count: 4),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. HEADER SECTION
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Schedule',
                            style: AppTypography.font(
                              color: AppColors.textPrimary,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'UPCOMING & PAST SESSIONS',
                            style: AppTypography.font(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. TOGGLE BAR
                    _buildViewToggle(),

                    const SizedBox(height: 16),

                    // 3. CALENDAR CONTENT (BASED ON TOGGLE STATE)
                    if (_selectedView == 'Month')
                      _buildMonthCalendar()
                    else if (_selectedView == 'Week')
                      _buildWeekCalendar()
                    else
                      _buildDayHeader(),

                    const SizedBox(height: 24),

                    // 4. SELECTED DATE SESSIONS HEADER
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'SESSIONS ON THIS DAY (${daySessions.length})',
                        style: AppTypography.font(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Sessions list
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: daySessions.isEmpty
                          ? const EmptyState(
                              icon: Icons.event_available_outlined,
                              title: 'Nothing scheduled',
                              message: 'No sessions booked for this date.',
                            )
                          : Column(
                              children: daySessions.map((session) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildUpcomingCard(session),
                                );
                              }).toList(),
                            ),
                    ),

                    const SizedBox(height: 32),

                    // 5. ARCHIVE SECTION (Rate past sessions, static consistent UI)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'ARCHIVE & REBOOK',
                        style: AppTypography.font(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: pastSessions.isEmpty
                          ? const EmptyState(
                              icon: Icons.history,
                              title: 'No past sessions yet',
                              message:
                                  'Completed sessions will appear here to rate and rebook.',
                            )
                          : Column(
                              children: [
                                _buildRebookBanner(pastSessions.first),
                                const SizedBox(height: 16),
                                ...pastSessions.map(
                                  (session) => Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _buildPastSessionCard(
                                      emoji: session.emoji,
                                      title: session.title,
                                      subtext:
                                          '${_pastLabel(session.date)} • ${session.subtitle.toUpperCase()}',
                                      footer: _pastFooter(session),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),

                    // 6. CANCELLED SECTION (only when there are cancelled bookings)
                    if (cancelledSessions.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'CANCELLED',
                          style: AppTypography.font(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: cancelledSessions
                              .map(
                                (session) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildPastSessionCard(
                                    emoji: session.emoji,
                                    title: session.title,
                                    subtext:
                                        'CANCELLED • ${session.subtitle.toUpperCase()}',
                                    footer: _cancelledFooter(session),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],

                    const SizedBox(height: 120), // bottom space overlay
                  ],
                ),
              ),
      ),
    );
  }

  // Cancelled-card action: the only forward path is to book the program again.
  Widget _cancelledFooter(AthleteSession session) {
    return Row(
      children: [
        Expanded(
          child: _cardTextAction(
            'Book again',
            AppColors.slateText,
            () => _bookAgain(session),
          ),
        ),
      ],
    );
  }

  // Resolve one backend booking into an AthleteSession (shared by the active
  // and cancelled lists). programId may be a full object or an id string.
  AthleteSession _mapBookingToSession(Map booking, HomeProvider homeProvider) {
    final session = booking['sessionId'] is Map ? booking['sessionId'] : null;

    final rawBookingProgram = booking['programId'];
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
      for (final p in homeProvider.programs) {
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
    final address = program?['address'];

    return AthleteSession(
      date: startTime,
      emoji: program != null
          ? _getSportEmoji(program['sportType']?.toString())
          : 'running',
      time: formatTime12h(startTime),
      location:
          (address is Map ? address['city']?.toString() : null) ?? 'Location',
      title: program?['title']?.toString() ?? 'Session',
      subtitle: (program?['providerId'] is Map)
          ? (program!['providerId']['businessName']?.toString() ?? 'COACH')
          : 'COACH',
      id: booking['_id']?.toString(),
      program: program != null ? Map<String, dynamic>.from(program) : null,
    );
  }

  // Segmented Sliding Choice Selector
  Widget _buildViewToggle() {
    const views = ['Month', 'Week', 'Day'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: SporveSegmented(
        segments: const ['MONTH', 'WEEK', 'DAY'],
        selected: views.indexOf(_selectedView),
        onChanged: (i) => setState(() => _selectedView = views[i]),
      ),
    );
  }

  // Calendar session dot inherits the sport color of that day's session
  // (first match); falls back to slate when the sport is unmapped/none.
  Color _sportDotColor(DateTime date) {
    for (final s in _allSessions) {
      if (s.date.year == date.year &&
          s.date.month == date.month &&
          s.date.day == date.day) {
        return SportColors.of(s.program?['sportType']?.toString() ?? s.emoji);
      }
    }
    return AppColors.slateText;
  }

  // 1. Month Calendar Component (matches Provider's schedule layout)
  Widget _buildMonthCalendar() {
    int daysInMonth = _getDaysInMonth(_currentMonth.year, _currentMonth.month);
    int firstWeekday = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    ).weekday;
    int offset = firstWeekday == 7 ? 0 : firstWeekday;
    int totalCells = daysInMonth + offset;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          // Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SporveIconButton(
                Icons.arrow_back,
                onTap: _prevMonth,
                size: 32,
                iconSize: 16,
              ),
              Text(
                _formatMonthHeader(_currentMonth),
                style: AppTypography.font(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SporveIconButton(
                Icons.arrow_forward,
                onTap: _nextMonth,
                size: 32,
                iconSize: 16,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // SUN-SAT weekdays title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'].map((
              day,
            ) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Days Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // Fixed cell height (decoupled from width) so day cells never
            // overflow at any viewport width — day circle (34) + gap (4) + dot
            // (4) = 42px fits inside 56.
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 12,
              crossAxisSpacing: 8,
              mainAxisExtent: 56,
            ),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              if (index < offset) {
                return const SizedBox.shrink();
              }
              final dayNum = index - offset + 1;
              final cellDate = DateTime(
                _currentMonth.year,
                _currentMonth.month,
                dayNum,
              );
              final isSelected =
                  _selectedDate.year == cellDate.year &&
                  _selectedDate.month == cellDate.month &&
                  _selectedDate.day == cellDate.day;

              final hasSessions = _allSessions.any(
                (s) =>
                    s.date.year == cellDate.year &&
                    s.date.month == cellDate.month &&
                    s.date.day == cellDate.day,
              );

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = cellDate;
                  });
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.slateText
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                      ),
                      child: Text(
                        '$dayNum',
                        style: AppTypography.mono(
                          color: isSelected
                              ? AppColors.onSlate
                              : AppColors.textPrimary,
                          weight: FontWeight.bold,
                          size: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (hasSessions)
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.onSlate
                              : _sportDotColor(cellDate),
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const SizedBox(height: 4),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          _buildSelectedDatePanel(),
        ],
      ),
    );
  }

  // 2. Week Calendar Component (horizontal single-week day chips)
  Widget _buildWeekCalendar() {
    final int difference = _selectedDate.weekday == 7
        ? 0
        : _selectedDate.weekday;
    final DateTime sunday = _selectedDate.subtract(Duration(days: difference));
    final List<DateTime> weekDays = List.generate(
      7,
      (i) => sunday.add(Duration(days: i)),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekDays.map((date) {
              final List<String> shortDays = [
                'SUN',
                'MON',
                'TUE',
                'WED',
                'THU',
                'FRI',
                'SAT',
              ];
              final String dayLabel =
                  shortDays[date.weekday == 7 ? 0 : date.weekday];
              final bool isSelected =
                  date.year == _selectedDate.year &&
                  date.month == _selectedDate.month &&
                  date.day == _selectedDate.day;

              final hasSessions = _allSessions.any(
                (s) =>
                    s.date.year == date.year &&
                    s.date.month == date.month &&
                    s.date.day == date.day,
              );

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                      _currentMonth = DateTime(date.year, date.month);
                    });
                  },
                  child: Column(
                    children: [
                      Text(
                        dayLabel,
                        style: AppTypography.font(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.slateText
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadii.tile),
                        ),
                        child: Text(
                          '${date.day}',
                          style: AppTypography.mono(
                            color: isSelected
                                ? AppColors.onSlate
                                : AppColors.textPrimary,
                            weight: FontWeight.bold,
                            size: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (hasSessions)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.onSlate
                                : _sportDotColor(date),
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(height: 4),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _buildSelectedDatePanel(),
        ],
      ),
    );
  }

  // 3. Collapsed Day View Header (collapses calendar grid entirely)
  Widget _buildDayHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: _buildSelectedDatePanel(),
    );
  }

  Widget _buildSelectedDatePanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadii.tile),
      ),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELECTED DATE',
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatFullDate(_selectedDate),
            style: AppTypography.font(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // FIGMA UPCOMING SESSION CARD
  Widget _buildUpcomingCard(AthleteSession session) {
    final emoji = session.emoji;
    final time = session.time;
    final location = session.location;
    final title = session.title;
    final subtitle = session.subtitle;
    final tip = session.tip;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row (Sport glyph & Time info)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sport glyph tile — sport-tinted base + sport-color glyph.
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: SportColors.tileTintOf(emoji),
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                ),
                alignment: Alignment.center,
                child: SportGlyph(
                  emoji,
                  size: 22,
                  color: SportColors.of(emoji),
                ),
              ),
              // Time & Location
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    time,
                    style: AppTypography.mono(
                      color: AppColors.textPrimary,
                      size: 22,
                      weight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    location,
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Session Title
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.font(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          // Coach subtitle
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),

          // Optional Coach Tip Box (coach = social/relationship → blue)
          if (tip != null) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.blueTint,
                borderRadius: BorderRadius.circular(AppRadii.tile),
                border: Border.all(
                  color: AppColors.blue.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COACH TIP',
                    style: AppTypography.font(
                      color: AppColors.blueText,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '"$tip"',
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Bottom Row (Buttons)
          Row(
            children: [
              // GET DIRECTIONS Button
              Expanded(
                child: SporveButton(
                  'Get directions',
                  onPressed: () => _openDirections(session),
                  variant: SporveButtonVariant.primary,
                ),
              ),
              const SizedBox(width: 12),
              // Message Icon Button — opens the chat with this coach/provider.
              SporveIconButton(
                Icons.chat_bubble_outline,
                onTap: () => Get.toNamed(
                  AppRoutes.chatDetails,
                  arguments: {'contactName': subtitle},
                ),
                size: 50,
                iconSize: 20,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Reschedule / Cancel — the previously-absent booking management.
          Row(
            children: [
              Expanded(
                child: _cardTextAction(
                  'Reschedule',
                  AppColors.slateText,
                  () => _reschedule(session),
                ),
              ),
              Container(width: 1, height: 16, color: AppColors.hairline),
              Expanded(
                child: _cardTextAction(
                  'Cancel',
                  AppColors.destructiveRed,
                  () => _confirmCancel(session),
                ),
              ),
            ],
          ),
          // "Report no-show" — only visible after the session start time has
          // passed, giving the parent a guaranteed-refund path if the coach
          // didn't appear.
          if (session.date.isBefore(DateTime.now())) ...[
            const SizedBox(height: 4),
            Center(
              child: _cardTextAction(
                '⚑  Report coach no-show',
                AppColors.destructiveRed,
                () => _reportNoShow(session),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cardTextAction(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            label,
            style: AppTypography.font(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmSheet(
    String title,
    String body,
    String confirmLabel,
    Color confirmColor,
  ) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        title: Text(
          title,
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          body,
          style: AppTypography.font(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Keep it',
              style: AppTypography.font(color: AppColors.slateText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmLabel,
              style: AppTypography.font(
                color: confirmColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Future<void> _confirmCancel(AthleteSession session) async {
    final policy =
        (session.program?['cancellationPolicy'] as String? ?? 'flexible')
            .toLowerCase();
    final now = DateTime.now();
    final hoursLeft = session.date.difference(now).inHours;

    String refundEstimate;
    if (policy == 'strict') {
      if (hoursLeft >= 48) {
        refundEstimate = 'Full refund (100%)';
      } else if (hoursLeft >= 2) {
        refundEstimate = 'Partial refund (50%)';
      } else {
        refundEstimate = 'No refund (< 2 hours before start)';
      }
    } else if (policy == 'moderate') {
      if (hoursLeft >= 24) {
        refundEstimate = 'Full refund (100%)';
      } else if (hoursLeft >= 2) {
        refundEstimate = 'Partial refund (50%)';
      } else {
        refundEstimate = 'No refund (< 2 hours before start)';
      }
    } else {
      // flexible
      if (hoursLeft >= 4) {
        refundEstimate = 'Full refund (100%)';
      } else if (hoursLeft >= 0) {
        refundEstimate = 'Partial refund (50%)';
      } else {
        refundEstimate = 'No refund (session already started)';
      }
    }

    final ok = await _confirmSheet(
      'Cancel session?',
      'This cancels "${session.title}".\n\n'
          '• Cancellation policy: ${policy.toUpperCase()}\n'
          '• Estimated refund: $refundEstimate\n\n'
          'You can book again anytime.',
      'Cancel session',
      AppColors.destructiveRed,
    );
    if (!ok || !mounted) return;
    final home = context.read<HomeProvider>();
    final done = session.id != null && await home.cancelBooking(session.id!);
    if (!mounted) return;
    Get.snackbar(
      done ? 'Cancelled' : 'Error',
      done
          ? 'Your session was cancelled. Refund status: $refundEstimate'
          : 'Could not cancel right now. Please try again.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.surface2,
      colorText: AppColors.textPrimary,
    );
  }

  /// Parent-side no-show report — shown after the session start time has
  /// passed and no completion was recorded. Guaranteed refund promise.
  Future<void> _reportNoShow(AthleteSession session) async {
    final ok = await _confirmSheet(
      'Report coach no-show?',
      'If your coach did not show up, we\'ll process a full refund automatically. '
          'Your report will be reviewed and the coach will be notified.',
      'Report no-show',
      AppColors.destructiveRed,
    );
    if (!ok || !mounted) return;
    // Cancel the booking (triggers refund path on the backend).
    final home = context.read<HomeProvider>();
    final done = session.id != null && await home.cancelBooking(session.id!);
    if (!mounted) return;
    Get.snackbar(
      done ? 'Report submitted' : 'Error',
      done
          ? 'We received your report. A full refund will be issued within 3–5 business days.'
          : 'Could not submit right now. Please contact support.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.surface2,
      colorText: AppColors.textPrimary,
      duration: const Duration(seconds: 5),
    );
  }

  Future<void> _reschedule(AthleteSession session) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadii.card),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          24 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Reschedule session',
              style: AppTypography.font(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your current slot is held until you cancel.\nChoose how you\'d like to move this session.',
              style: AppTypography.font(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            // Option 1: Cancel and pick a new time
            GestureDetector(
              onTap: () {
                Navigator.of(ctx).pop();
                // Cancel the existing booking, then open booking flow for
                // the same program with fresh date/time selection.
                if (session.id != null) {
                  context.read<HomeProvider>().cancelBooking(session.id!);
                }
                final program = session.program;
                if (program != null) {
                  final provider = program['providerId'];
                  final business = provider is Map
                      ? (provider['businessName']?.toString() ?? 'Academy')
                      : 'Academy';
                  Get.toNamed(
                    AppRoutes.bookingFlow,
                    arguments: {
                      'program': program,
                      'title': program['title']?.toString() ??
                          'Training Session',
                      'coach': business,
                      'tier': 'STANDARD',
                      'price': program['price'] ?? 75,
                    },
                  );
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pick a new time',
                            style: AppTypography.font(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Cancel your current slot and choose another date.',
                            style: AppTypography.font(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.slateText,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Option 2: Message the coach
            GestureDetector(
              onTap: () {
                Navigator.of(ctx).pop();
                Get.toNamed(
                  AppRoutes.chatDetails,
                  arguments: {'contactName': session.subtitle},
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Message the coach',
                            style: AppTypography.font(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Coordinate a new time directly without cancelling.',
                            style: AppTypography.font(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.slateText,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Keep current slot
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'Keep current time',
                  style: AppTypography.font(
                    color: AppColors.slateText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // FIGMA REBOOK BANNER
  Widget _buildRebookBanner(AthleteSession recent) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline, width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Circular Clock Icon
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: AppColors.slateTint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.history,
              color: AppColors.slateText,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          // Banner Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to rebook?',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Consistent athletes improve 40% faster. Book your next session.',
                  style: AppTypography.font(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Book Again Button
          SporveButton(
            'Book again',
            onPressed: () => _bookAgain(recent),
            variant: SporveButtonVariant.primary,
            size: SporveButtonSize.compact,
            fullWidth: false,
          ),
        ],
      ),
    );
  }

  // FIGMA PAST SESSION CARD
  // ALL-CAPS relative label for a past session date, matching the subtext style.
  String _pastLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final days = today.difference(d).inDays;
    if (days <= 0) return 'TODAY';
    if (days == 1) return 'YESTERDAY';
    if (days < 7) return '$days DAYS AGO';
    if (days < 14) return 'LAST WEEK';
    const m = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${m[dt.month - 1]} ${dt.day}';
  }

  Widget _buildPastSessionCard({
    required String emoji,
    required String title,
    required String subtext,
    required Widget footer,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline, width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Circular Icon Box
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: SportGlyph(
                  emoji,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 16),
              // Text Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtext,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.font(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Hairline(),
          const SizedBox(height: 4),
          footer,
        ],
      ),
    );
  }

  // Past-card actions (§16): Leave review / View session notes / Book again.
  // Once reviewed, the first action flips to a "Reviewed ★" indicator.
  Widget _pastFooter(AthleteSession session) {
    final reviewed = session.id != null && _reviewedIds.contains(session.id);
    return Row(
      children: [
        Expanded(
          child: reviewed
              ? _reviewedInline()
              : _cardTextAction(
                  'Leave review',
                  AppColors.slateText,
                  () => _openRatingSheet(session),
                ),
        ),
        Container(width: 1, height: 16, color: AppColors.hairline),
        Expanded(
          child: _cardTextAction(
            'Session notes',
            AppColors.slateText,
            () => Get.toNamed(AppRoutes.progressUpdates),
          ),
        ),
        Container(width: 1, height: 16, color: AppColors.hairline),
        Expanded(
          child: _cardTextAction(
            'Book again',
            AppColors.slateText,
            () => _bookAgain(session),
          ),
        ),
      ],
    );
  }

  // The "Reviewed ★" indicator shown once a past session has been rated.
  Widget _reviewedInline() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star, color: AppColors.textTertiary, size: 13),
          const SizedBox(width: 4),
          Text(
            'Reviewed',
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Button actions ────────────────────────────────────────────────────────

  // Opens Google Maps directions to the program's address/coords, else the
  // session's location string. HTTPS URL — no platform scheme config needed.
  Future<void> _openDirections(AthleteSession session) async {
    String destination = session.location;
    final program = session.program;
    if (program != null) {
      final address = program['address'];
      if (address is Map) {
        final parts = [
          address['line1'],
          address['city'],
          address['state'],
        ].where((p) => p != null && p.toString().trim().isNotEmpty).join(', ');
        if (parts.isNotEmpty) destination = parts;
      }
      // Prefer explicit coordinates when present (GeoJSON [lng, lat]).
      final loc = program['location'];
      if (loc is Map &&
          loc['coordinates'] is List &&
          (loc['coordinates'] as List).length >= 2) {
        final coords = loc['coordinates'] as List;
        destination = '${coords[1]},${coords[0]}'; // lat,lng
      }
    }
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  // Re-book the most recent past program: open the booking flow directly with
  // the same time slot pre-filled for next week (same weekday + same time),
  // so the user only needs to review and confirm — 2 taps total.
  void _bookAgain(AthleteSession recent) {
    final program = recent.program;
    if (program == null) {
      // No program data — fall back to discovery search.
      Get.toNamed(AppRoutes.search);
      return;
    }

    // "Same time next week": add 7 days to the original session date.
    final nextDate = recent.date.add(const Duration(days: 7));

    final provider = program['providerId'];
    final business = provider is Map
        ? (provider['businessName']?.toString() ?? 'Academy')
        : 'Academy';

    Get.toNamed(
      AppRoutes.bookingFlow,
      arguments: {
        'program': program,
        'title': program['title']?.toString() ?? 'Training Session',
        'coach': business,
        'tier': 'STANDARD',
        'price': program['price'] ?? 75,
        // Pre-fill calendar + time for "same time next week"
        'prefillDate': nextDate,
        'prefillTime': recent.time, // e.g. "10:30 AM"
      },
    );
  }



  // Rating sheet: 1–5 stars + optional note. On submit, marks the session
  // reviewed so the card flips to the "REVIEWED" block.
  void _openRatingSheet(AthleteSession session) {
    int rating = 5;
    final noteCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(top: BorderSide(color: AppColors.hairline)),
                ),
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
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Rate ${session.title}',
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: List.generate(5, (i) {
                        return GestureDetector(
                          onTap: () => setSheet(() => rating = i + 1),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              i < rating ? Icons.star : Icons.star_border,
                              color: AppColors.textPrimary,
                              size: 36,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 3,
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      cursorColor: AppColors.slateText,
                      decoration: InputDecoration(
                        hintText: 'Add a note (optional)…',
                        hintStyle: AppTypography.font(
                          color: AppColors.textTertiary,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: AppColors.surface2,
                        contentPadding: const EdgeInsets.all(14),
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
                    const SizedBox(height: 20),
                    SporveButton(
                      'Submit review',
                      onPressed: () {
                        if (session.id != null) {
                          setState(() => _reviewedIds.add(session.id!));
                        }
                        Navigator.pop(sheetCtx);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(noteCtrl.dispose);
  }
}
