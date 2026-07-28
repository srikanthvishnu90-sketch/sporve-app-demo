# Sporve Demo — Public Audit Summary

**Date:** 2026-07-28 · **Scope:** the Sporve Flutter web demo (frontend).
**Stance:** a candid engineering review. Strengths are noted where they change
the risk picture; the body is what should improve.

> **Note on scope.** This is the *public* summary. It covers the design system,
> frontend architecture, product concept, documentation honesty, and
> accessibility/fairness. A separate, **private** security review (backend
> access control, payments internals, secret handling, and child-safety /
> COPPA enforcement) was delivered directly to the maintainers and is **not**
> published here — this is a live product handling minors' data, so those
> findings follow responsible-disclosure rather than public posting.

---

## Verified strengths (measured, not flattery)

- **Zero leaked secrets.** No server secret is committed or embedded anywhere in
  the frontend or the compiled bundle; only public-safe keys ship to the client.
- **Payments are server-authoritative and idempotent** — amounts/fees are
  derived server-side from the database, never from the client; no card data or
  secret ever touches the app.
- **Row-Level Security is on for every table.**
- **Clean architecture swap-point** — 0 presentation files reach past the
  repository interface into mock data; the mock→real backend swap is one binding.
- **`flutter analyze` is clean and the test suite passes (70/70)**, including
  real error-state and safety-gate tests.
- **Honest empty/loading/error states** — real "nothing yet" states and skeleton
  loaders, not fake data.

The engineering craft is real and, in several dimensions, above its stage. The
findings below are quality and honesty gaps, not a house of cards.

---

## 1 — Design system / color / UI

- **Contrast:** the brand slate `#475569` is used as foreground text/icon on the
  black canvas in ~140 places (≈2.5–2.77:1, below WCAG AA's 4.5:1). Add a lifted
  slate for foreground; keep `#475569` as a fill-with-white-text only.
- **Semantic collapse:** `blue`, `positive`, `warning`, `slate`, `entryWall` are
  all literally the same `#475569`, and `negative` equals `textTertiary`. A
  confirmation, a warning, a link, and an error render identically — for a
  product moving money, errors that don't look like errors is a real UX defect.
- **Docs vs. reality:** the "three-font system" (Inter / Hanken / JetBrains) is
  Inter everywhere — the selection ternary has identical branches. Bold weight is
  globally suppressed (`w700+ → w600`), flattening intended hierarchy.
- **Token discipline drift:** ~29 raw `Color(0x…)` hexes in the two AI screens
  (including a reserved AI-blue that no longer exists in the palette) and several
  ad-hoc radii (30/32/36/50) that exceed the tight-radius token system.
- **Responsive:** a fixed 440px phone-frame with a hard `≤480` breakpoint and no
  short-viewport scroll fallback — fine for a demo, not a product.
- **Minor:** an external Unsplash hotlink bypasses the image error wrapper; a
  `debug/` palette screen ships with stale hex labels.

## 2 — Frontend architecture

- **Silent failures:** 9 swallowed catches (5 fully empty `catch (_) {}`) hide
  network/permission errors as "nothing happened," some around data writes.
- **Two-data-shape landmine:** the codebase carries both Flutter string keys and
  Supabase numeric columns for the same fields; every reader must remember both.
  There is no single normalization layer, so the next field re-introduces the
  bug. Add one adapter at the repository boundary.
- **Dual state system breadth:** the Provider-for-state / GetX-for-routing split
  is coherent, but 152 GetX call sites entangle navigation with business state
  and make a future migration costly and testing harder.
- **God-object repository:** the swap-point class is ~2,000 lines mixing many
  concerns; split into per-aggregate repositories behind the existing interface.
- **Best-effort AI with silent fallback:** an "AI headline" step falls back to a
  local truncation on any error with no health signal — correct only if the
  remote function is actually deployed.
- **Housekeeping:** a rollback-only unused import and a parity prototype/dead
  folder clutter the diligence surface.
- **Strength:** repository swap-point discipline is genuinely clean (0 direct
  mock-data reads); analyze clean; 70/70 tests pass.

## 3 — Product concept

- **The trust model is asserted, not built:** "background-checked coaches" is the
  entire wedge, but there is no screening-vendor integration or verification
  workflow in the code — it's a status enum someone sets by hand. The concept
  only works if verification is real, gating, and universal.
- **Two-sided cold-start:** the marketplace needs vetted supply before families
  find value; here supply appears only as a waitlist. Verification throughput
  becomes the growth bottleneck at scale.
- **AI value vs. risk is inverted:** the strongest AI surface (ranked match) is a
  deterministic formula in the canonical build, while the genuinely generative
  surface is the least constrained — the opposite of the safe configuration.
- **Payout loop:** booking + payment are real, but provider payout history is a
  labeled stub — the "coach gets paid" loop isn't demonstrably closed.
- **One intensity model across 20+ sports** ("Every sport. One app.") will
  misclassify safety for some sports; this axis is already fragile.
- **Operational risk:** correctness depends on humans remembering which of two
  source trees owns functions and schema — an accident waiting to happen.

## 4 — Accessibility & fairness

- **Accessibility exclusion:** near-total absence of `Semantics` (~9 across the
  presentation layer vs. 126 tap targets and 29 icon-only buttons), likely
  sub-48px tap targets, suppressed bold, and the AA-failing slate foreground
  together exclude low-vision and screen-reader users.
- **Unaudited ranking bias:** matching weighs rating, review count, and distance.
  Rating shrinkage helps low-review coaches, but new/rural/less-reviewed coaches
  are structurally down-ranked and distance weighting can encode socioeconomic
  geography. A marketplace deciding who gets seen needs an explicit fairness
  review — and any "founding coach placement" incentive must never override
  safety gating.

## 5 — Documentation honesty (doc-vs-code mismatches)

The most corrosive category for diligence trust: the code contradicts its own
documentation in several load-bearing places.

- The design docs describe a "deep teal" system; the code is slate.
- The docs say "auth is mock"; it's real authentication.
- "AI matching" is deterministic in the canonical build.
- The "three-font system" is Inter-only; "blue reserved for AI" no longer maps to
  any token yet the color still appears as raw hex.
- "Secured by Stripe" is honest on the real path but shows a fully simulated
  payment under the offline demo flag — any recorded demo must disclose its mode.

**Fix (cheap, high-value):** update the docs to match the code. Stale docs are
actively misleading, and none of these are rewrites.

---

## Priority order (engineering-quality track)

1. Fix design-system contrast + semantic collapse (lifted slate foreground;
   distinct positive/warning/negative).
2. Add one repository-boundary normalization layer for the two data shapes.
3. Replace silent catches with logging + user-facing retry.
4. Collapse to a single source of truth for the codebase; add a CI check that
   every client-invoked function name maps to a real deployed function.
5. Update all documentation to reflect the real design system, auth, AI, and fonts.
6. Add `Semantics`, fix tap-target sizes, and commission a ranking-fairness review.

*(Security, payments-internals, and child-safety/COPPA findings are covered in
the private report shared with the maintainers.)*
