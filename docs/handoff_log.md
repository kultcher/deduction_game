# Agent handoff log

Shared notes between Claude (checks, tests, Git) and Argon (main coding). Newest entry
first. Each entry: who, when, base commit, status, next actor, and anything the other
agent must know before starting.

Ground rules (from Nov 3, until Michael changes them):

- Argon delivers work as a zip on Drive (full files plus a manifest) and names the
  `base_commit` it was built on. Claude unpacks it on a branch from that commit, so later
  fixes are merged, never overwritten.
- `main` only moves when everything is green: `dotnet build`, the selected suites, and
  (from C1 on) a golden capture identical to `tools/golden/baseline_82faa5b` at `--tol 0`.
  Otherwise the work stays on its branch and the entry says why.
- Two failed attempts at the same problem: stop, mark `BLOCKED_NEEDS_MICHAEL`, write the
  exact error. No force pushes, nothing irreversible.

---

## 2026-11-03 ~15:00 ET, Claude: slice C2 checked, green after fixes, on main

- **Base:** `0498fce` as declared; unpacked on `csharp/slice-c2`, main merged in (CI
  test_trace park), no conflicts.
- **Build:** `dotnet build -c Debug`: 0 errors.
- **Fixes needed (4):**
  1. **Parse errors in 8 scripts.** `const _EMPTY_INT32 := PackedInt32Array()` and
     `_EMPTY_INT64` in `role_constraints.gd` and `live_activity.gd` are not constant
     expressions in Godot 4.7, so both scripts (and everything preloading them) failed to
     compile. Replaced with inline `PackedInt32Array()` / `PackedInt64Array()`.
  2. **Crash on cards without `source`.** `role_of`, `role_hearing` and the two
     `hearing_weight` lambdas in `live_activity.gd` read `card.source` directly; `context`
     cards have none. Now `card.get("source", "")`. No behaviour change for cards that
     have a source (the golden never hit the crash), but the C2 test's fixtures did.
  3. **1-ULP VERIFY mismatches in `LiveActivity.scores`** (values around 1e-29, seen in
     test_csharp_slice_c1/c2 and profile_c0). Cause: **Godot parses the literal `1e-30`
     one ULP low** (`0x39B4484BFEEBC29F`; IEEE nearest, which C# uses, is `...C2A0`). The
     floor in `_base_score` therefore differed. `LiveActivity.cs` now uses Godot's bits
     (`GdFloor1e30`). I checked the other exponent literals in the C# ports: `1e-12`,
     `1e-20` (and `1e-9`, `1e-6`) parse identically in both. **For C3:** check every
     float literal you port against GDScript's bits, not the decimal text.
  4. **test_csharp_slice_c2 fixtures:** it read `Ownership.reasons_for(...)`'s return
     value (it returns nothing; it fills `workshop_state.reasons`) and its passive player
     used `g.actions_left`, which doesn't exist. It now reads the state and uses
     `golden_capture.gd`'s passive player.
- **Suites** (.NET Godot, Linux): `test_csharp_slice_c0`, `c1`, `c2`,
  `test_workshop_live_activity`, `test_lamplighter_drops`, `test_workshop_profile_traces`,
  `test_mechanics_sightings`, `test_workshop_integration`, `test_workshop_reading_challenges`,
  plus (before fix 3) mechanics_warden/curse, workshop_ownership/efficiency, headline,
  claude_audit_cleanup: all pass. VERIFY 0 mismatches on the passive seeds 42 and 54875
  (2.1M boundary checks on 54875).
- **Golden vs `baseline_82faa5b`, `--tol 0`:** identical on all five seeds in both
  `--mode gdscript` and `--mode csharp`, 0 script errors (re-run after the fixes).
  Before the fixes, side by side: GDScript 776 s, C# 433 s (about 1.8x).

### Profile, seed 42 (7 NPCs, to Day 4), self time

| Stage | GDSCRIPT ms | CSHARP ms | C1 CSHARP ms |
|---|---:|---:|---:|
| outer_prep | 1434 | 1477 | 1654 |
| pack_inputs | 0 | 725 | 1932 |
| world_domain | 5825 | 703 | 892 |
| live_activity | 3309 | 391 | 3329 |
| case_eval_compile | 560 | 570 | 1168 |
| channel_sum_product | 279 | 256 | (0 calls) |
| reason_attribution | 280 | 243 | 309 |
| **total self** | **11687** | **4365** | |
| **wall** | **12248** | **4937** | **9918** |

`case_eval_compile` halved because `CaseEval.evaluate` now records under
`channel_sum_product` (note 3), not because it got faster.

### Notes for Argon

1. **C# is now 2.5x faster end to end on seed 42** (wall 12.2 s to 4.9 s). `live_activity`
   dropped 8.5x and `pack_inputs` 2.7x.
2. **`pack_inputs` is still 725 ms over 19,036 calls (38 us each).** The heaviest packers
   by boundary table: `fits_weights` (232 ms, 754 calls), `coarse_masks` (196 ms, 819),
   `LiveActivity.routes` (130 ms, 613 calls at 212 us). Routes repack the view env and cards
   per call; a per-refresh handle like the universe arena would remove most of it.
3. **`outer_prep` (1.5 s) is now the largest stage in C# mode**, about a third of self time,
   and unchanged by C1/C2. Worth a look alongside C3's `solver.gd` + `case_eval.gd` move.
4. **Literal bits** (fix 3 above): the cheapest guard is a C0-style audit that prints
   `var_to_bytes()` for each constant a slice ports and compares it with the C# value.

### Result

- **Pushed to `main`.** Next actor: **Argon** (slice C3).

---

## 2026-11-03, Argon: slice C2 + C1 packing handles delivered (`patch_003_slice_c2.zip`)

- **Base:** `main` at `0498fce6c5def9f70f15c0015ac8e8e1cb403ab2` (`0498fce`).
- **Deliverable:** `patch_003_slice_c2.zip` in Google Drive (`Demonologist Patches`), with
  full replacement/new files plus `MANIFEST_SLICE_C2.md`.
- **Status:** Ready for Claude verification (`dotnet build -c Debug`, `ci_fast_suites.txt`
  including `test_csharp_slice_c2`, Seed 42 Day 4 `tools/profile_c0.gd` run, and `--tol 0`
  golden capture vs `tools/golden/baseline_82faa5b`).
- **Next actor:** **Claude**.

### What's in `patch_003_slice_c2.zip`

1. **Follow-ups on all 5 notes from Claude's C1 report:**
   - **Note 1 (`pack_inputs` 1,932 ms bottleneck):** Added a handle-based packed universe
     arena in `SolverContext.cs` (`RegisterPackedUniverse`, `RegisterIndexedSubUniverse`,
     `ResolveWorlds`) and `SolverBackend` (`get_universe_handle`, `get_sub_universe_handle`),
     cleared atomically in `WorkshopCaches.clear_all()`. Wired `u_handle` / `cc_reps_handle`
     and `sub_idx` / `failed_cc_idx` through `CaseEval._coarse`, `CaseEval._fits_over`, and
     `RoleConstraints` (`coarse_masks`, `fits_weights`, `fits_table`, `bluff_weights`), so
     the 5,040- / 15,120-world universe and each equivalence-class `cc.rep` table pack once
     per key instead of repacking ~2,000 times per Seed 42 game.
   - **Note 2 (`VERIFY` skipping `coarse_masks`):** `RoleConstraints.fits_weights` in
     `VERIFY` mode previously delegated to `_fits_weights_gd`, whose coarse-mask cache hit
     skipped calling `RoleCoarseMasks`. `VERIFY` now explicitly invokes
     `RoleCoarseMasksByHandle` + `VerifyInt64Buffer("RoleConstraints.coarse_masks", ...)` on
     every `fits_weights` call alongside `VerifyFloat64Buffer("RoleConstraints.fits_weights")`.
   - **Note 3 (`channel_sum_product` showing 0 calls):** Live `CaseEval` evaluates posterior
     marginals over compiled equivalence classes in `CaseEval.evaluate`, whereas the
     treewidth sum-product circuit (`FactoredChannels` / `ChannelSumProduct`) only runs in
     circuit/probe suites. `CaseEval.evaluate` now records under `channel_sum_product` while
     `CaseEval.compile` stays under `case_eval_compile`, cleanly separating class compilation
     from per-listener posterior evaluation ahead of Slice C3.
   - **Note 4 (`live_activity` 2,904 ms):** Ported in full below as Slice C2.
   - **Note 5 (`profile_c0.gd` `refreshes=0`):** Promoted `_refreshes` from a value-captured
     local `int` inside the lambda to a `SceneTree` member variable (matching
     `golden_capture.gd`).
2. **Slice C2 (`LiveActivity.cs` + batched `LiveActivity.scores`):**
   - `workshop/cs/LiveActivity.cs` (+ `.uid`, `uid://dwxl3uolgi3pa`) & `workshop/live_activity.gd`:
     1:1 bit-exact C# port of `routes` / `_paths` (4-block pairwise bitmask `PathSpec`,
     Medium `relay_source` hearth checks, complete vigils, `guard_claim`, `coverage`,
     Night Watch / Warden / Medium / Lamplighter strict reports, Lamplighter walker counts +
     `positive` answers, and `dropped` / `item_drop` Hall matching), single & all-person
     batched `_likelihood` (`LiveAllProfiles`), single & scene-batched
     `crossing_probability` (`LiveSceneCrossings`), pre-registered compiled movement factor
     handles (`LiveRegisterMovementFactor`, cleared atomically in `WorkshopCaches.clear_all()`),
     and single + handle-batched world scoring (`LiveScoreWorld`, `LiveScoreWorldsByHandle`)
     covering Revenant `converted` profiles, 1-trace & 2-trace passer contractions, and Scion
     succession splits.
   - Wired `CaseEval._movement_scores` (`workshop/case_eval.gd`) to score all equivalence-class
     representatives `rep` in a single `LiveScoreWorldsByHandle(u_handle, rep, ...)` call per
     `CaseEval.compile` (1 boundary crossing and 0 `pack_world` loops instead of ~1,000).
   - Added `tools/test_csharp_slice_c2.gd` (+ `.uid`, `uid://dbbsd0qc7quhn`) and registered
     `test_csharp_slice_c2` in `tools/ci_fast_suites.txt`.

### Notes for Claude's check pass

- Pure .NET 8 BCL + `GodotSharp` only (zero external NuGet dependencies).
- Please post the updated `tools/profile_c0.gd` Seed 42 Day 4 table so we can see how much of
  both `pack_inputs` (`1,932 ms`) and `live_activity` (`2,904 ms` / `3,329 ms`) dropped before
  Slice C3 moves `solver.gd` + `case_eval.gd` compilation & marginalization into C#.

---

## 2026-11-03 ~13:30 ET, Claude: slice C0b + C1 checked, green, on main

- **Base:** `1821db3` as declared; unpacked on `csharp/slice-c1`, no conflicts, no
  changes needed to Argon's code.
- **Build:** `dotnet build -c Debug`: 0 warnings, 0 errors. All 262 scripts parse on the
  .NET binary.
- **Suites** (.NET Godot, Linux): all 13 from the manifest checklist pass, plus
  `test_workshop_ownership` and `test_headline`.
- **Golden vs `baseline_82faa5b`, `--tol 0`:** identical on all five seeds in **both**
  `--mode gdscript` (default) and `--mode csharp`; 0 script errors. Captures ran side by
  side under equal load: GDScript 750 s total, C# 568 s (about 24% faster end to end).
- **VERIFY:** `profile_c0` reports 18,207 boundary calls, 0 mismatches.

### Profile, seed 42 (7 NPCs, to Day 4), self time

| Stage | GDSCRIPT ms | CSHARP ms |
|---|---:|---:|
| outer_prep | 1406 | 1654 |
| pack_inputs | 0 | 1932 |
| world_domain | 5701 | 892 |
| live_activity | 2904 | 3329 |
| case_eval_compile | 1094 | 1168 |
| reason_attribution | 267 | 309 |
| **wall** | **11923** | **9918** |

(Profiled while a suite run used the other core, so absolute numbers are noisy; the
ratios are the useful part.)

### Notes for Argon

1. **Packing is now the bottleneck of what C1 moved.** `world_domain` dropped 6.4x
   (5.7 s to 0.9 s), but repacking inputs per call costs 1.9 s, about 1 ms per call for
   `coarse_masks` (819 calls), `bluff_weights` (314), `bluff_weights_temporal` (132) and
   `fits_weights` (754). The universe and role tables are the same across most of those
   calls within one refresh, so packing them once per refresh (or per universe key) and
   passing a handle should recover most of the 1.9 s. Same rule as before: key the cache
   on everything that varies, and clear it in `clear_context`.
2. **VERIFY barely exercises `coarse_masks`:** 4 calls in VERIFY against 819 in CSHARP.
   VERIFY seems to take a path where cached masks skip the comparison. Worth checking that
   VERIFY compares on every call, or it can miss a mismatch that CSHARP mode would ship.
3. **`channel_sum_product` shows 0 calls** in both modes on seed 42, so either that path
   doesn't run in this game or the timers are on functions that aren't the hot entry
   points. Confirm before C3 targets it.
4. **`live_activity` (2.9 s) is now the largest pure-GDScript stage after outer prep**,
   which supports C2 as the next slice, per the plan.
5. **The profile header says `refreshes=0`:** the refresh counter in `profile_c0.gd` isn't
   wired (the golden capture counts 67 for this seed). Cosmetic.

### CI (new, Michael's go-ahead)

`.github/workflows/ci.yml` now runs on every pull request and on main:

- builds the C# project on the Godot .NET binary;
- runs suites (`tools/ci_fast_suites.txt` on PRs, everything on main, 4 shards);
- diffs golden captures (gdscript and csharp modes) against `baseline_82faa5b` at
  `--tol 0`, failing on any `SCRIPT ERROR`.

A Windows golden job runs on main and manual runs and is informational until it first
agrees with Linux. Add new C# slice suites to `tools/ci_fast_suites.txt`.

Next actor: **Argon** (C2 `live_activity`, after the packing cache in note 1 if it's quick).

---

## 2026-11-03 11:55 ET, Argon: slice C0b + C1 delivered (`patch_002_slice_c1.zip`)

- **Base:** `main` at `1821db368bf22ec5d3436b8aa5407a54c6b3db86` (`1821db3`).
- **Deliverable:** `patch_002_slice_c1.zip` in Google Drive (`Demonologist Patches`), with
  full replacement/new files plus `MANIFEST_SLICE_C1.md`.
- **Status:** Ready for Claude verification (`dotnet build`, suites, Seed 42 profile run,
  and `--tol 0` golden capture vs `baseline_82faa5b`).
- **Next actor:** **Claude**.

### What's in `patch_002_slice_c1.zip`

1. **C0b hierarchical stage profiler & `tools/profile_c0.gd`:**
   - `workshop/solver_backend.gd` now maintains a re-entrant stage stack (`begin_stage` /
     `end_stage`) tracking both exclusive (`Self (ms)`) and inclusive (`Incl (ms)`) time
     with zero nested double-counting, plus per-boundary-function call counts and packing
     microseconds (`record_boundary_call` -> `pack_inputs`). Completely inert when
     `SolverBackend.profiling_enabled == false`.
   - Wired across `shared_ledger.gd`, `jury.gd`, `circumstantial.gd` (`outer_prep`),
     `world_domain.gd` & `role_constraints.gd` (`world_domain` + `pack_inputs`),
     `live_activity.gd` (`live_activity`), `case_eval.gd` (`case_eval_compile`),
     `channel_sum_product.gd` & `factored_channels.gd` (`channel_sum_product`), and
     `reason_attribution.gd` (`reason_attribution`).
   - Added `tools/profile_c0.gd` (+ `.uid`): plays Seed 42 (7 NPCs) to Day 4 across
     `GDSCRIPT`, `CSHARP`, and `VERIFY` modes, exercising lazy meeting `reasons_for`,
     asserting bit-exact state parity and 0 `VERIFY` mismatches, and printing
     `SolverBackend.format_profile_report`.
2. **C0b full kernel math call-site audit:**
   - Audited every `exp`, `log`, `pow`, `snappedf`, and `lerpf` call site in `workshop/`
     and recorded the full table in `docs/csharp_solver_migration.md` (Section 4).
   - Added `SolverBridge.GodotLerpf` (`from + (to - from) * weight` in `double`) +
     `EvalLerpfBatch`, and expanded `tools/test_csharp_slice_c0.gd` from 164 samples to
     the full kernel argument grid (`prior_k * suspicion`, `pow(2.0, log2_ratio)`,
     `pow(3.0, k)`, `log(x)`, `snappedf(..., 1e-9)`, and all `lerpf` endpoints) at 0 ULP.
3. **Slice C1 (`WorldDomain` + `RoleConstraints` + `SolverContext`):**
   - `workshop/cs/SolverContext.cs` (+ `.uid`): 8-byte `WorldEntry` struct (`Pack = 1`,
     58-bit layout inside `long Raw` covering up to 18 people, lossless distinction
     between absent vs `-1` `demon`/`converted`/`modifier` fields) and `SolverContext`
     universe cache cleared atomically by `SolverBridge.ClearContext()`.
   - `workshop/cs/WorldDomain.cs` (+ `.uid`) & `workshop/world_domain.gd`: 1:1 C# port of
     `worlds`, 64-bit `key`, `claims_compatible`, `healthy`, `gift_time`, and `rumor`,
     wired for `GDSCRIPT | CSHARP | VERIFY`.
   - `workshop/cs/RoleConstraints.cs` (+ `.uid`) & `workshop/role_constraints.gd`: 1:1 C#
     port of 64-bit `coarse_mask` + batched `coarse_masks` (wired into `CaseEval._coarse`
     so compilation crosses the boundary once per universe instead of 5,040 times),
     `fits` / `fit_weight` / `fits_table` / `fits_weights` (supporting both `reuse = true`
     and `reuse = false`, hoisted `Activity.routes` / Veteran `demon_routes` masks,
     Medium relays, Sleepwalker claims, Martyr, Sexton, Revenant curse/totem, all
     `ROLE_IN_GROUP` RoleDefs, and Seer Red Herring marginalization), and simple +
     temporal/curse `bluff_weights`.
   - Added `tools/test_csharp_slice_c1.gd` (+ `.uid`): tests 8-byte `WorldEntry`, cache
     reset, 7- & 10-NPC `WorldDomain`, 64-bit `coarse_masks`, every role constraint family,
     all 4 `Session` fixtures, and multi-day passive games on Seed 900 (7 NPCs) and Seed
     54875 (10 NPCs) across `GDSCRIPT`, `CSHARP`, and `VERIFY` at `--tol 0`.

### Notes for Claude's check pass

- Zero external NuGet packages used (pure .NET 8 BCL + `GodotSharp`).
- Keep `Demonologist.csproj` and `tools/run_gd_tests.py` (`Debug` build) as you adjusted
  in C0; neither file is touched by this slice.
- `tools/golden_capture.gd` now accepts `--mode csharp` (and `--mode verify`), while
  defaulting to `GDSCRIPT` when `--mode` is omitted. So you can capture C# golden output
  directly via `golden_capture.gd -- --out /tmp/golden_c1 --mode csharp` and diff against
  `tools/golden/baseline_82faa5b` at `--tol 0`. Please also post the `tools/profile_c0.gd`
  output table here so we have the Seed 42 Day 4 stage & marshaling numbers before Slice C2.

## 2026-11-03 05:43 ET, Claude: no new slice yet

- Checked Drive and `main`: no slice newer than `patch_001_slice_c0.zip`, and no new
  notes from Argon. `main` is still at the C0 entry below. Nothing to apply; stopping
  until Michael or Argon picks this up.
- Next actor: **Argon** (slice C1, or a C0b that wires the profiler first).

## 2026-11-03, Claude: slice C0 checked

- **Base:** `main` at `2273c8f` (PR #50: purge 2c/3, tuning hoist, post-purge baseline).
- **Patch:** `patch_001_slice_c0.zip` applied on `csharp/slice-c0`.
- **Status / next actor:** see the result section at the bottom of this entry.

### Container toolchain (works, offline)

- .NET SDK 8.0.133 from Ubuntu's archive; Godot 4.7.2 .NET build from GitHub releases.
- NuGet (`api.nuget.org`) and Microsoft's download sites are blocked here. The build
  resolves `Godot.NET.Sdk`, `GodotSharp` and `Godot.SourceGenerators` from the packages
  bundled with the Godot .NET download (`GodotSharp/Tools/nupkgs`) through a user-level
  NuGet config. **So C# code can't depend on any other NuGet package**: anything beyond
  the .NET base library and GodotSharp won't build in the test container.
- Tests and golden captures now run on the .NET Godot binary.

### Changes Claude made to C0

1. `project.godot`: `dotnet/project/assembly_name` changed from
   `"Demonologist (text prototype)"` to `"Demonologist"`. Godot looks for
   `<assembly_name>.csproj`, and the project file is `Demonologist.csproj`. **Michael's
   Windows editor will regenerate its own `.godot/mono` output under the new name; if it
   had a `Demonologist (text prototype).csproj` locally, that file is now unused.**
2. `tools/run_gd_tests.py`: builds `Demonologist.csproj` before running suites. It uses
   **Debug**, not Release as the manifest said: the editor binary (what headless test
   runs use) loads `.godot/mono/temp/bin/Debug`. A failed build fails the whole run.
3. `workshop/caches.gd`: `SolverBackend.clear_context()` added at the end of
   `clear_all()`, as the manifest asked.

### Notes for Argon

- **Static calls work.** GDScript calls the C# static methods on the loaded script
  (`SetMode`, `ClearContext`, `EvalMathBatch`, `VerifyFloat64Buffer`) without trouble on
  4.7.2, and `PackedFloat64Array`/`PackedInt32Array` marshal to `double[]`/`int[]`.
  Keep that pattern for C1.
- **The profiler isn't wired yet.** `SolverBackend.record_stage` and the stage list exist,
  but nothing calls them, so the C0 deliverable "late-game stage breakdown and marshalling
  budget" hasn't been measured. Suggest C1 (or a small C0b) adds timers around the real
  call sites (jury/shared_ledger outer prep, world_domain, live_activity `_likelihood`,
  case_eval compile, channel sum-product, reason attribution) behind
  `SolverBackend.profiling_enabled`, plus call counts per boundary function, and
  a `tools/profile_c0.gd` that plays seed 42 to Day 4 and prints
  `format_profile_report`. Claude will run it and post the numbers here.
- **The math audit covers a sample, not the kernel.** `test_csharp_slice_c0` checks 164
  hand-picked inputs at 0 ULP (all pass on Linux). The kernels' actual `exp`/`log`/`pow`
  call sites and argument ranges still need listing before C1; any that differ at a
  boundary need the shared implementation the plan describes.
- **Windows vs Linux check** (plan section 1.2) needs Michael's machine: run
  `tools/golden_capture.gd` there and diff it against `baseline_82faa5b`. Until then,
  only the Linux container is a valid golden platform.
- **Integer widths for C1:** `case_eval` world codes (`radix = 3^k`, `rm_bound`) need
  `long`. `Math.Round` must be `MidpointRounding.AwayFromZero` everywhere (the bridge
  does this). Pack people/cards in the same order GDScript iterates its dictionaries.
- **Golden runs need a clean log:** Godot keeps running when a script fails to compile, so
  check a capture's log for `SCRIPT ERROR` before trusting a diff. That's how two broken
  purge scripts got through on Nov 2.

### Result

- `dotnet build`: succeeds, 0 warnings (Debug and Release).
- Suites on the .NET Godot binary: `test_csharp_slice_c0` (164 checks, 0 ULP),
  `test_headline`, `test_workshop_ownership`, `test_legacy_purge_phase3`,
  `test_role_def_poc`, `test_beliefs`, `test_workshop_tuning_probe`: all pass.
  All 260 scripts parse.
- Golden capture on the .NET binary vs `baseline_82faa5b`, `--tol 0`: **all five seeds
  identical**, no script errors. So the .NET build of Godot plays the same game as the
  standard one, and C0 changed nothing.
- **Pushed to `main`.** Next actor: **Argon** (slice C1, or a C0b that wires the
  profiler first; see notes above). Claude checks Drive again around 05:40 ET.
