#!/usr/bin/env python3
"""Summarise tools/measure_evidence.gd --what interactions|premises output.

python3 tools/measure_interactions_summary.py run1.jsonl [run2.jsonl ...]

Interactions: per pair type, the number of pairs and, per pair, the largest |interaction|
over people in log-odds on P(evil) (joint - A - B + none; chances clipped to 1-99%), with
the share of pairs reaching 0.2, 0.4 and 0.8 (the Phase 4 core thresholds). Also the
interaction on the named subject, split by whether the subject is evil.
Premises: per variant, the mean step on the target's and the first teller's P(evil) from
the case's own verdict, and the suspicion step, against holding the cards unpresented.
"""
import json
import math
import statistics
import sys
from collections import defaultdict


def lo(p):
    p = min(0.99, max(0.01, p))
    return math.log(p / (1 - p))


def main(paths):
    inter = defaultdict(lambda: defaultdict(list))
    prem = []
    for path in paths:
        for line in open(path):
            try:
                r = json.loads(line)
            except json.JSONDecodeError:
                continue  # a line still being written
            if r.get("evidence") == "premises":
                prem.append(r)
                continue
            key = (path, r["seed"], r["listener"], r["pair_type"], json.dumps(r["a"], sort_keys=True), json.dumps(r["b"], sort_keys=True), r.get("trust"))
            inter[r["pair_type"]][key].append(r)
    if inter:
        print("pair type                      pairs  median max|int|  >=0.2  >=0.4  >=0.8  subject evil / good (mean int)")
        for pt in sorted(inter):
            maxes = []
            subj = {True: [], False: []}
            for key, rs in inter[pt].items():
                maxes.append(max(abs(r["interaction_lo"]) for r in rs))
                who = rs[0]["a"].get("who") or (rs[0]["a"].get("named") or [None])[0]
                for r in rs:
                    if r["person"] == who:
                        subj[r["person_evil"]].append(r["interaction_lo"])
            n = len(maxes)
            share = lambda t: sum(m >= t for m in maxes) / n
            sv = lambda xs: "%+.2f (%d)" % (statistics.mean(xs), len(xs)) if xs else "-"
            print("%-30s %5d  %14.2f  %5.0f%% %5.0f%% %5.0f%%  %s / %s" % (pt, n, statistics.median(maxes), 100 * share(0.2), 100 * share(0.4), 100 * share(0.8), sv(subj[True]), sv(subj[False])))
    if prem:
        steps = defaultdict(lambda: {"target": [], "teller": [], "susp_target": [], "susp_teller": []})
        held = {"target": [], "teller": []}
        for r in prem:
            role = "target" if r["person"] == r["target"] else ("teller" if r["person"] == r["pair"][0]["teller"] else None)
            if role is None:
                continue
            base = r["p_evil"]["none"]
            if "held" in r["p_evil"]:
                held[role].append(lo(r["p_evil"]["held"]) - lo(base))
            for k, v in r.get("case_p_evil", {}).items():
                if v >= 0:
                    steps[k][role].append(lo(v) - lo(base))
                    steps[k]["susp_" + role].append(r["susp_step"].get(k, 0.0))
        m = lambda xs: "%+.2f" % statistics.mean(xs) if xs else "  -  "
        print("\nvariant              case verdict vs none (log-odds)   suspicion step")
        print("                     target   first teller           target  first teller")
        print("%-20s %s    %s" % ("held, unpresented", m(held["target"]), m(held["teller"])))
        for k in sorted(steps):
            s = steps[k]
            print("%-20s %s    %s               %s   %s" % (k, m(s["target"]), m(s["teller"]), m(s["susp_target"]), m(s["susp_teller"])))
        ch = defaultdict(list)
        for r in prem:
            for k, c in r.get("challenge", {}).items():
                if r["person"] == r["target"]:
                    ch[k].append(c)
        for k, cs in ch.items():
            print("%s: %d presented, mean effect %.2f, mean multiplier %.2f, backfires %d" % (k, len(cs), statistics.mean(c["effect"] for c in cs), statistics.mean(c["multiplier"] for c in cs), sum(c["backfire"] for c in cs)))


if __name__ == "__main__":
    main(sys.argv[1:])
