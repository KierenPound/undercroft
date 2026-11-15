# UnderCroft — TestFlight test notes, build 39

`1.0.0 (39)`. Contents derived from the commit range between the build-38 bump
(`235a85a`) and the build-39 bump (`b5372f1`).

---

## 1. Paste into App Store Connect → TestFlight → Test Information → "What to Test"

```text
UnderCroft 1.0.0 (39)

What's new in this build

• Long video messages now upload reliably. Recording "My Video to You" and
  picking an existing clip from your library both compress the clip on the
  device first, so anything long enough to exceed the 50 MB limit still goes
  up. Please try a deliberately long clip, 3-5 minutes, and a clip picked
  straight from Photos, then play it back from the letter page.

• Shuffle no longer races. If a video in your playlist can't be played, the
  player now skips it and carries on, and stops with a message when nothing
  playable is left, instead of tearing through every remaining track in a
  burst. Worth trying with a playlist containing a bad or deleted video ID.

• The app lock stopped flashing. With the lock switched on (Settings >
  Privacy > Unlock with biometrics), opening any picker — a photo, a PDF, or
  a video — briefly covered the app with the "UnderCroft is locked" screen.
  That should be gone now.

• Playlist CSV download has a header row, so the file can be edited and
  re-uploaded without the first track being misread.

• The default video in the Legal Documents pages has been replaced.

What to focus on

1. Video: record a 3-5 minute clip and pick one from Photos. Confirm both
   reach the letter page, play back, and survive leaving and reopening the app.
2. App lock: turn it on, then attach a photo, a PDF and a video in turn. No
   lock screen should appear during the picker. Come back after the app has
   been in the background for over a minute and it should ask for biometrics
   once, normally.
3. My Songs: upload a playlist, play it, and try shuffle with a video that
   no longer exists in it.
4. Delete an account confirmation: the DELETE field should now open the
   keyboard in capitals and accept capitals only.

As always, please report anything that looks wrong with the screen you were
on and what you did just before, and send a screenshot if you can.
```

---

## 2. What is actually in build 39

| Commit | Change | Tester-facing? |
|---|---|---|
| `bbc5977` | Video compression before upload ([video_compression_service.dart](file:///Users/kierenpound/Developer/UnderCroft/lib/services/video_compression_service.dart), [my_letter_view.dart](file:///Users/kierenpound/Developer/UnderCroft/lib/views/my_letter_view.dart)) | Yes — new capability |
| `a5fb5bc` | CSV header row + uppercase-only delete confirmation | Yes — both |
| `01749c8` | Shuffle skips failed videos and stops with a message | Yes — bug fix |
| `e49fa63`, `4d312b5` | Default Legal Documents video replaced | Yes — content |
| `4d42bf5` | Dependency lockfile | No |
| `54d279b` | `material_ui` import migration + picker lock-flash fix | Yes — the lock-flash part is testable |
| `b5372f1` | Build number 39 | No |

Not user-visible but worth knowing: the Android Gradle Plugin moved to 9.1.1 and
the Material imports were migrated to `material_ui`. Both are plumbing, but they
touch nearly every widget file, so **the broadest regression risk in this build is
ordinary screen rendering** — open each section and confirm nothing looks off.

---

## 3. Things to tell testers, or not to

- **Testers can and should rehearse the purchase.** The Sandbox flow works and Restore
  sits on the same card, so it is worth asking them to walk it. My earlier draft said
  to keep testers away from it; that was wrong.
- **What a Sandbox purchase does not do is persist.** A purchase and a restore both set
  the in-session unlock only (`sessionInvitesUnlockedProvider`,
  [estate_service.dart](file:///Users/kierenpound/Developer/UnderCroft/lib/services/estate_service.dart#L165-L178)), so
  invitations open for that session and no durable row is written. Say so in the beta
  description, otherwise a tester who buys it and then finds it locked again the next
  day will report it as a bug.
- **Durable free access is `beta_free`, and it is a manual grant.** The app reads
  entitlement rows on start ([estate_service.dart](file:///Users/kierenpound/Developer/UnderCroft/lib/services/estate_service.dart#L148-L163))
  and the schema accepts `beta_free` for exactly this ([0035_create_handover_entitlements.sql](file:///Users/kierenpound/Developer/UnderCroft/supabase/migrations/0035_create_handover_entitlements.sql#L3-L15)),
  but nothing in the repo writes one: the table is `service_role` only, so each beta
  estate that should keep the handover needs a row inserted by hand. This is the
  mechanism that makes "beta testers keep it free" true
  ([MONETISATION.md](file:///Users/kierenpound/Developer/UnderCroft/MONETISATION.md#L81-L88)),
  and it needs an owner before launch or those testers will meet the paywall.
- **Do not wipe the database while external testers are on it.** It would delete their
  accounts and estates, and would take their `beta_free` rows with them.

---

## 4. I could not confirm

- **Whether build 39 was archived with `--beta`.** [newappios.sh](file:///Users/kierenpound/Developer/UnderCroft/newappios.sh#L54-L57) only includes the Developer tools
  section for TestFlight when `--beta` is passed. If it was not, the "Test Payment
  Logic" switch will be missing and the payment steps above cannot be followed at all.
  Worth checking before the notes go out.

Checked, so no longer a caveat: compression only kicks in above **25 MB**
(`compressThresholdBytes`, [video_compression_service.dart](file:///Users/kierenpound/Developer/UnderCroft/lib/services/video_compression_service.dart#L77-L84)),
with the 50 MB bucket limit as the hard ceiling. A 3-5 minute phone clip will be well
over 25 MB, so the "3-5 minutes" wording in the paste block does exercise the new path.
If you would rather testers not burn that much time, change it to "anything over about
30 seconds of HD video".
