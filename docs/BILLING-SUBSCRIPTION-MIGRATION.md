# Workspace subscription migration

## Decision

Sporve revenue comes from one subscription per provider workspace, where a
workspace is either a solo provider or an organization provider. A customer
`team` remains a roster/buyer construct and is not a billing account.

Sporve's current booking and invoice fee policy is 0%. Stripe processing and
connected-account payout behavior are separate from Sporve's fee.

There is no active first-booking, recurring-booking, introduction, or
off-platform commission branch in the client. New transaction previews all use
the same subscription-funded 0% deduction policy. Nullable fee fields remain in
the read model only so historical charges can be reported exactly rather than
rewritten.

An organization may configure how booking revenue is divided with an affiliated
trainer. That is an organization compensation rule, not revenue earned by
Sporve. User-facing copy calls it an “organization share” or “revenue split”; the
legacy `commission_*` database field names remain unchanged for compatibility.

## Server-owned contract

The production Supabase project already owns the following contract:

| Plan | Monthly price | AI actions | Seats | Self-serve |
| --- | ---: | --- | ---: | --- |
| Free | $0 | 3/month | 1 | Included |
| Pro | $34.99 | Unlimited | 3 | Yes |
| Enterprise | $149 | Unlimited | Unlimited | No, until shared workspace is available |

`plan_entitlements` is the price/feature source of truth. The provider row
contains server-controlled `plan`, `plan_status`, `plan_period_end`,
`founding_coach`, and `stripe_customer_id` fields. Clients must not write them.

`billing-create-checkout` accepts only a plan identifier and validated redirect
URLs. `billing-portal` creates a Stripe-hosted management session. Stripe
webhooks update the provider subscription state. A checkout redirect never
grants access.

## Client behavior

- Web can open Stripe Checkout for self-serve Pro and the Stripe Billing Portal
  for an existing customer.
- iOS and Android are consumption-only for digital subscription features. They
  show server-confirmed plan and entitlements without a Stripe purchase or
  external upgrade link.
- Real-world coaching session checkout remains separate from workspace billing.
- Plan and billing UI follows a familiar three-tier subscription selector: Free,
  recommended Pro, and Enterprise early access, with a single primary upgrade
  action and a compact current-plan summary.
- Finance surfaces show recorded Sporve fee facts. Missing historical values
  remain unknown and exports leave those cells blank.
- Mock mode never simulates a successful Stripe purchase.

## Deployment boundary

This public demo is not the Supabase migration/function owner. Do not link it to
production, run `supabase db push`, deploy Edge Functions from it, or put Stripe
secrets in Flutter. Server migrations and function releases belong in the
canonical backend repository and require its migration-lineage process.

## Remaining backend release work

1. Set every server-side marketplace and off-platform Sporve fee default to
   zero through an idempotent migration in the backend owner repository, and
   remove first/recurring fee selection from new checkout creation.
2. Use stable Stripe Price IDs or lookup keys instead of creating dynamic
   Product/Price data on every Checkout Session.
3. Reject creation of a second live subscription for the same provider; route
   active customers through the Billing Portal for plan changes.
4. Decide who bears Stripe processing fees. The existing destination-charge
   shape can make the platform responsible even when Sporve's application fee
   is zero. Moving to direct charges requires connected-account webhook and
   dispute/refund verification before release.
5. Test webhook idempotency, delayed payment, past-due recovery, cancellation,
   refunds, and founding-coach coupons in Stripe test mode before any live
   billing change.

## Release evidence required

- Server migration applied through the backend owner workflow, never `db push`.
- Canonical Stripe products/prices and Portal configuration verified in test
  mode.
- One and only one subscription per provider workspace.
- Checkout return does not grant access before the signed webhook arrives.
- Recorded zero fees remain distinguishable from unknown historical fees.
- App Store and Play builds contain no external digital-subscription purchase
  CTA.
