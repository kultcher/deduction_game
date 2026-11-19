#!/usr/bin/env python3
"""The case benchmark slate's report (tools/case_slate.gd writes the rows).

    python3 tools/case_slate_report.py RUN.jsonl [BASELINE.jsonl] > report.md

Per case: the Test juror's badge (and how often each), its strength (the likelihood ratio,
geometric mean), the town's mean change in suspicion of the subject (in points: 0.01 of
suspicion is 1 point) with its range, and two agreement figures:
  sign: the share of cases where the juror and the town point the same way. The juror's
        direction is its likelihood ratio's side of 1 (within 1% of 1 is neutral); the
        town's is its movement's side of zero (within a point is neutral). Cases the juror
        couldn't judge ("not ready") are left out; with none left, the figure is "n/a";
  category: the share where the juror's badge matches the town's own band (TOWN_BANDS).
Then the town's movement by badge across the whole slate, for revisiting the cut points.
With a baseline, each case's town mean and strength are shown against it.

TOWN_BANDS are the report's own reading of "how far the town moved", provisional, so that
the juror's badge has something to be compared with. They are not game numbers.
"""
import json
import math
import sys
from collections import OrderedDict, defaultdict

ORDER = ["pile", "kill_sighting", "vigil_kill", "alibi_sighting", "converging", "impossible",
         "double_claim", "gravedigger", "lamp_alibis", "nw_nobody", "guard"]
BADGES = ["contradicts", "none", "weak", "moderate", "strong", "not ready"]
# Lower edge, in points, of each band (the town's movement).
TOWN_BANDS = [("strong", 25.0), ("moderate", 10.0), ("weak", 3.0), ("none", -2.0)]


def band(points):
    for name, edge in TOWN_BANDS:
        if points >= edge:
            return name
    return "contradicts"


def juror_way(lr):
    return 1 if lr > 1.01 else (-1 if lr < 1 / 1.01 else 0)


def town_way(points):
    return 1 if points > 1.0 else (-1 if points < -1.0 else 0)


def pct(x):
    return "n/a" if x is None else "%d%%" % round(100 * x)


def load(path):
    rows = defaultdict(list)
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line:
                r = json.loads(line)
                rows[r["case"]].append(r)
    return rows


def gmean(xs):
    xs = [x for x in xs if x > 0]
    return math.exp(sum(math.log(x) for x in xs) / len(xs)) if xs else float("nan")


def summary(rs):
    pts = [100.0 * r["town"] for r in rs]
    cats = [r["category"] for r in rs]
    judged = [(r, p) for r, p in zip(rs, pts) if r["category"] != "not ready" and r["lr"] > 0]
    sign = (sum(1 for r, p in judged if juror_way(r["lr"]) == town_way(p)) / len(judged)) if judged else None
    cat = sum(1 for r, p in zip(rs, pts) if r["category"] == band(p)) / len(rs)
    return {"n": len(rs), "lr": gmean([r["lr"] for r in rs]), "mean": sum(pts) / len(pts),
            "lo": min(pts), "hi": max(pts), "sign": sign, "cat": cat,
            "badges": OrderedDict((b, cats.count(b)) for b in BADGES if cats.count(b))}


def badge_text(badges):
    return ", ".join("%s %d" % (b, n) for b, n in badges.items())


def main():
    run = load(sys.argv[1])
    base = load(sys.argv[2]) if len(sys.argv) > 2 else None
    names = [c for c in ORDER if c in run] + sorted(c for c in run if c not in ORDER)
    out = ["| Case | n | Juror's badges | Strength | Town, mean (range) | Sign | Category |",
           "|---|---|---|---|---|---|---|"]
    if base:
        out[0] += " Baseline town (strength) |"
        out[1] += "---|"
    for c in names:
        s = summary(run[c])
        line = "| %s | %d | %s | %.2f | %+.1f (%+.1f to %+.1f) | %s | %s |" % (
            c, s["n"], badge_text(s["badges"]), s["lr"], s["mean"], s["lo"], s["hi"],
            pct(s["sign"]), pct(s["cat"]))
        if base:
            if c in base:
                b = summary(base[c])
                line += " %+.1f (%.2f) |" % (b["mean"], b["lr"])
            else:
                line += " (new) |"
        out.append(line)
    blocked = [(c, r["seed"], len(r["blocked"])) for c in names for r in run[c] if r.get("blocked")]
    if blocked:
        out += ["", "**Listeners who couldn't assess the case** (left out of the town's movement): " + ", ".join(
            "%s seed %d (%d)" % b for b in blocked)]
    out += ["", "Town movement by the juror's badge, across the slate:", "",
            "| Badge | Cases | Town, mean | Median | Range | Cases by name |",
            "|---|---|---|---|---|---|"]
    by = defaultdict(list)
    for c in names:
        for r in run[c]:
            by[r["category"]].append((100.0 * r["town"], c))
    for b in BADGES:
        if b not in by:
            continue
        pts = sorted(p for p, _ in by[b])
        mid = pts[len(pts) // 2] if len(pts) % 2 else (pts[len(pts) // 2 - 1] + pts[len(pts) // 2]) / 2
        cs = defaultdict(int)
        for _, c in by[b]:
            cs[c] += 1
        out.append("| %s | %d | %+.1f | %+.1f | %+.1f to %+.1f | %s |" % (
            b, len(pts), sum(pts) / len(pts), mid, pts[0], pts[-1],
            ", ".join("%s %d" % (c, n) for c, n in cs.items())))
    out += ["", "Town bands used for category agreement (points): " + ", ".join(
        "%s from %+g" % (n, e) for n, e in TOWN_BANDS) + ", contradicts below."]
    print("\n".join(out))


if __name__ == "__main__":
    main()
