"""Summarise tools/connections_prototype.gd results against the Phase 4 acceptance criteria.

  python3 tools/connections_prototype_summary.py results_a.json [results_b.json ...]
          [--theta 0.4] [--fade main|0.7|0.85] [--watch LISTENER:PERSON] [--label TEXT]

Each file is one --out of connections_prototype.gd; several files are pooled. --theta picks
the core threshold and --fade the stored-case fade rate ("main" is the run's first rate).
--watch follows one listener's belief about one person (criterion 2; default hollis:kiran).

Prints: untouched people per presentation (criterion 1) and the target's change (3), the
watched listener (2), vote shapes (4), refresh cost cached and counting cache
invalidations (5), stability (6), the largest joint set (7), core sizes, seedless
listeners, and separation by day against the truth. Reads the JSON only.
"""
import json, os, statistics as st, sys


def arg(name, default):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def q(xs):
    xs = sorted(xs)
    return (st.median(xs), xs[int(0.9 * (len(xs) - 1))]) if xs else (float("nan"), float("nan"))


def pct(x):
    return "%.0f%%" % (100 * x)


def beliefs(rec, theta, fade, key="proto", fkey="fades"):
    """The per-person chances for this record at a threshold and fade rate."""
    if fade == "main":
        src = rec[key]
        src = src.get("thetas", src)
    else:
        src = rec[fkey][fade]
    return src[theta]


def sep(pe, truth, keys):
    e = [v for p, v in pe.items() if p in keys and truth[p]["evil"]]
    g = [v for p, v in pe.items() if p in keys and not truth[p]["evil"]]
    return (sum(e) / len(e) - sum(g) / len(g)) if e and g else None


def main():
    skip = set()
    for flag in ("--theta", "--fade", "--watch", "--label"):
        if flag in sys.argv:
            skip.add(sys.argv.index(flag) + 1)
    files = [a for i, a in enumerate(sys.argv[1:], 1) if not a.startswith("--") and i not in skip]
    theta = arg("--theta", "0.4")
    fade = arg("--fade", "main")
    watch = tuple(arg("--watch", "hollis:kiran").split(":"))
    logs = {os.path.basename(f).replace(".json", ""): json.load(open(f)) for f in files}
    first = next(iter(logs.values()))
    print("== %s | %d logs | threshold %s | fade %s (run's rates %s) | cap %s | movement seed %s" % (
        arg("--label", ""), len(logs), theta, fade, first.get("fades"), first.get("cap"), first.get("movement_seed")))

    # ---- criteria 1 and 3: presentations (first presentation of each case to each listener)
    seen = set()
    c1 = []
    for name, d in logs.items():
        for r in d["records"]:
            if r["kind"] != "present" or (name, r["case"], r["listener"]) in seen:
                continue
            seen.add((name, r["case"], r["listener"]))
            a = beliefs(r, theta, fade, "without", "fades_without")["pe"]
            b = beliefs(r, theta, fade, "with", "fades_with")["pe"]
            un = [p for p in a if p not in r["touched"][theta]]
            mv = max([abs(b[p] - a[p]) for p in un] or [0])
            who = max(un, key=lambda p: abs(b[p] - a[p])) if un else "-"
            c1.append((100 * mv, r["label"], r["listener"], who, 100 * (b[r["target"]] - a[r["target"]]), r.get("trace_matched", []),
                       100 * a[r["target"]], 100 * b[r["target"]], r["twice_same"]))
    if c1:
        print("C1 untouched people: %d listener-presentations, largest move %.1f points, over 3 points: %d" % (
            len(c1), max(x[0] for x in c1), sum(1 for x in c1 if x[0] > 3)))
        for x in sorted(c1, reverse=True)[:4]:
            print("     %.1f points: %s, %s on %s (trace matches: %s)" % (x[0], x[1], x[2], x[3], ",".join(x[5]) or "none"))
        print("C3 target's change per presentation:")
        for x in c1:
            print("     %-18s %-8s %.0f%% -> %.0f%% (%+.1f)" % (x[1], x[2], x[6], x[7], x[4]))
        print("C6 a case presented twice is identical: %s" % all(x[8] for x in c1))

    # ---- criterion 2: the watched listener
    for name, d in logs.items():
        rows = [r for r in d["records"] if r["kind"] in ("dawn", "present") and r["listener"] == watch[0]]
        if not rows:
            continue
        print("C2 %s on %s (%s):" % (watch[0], watch[1], name))
        for r in rows:
            if r["kind"] == "dawn":
                th = beliefs(r, theta, fade)
                mine = [cid for cid, desc in r["cards"].items() if desc.startswith("report") and ("by %s " % watch[1]) in desc]
                print("     dawn day %d: %s (no stored cases %s; today %s; connects everything %s); their reading held %s, in core %s; core %d" % (
                    r["day"], pct(th["pe"].get(watch[1], 0)), pct(r["proto_no_cases"][theta]["pe"].get(watch[1], 0)), pct(r["today"].get(watch[1], 0)),
                    pct(r["everything"].get(watch[1], 0)), bool(mine), any(k in th["core"] for k in mine), len(th["core"])))
            else:
                a = beliefs(r, theta, fade, "without", "fades_without")
                b = beliefs(r, theta, fade, "with", "fades_with")
                print("     %s (seq %d): %s -> %s; core %d" % (r["label"], r["seq"], pct(a["pe"][watch[1]]), pct(b["pe"][watch[1]]), len(b["core"])))

    # ---- criterion 4: votes
    tot = {"today": [0, 0, 0], "proto": [0, 0, 0]}
    votes = flips = voters = outcomes = 0
    detail = []
    for d in logs.values():
        for r in d["records"]:
            if r["kind"] != "vote":
                continue
            votes += 1
            yes = set(r["yes"])
            y = set(yes)
            for v in r["voters"]:
                if v["p_today"] < 0:
                    continue
                voters += 1
                p = v["proto"][theta] if fade == "main" else v["fades"][fade][theta]
                want = v["total"] + v["scale"] * (p - v["p_today"]) >= v["need"]
                flips += want != (v["voter"] in yes)
                (y.add if want else y.discard)(v["voter"])
            others = [v for v in r["order"] if v != r["nominee"]]

            def shape(yy):
                return [all(v in yy for v in others), len(yy) == 1 and r["by"] in yy, (r["by"] in r["evil"]) and len(yy) >= r["threshold"] > 0]
            for i in range(3):
                tot["today"][i] += shape(yes)[i]
                tot["proto"][i] += shape(y)[i]
            if (len(y) >= r["threshold"]) != (len(yes) >= r["threshold"]):
                outcomes += 1
                detail.append("%s nominee %d->%d of %d" % ("evil" if r["nominee_evil"] else "good", len(yes), len(y), r["threshold"]))
    print("C4 votes %d: [unanimous but the nominee, only the nominator, evil nomination carried] today %s prototype %s; good votes flipped %d of %d; outcomes changed %d %s" % (
        votes, tot["today"], tot["proto"], flips, voters, outcomes, detail))

    # ---- criterion 5: cost, cached, and counting what the cache would have had to redo
    dawns = [r for d in logs.values() for r in d["records"] if r["kind"] == "dawn"]
    late = [r for r in dawns if r["day"] >= 3]
    print("C5 refresh ms, median / 90th: all days today %.0f / %.0f, cached %.0f / %.0f, nothing cached %.0f / %.0f | from day 3 today %.0f / %.0f, cached %.0f / %.0f, nothing cached %.0f / %.0f" % (
        q([r["today_ms"] for r in dawns]) + q([r["cold_joint_ms"] for r in dawns]) + q([r["cold_ms"] for r in dawns])
        + q([r["today_ms"] for r in late]) + q([r["cold_joint_ms"] for r in late]) + q([r["cold_ms"] for r in late])))
    caches = [r for d in logs.values() for r in d["records"] if r["kind"] == "cache" and r["since_seq"] != r["seq"]]
    if caches:
        items = sum(r["counts"]["items"] for r in caches)
        for key in ("new", "record", "hearing", "trust", "kept", "kept_drifted"):
            n = sum(r["counts"][key] for r in caches)
            print("     cache, %-12s %5d of %d items (%.1f%%)" % (key, n, items, 100 * n / max(1, items)))
        clean = sum(1 for r in caches if r["counts"]["record"] + r["counts"]["hearing"] + r["counts"]["trust"] + r["counts"]["new"] == 0)
        print("     %d refreshes compared with the listener's previous one that day; %d (%.0f%%) invalidated nothing; refreshes where the public record changed: %d" % (
            len(caches), clean, 100 * clean / len(caches), sum(1 for r in caches if r["counts"]["record"] > 0)))
        drift = [r["worst_drift"] for r in caches if r["counts"]["kept"] > 0]
        print("     drift of items the cache would have kept (log-odds): median %.3f, 90th %.3f, worst %.3f" % (q(drift) + (max(drift),)))
        # cost counting invalidations: the joint pass plus two judgements per invalidated or new item
        by_listener_day = {(name, r["listener"], r["day"]): r for name, d in logs.items() for r in d["records"] if r["kind"] == "dawn"}
        costs, todays = [], []
        for name, d in logs.items():
            for r in d["records"]:
                if r["kind"] != "cache" or r["since_seq"] == r["seq"]:
                    continue
                dawn = by_listener_day.get((name, r["listener"], r["day"]))
                if not dawn:
                    continue
                redo = r["counts"]["record"] + r["counts"]["hearing"] + r["counts"]["trust"] + r["counts"]["new"]
                costs.append(dawn["cold_joint_ms"] + 2 * redo * r["judgement_ms"])
                todays.append(dawn["today_ms"])
        print("     refresh cost counting those, median / 90th: %.0f / %.0f ms (today on the same listener-days %.0f / %.0f)" % (q(costs) + q(todays)))

    # ---- criterion 6 and 7, cores, seeds
    print("C6 recomputing at a dawn is identical: %s" % all(r["stable"] for r in dawns))
    share = [beliefs(r, theta, fade)["largest"] / max(1, r["proto"]["held"]) for r in late]
    if share:
        print("C7 largest joint set / held from day 3: median %.0f%%, largest %.0f%% (%d listener-dawns)" % (100 * st.median(share), 100 * max(share), len(share)))
        members = [len(beliefs(r, theta, fade)["core"]) for r in late]
        print("   cores from day 3: joined items median %s, most %d; listener-dawns with at least one %d of %d; seedless %d of %d (%.0f%%)" % (
            st.median(members), max(members), sum(1 for m in members if m > 0), len(members),
            sum(1 for r in late if r["proto"]["seed"] == 0), len(late), 100 * sum(1 for r in late if r["proto"]["seed"] == 0) / len(late)))
        live = [len(beliefs(r, theta, fade)["cases"]) for r in late]
        print("   stored cases still counting per listener from day 3: median %s, most %d" % (st.median(live), max(live)))

    # ---- separation against the truth
    agg = {}
    for d in logs.values():
        truth = d["records"][-1]["truth"]
        for r in d["records"]:
            if r["kind"] != "dawn" or r["day"] < 2 or not r["everything"] or not r["today"]:
                continue
            pe = beliefs(r, theta, fade)["pe"]
            keys = set(pe) & set(r["everything"]) & set(r["today"])
            for m, x in (("today", r["today"]), ("prototype", pe), ("everything", r["everything"])):
                s = sep(x, truth, keys)
                top = max(keys, key=lambda k: x[k])
                agg.setdefault((min(r["day"], 4), m), []).append((s, truth[top]["evil"]))
    for day in (2, 3, 4):
        if (day, "today") not in agg:
            continue
        print("separation day %s (%d listener-dawns): %s" % (day if day < 4 else "4+", len(agg[(day, "today")]), " | ".join(
            "%s %.2f, top suspect evil %d%%" % (m, st.mean(s for s, _ in agg[(day, m)] if s is not None), 100 * sum(t for _, t in agg[(day, m)]) / len(agg[(day, m)]))
            for m in ("today", "prototype", "everything"))))


if __name__ == "__main__":
    main()
