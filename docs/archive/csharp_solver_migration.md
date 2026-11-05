# C# (.NET 8) Solver Backend Migration Plan

**Status:** Complete. **Nov 4 cutover (Claude-Bailiff): C# is the only solver.** The game, the bot, the tests and the golden capture all run the C# kernels; the GDScript kernel implementations, `SolverBackend` modes (`GDSCRIPT`/`VERIFY`), the parity CI job and the slice parity suites (`test_csharp_slice_c1`-`c3`) were removed. A missing assembly is a hard error. The last dual-mode code is kept on branch `archive/gdscript-solver-final` (`47913b7`) as the starting point should a browser build (no C# export) ever be wanted; that would be a port project, not a sync. Kernel changes from here on are C# only. Some small GDScript paths remain on purpose where C# mode always used them (e.g. `Solver._positions` below 64 worlds, `CaseEval._evaluate_posterior_gd` when a case has no compiled C# class table, `WorldDomain._gift_time_gd` for input packing).

*History below is the migration as it happened.*
**Updated:** 2026-11-03
**Repository location:** `docs/csharp_solver_migration.md` (and Section 5 of `docs/orchestration_plan.md`)
**Related:** `docs/orchestration_plan.md` (Zone 9 / Milestone 3, Track 3B), `docs/legacy_retirement_plan.md`, `docs/handoff_log.md`, `workshop/caches.gd`

---

## 1. Goal & Core Invariants

Port the hot numerical solver kernel in `workshop/` from GDScript to **C# (.NET 8 RyuJIT)** to bring late-game Day 3-4 meeting refreshes, presentations, and 150-seed bot sweeps well under the 2-second interactive budget, while unlocking 12-13-NPC town setups (103k-180k worlds), 2-modifier scripts (e.g., The Hexer), and Storyteller/Director counterfactual lookahead.

To guarantee that simulation tuning, tie-breakers, and RNG consumption **never drift** during the port, the migration enforces nine strict engineering invariants:

1. **Pre-Flight Gate (Never Port Moving Math):** C# solver work does not start until **Legacy Purge Phases 2c and 3** (`workshop_effects` and `--native` removed) and the **Tuning Literal Hoist** (`sim/tuning.gd` / `Tuning.fingerprint()`) are merged and signed off on `main`.
2. **Post-Purge Golden Oracle (Same-Platform Rule):** Immediately upon Milestone 1 sign-off, re-record the golden baseline from the post-purge GDScript solver (`baseline_82faa5b`). Because underlying C math libraries (`glibc` on Linux vs. UCRT on Windows) can differ by 1 ULP on transcendental functions even in pure GDScript, always record and compare baselines on the **same platform** (and run a Windows-vs-Linux container diff check).
3. **Phase 1 is Strictly Bit-Exact (`--tol 0`):** Suspicions feed `>=` gates in `decide()` and ranking sorts; even a 1e-15 ULP difference can flip a tie-breaker and diverge full-game replays. Phase 1 preserves exact left-to-right loop summation order, uses zero `Vector<double>` horizontal SIMD reductions, runs single-threaded, and enforces the **Bit-Exact Numerical Checklist** (Section 3) so results match the GDScript oracle at **`--tol 0`**.
4. **Retain Side-by-Side `VERIFY` Mode:** Keep `SolverBackend.Mode = GDSCRIPT | CSHARP | VERIFY`. While the golden diff only reveals *which refresh* diverged, `VERIFY` runs both backends on every kernel call, asserts bit-exact equality (`--tol 0`) at the function boundary, logs the exact function and input on mismatch, and **always returns the GDScript value** so the game stays on the reference path.
5. **Measure Marshaling First, Cache Immutable Universes by Handle:** Slice C0b/C1 measured `pack_inputs` at `1,932 ms` on Seed 42 (from repacking immutable `universe` and `cc.rep` arrays per boundary call). Slices C2 and C3 introduce handle-based packed universe/sub-universe, compiled equivalence-class (`CompiledCaseEntry`), and sum-product circuit registration in `SolverContext` (plus view-env memoization in `LiveActivity`), cleared atomically in `WorkshopCaches.clear_all()`.
6. **Profile First, Judge Speed at C3 (Not C1):** Do not judge net speedup at Slice C1. While outer loops remain in GDScript during C1/C2, per-world or per-card calls cross the GDScript/C# boundary repeatedly. Slice C0b (`tools/profile_c0.gd`) records call counts and exclusive/inclusive stage timings; net speedup is judged at **Slice C3** once compilation and marginalization loops live inside C#.
7. **1:1 Translation First (Defer Opcodes, Threading & Maybe C4):**
   * Port `role_constraints.gd` and `live_activity.gd` as direct 1:1 translations of existing checks rather than inventing a declarative opcode VM during parity lock.
   * Keep all refreshes synchronous on the main thread (`WorkerThreadPool` background refreshes change when beliefs are read and are deferred until after parity).
   * Gate **Slice C4 (`reason_attribution.gd`)** on post-C3 profiling, since Legacy Purge Phase 2a already made `WorkshopOwnership.reasons_for` lazy.
8. **Unified Cache Clearing (`WorkshopCaches.clear_all()`):** `WorkshopCaches.clear_all()` clears all GDScript caches **and** invokes `SolverBridge.ClearContext()` -> `SolverContext.Clear()` atomically so zero state (including universe, movement factor, compiled case, and sum-product handles) leaks between cases.
9. **Offline Build Constraint:** C# code in `Demonologist.csproj` depends strictly on the .NET 8 BCL and `GodotSharp` bundled with Godot 4.7.2 .NET (`GodotSharp/Tools/nupkgs`), with zero external NuGet dependencies.

---

## 2. Boundary Design & Slice Progress

### Stays in GDScript (Control, Ownership & UI)
* `workshop/jury.gd`, `workshop/shared_ledger.gd`, `workshop/circumstantial.gd`
* `game/workshop_ownership.gd`, `game/workshop_presentation.gd`, `game/credibility.gd`
* `workshop/live_evidence.gd`, `workshop/live_assessment.gd`, `workshop/canvas_model.gd`, `workshop/case_graph.gd`
* `workshop/caches.gd` (clears all GDScript caches + `SolverBackend.clear_context()`)

### Moves to C# (`workshop/cs/` — Pure Numerical Kernel)
* **Slice C0, C0b & C1 (Merged `0498fce`):** `Demonologist.csproj`, `workshop/cs/SolverBridge.cs`, `workshop/solver_backend.gd` re-entrant exclusive/inclusive stage timers and boundary call counters (`tools/profile_c0.gd`), `workshop/cs/SolverContext.cs` (8-byte `WorldEntry` struct + universe/handle arena), `workshop/cs/WorldDomain.cs`, and `workshop/cs/RoleConstraints.cs` (1:1 bitmask role-constraint checks, 64-bit `coarse_mask`/`coarse_masks`, Seer Red Herring marginalization, and simple/temporal `bluff_weights`), verified by `tools/test_csharp_slice_c0.gd` and `tools/test_csharp_slice_c1.gd`.
* **Slice C2 (Merged `4077dce`):** `workshop/cs/LiveActivity.cs` (`workshop/live_activity.gd` 1:1 port: night route bitmask enumeration, drop Hall matching & Lamplighter walker counts, batched persistent night-walk / evening haunt likelihoods, batched scene crossing probabilities, compiled movement factor handles, and single + handle-batched two-trace passer & Scion succession world scoring wired into `CaseEval._movement_scores`), verified by `tools/test_csharp_slice_c2.gd` (2.5x Seed 42 end-to-end speedup, 0 mismatches across 2.1M `VERIFY` checks on Seed 54875).
* **Slice C3 (Delivered via `patch_004_slice_c3.zip`):** `workshop/cs/SolverKernel.cs` (`world_bits`, `sig_groups`, `valid_table`, `report_table`, `_solve` candidate & position filtering, fixture `_movement`, `question_table`, and `premise_mask`), `workshop/cs/CaseEvalKernel.cs` (`_index`, `compile` equivalence classes + fused C# movement scoring, `_own_counts`, `_team_prior`, `_class_like`, and full `evaluate` posterior pass including `_people`, `_joint`, `_pivotal`, and `_expand`), and `workshop/cs/ChannelSumProduct.cs` (`compile`, `evaluate`, `circuit`, `run`, and batched `FactoredChannels.assess`), plus targeted `pack_inputs` and `outer_prep` follow-ups from C2 profiling, verified by `tools/test_csharp_slice_c3.gd`.
* **Slice C4 (Conditional on Post-C3 Profile):** `workshop/reason_attribution.gd` (`_class_like` and `_subset_fits` leave-one-out inner loops, ported only if post-C3 profiling shows attribution > 150ms in late-game meetings; note `_subset_fits` and `_class_like` already route role and class-likelihood checks through C1 and C3).

---

## 3. Bit-Exact Numerical & Marshaling Checklist (`--tol 0`)

1. **Rounding Semantics (`MidpointRounding.AwayFromZero`):** Always call `SolverBridge.GodotRound(x)` (`Math.Round(x, MidpointRounding.AwayFromZero)`) and `SolverBridge.GodotSnappedf(x, step)`.
2. **Linear Interpolation (`GodotLerpf`):** Always call `SolverBridge.GodotLerpf(from, to, weight)` (`from + (to - from) * weight` in 64-bit `double`), never `(1.0 - weight) * from + weight * to`.
3. **64-Bit Integer Width (`long` / `Int64`, Never 32-Bit `int` for Codes):** `WorldDomain.key`, `RoleConstraints.coarse_mask`, `CaseEval`'s ternary world codes and bounds (`radix = 3^k`, `rm_bound` up to ~9e18), and packed `WorldEntry` keys **must** use `long` (`Int64`) and `PackedInt64Array`.
4. **Transcendental & Float Literal Parity (`exp`, `log`, `pow`, `GdFloor1e30`):** Verified at 0-ULP parity via `tools/test_csharp_slice_c0.gd` and `tools/test_csharp_slice_c3.gd`. Note Godot parses `1e-30` as `0x39B4484BFEEBC29F` (1 ULP below IEEE nearest `...C2A0`), matched via `SolverContext.GdFloor1e30`.
5. **Deterministic Packing Order & `PackedFloat64Array` Only:** Pack arrays in the exact iteration order of GDScript's dictionaries/arrays and use `PackedFloat64Array` exclusively. Never use `Packed*Array()` in GDScript `const` declarations.

---

## 4. Kernel Math Call-Site Audit (`workshop/`)

Complete inventory of floating-point transcendental, rounding, and interpolation call sites across `workshop/`, audited at `--tol 0` in `tools/test_csharp_slice_c0.gd` and `tools/test_csharp_slice_c3.gd`:

| File & Location | Expression | Argument Domain | C# Equivalent & Slice |
| :--- | :--- | :--- | :--- |
| `world_domain.gd` | *(none — pure 64-bit integer/bitmask)* | `n <= 15` | `WorldDomainKernel` (Slice C1) |
| `role_constraints.gd` (`_temporal_bluff_weights`) | `lerpf(1.0, BLUFF_WEIGHT, hw)` | `BLUFF_WEIGHT` in `[0, 1]`, `hw` in `[0, 1]` | `SolverBridge.GodotLerpf(1.0, bw, hw)` (Slice C1) |
| `live_activity.gd` (`_likelihood`, `crossing_probability`) | `lerpf(0.75, 0.2/0.9, s)`, `lerpf(0.15, 0.7/0.0, s)` | `s` in `[0.0, 1.0]` | `SolverBridge.GodotLerpf` + `GdFloor1e30` (Slice C2) |
| `live_activity.gd` (`_profile_paths`) | `lerpf(0.05, 0.55, hw)` | `hw` in `[0.0, 1.0]` | `SolverBridge.GodotLerpf` (Slice C2) |
| `case_eval.gd` (`compile`) | `int(pow(3, k))` | integer `k` in `0..16` (`3^16 = 43,046,721`) | `(long)SolverBridge.GodotPow(3.0, k)` (Slice C3) |
| `case_eval.gd` (`_movement_score`, `_test_like`) | `pow(2.0, log2_ratio)` | `log2_ratio` in `[-20.0, +20.0]` | `SolverBridge.GodotPow(2.0, lr)` (Slice C3) |
| `case_eval.gd` (`_team_prior`) | `exp(prior_k * clampf(raw, 0.0, 1.5))` | `prior_k * raw` in `[0.0, 6.0]` | `SolverBridge.GodotExp` (Slice C3) |
| `case_eval.gd` (`_team_prior`) | `pow(2.0, -2.0 * (clampf(trust, 0.0, 1.0) - 0.5))` | exponent in `[-1.0, +1.0]` | `SolverBridge.GodotPow` (Slice C3) |
| `factored_channels.gd` (`_values`) | `pow(2.0, float(f.log2_ratio))` | `log2_ratio` in `[-20.0, +20.0]` | `SolverBridge.GodotPow` (Slice C3) |
| `channel_likelihood.gd`, `support_model.gd` | `pow(2.0, exponent)` | `exponent` in `[-20.0, +20.0]` | Stays in GDScript / `GodotPow` |
| `movement_model.gd`, `public_evidence.gd`, `speech_evidence.gd`, `reason_attribution.gd` | `log(x) / log(2.0)` | `x` in `[1e-12, 1e+12]` | Stays in GDScript (`GodotLog` verified) |
| `theory.gd` (`prepare`) | `pow(THEORY_BIAS_BASE, confidence)` | `confidence` in `[0.0, 1.0]` | Stays in GDScript (`GodotPow` verified) |
| `jury.gd`, `session.gd`, `circumstantial.gd` | `snappedf(val, 1e-9)` / `snappedf(val, 1e-4)` | `val` in `[-1.5, 3.0]` | Stays in GDScript (`GodotSnappedf` verified) |
