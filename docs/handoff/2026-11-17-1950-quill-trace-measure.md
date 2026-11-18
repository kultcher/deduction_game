# 2026-11-17, Claude-Quill: Tally's trace probe kept as a tool (`claude/trace-measure`; tool only)

- **Base:** main `ae6c304`. **Status:** PR open. **Next:** Bailiff (review and merge; no game
  code, golden can't move).
- **What:** BACKLOG "Keep Tally's trace probe as a tool" ([decided], Michael Nov 17, owner
  Quill). Tally measured trace weight with an uncommitted copy of `tools/measure_evidence.gd`
  carrying three extra modes (handoff in #212). Rather than keep a 72 KB near-copy, the modes
  are now in `measure_evidence.gd` itself: `--what traces`, `--what combined`, `--what support`.
  The shared setup Tally flagged is factored out (search every scene, file the town's work and
  haunt profiles, count the scenes a person fits, the case step), and the unused variable in
  support part (b) is gone. The header documents each mode.
- **Same numbers as Tally's probe:** both run on this branch, size 10, `--day 4`, and their
  JSON lines compared byte for byte. `traces` on seeds 100000–100003: 11 rows, identical.
  `combined` on the same seeds: 3 rows, identical. `support` on 100000–100001: 6 rows,
  identical.
- **Commands** (as Tally ran them; one process per weight branch, in parallel):
  `godot --headless --path . --script res://tools/measure_evidence.gd -- --seeds 100000:100149 --size 10 --what traces --day 3 --out /tmp/w3.jsonl`,
  and `--what combined --day 4` or `--day 5`, and `--what support --day 4` (slow, about a
  minute a seed).
- **Not done (design call):** a `--trace-ratio` flag. The weights are `const` in
  `sim/tuning.gd` (`TRACE_MATCH_WEIGHT`, `TRACE_UNKNOWN_WEIGHT`), so setting them at run time
  would need a new hook. Until then, compare weights by running on a branch that changes them.
  Tally's Python analysis scripts aren't included; ask Tally if they're wanted.
- **BACKLOG:** the item is closed as built in this PR.
