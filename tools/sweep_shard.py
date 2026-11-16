#!/usr/bin/env python3
"""Run one balance-sweep shard: a seed range for one cell, split across parallel
autoplay processes (docs/balance_sweep.md).

    python3 tools/sweep_shard.py --godot BIN --npcs 10 --mode bot --insight 1.0 \
        --seeds 100000:100100 --procs 4 --out OUTDIR [--sha SHA] [--game-timeout 1800]

Each process appends `sweep_v1` records to OUTDIR/results_<cell>_<first>.jsonl. The
runner watches the output: engine error lines between `SWEEP_BEGIN n` and `SWEEP_END n`
are counted against seed n; a process that crashes or exceeds --game-timeout on one game
is restarted on the next seed, and the lost seed gets an error record. Per-game dev logs
are deleted once the game is recorded, unless the game is flagged (errors, stuck, or
wall time over 5x the running median), in which case they are kept under OUTDIR/flagged.
Standard library only.
"""
import argparse
import json
import os
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import threading
import time

ERROR_RE = re.compile(r"(SCRIPT ERROR|^ERROR:|USER ERROR|Parse Error|Invalid call|Invalid access)")


def record_mode(a):
    """The mode a sweep record carries: autoplay's _mode_name, forced demon type included,
    so runner-written failure records fall in the same cell as the games (Codex, #138).
    Autoplay puts _connections after the forced type."""
    mode = a.mode
    conn = mode.endswith("_connections")
    if conn:
        mode = mode[: -len("_connections")]
    mode += "_force_" + a.force_demon if getattr(a, "force_demon", "") else ""
    return mode + ("_connections" if conn else "")


def cell_name(a):
    # The forced demon type is in the name, so a local run never reuses another setting's records.
    force = ("_force_" + a.force_demon) if getattr(a, "force_demon", "") else ""
    return "%d_%s_%s%s" % (a.npcs, a.mode, ("%.2f" % a.insight).rstrip("0").rstrip("."), force)


class Worker:
    def __init__(self, a, first, last, out_dir, idx):
        self.a = a
        self.first = first
        self.last = last  # exclusive
        self.idx = idx
        self.cell = cell_name(a)
        self.results = os.path.join(out_dir, "results_%s_%d.jsonl" % (self.cell, first))
        self.errors_path = os.path.join(out_dir, "errors_%s_%d.jsonl" % (self.cell, first))
        self.flag_dir = os.path.join(out_dir, "flagged")
        self.log_root = tempfile.mkdtemp(prefix="sweep_logs_%d_" % idx)
        self.walls = []
        self.done = set()

    def _recorded(self):
        out = {}
        if os.path.exists(self.results):
            with open(self.results, encoding="utf-8") as fh:
                for line in fh:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        rec = json.loads(line)
                    except ValueError:
                        continue
                    out[int(rec["seed"])] = rec
        return out

    def _log_files(self, seed):
        found = []
        for base, _dirs, files in os.walk(self.log_root):
            for f in files:
                if f.startswith("case_%d." % seed) or f.startswith("case_%d_" % seed):
                    found.append(os.path.join(base, f))
        return found

    def _note_error(self, seed, kind, lines):
        with open(self.errors_path, "a", encoding="utf-8") as fh:
            fh.write(json.dumps({"seed": seed, "cell": self.cell, "kind": kind, "count": len(lines),
                                 "lines": lines[:20]}) + "\n")

    def _finish_game(self, seed, err_lines):
        recs = self._recorded()
        rec = recs.get(seed)
        flagged = bool(err_lines)
        if rec is not None:
            wall = float(rec.get("wall_s", 0.0))
            if len(self.walls) >= 10 and wall > 5.0 * statistics.median(self.walls):
                flagged = True
            self.walls.append(wall)
            if rec.get("stuck"):
                flagged = True
        if err_lines:
            self._note_error(seed, "engine_errors", err_lines)
        for path in self._log_files(seed):
            if flagged:
                os.makedirs(self.flag_dir, exist_ok=True)
                shutil.move(path, os.path.join(self.flag_dir, "%s_%s" % (self.cell, os.path.basename(path))))
            else:
                os.remove(path)
        self.done.add(seed)

    def run(self):
        seed = self.first
        recorded = self._recorded()
        while seed < self.last:
            if seed in recorded:
                seed += 1
                continue
            games = self.last - seed
            cmd = [self.a.godot, "--headless", "--path", self.a.project, "--script", "res://tools/autoplay.gd", "--",
                   "--seed", str(seed), "--games", str(games), "--npcs", str(self.a.npcs), "--no-trace",
                   "--dynamic", "--results-jsonl", self.results, "--sha", self.a.sha,
                   "--log-dir", self.log_root, "--insight", str(self.a.insight)]
            base, flags = split_mode(self.a.mode)
            if base == "passive":
                cmd.append("--passive")
            elif base == "bot_pre_m4":
                cmd.append("--pre-m4")  # the bot policy before meeting plan M4, for A/Bs
            elif base == "no_present":
                cmd.append("--no-present")  # Phase 0 silent-bot cell: never presents a case
            elif base == "present_vote":
                cmd.append("--present-and-vote")  # Phase 0: no vigils, wards or searches
            if "nocross" in flags:
                cmd.append("--no-crosscheck")  # Phase 5: no cross-check case seeding
            if "connections" in flags:
                cmd.append("--connections")  # the connections belief model on (off in play)
            if "nodeclare" in flags:
                cmd.append("--no-declare")  # Phase 5: never declares the demon type
            if self.a.force_demon:
                cmd += ["--force-demon", self.a.force_demon]
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1,
                                    errors="replace")
            current = None
            started = time.time()
            err_lines = []
            killed = {"flag": False}

            def watchdog():
                while proc.poll() is None:
                    if current_holder[0] is not None and time.time() - current_holder[1] > self.a.game_timeout:
                        killed["flag"] = True
                        proc.kill()
                        return
                    time.sleep(5)

            current_holder = [None, started]
            t = threading.Thread(target=watchdog, daemon=True)
            t.start()
            for line in proc.stdout:
                line = line.rstrip("\n")
                m = re.match(r"^SWEEP_BEGIN (\d+)", line)
                if m:
                    current = int(m.group(1))
                    current_holder[0] = current
                    current_holder[1] = time.time()
                    err_lines = []
                    continue
                m = re.match(r"^SWEEP_END (\d+)", line)
                if m:
                    self._finish_game(int(m.group(1)), err_lines)
                    current = None
                    current_holder[0] = None
                    err_lines = []
                    continue
                if current is not None and ERROR_RE.search(line):
                    err_lines.append(line[:400])
                if line.startswith("case ") and self.a.echo:
                    print("[w%d] %s" % (self.idx, line), flush=True)
            proc.wait()
            recorded = self._recorded()
            if current is not None and current not in recorded:
                # The process died (or was killed) inside this game: record it and move on.
                self._note_error(current, "timeout" if killed["flag"] else "crash", err_lines + ["exit %s" % proc.returncode])
                if os.path.exists(self.results) and os.path.getsize(self.results) > 0:
                    with open(self.results, "rb") as fh:
                        fh.seek(-1, os.SEEK_END)
                        if fh.read(1) != b"\n":
                            with open(self.results, "a", encoding="utf-8") as fa:
                                fa.write("\n")
                with open(self.results, "a", encoding="utf-8") as fh:
                    fh.write(json.dumps({"schema": "sweep_v1", "seed": current, "npcs": self.a.npcs, "mode": record_mode(self.a),
                                         "insight": self.a.insight, "sha": self.a.sha, "dynamic": True,
                                         "failed": "timeout" if killed["flag"] else "crash", "complete": False}) + "\n")
                for path in self._log_files(current):
                    os.makedirs(self.flag_dir, exist_ok=True)
                    shutil.move(path, os.path.join(self.flag_dir, "%s_%s" % (self.cell, os.path.basename(path))))
                recorded = self._recorded()
                seed = current + 1
            else:
                missing = [s for s in range(seed, self.last) if s not in recorded]
                if not missing:
                    break
                if missing[0] == seed and proc.returncode != 0 and current is None:
                    # Failed before starting any game (a load error): don't loop forever, but
                    # record every remaining seed as failed so none goes missing silently.
                    self._note_error(seed, "startup", ["exit %s" % proc.returncode])
                    with open(self.results, "a", encoding="utf-8") as fh:
                        for s_left in missing:
                            fh.write(json.dumps({"schema": "sweep_v1", "seed": s_left, "npcs": self.a.npcs, "mode": record_mode(self.a),
                                                 "insight": self.a.insight, "sha": self.a.sha, "dynamic": True,
                                                 "failed": "startup", "complete": False}) + "\n")
                    break
                seed = missing[0]
        shutil.rmtree(self.log_root, ignore_errors=True)


BASE_MODES = ["passive", "bot", "bot_pre_m4", "no_present", "present_vote"]
MODE_FLAGS = ["nocross", "nodeclare", "connections"]


def split_mode(mode):
    """A cell mode is a base mode plus optional suffixes, as autoplay names them:
    bot_nocross, bot_nodeclare, bot_nocross_nodeclare (Phase 5), and _connections last
    (the connections belief model on; passive may take it too)."""
    flags = []
    for f in reversed(MODE_FLAGS):
        if mode.endswith("_" + f):
            flags.insert(0, f)
            mode = mode[: -len(f) - 1]
    if mode not in BASE_MODES or (mode == "passive" and [f for f in flags if f != "connections"]):
        raise SystemExit("bad mode %r" % mode)
    return mode, flags


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", required=True)
    ap.add_argument("--project", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    ap.add_argument("--npcs", type=int, required=True)
    ap.add_argument("--mode", required=True, help="passive, bot, bot_pre_m4, no_present or present_vote, "
                    "optionally with _nocross / _nodeclare (Phase 5) and then _connections")
    ap.add_argument("--force-demon", default="", help="deal this demon type (autoplay --force-demon), e.g. daykiller")
    ap.add_argument("--insight", type=float, default=1.0)
    ap.add_argument("--seeds", required=True, help="first:last (last exclusive)")
    ap.add_argument("--procs", type=int, default=4)
    ap.add_argument("--out", required=True)
    ap.add_argument("--sha", default=os.environ.get("GITHUB_SHA", ""))
    ap.add_argument("--game-timeout", type=float, default=1800.0)
    ap.add_argument("--echo", action="store_true")
    a = ap.parse_args()
    split_mode(a.mode)
    first, last = [int(x) for x in a.seeds.split(":")]
    os.makedirs(a.out, exist_ok=True)
    n = last - first
    procs = max(1, min(a.procs, n))
    bounds = [first + (n * i) // procs for i in range(procs + 1)]
    workers = [Worker(a, bounds[i], bounds[i + 1], a.out, i) for i in range(procs) if bounds[i] < bounds[i + 1]]
    threads = [threading.Thread(target=w.run) for w in workers]
    t0 = time.time()
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    total = sum(len(w._recorded()) for w in workers)
    print("shard %s %s: %d/%d records in %.0f s" % (cell_name(a), a.seeds, total, n, time.time() - t0), flush=True)
    if total < n:
        print("shard %s %s: %d seed(s) have no record" % (cell_name(a), a.seeds, n - total), flush=True)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
