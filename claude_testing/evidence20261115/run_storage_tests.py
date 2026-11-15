#!/usr/bin/env python3
"""
UnderCroft - Supabase private-file storage tests (automates S0-S17, S19 where possible).

Setup:
    pip install requests

Environment variables (set in your shell, never commit them):
    SUPABASE_URL          https://<project>.supabase.co
    SUPABASE_ANON_KEY     the anon/public key (same one the app ships with)
    ESTATE_ID             UUID of account A's estate
    A_EMAIL / A_PASSWORD  owner
    B_EMAIL / B_PASSWORD  accepted executor of A's estate
    C_EMAIL / C_PASSWORD  authenticated stranger (not in A's estate)
Optional:
    DOWNLOAD_URL          a download_url value copied from a DB row (for S16)
    SUPABASE_SERVICE_KEY  service-role key, ONLY to read bucket config (S19).
                          Skip it and check the bucket in the dashboard instead.

Run:
    python run_storage_tests.py

Output: ./evidence/storage_NN_*.txt and ./evidence/RESULTS.md
All test files are fictional dummy bytes. Test objects are deleted at the end.
Invite code 5DTR3Q
"""
import os, sys, time, hashlib, pathlib, uuid
import requests
# ---- Test configuration (edit these) ----
CONFIG = {
  "SUPABASE_URL": "https://mpsygpgaakdtlgjzmbtr.supabase.co",
  "SUPABASE_ANON_KEY": "sb_publishable_Bx3raJCiddF7J35h8fl0IA_i5TWsP0I",
    "ESTATE_ID": "6d6a7fe4-28d3-4f53-b6a8-a6145f6f90a0",
    "A_EMAIL": "claude_owner@test.com",
    "A_PASSWORD": "test1234",
    "B_EMAIL": "claude_executor@test.com",
    "B_PASSWORD": "test1234",
    "C_EMAIL": "claude_random@test.com",
    "C_PASSWORD": "test1234",
    # Optional:
    "DOWNLOAD_URL": "https://mpsygpgaakdtlgjzmbtr.supabase.co/storage/v1/object/public/estate-documents/estate-documents/8fe55a85-0bd7-4cc3-b35c-50ba1c57c5bc/sections/ee08d326-e27f-497a-89ec-8229d90b2014/1794744168371_will_1_kieren_tom_insolvency.pdf",
    "SUPABASE_SERVICE_KEY": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1wc3lncGdhYWtkdGxnanptYnRyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTI5Njg0MiwiZXhwIjoyMTA2ODcyODQyfQ.zuTsZA2XacT_TKOiI-fQrspjqL7JBLLMq_15wIdqDbk",
}
for _k, _v in CONFIG.items():
    os.environ.setdefault(_k, _v)
URL = os.environ["SUPABASE_URL"].rstrip("/")
ANON = os.environ["SUPABASE_ANON_KEY"]
ESTATE = os.environ["ESTATE_ID"]
BUCKET = "estate-documents"
ST = f"{URL}/storage/v1"
OUT = pathlib.Path("evidence")
OUT.mkdir(exist_ok=True)
STAMP = time.strftime("%Y%m%d-%H%M%S")

results = []
created = set()


def sha(b):
    return hashlib.sha256(b).hexdigest()


def redact(u):
    return u.split("?token=")[0] + ("?token=<redacted>" if "?token=" in u else "")


class Case:
    def __init__(self, num, slug):
        self.num, self.slug, self.lines = num, slug, []

    def log(self, t):
        self.lines.append(t)

    def save(self):
        (OUT / f"storage_{self.num:02d}_{self.slug}.txt").write_text("\n".join(self.lines) + "\n")


def rec(sid, name, actor, expected, observed, ok, note=""):
    res = "MANUAL" if ok is None else ("PASS" if ok else "FAIL")
    results.append((sid, name, actor, expected, observed, res, note))
    print(f"{sid:4} {res:6} {name} -> {observed}")


def call(c, actor, method, url, tok=None, headers=None, **kw):
    h = {"apikey": ANON, "Authorization": f"Bearer {tok or ANON}"}
    h.update(headers or {})
    r = requests.request(method, url, headers=h, timeout=300, **kw)
    c.log(f"[{time.strftime('%H:%M:%S')}] {actor}: {method} {redact(url)}")
    ct = r.headers.get("content-type", "")
    body = r.text[:400] if ct.startswith(("application/json", "text/")) else f"<{len(r.content)} bytes binary>"
    c.log(f"  -> HTTP {r.status_code}  {body}")
    return r


def login(prefix):
    r = requests.post(
        f"{URL}/auth/v1/token?grant_type=password",
        headers={"apikey": ANON},
        json={"email": os.environ[f"{prefix}_EMAIL"].strip(), "password": os.environ[f"{prefix}_PASSWORD"]},
        timeout=60,
    )
    if not r.ok:
        print(f"Login failed for account {prefix} ({os.environ[f'{prefix}_EMAIL']}): HTTP {r.status_code} {r.text}")
        sys.exit(1)
    return r.json()["access_token"]

# Object key per F3: bucket name is repeated as the first path segment.
def key(name):
    return f"{BUCKET}/{ESTATE}/{name}"


def obj(k):
    return f"{ST}/object/{BUCKET}/{k}"


def upload(c, actor, tok, k, data, ctype="application/pdf", method="POST"):
    r = call(c, actor, method, obj(k), tok, headers={"Content-Type": ctype}, data=data)
    if r.ok:
        created.add(k)
    return r


def sign(c, actor, tok, k, ttl=3600):
    r = call(c, actor, "POST", f"{ST}/object/sign/{BUCKET}/{k}", tok, json={"expiresIn": ttl})
    if r.ok:
        try:
            return r, ST + r.json()["signedURL"]
        except Exception:
            pass
    return r, None


def fetch_signed(c, actor, url):
    r = requests.get(url, timeout=120)
    c.log(f"[{time.strftime('%H:%M:%S')}] {actor}: GET {redact(url)}")
    ct = r.headers.get("content-type", "")
    body = r.text[:300] if ct.startswith(("application/json", "text/")) else f"<{len(r.content)} bytes>"
    c.log(f"  -> HTTP {r.status_code}  {body}")
    return r


def main():
    tokA, tokB, tokC = login("A"), login("B"), login("C")

    # ---------------- S0 setup ----------------
    c = Case(0, "setup")
    pdf1 = b"%PDF-1.4\n" + b"UnderCroft FICTIONAL storage test document\n" * 100 + b"%%EOF\n"
    pdf2 = pdf1 + b"\n% version 2\n"
    c.log(f"Accounts: A, B, C signed in via password grant (identities from env vars).")
    c.log(f"Estate under test: {ESTATE}")
    c.log(f"storage-test-{STAMP}.pdf  size={len(pdf1)}  sha256={sha(pdf1)}")
    c.log(f"v2 of the file            size={len(pdf2)}  sha256={sha(pdf2)}")
    c.save()
    rec("S0", "Setup", "-", "-", "3 tokens obtained", True)

    k1 = key(f"storage-test-{STAMP}.pdf")
    k2 = key(f"storage-test-{STAMP}-v2.pdf")

    # ---------------- S1 owner upload ----------------
    c = Case(1, "owner_upload")
    r = upload(c, "A", tokA, k1, pdf1)
    c.save()
    rec("S1", "Owner upload", "A", "allow", r.status_code, r.ok, "DB row check is manual (see below)")

    # ---------------- S2 owner download ----------------
    c = Case(2, "owner_download")
    rs, u = sign(c, "A", tokA, k1)
    ok, obs = False, rs.status_code
    if u:
        d = fetch_signed(c, "A", u)
        match = sha(d.content) == sha(pdf1)
        c.log(f"SHA-256 original={sha(pdf1)}\nSHA-256 retrieved={sha(d.content)}  match={match}")
        ok, obs = d.ok and match, f"{d.status_code}, sha match={match}"
    c.save()
    rec("S2", "Owner download", "A", "200, bytes match", obs, ok)

    # ---------------- S3 cross-estate download ----------------
    c = Case(3, "cross_estate_download")
    rs, u = sign(c, "C", tokC, k1)
    rg = call(c, "C", "GET", obj(k1), tokC)
    ok = (not rs.ok) and (not rg.ok)
    c.save()
    rec("S3", "Cross-estate download", "C", "deny", f"sign={rs.status_code}, GET={rg.status_code}", ok)

    # ---------------- S4 anonymous ----------------
    c = Case(4, "anon_download")
    r1 = call(c, "anon", "GET", f"{ST}/object/public/{BUCKET}/{k1}")
    r2 = call(c, "anon", "GET", obj(k1))
    r3 = call(c, "anon", "POST", f"{ST}/object/sign/{BUCKET}/{k1}", json={"expiresIn": 60})
    ok = not (r1.ok or r2.ok or r3.ok)
    c.save()
    rec("S4", "Anonymous download", "anon", "deny", f"public={r1.status_code}, GET={r2.status_code}, sign={r3.status_code}", ok)

    # ---------------- S5 cross-estate upload ----------------
    c = Case(5, "cross_estate_upload")
    r = upload(c, "C", tokC, key(f"c-intruder-{STAMP}.pdf"), pdf1)
    c.save()
    rec("S5", "Cross-estate upload", "C", "deny", r.status_code, not r.ok)

    # ---------------- S6 executor download (positive) ----------------
    c = Case(6, "executor_download")
    rs, u = sign(c, "B", tokB, k1)
    ok, obs = False, rs.status_code
    if u:
        d = fetch_signed(c, "B", u)
        match = sha(d.content) == sha(pdf1)
        c.log(f"SHA-256 match={match}")
        ok, obs = d.ok and match, f"{d.status_code}, sha match={match}"
    c.save()
    rec("S6", "Executor download", "B", "ALLOW", obs, ok)

    # ---------------- S7 executor upload ----------------
    c = Case(7, "executor_upload")
    r = upload(c, "B", tokB, key(f"b-new-{STAMP}.pdf"), pdf1)
    c.save()
    rec("S7", "Executor upload", "B", "deny", r.status_code, not r.ok)

    # ---------------- S8 executor replacement ----------------
    c = Case(8, "executor_replace")
    r = call(c, "B", "PUT", obj(k1), tokB, headers={"Content-Type": "application/pdf"}, data=pdf2)
    rs, u = sign(c, "A", tokA, k1)
    intact = False
    if u:
        d = fetch_signed(c, "A", u)
        intact = d.ok and sha(d.content) == sha(pdf1)
    c.log(f"Original still intact after B's attempt: {intact}")
    c.save()
    rec("S8", "Executor replacement", "B", "deny", f"{r.status_code}, original intact={intact}", (not r.ok) and intact)

    # ---------------- S9 executor deletion ----------------
    c = Case(9, "executor_delete")
    r = call(c, "B", "DELETE", obj(k1), tokB)
    rs, u = sign(c, "A", tokA, k1)
    intact = False
    if u:
        d = fetch_signed(c, "A", u)
        intact = d.ok and sha(d.content) == sha(pdf1)
    c.log(f"Object still present after B's delete attempt: {intact}")
    c.save()
    rec("S9", "Executor deletion", "B", "deny", f"{r.status_code}, object still present={intact}", intact,
        "Pass depends on the object surviving; the status code alone can mislead")

    # ---------------- S10 replacement + retained URL ----------------
    c = Case(10, "replacement_retained_url")
    rs, old_url = sign(c, "A", tokA, k1)
    up = upload(c, "A", tokA, k2, pdf2)
    dl = call(c, "A", "DELETE", obj(k1), tokA)
    created.discard(k1)
    old = fetch_signed(c, "anyone", old_url) if old_url else None
    if old is not None and old.ok:
        c.log("Old URL still served the file; polling every 15 s for up to 5 min")
        t0 = time.time()
        while time.time() - t0 < 300:
            time.sleep(15)
            old = fetch_signed(c, "anyone", old_url)
            if not old.ok:
                c.log(f"Old URL died after about {int(time.time() - t0)} s")
                break
    rs2, _ = sign(c, "A", tokA, k1)
    new_rs, new_url = sign(c, "A", tokA, k2)
    new_ok = False
    if new_url:
        nd = fetch_signed(c, "A", new_url)
        new_ok = nd.ok and sha(nd.content) == sha(pdf2)
    ok = up.ok and dl.ok and old is not None and (not old.ok) and (not rs2.ok) and new_ok
    c.log("NOTE: this tests storage behaviour (new in, old out, old URL dead). The app's own replace flow is a manual in-app check.")
    c.save()
    rec("S10", "Replacement + retained URL", "A", "old object gone, old URL dead",
        f"old URL={old.status_code if old is not None else 'n/a'}, re-sign old={rs2.status_code}, v2 ok={new_ok}", ok)

    # ---------------- S11 owner deletion ----------------
    c = Case(11, "owner_delete")
    rs, url2 = sign(c, "A", tokA, k2)
    dl = call(c, "A", "DELETE", obj(k2), tokA)
    created.discard(k2)
    after = fetch_signed(c, "anyone", url2) if url2 else None
    if after is not None and after.ok:
        c.log("Old URL still served the file; polling every 15 s for up to 5 min")
        t0 = time.time()
        while time.time() - t0 < 300:
            time.sleep(15)
            after = fetch_signed(c, "anyone", url2)
            if not after.ok:
                c.log(f"Old URL died after about {int(time.time() - t0)} s")
                break
    rs3, _ = sign(c, "A", tokA, k2)
    ok = dl.ok and after is not None and (not after.ok) and (not rs3.ok)
    c.save()
    rec("S11", "Owner deletion", "A", "object gone, old URL dead",
        f"delete={dl.status_code}, old URL={after.status_code if after is not None else 'n/a'}", ok, "DB row removal is manual")

    # ---------------- S13 oversized ----------------
    c = Case(13, "oversized")
    k13 = key(f"oversize-{STAMP}.pdf")
    big = bytes(51 * 1024 * 1024)
    r13 = upload(c, "A", tokA, k13, big)
    c.save()
    rec("S13", "Oversized file (51 MB)", "A", "reject", r13.status_code, not r13.ok)

    # ---------------- S14 disallowed MIME ----------------
    c = Case(14, "disallowed_mime")
    k14a, k14b = key(f"bad-{STAMP}.zip"), key(f"bad-{STAMP}.docx")
    r14a = upload(c, "A", tokA, k14a, b"PK\x03\x04 fictional", "application/zip")
    r14b = upload(c, "A", tokA, k14b, b"PK\x03\x04 fictional",
                  "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
    c.save()
    rec("S14", "Disallowed MIME (zip, docx)", "A", "reject", f"zip={r14a.status_code}, docx={r14b.status_code}",
        (not r14a.ok) and (not r14b.ok))

    # ---------------- S12 failed upload leaves no object (object half) ----------------
    c = Case(12, "failed_upload_rollback")
    leftovers = []
    for k in (k13, k14a, k14b):
        rs, _ = sign(c, "A", tokA, k)
        if rs.ok:
            leftovers.append(k)
    c.log(f"Objects left behind by the rejected uploads: {leftovers or 'none'}")
    c.log("NOTE: the DB-row half of the rollback (F8) must be shown through the app - see manual steps.")
    c.save()
    rec("S12", "Failed upload leaves no object", "A", "no orphan", f"leftovers={len(leftovers)}", not leftovers,
        "Object half only; DB-row half is manual")

    # ---------------- S15 signed-URL expiry ----------------
    c = Case(15, "signed_url_expiry")
    k15 = key(f"expiry-{STAMP}.pdf")
    upload(c, "A", tokA, k15, pdf1)
    rs, u = sign(c, "A", tokA, k15, ttl=60)
    before = fetch_signed(c, "A", u) if u else None
    c.log("Waiting 65 seconds for expiry...")
    time.sleep(65)
    after = fetch_signed(c, "A", u) if u else None
    ok = bool(before is not None and before.ok and after is not None and not after.ok)
    c.save()
    rec("S15", "Signed-URL expiry (60 s)", "A", "live then dead",
        f"before={before.status_code if before is not None else 'n/a'}, after={after.status_code if after is not None else 'n/a'}", ok)

    # ---------------- S16 retained public URL ----------------
    c = Case(16, "retained_public_url")
    dlurl = os.environ.get("DOWNLOAD_URL")
    if dlurl:
        r = requests.get(dlurl, timeout=60)
        c.log(f"GET {redact(dlurl)} (no auth) -> HTTP {r.status_code} {r.text[:300]}")
        rec("S16", "Retained public URL", "-", "no access", r.status_code, not r.ok)
    else:
        k16 = key(f"expiry-{STAMP}.pdf")
        r = requests.get(f"{ST}/object/public/{BUCKET}/{k16}", timeout=60)
        c.log("DOWNLOAD_URL not supplied; fetched the equivalent public route for a live test object instead.")
        c.log(f"GET public route -> HTTP {r.status_code} {r.text[:300]}")
        rec("S16", "Retained public URL", "-", "no access", r.status_code, None if False else (not r.ok),
            "Proxy test. For full evidence, copy a real download_url from a DB row and re-run with DOWNLOAD_URL set")
    c.save()

    # ---------------- S17 path traversal ----------------
    c = Case(17, "path_traversal")
    other = str(uuid.uuid4())
    attempts = [
        ("C", tokC, f"{BUCKET}/{ESTATE}/../x-{STAMP}-a.pdf"),
        ("C", tokC, f"{BUCKET}/{ESTATE}/%2e%2e/x-{STAMP}-b.pdf"),
        ("C", tokC, f"{BUCKET}/../{ESTATE}/x-{STAMP}-c.pdf"),
        ("A", tokA, f"{ESTATE}/x-{STAMP}-d.pdf"),
        ("A", tokA, f"{BUCKET}/{other}/x-{STAMP}-e.pdf"),
    ]
    codes = []
    for actor, tok, k in attempts:
        r = upload(c, actor, tok, k, pdf1)
        codes.append(r.status_code)
    lst = call(c, "A", "POST", f"{ST}/object/list/{BUCKET}", tokA,
               json={"prefix": f"{BUCKET}/{ESTATE}", "limit": 100})
    stray = [n for n in (lst.json() if lst.ok else []) if f"x-{STAMP}" in n.get("name", "")]
    c.log("NOTE: the HTTP client may normalise ../ before sending; the server-side result is what matters.")
    c.log(f"Stray objects under the estate prefix: {[s['name'] for s in stray] or 'none'}")
    c.save()
    rec("S17", "Path traversal / crafted keys", "C/A", "deny, nothing created", f"codes={codes}, stray={len(stray)}",
        all(code >= 400 for code in codes) and not stray)

    # ---------------- S19 bucket config ----------------
    c = Case(19, "bucket_config")
    svc = os.environ.get("SUPABASE_SERVICE_KEY")
    if svc:
        r = call(c, "service", "GET", f"{ST}/bucket/{BUCKET}", svc)
        try:
            b = r.json()
            ok = (b.get("public") is False and b.get("file_size_limit") == 50 * 1024 * 1024 and
                  set(b.get("allowed_mime_types") or []) ==
                  {"application/pdf", "image/jpeg", "image/png", "image/heic", "text/plain",
                   "video/mp4", "video/quicktime", "video/x-m4v", "video/3gpp", "video/webm"})
            rec("S19", "Live bucket config", "service", "private / 50 MB / allowlist",
                f"public={b.get('public')}, limit={b.get('file_size_limit')}, mime={b.get('allowed_mime_types')}", ok)
        except Exception:
            rec("S19", "Live bucket config", "service", "private / 50 MB / allowlist", r.status_code, False)
    else:
        c.log("No service key supplied. Check in Supabase dashboard: Storage > estate-documents > settings, and screenshot it.")
        rec("S19", "Live bucket config", "-", "private / 50 MB / allowlist", "not run", None,
            "Check in the dashboard and screenshot")
    c.save()

    # ---------------- manual rows ----------------
    rec("S18", "Cleanup on deletion", "A", "folder emptied incl. utilities/ and about-you/", "not automated", None,
        "Do in-app (see manual steps)")

    # ---------------- cleanup ----------------
    c = Case(99, "cleanup")
    for k in sorted(created):
        call(c, "A", "DELETE", obj(k), tokA)
    c.save()

    # ---------------- results ----------------
    lines = ["| # | Test | Actor | Expected | Observed | Result | Note |", "|---|---|---|---|---|---|---|"]
    for row in results:
        lines.append("| " + " | ".join(str(x) for x in row) + " |")
    (OUT / "RESULTS.md").write_text("\n".join(lines) + "\n")
    fails = [r for r in results if r[5] == "FAIL"]
    print(f"\nDone. {len(results)} rows, {len(fails)} FAIL. See ./evidence/")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
