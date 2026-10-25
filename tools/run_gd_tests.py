"""Run headless GDScript suites, including suites that print failures but exit 0.

Slow suites (SLOW below) are skipped in a full run unless --include-slow is given;
naming a suite explicitly always runs it. Run them before merging, and whenever a
change touches tracing, logging, determinism or whole-game flow.
"""
import argparse
import os
from pathlib import Path
import re
import subprocess

# test_trace plays twelve full games with tracing on/off parity checks (~10 minutes).
SLOW = {"test_trace"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--output", type=Path, default=Path("logs/test-run"))
    parser.add_argument("--timeout", type=int, default=600)
    parser.add_argument("--include-slow", action="store_true", help="also run the slow suites in a full run")
    parser.add_argument("tests", nargs="*")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    user_data = output / "userdata"
    user_data.mkdir(exist_ok=True)
    env = {**os.environ, "APPDATA": str(user_data)}
    project = args.project.resolve()
    suites = [project / "tools" / (name.removesuffix(".gd") + ".gd") for name in args.tests] if args.tests else sorted((project / "tools").glob("test_*.gd"))
    skipped = []
    if not args.tests and not args.include_slow:
        skipped = [suite.stem for suite in suites if suite.stem in SLOW]
        suites = [suite for suite in suites if suite.stem not in SLOW]
    failed = []
    pattern = re.compile(r"(?m)^(?:FAIL[ :]|ERROR: FAIL|SCRIPT ERROR:)|(?:FAILURES:\s*[1-9]|failures:\s*[1-9]|\b[1-9]\d* failures\b)")
    for suite in suites:
        cmd = [str(args.godot.resolve()), "--headless", "--path", str(project), "--log-file", str(output / "engine.log"), "--script", "res://tools/" + suite.name]
        try:
            result = subprocess.run(cmd, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=args.timeout)
            text = result.stdout + result.stderr
            bad = result.returncode != 0 or bool(pattern.search(text))
        except subprocess.TimeoutExpired as exc:
            text = (exc.stdout or b"").decode("utf-8", errors="replace") if isinstance(exc.stdout, bytes) else exc.stdout or ""
            text += "\nFAIL: suite timed out\n"
            bad = True
        (output / (suite.stem + ".txt")).write_text(text, encoding="utf-8")
        print(f"{'FAIL' if bad else 'PASS'} {suite.stem}", flush=True)
        if bad:
            failed.append(suite.stem)
    print(f"{len(suites) - len(failed)}/{len(suites)} suites passed; failures: {', '.join(failed) or 'none'}", flush=True)
    if skipped:
        print(f"Skipped slow suites: {', '.join(skipped)} (use --include-slow, or name them)", flush=True)
    return bool(failed)


if __name__ == "__main__":
    raise SystemExit(main())
