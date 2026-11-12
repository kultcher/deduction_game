#!/usr/bin/env python3
"""Balance-sweep report: reads merged `sweep_v1` JSONL records and writes a markdown
report plus a JSON summary (docs/balance_sweep.md).

    python3 tools/sweep_report.py merged.jsonl --md sweep_report.md --json sweep_summary.json
        [--errors errors.jsonl]

Standard library only.
"""
import argparse
import json
import math
import statistics
from collections import defaultdict

Z = 1.96


def wilson(k, n):
    if n == 0:
        return (0.0, 0.0, 0.0)
    p = k / n
    d = 1 + Z * Z / n
    c = (p + Z * Z / (2 * n)) / d
    h = Z * math.sqrt(p * (1 - p) / n + Z * Z / (4 * n * n)) / d
    return (p, max(0.0, c - h), min(1.0, c + h))


def diff_ci(k1, n1, k2, n2):
    """Difference of two proportions with a normal-approximation 95% interval."""
    if n1 == 0 or n2 == 0:
        return (0.0, 0.0, 0.0)
    p1, p2 = k1 / n1, k2 / n2
    se = math.sqrt(p1 * (1 - p1) / n1 + p2 * (1 - p2) / n2)
    d = p1 - p2
    return (d, d - Z * se, d + Z * se)


def pct(x):
    return "%.1f%%" % (100.0 * x)


def pts(x):
    return "%+.1f" % (100.0 * x)


def mean(xs):
    xs = list(xs)
    return sum(xs) / len(xs) if xs else 0.0


def cell_key(r):
    # A forced demon type is in the record's mode ("bot_force_daykiller"), so it keeps the
    # cell apart in grouping, deduplication and pairing.
    return (r["npcs"], r["mode"], float(r.get("insight", 1.0)) if not r["mode"].startswith("passive") else 1.0)


def cell_label(k):
    npcs, mode, ins = k
    forced = ""
    if "_force_" in mode:
        mode, d = mode.split("_force_", 1)
        forced = ", %s forced" % d
    names = {"bot_pre_m4": "bot (pre-M4)", "no_present": "bot, no presenting", "present_vote": "bot, present and vote",
             "bot_nocross": "bot, no cross-checks", "bot_nodeclare": "bot, no declaring"}
    return "%d NPCs, %s%s" % (npcs, mode if mode == "passive" else "%s insight %.1f" % (names.get(mode, mode), ins), forced)


def good_win(r):
    return r.get("winner") == "good"


def load(path):
    recs = []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                recs.append(json.loads(line))
            except ValueError:
                continue
    # One record per (cell, seed): keep the last.
    seen = {}
    for r in recs:
        seen[(cell_key(r), r["seed"])] = r
    return list(seen.values())


def tagged_walkers(r):
    return r.get("night_walkers_dealt", 0)


def dealt_roles(r):
    return set(r.get("town_roles", [])) | set(r.get("minion_roles", [])) | set(r.get("demon_roles", []))


def effect_rows(games, feature_of, min_n=30):
    """Win rate with vs without each feature value. feature_of(r) -> set of labels."""
    present = defaultdict(lambda: [0, 0])
    labels = set()
    for r in games:
        for f in feature_of(r):
            labels.add(f)
    total_w = sum(1 for r in games if good_win(r))
    total_n = len(games)
    rows = []
    for f in labels:
        k1 = n1 = 0
        for r in games:
            if f in feature_of(r):
                n1 += 1
                k1 += 1 if good_win(r) else 0
        k2, n2 = total_w - k1, total_n - n1
        if n1 < min_n or n2 < min_n:
            continue
        d, lo, hi = diff_ci(k1, n1, k2, n2)
        rows.append({"feature": f, "with_n": n1, "with_win": k1 / n1, "without_n": n2,
                     "without_win": k2 / n2 if n2 else 0.0, "diff": d, "lo": lo, "hi": hi,
                     "significant": lo > 0 or hi < 0})
    rows.sort(key=lambda x: -abs(x["diff"]))
    return rows


def effect_table(rows, title, out):
    out.append("**%s**\n" % title)
    if not rows:
        out.append("_Not enough games._\n")
        return
    out.append("| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |")
    out.append("|---|---|---|---|---|---|")
    for x in rows:
        mark = " **\\***" if x["significant"] else ""
        out.append("| %s | %d | %s | %d | %s | %s (%s to %s)%s |" % (
            x["feature"], x["with_n"], pct(x["with_win"]), x["without_n"], pct(x["without_win"]),
            pts(x["diff"]), pts(x["lo"]), pts(x["hi"]), mark))
    out.append("")


def town_role_stats(games):
    stats = defaultdict(lambda: {"n": 0, "death_days": [], "early_kill": 0, "exec_good": 0, "claimed": 0})
    for r in games:
        for p in r.get("people", []):
            if p.get("evil_at_start"):
                continue
            s = stats[p["role"]]
            s["n"] += 1
            if p.get("death_day", -1) >= 0:
                s["death_days"].append(p["death_day"])
            if p.get("death_cause") == "demon" and 0 <= p.get("death_day", -1) <= 2:
                s["early_kill"] += 1
            if p.get("death_cause") == "executed" and p.get("alignment") == "good":
                s["exec_good"] += 1
            if p.get("claim_public"):
                s["claimed"] += 1
    return stats


def bluff_stats(games):
    stats = defaultdict(lambda: {"picked": 0, "contested": 0, "executed": 0})
    for r in games:
        for p in r.get("people", []):
            if not p.get("evil_at_start"):
                continue
            claim = p.get("claimed_role") or ""
            if not claim or claim == p.get("role"):
                continue
            s = stats[claim]
            s["picked"] += 1
            if p.get("claim_contested"):
                s["contested"] += 1
            if p.get("executed_while_bluffing"):
                s["executed"] += 1
    return stats


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("jsonl")
    ap.add_argument("--md", default="sweep_report.md")
    ap.add_argument("--json", default="sweep_summary.json")
    ap.add_argument("--errors", default="")
    ap.add_argument("--title", default="Balance sweep report")
    a = ap.parse_args()
    recs = load(a.jsonl)
    failed = [r for r in recs if r.get("failed")]
    # Stuck games (the bot hit the command guard) have no real winner: autoplay records
    # them as evil, so they are left out of every rate and listed under Health instead.
    stuck = [r for r in recs if not r.get("failed") and r.get("stuck")]
    games = [r for r in recs if not r.get("failed") and not r.get("stuck")]
    errors = []
    if a.errors:
        try:
            with open(a.errors, encoding="utf-8") as fh:
                errors = [json.loads(l) for l in fh if l.strip()]
        except (OSError, ValueError):
            errors = []
    by_cell = defaultdict(list)
    for r in games:
        by_cell[cell_key(r)].append(r)
    cells = sorted(by_cell)
    shas = sorted({r.get("sha", "") for r in recs})
    out = ["# %s" % a.title, ""]
    out.append("Records: %d games, %d failed, %d stuck (left out of the rates). Commit(s): %s." % (len(games), len(failed), len(stuck), ", ".join("`%s`" % s[:10] for s in shas if s) or "unknown"))
    out.append("")
    summary = {"cells": {}, "games": len(games), "failed": len(failed), "shas": shas}

    # ---------------- per cell
    out.append("## Win rate by cell\n")
    out.append("| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |")
    out.append("|---|---|---|---|---|---|---|---|---|")
    for k in cells:
        g = by_cell[k]
        n = len(g)
        w = sum(1 for r in g if good_win(r))
        p, lo, hi = wilson(w, n)
        firsts = [r["first_evil_exec_day"] for r in g if r.get("first_evil_exec_day", -1) >= 0]
        day1 = sum(1 for r in g if r.get("first_evil_exec_day", -1) == 1)
        walk_hang = mean(r.get("good_gift_walkers_executed", 0) + r.get("good_secret_walkers_executed", 0) for r in g)
        out.append("| %s | %d | %s (%s–%s) | %.2f | %.2f | %.2f | %s | %s | %.2f |" % (
            cell_label(k), n, pct(p), pct(lo), pct(hi), mean(r["days"] for r in g),
            mean(r.get("exec_good", 0) for r in g), mean(r.get("exec_evil", 0) for r in g),
            ("%.2f" % mean(firsts)) if firsts else "–", pct(day1 / n) if n else "–", walk_hang))
        summary["cells"][cell_label(k)] = {"n": n, "good_wins": w, "win_rate": p, "ci": [lo, hi]}
    out.append("")

    # Vote shape (belief-model guardrail). Records from before tools/vote_shape.gd lack the
    # fields; such cells are skipped.
    shaped = [k for k in cells if any("votes" in r for r in by_cell[k])]
    if shaped:
        out.append("### Vote shape\n")
        out.append("Unanimous: every NPC voter but the nominee voted yes. Evil nominations: by someone evil at case start; carried = put on the block.\n")
        out.append("| Cell | Votes/game | Unanimous | Only the nominator | Evil noms/game | Evil noms carried | Evil noms on good targets carried | ...hanged |")
        out.append("|---|---|---|---|---|---|---|---|")
        for k in shaped:
            g = [r for r in by_cell[k] if "votes" in r]
            tot = lambda f: sum(r.get(f, 0) for r in g)
            votes, en, eng = tot("votes"), tot("evil_nominations"), tot("evil_nominations_good_target")
            frac = lambda a, b: pct(a / b) if b else "–"
            out.append("| %s | %.2f | %s | %s | %.2f | %s | %s | %s |" % (
                cell_label(k), votes / len(g), frac(tot("votes_unanimous"), votes), frac(tot("votes_only_nominator"), votes),
                en / len(g), frac(tot("evil_nominations_carried"), en), frac(tot("evil_nominations_good_target_carried"), eng),
                frac(tot("evil_nominations_good_target_executed"), eng)))
            summary["cells"][cell_label(k)]["vote_shape"] = {f: tot(f) for f in ["votes", "votes_unanimous", "votes_only_nominator", "evil_nominations",
                "evil_nominations_carried", "evil_nominations_executed", "evil_nominations_good_target", "evil_nominations_good_target_carried", "evil_nominations_good_target_executed"]}
        out.append("")

    out.append("### End reasons and solvability\n")
    for k in cells:
        g = by_cell[k]
        n = len(g)
        reasons = defaultdict(int)
        for r in g:
            reasons[r.get("reason", "")] += 1
        on_board = [r for r in g if r.get("demon_evidence_on_board")]
        reach = [r for r in g if r.get("demon_evidence_reachable")]
        neither = [r for r in g if not r.get("demon_evidence_on_board") and not r.get("demon_evidence_reachable")]
        out.append("**%s** (n=%d)\n" % (cell_label(k), n))
        for reason, c in sorted(reasons.items(), key=lambda x: -x[1]):
            out.append("- %s: %d (%s)" % (reason or "(none)", c, pct(c / n)))
        def wr(sub):
            return "%s of %d" % (pct(sum(1 for r in sub if good_win(r)) / len(sub)), len(sub)) if sub else "–"
        out.append("- Demon evidence on the board: %s of games; good win rate %s" % (pct(len(on_board) / n), wr(on_board)))
        out.append("- Demon evidence reachable: %s of games; good win rate %s" % (pct(len(reach) / n), wr(reach)))
        out.append("- Neither: %s of games; good win rate %s" % (pct(len(neither) / n), wr(neither)))
        out.append("- Deal fallback (guarantees or night-walker band not met): %d games" % sum(1 for r in g if r.get("deal_fallback")))
        out.append("")

    # ---------------- role effects
    out.append("## Role effects\n")
    out.append("Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; "
               "**\\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games "
               "(or missing from fewer than 30) are left out. These are associations, not causes: roles "
               "travel with the deal rules.\n")
    summary["effects"] = {}
    for k in cells:
        g = by_cell[k]
        out.append("### %s\n" % cell_label(k))
        town = effect_rows(g, lambda r: set(r.get("town_roles", [])))
        mins = effect_rows(g, lambda r: set(r.get("minion_roles", [])))
        demons = effect_rows(g, lambda r: set(r.get("demon_roles", [])))
        secrets = effect_rows(g, lambda r: {r.get("secret") or "(none)"})
        effect_table(town, "Town gifts", out)
        effect_table(mins, "Minions", out)
        if len({d for r in g for d in r.get("demon_roles", [])}) > 1:
            effect_table(demons, "Demons", out)
        else:
            out.append("_One demon type in every game: no demon comparison._\n")
        effect_table(secrets, "Secrets", out)
        walk_rows = effect_rows(g, lambda r: {"%d night-walkers" % tagged_walkers(r)})
        effect_table(walk_rows, "Night-walkers dealt (including the Demon)", out)
        summary["effects"][cell_label(k)] = {"town": town, "minions": mins, "secrets": secrets, "walkers": walk_rows}

        # town role detail
        ts = town_role_stats(g)
        out.append("**Town gifts in play: fate**\n")
        out.append("| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |")
        out.append("|---|---|---|---|---|---|")
        for role, s in sorted(ts.items(), key=lambda x: -x[1]["n"]):
            if s["n"] < 20:
                continue
            out.append("| %s | %d | %s | %s | %s | %s |" % (
                role, s["n"], ("%.1f" % mean(s["death_days"])) if s["death_days"] else "–",
                pct(s["early_kill"] / s["n"]), pct(s["exec_good"] / s["n"]), pct(s["claimed"] / s["n"])))
        out.append("")
        bs = bluff_stats(g)
        if bs:
            out.append("**Evil bluffs claimed**\n")
            out.append("| Bluff | Times claimed | Contested | Bluffer executed |")
            out.append("|---|---|---|---|")
            for role, s in sorted(bs.items(), key=lambda x: -x[1]["picked"]):
                if s["picked"] < 10:
                    continue
                out.append("| %s | %d | %s | %s |" % (role, s["picked"], pct(s["contested"] / s["picked"]),
                                                    pct(s["executed"] / s["picked"])))
            out.append("")

        # pairs
        pairs = defaultdict(lambda: [0, 0])
        for r in g:
            roles = sorted(dealt_roles(r))
            for i in range(len(roles)):
                for j in range(i + 1, len(roles)):
                    pairs[(roles[i], roles[j])][0] += 1
                    pairs[(roles[i], roles[j])][1] += 1 if good_win(r) else 0
        total_w = sum(1 for r in g if good_win(r))
        prow = []
        for (x, y), (n1, k1) in pairs.items():
            n2 = len(g) - n1
            if n1 < 200 or n2 < 200:
                continue
            d, lo, hi = diff_ci(k1, n1, total_w - k1, n2)
            if abs(d) >= 0.10:
                prow.append((x, y, n1, k1 / n1, n2, (total_w - k1) / n2, d, lo, hi))
        out.append("**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)\n")
        if prow:
            out.append("| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |")
            out.append("|---|---|---|---|---|---|")
            for x, y, n1, w1, n2, w2, d, lo, hi in sorted(prow, key=lambda t: -abs(t[6])):
                out.append("| %s + %s | %d | %s | %d | %s | %s (%s to %s) |" % (x, y, n1, pct(w1), n2, pct(w2), pts(d), pts(lo), pts(hi)))
        else:
            out.append("_None._")
        out.append("")

    # ---------------- paired passive vs bot
    out.append("## Does the player matter? Paired seeds\n")
    out.append("Same seed and size means the same script and deal, so each bot game has a passive twin.\n")
    out.append("| Size | Bot cell | Paired games | Bot wins, passive loses | Passive wins, bot loses | Both win | Both lose |")
    out.append("|---|---|---|---|---|---|---|")
    for npcs in sorted({k[0] for k in cells}):
        for k in cells:
            if k[0] != npcs or k[1].startswith("passive"):
                continue
            # A forced cell's twin is the passive cell with the same forced demon type.
            forced = ("_force_" + k[1].split("_force_", 1)[1]) if "_force_" in k[1] else ""
            passive = {r["seed"]: r for r in by_cell.get((npcs, "passive" + forced, 1.0), [])}
            flips = [0, 0, 0, 0]
            for r in by_cell[k]:
                p = passive.get(r["seed"])
                if p is None:
                    continue
                b, q = good_win(r), good_win(p)
                flips[0 if b and not q else 1 if q and not b else 2 if b and q else 3] += 1
            n = sum(flips)
            if n:
                out.append("| %d | %s | %d | %d (%s) | %d (%s) | %d | %d |" % (npcs, cell_label(k), n, flips[0], pct(flips[0] / n),
                                                                            flips[1], pct(flips[1] / n), flips[2], flips[3]))
    out.append("")

    # ---------------- health
    out.append("## Health\n")
    out.append("- Stuck games (guard exhausted): %d%s" % (len(stuck), (" — seeds " + ", ".join("%d (%d NPCs, %s)" % (r["seed"], r["npcs"], r["mode"]) for r in stuck[:30])) if stuck else ""))
    # Seeds a cell should have (every cell shares the same seed range) but has no record of.
    all_seeds = sorted({r["seed"] for r in recs if "seed" in r})
    gaps = {}
    if all_seeds:
        expected = set(range(all_seeds[0], all_seeds[-1] + 1))
        for k in cells:
            have = {r["seed"] for r in recs if cell_key(r) == k}
            lost = sorted(expected - have)
            if lost:
                gaps[cell_label(k)] = lost
    out.append("- Seeds with no record: %s" % ("; ".join("%s: %d (first %s)" % (c, len(v), ", ".join(str(x) for x in v[:10])) for c, v in gaps.items()) if gaps else "none"))
    out.append("- Failed games (crash or timeout): %d%s" % (len(failed), (" — seeds " + ", ".join("%d (%s)" % (r["seed"], r.get("failed")) for r in failed[:30])) if failed else ""))
    err_seeds = defaultdict(int)
    for e in errors:
        if e.get("kind") == "engine_errors":
            err_seeds[(e.get("cell"), e.get("seed"))] += e.get("count", 0)
    out.append("- Games with engine errors: %d" % len(err_seeds))
    if err_seeds:
        sample = defaultdict(int)
        for e in errors:
            for line in e.get("lines", [])[:3]:
                sample[line[:160]] += 1
        out.append("  - Most common lines:")
        for line, c in sorted(sample.items(), key=lambda x: -x[1])[:8]:
            out.append("    - %d× `%s`" % (c, line.replace("`", "'")))
    out.append("- Shared-model fallbacks: %d games with any" % sum(1 for r in games if r.get("legacy_fallbacks", 0)))
    out.append("")
    out.append("| Cell | Median wall (s) | p90 | Max |")
    out.append("|---|---|---|---|")
    for k in cells:
        walls = sorted(r.get("wall_s", 0.0) for r in by_cell[k])
        if walls:
            out.append("| %s | %.1f | %.1f | %.1f |" % (cell_label(k), statistics.median(walls), walls[int(0.9 * (len(walls) - 1))], walls[-1]))
    out.append("")
    slow = sorted(games, key=lambda r: -r.get("wall_s", 0.0))[:20]
    out.append("Slowest seeds: " + ", ".join("%d (%d NPCs %s, %.0f s)" % (r["seed"], r["npcs"], r["mode"], r.get("wall_s", 0.0)) for r in slow))
    out.append("")
    summary["health"] = {"stuck": [r["seed"] for r in stuck], "failed": [r["seed"] for r in failed], "missing": gaps,
                         "error_games": len(err_seeds)}

    with open(a.md, "w", encoding="utf-8") as fh:
        fh.write("\n".join(out) + "\n")
    with open(a.json, "w", encoding="utf-8") as fh:
        json.dump(summary, fh, indent=1)
    print("wrote %s and %s (%d games)" % (a.md, a.json, len(games)))


if __name__ == "__main__":
    main()
