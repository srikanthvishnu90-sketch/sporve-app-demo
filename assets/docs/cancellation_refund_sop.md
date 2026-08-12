# Sporve Support SOP: Cancellations, Refunds & Escalations

**Official Support Channel**: `support@sporve.com`  
**SLA**: Response within 24 hours daily.

---

## 1. Refund Standard Operating Procedures (SOP)

### A. Coach No-Show or Cancellation > 24 Hours Prior
- **Trigger**: Coach cancels or fails to show up for session.
- **Action**: Full 100% refund processed back to original payment method via Stripe within 3-5 business days.
- **Standard Reply Script**:
> "Hi [Parent Name],
>
> We sincerely apologize for the inconvenience caused by your session's cancellation. A full 100% refund of $[Amount] has been issued to your payment card (Stripe Ref: [ID]). You should see this reflected in 3-5 business days.
>
> If you'd like help booking an alternative top-rated coach in your area, please reply to this email!
>
> Best regards,  
> Sporve Support Team"

### B. Parent Cancellation (< 24 Hours Notice)
- **Policy**: Per marketplace guidelines, cancellations under 24 hours incur a 50% late-cancellation fee to compensate the coach's reserved slot, unless due to medical emergency.
- **Standard Reply Script**:
> "Hi [Parent Name],
>
> Thank you for reaching out. Per our booking terms, cancellations with less than 24 hours notice are subject to a 50% late-cancellation fee to honor our coach's committed schedule.
>
> We have refunded $[Refund Amount] back to your account. If this cancellation was due to a medical emergency, please attach a note or documentation and we will review for a full waiver.
>
> Best regards,  
> Sporve Support Team"

---

## 2. Webhook & Payment State Discrepancy Protocol

- When daily reconciliation alert triggers a payment vs booking state drift:
1. Cross-reference Stripe Dashboard `payment_intents` list with database `bookings` table.
2. Check Supabase webhook error logs.
3. Re-trigger Stripe event processing if webhook failed.
4. Notify affected parent/coach within 2 hours.

---

## 3. Escalation Contacts

- **Payment/Stripe Issues**: `support@sporve.com`
- **Safety / Background Check Disputes**: `trust@sporve.com`
