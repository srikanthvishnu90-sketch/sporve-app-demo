# Sporve Design System

## Theme

Sporve uses a restrained product interface with an obsidian dark theme today.
The production system must also provide a genuine light/daylight theme; changing
dark gray values alone does not satisfy field usability.

## Color

- Canvas: `AppColors.ink`
- Surfaces: `surface`, `surface2`, `surface3`
- Primary action and selection: `slate`
- Destructive actions only: `destructiveRed`
- Verified trust evidence only: `trustGold`
- Sport colors identify sport context, not generic decoration
- Text contrast targets WCAG 2.2 AA in every state

Flutter tokens in `lib/core/theme/app_colors.dart` are authoritative.

## Typography

Inter is the only product typeface. Use the scale in
`lib/core/theme/app_typography.dart`. Body copy is at least 13 logical pixels;
interactive labels remain readable under text scaling. Reserve compact labels
for metadata, not instructions or essential status.

## Components

- Interactive targets: minimum 44-by-44 logical pixels
- Primary actions: shared `SporveButton`
- Loading: geometry-matched skeletons
- Errors: plain description plus a recovery action
- Empty states: explain what is absent and provide one relevant next action
- Focus, hover, pressed, disabled, loading, and error states are mandatory
- Cards use full borders or surface separation, not decorative side stripes
- Billing uses a familiar Free/Pro/Enterprise comparison: current state first,
  one primary upgrade action, server-sourced prices, and explicit 0% Sporve
  booking-fee copy

## Layout

Mobile-first, safe-area aware, and usable at 320 logical pixels and at 200%
text scaling. Desktop framing must not hide functionality. Long prose stays
within 65-75 characters per line.

## Motion

State-oriented motion at 150-250ms. Reduced-motion preference removes
non-essential movement. Content is visible without animation completion.

## Content

Copy states only capabilities supported by deployed systems and operating
processes. “Verified” must identify the verification type. Payment copy names
Stripe-hosted checkout without promising security, encryption, refunds, or price
guarantees beyond the recorded transaction facts.
