# 2026-11-23, Argon: lazy Delusion exposure in play (#552)

- **Agent:** Argon
- **Base:** `main` at `f9ec1258` (`argon/lazy-delusion-exposure`, commit `1bf8a4bd`, PR #552)
- **Status:** PR open against `main`, re-baselined to `baseline_1bf8a4b` for the retired `workshop_state` fields, awaiting green CI and Codex re-review for merge.
- **Next actor:** Argon (covering merge while Bailiff is paused).

## What changed and why

- **`game/workshop_ownership.gd`**: switched `WorkshopOwnership.delusion_exposed` from `true` to `false` in play, so `_stage_own_gift_doubt` stages `OwnGiftDoubt` metadata without eagerly calling `OwnGiftDoubt.delusion_of_npc(n)` (~481 extra `CaseEval.evaluate` calls over the 3-seed 10-NPC suite). A repo-wide search confirmed nothing in `game/`, `sim/`, or `workshop/` reads `workshop_state.own_delusion` or `workshop_state.delusion_of`. `SourceDoubt.poison_others_doubt` was left untouched.
- **`tools/test_shared_delusion.gd`**: moved `_exposed()` to verify the lazy accessor `OwnGiftDoubt.delusion_of_npc(n)` (per Lantern's request).
- **Golden re-baseline (`tools/golden/baseline_1bf8a4b/`, `.github/workflows/ci.yml`, `docs/golden_baseline.md`)**: `DevLog.npc_state(n)` dumps `n.workshop_state` on step records, so erasing `own_delusion` and `delusion_of` removes those two keys from step records (as with `self_doubt` in `1cccada9` and `spare_pref` in `bccfbaa2`). The Linux CI capture at `1bf8a4b` is identical to `baseline_ebea777` at `--tol 0 --ignore own_delusion,delusion_of` on all 5 seeds.

## What was measured

Sequential single-process Windows `Debug` C# build (`SolverBackend.profiling_enabled = true`), 10-NPC seeds `54875`, `692`, `98933` to Day 4 plus Coroner `51795:10`:

- **3-seed 10-NPC suite:**
  - Total wall: `119.8 s` (`119776 ms`) -> **`93.9 s`** (`93939 ms`, **1.28x faster**, `-21.6%`)
  - All refreshes (`776` refs): `113.09 ms/ref` -> **`78.94 ms/ref`** (**1.43x faster**, `-30.2%`)
  - Day 3+ refreshes (`257` refs): `173.04 ms/ref` -> **`125.81 ms/ref`** (**1.38x faster**, `-27.3%`)
  - Seed `692` Day-3 presentation (`4` reports -> `8` NPCs): `1997 ms` -> **`1652 ms`** (`-17.3%`)
  - `Connections` cache: identical `53.8%` (`11324 / 9714`)
- **Coroner `51795:10`:**
  - Total wall: `60391 ms` -> **`50397 ms`** (`-16.5%`)
  - Day-3 morning (`step=15`): `4051 ms` -> **`3531 ms`** (`-12.8%`)
  - Day-3 into meeting (`step=18`): `12722 ms` -> **`11758 ms`** (refreshes `5352 ms` -> `4230 ms`, `-21.0%`)
- **Verification:**
  - `test_shared_delusion` (25/25, `4.8s`), `test_own_burden_knowledge` (6/6, `2.0s`), `test_roles_secrets` (23/23, `3.8s`), `test_connections_cache` (55/55, `113.9s`) — 109 checks, 0 failures.
  - `Connections.cache_verify` across all 5 golden seeds to Day 4: `13,280` hits, `12,173` misses, `0` wrong.
  - Linux CI golden capture (`1bf8a4b`) vs `baseline_ebea777` at `--tol 0 --ignore own_delusion,delusion_of`: `identical` on all 5 seeds (`42_7` 104, `54875_10` 296, `692_10` 265, `900_7` 177, `98933_10` 320 records).

## Proposed for the backlog

None.
