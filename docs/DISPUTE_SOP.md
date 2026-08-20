# Sporve Stripe Dispute & Chargeback Operating Standard Procedure (SOP)

**Document Version:** 1.0  
**Effective Date:** August 2026  
**Scope:** Payment disputes, bank chargebacks, evidence collection, and booking lifecycle state updates.

---

## 1. Merchant of Record & Statement Descriptor

- **Merchant of Record:** Sporve LLC operates as the Merchant of Record (or platform billing entity) via Stripe Connect Custom/Express integration.
- **Statement Descriptor:** All parent transactions appear on card statements as:
  `SPORVE* <COACH_NAME>` or `SPORVE PARKING/SPORTS`.
- **Receipt Payload:** Automated receipts sent by Stripe contain:
  - Coach / Organization Name
  - Session Title & Scheduled Date/Time
  - Athlete Name
  - Total Charged & Currency (USD)

---

## 2. Dispute Detection & Webhook Triggers

When a parent initiates a chargeback or payment dispute via their issuing bank:

1. **Stripe Webhook Event:** `charge.dispute.created` is received by the backend webhook handler.
2. **Database Status Update:** The corresponding booking row in `bookings` is immediately set to:
   - `status = 'disputed'`
   - `dispute_status = 'needs_response'`
3. **Provider Notification:** An automated in-app banner and push notification alert the coach of the active dispute.

---

## 3. Financial Liability Allocation

| Dispute Outcome | Financial Allocation |
| :--- | :--- |
| **Dispute Initiated** | Stripe assesses a $15.00 dispute processing fee. The disputed charge amount is temporarily held by Stripe. |
| **Dispute Won** | Held charge amount + $15.00 fee are returned to Sporve and credited back to the provider's payout balance. |
| **Dispute Lost** | The provider absorbs the lost session amount and any Stripe-assessed dispute costs. Sporve does not retain a booking commission; workspace subscription charges are separate. |

---

## 4. Evidence Submission Workflow

Within 7 days of `charge.dispute.created`:

1. **Automated Log Assembly:**
   - **Session Attendance Log:** Check-in timestamp recorded by provider in `provider_schedule_screen`.
   - **Chat History:** Timestamped messages between Parent and Coach in `chat_details_screen`.
   - **Booking Confirmation:** Signed proposal/booking timestamp, parent profile ID, and IP footprint.
2. **Stripe API Evidence Upload:**
   - Evidence bundle attached via `stripe.disputes.update(dispute_id, evidence: {...})`.
3. **Status Resolution:**
   - `charge.dispute.closed` event updates DB booking state to `chargeback_won` or `chargeback_lost`.

---

## 5. Booking & Account State Rules

- **Active Dispute:** Booking status displays `Disputed` badge; session calendar slot is preserved for historical accuracy.
- **Lost Dispute:** Booking status updates to `Cancelled (Chargeback Lost)`. If fraudulent activity is detected, user profile access is temporarily suspended.
- **Won Dispute:** Booking status reverts to `Confirmed`.
