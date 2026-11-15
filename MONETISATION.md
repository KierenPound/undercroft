# UnderCroft Monetisation

This note records the pricing and packaging decision for the paid handover unlock.
It is a working decision, not a marketing page. Update it when the decision changes.

## Status

The TestFlight purchase flow has been exercised with an Apple Sandbox purchase.
The app currently unlocks invitations for that session only. Migration `0035`
adds durable, per-estate entitlement records, but a trusted store-verification
function and production purchase grants are still required before launch.

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
- Entitlement records live in `estate_handover_entitlements`, one row per
  estate. The source distinguishes `beta_free`, `app_store`, and `google_play`.
  Authenticated clients may read whether their estate has a row but cannot
  grant or edit one; trusted backend/admin code writes grants.
- Keep the check in one place — the invitation entry
  points (`inviteExecutor` and `inviteOwner` in
  `lib/services/estate_service.dart`, plus `lib/services/invite_print_service.dart`)
  — so the digital and printed routes share the same gate.
- The current test gate is UI-only. Before charging customers, enforce the
  entitlement in the trusted invite-creation path too; do not rely on a
  disabled button or a client-side purchase callback.
- **TestFlight purchases are free and sandboxed**, so testers can rehearse the
  real purchase flow without being charged.
- A store callback in the app is not sufficient proof of payment. Apple and
  Google grants must be validated by trusted server code before writing an
  `app_store` or `google_play` entitlement. Refund revocation needs server-side
  transaction status checks / store notifications before public launch.

## Testing Without Paying

The existing developer toggle in Settings ("Act as Executor") plus the invite code
generation let the gated flow be exercised before any billing code exists.

## Beta Testers Get It Free

Decided: testers who set up an estate and complete their handover during the beta
keep it, and are not charged when the gate ships.

This is fair rather than generous. They did the work of testing, and reaching the
end of the setup flow is the clearest signal we could ask for. Three consequences to
hold in mind:

- The gate is checked when an invite is created. Invites already `accepted`
  during the beta stay accepted, so those handovers cannot be re-gated later.
- Testers **can** rehearse the purchase, and should. The Sandbox flow works end to
  end and *Restore* sits on the same card, so the checkout is worth exercising and
  testers should not be told to avoid it.
- What a Sandbox purchase or a restore does **not** do is persist. Both set the
  in-session unlock only (`sessionInvitesUnlockedProvider`), so a tester who buys the
  unlock in TestFlight still meets the paywall on the live app. That is expected
  behaviour, not a defect, and the beta description should say so before a tester
  reports it as one.
- If a beta tester does try a Sandbox purchase, record any permanent beta
  access as `beta_free`, not as an `app_store` payment. The Sandbox transaction
  is useful for checking checkout, but it is not a real charge and does not
  automatically create the durable entitlement row.

### Granting `beta_free`

Beta grants are made by trusted admin/backend code, and **nothing in the repo writes
one yet**. The table is `service_role` only — an authenticated client can read
`estate_id` and nothing else — so every beta estate that should keep the handover needs
a row inserted by hand. Until that happens, the promise above is not real for that
tester.

Preview which estates are missing a grant:

```sql
SELECT e.id, e.name, ent.source
FROM public.estates e
LEFT JOIN public.estate_handover_entitlements ent ON ent.estate_id = e.id
WHERE ent.estate_id IS NULL
ORDER BY e.name;
```

Grant `beta_free` to every estate that has no row:

```sql
INSERT INTO public.estate_handover_entitlements (estate_id, source)
SELECT e.id, 'beta_free'
FROM public.estates e
WHERE NOT EXISTS (
    SELECT 1 FROM public.estate_handover_entitlements ent
    WHERE ent.estate_id = e.id
)
ON CONFLICT (estate_id) DO NOTHING;
```

That reaches every estate, including scratch and test estates. To keep it to named
testers, add `AND e.name IN ('...')` to the inner select.

Granting early is harmless: the client-side gate only closes when the Developer tools
section has put it there, so a release build ignores these rows until the paywall is
switched on for real.

Testers reachable at the time of writing: 10 estates exist, 1 has a `beta_free` row
(Demo Estate, granted 2026-11-12), 9 do not.

If that ever needs revisiting, the honest lever is a free unlock for a named list
of beta estates, not a change to the price.

## Launch Constraints

Two things must not change between the beta and the App Store release, or beta
testers lose their accounts and estates:

- **One Supabase project throughout.** The dart-defines are baked into the
  archive from `supabase_config.json`. Standing up a separate "production"
  project at launch would orphan every account, estate and invite created during
  the beta. Keep pointing at the same project.
- **No database wipes once external testers are on it.** Rebuilding the schema
  and re-seeding is fine during solo testing, but it deletes real testers'
  accounts and estates, with no way for them to recover.

## Signal To Watch

Testers evaluating it for setting up their own estates — family friends included —
are the closest thing to a real customer read. If £34.99 is clearly too low, or
nobody flinches, revisit. Changing the price does not affect people who have
already bought.
