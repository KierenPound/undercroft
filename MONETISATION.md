# UnderCroft Monetisation

This note records the pricing and packaging decision for the paid handover unlock.
It is a working decision, not a marketing page. Update it when the decision changes.

## Status

Decided, not yet built. Build it after the first round of beta feedback.

## What Is Paid

One **non-consumable** in-app purchase per estate: **"Complete the Handover"**.

It unlocks **all invitations** for that estate:

- executor invites (digital)
- co-owner invites
- the printed invite, for leaving in a desk or lodging with a solicitor

Everything else in the app stays free. The only thing behind the purchase is the
moment the owner brings someone else into the estate.

## Price

**£34.99**, one-off, per estate.

This is a starting point, not a commitment. The price lives in App Store Connect,
so it can be changed without shipping a new build.

## Why This Shape

- **Bundled, not per seat.** A will commonly names two or more executors, and
  people often want a spouse as co-owner. Charging per seat punishes exactly the
  situation the product exists for.
- **One gate, easy to explain.** "Bring everyone in." No second charge at the
  worst possible moment, and no support questions about which seat is which.
- **Generosity is the strategy.** We would rather people recommend it to their
  friends than feel taken to the cleaners. A single fair price, charged at the
  point of maximum value, does that.
- **Anchored to reality.** The natural comparison is a solicitor's hourly rate,
  so a one-off in the low tens reads as trivial against a completed handover.

## What We Are Not Doing

- No per-seat pricing.
- No subscription. This is something people set up once.
- No gating of the day-to-day app. The gate is only on invitations.

## Implementation Notes

- Must go through **Apple in-app purchase** (and Google Play billing on Android).
  Apple requires their system for unlocking digital features in-app — no Stripe
  for this.
- **Non-consumable**, so *Restore Purchases* is required and meaningful.
- Anticipated entitlement shape: a single boolean per estate, e.g.
  `estates.handover_unlocked`. Keep the check in one place — the invitation entry
  points (`inviteExecutor` and `inviteOwner` in
  `lib/services/estate_service.dart`, plus `lib/services/invite_print_service.dart`)
  — so the digital and printed routes share the same gate.
- **TestFlight purchases are free and sandboxed**, so testers can rehearse the
  real purchase flow without being charged.
- Revoking entitlement on refund needs server-side receipt validation and App
  Store Server Notifications. Not a beta concern.

## Testing Without Paying

The existing developer toggle in Settings ("Act as Executor") plus the invite code
generation let the gated flow be exercised before any billing code exists.

## Signal To Watch

Testers evaluating it for setting up their own estates — family friends included —
are the closest thing to a real customer read. If £34.99 is clearly too low, or
nobody flinches, revisit. Changing the price does not affect people who have
already bought.
