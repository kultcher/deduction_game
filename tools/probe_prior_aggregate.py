import json, glob, collections, sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "."
rows = []
for f in glob.glob(D + "/r_*.json"):
    try: rows += json.load(open(f))
    except Exception as e: print("bad", f, e)
def auc(ps, key):
    ev = [p[key] for p in ps if p["evil"]]; gd = [p[key] for p in ps if not p["evil"]]
    if not ev or not gd: return None
    s = sum((e > g) + 0.5 * (e == g) for e in ev for g in gd)
    return s / (len(ev) * len(gd))
by = collections.defaultdict(list)
for r in rows:
    ps = list(r["people"].values())
    if not ps: continue
    post_sorted = sorted(ps, key=lambda p: -p["post"])
    demon_rank = next((i + 1 for i, p in enumerate(post_sorted) if p["demon"]), None)
    m = dict(auc_prior=auc(ps, "prior"), auc_post=auc(ps, "post"),
             top_evil=post_sorted[0]["evil"], demon_rank=demon_rank,
             evil_post=sum(p["post"] for p in ps if p["evil"]) / max(1, sum(p["evil"] for p in ps)),
             good_post=sum(p["post"] for p in ps if not p["evil"]) / max(1, sum(not p["evil"] for p in ps)),
             move=sum(abs(p["post"] - p["prior"]) for p in ps) / len(ps),
             role=r["role"], key=(r["seed"], r["holder"]))
    by[r["k"]].append(m)
def mean(xs):
    xs = [x for x in xs if x is not None]
    return sum(xs) / len(xs) if xs else float("nan")
print("holders per setting:", {k: len(v) for k, v in sorted(by.items())})
print("%-8s %9s %9s %8s %9s %9s %9s %9s" % ("prior", "AUCprior", "AUCpost", "lift", "top=evil", "demonRk", "P(evil)E", "P(evil)G"))
for k in sorted(by):
    v = by[k]
    print("%-8s %9.3f %9.3f %8.3f %9.2f %9.2f %9.3f %9.3f" % ("current" if k < 0 else "K=%.1f" % k,
        mean(m["auc_prior"] for m in v), mean(m["auc_post"] for m in v),
        mean((m["auc_post"] - m["auc_prior"]) if m["auc_prior"] is not None and m["auc_post"] is not None else None for m in v),
        mean(float(m["top_evil"]) for m in v), mean(m["demon_rank"] for m in v),
        mean(m["evil_post"] for m in v), mean(m["good_post"] for m in v)))
print("\nBy holder role: AUC after own evidence (current -> K=1.5 / 2.2 / 3.0), n")
roles = collections.defaultdict(lambda: collections.defaultdict(list))
for k, v in by.items():
    for m in v: roles[m["role"]][k].append(m["auc_post"])
for role in sorted(roles):
    d = roles[role]
    print("  %-13s %s  n=%d" % (role, "  ".join("%.2f" % mean(d[k]) for k in sorted(d)), len(d[-1.0]) if -1.0 in d else 0))
