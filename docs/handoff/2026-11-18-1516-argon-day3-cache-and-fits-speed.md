# 2026-11-18, Argon: Day 3 cache caps, `_fits_over` / `RoleConstraints` C# memo dispatch, and `_connections_drop` fast path (`argon/day3-cache-and-fits-speed`; zero drift)

- **Base:** main `3aef7380`. **Status:** PR open. **Next:** Claude-Quill (`(c)`: `_fits_over` and `RoleConstraints` C# memo dispatch) and Claude-Lantern (`(b)` and `(d)`), then Bailiff once Linux CI `--tol 0` golden is green.
- **What and why:** Implements the three zero-drift speed wins (`(b)`, `(c)`, `(d)`) from the Nov 18 Leads' review of the `16010` profile (`(a)` dawn-refresh deferral is intentionally left out for a separate re-baselined PR).

## Changes

- **(b) Cache caps + `RoleConstraints` `SOFT_EVENTS` strip with `view.chronology` fix (`workshop/role_constraints.gd`, `workshop/live_activity.gd`, `workshop/case_eval.gd`):**
  - Raised cache caps to prevent Day 3 mid-turn thrashing: `RoleConstraints.cache` `64 → 2048`, `LiveActivity._env_cache` `16 → 128`, `LiveActivity.route_cache` `128 → 2048`, `LiveActivity.cache` `128 → 2048`, `LiveActivity._factor_handles` `64 → 2048`, `CaseEval._compiled` `2048 → 4096`, `CaseEval._fits_cache` `2048 → 4096`.
  - Added `RoleConstraints._hard_timeline(view)` stripping `SOFT_EVENTS` (`nomination`, `meeting`, `vote`, `vote_yes`, `accusation`, `reading`, `clear`) from `timeline.events` in `_get_cache_entry`, **together with adding `view.get("chronology", {})`** to the key so changes to the curse window (`chronology.curse`) remain distinct.

- **(c) `_fits_over` reps skip + `RoleConstraints` C# coarse-mask memo dispatch (`workshop/case_eval.gd`, `workshop/role_constraints.gd`, `workshop/cs/SolverContext.cs`, `workshop/cs/RoleConstraints.cs`, `workshop/cs/SolverBridge.cs`):**
  - In `CaseEval._fits_over`, when `cc_reps_handle >= 0`, skipped allocating and populating `reps` and `failed` world Dictionary arrays; looks up `universe[cc.rep[which[x]]]` lazily only if `not relayed_seers.is_empty()` and `content > 0.0`. Added `CaseEval.use_cc_reps_handle` test switch for handle-off parity checks.
  - Added persistent coarse-mask memo slots in `SolverContext` (`RoleConstraintMemos`, cleared in `SolverContext.Clear()` / `RoleClearMemos()`) and `RoleConstraintsKernel.TryLookupMemo` + optional `memoSlot` on `FitsWeights`. `RoleConstraints._fits_weights_dispatch` and `_fit_weight_dispatch` now resolve hits in C# (`RoleTryLookupMemoByHandle`) and compute empty-`reps` slice size via `GetUniverseSize(u_handle)` / `sub_indices.size()`, eliminating the per-world GDScript mask/dictionary loop. All repeat judge calls (bare claims, neutral + personal, per-doubted card) remain intact.

- **(d) `ReasonAttribution._connections_drop` fast path (`workshop/connections.gd`, `workshop/reason_attribution.gd`):**
  - Added `Connections.drop_card_posterior` and wired `ReasonAttribution._connections_drop` to it.
  - Falls back to full `Connections.refresh` whenever `cid` is a firsthand seed card, appears in any core item's `cards` or `ctx`, appears in any stored case's `cards`/`challenges` (or a non-`ALWAYS_ON` item sharing cards with one), or changes core/case/non-`ALWAYS_ON` structure (when `core.seed` is non-empty).
  - Otherwise reuses unchanged `items`, `core.lean`, and `cases.lean`, recomputing only items modified by dropping `cid` (with identical premise centring) and re-running `combine(...)`. Verified against full `refresh(...)` when `Connections.cache_verify = true` (with `cache_enabled`/`cache_verify`/`capture`/`cache_stats` isolated during verification).

## Verification

- **Golden (`tools/golden_diff.py`):**
  - **Windows `origin/main` vs branch at `--tol 0`:** all 5 seeds (`42_7` 112 records, `900_7` 183 records, `692_10` 251 records, `98933_10` 291 records, `54875_10` 345 records) are **identical**.
  - **Linux `tools/golden/baseline_e287b3d` vs Windows candidate:** `seed_42_7` identical at `--tol 0`; all 5 seeds match at `--tol 1e-13` (1–2 ULP `~1e-16` Windows `ucrtbase` vs Linux `libm` difference already present on `origin/main`). CI Linux golden check will verify `--tol 0` against `baseline_e287b3d`.
- **Handle-off parity (`CaseEval.use_cc_reps_handle = false` vs `true`):**
  - `seed_900_7` (183 records) and `seed_692_10` (251 records) **identical at `--tol 0`**.
- **Test suites (0 failures across all):**
  - `tools/test_connections_cache.gd`: **56 checks, 0 failures** (including new tests for `RoleConstraints` `SOFT_EVENTS` + `chronology` key/parity, `use_cc_reps_handle` parity, and `Connections.drop_card_posterior` parity across 27 card drops with `cache_verify = true`, max diff `0.000000000000`, `wrong = 0`).
  - `tools/test_workshop_cases.gd`: **53 checks, 0 failures**.
  - `tools/test_workshop_reading_challenges.gd`: **63 checks, 0 failures**.
  - `tools/test_warden_quiet_route.gd`: **29 checks, 0 failures**.
  - `tools/test_poison_outing.gd`: **17 checks, 0 failures**.
  - `tools/test_nightwatch_whole_list.gd`: **6 checks, 0 failures**.
  - `tools/test_roles_official.gd`: **101 checks, 0 failures**.

## Measured Speed (Windows `Debug` C# build)

- **5-seed golden capture (passive, `Connections` off; `origin/main` `29a0fba2` vs branch):**
  - `seed 900 (7)`: `6,672 ms → 6,156 ms` (`-7.7%`)
  - `seed 42 (7)`: `4,503 ms → 4,143 ms` (`-8.0%`)
  - `seed 54875 (10)`: `56,078 ms → 46,073 ms` (`-17.8%`)
  - `seed 692 (10)`: `40,220 ms → 28,974 ms` (`-28.0%`)
  - `seed 98933 (10)`: `48,838 ms → 35,705 ms` (`-26.9%`)
  - **Total:** `156.3 s → 121.1 s` (**`-22.6%`** overall, **`-23.9%`** across 10-NPC seeds).
- **`16010` command replay (`Connections` on, `3aef7380` vs branch):**
  - Total command wall time: `14,579 ms → 9,849 ms` (**`-32.4%`**).
  - Key steps: `seq 93` (`1,053 → 691 ms`), `seq 271` (`1,742 → 1,245 ms`), `seq 564` (`3,732 → 2,259 ms`), `seq 615` (`1,022 → 670 ms`, no mid-turn `_fits_cache` clear), `seq 616` (`2,017 → 1,377 ms`), `seq 852` (`1,525 → 1,033 ms`), `seq 879` (`1,004 → 675 ms`), `seq 897` (`world_domain` `206.0 → 77.8 ms`, `LiveActivity.routes` `61 → 16`, `RoleConstraints.fits_weights` `74 → 0`, nested `connections/items` `63.9 → 13.7 ms`).
