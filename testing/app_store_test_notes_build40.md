# UnderCroft — TestFlight test notes, build 40

`1.0.0 (40)`. Contents derived from the commit range between the build-39 bump
(`b5372f1`) and `HEAD` (`47834f1`).

This build has **no changes to the app itself**. It exists to carry the
back-end consolidation onto the same binary testers already have, so the notes
below are deliberately short.

---

## 1. Paste into App Store Connect → TestFlight → Test Information → "What to Test"

```text
UnderCroft 1.0.0 (40)

What's new in this build

• Nothing has changed in the app. This is a back-end housekeeping release: the
  services behind the support form and the artwork-request form were moved onto
  a single server. There are no new screens and no visible changes, so the app
  should behave exactly as it did in build 39.

What to focus on

1. Support ticket. Open Settings > Support & legal > Support. A short form
   opens in your browser. Fill it in (name is optional; email, subject and a
   message are required) and submit. You should see "Thank you — your support
   ticket has been submitted." Please try one with a screenshot attached, and
   one without. If you get "We could not send your ticket just now" instead,
   tell us straight away.

2. General check that everything still loads. Sign in, open your estate, and
   open a letter containing a photo, a PDF and a video. Confirm they still
   display and play, and that your songs still play.

As always, please report anything that looks wrong with the screen you were on
and what you did just before, and send a screenshot if you can.
```

---

## 2. What is actually in build 40

| Commit | Change | Tester-facing? |
|---|---|---|
| `84853f7` | Consolidate Supabase onto the UnderCroft project — support/artwork-request tables, edge functions and the reminder cron | No — server-side only |
| `47834f1` | `pubspec.lock` and regenerated Windows plugin files from `flutter pub get` | No |
| `b6e6fd6` | Add App Store notes, commit storage-test evidence, drop a dead ignore rule | No |

No file under `lib/` or `ios/` changed between `b5372f1` and `HEAD`, so the
installed app is behaviourally identical to build 39. The only runtime change a
tester can reach is where the support form's data goes.

---

## 3. Things to tell testers, or not to

- **The support form is a web page, not part of the build.** Settings > Support
  opens `https://crabkingslair.com/support` in the browser, so it behaves the
  same on any installed build. The reason to re-test it now is that its
  back-end was repointed: a submission that used to land in the old project now
  lands in the new one, and the notification email is sent by the new service.
- **Nothing about a tester's own data changed.** Estates, letters, attachments
  and songs stay where they were. Only the support / artwork-request side moved.
- **Artwork requests are not an iOS tester task.** That form is on the
  CrabKingsLair website, used by the artwork team, and is not reachable from the
  app.
- **If you archive with `--beta`,** the Developer tools section and the "Beta
  build" marker appear in Settings. That is expected and unrelated to this
  change.

---

## 4. Could not confirm

- **Whether the artwork-request notification email is arriving.** The support
  email was confirmed end-to-end today; the artwork-request email shares the
  same mechanism and was set up at the same time, but delivery to its inbox has
  not been confirmed. Not an iOS tester concern, but worth checking before the
  old project is deleted.
- **Whether this build is archived with `--beta`.** [newappios.sh](file:///Users/kierenpound/Developer/UnderCroft/newappios.sh#L54-L57)
  only shows Developer tools for TestFlight when `--beta` is passed. Nothing in
  this release needs them, so either is fine.
