# 2026-11-21, Argon: Burdens stage 1 performance review & zero-drift fixes (`argon/burdens-stage1-perf`)

- **Measured commit:** `mock/burdens-slot` at **`e1911919`** (compared single-process against its `main` merge-base **`70223caa`**).
- **Coordination:** Based strictly on `e1911919`. Only `workshop/role_constraints.gd` and `workshop/case_eval_classes.gd` are edited (no C# changes, no `connections.gd` changes). Stage 2 (`Unrequited` / `Ill-Omened`) can merge cleanly over these two files.
- **Reviewers:** Bailiff and Claude-Lantern.

---

## 1. #468 §4 Prototype Measurements (`e1911919` vs. `main` `70223caa`)

All timings were collected **single-process** (Windows `Debug` C# build, `Connections` on, no concurrent runs).

### A. 5 Golden Seeds (`900:7, 42:7, 54875:10, 692:10, 98933:10` to Day 4)

| Metric | `main` (`70223caa`) | `e1911919` | `argon/burdens-stage1-perf` | `e1911919` vs. `main` |
|---|---:|---:|---:|---:|
| Total wall | 175,713 ms | **104,133 ms** | 105,949 ms | **-40.7% (1.69× faster)** |
| Total refreshes | 1,006 | 1,116 | 1,116 | +10.9% |
| ms / belief refresh | 174.67 ms | **93.31 ms** | 94.94 ms | **-46.6% (1.87× faster)** |
| `nc` (avg / med / p95 / max) | 1,389.5 / 756 / 4,392 / 10,752 | **1,111.5 / 612 / 3,696 / 5,637** | 1,111.5 / 612 / 3,696 / 5,637 | **-20.0% avg, -47.6% max** |
| `Connections` cache hit rate | 55.0% (`15,057 / 27,388`) | **56.4%** (`17,245 / 30,580`) | **56.4%** (`17,245 / 30,580`) | +1.4 pp |
| `Connections.cache_verify` wrong | 0 | **0** (17,245 checked) | **0** (17,245 checked) | Clean |

Stage breakdown on 5 golden seeds (`Self ms`, `us/Call`):
- `case_eval_compile`: `19,100 ms` (`1,446 µs/call`) → **`8,352 ms`** (`588 µs/call`, **-59.3% / call**)
- `channel_sum_product` (`CaseEval.evaluate`): `50,165 ms` (`3,842 µs/call`) → **`27,445 ms`** (`1,952 µs/call`, **-49.2% / call**)
- `world_domain` (`WorldDomain` + `RoleConstraints`): `31,793 ms` (`391 µs/call`) → **`17,113 ms`** (`262 µs/call`, **-33.0% / call**)
- `live_activity`: `25,238 ms` (`620 µs/call`) → **`15,245 ms`** (`516 µs/call`, **-16.7% / call**)
- `reason_attribution`: `15,392 ms` (`88.5 ms/call`) → **`8,787 ms`** (`58.2 ms/call`, **-34.2% / call**)
- `outer_prep`: `14,951 ms` → `13,812 ms` (-7.6%)
- `pack_inputs`: `11,822 ms` (`450,691` calls) → `7,150 ms` (`126,080` calls; `WorldDomain.key` dropped `317,520 -> 23,520`)

### B. Full 10-NPC Passive Games (`8000–8004` to Game Over, Lantern's 8000–8039 range)

| Metric | `main` (`70223caa`) | `e1911919` | `argon/burdens-stage1-perf` | Post-fix vs. `main` |
|---|---:|---:|---:|---:|
| Total wall (5 games) | 290,052 ms (58.0 s/game) | 252,825 ms (50.6 s/game) | **246,177 ms (49.2 s/game)** | **-15.1%** |
| Total days played (5 games) | 21 days (4.2 avg) | 26 days (5.2 avg) | 26 days (5.2 avg) | +23.8% longer games |
| Total refreshes | 1,570 | 1,528 | 1,528 | -2.7% |
| ms / belief refresh | 184.75 ms | 165.46 ms | **161.11 ms** | **-12.8%** |
| `nc` (avg / med / p95 / max) | 1,484.3 / 696 / 3,636 / 5,484 | 1,667.1 / 807 / 4,431 / 7,056 | 1,667.1 / 807 / 4,431 / 7,056 | +12.3% avg (late-game & curse) |
| `Connections` cache hit rate | 60.4% (`33,614 / 55,620`) | 57.4% (`30,834 / 53,705`) | 57.4% (`30,834 / 53,705`) | -3.0 pp |

---

## 2. Where the Time Goes (Why Lantern Saw 121s vs. 102s)

**Headline:** `e1911919` is **not** slower than `main` per refresh — in clean single-process runs it is **46.6% faster per refresh** on the 5 golden seeds and **10.4–12.8% faster per refresh** on full 10-NPC games `8000–8004`. The 121s vs. 102s in Lantern's 4-way contended run came primarily from **game-length variance and contention**, plus three secondary judge-side drags (ranked):

1. **Longer games after retiring Lovers (#1 driver of total game wall time):** On `8000–8004`, `main` averaged 4.2 days/game (three games ended on Day 3), while `e1911919` averaged **5.2 days/game (+24%)**. Day 5–6 refreshes carry far more cards, larger `nc` (especially with a Revenant curse, e.g., `8000` hitting `nc=7,056`), and lower `Connections` cache hit rate (`60.4% -> 57.4%`).
2. **`RoleConstraints.burden_claim_factors` + `names_evil` overhead (#1 judge-side addition):**
   - Called on every `_class_fits` lookup (including cache hits and cards with zero burden claims, allocating `ids_of(view)` every time) and recomputed a second time inside `_bluff_weights_cs` on cache misses (`bluff_weights` pack time rose `12.1 -> 17.9 µs`, `bluff_weights_temporal` `33.8 -> 47.0 µs`).
   - Allocated `held + cards` twice per burden card, ran `_reading_known_tick` on non-report cards, and checked `_names_evil_cache.size() > 4096` inside the per-world loop.
3. **Cache cap flushes on longer games & relayed-Seer boundary churn (pre-existing, amplified by longer games):**
   - `RoleConstraints.cache` (`2048`) and `CaseEvalClasses._fits_cache` (`4096`) cleared mid-game on `54875`, `98933`, `8002`, and `8004`.
   - `CaseEvalClasses._fits_over` called `RoleConstraints._seer_rh_weight` **1,171,158 times** across the GDScript/C# boundary on `8000–8004` (one call per class for relayed Seer readings).
4. **Coarse-memo keys (`CoarseMask` ×5), `BluffWeightsFactors`, and retirements:**
   - **Retirements (Lovers & Sleepwalker 1.0):** Confirmed pure work removal (`case_eval_compile` -59%/call, `WorldDomain.key` calls -92% on golden seeds).
   - **`CoarseMask` ×5 term:** Zero practical hit-rate regression on Stage 1 (with only `Delusional` and `Marked`, non-Marked `mod` is always `Delusional`, and `rmBound` stays well within `intKeys` up to `k=16`).
   - **`BluffWeightsFactors` C# kernel:** Fast and clean; only the GDScript `burden_claim_factors` caller around it was adding overhead.

---

## 3. Zero-Drift Fixes on `argon/burdens-stage1-perf`

1. **`workshop/role_constraints.gd`:**
   - Early-exit `burden_claim_factors` before `ids_of(view)` / allocations when `cards` has no `secret_claim` burden.
   - Avoid `held + cards` array allocations; filter `kind == "report"` & `!quoted` & `source != claimant` before `_reading_known_tick` / `names_evil`.
   - In `names_evil`: cache the `Solver` script reference, avoid `ids_of(view)`, hoist cache-size cap check out of the per-world loop, and use a compact string key. Use a compact key in `_deal_share`.
   - Accept optional `precomputed_burdens` in `bluff_weights` so `_class_fits` doesn't compute `burden_claim_factors` twice.
   - Raise `RoleConstraints.cache` cap `2048 -> 8192`.
2. **`workshop/case_eval_classes.gd`:**
   - Pass precomputed `burden_factors` from `_class_fits` to `bluff_weights` and `_personal_fits`.
   - Raise `_fits_cache` cap `4096 -> 12288`.
   - In `_fits_over`: precompute `relayed_seers` pair bitmasks once per call and memoize `_seer_rh_weight` by `(candidates_mask, demon, marked, rel_bits)` (cuts `_seer_rh_weight` boundary calls on `8000–8004` by **338,550 / -28.9%**, saving **6.65 s** on `8000–8004`, and bringing `bluff_weights` pack time back down **-30%** to `12.5 µs` / `11.1 µs`).

**Verification:**
- Golden diff vs. `e1911919` at **`--tol 0`**: **100% identical** across all 5 seeds (`42_7`: 137, `54875_10`: 384, `692_10`: 277, `900_7`: 139, `98933_10`: 350 records).
- `test_connections_cache.gd`: **55/55 checks pass**.
- `Connections.cache_verify = true` over all 5 golden seeds to Day 4: **0 mismatches** across 17,245 hits.

**Latent cache-key note for Lantern (not changed here, to keep zero drift):** `Connections.judge_key` / `_judge_key_fast` does not yet include `burden_claim_factors(view, cards)`. Because `burden_claim_factors` reads `view.cards` (which `around.erase("cards")` strips from `judge_key`), if a listener hears a `Marked` claim *unprompted* (`_deal_share = 0.0714`) and later hears a reading naming the claimant evil with `_reading_known_tick <= first` (flipping it to *reactive* `0.0748`), `judge_key` could reuse the unprompted judgement. Worth adding to `_mix_key` in Stage 2 (or whenever `BURDEN_BLUFF_REACTIVE` diverges further from `_deal_share`).

---

## 4. Verdict: Model A vs. Model C

**Model A holds up cleanly on speed — Model C is NOT needed.**
- Model A is already **46.6% faster per refresh** on the 5 golden seeds (`93–95 ms` vs. `175 ms`) and **12.8% faster per refresh** (`15.1%` faster total wall even with +24% longer games) on full 10-NPC games `8000–8004`.
- Stage 2 (`Unrequited` + `Ill-Omened`) only adds 2 placements per team (`14 -> 16`, `+14%` worlds vs. Stage 1, still `2.625×` fewer than `main`). Keep Model A.
