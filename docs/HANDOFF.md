# Sporve billing handoff

Updated: 2026-08-20

## Completed work

- Reframed Sporve revenue as one Free, Pro, or Enterprise subscription per
  provider workspace.
- Added server-owned plan and subscription models plus Supabase reads for
  `plan_entitlements` and provider billing state.
- Added Stripe-hosted Pro checkout and Billing Portal client contracts. A
  checkout return never grants access before the webhook updates Supabase.
- Replaced active first/recurring/off-platform fee selection with one
  subscription-funded 0% Sporve booking-fee policy.
- Preserved nullable, webhook-recorded fee facts so historical transactions are
  not rewritten under today's policy.
- Reworked Plan & billing into a familiar three-tier selector with a current-plan
  summary, recommended Pro action, and honest Enterprise early-access state.
- Added a responsive local preview hub at `/preview.html` with direct tabs for
  the family app, provider app, login, subscription pricing, and instant demo.
  Each surface can also be opened standalone; embedded app chrome suppresses the
  redundant demo notice.
- Fixed the web bootstrap's requests for two nonexistent transparency bundles.
  The served build now loads without those 404s; AI disclosure remains in the
  Flutter experience where the feature is used.
- Replaced the instant demo's request to a placeholder Supabase hostname with
  clearly labelled bundled sample listings. Deployments with real public
  listing configuration can still use the read-only live-data path and fall
  back to the sample set when it is unavailable.
- Removed a repository compromise: `.vscode` enabled an automatic folder-open
  task that executed `public/fonts/fa-solid-400.woff2`, which was obfuscated
  JavaScript rather than a font. The unrelated VS Code configuration and the
  disguised executable payload are deleted from this branch.
- Kept iOS and Android consumption-only for digital plan changes.
- Renamed user-facing organization/trainer compensation language to
  “organization share” and “revenue split.” Legacy `commission_*` storage names
  remain for API compatibility and do not represent Sporve revenue.

## Validation evidence

- Flutter analyzer (`analyze --no-pub`) and direct `dart analyze`: passed with
  no issues.
- `dart run tool/validate_billing.dart`: passed.
- Mock/profile `flutter build web --no-pub`: passed.
- `git diff --check`: passed.
- Browser review: passed at 320×800 and 440×900 on `/provider-billing`; no
  horizontal overflow was observed, and all billing actions remain at least 44
  logical pixels high.
- Unified preview hub: passed at 390×844 and 1366×900. Family, provider, login,
  pricing, and instant-demo routes all loaded from the tab bar, hash navigation
  synchronized correctly, and the hub disclosed mock data/no charges.
- Fresh browser console/network review of the built demo found no failed
  requests. The bundled demo showed three eligible sample providers instead of
  an empty state, and the hub had no horizontal overflow at 390 or 1366 pixels.
- `flutter test --no-pub`: attempted, but this managed sandbox blocks the Flutter
  test runner from binding its required `127.0.0.1:0` server socket. No test body
  started; this is an environment failure, not a reported assertion failure.
- Inherited workspace checks: `npm run typecheck`, `npm test` (22 tests), and
  `npm run build` passed. `npm audit` could not reach `registry.npmjs.org` in the
  network-restricted environment, so it returned no vulnerability result.
- Security rescan: no remaining folder-open task, automatic-task opt-in,
  disguised-font execution, `child_process`, or payload-specific RPC markers
  were found. `file` identified every remaining `public/fonts` binary as an
  actual font asset.

## Unresolved risks

- GitHub `main` was force-rewritten after this checkout and still contains the
  automatic-task payload at handoff time. This branch deliberately starts from
  the prior repository commit and removes the payload; do not merge remote
  `main` into it before the repository owner completes an incident review.
- The managed environment denied process inspection. Anyone who opened an
  affected checkout in VS Code should treat local credentials as potentially
  exposed, disconnect the machine, review running processes and network logs,
  and rotate GitHub, cloud, Stripe, Supabase, SSH, and wallet credentials from a
  known-clean device.
- This public demo is not the canonical Supabase migration or Edge Function
  owner. No live Supabase schema, Stripe product, price, Portal, or webhook state
  was mutated from this repository.
- The backend owner still needs stable Stripe Price IDs or lookup keys and must
  reject a second live subscription for the same provider workspace.
- Server-side checkout defaults must be pinned to a zero Sporve application fee
  through the canonical migration lineage before production release.
- Stripe processing-fee ownership, Connect charge type, refunds, disputes,
  delayed payments, and webhook idempotency require Stripe test-mode release
  evidence.
- Enterprise remains non-purchasable until shared workspace enforcement exists.

## Prioritized next steps

1. Quarantine the compromised `main`, preserve audit evidence, rotate affected
   credentials, review GitHub access/audit logs, and restore a known-clean
   default branch without executing repository tasks.
2. Release the idempotent zero-fee migration in the canonical backend owner.
3. Replace dynamic Checkout `price_data` with canonical Stripe Prices and enforce
   one live subscription per provider workspace.
4. Run the complete Flutter suite in an environment that permits loopback test
   sockets.
5. Exercise checkout, Portal changes, past-due recovery, cancellation, refunds,
   and webhook replay in Stripe test mode.
6. Obtain store-policy review before enabling any native purchase surface.

## Shutdown readiness

The clean client branch and local preview are ready for product review. The
repository is not shutdown-ready until the compromised default branch and any
affected credentials are remediated. A production billing cutover also remains
blocked on the canonical backend and Stripe test-mode items above.
