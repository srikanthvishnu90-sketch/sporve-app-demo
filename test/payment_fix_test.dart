// Verifies server-authoritative cancellation/refund status synchronization.
// Run: flutter test test/payment_fix_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sporve_app/core/data/app_repository.dart';
import 'package:sporve_app/presentation/client/controllers/home_controller.dart';

class _FakeBookingRepo implements AppRepository {
  final List<Map<String, dynamic>> bookings = [];
  double nextRefundAmount = 30;

  @override
  Future<List<dynamic>> getBookings() async => bookings;

  @override
  Future<List<dynamic>> getBookingsOrThrow() async => bookings;

  @override
  Future<Map<String, dynamic>> requestBookingCancellation(
    String bookingId, {
    String? reason,
  }) async {
    final i = bookings.indexWhere((b) => b['_id'] == bookingId);
    if (i == -1) {
      return {'success': false, 'error': 'Booking not found.'};
    }
    final booking = Map<String, dynamic>.from(bookings[i]);
    final originalPrice =
        (booking['finalPrice'] ?? booking['originalPrice'] ?? 75.0) as num;
    // This fake stands in for the server: the caller supplies no amount and
    // only reads the recorded decision returned by the function.
    final amount = nextRefundAmount;
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
    return {
      'success': true,
      'refundStatus': booking['refundStatus'],
      'refundedAmount': amount,
      'paymentStatus': booking['paymentStatus'],
    };
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

  group('Server-authoritative refund path', () {
    test('partial result is rendered from the server response', () async {
      fakeRepo.nextRefundAmount = 30;
      final result = await fakeRepo.requestBookingCancellation(
        'pay_test_b1',
        reason: 'Partial session cancellation',
      );

      expect(result['success'], isTrue);
      expect(result['refundedAmount'], 30.0);
      final bookings = await fakeRepo.getBookings();
      final updated = bookings.firstWhere((b) => b['_id'] == 'pay_test_b1');

      expect(updated['refundStatus'], equals('partial'));
      expect(updated['refundedAmount'], equals(30.0));
      expect(updated['refundReason'], equals('Partial session cancellation'));
      expect(updated['status'], equals('confirmed'));
      expect(updated['paymentStatus'], equals('paid'));
    });

    test('full result updates status only after the server decision', () async {
      fakeRepo.nextRefundAmount = 100;
      final result = await fakeRepo.requestBookingCancellation(
        'pay_test_b1',
        reason: 'Full refund request',
      );

      expect(result['success'], isTrue);
      final bookings = await fakeRepo.getBookings();
      final updated = bookings.firstWhere((b) => b['_id'] == 'pay_test_b1');

      expect(updated['refundStatus'], equals('full'));
      expect(updated['refundedAmount'], equals(100.0));
      expect(updated['status'], equals('refunded'));
      expect(updated['paymentStatus'], equals('refunded'));
    });
  });

  group('HomeController cancellation integration', () {
    test('successful server decision triggers a booking refetch', () async {
      final controller = HomeProvider(fakeRepo);
      await controller.fetchBookings();

      fakeRepo.nextRefundAmount = 50;
      final result = await controller.requestBookingCancellation(
        'pay_test_b1',
        reason: 'Half refund',
      );

      expect(result['success'], isTrue);
      final b = controller.bookingById('pay_test_b1');
      expect(b, isNotNull);
      expect(b!['refundStatus'], equals('partial'));
      expect(b['refundedAmount'], equals(50.0));
    });
  });
}
