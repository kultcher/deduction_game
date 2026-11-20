# Burdens Rework: Performance Feasibility (Argon)

**Author:** Argon  
**Date:** 2026-11-20  
**Base:** `origin/main` `1e45f93d` (includes `docs/design/burdens.md` at `eec8716b` and the Tier 2 `case_eval` / `live_activity` splits)  
**Scope:** Read-only performance feasibility for [docs/design/burdens.md](burdens.md).  
**Overlap with Lantern:** Lantern owns the judge's probability semantics (how unenumerated `Marked` enters `marked_registers` roles, the exact general-allowance formula, and how `Ill-Omened` combines with Poisoner/Delusional doubt). This note covers only the resulting world counts, hot paths, cache-key / `Connections.cache_verify` risks, and prototype measurements.

---

## 1. World Count (`WorldDomainKernel.EnumerateWorlds`)

Today (`workshop/cs/WorldDomain.cs`), every evil team enumerates 4 modifiers (`delusional`, `marked`, `sleepwalker`, `lovers`). Under `burdens.md`, a script lists up to 4 possible burdens with **at most 1 hidden** and `N` in play (without saying whether the hidden one is among the `N`). Only the hidden burden is enumerated: per evil team, each of the `g` good NPCs can hold the hidden burden, **plus 1 "no hidden burden in play" world** (`holders = 0`, representing that the in-play burden(s) are known ones).

| Configuration | Evil teams | Placements / team | Base worlds | With Demon identity (`identities = true`) | vs. today (10 NPCs) |
|---|---:|---:|---:|---:|---:|
| **Today — 10 NPCs** (3 evil, 7 good, 4 mods incl. Lovers) | 120 | 42 (`3×7 + 21`) | 5,040 | **15,120** | 1.00× |
| **Burdens — 10 NPCs** (1 hidden on script, `N >= 1`) | 120 | 8 (`7 + 1`) | 960 | **2,880** | **0.19× (5.25× fewer)** |
| **Burdens — 10 NPCs** (0 hidden on script) | 120 | 1 | 120 | **360** | **0.024× (42× fewer)** |
| **Today — 7 NPCs** (2 evil, 5 good, 4 mods incl. Lovers) | 21 | 25 (`3×5 + 10`) | 525 | **1,050** | — |
| **Burdens — 7 NPCs** (1 hidden on script, `N >= 1`) | 21 | 6 (`5 + 1`) | 126 | **252** | 4.17× fewer than 7-NPC today |
| **Scaling check — 12 NPCs** (3 evil, 9 good, 1 hidden) | 220 | 10 (`9 + 1`) | 2,200 | **6,600** | 0.44× of 10-NPC today |
| **Scaling check — 15 NPCs** (4 evil, 11 good, 1 hidden) | 1,365 | 12 (`11 + 1`) | 16,380 | **65,520** | 4.33× of 10-NPC today |

**Key points:**
- **Worst case on 10 NPCs:** **960 base / 2,880 with Demon identity** (or up to ~`2,880 × (1 + k)` during an active Revenant curse with `k` good yes-voters, vs. `15,120 × (1 + k)` today).
- **Listing up to 4 possible burdens with `N` in play adds zero worlds** as long as at most 1 is hidden. Even a future Baron adding extra *known* burdens (`N = 2` or `3`) keeps the exact same `g + 1 = 8` placements per team.
- **Implementation note:** `WorldDomainKernel.EnumerateWorlds` currently has no `holders = 0` ("none") placement; adding one `holders = 0, marked = -1` entry per team (and a `"none"` code in `WorldEntry.ParseModifierCode` / `ComputeKey`) is a small, localized change.
- **Larger-town headroom:** 12 NPCs (6,600 identity worlds) fits well inside today's 10-NPC budget; 15 NPCs (65,520) does not without further compression.

---

## 2. Hot Paths Touched

1. **`workshop/cs/WorldDomain.cs` (`EnumerateWorlds`, `ComputeKey`) & `workshop/world_domain.gd`**
   - Drops the `lovers` pair loop and non-hidden modifiers; adds the `holders = 0` placement when a hidden burden is on the script.
2. **`workshop/case_eval_classes.gd` (`compile`, `_compile_classes_cs`) & `workshop/cs/CaseEvalKernel.cs`**
   - Equivalence-class compilation (`nc`) shrinks directly because `marked` and `lovers` no longer split classes.
   - Removes the `Solver.lovers_needs` / `lovers_ok` world-filtering loop.
3. **`workshop/case_eval_content.gd` (`_healthy_modifier_worlds_per_team`, `_chance_rumormonger`, `_chance_chronicler`, `reading_error`) & `workshop/case_eval.gd`**
   - `q` (chance content) for Rumormonger/Chronicler updates for the `g + 1` modifier space.
   - `Ill-Omened` (when claimed & hanged) adds an O(1) per-report error lookup on that single night (in `reading_error` / `SourceDoubt`).
   - Unenumerated `Marked` shifts `marked_registers` checks in `workshop/role_constraints.gd` / `RoleConstraints.cs` from `world.marked` to claim + allowance (semantics owned by Lantern).
4. **`workshop/live_activity_pack.gd` (`_pack_activity_cards`), `workshop/live_activity_factors.gd` (`_factors_core`, `_sighting_contests`, `_list_mix`), `workshop/live_activity_profiles.gd` (`good_walk_chance`), & `workshop/cs/LiveActivity.cs`**
   - `_pack_activity_cards` already packs `secret_claim` cards; it only needs to distinguish walking burdens (`unrequited`, later `carouser`) from non-walking burdens (`marked`, `ill_omened`) so claiming `Marked` or `Ill-Omened` doesn't grant a night-walk rate.
   - The general allowance (~10%, scaled by burden claims and Rumormonger/Chronicler reads) is an O(1) rate scalar inside `LiveActivity.cs` — no extra world loops.
   - On deck: `Sleepwalker 2.0` (multi-block hidden walker) will touch `_paths` / `LiveActivity.cs` route generation for the hidden-walker profile (similar shape to Lamplighter, bounded by block count).
5. **`workshop/connections.gd` (`_judgement_key`, unit `ctx`, `cache_verify`) & `workshop/shared_ledger.gd` (`brought_by_premise`)**
   - `connections.gd` already puts `secret_claim` in `CONTEXT_KINDS`, but currently only attaches `secret_claim` to `night:` units (`L542`). See cache hazards below.

---

## 3. Cost & Caching (`Connections.cache_verify`) Concerns

### Rough cost per refresh and per presentation
- **World-scaled stages** (`WorldDomain`, `Solver.report_table`, `RoleConstraints.fits_table`, `CaseEvalCompile`, `CaseEvalEvaluatePosterior`): drop sharply with the 5.25× world reduction and smaller `nc`.
- **Non-world-scaled stages** (`LiveActivity` factor compilation, `SourceDoubt.derive`, GDScript packing, `Connections` unit orchestration): unchanged in structure, and on Day 3+ they represent a large fraction of total refresh time.
- **Expected net effect on 10 NPCs:** roughly **20–40% faster** per belief refresh and per presentation (larger wins on reading-heavy / `RoleConstraints` cases; smaller wins on Night-Watch / movement-heavy refreshes). The new Burdens logic itself adds negligible CPU (<2–3%) as long as known burdens stay out of `WorldDomain`.
- **One cost cliff to watch:** if the tentative per-case either/or (arguing an unclaimed known burden, `burdens.md` §4.9) is built later, it roughly doubles `CaseEval` cost for *that one presented case* (not town-wide refreshes).

### `Connections.cache_verify` & cache-invalidation hazards
Three specific cache traps must be wired into keys up front, or `Connections.cache_verify` will flag stale hits (the same class of bug as `#273`'s `list_broken_chance`):

1. **Dynamic general allowance vs. unit-local cache keys (biggest risk):** `burdens.md` §7 scales the ~10% general allowance by *other* burden claims and Rumormonger/Chronicler readings the listener holds. Today, `Connections` night units only include `claim`/`secret_claim` cards for people *in that unit* (`connections.gd:542`). If a third party's burden claim changes the general allowance for everyone, the effective allowance (or a compact burden-context summary: claimed-burden count + Rumormonger/Chronicler signal) **must** be included in both `LiveActivity`'s cache key and `Connections`'s judgement key.
   - *Thrashing guard:* quantize or key the allowance on discrete counts/buckets rather than raw continuous trust floats, so `LiveActivity` and `CaseEval` caches don't miss on every minor trust shift.
2. **Known `Marked` claims on non-night reading units:** Once `Marked` leaves `world.marked`, any unit containing a `marked_registers` report (`seer`, `confessor`, `monitor`, `registrar`, `augur`, `dowser`) depends on whether the target has a `Marked` `secret_claim`. Those units must pull the target's `secret_claim` into unit `ctx` and the judgement cache key (today `secret_claim` is only attached to `night:` units).
3. **`Ill-Omened` hanging night:** Hanging a claimed `Ill-Omened` changes `reading_error` for all good reports on that night. The affected night (or resulting per-card `reading_error`) must be in `CaseEval`'s and `Connections`'s cache keys so pre-hanging judgements aren't reused.

---

## 4. What to Measure on the `mock/` Prototype

Before moving past the prototype, run paired measurements against `main` on the 5 golden seeds plus a Day-3+ heavy replay (10 NPCs, `Connections` on):

1. **Stage-level timing (`SolverBackend.profiling_enabled` + `WorkshopLedgerProfiler`):**
   - Total `belief_refresh` time, night-to-dawn wall time, and worst-case single presentation latency (check against the 2-second UI budget).
   - Split between world-scaled stages (`WorldDomain` + `CaseEval` + `RoleConstraints`) vs. `LiveActivity` (`_factors` / `_pack`) vs. `Connections` overhead.
   - Equivalence-class count `nc` (median and max per presentation, main vs. prototype).
2. **Cache correctness & hit rates:**
   - Run `Connections.cache_verify = true` across all 5 golden seeds to Day 4 (plus `test_connections_cache`) with **zero new mismatches**, specifically covering: (a) a mid-game third-party burden claim changing the general allowance, (b) a `Marked` claim arriving after a `marked_registers` reading, and (c) an `Ill-Omened` hanging.
   - Compare `_compiled` (`CaseEval`) and `LiveActivity` factor cache hit rates against `main` to confirm the dynamic allowance isn't thrashing caches.
3. **12-NPC headroom check (optional, if targeting larger towns next):**
   - Time a 12-NPC (3 evil, 9 good, 1 hidden burden → 6,600 identity worlds) Day 1–4 run to confirm worst-case presentation latency stays under the 2-second budget.
