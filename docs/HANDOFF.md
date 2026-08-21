# Sporve Flutter implementation handoff

Updated: 2026-08-20

## Completed work

- Implemented D1 as provider-workspace subscriptions with Free, Pro ($34.99),
  and Enterprise ($149) plans and a current 0% Sporve booking fee. Recorded
  historical booking fees remain immutable and visible.
- Implemented D4 by removing tier selection/writes from new bookings while
  labeling recorded historical Pro/Elite rows.
- Centralized D2 trust in `providerTrusted()`: approved provider, verified
  background check, and a valid completion timestamp are all required for
  discovery, badges, map eligibility, and checkout.
- Added client contracts and generated constants for fees, plans, quotas,
  statuses, 27 observed Edge Functions, and 19 observed RPCs.
- Made booking checkout, refund/cancellation, and Connect onboarding repository
  actions. Checkout sends booking/return identifiers only. Booking creation no
  longer authors id, price, currency, lifecycle status, payment status, or
  timestamps; it refetches server facts after creation and Stripe return.
- Added cold browser-return routing, three-attempt webhook-state polling,
  processing/check-back/failed/cancelled states, and persisted-booking hydration.
- Added abandoned-Connect recovery and honest payout loading/error/empty states.
- Rebuilt the semantic design tokens around obsidian + Persimmon, distinct
  success/warning/error/link colors, WCAG-tested foregrounds, Oswald display,
  Hanken Grotesk body, and JetBrains Mono data styles. Presentation raw hexes
  are now test-forbidden.
- Added Chicago/listing-bounds map centering, explicit location denial and
  unavailable states, malformed-time sentinels, booking-write error surfacing,
  analytics breadcrumbs, and bounded reporter self-failure logging.
- Kept the 440px mobile web frame and added a verified short-viewport scroll
  fallback. Removed external demo/stock-image hotlinks; the preview now works
  without image-network errors.
- Added the unified `/preview.html` hub for Family, Provider, Login, Pricing,
  and Demo surfaces. Mock checkout/refund/portal paths cannot fabricate success.
- Changed the app package/application identity to `sporve_app` /
  `com.sporve.app`, removed local storage junk, added license/notice records,
  and documented unresolved asset and contributor provenance.

## Validation evidence

- `flutter analyze --no-pub`: passed, no issues.
- `flutter test --no-pub`: passed, 188 tests.
- `dart run tool/validate_implementation_pack.dart`: passed; 27 functions and
  19 RPCs registered, with raw-hex, anonymous-catch, repository-boundary, and
  payment-authority checks active.
- `dart run tool/validate_billing.dart`: passed.
- Release web build: passed while explicitly requesting
  `USE_MOCK_REPO=true`; the release guard remained compiled in.
- Mock/profile web build: passed and is served at
  `http://localhost:8766/preview.html`.
- Browser review: Family, Provider, Login, Pricing, and Demo routes loaded;
  Free/Pro/Enterprise and 0% fee copy rendered; abandoned Connect rendered;
  500px short-viewport scrolling worked; no application console errors or
  external image requests remained. Headless-only WebGL/preload warnings remain.
- `git diff --check`: passed.
- Parent workspace gates: `npm run typecheck`, 22-test `npm test`, and
  `npm run build` passed. `npm audit --offline` reported zero known
  vulnerabilities; live `npm audit` could not resolve `registry.npmjs.org`.
- No Supabase/Stripe production mutation was performed.

## Unresolved risks

- D5 assigns backend ownership to a dedicated repository, but the owner has not
  named or recovered it. No production schema baseline or deployed Edge Function
  source is available here. The signed Stripe webhook path therefore remains
  unverified from source.
- Real Stripe test-mode evidence is still missing: app checkout to webhook-paid
  row, bidirectional web/app visibility, Connect completion, refund-to-the-cent,
  webhook replay/idempotency, and L-003 off-platform proof.
- D1/D2/D4 must be verified in the companion web repository; only this client's
  side and its portable contracts are present here.
- Mobile Stripe return links are configurable, but native universal/app-link
  association and store-policy review still require owner infrastructure.
- The canonical backend must prove booking defaults/triggers derive price,
  currency, lifecycle status, and payment status from identifiers exactly as
  the client contract now requires.
- Asset source records and the original contributor IP assignment remain owner
  items. `com.sporve.app` also requires final owner confirmation before stores.
- The previously documented compromised default-branch history still requires
  repository-owner incident review before any default-branch replacement.

## Prioritized next steps

1. Name and secure the dedicated backend repository; import the production
   baseline and every deployed function without writing to production.
2. Review recovered Stripe sources for signature verification, zero application
   fees, server-derived booking facts, entitlement webhooks, and idempotency.
3. Apply/verify the companion web D1/D2/D4 implementation against the same
   contracts and one staging row.
4. Run the full cross-surface Stripe test-mode matrix and record evidence in
   `docs/IMPLEMENTATION-PACK-STATUS.md`.
5. Complete owner provenance, asset-license, app-link, and store-identifier
   decisions; add the requested PR screenshot grid.

## Shutdown readiness

The Flutter client and safe mock localhost preview are ready for product review.
Production launch is not ready: backend reconstruction, cross-client parity,
Stripe test-mode evidence, governance/owner actions, and the default-branch
security review remain hard blockers. The local preview makes no real charges.

## Publish-readiness addendum — 2026-08-21

- Rechecked the exact publish tree after the subscription overhaul: analyzer
  clean, all 196 Flutter tests green, contract and billing validators green, and
  guarded web release/profile builds successful.
- Browser-tested the Family, Provider, Login, Pricing, Demo, session-detail, and
  booking surfaces. The sampled build has no application console exceptions;
  headless WebGL fallback and unused CanvasKit-preload warnings are non-blocking.
- Repaired stale Miami demo geography, duplicate city/state rendering, disabled
  search semantics, unlabelled core booking/payment controls, and the empty
  booking flow that exposed dates/times without a real server session. The
  featured program now has a future-relative session, and calendar/time actions
  are derived exclusively from real session rows.
- Added `docs/APP-QA-2026-08-21.md`, recording a 17/20 post-fix UI health score
  and the remaining daylight-theme, optional-Wasm, and native assistive-tech
  work.
- Scanned the current tree and reachable Git history for high-confidence secret
  patterns and sensitive credential filenames; no credential requiring history
  rewriting was found.
- The repository is already public. Publishing source does not deploy the app,
  mutate Supabase, contact Stripe, or satisfy the unresolved live-money gates.

### Addendum shutdown readiness

Source and the localhost mock preview are ready to publish. Production money
remains not ready until the canonical backend and Stripe sources are recovered,
the companion web client is aligned, and the documented Stripe test-mode matrix
passes bidirectionally.
