# Sporve Flutter client — implementation audit

**Updated:** 2026-08-20
**Scope:** Flutter mobile client and framed web demo. This is not a production
Supabase or Stripe attestation.

## Remediated in the 2026-08-20 implementation

- Sporve revenue is one Free, Pro, or Enterprise subscription per provider
  workspace. The current policy takes 0% from bookings; historical webhook-
  recorded fee/net facts continue to render unchanged.
- New bookings no longer offer or write Standard/Pro/Elite booking tiers.
  Historical Pro/Elite rows label the immutable tier and recorded price.
- Checkout sends identifiers and return URLs only. The app never supplies an
  amount or writes `payment_status`; it refetches the booking after Stripe return
  and shows processing/check-back states while the webhook is pending.
- Refund requests send a booking identifier/reason only. The server decides and
  records the amount from the captured policy snapshot.
- Preview/mock mode cannot fabricate checkout, Connect, refund, or payment
  success. Release mode still force-disables the mock repository.
- Provider trust is one strict predicate: approved provider + verified
  background check + valid completion timestamp. Discovery, matching, map pins,
  badges, and payment entry use it and fail closed.
- The design tokens now implement distinct positive/warning/negative/link roles,
  Persimmon action color, an AA-capable structural foreground, real gradients,
  Oswald displays, Hanken Grotesk body, and JetBrains Mono data.
- Presentation raw-color literals and direct Supabase access are prohibited by
  source-invariant tests. Dead/fabricated AI demo surfaces and an external image
  hotlink were removed.
- The mobile frame scrolls on short desktop viewports. Flutter web intentionally
  remains a framed app demo under D6; `sporve-web` is the browser product.
- Location permission failures now distinguish denied/unavailable states. The
  map centers on the complete listing bounds and falls back to Chicago only when
  no coordinates exist.
- Malformed session times are explicit (`Time unavailable`) rather than silently
  guessed. Silent catches now surface, breadcrumb, log, or document the one
  legitimate reporter-recursion exception.
- Client-invoked Edge Function and RPC names are source-extracted and checked
  against machine-readable contracts. This detects client/manifest drift but
  does not pretend absent backend source has been recovered.
- Local GetStorage artifacts were removed and ignored; package/store identity is
  `sporve_app` / `com.sporve.app`; proprietary and third-party notices now exist.

## Verification state

- Flutter analyzer: clean after the implementation changes.
- New deterministic tests cover strict trust, tier-history labels, Chicago/list
  bounds, contract projection, source invariants, color contrast, payment state,
  booking-path server messages, and malformed time input.
- The managed workspace blocks Flutter's test runner from opening its required
  `127.0.0.1:0` loopback socket. No test body failed in that attempt; the full
  suite must still run in an environment that permits the test process.
- Final build, browser, inherited workspace, and diff checks are recorded in
  `docs/HANDOFF.md` at handoff rather than forecast here.

## Open structural and launch risks

1. D5 assigns production schema and Edge Functions to one dedicated backend
   repository, but its name/source recovery is unresolved. This client contains
   contracts, not the source of truth.
2. The signed `checkout.session.completed → payment_status='paid'` webhook path,
   Stripe amount derivation, idempotency, Connect behavior, payout reconciliation,
   and refund execution cannot be verified without that backend source.
3. No production Supabase mutation or Stripe action was performed. Test-mode
   bidirectional app/web checkout, abandoned Connect resume, and refund-to-cent
   evidence remain launch gates.
4. The web pack containing canonical D1–D3 was absent from this checkout. The 0%
   outcome implements the research owner's explicit subscription direction;
   cross-repository contract consumption remains to be wired by the web owner.
5. Asset provenance is incomplete for the files named in `NOTICE`. Font license
   terms are recorded; unresolved product-image ownership is an owner blocker.
6. IP assignment for the original third-party-authored history and stable git
   identity are owner-only diligence items and remain unchecked.
7. This branch descends from a repository state with a previously identified
   automatic-task payload. The reviewed branch deletes it; default-branch and
   credential incident remediation remain owner responsibilities.

## Priority order

1. Name and reconstruct the dedicated backend repository; recover every deployed
   function and a truthful schema baseline without mutating production from here.
2. Audit/build the signed Stripe webhook and run the complete shared test-mode
   money matrix from app and web.
3. Run the full Flutter suite and store builds in an unrestricted CI runner.
4. Complete asset/IP provenance and company git identity records.
5. Apply the same generated contracts in `sporve-web` and make drift a CI failure.
