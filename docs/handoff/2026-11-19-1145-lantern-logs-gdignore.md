# 2026-11-19, Claude-Lantern: Godot skips the logs folder (`claude/logs-gdignore`; zero drift)

- **Base:** main `fa2b2e6`. **Status:** PR open. **Next:** Bailiff.
- **Why:** on opening the project, Michael sees parse errors from old probe scripts in
  `logs/`: `trace_records_probe.gd`, `dialogue_shapes.gd` and `shape_probe.gd`. They preload
  code the purge removed. None of them is tracked (`logs/` is git-ignored), so they're local
  leftovers, and he can delete them.
- **What changed:** a tracked, empty `logs/.gdignore`, as `tools/golden/` and the art source
  folders already have, so Godot never imports or parses anything under `logs/`. `.gitignore`
  goes from `logs/` to `logs/*` plus `!logs/.gdignore`, so the logs themselves stay untracked.
- **Not changed:** `tools/test_ask_night_results.gd` also showed an error for him ("could not
  find res://sim/content.gd"). That file exists on main and the suite passes, so it's most
  likely a branch switch or a stale import cache on his side; reopening the project or running
  `--import` should clear it.
- **Measured:** nothing to measure. No game code changes, so golden doesn't move.
- **Proposed for the backlog:** none.
