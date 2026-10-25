"""Run the replay and reject printed script errors even if Godot exits zero."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess


def failed_output(output):
    return bool(re.search(r"(?m)^(?:SCRIPT ERROR:|FAIL[: ])", output))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--stage", choices=["opening", "day3-four", "day4-six"], default="opening")
    parser.add_argument("--timeout", type=int, default=600)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    project = args.project.resolve()
    run = subprocess.run(
        [str(args.godot.resolve()), "--headless", "--path", str(project),
         "--log-file", str(output / "engine.log"), "--script", "res://tools/replay_54875.gd", "--", "--stage", args.stage],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
        timeout=args.timeout, env={**os.environ, "APPDATA": str(output / "userdata")},
    )
    text = run.stdout + run.stderr
    (output / "replay.txt").write_text(text, encoding="utf-8")
    source = project / "logs/migration/replay_54875/measurement.json"
    bad = run.returncode != 0 or failed_output(text)
    if source.exists():
        value = json.loads(source.read_text(encoding="utf-8"))
        value["script_errors"] = len(re.findall(r"(?m)^SCRIPT ERROR:", text))
        value["valid_run"] = not bad
        (output / "measurement.json").write_text(json.dumps(value, indent=2), encoding="utf-8")
        print(json.dumps({"valid_run": not bad, "script_errors": value["script_errors"],
                          "shared": sum(p["model"] == "shared" for p in value["presentation"]),
                          "refreshes": value.get("refreshes"),
                          "impossible": len(value.get("impossible_refreshes", []))}))
    else:
        bad = True
    print("FAIL replay" if bad else "PASS replay", flush=True)
    return int(bad)


if __name__ == "__main__":
    raise SystemExit(main())
