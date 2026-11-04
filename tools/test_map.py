#!/usr/bin/env python3
"""Static map of the GDScript test suites, for the test audit.

For every tools/test_*.gd it records: size, checks (and their messages), the game
modules it preloads, the module functions and game/world methods it calls, the
commands it plays, exact-text assertions (brittle when dialogue changes), and
"absence" guards (checks that old code stays gone). From that it reports which
suites overlap most, which modules each suite leans on, and what CI runs.

  python3 tools/test_map.py [--timings t1.json t2.json ...] [--json out.json] [--md out.md]

Heuristic, not a coverage tool: it reads the source, it doesn't trace execution.
"""
import argparse
import json
import re
from collections import Counter, defaultdict
from itertools import combinations
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"

PRELOAD = re.compile(r'^\s*const\s+(\w+)\s*=\s*preload\("res://([^"]+)"\)', re.M)
LOAD = re.compile(r'\bload\("res://([^"]+\.(?:gd|tscn))"\)')
CHECK = re.compile(r'(?<![\w.])(?:_check|check|_expect\w*|_ok|_assert\w*|assert|_eq|_t)\s*(?:\.call)?\s*\(')
MESSAGE = re.compile(r'(?:_check|check(?:\.call)?|_expect\w*|_ok|_assert\w*|assert|_eq|_t)\s*\((.*?),\s*"((?:[^"\\]|\\.)*)"\s*[\),]', re.S)
OBJ_CALL = re.compile(r'\b(g|game|w|world|scene|main|view|panel|board|model|canvas|mind)\.([a-z_][a-z0-9_]*)\s*\(')
COMMAND = re.compile(r'\.(?:command|_run|workshop_command)\(\s*"([a-z_]+)')
EXACT_TEXT = re.compile(r'(?:==|!=)\s*"[^"]{18,}"|"[^"]{18,}"\s*(?:==|!=)|\bin\s+[\w.\[\]"]*text|\.text\s*==')
ABSENCE = re.compile(r'not\s+ResourceLoader\.exists|not\s+FileAccess\.file_exists|not\s+[\w.]+\.has_method\(|not\s+"[^"]+"\s+in\s+[\w.]*(?:get_script_constant_map|keys\(\))|\bnot\s+[\w.]+\.has\("[A-Z_]+"\)|legacy\s+\w+\s+(?:is\s+)?(?:gone|removed|deleted)', re.I)
CASE = re.compile(r'\.new_case\(|_game\(|\.setup\(\s*\d')
DATE_NAMED = re.compile(r'batch|phase|claude|_fixes$|playtest|slice|legacy|_poc$|remaining|sweep|followup|cleanup')


def area(path: str) -> str:
    return path.split("/")[0] if "/" in path else path


def scan(path: Path) -> dict:
    src = path.read_text(encoding="utf-8", errors="replace")
    aliases = {}
    for name, res in PRELOAD.findall(src):
        aliases[name] = res
    modules = sorted({r for r in aliases.values() if not r.startswith("tools/")} |
                     {r for r in LOAD.findall(src) if not r.startswith("tools/")})
    symbols = set()
    for name, res in aliases.items():
        if res.startswith("tools/"):
            continue
        for fn in re.findall(r'\b%s\.([A-Za-z_]\w*)\s*\(' % re.escape(name), src):
            if fn != "new":
                symbols.add("%s::%s" % (res, fn))
    methods = Counter(m for _, m in OBJ_CALL.findall(src))
    for m in methods:
        symbols.add("obj::" + m)
    commands = Counter(COMMAND.findall(src))
    for c in commands:
        symbols.add("cmd::" + c)
    messages = [m[1] for m in MESSAGE.findall(src)]
    lines = src.splitlines()
    check_lines = [l for l in lines if CHECK.search(l)]
    exact = sum(1 for l in check_lines if EXACT_TEXT.search(l))
    absence = sum(1 for l in lines if ABSENCE.search(l))
    return {
        "suite": path.stem,
        "lines": len(lines),
        "checks": len(check_lines),
        "messages": messages,
        "modules": modules,
        "areas": sorted({area(m) for m in modules}),
        "symbols": sorted(symbols),
        "commands": dict(commands),
        "exact_text_checks": exact,
        "absence_checks": absence,
        "cases_built": len(CASE.findall(src)),
        "date_named": bool(DATE_NAMED.search(path.stem)),
    }


def jaccard(a: set, b: set) -> float:
    return len(a & b) / len(a | b) if a and b else 0.0


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--timings", nargs="*", default=[])
    ap.add_argument("--json", type=Path)
    ap.add_argument("--md", type=Path)
    args = ap.parse_args()

    suites = [scan(p) for p in sorted(TOOLS.glob("test_*.gd"))]
    timing = {}
    for t in args.timings:
        timing.update(json.loads(Path(t).read_text()))
    ci_fast = set()
    fast = TOOLS / "ci_fast_suites.txt"
    if fast.exists():
        ci_fast = {l.strip() for l in fast.read_text().splitlines() if l.strip() and not l.startswith("#")}
    m = re.search(r"SLOW\s*=\s*\{([^}]*)\}", (TOOLS / "run_gd_tests.py").read_text())
    slow = set(re.findall(r'"(test_\w+)"', m.group(1))) if m else set()
    for s in suites:
        s["seconds"] = timing.get(s["suite"], {}).get("seconds")
        s["passed"] = timing.get(s["suite"], {}).get("passed")
        s["tier"] = "slow" if s["suite"] in slow else ("pr" if s["suite"] in ci_fast else "main")

    # Overlap on what the suites exercise. Very common symbols (used by most suites,
    # like new_case) say little, so they're dropped before comparing.
    freq = Counter(sym for s in suites for sym in s["symbols"])
    common = {sym for sym, n in freq.items() if n > len(suites) * 0.4}
    sets = {s["suite"]: set(s["symbols"]) - common for s in suites}
    pairs = []
    for a, b in combinations(sets, 2):
        j = jaccard(sets[a], sets[b])
        if j >= 0.35 and min(len(sets[a]), len(sets[b])) >= 4:
            pairs.append((round(j, 2), a, b, len(sets[a] & sets[b])))
    pairs.sort(reverse=True)
    best = {}
    for s in suites:
        cands = [(jaccard(sets[s["suite"]], sets[o]), o) for o in sets if o != s["suite"]]
        cands.sort(reverse=True)
        best[s["suite"]] = [(round(j, 2), o) for j, o in cands[:3] if j > 0]
    by_module = defaultdict(list)
    for s in suites:
        for m in s["modules"]:
            by_module[m].append(s["suite"])

    # Near-duplicate check messages across suites: the same behaviour asserted twice.
    def words(m):
        return frozenset(w for w in re.findall(r"[a-z]+", m.lower()) if len(w) > 2)
    msg_index = []
    for s in suites:
        for m in s["messages"]:
            ws = words(m)
            if len(ws) >= 4:
                msg_index.append((s["suite"], m, ws))
    dup_pairs = Counter()
    dup_examples = defaultdict(list)
    by_word = defaultdict(list)
    for i, (_, _, ws) in enumerate(msg_index):
        for w in ws:
            by_word[w].append(i)
    seen = set()
    for i, (sa, ma, wa) in enumerate(msg_index):
        cands = Counter(j for w in wa for j in by_word[w] if j > i)
        for j, n in cands.items():
            sb, mb, wb = msg_index[j]
            if sb == sa or (i, j) in seen:
                continue
            if n / len(wa | wb) >= 0.7:
                seen.add((i, j))
                key = tuple(sorted((sa, sb)))
                dup_pairs[key] += 1
                if len(dup_examples[key]) < 3:
                    dup_examples[key].append([ma, mb])
    for s in suites:
        s["duplicate_checks"] = sum(n for k, n in dup_pairs.items() if s["suite"] in k)

    report = {"suites": suites, "overlap_pairs": pairs, "nearest": best,
              "duplicate_check_pairs": [[a, b, n, dup_examples[(a, b)]] for (a, b), n in dup_pairs.most_common()],
              "module_users": {m: sorted(v) for m, v in sorted(by_module.items(), key=lambda kv: -len(kv[1]))},
              "common_symbols": sorted(common)}
    if args.json:
        args.json.write_text(json.dumps(report, indent=1))
    if args.md:
        args.md.write_text(markdown(report))
    print("%d suites, %d checks, %d lines" % (len(suites), sum(s["checks"] for s in suites), sum(s["lines"] for s in suites)))


def markdown(r: dict) -> str:
    suites = r["suites"]
    out = ["# Test suite map", ""]
    tot = sum(s["seconds"] or 0 for s in suites)
    out.append("%d suites · %d checks · %d lines · %.0f min measured" % (
        len(suites), sum(s["checks"] for s in suites), sum(s["lines"] for s in suites), tot / 60))
    out += ["", "## Every suite", "",
            "| Suite | Tier | Time (s) | Checks | Lines | Areas | Exact text | Absence | Dup checks | Cases | Nearest overlap |",
            "|---|---|---|---|---|---|---|---|---|---|---|"]
    for s in sorted(suites, key=lambda s: -(s["seconds"] or 0)):
        near = ", ".join("%s %.2f" % (o, j) for j, o in r["nearest"][s["suite"]][:2])
        flag = "" if s["passed"] in (None, True) else " ✕"
        out.append("| %s%s%s | %s | %s | %d | %d | %s | %d | %d | %d | %d | %s |" % (
            s["suite"], " ⌚" if s["date_named"] else "", flag, s["tier"],
            "%.0f" % s["seconds"] if s["seconds"] is not None else "–", s["checks"], s["lines"],
            ", ".join(s["areas"]), s["exact_text_checks"], s["absence_checks"], s["duplicate_checks"], s["cases_built"], near))
    out += ["", "⌚ named after when it was written (batch, phase, slice, playtest…) rather than what it tests. ✕ failed in the timing run.", ""]
    out += ["## Most-overlapping pairs", "", "Jaccard similarity of the game functions, methods and commands the two suites call (ignoring ones most suites call).", "",
            "| Similarity | Suite A | Suite B | Shared |", "|---|---|---|---|"]
    for j, a, b, n in r["overlap_pairs"][:40]:
        out.append("| %.2f | %s | %s | %d |" % (j, a, b, n))
    out += ["", "## Near-duplicate checks across suites", "",
            "Check messages that say nearly the same thing (70%+ word overlap): the likeliest real redundancy.", "",
            "| Suite A | Suite B | Near-duplicates | Example |", "|---|---|---|---|"]
    for a, b, n, ex in r["duplicate_check_pairs"][:40]:
        e = ex[0]
        out.append("| %s | %s | %d | “%s” / “%s” |" % (a, b, n, e[0][:70].replace("|", "/"), e[1][:70].replace("|", "/")))
    out += ["", "## Game modules by number of suites that preload them", "", "| Module | Suites |", "|---|---|"]
    for m, users in list(r["module_users"].items())[:40]:
        out.append("| %s | %d |" % (m, len(users)))
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    main()
