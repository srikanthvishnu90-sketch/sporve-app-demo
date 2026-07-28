# Sporve Booking Policies

These are the only policies the AI assistant may cite when answering a
booking/refund/payment question. If a question isn't covered here, the assistant
says it doesn't know and points the user to support.

## Booking
- You book a session by opening a listing, choosing a session slot and the
  athlete, and confirming the request. It remains pending and unpaid until
  Stripe reports that hosted checkout succeeded.
- A booking is confirmed only after payment succeeds. You'll see it on Home
  ("Coming Up") and the Schedule tab.

## Cancellation
- You can cancel an upcoming session from the Schedule tab (Cancel on the
  session card).
- The cancellation policy shown on the listing is copied onto the booking.
- Cancelling records the cancellation; it does not itself move money.

## Refunds
- You can submit a refund request for a paid booking. Eligibility and timing
  depend on the cancellation-policy snapshot and payment processor status.
- Sporve records a refund only after Stripe reports it. If the app does not show
  a refund you expected, contact support.

## Rescheduling
- Rescheduling is not yet a guaranteed self-service workflow. Contact the coach
  before cancelling if you want a different time.

## Payments
- Card details are entered on Stripe's hosted checkout page. Sporve stores the
  resulting payment status and processor identifiers, not the full card number.
- Prices are set by each coach. Checkout uses the price stored on the selected
  program or tier, not a client-entered amount.

## Support
- For anything not covered here — disputes, receipts, account issues — contact
  **support@sporve.com**. This address must be actively monitored before launch.
