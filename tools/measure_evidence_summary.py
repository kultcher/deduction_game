#!/usr/bin/env python3
"""Summarise tools/measure_evidence.gd output into the evidence catalog's measured tables.

python3 tools/measure_evidence_summary.py DIR  (reads DIR/*.jsonl, prints markdown)

Separation = mean step on the truly evil minus mean step on the truly good (listener
excluded), in suspicion units: how far one card pulls the evil apart from the good for a
listener who knows nothing else. Positive is the right way.
"""
import json, sys, glob, os, statistics as st
from collections import defaultdict

TIERS = [(0.20, "decisive"), (0.10, "strong"), (0.05, "moderate"), (0.02, "weak"), (-1e9, "negligible")]

def tier(v):
    for cut, name in TIERS:
        if v >= cut:
            return name

def med(xs):
    return st.median(xs) if xs else float("nan")

def load(d):
    rows = []
    for p in sorted(glob.glob(os.path.join(d, "*.jsonl"))):
        tag = os.path.basename(p)[:-6]
        for line in open(p):
            try:
                r = json.loads(line)
            except json.JSONDecodeError:
                continue  # a line still being written
            r["_file"] = tag
            r["_hex"] = tag.endswith("_hex")
            rows.append(r)
    return rows

def fmt(v):
    return "—" if v != v else ("%+.3f" % v)

def readings(rows, hexer=False):
    out = []
    by = defaultdict(list)
    for r in rows:
        if r["evidence"] == "reading" and r["_hex"] == hexer:
            by[r["role"]].append(r)
    out.append("| Role | Readings (false) | Separation, heard 0.4 | Separation, heard 0.8 | Separation, own | All of a source's readings, 0.8 | Step on named people, 0.8 | Biggest single move, 0.8 | Tier (heard 0.8) |")
    out.append("|---|---|---|---|---|---|---|---|---|")
    order = sorted(by, key=lambda k: -med([r["separation"] for r in by[k] if r["mode"] == "heard" and r["trust"] == 0.8 and r["true"]] or [0]))
    for role in order:
        rs = by[role]
        true_rs = [r for r in rs if r["true"]]
        n_read = len({(r["seed"], r["size"], r["source"], json.dumps(r.get("data", {}), sort_keys=True)) for r in rs if r["mode"] == "own"})
        n_false = len({(r["seed"], r["size"], r["source"], json.dumps(r.get("data", {}), sort_keys=True)) for r in rs if r["mode"] == "own" and not r["true"]})
        def sep(mode, trust=None, pool=true_rs):
            return med([r["separation"] for r in pool if r["mode"] == mode and (trust is None or r["trust"] == trust)])
        h4, h8, own, allr = sep("heard", 0.4), sep("heard", 0.8), sep("own"), sep("all_readings", 0.8)
        big = med([r["max_abs"] for r in true_rs if r["mode"] == "heard" and r["trust"] == 0.8])
        named8 = med([r["named_mean"] for r in true_rs if r["mode"] == "heard" and r["trust"] == 0.8 and r["named"]])
        out.append("| %s | %d (%d) | %s | %s | %s | %s | %s | %s | %s |" % (role, n_read, n_false, fmt(h4), fmt(h8), fmt(own), fmt(allr), fmt(named8), "%.3f" % big if big == big else "—", tier(h8) if h8 == h8 else "—"))
    # False readings: how far they mislead.
    out.append("")
    out.append("False readings (Delusional, poisoned, Marked, Red Herring), heard at 0.8:")
    out.append("")
    out.append("| Role | False readings | Separation (median) |")
    out.append("|---|---|---|")
    for role in order:
        fr = [r["separation"] for r in by[role] if not r["true"] and r["mode"] == "heard" and r["trust"] == 0.8]
        if fr:
            out.append("| %s | %d | %s |" % (role, len(fr), fmt(med(fr))))
    return "\n".join(out)

def other(rows, kinds, hexer=False):
    out = ["| Evidence | Subject | n | Step on subject, 0.4 | Step on subject, 0.8 | Separation, 0.8 |", "|---|---|---|---|---|---|"]
    for kind in kinds:
        rs = [r for r in rows if r["evidence"] == kind and r["_hex"] == hexer]
        if not rs:
            continue
        def split(key):
            if kind in ("night_sighting", "home_alibi", "sighting_vs_alibi", "role_claim"):
                return "evil" if r.get("subject_evil") else "good"
            if kind in ("trace", "trace_with_profiles", "dropped_belongings"):
                return "evil" if r.get("target_evil") else "good"
            if kind in ("demon_death", "silenced"):
                return "evil" if r.get("subject_evil") else "good"
            if kind == "claim_clash":
                return "holder + bluffer"
            return "—"
        groups = defaultdict(list)
        for r in rs:
            groups[split(r)].append(r)
        for gname in sorted(groups):
            g = groups[gname]
            def step(t):
                vals = [r["named_mean"] for r in g if r.get("trust") == t]
                return med(vals)
            t4, t8 = step(0.4), step(0.8)
            if kind in ("demon_death", "silenced"):
                t4 = float("nan")
                t8 = med([r["named_mean"] for r in g])
                s8 = med([r["separation"] for r in g])
            else:
                s8 = med([r["separation"] for r in g if r.get("trust") == 0.8])
            n = len({(r["seed"], r["size"], tuple(r["named"]), r.get("night", -1), json.dumps(r.get("cards", []))) for r in g})
            out.append("| %s | %s | %d | %s | %s | %s |" % (kind, gname, n, fmt(t4), fmt(t8), fmt(s8)))
    return "\n".join(out)

def clash(rows):
    rs = [r for r in rows if r["evidence"] == "claim_clash" and not r["_hex"]]
    if not rs:
        return ""
    out = ["| Trust | Clashes | Holder step | Bluffer step |", "|---|---|---|---|"]
    for t in (0.4, 0.8):
        g = [r for r in rs if r["trust"] == t]
        # named = [holder, bluffer]; named_mean averages them, so recover each from top-level fields is not stored;
        # report the separation instead (bluffer is evil, holder good).
        out.append("| %.1f | %d | — | separation %s |" % (t, len(g), fmt(med([r["separation"] for r in g]))))
    return "\n".join(out)

def main():
    d = sys.argv[1]
    rows = load(d)
    if len(sys.argv) > 2:
        rows = [r for r in rows if str(r["size"]) == sys.argv[2]]
    print("Rows: %d\n" % len(rows))
    print("## Gift readings (default demon)\n")
    print(readings(rows))
    print("\n## Gift readings (Hexer on the script)\n")
    print(readings(rows, True))
    kinds = ["night_sighting", "home_alibi", "sighting_vs_alibi", "role_claim", "claim_clash", "demon_death", "silenced", "trace", "trace_with_profiles", "dropped_belongings"]
    print("\n## Other evidence (default demon)\n")
    print(other(rows, kinds))
    print("\n## Other evidence (Hexer on the script)\n")
    print(other(rows, kinds, True))
    print("\n## Claim clashes\n")
    print(clash(rows))

if __name__ == "__main__":
    main()
