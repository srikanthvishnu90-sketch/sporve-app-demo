# Sporve — Demo (frontend)

**Every sport. One app.** Sporve is a youth-sports marketplace connecting
families and athletes with coaches, trainers, camps, and teams — with in-app
discovery, booking, and payments. This repository contains the **frontend of the
demo** (the Flutter app). The backend (Supabase schema, edge functions, payment
integration) is intentionally **not** included here.

> **Live demo:** https://sporve.vercel.app/app/
> (hosted build of this app; browse as a guest, or sign in)

## What's here

```
lib/          Flutter app source (client + provider experiences)
web/          web shell (CSP, boot loader)
assets/       images, icons, policy copy
test/         widget + logic tests
android/ ios/ native scaffolding
pubspec.yaml  dependencies
AUDIT-SUMMARY.md   candid public engineering review of this demo
```

## What's intentionally NOT here

- The Supabase **backend** — schema, migrations, and edge functions.
- Any **secrets or environment values**. `env.example.json` shows the shape of
  the required config (public-safe keys only); the real `env.json` is not
  committed.
- Internal planning docs and a throwaway parity prototype.

## Stack

- **Flutter** (Dart) — web is the primary target; iOS/Android scaffolding included.
- **State:** `provider` / `ChangeNotifier` for screen state; **GetX** for routing,
  snackbars, and key-value storage.
- **Backend (not in this repo):** Supabase (Postgres + Row-Level Security + Auth +
  Edge Functions), Stripe Connect for payments.

## Run it locally

```bash
flutter pub get

# Copy the example config and fill in your own PUBLIC Supabase keys:
cp env.example.json env.json   # then edit env.json

# Web (primary target):
flutter run -d chrome --dart-define-from-file=env.json

# Analyze / test:
flutter analyze
flutter test
```

The app renders inside a phone-width frame on wide screens, so the web build
keeps mobile proportions.

## Honest status

This is a **demo built to become the product** — the full surface (discover →
profile → book → confirm → upcoming) is real, but some pieces are simulated or
stubbed (e.g., provider payout history). See **[AUDIT-SUMMARY.md](AUDIT-SUMMARY.md)**
for a candid review of what works, what's rough, and what to fix. A separate
private security review covers the backend, payments internals, and child-safety
enforcement.
