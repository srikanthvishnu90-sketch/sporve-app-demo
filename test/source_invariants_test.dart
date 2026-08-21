import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<File> _dartFiles(String root) sync* {
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) yield entity;
  }
}

void main() {
  test('presentation code contains no raw Color hex literals', () {
    final violations = <String>[];
    final pattern = RegExp(r'Color\s*\(\s*0x', caseSensitive: false);
    for (final file in _dartFiles('lib/presentation')) {
      if (pattern.hasMatch(file.readAsStringSync())) violations.add(file.path);
    }
    expect(violations, isEmpty);
  });

  test('no anonymous catch can silently swallow an error', () {
    final violations = <String>[];
    final pattern = RegExp(r'catch\s*\(\s*_\s*\)');
    for (final file in _dartFiles('lib')) {
      if (pattern.hasMatch(file.readAsStringSync())) violations.add(file.path);
    }
    expect(violations, isEmpty);
  });

  test('presentation reaches Supabase only through AppRepository', () {
    final violations = <String>[];
    final pattern = RegExp(
      r'''import\s+['"]package:supabase_flutter|Supabase\.instance''',
    );
    for (final file in _dartFiles('lib/presentation')) {
      if (pattern.hasMatch(file.readAsStringSync())) violations.add(file.path);
    }
    expect(violations, isEmpty);
  });

  test('client code contains no payment-status write shortcut', () {
    final source = _dartFiles(
      'lib',
    ).map((file) => file.readAsStringSync()).join();
    expect(source, isNot(contains('markBookingPaid')));
    expect(
      RegExp(
        r'''update\s*\(\s*\{[^}]*['"]payment_status['"]''',
        dotAll: true,
      ).hasMatch(source),
      isFalse,
    );
    final supabase = File(
      'lib/core/data/supabase_repository.dart',
    ).readAsStringSync();
    expect(
      RegExp(r'''['"]payment_status['"]\s*:''').hasMatch(supabase),
      isFalse,
      reason: 'Even the initial unpaid state is a database default.',
    );
    final bookingFlow = File(
      'lib/presentation/client/view/booking_flow_screen.dart',
    ).readAsStringSync();
    for (final key in [
      'paymentStatus',
      'originalPrice',
      'finalPrice',
      'currency',
    ]) {
      expect(
        RegExp("['\"]$key['\"]\\s*:").hasMatch(bookingFlow),
        isFalse,
        reason: '$key must be derived by the booking server.',
      );
    }
    expect(
      RegExp(r'''['"]status['"]\s*:\s*['"]pending['"]''').hasMatch(bookingFlow),
      isFalse,
      reason: 'Initial booking status is a database default.',
    );
  });

  test('mock marketplace geography stays aligned with Chicagoland', () {
    final source = File('lib/core/mock/mock_data.dart').readAsStringSync();
    expect(source.toLowerCase(), isNot(contains('miami')));
    expect(source, contains('America/Chicago'));
    expect(source, contains('Chicago, IL'));
  });

  test(
    'mock booking sessions stay future-relative and cover the hero program',
    () {
      final source = File('lib/core/mock/mock_data.dart').readAsStringSync();
      expect(source, contains('"date": _futureSessionDate('));
      expect(source, contains('"programId": "prog_5"'));
      expect(source, contains('"_id": "sess_4"'));
    },
  );

  test(
    'booking availability is derived from real sessions, not static slots',
    () {
      final source = File(
        'lib/presentation/client/view/booking_flow_screen.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('final List<String> _timeSlots')));
      expect(source, contains('get _timeSlots => _sessionsOnSelectedDay'));
      expect(source, contains('_firstSessionOnCalendarDay(day)'));
    },
  );
}
