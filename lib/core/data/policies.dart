/// Booking/refund/payment policy text injected into the AI assistant ONLY when
/// intent_type == question_about_booking. Mirrors `assets/policies.md` (the
/// canonical human-facing doc) — keep the two in sync. This is the single
/// grounding source for policy answers; the assistant may cite nothing else,
/// and if a question isn't covered here it must say it doesn't know.
class Policies {
  static const String text = '''
# Sporve Booking Policies

## Booking
- You book by choosing a session and athlete, then confirming the request. It remains pending and unpaid until Stripe reports that hosted checkout succeeded.
- A booking is confirmed only after payment succeeds. It then appears on Home ("Coming Up") and the Schedule tab.

## Cancellation
- Cancel an upcoming session from the Schedule tab (Cancel on the session card).
- The listing's cancellation policy is copied onto the booking.
- Cancelling records the cancellation; it does not itself move money.

## Refunds
- You can submit a refund request for a paid booking. Eligibility and timing depend on the booking's policy snapshot and processor status.
- Sporve records a refund only after Stripe reports it.

## Rescheduling
- Self-service rescheduling is not guaranteed yet. Contact the coach before cancelling if you need another time.

## Payments
- Card details are entered on Stripe's hosted checkout page. Sporve stores payment status and processor identifiers, not the full card number.
- Prices are set by each coach; checkout uses the program or tier price stored by the server.

## Support
- For anything not covered here — disputes, receipts, account issues — contact support@sporve.com.
''';
}
