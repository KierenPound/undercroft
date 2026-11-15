| # | Test | Actor | Expected | Observed | Result | Note |
|---|---|---|---|---|---|---|
| S0 | Setup | - | - | 3 tokens obtained | PASS |  |
| S1 | Owner upload | A | allow | 200 | PASS | Database half: `s18_list.py` 'before' showed 4 rows against 4 objects (see summary) |
| S2 | Owner download | A | 200, bytes match | 200, sha match=True | PASS |  |
| S3 | Cross-estate download | C | deny | sign=400, GET=400 | PASS |  |
| S4 | Anonymous download | anon | deny | public=400, GET=400, sign=400 | PASS |  |
| S5 | Cross-estate upload | C | deny | 400 | PASS |  |
| S6 | Executor download | B | ALLOW | 200, sha match=True | PASS |  |
| S7 | Executor upload | B | deny | 400 | PASS |  |
| S8 | Executor replacement | B | deny | 400, original intact=True | PASS |  |
| S9 | Executor deletion | B | deny | 400, object still present=True | PASS | Pass depends on the object surviving; the status code alone can mislead |
| S10 | Replacement + retained URL | A | old object gone, old URL dead | old URL=400, re-sign old=400, v2 ok=True | PASS | Old URL died immediately on the later runs; one earlier run still served the deleted file straight after deletion (finding F-2). Database half: dashboard screenshots of the attachment row before/after replacement, plus the S18 'before' listing showing no orphan objects or dangling rows |
| S11 | Owner deletion | A | object gone, old URL dead | delete=200, old URL=400 | PASS | Old signed URL kept serving the deleted file for ~61 s and ~60 s on two runs before dying (finding F-2). Database half: as S10 |
| S13 | Oversized file (51 MB) | A | reject | 400 | PASS |  |
| S14 | Disallowed MIME (zip, docx) | A | reject | zip=400, docx=400 | PASS |  |
| S12 | Failed upload leaves no object | A | no orphan | leftovers=0 | PASS | Object half by `run_storage_tests.py`; database half by `s18_list.py` 'before' (no orphan objects, no dangling rows) |
| S15 | Signed-URL expiry (60 s) | A | live then dead | before=200, after=400 | PASS |  |
| S16 | Retained public URL | - | no access | 400 (proxy: public-route URL for a live test object) | PASS | A `download_url` stored in a database row was not fetched before the account was deleted, so this is recorded as a proxy test |
| S17 | Path traversal / crafted keys | C/A | deny, nothing created | codes=[400, 400, 400, 400, 400], stray=0 | PASS |  |
| S19 | Live bucket config | service | private / 50 MB / allowlist | public=False, limit=52428800, mime=['application/pdf', 'image/jpeg', 'image/png', 'image/heic', 'text/plain', 'video/mp4', 'video/quicktime', 'video/x-m4v', 'video/3gpp', 'video/webm'] | PASS | Allowlist includes video types (intended; matches repo SQL) |
| S18 | Cleanup on deletion | A | folder emptied incl. utilities/ and about-you/ | Run 4 (2026-11-15 19:41, estate 6d6a7fe4): 4 objects across about-you, sections, utilities before; after deletion 0 objects, estate row and all table rows gone | PASS | Collected with `s18_list.py` (init, before, tests, after, report: storage and database). Owner account deletion is the app's only deletion route. An earlier run failed and was fixed; see run history below |

## S18 run history

| Run | Time | Route | Before | After | Result |
|---|---|---|---|---|---|
| 1 | 2026-11-15 13:50 | Owner account deletion | not captured | 2 objects left under `sections/<sectionId>/` (1 video, 1 PDF) | FAIL (finding raised) |
| 2 | 2026-11-15 14:26 | Owner account deletion (after delete-code fix) | 2 objects, `sections/` only | 0 objects | Partial pass (`utilities/` and `about-you/` not populated) |
| 3 | 2026-11-15 18:05 | Owner account deletion | 4 objects across `about-you/`, `sections/`, `utilities/` | 0 objects, no subfolders | PASS |
| 4 | 2026-11-15 19:41 (estate 6d6a7fe4) | Owner account deletion | 4 objects across `about-you/`, `sections/`, `utilities/`; 4 DB rows referencing storage; no orphan objects, no dangling rows | 0 objects, no subfolders, estate row gone, no rows in any table | PASS (full evidence collector, test-script stage matched 'before') |

**Finding (resolved):** Initial account deletion left objects orphaned under `estate-documents/<estateId>/sections/<sectionId>/`. The deletion code was fixed and retested. A full retest with files in all three subfolders left 0 objects.

**Evidence files:** run 4 is in `evidence/s18_6d6a7fe4/` (`storage_18_init.txt`, `storage_18_before.txt`, `storage_18_tests.txt`, `storage_18_after.txt`, `s18_evidence_summary.md`). Runs 1 to 3: `storage_18_cleanup_before.txt` / `storage_18_cleanup_after.txt` and the earlier listings.

---

## Summary

**Item:** Review item 3, Supabase private-file storage
**Build:** versionName 1.0.0 / versionCode 20
**Environment:** Supabase production project (no staging exists)
**Test date:** 2026-11-15
**Method:** Scripted HTTP calls using real tokens for three accounts (A owner, B executor, C stranger) plus anonymous requests, with SHA-256 byte-integrity checks on downloads (`run_storage_tests.py`). S18 was run through the app, with staged storage and database snapshots from `s18_list.py` (init, before, tests, after, report).

### Result at a glance

All 20 test cases (S0 to S19) passed. S18 passed on retest after a defect was found and fixed, and passed again on a full run that also checked the database. The database halves of S1, S10, S11 and S12 are evidenced. Open items are listed at the end.

### What was demonstrated

- **The bucket is private** and the live configuration matches the repo, with a 50 MB limit and a MIME allowlist that includes video types (S19).
- **Access control holds at the object layer:** an authenticated stranger and an anonymous caller were denied download, signing and upload (S3, S4, S5).
- **Executors have read-only access:** download was allowed, while upload, replacement and deletion were denied, and the original object was confirmed intact afterwards (S6 to S9).
- **Owners can upload, download, replace and delete,** and downloaded bytes matched the original hash (S1, S2, S10, S11).
- **Signed URLs expire exactly:** a 60 s URL worked before expiry and was rejected afterwards (S15).
- **The stored public `download_url` does not grant access** to a private bucket (S16).
- **Server-side limits are enforced:** an oversized file and disallowed types (zip, docx) were rejected, and no objects were left behind (S12 to S14).
- **Crafted and traversal keys were denied** and created nothing (S17).
- **Account deletion empties storage** across `sections/`, `utilities/` and `about-you/`, and removes the estate and all its database rows (S18, after the fix below).

### Findings

| ID | Severity | Status | Description |
|---|---|---|---|
| F-1 | Medium | Resolved | Account deletion left objects orphaned under `estate-documents/<estateId>/sections/<sectionId>/` (1 video, 1 PDF). The deletion code was fixed. Retest with files in `sections/`, `utilities/` and `about-you/` left 0 objects. |
| F-2 | Low | Open | After an object is deleted, a signed URL issued beforehand can keep serving it for up to about a minute. Observed: ~61 s and ~60 s in S11 on two runs, and immediately after deletion in one S10 run (not reproduced in later S10 runs). Re-signing returned 404 throughout, so the object is removed at origin. Consistent with a cache of about 60 s, but the cause was not confirmed. Signed URLs are unguessable, issued only to authorised users, and expire within 1 hour. Optional mitigation: shorter signed-URL lifetimes for sensitive documents. |
| F-3 | Info | Resolved | The live bucket allowlist includes video types (mp4, quicktime, x-m4v, 3gpp, webm) that the original plan's F1 did not list. Video upload is intended and the repo SQL already matches. The original plan was not edited; it is superseded by the test scripts, whose expected allowlist includes the video types. |

### Residual notes

- The database stores a public-form `download_url` for a private bucket (S16 confirmed it grants no access). If the bucket were ever made public, every stored URL would become live, so keep the bucket private and treat any change to it as a security change.
- The `GRANT SELECT ON storage.objects TO anon` exists. S4 confirmed that anonymous callers are denied in practice. Revoking the grant would be a tidy-up.
- Not covered by this round: the `.jpg` extension applied to all About You uploads regardless of type (F13), and CDN caching behaviour beyond the lag seen in F-2.
- Test files were dummy or fictional, except where realistic filenames were used during S18. All objects were deleted by the account deletion under test.
- The `estate-documents` bucket also held four other estate folders (`4a442cfa`, `58907709`, `7adc69ef`, `b93e663f`) that were not part of this test and were not examined or changed.

### Open items at sign-off

- [x] Database-row checks. S1 and S12: `s18_list.py` 'before' showed 4 rows against 4 objects, no orphans, no dangling rows. S10 and S11: dashboard screenshots of the replaced and deleted attachment plus the same end state.
- [x] Screenshots: Table Editor screenshots of the attachment rows supplied (S10/S11 database half). Any other in-app screenshots are held by the tester.
- [x] Test accounts A, B and C deleted (A by the S18 test; B and C from Authentication > Users).
- [x] Objects from the first test estate (`8fe55a85-...`) confirmed gone: dashboard screenshot of the `estate-documents` bucket shows no `8fe55a85` folder. Folders for the other test estates (`2f6d3d82`, `2e205cc0`, `6d6a7fe4`) are also absent.
- [x] Temporary `service_role` SELECT grant revoked. Service key replaced with a placeholder in both scripts; test passwords and estate ID left in place deliberately (test accounts deleted).
- [x] Original plan not edited: F1, S14 and S19 are superseded by `run_storage_tests.py` and `s18_list.py` (allowlist includes video types) and by finding F-3.
- [x] S16 accepted as a proxy test (see S16 row).
- [ ] Legacy service key rotated or disabled (recommended: the key appeared in the test conversation while the script was being debugged). Not confirmed.

### Sign-off

| Field | Value |
|---|---|
| Tester | Kieren Pound |
| Date | 2026-11-15 |
| Accounts used | A (owner), B (executor), C (stranger); all deleted after testing |
| Overall result | PASS with findings F-1 (resolved), F-2 (open, low), F-3 (resolved). Accepted limitation: S16 recorded as a proxy test. Legacy service key rotation not confirmed. |
| Findings raised | F-1, F-2, F-3 |
| Evidence | `evidence/` folder (archived by tester); scripts `run_storage_tests.py` and `s18_list.py` |

