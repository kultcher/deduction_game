# 2026-11-17, Claude-Steward: maintenance report, DEEP run (maintenance/2026-11-17)

- **Base:** `origin/main` at `6e99d80`. Range reviewed: `b99a2fe..6e99d80` (36 PRs).
- **Status:** PR open, docs only. **Next actor:** Bailiff (merge), Herald and Bailiff for
  the red `main`.
- **What changed:** `docs/maintenance/2026-11-17.md` (the report); `README.md` now points at
  `docs/handoff/` instead of the frozen `docs/handoff_log.md`, and lists
  `sim/fabrication_check.gd` in the code map.
- **Measured:** built locally (Godot 4.7.2 .NET, Debug) and ran `tools/test_social.gd` at
  `4feed81` (passes), `b28d6d7` (#178, fails) and `6e99d80` (fails): "a false Night Watch's
  night story matches their fake report", 2 of 20 towns. Nothing else was run.
- **For the leads:** report section A lists findings by owner: Beadle A1, A2, A3, A5, A10;
  Lantern A4, A8, A9; Argon A6, A7; Herald the `test_social` failure (from #178) and A10.

## Proposed for the backlog

- **Put `test_social` on the CI fast list** (it would have caught #178): what I saw is in
  report B and E1. Suggested `[open]`, owner Bailiff.
