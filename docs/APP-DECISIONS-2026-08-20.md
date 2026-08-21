# Sporve app decisions — 2026-08-20

The web pack remains the canonical home of D1–D3. It was not present in this
checkout; this file does not fork those decisions. D1's subscription/0% outcome
is implemented from the research owner's explicit instruction in this thread.

## D4 — Drop new booking tiers

New app bookings no longer write or offer `selected_tier`. Historical Pro/Elite
bookings keep their recorded price and render a historical tier label. No client
recomputes an old price from a multiplier.

## D5 — Dedicated backend repository

This Flutter repository is a client, not the system-of-record backend. The
dedicated backend repository name is still awaiting research-owner confirmation.
Until it is named and recovered, production schema/functions are an explicit
release blocker. Client-observed shapes live under `contracts/`.

## D6 — Keep the framed mobile demo

Flutter web remains a centered 440px mobile-app demo; `sporve-web` is the browser
product. Short viewports scroll the frame instead of clipping it.
