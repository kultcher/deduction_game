#!/usr/bin/env python3
"""Diff a golden capture (tools/golden_capture.gd) against a baseline.

    python3 tools/golden_diff.py BASELINE_DIR CANDIDATE_DIR [--tol 1e-9] [--ignore discounted,honesty]

Each seed file is compared record by record, in order. Numbers match when equal or
within --tol (absolute, or relative to the larger magnitude); everything else must be
identical. For each seed the report says identical, matching within tolerance (with
how many values needed it), or where it first diverged: the record (a refresh or a
command step), its day/phase/NPC, and the first differing paths. The first divergence
is the one to chase; later ones usually follow from it.

Baselines may be gzipped (.jsonl.gz). Exit status: 0 when every seed matches, 1 if not.
"""
import argparse
import gzip
import json
import math
import re
import sys
from pathlib import Path


# Absolute paths into Godot's user data folder (e.g. the game-over "Dev log written:" reply)
# differ by machine; compare them as user://. Captures write user:// already
# (tools/golden_capture.gd); this keeps older baselines comparable too.
USER_DIR = re.compile(r"(?:[A-Za-z]:)?[^\s,:]*?app_userdata[/\\][^/\\,]+[/\\]([^,]*)")


def portable(rec):
    if isinstance(rec.get("reply"), str) and "app_userdata" in rec["reply"]:
        rec["reply"] = USER_DIR.sub(lambda m: "user://" + m.group(1).replace("\\", "/"), rec["reply"])
    return rec


def load(path: Path):
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rt", encoding="utf-8") as fh:
        return [portable(json.loads(line)) for line in fh if line.strip()]


def seed_files(folder: Path):
    found = {}
    for p in sorted(folder.glob("seed_*.jsonl*")):
        found[p.name.split(".jsonl")[0]] = p
    return found


class Comparer:
    def __init__(self, tol: float, ignore: set, limit: int):
        self.tol = tol
        self.ignore = ignore
        self.limit = limit
        self.tolerated = 0
        self.diffs = []

    def numbers_match(self, a, b) -> bool:
        if a == b:
            return True
        if isinstance(a, float) or isinstance(b, float):
            if math.isnan(a) and math.isnan(b):
                return True
            scale = max(abs(a), abs(b), 1.0)
            if abs(a - b) <= self.tol * scale:
                self.tolerated += 1
                return True
        return False

    def walk(self, a, b, path):
        if len(self.diffs) >= self.limit:
            return
        if path and path[-1] in self.ignore:
            return
        num = (int, float)
        if isinstance(a, bool) or isinstance(b, bool):
            if a is not b:
                self.diffs.append((path, a, b))
            return
        if isinstance(a, num) and isinstance(b, num):
            if not self.numbers_match(a, b):
                self.diffs.append((path, a, b))
            return
        if isinstance(a, dict) and isinstance(b, dict):
            for key in a:
                if key in self.ignore:
                    continue
                if key not in b:
                    self.diffs.append((path + [key], a[key], "<missing>"))
                else:
                    self.walk(a[key], b[key], path + [key])
            for key in b:
                if key not in a and key not in self.ignore:
                    self.diffs.append((path + [key], "<missing>", b[key]))
            return
        if isinstance(a, list) and isinstance(b, list):
            if len(a) != len(b):
                self.diffs.append((path + ["<len>"], len(a), len(b)))
            for i, (x, y) in enumerate(zip(a, b)):
                self.walk(x, y, path + [str(i)])
            return
        if a != b:
            self.diffs.append((path, a, b))


def short(value, width=120):
    text = json.dumps(value, sort_keys=True) if not isinstance(value, str) else value
    return text if len(text) <= width else text[: width - 3] + "..."


def where(rec):
    if rec.get("k") == "refresh":
        return "refresh #%s (%s%s, day %s phase %s)" % (rec.get("i"), rec.get("npc"), " cover" if rec.get("shadow") else "", rec.get("day"), rec.get("phase"))
    if rec.get("k") == "step":
        return "step %s '%s' (day %s phase %s, state %s)" % (rec.get("step"), rec.get("cmd"), rec.get("day"), rec.get("phase"), rec.get("state"))
    return "%s record" % rec.get("k")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("baseline", type=Path)
    ap.add_argument("candidate", type=Path)
    ap.add_argument("--tol", type=float, default=1e-9, help="numeric tolerance (default 1e-9; 0 = exact)")
    ap.add_argument("--ignore", default="engine", help="comma-separated keys to skip anywhere (default: engine)")
    ap.add_argument("--limit", type=int, default=12, help="differing paths to list per divergence")
    args = ap.parse_args()
    ignore = {k for k in args.ignore.split(",") if k}

    for folder, label in ((args.baseline, "baseline"), (args.candidate, "candidate")):
        if not folder.is_dir():
            print("%s folder not found: %s" % (label, folder))
            sys.exit(1)
    base, cand = seed_files(args.baseline), seed_files(args.candidate)
    # A partial candidate is fine; an empty one (misspelt path, failed capture) is not.
    if not cand:
        print("no seed captures (seed_*.jsonl) in candidate folder %s" % args.candidate)
        sys.exit(1)
    if not set(cand) & set(base):
        print("candidate shares no seeds with the baseline: %s" % ", ".join(sorted(cand)))
        sys.exit(1)
    ok = True
    for name in sorted(set(base) | set(cand)):
        if name not in cand:
            print("%s: skipped (not in candidate)" % name)
            continue
        if name not in base:
            print("%s: missing from baseline" % name)
            ok = False
            continue
        a, b = load(base[name]), load(cand[name])
        cmp = Comparer(args.tol, ignore, args.limit)
        diverged = None
        for i, (ra, rb) in enumerate(zip(a, b)):
            cmp.walk(ra, rb, [])
            if cmp.diffs:
                diverged = (i, ra, rb)
                break
        if diverged is None and len(a) != len(b):
            longer = a if len(a) > len(b) else b
            diverged = (min(len(a), len(b)), longer[min(len(a), len(b))], None)
            cmp.diffs.append((["<records>"], len(a), len(b)))
        if diverged is None:
            note = "identical" if cmp.tolerated == 0 else "matches within tolerance (%d values)" % cmp.tolerated
            print("%s: %s, %d records" % (name, note, len(a)))
            continue
        ok = False
        i, ra, _ = diverged
        print("%s: DIVERGES at record %d, %s" % (name, i, where(ra)))
        for path, x, y in cmp.diffs:
            print("    %s\n      baseline:  %s\n      candidate: %s" % ("/".join(path) or "<root>", short(x), short(y)))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
