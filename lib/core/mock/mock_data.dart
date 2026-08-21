import 'package:get_storage/get_storage.dart';

class MockData {
  static final GetStorage _box = GetStorage();

  // Bump when the seed data shape/content changes so existing installs re-seed.
  static const int _seedVersion = 5;

  static void init() {
    if (_box.read('mock_seed_version') != _seedVersion) {
      _box.write('mock_seed_version', _seedVersion);

      _box.write('mock_user_profile', {
        "_id": "user_123",
        "firstName": "Alex",
        "lastName": "Mercer",
        "email": "alex.mercer@gmail.com",
        "role": "searcher",
        "phoneNumber": "+1 (555) 019-2834",
        "preferredSports": ["Soccer", "Tennis"],
        "profileImage": "",
      });

      _box.write('mock_provider_profile', {
        "_id": "provider_123",
        "userId": "user_123",
        "businessName": "Apex Performance Club",
        "bio":
            "Dedicated sports academy providing elite training clinics for junior athletes.",
        "sports": ["Soccer", "Tennis", "Basketball"],
        "location": "Miami, FL",
        "status": "approved",
        "verificationStatus": "verified",
        "backgroundCheckStatus": "verified",
        "backgroundCheckCompletedAt": "2026-01-15T18:00:00.000Z",
        "onboardingCompleted": true,
        "stripeAccountId": "acct_mockstripe123",
      });

      _box.write('mock_athletes', [
        {
          "_id": "athlete_1",
          "firstName": "Julian",
          "lastName": "Mercer",
          "dateOfBirth": "2013-04-12T00:00:00.000Z",
          "gender": "male",
          "preferredSports": ["Soccer"],
          "medicalConditions": "None",
          "emergencyContact": {
            "name": "Alex Mercer",
            "phone": "+1 (555) 019-2834",
            "relation": "Father",
          },
          "profileImage": "",
        },
      ]);

      _box.write('mock_programs', [
        {
          "_id": "prog_1",
          "coverImage": "",
          "title": "Elite Soccer Academy - U12 Training",
          "description":
              "High-intensity technical training focusing on dribbling, passing, and match awareness.",
          "sportType": "Soccer",
          "skillLevel": "Intermediate",
          "ageGroup": "Youth (Under 12)",
          "language": "English",
          "price": 45.0,
          "currency": "USD",
          "pricingModel": "single_session",
          "maxCapacity": 15,
          "enrolledCount": 8,
          "gallery": <String>[],
          "whatsIncluded": [
            "Training Bibs",
            "Water Bottles",
            "Professional Coaching",
          ],
          "location": {
            "type": "Point",
            "coordinates": [-80.1918, 25.7617],
          },
          "address": {
            "line1": "123 Coral Way",
            "city": "Miami",
            "state": "FL",
            "zip": "33145",
            "country": "USA",
          },
          "cancellationPolicy": "moderate",
          "minimumAge": 9,
          "maximumAge": 12,
          "isFeatured": true,
          "status": "published",
          "averageRating": 4.8,
          "totalReviews": 12,
          "providerId": {
            "ownerId": "mock-provider-apex",
            "businessName": "Apex Performance Club",
            "verificationStatus": "verified",
            "backgroundCheckStatus": "verified",
            "status": "approved",
            "backgroundCheckCompletedAt": "2026-01-15T18:00:00.000Z",
          },
        },
        {
          "_id": "prog_2",
          "coverImage": "",
          "title": "Junior Tennis Clinic - All Levels",
          "description":
              "Learn basic and advanced tennis strokes, service, and court strategies from certified instructors.",
          "sportType": "Tennis",
          "skillLevel": "All Levels",
          "ageGroup": "Juniors (Under 16)",
          "language": "English",
          "price": 120.0,
          "currency": "USD",
          "pricingModel": "monthly",
          "maxCapacity": 8,
          "enrolledCount": 5,
          "gallery": <String>[],
          "whatsIncluded": ["Tennis Balls", "Racquet rentals"],
          "location": {
            "type": "Point",
            "coordinates": [-80.2000, 25.7700],
          },
          "address": {
            "line1": "450 Tennis Center Dr",
            "city": "Miami",
            "state": "FL",
            "zip": "33149",
            "country": "USA",
          },
          "cancellationPolicy": "strict",
          "minimumAge": 10,
          "maximumAge": 16,
          "isFeatured": false,
          "status": "published",
          "averageRating": 4.5,
          "totalReviews": 8,
          "providerId": {
            "ownerId": "mock-provider-racquet",
            "businessName": "Apex Performance Club",
            "verificationStatus": "verified",
            "backgroundCheckStatus": "verified",
            "status": "approved",
            "backgroundCheckCompletedAt": "2026-01-15T18:00:00.000Z",
          },
        },
        // Every business carries EXACTLY 5 published listings (uniform browse).
        ..._extraPrograms(),
      ]);

      _box.write('mock_sessions', [
        {
          "_id": "sess_1",
          "programId": "prog_1",
          "title": "Soccer Skill Session 1",
          "startDate": "2026-05-04T00:00:00.000Z",
          "endDate": "2026-05-04T00:00:00.000Z",
          "date": "2026-05-04T00:00:00.000Z",
          "startTime": "05:00 PM",
          "endTime": "06:30 PM",
          "timezone": "EST",
          "address": "123 Coral Way, Miami, FL",
        },
        {
          "_id": "sess_2",
          "programId": "prog_1",
          "title": "Soccer Skill Session 2",
          "startDate": "2026-05-06T00:00:00.000Z",
          "endDate": "2026-05-06T00:00:00.000Z",
          "date": "2026-05-06T00:00:00.000Z",
          "startTime": "05:00 PM",
          "endTime": "06:30 PM",
          "timezone": "EST",
          "address": "123 Coral Way, Miami, FL",
        },
        {
          "_id": "sess_3",
          "programId": "prog_2",
          "title": "Weekly Tennis Practice",
          "startDate": "2026-05-05T00:00:00.000Z",
          "endDate": "2026-05-05T00:00:00.000Z",
          "date": "2026-05-05T00:00:00.000Z",
          "startTime": "04:00 PM",
          "endTime": "05:30 PM",
          "timezone": "EST",
          "address": "450 Tennis Center Dr, Miami, FL",
        },
      ]);

      _box.write('mock_bookings', [
        {
          "_id": "book_1",
          "searcherId": "user_123",
          "athleteId": {
            "_id": "athlete_1",
            "fullName": "Julian Mercer",
            "profileImage": "",
          },
          "providerId": "provider_123",
          "programId": {
            "_id": "prog_1",
            "title": "Elite Soccer Academy - U12 Training",
          },
          "sessionId": {
            "_id": "sess_1",
            "title": "Soccer Skill Session 1",
            "date": "2026-05-04T00:00:00.000Z",
            "startTime": "05:00 PM",
            "programId": "prog_1",
          },
          "selectedTier": "Standard",
          "originalPrice": 45.0,
          "finalPrice": 45.0,
          "currency": "USD",
          "status": "confirmed",
          "paymentStatus": "paid",
          "createdAt": "2026-05-01T10:00:00.000Z",
        },
      ]);

      _box.write('mock_conversations', [
        {
          "_id": "conv_1",
          "participants": [
            {
              "_id": "user_123",
              "firstName": "Alex",
              "lastName": "Mercer",
              "role": "searcher",
            },
            {
              "_id": "provider_user_123",
              "firstName": "Apex Performance",
              "lastName": "Club",
              "role": "provider",
            },
          ],
          "programId": "prog_1",
          "lastMessage": {
            "_id": "msg_initial",
            "conversationId": "conv_1",
            "text": "Hello, thank you for booking! See you on Monday.",
            "senderId": "provider_user_123",
            "createdAt": "2026-05-01T10:05:00.000Z",
          },
        },
      ]);

      _box.write('mock_messages_conv_1', [
        {
          "_id": "msg_1",
          "conversationId": "conv_1",
          "text":
              "Hi, I just booked the soccer session for Julian. Does he need to bring his own ball?",
          "senderId": "user_123",
          "createdAt": "2026-05-01T10:02:00.000Z",
        },
        {
          "_id": "msg_initial",
          "conversationId": "conv_1",
          "text":
              "Hello, thank you for booking! See you on Monday. We will provide training bibs and soccer balls, but he is welcome to bring his own.",
          "senderId": "provider_user_123",
          "createdAt": "2026-05-01T10:05:00.000Z",
        },
      ]);

      _box.write('mock_notifications', [
        {
          "_id": "notif_1",
          "title": "Booking Confirmed",
          "message":
              "Your booking for Soccer Skill Session 1 has been confirmed.",
          "isRead": false,
          "createdAt": "2026-05-01T10:00:00.000Z",
        },
      ]);

      _box.write('mock_teams', [
        {
          "_id": "team_1",
          "name": "Miami Elite Soccer U12",
          "sport": "Soccer",
          "roster": [
            {
              "_id": "athlete_1",
              "fullName": "Julian Mercer",
              "email": "alex.mercer@gmail.com",
              "jerseyNumber": "10",
              "avatar": "",
              "isAvailable": true,
              "isPaid": true,
            },
          ],
        },
      ]);

      _box.write('mock_favorites', <String>[]);

      // A coach-authored, SENT progress update so the parent view has real
      // content out of the box (childId matches the seeded athlete_1).
      _box.write('mock_parent_updates', [
        {
          'id': 'pu_seed_1',
          'childId': 'athlete_1',
          'summaryBody':
              'Julian had a focused session working on first touch and passing under pressure. Great energy from start to finish.',
          'skillsWorked': ['First touch', 'Passing', 'Spatial awareness'],
          'progressSignal': 'building consistency',
          'practiceSuggestions': ['10 minutes of wall passes, 3x this week'],
          'encouragement':
              'Keep it up, Julian — your close control is really coming along!',
          'status': 'sent',
          'createdAt': '2026-05-04T18:00:00.000Z',
          'sentAt': '2026-05-04T18:05:00.000Z',
        },
      ]);
    }
  }

  /// Builds one published listing with the full program shape. Coordinates are
  /// [lng, lat] to match the GeoJSON Point convention used across the app.
  static Map<String, dynamic> _p(
    String id,
    String biz,
    bool verified,
    String sport,
    String title,
    String desc,
    num price,
    String model,
    double rating,
    int reviews,
    double lng,
    double lat,
    bool featured,
    String skill,
    String age,
    int minAge,
    int maxAge,
    int cap,
    int enrolled,
  ) => {
    "_id": id,
    "coverImage": "",
    "title": title,
    "description": desc,
    "sportType": sport,
    "skillLevel": skill,
    "ageGroup": age,
    "language": "English",
    "price": price.toDouble(),
    "currency": "USD",
    "pricingModel": model,
    "maxCapacity": cap,
    "enrolledCount": enrolled,
    "gallery": <String>[],
    "whatsIncluded": const [
      "Equipment provided",
      "Professional coaching",
      "Progress report",
    ],
    "location": {
      "type": "Point",
      "coordinates": [lng, lat],
    },
    "address": {
      "line1": "Miami, FL",
      "city": "Miami",
      "state": "FL",
      "zip": "33101",
      "country": "USA",
    },
    "cancellationPolicy": "moderate",
    "minimumAge": minAge,
    "maximumAge": maxAge,
    "isFeatured": featured,
    "status": "published",
    "averageRating": rating,
    "totalReviews": reviews,
    "providerId": {
      "ownerId": "mock-provider-apex",
      "businessName": biz,
      "verificationStatus": verified ? "verified" : "pending",
      "backgroundCheckStatus": verified ? "verified" : "pending",
      "status": verified ? "approved" : "pending",
      if (verified) "backgroundCheckCompletedAt": "2026-01-15T18:00:00.000Z",
    },
  };

  /// Programs 3–30: five more businesses at EXACTLY 5 listings each, plus the
  /// 3 that complete Apex's 5 (prog_1 + prog_2 are defined inline above). Spread
  /// across 20+ sports and Miami neighborhoods so browse + map read full.
  static List<Map<String, dynamic>> _extraPrograms() => [
    // ── Apex Performance Club (verified) — completes its 5 ──────────────
    _p(
      'prog_3',
      'Apex Performance Club',
      true,
      'Basketball',
      'Elite Basketball Skills — U14',
      'Ball-handling, shooting mechanics, and court IQ for competitive guards and forwards.',
      55,
      'single_session',
      4.7,
      19,
      -80.195,
      25.755,
      true,
      'Advanced',
      'Juniors (Under 16)',
      11,
      14,
      16,
      9,
    ),
    _p(
      'prog_4',
      'Apex Performance Club',
      true,
      'Volleyball',
      'Youth Volleyball Fundamentals',
      'Serving, passing, and rotation basics in a high-energy team environment.',
      40,
      'single_session',
      4.6,
      14,
      -80.188,
      25.768,
      false,
      'Beginner',
      'Youth (Under 12)',
      8,
      12,
      14,
      7,
    ),
    _p(
      'prog_5',
      'Apex Performance Club',
      true,
      'Swimming',
      'Learn-to-Swim Clinic',
      'Water confidence, freestyle, and backstroke for first-time swimmers.',
      50,
      'monthly',
      4.9,
      22,
      -80.205,
      25.772,
      false,
      'Beginner',
      'All Ages',
      6,
      16,
      10,
      6,
    ),
    // ── Coral Reef Aquatics (verified) ──────────────────────────────────
    _p(
      'prog_6',
      'Coral Reef Aquatics',
      true,
      'Swimming',
      'Competitive Swim Squad',
      'Stroke refinement and race-pace sets for club swimmers chasing PBs.',
      90,
      'monthly',
      4.8,
      31,
      -80.130,
      25.790,
      true,
      'Advanced',
      'Teens (13-18)',
      12,
      18,
      12,
      9,
    ),
    _p(
      'prog_7',
      'Coral Reef Aquatics',
      true,
      'Diving',
      'Springboard Diving Basics',
      'Approach, hurdle, and entry technique on the 1-meter board.',
      75,
      'single_session',
      4.5,
      11,
      -80.128,
      25.800,
      false,
      'Intermediate',
      'Juniors (Under 16)',
      10,
      16,
      8,
      5,
    ),
    _p(
      'prog_8',
      'Coral Reef Aquatics',
      true,
      'Water Polo',
      'Junior Water Polo League',
      'Eggbeater, ball control, and small-sided games for aspiring polo players.',
      65,
      'monthly',
      4.4,
      9,
      -80.135,
      25.810,
      false,
      'Intermediate',
      'Teens (13-18)',
      12,
      18,
      16,
      12,
    ),
    _p(
      'prog_9',
      'Coral Reef Aquatics',
      true,
      'Surfing',
      'Beginner Surf Camp',
      'Pop-ups, paddling, and ocean safety on gentle South Beach breaks.',
      85,
      'package',
      4.7,
      17,
      -80.125,
      25.782,
      true,
      'Beginner',
      'All Ages',
      8,
      18,
      8,
      6,
    ),
    _p(
      'prog_10',
      'Coral Reef Aquatics',
      true,
      'Swimming',
      'Masters Stroke Technique',
      'Adult-focused technique clinic for triathletes and lap swimmers.',
      60,
      'monthly',
      4.6,
      13,
      -80.132,
      25.795,
      false,
      'All Levels',
      'All Ages',
      16,
      60,
      12,
      8,
    ),
    // ── Downtown Hoops Academy (verified) ───────────────────────────────
    _p(
      'prog_11',
      'Downtown Hoops Academy',
      true,
      'Basketball',
      'Guard Development Lab',
      'Handles, footwork, and finishing for point and combo guards.',
      70,
      'single_session',
      4.9,
      40,
      -80.191,
      25.774,
      true,
      'Advanced',
      'Teens (13-18)',
      13,
      18,
      12,
      10,
    ),
    _p(
      'prog_12',
      'Downtown Hoops Academy',
      true,
      'Basketball',
      'Little Ballers Intro',
      'Fundamentals and fun for first-time players ages 6–9.',
      35,
      'single_session',
      4.7,
      24,
      -80.196,
      25.779,
      false,
      'Beginner',
      'Youth (Under 12)',
      6,
      9,
      16,
      11,
    ),
    _p(
      'prog_13',
      'Downtown Hoops Academy',
      true,
      'Track & Field',
      'Speed & Agility Training',
      'Sprint mechanics, plyometrics, and acceleration for multi-sport athletes.',
      45,
      'monthly',
      4.6,
      15,
      -80.185,
      25.770,
      false,
      'All Levels',
      'Juniors (Under 16)',
      10,
      16,
      14,
      9,
    ),
    _p(
      'prog_14',
      'Downtown Hoops Academy',
      true,
      'Volleyball',
      'Indoor Volleyball Clinic',
      'Attacking, blocking, and defensive systems for club-level players.',
      55,
      'single_session',
      4.5,
      12,
      -80.199,
      25.765,
      false,
      'Intermediate',
      'Teens (13-18)',
      12,
      18,
      14,
      10,
    ),
    _p(
      'prog_15',
      'Downtown Hoops Academy',
      true,
      'Dance',
      'Hip-Hop & Movement',
      'Choreography, rhythm, and performance for expressive young movers.',
      40,
      'monthly',
      4.8,
      20,
      -80.188,
      25.783,
      true,
      'Beginner',
      'All Ages',
      7,
      16,
      18,
      14,
    ),
    // ── Everglade Racquet Institute (pending) ───────────────────────────
    _p(
      'prog_16',
      'Everglade Racquet Institute',
      false,
      'Tennis',
      'High-Performance Tennis',
      'Topspin, serve mechanics, and point construction for tournament players.',
      110,
      'monthly',
      4.7,
      18,
      -80.320,
      25.760,
      true,
      'Advanced',
      'Teens (13-18)',
      12,
      18,
      6,
      4,
    ),
    _p(
      'prog_17',
      'Everglade Racquet Institute',
      false,
      'Pickleball',
      'Pickleball for Everyone',
      'Dinks, third-shot drops, and court positioning in a friendly setting.',
      35,
      'single_session',
      4.6,
      21,
      -80.330,
      25.755,
      false,
      'All Levels',
      'All Ages',
      10,
      60,
      12,
      9,
    ),
    _p(
      'prog_18',
      'Everglade Racquet Institute',
      false,
      'Badminton',
      'Badminton Footwork Clinic',
      'Clears, drops, and shadow footwork for competitive juniors.',
      45,
      'single_session',
      4.4,
      8,
      -80.315,
      25.770,
      false,
      'Intermediate',
      'Juniors (Under 16)',
      10,
      16,
      10,
      6,
    ),
    _p(
      'prog_19',
      'Everglade Racquet Institute',
      false,
      'Squash',
      'Squash Fundamentals',
      'Racquet prep, length, and movement patterns for the singles court.',
      60,
      'package',
      4.5,
      7,
      -80.325,
      25.748,
      false,
      'Beginner',
      'Teens (13-18)',
      12,
      18,
      6,
      4,
    ),
    _p(
      'prog_20',
      'Everglade Racquet Institute',
      false,
      'Table Tennis',
      'Table Tennis Spin Lab',
      'Loops, pushes, and serve variation for developing paddlers.',
      30,
      'single_session',
      4.6,
      10,
      -80.335,
      25.765,
      false,
      'All Levels',
      'All Ages',
      9,
      60,
      8,
      5,
    ),
    // ── Ironside Combat Gym (verified) ──────────────────────────────────
    _p(
      'prog_21',
      'Ironside Combat Gym',
      true,
      'Boxing',
      'Youth Boxing Foundations',
      'Stance, footwork, and pad work — non-contact, discipline-first.',
      50,
      'monthly',
      4.8,
      26,
      -80.210,
      25.850,
      true,
      'Beginner',
      'Juniors (Under 16)',
      10,
      16,
      12,
      9,
    ),
    _p(
      'prog_22',
      'Ironside Combat Gym',
      true,
      'Wrestling',
      'Folkstyle Wrestling Club',
      'Takedowns, escapes, and conditioning for scholastic wrestlers.',
      55,
      'monthly',
      4.6,
      14,
      -80.205,
      25.845,
      false,
      'Intermediate',
      'Teens (13-18)',
      12,
      18,
      16,
      12,
    ),
    _p(
      'prog_23',
      'Ironside Combat Gym',
      true,
      'Martial Arts',
      'Mixed Martial Arts Intro',
      'Striking, grappling, and movement fundamentals in a controlled setting.',
      65,
      'single_session',
      4.7,
      19,
      -80.215,
      25.860,
      false,
      'Beginner',
      'Teens (13-18)',
      13,
      18,
      14,
      10,
    ),
    _p(
      'prog_24',
      'Ironside Combat Gym',
      true,
      'Karate',
      'Traditional Karate Dojo',
      'Kata, kihon, and respect-centered practice for all belt levels.',
      45,
      'monthly',
      4.9,
      33,
      -80.200,
      25.855,
      true,
      'All Levels',
      'All Ages',
      6,
      60,
      20,
      15,
    ),
    _p(
      'prog_25',
      'Ironside Combat Gym',
      true,
      'Judo',
      'Judo Throws & Groundwork',
      'Nage-waza and ne-waza basics with certified black-belt instruction.',
      50,
      'single_session',
      4.5,
      11,
      -80.220,
      25.848,
      false,
      'Beginner',
      'Juniors (Under 16)',
      8,
      16,
      16,
      11,
    ),
    // ── Sunset Field Athletics (pending) ────────────────────────────────
    _p(
      'prog_26',
      'Sunset Field Athletics',
      false,
      'Baseball',
      'Hitting & Fielding Camp',
      'Swing mechanics, glove work, and situational baserunning.',
      60,
      'package',
      4.6,
      16,
      -80.230,
      25.680,
      true,
      'Intermediate',
      'Juniors (Under 16)',
      9,
      16,
      18,
      13,
    ),
    _p(
      'prog_27',
      'Sunset Field Athletics',
      false,
      'Softball',
      'Fastpitch Softball Clinic',
      'Pitching, slapping, and infield defense for competitive girls.',
      55,
      'monthly',
      4.7,
      12,
      -80.240,
      25.675,
      false,
      'Advanced',
      'Teens (13-18)',
      12,
      18,
      14,
      10,
    ),
    _p(
      'prog_28',
      'Sunset Field Athletics',
      false,
      'Football',
      'Flag Football Fundamentals',
      'Routes, coverage, and non-contact game IQ for youth athletes.',
      40,
      'single_session',
      4.5,
      9,
      -80.225,
      25.690,
      false,
      'Beginner',
      'Youth (Under 12)',
      7,
      12,
      20,
      15,
    ),
    _p(
      'prog_29',
      'Sunset Field Athletics',
      false,
      'Lacrosse',
      'Intro to Lacrosse',
      'Cradling, passing, and dodging in a fast-paced beginner clinic.',
      50,
      'single_session',
      4.4,
      7,
      -80.235,
      25.665,
      false,
      'Beginner',
      'Juniors (Under 16)',
      9,
      16,
      16,
      10,
    ),
    _p(
      'prog_30',
      'Sunset Field Athletics',
      false,
      'Cricket',
      'Cricket Skills Academy',
      'Batting technique, seam bowling, and fielding drills for all comers.',
      45,
      'monthly',
      4.6,
      8,
      -80.245,
      25.685,
      true,
      'All Levels',
      'All Ages',
      9,
      60,
      16,
      11,
    ),
  ];

  // Getters & Setters
  static Map<String, dynamic> get userProfile {
    init();
    final data = _box.read('mock_user_profile');
    if (data == null) return {};
    return Map<String, dynamic>.from(data);
  }

  static set userProfile(Map<String, dynamic> val) {
    init();
    _box.write('mock_user_profile', val);
  }

  static Map<String, dynamic> get providerProfile {
    init();
    final data = _box.read('mock_provider_profile');
    if (data == null) return {};
    return Map<String, dynamic>.from(data);
  }

  static set providerProfile(Map<String, dynamic> val) {
    init();
    _box.write('mock_provider_profile', val);
  }

  static List<dynamic> get athletes {
    init();
    return _box.read<List<dynamic>>('mock_athletes') ?? [];
  }

  static set athletes(List<dynamic> val) {
    init();
    _box.write('mock_athletes', val);
  }

  static List<dynamic> get programs {
    init();
    return _box.read<List<dynamic>>('mock_programs') ?? [];
  }

  static set programs(List<dynamic> val) {
    init();
    _box.write('mock_programs', val);
  }

  static List<dynamic> get sessions {
    init();
    return _box.read<List<dynamic>>('mock_sessions') ?? [];
  }

  static set sessions(List<dynamic> val) {
    init();
    _box.write('mock_sessions', val);
  }

  static List<dynamic> get bookings {
    init();
    return _box.read<List<dynamic>>('mock_bookings') ?? [];
  }

  static set bookings(List<dynamic> val) {
    init();
    _box.write('mock_bookings', val);
  }

  /// Persist a new booking (newest first) so it survives navigation and shows
  /// up on Home "Coming Up" and the Schedule calendar.
  static void addBooking(Map<String, dynamic> booking) {
    final current = List<dynamic>.from(bookings);
    current.insert(0, booking);
    bookings = current;
  }

  static Map<String, dynamic> get notificationPrefs {
    init();
    final data = _box.read('mock_notification_prefs');
    return data != null ? Map<String, dynamic>.from(data) : {};
  }

  static set notificationPrefs(Map<String, dynamic> val) {
    init();
    _box.write('mock_notification_prefs', val);
  }

  static List<dynamic> get conversations {
    init();
    return _box.read<List<dynamic>>('mock_conversations') ?? [];
  }

  static set conversations(List<dynamic> val) {
    init();
    _box.write('mock_conversations', val);
  }

  static List<dynamic> getMessages(String convId) {
    init();
    return _box.read<List<dynamic>>('mock_messages_$convId') ?? [];
  }

  static void saveMessages(String convId, List<dynamic> msgs) {
    init();
    _box.write('mock_messages_$convId', msgs);
  }

  static List<dynamic> get notifications {
    init();
    return _box.read<List<dynamic>>('mock_notifications') ?? [];
  }

  static set notifications(List<dynamic> val) {
    init();
    _box.write('mock_notifications', val);
  }

  static List<dynamic> get teams {
    init();
    return _box.read<List<dynamic>>('mock_teams') ?? [];
  }

  static set teams(List<dynamic> val) {
    init();
    _box.write('mock_teams', val);
  }

  static List<String> get favorites {
    init();
    final favs = _box.read('mock_favorites');
    if (favs == null) return [];
    return List<String>.from(favs);
  }

  static set favorites(List<String> val) {
    init();
    _box.write('mock_favorites', val);
  }

  static List<dynamic> get parentUpdates {
    init();
    return _box.read<List<dynamic>>('mock_parent_updates') ?? [];
  }

  static set parentUpdates(List<dynamic> val) {
    init();
    _box.write('mock_parent_updates', val);
  }

  /// Grounded, backend-authored progress digests keyed by `athleteId`. Empty by
  /// default (the offline fake backend seeds none — the timeline renders from
  /// parent_updates alone); the real digests come from `progress_digests`.
  static List<dynamic> get progressDigests {
    init();
    return _box.read<List<dynamic>>('mock_progress_digests') ?? [];
  }

  static set progressDigests(List<dynamic> val) {
    init();
    _box.write('mock_progress_digests', val);
  }
}
