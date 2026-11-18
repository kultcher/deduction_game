# 2026-11-18, Argon: fix 32-bit hash collisions in CaseEval/_fits_cache and sub-universe handle caches (`argon/fix-fits-cache-collision`)

- **Base:** `878ddaa` (main). **Status:** Ready for review. **Next:** Bailiff / Codex review, merge on green Linux CI (`--tol 0`).

## Root cause

`CaseEval._fits_cache` (`workshop/case_eval.gd`) was keyed solely by 32-bit `hash()` integers (`neutral_key` in `_class_fits`, `key` in `_personal_fits`) without storing or verifying the full structured key (`ref`). On a birthday-paradox collision in `hash()`, a cached `PackedFloat64Array` from an earlier compiled case (e.g. `nc = 843` on a 1-card set) was returned for a different compiled case with a different class count (e.g. `nc = 5148` on a 55-card set), causing `IndexOutOfRangeException` at `double w0 = tp * fits[c];` in `CaseEvalKernel.EvaluatePosterior`.

Reproduced deterministically on `c676018` (`autoplay.gd --seed 100258 --games 1 --npcs 10 --no-trace --dynamic --insight 1.0`, Day 3 `jory` demon check; colliding 32-bit key `514368271` between an 843-class 1-card case and a 5148-class 55-card case).

The audit found the same hash-only pattern in:
- `CaseEval._valid_cache` and `CaseEval._premise_cache` (`workshop/case_eval.gd`)
- `ReasonAttribution._fits_cache` (`workshop/reason_attribution.gd`)
- `SolverBackend.get_sub_universe_handle` (`workshop/solver_backend.gd`, keyed in GDScript and C# `PackedUniverseByKey` by `"cc_reps:" + str(hash([u_key, cc.rep]))` without checking `[base_handle, indices]`)

## What changed

- **`workshop/case_eval.gd`:**
  - Updated `_class_fits` and `_personal_fits` (`_fits_cache`), `_valid_table` (`_valid_cache`), and `_premise_mask` (`_premise_cache`) to store `{"ref": ref.duplicate(true), "out": out}` and require `entry.ref == ref` on cache hit (matching `_bare_fits_cache`, `_own_cache`, and `_team_prior_cache`).
  - Added cache-size capping (`> 2048`) on neutral insertion in `_class_fits` so empty-personal callers cannot grow `_fits_cache` unbounded.
  - Added `_cc_reps_handle` helper including `rep.size()` in the key and deduplicating the 3 `cc_reps` call sites.
  - Added `assert(fits.size() == nc and fits_before.size() == nc, ...)` in `_evaluate_impl`.
- **`workshop/reason_attribution.gd`:**
  - Updated `_subset_fits` (`_fits_cache`) to store `{"ref": ref.duplicate(true), "out": ...}` with `[cc.key, cc.rep, ...]` and verify `entry.ref == ref` on hit.
- **`workshop/solver_backend.gd`:**
  - Changed `get_sub_universe_handle` to track buckets in `_sub_universe_handles` (cleared in `clear_context()`), verify `base == base_handle and indices == indices`, and disambiguate the C# `RegisterIndexedSubUniverse` key (`"<sub_key>#<n>"`) on hash collision.
- **`workshop/cs/CaseEvalKernel.cs`:**
  - Added explicit shape checks in `EvaluatePosterior` (`evalInts[8] == nc`, `fits.Length == nc`, `fitsBefore.Length == nc`, `counts.Length == nc * ns`, `ns > 1 && ownOf.Length != cc.ClassOf.Length`, `caseErrs.Length == k`, `ownErrs/ownQs/flatOwnCodes`, `routeCredits/testLog2Ratios == cc.NumTests`), throwing `ArgumentException` with dimensions instead of `IndexOutOfRangeException`.
- **`tools/test_connections_cache.gd`:**
  - Added `_cache_collision_safety()` injecting forced 32-bit hash collisions with wrong-sized arrays into `CaseEval._fits_cache`, `_valid_cache`, `_premise_cache`, `ReasonAttribution._fits_cache`, and `SolverBackend.get_sub_universe_handle`, verifying exact zero-drift output and collision disambiguation.

## Verification

- **Fix proof on colliding commit (`c676018`):** Applied the `_fits_cache` fix cleanly on `c676018` in a temporary worktree and ran `autoplay.gd --seed 100258 --games 1 --npcs 10 --no-trace --dynamic --insight 1.0` -> exited `0` (`good wins on day 4`, zero errors/exceptions), then removed the worktree.
- **Branch (`878ddaa` + fix):**
  - `dotnet build Demonologist.csproj -c Debug`: 0 errors.
  - `autoplay.gd --seed 100258 --games 1 --npcs 10 --no-trace --dynamic --insight 1.0`: exited `0` (`good wins on day 3`).
  - `test_connections_cache.gd`: 50/50 checks passed.
  - Suites via `tools/run_gd_tests.py`: `test_case_eval`, `test_connections`, `test_connections_core`, `test_premise_step3`, `test_connections_cases`, `test_connections_why`, `test_connections_pairings`, `test_workshop_regressions`, `test_workshop_efficiency`, `test_roles_official` all passed (`test_csharp_slice_c0` failed at `EvalMathBatch_Tol0[152]` by `1.776e-15` = 1 ULP, pre-existing Windows vs Linux libm difference unrelated to this PR).
  - `golden_capture.gd` vs `tools/golden/baseline_44073d9`: `seed_42_7` and `seed_900_7` bit-identical (`--tol 0`); `seed_54875_10`, `seed_692_10`, and `seed_98933_10` match within `--tol 1e-14` (`1e-16` Windows vs Linux libm difference; Linux CI `--tol 0` decides).
