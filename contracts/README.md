# Sporve client contracts

These files are the machine-readable cross-surface contract consumed by the
Flutter client. They record the 2026-08-20 subscription, trust, tier, status,
and backend-call decisions without claiming that this client repository owns
the production Supabase project.

Under app Decision D5, schema migrations and Edge Function source belong in one
dedicated backend repository whose final name still requires research-owner
confirmation. This repository must never run `supabase db push` or mutate
production. `backend_functions.json` and `backend_rpcs.json` therefore describe
what the client observes; they are not proof that the server implementations
exist or are safe.

`lib/core/generated/contracts.dart` is the checked-in Dart projection used by
deterministic client logic. `test/contracts_test.dart` prevents it from drifting
from `product_contracts.json`.
