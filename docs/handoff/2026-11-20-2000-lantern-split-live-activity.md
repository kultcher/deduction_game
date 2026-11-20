# 2026-11-20, Claude-Lantern: split live_activity.gd into a chain of five modules (claude/split-live-activity)

- **Base:** main at ce7e6e89 (after #449).
- **Status:** PR open. **Next:** Bailiff.
- **Zero drift:** code moved, not rewritten. Golden identical at `--tol 0`.
- Backlog: "File splits, Tier 2", `workshop/live_activity.gd`. Independent of #450 (the
  case_eval split): no shared files except README.md, where the two entries sit in different
  places in the code map.

## What changed

`workshop/live_activity.gd` had 2,032 lines. It is now an inheritance chain:
`live_activity.gd` extends `live_activity_factors.gd` extends `live_activity_pack.gd` extends
`live_activity_profiles.gd` extends `live_activity_base.gd`.

| File | Lines | Holds |
|---|---|---|
| `live_activity_base.gd` | 14 | the preloads (Tuning, C, History, DayPresence, Chronology) and the movement constants used across files (VIGIL_MISS, GOOD_OWN_ALIBI_OUT, WALKER_CLAIM_*) |
| `live_activity_profiles.gd` | 567 | movement inputs and per-person profiles: `relevant`, `movement_inputs`, `role_of`, `role_hearing`, `_paths`, `own_home_cards`, the day-demon share (`has_day_evidence`, `declared_demon_type`, `day_demon_share`, `mix_demon`), `good_walk_chance`, PROFILE_RATES, `_profile_paths`, `demon_routes` and its cache, `relationships`; and the GDScript single-person model: `_likelihood_gd`, `_crossing_probability_gd`, `evaluate_trace_for_person`, `_alibi_incident`, `_home_of`, `_observed` |
| `live_activity_pack.gd` | 335 | the C# packing helpers matching `workshop/cs/LiveActivity.cs` (`_block_code`, `_move_role_code`, `_align_code`, `_intern_tok`, `_pack_view_env`, `_pack_activity_cards`, _CARD_STRIDE, `_env_cache`) and the bounded routes (`routes`, `_routes_dispatch`, `_routes_cs`, `route_cache`, `_count`) |
| `live_activity_factors.gd` | 977 | the joint factor machinery: list mixing (`_mixed_lists`, `_factors_cs`, `_list_mix`, `certain_for_count`, `_log_good_of`), `_factors_core`, the quiet-night Warden guards, `_sighting_contests`, `_told_cursed`, `hex_kills`, `hex_successions`, the scene tables (`_build_scene_tables_cs`, `_scion_succession_splits_cs`, `_append_scene_packed`) and the C# factor handles (`_ensure_factor_handle`, `_factor_handles`, the `_mru_*` statics); with the diagnostics flags `hex_factor_enabled`, `sighter_contests_enabled`, `quiet_guards_enabled`, `quiet_guards_skip` |
| `live_activity.gd` | 160 | the public face: `available`, `factors`/`_factors_dispatch` and `cache`, `score`, `scores`, `_likelihood` (typed and dispatch), `crossing_probability` and its dispatch |

- Every `LiveActivity.<fn>` and every `preload("res://workshop/live_activity.gd")` caller is
  unchanged (including the `Activity`, `Live` and `Movement.Live` aliases): functions,
  constants and static vars are all inherited.
- **No loader was needed.** A call-graph script found no function that calls one further down
  the chain, so no call needed a prefix. Nothing in the moved code changed.
- **Grouping differs a little from the first guess:** the GDScript single-person readings
  (`_likelihood_gd`, `_crossing_probability_gd`, `evaluate_trace_for_person`, `_observed`)
  sit with the profiles, not with the C# dispatch, because they call only profile helpers and
  `_pack_activity_cards` and `_build_scene_tables_cs` call `_alibi_incident` and
  `evaluate_trace_for_person`. The public `_likelihood` and `crossing_probability` stay in the
  outer file with `score` and `factors`. `routes` sits with the packing because `_list_mix`
  calls it. `_told_cursed` sits with the factors, its only callers.
- Within each file the declarations keep their original order, each with the comments that
  stood above it (the `# --- ... ---` section markers included).
- No C# change. `workshop/cs/LiveActivity.cs` names the file only in a comment ("port of
  workshop/live_activity.gd"), which stays true; no C# or GDScript looks up a LiveActivity
  method by name, and nothing reads live_activity.gd's source text.
- The README code map has an entry for the new files.

## Static vars

Each of the 14 static vars is declared once, in the file whose functions use it (table above);
nothing redeclares one. Tools, tests and the game set or clear them through the outermost class
(`LiveActivity`, `Activity`, `Movement.Live`): `workshop/caches.gd`'s `clear_all()` (the caches
and `_mru_*`), `connections.gd` (`hex_factor_enabled`), `workshop_canvas.gd` (the quiet-guard
flags), `case_eval.gd` (reads the flags into its keys), and 15 suites plus `fixture_seeds.gd`
and two measurement tools.

- A probe on the real chain set every static var through `live_activity.gd` (dictionary
  mutation, reassignment, `+=`) and read it back through the declaring file, then set some
  through the declaring file and read them through `live_activity.gd`, then ran
  `Caches.clear_all()` and checked every cache and `_mru_*` reset. 0 mismatches. The probe was
  deleted.

## Measured

- **Import:** `godot --headless --path . --import`: no parse or script errors; `.uid` files committed.
- **Pure move:** a script compared the old file (origin/main) with the five new ones. All 86
  declarations (59 functions, 14 static vars, 13 constants) appear exactly once, each with an
  identical body; there are no new declarations. Every non-blank line of the old file is
  present; the only added lines are the 25 header lines (the old header, new headers and
  `extends`). No call goes down the chain.
- **Golden** against `baseline_7005cc6` at `--tol 0 --ignore engine`: all 5 seeds identical
  (42, 900, 692, 54875, 98933).
- **Speed (for Argon):** two golden captures each, run alone on the same machine, alternating:
  origin/main 178.3 s and 180.4 s, split 185.4 s and 175.6 s (means 179.4 s vs 180.5 s, +0.6%,
  within the run-to-run spread).
- **Suites:** the whole CI fast list (217 suites, which includes `test_workshop_live_activity`,
  `test_demon_types` and every LiveActivity static-var suite on it) plus the 9 suites that
  call LiveActivity or set its statics and aren't on the list (`test_demon_declaration`,
  `test_evidence_cards`, `test_own_night_knowledge`, `test_self_sighting`,
  `test_social_credibility`, `test_ui`, `test_workshop_live_canvas`,
  `test_workshop_profile_traces`, `test_workshop_two_traces`) and `test_tuning_hoist`:
  227 of 227 pass, run in two parallel chunks.
