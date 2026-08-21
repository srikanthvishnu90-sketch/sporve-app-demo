# Sporve mobile app

**Every sport. One app.** Sporve is a youth-sports marketplace connecting
families and athletes with coaches, trainers, camps, and teams — with in-app
discovery, booking, and Stripe-hosted payments. This repository is the
production-intent Flutter mobile client plus a framed browser demo; it is not the
desktop web product and it is not the Supabase backend owner. `sporve-web` owns
the browser product. `SportsMan-main` is a legacy sibling whose production
relationship still requires owner confirmation; a dedicated backend repository
must become the one schema/function system of record before launch.

> **Live demo:** https://sporve.vercel.app/app/
> (hosted build of this app; browse as a guest, or sign in)

## What's here

```
lib/          Flutter app source (client + provider experiences)
web/          web shell (CSP, boot loader)
assets/       images, icons, policy copy
test/         widget + logic tests
contracts/    machine-readable cross-client product/API contracts
android/ ios/ native scaffolding
pubspec.yaml  dependencies
AUDIT-SUMMARY.md   candid public engineering review of this demo
docs/BILLING-SUBSCRIPTION-MIGRATION.md   workspace billing contract and release boundary
docs/HANDOFF.md   current billing implementation evidence and release risks
```

## What's intentionally NOT here

- The production Supabase **backend** — schema baseline and edge-function source.
- Any **secrets or environment values**. `env.example.json` shows the shape of
  the required config (public-safe keys only); the real `env.json` is not
  committed.
- Internal planning docs and a throwaway parity prototype.

## Stack

- **Flutter** (Dart) — iOS/Android are the product targets; web is the framed
  mobile-app demo described by D6.
- **State:** `provider` / `ChangeNotifier` for screen state; **GetX** for routing,
  snackbars, and key-value storage.
- **Backend (not in this repo):** Supabase (Postgres + Row-Level Security + Auth +
  Edge Functions), Stripe Connect for payments.

## Run it locally

```sh
flutter pub get

# Copy the example config and fill in your own PUBLIC Supabase keys:
cp env.example.json env.json   # then edit env.json

# Web (primary target):
flutter run -d chrome --dart-define-from-file=env.json

# Analyze / test:
flutter analyze
flutter test
```

The app renders inside a phone-width frame on wide screens and scrolls on short
viewports. `sporve-web` is the responsive desktop/browser surface.

For a complete local product tour, open `/preview.html` on the local web server.
The preview hub switches between the family app, provider workspace, login,
subscription pricing, and the non-transactional instant demo from one page.

## Honest status

The client implements the full family and provider surface, but release money
flows remain blocked until the dedicated backend repository proves the signed
Stripe webhook, schema baseline, test-mode checkout, Connect, payout, and refund
paths. Mock mode never fabricates a successful checkout or refund, and release
builds cannot select the mock repository. See **[AUDIT-SUMMARY.md](AUDIT-SUMMARY.md)**
and **[docs/HANDOFF.md](docs/HANDOFF.md)** for the current evidence and blockers.

No `.vscode/` configuration is committed; run arguments stay documented here.
The store identifiers are `com.sporve.app`. Source and bundled-asset terms are
recorded in [LICENSE](LICENSE) and [NOTICE](NOTICE).
