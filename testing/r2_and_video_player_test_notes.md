# UnderCroft — Test notes: R2 media storage + "My Video to You" player refresh

Covers the media-storage migration to Cloudflare R2 (build 43) together with
the "My Video to You" player size/look-and-feel refresh that followed it.
These two changes touch the same clip on the **My Letter to You** page, so
they are tested together here.

---

## 1. Paste into App Store Connect → TestFlight → Test Information → "What to Test"

```text
UnderCroft

What's new in this build

• Photos, PDFs and the "My Video to You" clip now use Cloudflare R2 for
  storage instead of Supabase Storage. The file-size limit has been raised
  from 50 MB to 150 MB, so a longer video message no longer needs to be
  trimmed down. Nothing about how you attach or view files changes, but the
  storage underneath is new — please try uploading and re-opening a photo,
  a PDF and a video to confirm they all still work.

• "My Video to You" on the My Letter to You page has been reworked. The clip
  is now larger and square, sitting in the middle of the section with the
  description underneath it. The Record / Replace, Choose and Remove
  buttons are now a single row beneath the clip, in the same style as the
  Support button. On desktop/web the video's play and scrub controls only
  appear when you move the mouse over the clip, so the video stays clean
  until you need them.

What to focus on

1. Video message (My Letter to You). Record a short clip with the camera
   and also pick one from your library. Confirm both upload, play back, and
   are still there after leaving and reopening the app. Try a longer clip
   (over 25 MB) to exercise compression and the new 150 MB limit.
2. Video player look and feel. The clip should be a large square in the
   middle, with the note beneath it and the three action buttons (Record or
   Replace, Choose, and Remove) in a row underneath, styled like the
   Support button. On a phone the play controls should be visible; on a
   computer they should only show while the mouse is over the video.
3. Photos and PDFs. Upload a photo and a PDF into any section, reopen the
   app, and confirm they still display. Delete one and confirm it is gone.
4. Cross-estate privacy (quick check). If you have a second account that is
   not a member of this estate, sign in as it and confirm it cannot see or
   open this estate's files.

As always, please report anything that looks wrong with the screen you were
on and what you did just before, and send a screenshot if you can.
```

---

## 2. What is actually changing

### 2a. Media storage migrated to Cloudflare R2

| Area | Before | After |
|---|---|---|
| Storage backend | Supabase Storage (`estate-documents` private bucket) | Cloudflare R2, via Supabase Edge Functions |
| File size limit | 50 MB (server-enforced) | **150 MB** (`MediaStorageService.maxUploadBytes`) |
| Access control | Supabase Storage RLS policies keyed on estate UUID in the path | Edge Functions authenticate the caller and check estate membership before issuing upload/download/delete URLs |
| What moves | Photos, PDFs, utility attachments, About-You photo, and the "My Video to You" clip | All media bytes now live in R2; database rows still hold the R2 key |

Key implementation facts:

- `MediaStorageService` ([media_storage_service.dart](file:///Users/kierenpound/Developer/UnderCroft/lib/services/media_storage_service.dart)) replaces every direct `supabase.storage.from(...)` call.
- Three Edge Functions handle R2: `r2-upload-url`, `r2-download-url`, `r2-delete` ([supabase/functions/](file:///Users/kierenpound/Developer/UnderCroft/supabase/functions)).
- Estate-based access: every request carries the estate id; the function verifies the caller is a member (owner or accepted executor) before signing an R2 URL.
- Signed download URLs are cached client-side with the same 1-hour TTL and 5-minute renewal margin as before.
- 32 legacy files (Kieren, Angie, Wendy estates) were migrated from Supabase Storage to R2 in a one-off step; the migration tooling has been removed.

### 2b. "My Video to You" player refresh

All in [my_letter_view.dart](file:///Users/kierenpound/Developer/UnderCroft/lib/views/my_letter_view.dart) (`_VideoToYouSection`, `_VideoNote`, `_VideoButtons`, `_VideoActionButton`, `_VideoPlayerBox`):

- **Layout:** the clip is now a **larger, square (1:1)** player, centred and capped at 320 px wide. The explanatory note sits directly **beneath** it at the same width (previously the note was a cramped column beside a tall portrait clip).
- **Buttons:** Replace (or Record when no clip exists), Choose, and Remove are now a **single horizontal row** of equal-width buttons spanning the frame width. They use the standard `OutlinedButton.icon` style (same as the Support button in Settings) with appropriate icons — refresh / video-cam, video-library, and delete. Remove is tinted red.
- **Player controls (desktop/web):** the Chewie play / scrub / fullscreen overlay is **hidden by default and only appears while the pointer is over the video**, then fades out ~1.2 s after the pointer leaves. On touch devices (iOS/Android) the controls stay visible from the start, since there is no hover.
- Chewie itself was introduced in the R2 commit (replacing the bare `VideoPlayer` + manual play button), giving play/pause, seek, mute and fullscreen.

---

## 3. Test cases

These combine the R2 storage verification with the player UI checks. **All test
documents must be fictional** — no real wills, deeds, certificates or ID
images.

### Storage (R2)

| # | Test | Expected |
|---|---|---|
| R1 | Owner uploads a photo | Upload succeeds; photo displays after refresh |
| R2 | Owner uploads a PDF | Upload succeeds; PDF opens/read-only view works |
| R3 | Owner records / picks a video (under 25 MB) | Upload succeeds; plays back from the letter page |
| R4 | Owner picks a video **over 25 MB** | Client-side compression runs; upload succeeds and plays back (exercises the compression path + 150 MB ceiling) |
| R5 | Owner attempts a file **over 150 MB** | Rejected with a clear "too large" message |
| R6 | Owner replaces a video / photo | New file displays; old file is no longer retrievable |
| R7 | Owner deletes a video / photo / PDF | File and row both removed; a previously-issued download URL no longer serves it |
| R8 | Cross-estate access (authenticated stranger) | Cannot list, download, upload to, or delete another estate's files — estate membership is enforced in the Edge Function |
| R9 | Anonymous access (no session) | Denied — no R2 URLs issued |
| R10 | Data survives restart | Reopen the app; all previously uploaded media still displays |

### Player UI ("My Video to You")

| # | Test | Expected |
|---|---|---|
| P1 | No clip yet | Empty square placeholder shown; buttons read **Record**, **Choose** (Remove hidden) |
| P2 | Clip present | Square video plays; buttons read **Replace**, **Choose**, **Remove** |
| P3 | Note placement | Explanatory text is directly beneath the video, same width |
| P4 | Button row | Three buttons in one row, equal width, same outline style as Settings → Support |
| P5 | Remove button | Tinted red; removes the clip and returns to the empty placeholder |
| P6 | Desktop/web controls | Play/scrub/fullscreen overlay hidden until the mouse moves over the video; fades out ~1.2 s after the pointer leaves |
| P7 | Mobile controls | Play/scrub controls visible from the start (no hover on touch) |
| P8 | Fullscreen | Fullscreen button works and returns to the inline player |

---

## 4. Known limitations and things to tell testers

- **150 MB is the hard ceiling.** The 50 MB limit is gone; a clip up to 150 MB is accepted. Anything over it is rejected client-side before upload.
- **Compression still only kicks in above 25 MB** (`compressThresholdBytes` in [video_compression_service.dart](file:///Users/kierenpound/Developer/UnderCroft/lib/services/video_compression_service.dart)), so short clips upload uncompressed.
- **R2 access is estate-scoped in the Edge Functions.** The old Supabase Storage RLS policies are no longer the enforcement point for media; the signed-URL functions are. Cross-estate isolation (R8/R9) is the key security regression to verify.
- **32 legacy files were migrated.** Existing media for the Kieren, Angie and Wendy estates should still display — if any are missing, the migration missed them.
- **The player is square (1:1).** Portrait clips are letterboxed inside the square; this is intentional so the controls are easy to reach. Fullscreen (P8) is the way to see a clip at its native aspect ratio.

---

## 5. Results table (to complete during execution)

| # | Test | Expected | Observed | Pass/Fail |
|---|---|---|---|---|
| R1 | Owner photo upload | success + displays | | |
| R2 | Owner PDF upload | success + opens | | |
| R3 | Owner short video | success + plays | | |
| R4 | Owner long video (>25 MB) | compresses + plays | | |
| R5 | File >150 MB | rejected | | |
| R6 | Replace media | new shows, old gone | | |
| R7 | Delete media | removed | | |
| R8 | Cross-estate access | denied | | |
| R9 | Anonymous access | denied | | |
| R10 | Survive restart | still displays | | |
| P1 | Empty placeholder | Record / Choose | | |
| P2 | Clip present | Replace / Choose / Remove | | |
| P3 | Note under video | same width | | |
| P4 | Button row | like Support button | | |
| P5 | Remove | red, removes clip | | |
| P6 | Desktop hover controls | show on hover | | |
| P7 | Mobile controls | visible from start | | |
| P8 | Fullscreen | works | | |

---

## 6. Sign-off

| Field | Value |
|---|---|
| Tester | |
| Date | |
| Accounts used | |
| Overall result | |
| Findings raised | |
