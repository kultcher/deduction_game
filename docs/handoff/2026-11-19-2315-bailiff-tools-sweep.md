# 2026-11-19, Claude-Bailiff: the tools/ sweep from Argon's audit (`claude/nice-mayer-naok85`)

- **Signed:** Claude-Bailiff
- **Base:** main `6e8cb63` (#378).
- **Status:** zero drift: three files deleted, and this entry. PR open.
- **Next actor:** Bailiff merges on green. Seneschal and Michael may want the "Kept" list.

## Why
"Argon's audit: cleanup", group 1 (Michael, Nov 19), gave me the one-off scripts in `tools/`
(audit section 4). I checked each one for callers, suites and live docs before deleting
anything. Most of the list is still in use, so the sweep is small.

## Deleted
- `tools/probe_prior_compare.gd` (and its `.uid`) and `tools/probe_prior_aggregate.py`: the
  Oct 30 prior experiment. Nothing references them, and no suite runs them.

## Kept, and why
| Script | Why it stays |
|---|---|
| `measure_evidence.gd`, `measure_evidence_summary.py`, `measure_interactions_summary.py` | Live measurements: `workshop/live_activity.gd`, `workshop/reading_challenges.gd` and `docs/evidence_catalog_measured.md` cite them. |
| `measure_npc_trust.gd` | Michael's trust-system measurement, written and re-measured Nov 19. |
| `measure_premise_frames.gd` | Reproduces a measurement quoted in `docs/belief_model.md`. |
| `connections_prototype.gd`, `connections_prototype_summary.py` | `docs/belief_model.md` describes the prototype as the offline harness over the connections module. Lantern's call. |
| `replay_54875.gd`, `run_replay_54875.py`, `profile_c0.gd` | The speed replay and solver profiler named in README and DESIGN. Argon's call. |
| `slice_sheets.py`, `make_trace_icons.py` | The art pipeline: `ui/theme.gd`, `ui/trace_art.gd` and `assets/ui/README.md` point to them. |
| `dialogue_voice_sketches.gd`, `.json` | Used by `ui/dialogue_lab.gd` and `tools/dialogue_preview.gd`. They go with Herald's dev-lab removal, not here. |

## Checked
`git grep` for each script's name outside the handoffs and the audit. Nothing else changes,
so golden and the suites are untouched.
