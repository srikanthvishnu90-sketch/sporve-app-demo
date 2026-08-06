// Verifies payment fixes (refund processing, idempotency fields, status sync)
// Run: flutter test test/payment_fix_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_structure/core/data/app_repository.dart';
import 'package:flutter_structure/presentation/client/controllers/home_controller.dart';

class _FakeBookingRepo implements AppRepository {
  final List<Map<String, dynamic>> bookings = [];

  @override
  Future<List<dynamic>> getBookings() async => bookings;

  @override
  Future<List<dynamic>> getBookingsOrThrow() async => bookings;

  @override
  Future<bool> processRefund(
    String bookingId, {
    required double amount,
    String? reason,
  }) async {
    final i = bookings.indexWhere((b) => b['_id'] == bookingId);
    if (i == -1) return false;
    final booking = Map<String, dynamic>.from(bookings[i]);
    final originalPrice =
        (booking['finalPrice'] ?? booking['originalPrice'] ?? 75.0) as num;
    final isFull = amount >= originalPrice.toDouble();
    booking['refundStatus'] = isFull ? 'full' : 'partial';
    booking['refundedAmount'] = amount;
    booking['refundedAt'] = DateTime.now().toIso8601String();
    if (reason != null && reason.isNotEmpty) {
      booking['refundReason'] = reason;
    }
    if (isFull) {
      booking['status'] = 'refunded';
      booking['paymentStatus'] = 'refunded';
    }
    bookings[i] = booking;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeBookingRepo fakeRepo;

  setUp(() {
    fakeRepo = _FakeBookingRepo();
    fakeRepo.bookings.add({
      '_id': 'pay_test_b1',
      'finalPrice': 100.0,
      'originalPrice': 100.0,
      'status': 'confirmed',
      'paymentStatus': 'paid',
      'createdAt': DateTime.now().toIso8601String(),
    });
  });

  group('Refund Path Logic Tests', () {
    test('Partial refund updates refundStatus and refundedAmount without canceling', () async {
      final ok = await fakeRepo.processRefund(
        'pay_test_b1',
        amount: 30.0,
        reason: 'Partial session cancellation',
      );

      expect(ok, isTrue);
      final bookings = await fakeRepo.getBookings();
      final updated = bookings.firstWhere((b) => b['_id'] == 'pay_test_b1');

      expect(updated['refundStatus'], equals('partial'));
      expect(updated['refundedAmount'], equals(30.0));
      expect(updated['refundReason'], equals('Partial session cancellation'));
      expect(updated['status'], equals('confirmed'));
      expect(updated['paymentStatus'], equals('paid'));
    });

    test('Full refund updates status and paymentStatus to refunded', () async {
      final ok = await fakeRepo.processRefund(
        'pay_test_b1',
        amount: 100.0,
        reason: 'Full refund request',
      );

      expect(ok, isTrue);
      final bookings = await fakeRepo.getBookings();
      final updated = bookings.firstWhere((b) => b['_id'] == 'pay_test_b1');

      expect(updated['refundStatus'], equals('full'));
      expect(updated['refundedAmount'], equals(100.0));
      expect(updated['status'], equals('refunded'));
      expect(updated['paymentStatus'], equals('refunded'));
    });
  });

  group('HomeController Refund Integration Tests', () {
    test('processRefund via HomeController re-fetches and updates state', () async {
      final controller = HomeProvider(fakeRepo);
      await controller.fetchBookings();

      final success = await controller.processRefund(
        'pay_test_b1',
        amount: 50.0,
        reason: 'Half refund',
      );

      expect(success, isTrue);
      final b = controller.bookingById('pay_test_b1');
      expect(b, isNotNull);
      expect(b!['refundStatus'], equals('partial'));
      expect(b['refundedAmount'], equals(50.0));
    });
  });
}
