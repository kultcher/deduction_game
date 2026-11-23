# 2026-11-23, Argon: zero-drift `outer_prep` deduplication and GDScript hot-path cleanup

- **Agent:** Argon
- **Base:** `main` at `9fff7143` (`argon/outer-prep-dedup`)
- **Status:** PR open against `main`, awaiting green CI (`Golden diff (Linux)` at `--tol 0` against `baseline_1bf8a4b`, no re-baseline) and Codex review for merge.
- **Next actor:** Argon (covering merge while Bailiff is paused).

## What changed and why

Seven zero-drift GDScript optimizations targeting `outer_prep`, presentation duplication, and per-world/per-person overhead:

1. **`workshop/chronology.gd`**: `TimeModel.expand` now uses `_person_index` instead of mapping `view.people`, shallow-copies `world` (`duplicate(false)`), and derives `alternative["__key"] = base_key * (n + 1) + index + 1` directly (matching `WorldDomain.ComputeKey`) instead of crossing `WorldDomain.key` per candidate world.
2. **`workshop/support_model.gd`**: `_explain` scores `result.support` and `result.rival` directly via `_single_world_score` / `_apply_factors` instead of computing `prior_scores` over the full world universe.
3. **`workshop/solver.gd`**: `analyze` reuses `base` for `proposed` when `proposed_cards == cards`, `positions`, `answers`, and `temporal_positions` are empty, and `conclusion.at` is `""` or `view.alignment_epoch`.
4. **`workshop/jury.gd`**: `_assess_target_eval` skips `Solver.analyze(view, case_data, {}, false)` (`shared`) for `bounded` listeners (where `_bounded_objection` replaces `_objection`); `_consequences_eval` hoists the person-independent `Reasoner.direct_checks` check (with `conclusion.type = ""`), `per_card_trust`, `curse_origin`, `_source_trust` sums/counts, and `withdrawn_empty` non-context mentions out of `for person in view.people`.
5. **`workshop/connections.gd`**: `_prepare_key_ctx` precomputes per-card burden factors, `missed_forced_trigger`, and Night Watch / Lamplighter mix metadata once per refresh; `_judge_key_fast` calls `_mix_key_fast` (falling back to `_mix_key` if `listener != ctx.listener`).
6. **`game/workshop_ownership.gd`**: `_refresh` reuses `pre_bundle` for `doubt_bundle` when `same_inputs` is true instead of running `SourceDoubt.derive` a second time on the unchanged plan.
7. **`game/game_presentation.gd` & `game/workshop_presentation.gd`**: `workshop_canvas_retire` returns whether any retraction occurred; `_present` uses `_readiness_detail` to reuse `snapshot` / `prepared` when nothing retracted, skips the redundant `Bridge.capture` + `Shared.prepare` readiness check when `proposals` / `withdrawn` / key order are unchanged, and skips the post-refresh `Shared.prepare` rebuild when `source_doubt`, `theories`, and `attention_focus` already match.

## What was measured

Sequential single-process Windows `Debug` C# build (`SolverBackend.profiling_enabled = true`), against `main` (`9fff7143` / `1bf8a4bd`):

- **Isolated Day-3 presentation** (`692:10`, 4 reports -> 8 NPCs):
  - Total: `1736 ms` -> **`1436 ms`** (`-17.3%`)
  - `outer_prep`: `672.3 ms self | 1379.2 ms incl | 78 calls` -> **`469.0 ms self | 1118.9 ms incl | 62 calls`** (`-30.2%` self, `-18.9%` incl)
  - `world_domain`: `221.8 ms self | 304.9 ms incl | 1364 calls` -> **`185.0 ms self | 244.1 ms incl | 931 calls`** (`-16.6%` self)
- **3-seed 10-NPC suite** (`54875`, `692`, `98933` to Day 4):
  - Total wall: `93939 ms` -> **`92223 ms`** (`-1.8%`)
  - All refreshes (`776` refs): `78.94 ms/ref` -> **`76.87 ms/ref`** (`-2.6%`)
  - Day 3+ refreshes (`257` refs): `125.81 ms/ref` -> **`122.38 ms/ref`** (`-2.7%`)
  - `outer_prep` self: `13743.3 ms` (`2516` calls) -> **`9953.2 ms`** (`2500` calls, **`-27.6%`**)
  - `reason_attribution` self: `6543.5 ms` -> **`5835.2 ms`** (`-10.8%`)
  - Seed `692` Day-3 presentation (in full run): `1652 ms` -> **`1464 ms`** (`-11.4%`)
  - `Connections` cache: identical `11324` hits / `9714` misses (`53.8%`).
- **Coroner `51795:10`**:
  - `WorldDomain.key` (`28,224` calls previously) dropped out of the top boundary calls.
  - Day-3 morning (`step=15`): `3531 ms` -> `3502 ms`; total wall `50397 ms` -> `52431 ms` (within run-to-run variance on C#-dominated passive steps).
- **Verification**:
  - Presentation parity check vs pre-edit `origin/main` (seed `692:10` Day-3 meeting + private presentations + curse `TimeModel.expand`): `PASS: presentation parity exact (10 NPCs checked)`.
  - `Connections.cache_verify` across all 5 golden seeds (`900/7`, `42/7`, `54875/10`, `692/10`, `98933/10`): `13,280` hits, `12,173` misses, `0` wrong.
  - 32 targeted GDScript suites passed (`0` failures), including `test_shared_delusion`, `test_own_burden_knowledge`, `test_roles_secrets`, `test_connections_cache`, `test_connections`, `test_connections_core`, `test_connections_pairings`, `test_connections_cases`, `test_connections_why`, `test_workshop_presentation`, `test_workshop_ownership`, `test_workshop_reasoning`, `test_workshop_consequences`, `test_workshop_profiling`, `test_workshop_action`, `test_workshop_live_canvas`, `test_shared_model`, and all burden/nightwatch/lamplighter/demon suites.
  - 5-seed Windows golden capture vs `tools/golden/baseline_1bf8a4b`: `seed_42_7` identical at `--tol 0` (`104` records); all 5 seeds match at `--tol 1e-12` (Windows vs Linux `Math.Exp` 1-ULP difference; Linux CI checks `--tol 0`).

## Proposed for the backlog

None.
