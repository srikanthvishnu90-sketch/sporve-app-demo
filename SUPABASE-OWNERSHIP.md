# Supabase ownership

Updated: 2026-08-20

`sporve-app-demo` is a Flutter client and does not own the production Supabase
schema or Edge Function source. D5 assigns those assets to one dedicated backend
repository whose final repository name must be confirmed by the research owner.

Until that owner is named and contains a production schema baseline plus every
deployed function source:

- production DDL/DML and `supabase db push` are forbidden from this repository;
- the two existing SQL files here are historical/pending evidence, not a truthful
  production migration ledger;
- `contracts/` records only client-observed API shapes and cannot prove deployed
  function behavior, Stripe webhook verification, or schema parity;
- any fresh-clone/backend-reconstruction acceptance item remains blocked.

No dashboard edits or production mutations were made during this implementation.
