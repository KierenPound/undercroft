#!/usr/bin/env python3
"""
S18 evidence collector: storage objects AND the database rows that point at them.

Run these in order, each at the right moment:

    python3 s18_list.py init      # estate exists, nothing attached yet
    python3 s18_list.py before    # after adding files in the app (sections, utilities, about-you)
    python3 s18_list.py tests     # OPTIONAL, after run_storage_tests.py; should equal 'before'
    python3 s18_list.py after     # after deleting the account in the app
    python3 s18_list.py report    # collates everything into one summary

ESTATE_ID must be the same for every stage of one run. The estate row is gone
after account deletion, so note the ID down at the start.

Evidence is saved in evidence/s18_<first 8 chars of estate id>/, so repeat runs
with a new estate never overwrite earlier evidence.

Read-only: nothing is created, changed or deleted. Uses the service key because
the owner account no longer exists once it has been deleted. Only IDs and storage
paths are read from the database; no names, numbers, passwords or notes.
"""
import os, sys, json, time, pathlib
import requests

CONFIG = {
    "SUPABASE_URL": "https://mpsygpgaakdtlgjzmbtr.supabase.co",
	"SUPABASE_SERVICE_KEY": "PASTE KEY HERE: Supabase dashboard > Project Settings > API Keys > service_role / secret key",
    "ESTATE_ID": "6d6a7fe4-28d3-4f53-b6a8-a6145f6f90a0",
}
for _k, _v in CONFIG.items():
    os.environ.setdefault(_k, _v)

URL = os.environ["SUPABASE_URL"].rstrip("/")
KEY = os.environ["SUPABASE_SERVICE_KEY"]
ESTATE = os.environ["ESTATE_ID"]
BUCKET = "estate-documents"
H = {"apikey": KEY, "Authorization": f"Bearer {KEY}"}
OUT = pathlib.Path("evidence") / f"s18_{ESTATE[:8]}"
REQUIRED_SUBFOLDERS = {"about-you", "sections", "utilities"}
PREV = {"before": "init", "tests": "before", "after": "before"}  # snapshot each stage is compared with


# ---------------------------------------------------------------- storage
def list_dir(prefix):
    items, offset = [], 0
    while True:
        r = requests.post(
            f"{URL}/storage/v1/object/list/{BUCKET}",
            headers=H,
            json={"prefix": prefix, "limit": 100, "offset": offset},
            timeout=60,
        )
        r.raise_for_status()
        page = r.json()
        items += page
        if len(page) < 100:
            return items
        offset += 100


def walk(prefix):
    files = []
    for it in list_dir(prefix):
        path = f"{prefix}/{it['name']}"
        if it.get("id") is None:  # a "folder" is only a path prefix
            files += walk(path)
        else:
            files.append({"path": path, "size": (it.get("metadata") or {}).get("size")})
    return files


# ---------------------------------------------------------------- database
def rest(table, query):
    r = requests.get(f"{URL}/rest/v1/{table}?{query}", headers=H, timeout=60)
    if not r.ok:
        return None, f"{table}: HTTP {r.status_code} {r.text[:150]}"
    return r.json(), None


def db_state():
    errors, refs, counts = [], [], {}

    est, e = rest("estates", f"select=id&id=eq.{ESTATE}")
    if e:
        errors.append(e)
    estate_exists = bool(est)

    secs, e = rest("sections", f"select=id,video_path&estate_id=eq.{ESTATE}")
    if e:
        errors.append(e)
    secs = secs or []
    counts["sections"] = len(secs)
    for s in secs:
        if s.get("video_path"):
            refs.append({"source": "sections.video_path", "id": s["id"], "path": s["video_path"]})

    atts = []
    if secs:
        ids = ",".join(s["id"] for s in secs)
        atts, e = rest("attachments", f"select=id,storage_path&section_id=in.({ids})")
        if e:
            errors.append(e)
        atts = atts or []
    counts["attachments"] = len(atts)
    for a in atts:
        if a.get("storage_path"):
            refs.append({"source": "attachments.storage_path", "id": a["id"], "path": a["storage_path"]})

    ay, e = rest("about_you", f"select=about_you_id,passport_storage_path,licence_storage_path&estate_id=eq.{ESTATE}")
    if e:
        errors.append(e)
    ay = ay or []
    counts["about_you"] = len(ay)
    for a in ay:
        for col in ("passport_storage_path", "licence_storage_path"):
            if a.get(col):
                refs.append({"source": f"about_you.{col}", "id": a["about_you_id"], "path": a[col]})

    ud, e = rest("utility_details", f"select=utility_detail_id,storage_path&estate_id=eq.{ESTATE}")
    if e:
        errors.append(e)
    ud = ud or []
    counts["utility_details"] = len(ud)
    for u in ud:
        if u.get("storage_path"):
            refs.append({"source": "utility_details.storage_path", "id": u["utility_detail_id"], "path": u["storage_path"]})

    docs, e = rest("documents", f"select=id,storage_path&estate_id=eq.{ESTATE}")
    if e:
        errors.append(e)
    docs = docs or []
    counts["documents"] = len(docs)
    for d in docs:
        if d.get("storage_path"):
            refs.append({"source": "documents.storage_path", "id": d["id"], "path": d["storage_path"]})

    return {"estate_exists": estate_exists, "counts": counts, "refs": refs, "errors": errors}


def norm(p):
    """Compare object names and stored paths on the part after the estate id."""
    if not p:
        return ""
    i = p.find(ESTATE + "/")
    if i >= 0:
        return p[i + len(ESTATE) + 1:]
    return p[len(BUCKET) + 1:] if p.startswith(BUCKET + "/") else p


# ---------------------------------------------------------------- snapshot
def take_snapshot(label):
    root = f"{BUCKET}/{ESTATE}"
    objects = walk(root)
    subfolders = sorted({o["path"][len(root) + 1:].split("/")[0] for o in objects if "/" in o["path"][len(root) + 1:]})
    db = db_state()
    snap = {
        "label": label,
        "time": time.strftime("%Y-%m-%d %H:%M:%S"),
        "estate": ESTATE,
        "objects": objects,
        "subfolders": subfolders,
        "db": db,
    }
    if not db["errors"]:
        obj_norm = {norm(o["path"]): o["path"] for o in objects}
        ref_norm = {norm(r["path"]): r for r in db["refs"]}
        snap["objects_without_row"] = sorted(p for n, p in obj_norm.items() if n not in ref_norm)
        snap["rows_without_object"] = sorted(r["source"] + " -> " + r["path"] for n, r in ref_norm.items() if n not in obj_norm)
    return snap


def render(snap):
    db = snap["db"]
    L = [
        f"[{snap['time']}] S18 snapshot '{snap['label']}'  estate {snap['estate']}",
        "",
        f"STORAGE  objects: {len(snap['objects'])}   subfolders: {snap['subfolders'] or 'none'}",
    ]
    L += [f"  {o['path']}  ({o['size']} bytes)" for o in snap["objects"]]
    L += ["", f"DATABASE  estate row exists: {db['estate_exists']}"]
    L.append("  rows per table: " + ", ".join(f"{k}={v}" for k, v in db["counts"].items()))
    L.append(f"  rows that reference a storage path: {len(db['refs'])}")
    L += [f"    {r['source']}  {r['path']}" for r in db["refs"]]
    if db["errors"]:
        L += ["", "DATABASE ERRORS (db checks not performed):"] + [f"  {e}" for e in db["errors"]]
    else:
        L += [
            "",
            f"Objects with no database row: {snap['objects_without_row'] or 'none'}",
            f"Database rows with no object: {snap['rows_without_object'] or 'none'}",
        ]
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------- verdicts
def verdicts(label, snap, prev):
    """Return a list of (check, True/False/None); None = could not be checked."""
    db, objs = snap["db"], {o["path"] for o in snap["objects"]}
    db_ok = not db["errors"]
    c = []
    if label == "init":
        c.append(("No objects under the estate prefix", len(objs) == 0))
        c.append(("No database rows reference a storage path", (len(db["refs"]) == 0) if db_ok else None))
        c.append(("Estate row exists", db["estate_exists"] if db_ok else None))
    elif label == "before":
        c.append(("Objects present", len(objs) > 0))
        c.append((f"All required subfolders present {sorted(REQUIRED_SUBFOLDERS)}", REQUIRED_SUBFOLDERS <= set(snap["subfolders"])))
        c.append(("Database rows reference storage paths", (len(db["refs"]) > 0) if db_ok else None))
        c.append(("Every object has a database row (no orphan objects)", (not snap["objects_without_row"]) if db_ok else None))
        c.append(("Every database row has an object (no dangling rows)", (not snap["rows_without_object"]) if db_ok else None))
    elif label == "tests":
        if prev:
            before = {o["path"] for o in prev["objects"]}
            c.append(("Nothing left behind by the test script", not (objs - before)))
            c.append(("Nothing missing compared with 'before'", not (before - objs)))
        else:
            c.append(("'before' snapshot available to compare with", None))
    elif label == "after":
        c.append(("No objects under the estate prefix", len(objs) == 0))
        c.append(("No subfolders remain", not snap["subfolders"]))
        c.append(("Estate row gone", (not db["estate_exists"]) if db_ok else None))
        c.append(("No database rows remain in any table", (all(v == 0 for v in db["counts"].values())) if db_ok else None))
    return c


def verdict_text(checks):
    lines = []
    for name, res in checks:
        lines.append(f"  [{'PASS' if res else 'NOT CHECKED' if res is None else 'FAIL'}] {name}")
    if any(r is False for _, r in checks):
        overall = "FAIL"
    elif any(r is None for _, r in checks):
        overall = "INCOMPLETE"
    else:
        overall = "PASS"
    return lines, overall


# ---------------------------------------------------------------- stages
def load(label):
    p = OUT / f"snapshot_{label}.json"
    return json.loads(p.read_text()) if p.exists() else None


def do_stage(label):
    OUT.mkdir(parents=True, exist_ok=True)
    snap = take_snapshot(label)
    (OUT / f"snapshot_{label}.json").write_text(json.dumps(snap, indent=2))
    prev = load(PREV[label]) if label in PREV else None
    if label in PREV and not prev:
        print(f"Note: no '{PREV[label]}' snapshot found to compare with. Run it first next time.\n")
    lines, overall = verdict_text(verdicts(label, snap, prev))
    text = render(snap) + "\nCHECKS\n" + "\n".join(lines) + f"\nStage result: {overall}\n"
    if label == "after" and prev:
        left = sorted({o["path"] for o in snap["objects"]} & {o["path"] for o in prev["objects"]})
        text += f"Objects from 'before' still present: {left or 'none'}\n"
    (OUT / f"storage_18_{label}.txt").write_text(text)
    print(text)
    print(f"Saved to {OUT}/")


def do_report():
    snaps = {l: load(l) for l in ("init", "before", "tests", "after")}
    missing = [l for l in ("init", "before", "after") if not snaps[l]]
    if missing:
        sys.exit(f"Cannot report yet: missing snapshot(s) {missing}. Run those stages first.")
    estates = {s["estate"] for s in snaps.values() if s}
    L = [f"# S18 evidence summary - estate {ESTATE}", ""]
    if len(estates) > 1:
        L += [f"**WARNING: snapshots come from different estates: {sorted(estates)}**", ""]
    L += ["| Stage | Time | Objects | Subfolders | DB rows referencing storage | Result |", "|---|---|---|---|---|---|"]
    results = {}
    for l in ("init", "before", "tests", "after"):
        s = snaps[l]
        if not s:
            continue
        prev = snaps.get(PREV.get(l)) if l in PREV else None
        _, results[l] = verdict_text(verdicts(l, s, prev))
        L.append(f"| {l} | {s['time']} | {len(s['objects'])} | {', '.join(s['subfolders']) or 'none'} | {len(s['db']['refs'])} | {results[l]} |")
    L += ["", "## What each stage shows", ""]
    for l in ("init", "before", "tests", "after"):
        s = snaps[l]
        if not s:
            continue
        prev = snaps.get(PREV.get(l)) if l in PREV else None
        lines, _ = verdict_text(verdicts(l, s, prev))
        L += [f"**{l}**", ""] + [f"- {x.strip()}" for x in lines] + [""]
    b = snaps["before"]
    L += [
        "## Database-row evidence for other tests",
        "",
        f"- **S1 (database half):** at 'before', {len(b['db']['refs'])} database rows reference storage paths, against {len(b['objects'])} objects.",
        f"- **S12 / F8 (no orphans):** objects without a row: {b.get('objects_without_row', 'not checked') or 'none'}; rows without an object: {b.get('rows_without_object', 'not checked') or 'none'}.",
        "",
    ]
    ok = all(results.get(l) == "PASS" for l in ("init", "before", "after"))
    L += [f"## S18 overall: {'PASS' if ok else 'NOT YET PASSING - see stages above'}", ""]
    text = "\n".join(L)
    (OUT / "s18_evidence_summary.md").write_text(text)
    print(text)
    print(f"Saved to {OUT}/s18_evidence_summary.md")


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("init", "before", "tests", "after", "report"):
        sys.exit(__doc__)
    do_report() if sys.argv[1] == "report" else do_stage(sys.argv[1])


if __name__ == "__main__":
    main()
