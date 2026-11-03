# C# (.NET 8) Solver Backend Migration Plan

**Status:** Locked Specification (Gated on Milestone 1 Closeout)
**Updated:** 2026-11-03
**Repository location:** `docs/csharp_solver_migration.md` (and Section 5 of `docs/orchestration_plan.md`)
**Related:** `docs/orchestration_plan.md` (Zone 9 / Milestone 3, Track 3B), `docs/legacy_retirement_plan.md`, `workshop/caches.gd`

---

## 1. Goal & Core Invariants

Port the hot numerical solver kernel in `workshop/` from GDScript to **C# (.NET 8 RyuJIT)** to bring late-game Day 3-4 meeting refreshes, presentations, and 150-seed bot sweeps well under the 2-second interactive budget, while unlocking 12-13-NPC town setups (103k-180k worlds), 2-modifier scripts (e.g., The Hexer), and Storyteller/Director counterfactual lookahead.

To guarantee that simulation tuning, tie-breakers, and RNG consumption **never drift** during the port, the migration enforces eight strict engineering invariants:

1. **Pre-Flight Gate (Never Port Moving Math):** C# solver work does not start until **Legacy Purge Phases 2c and 3** (`workshop_effects` and `--native` removed) and the **Tuning Literal Hoist** (`sim/tuning.gd` / `Tuning.fingerprint()`) are merged and signed off on `main`.
2. **Post-Purge Golden Oracle (Same-Platform Rule):** Immediately upon Milestone 1 sign-off, re-record the golden baseline from the post-purge GDScript solver. Because underlying C math libraries (`glibc` on Linux vs. UCRT on Windows) can differ by 1 ULP on transcendental functions even in pure GDScript, always record and compare baselines on the **same platform** (and run a Windows-vs-Linux container diff check in Slice C0).
3. **Phase 1 is Strictly Bit-Exact (`--tol 0`):** Suspicions feed `>=` gates in `decide()` and ranking sorts; even a 1e-15 ULP difference can flip a tie-breaker and diverge full-game replays. Phase 1 preserves exact left-to-right loop summation order, uses zero `Vector<double>` horizontal SIMD reductions, runs single-threaded, and enforces the **Bit-Exact Numerical Checklist** (Section 3) so results match the GDScript oracle at **`--tol 0`**.
4. **Retain Side-by-Side `VERIFY` Mode:** Keep `SolverBackend.MODE = GDSCRIPT | CSHARP | VERIFY`. While the golden diff only reveals *which refresh* diverged, `VERIFY` runs both backends on every kernel call, asserts bit-exact equality (`--tol 0`) at the function boundary, logs the exact function and input on mismatch, and **always returns the GDScript value** so the game stays on the reference path.
5. **Full Repacking First (No Premature Incremental State):** Start by repacking the full input into `Packed*Array` buffers on every refresh and measure the exact marshaling cost in isolation. Do not introduce incremental card/claim context syncing (which adds hidden state and cache-invalidation traps) unless measured repacking cost proves material.
6. **Profile First, Judge Speed at C3 (Not C1):** Do not judge net speedup at Slice C1. While outer loops remain in GDScript during C1/C2, per-world or per-card calls into `world_domain` and `role_constraints` cross the GDScript/C# boundary repeatedly and can make C1 slower than pure GDScript. Slice C0 records call counts and stage timings; net speedup is judged at **Slice C3** once the outer compilation and marginalization loops live inside C#.
7. **1:1 Translation First (Defer Opcodes, Threading & Maybe C4):**
   * Port `role_constraints.gd` as a direct 1:1 translation of existing role checks rather than inventing a declarative opcode VM during parity lock.
   * Keep all refreshes synchronous on the main thread (`WorkerThreadPool` background refreshes change when beliefs are read and are deferred until after parity).
   * Gate **Slice C4 (`reason_attribution.gd`)** on post-C3 profiling, since Legacy Purge Phase 2a already made `WorkshopOwnership.reasons_for` lazy.
8. **Unified Cache Clearing (`WorkshopCaches.clear_all()`):** There are 62 static caches across 19 files (`Jury._eval_memo`, movement caches, etc.), and `workshop/caches.gd` is the central place that clears them all. `WorkshopCaches.clear_all()` must clear all GDScript caches **and** invoke `SolverBridge.ClearContext()` atomically so zero state leaks between cases.

---

## 2. Boundary Design: What Moves vs. What Stays

### Stays in GDScript (Control, Ownership & UI)
* `workshop/jury.gd`, `workshop/shared_ledger.gd`, `workshop/circumstantial.gd`
* `game/workshop_ownership.gd`, `game/workshop_presentation.gd`, `game/credibility.gd`
* `workshop/live_evidence.gd`, `workshop/live_assessment.gd`, `workshop/canvas_model.gd`, `workshop/case_graph.gd`
* `workshop/caches.gd` (clears all 62 GDScript caches + `SolverBackend.clear_context()`)

### Moves to C# (`workshop/cs/` — Pure Numerical Kernel)
* **Slice C1:** `workshop/world_domain.gd` + `workshop/role_constraints.gd` (world universe enumeration, 8-byte `World` structs, and 1:1 bitmask role-constraint checks).
* **Slice C2:** `workshop/live_activity.gd` (night route bitmask enumeration, soft 3:1 trace family weights, and joint `(T1, T2)` passer trace likelihood contractions).
* **Slice C3:** `workshop/solver.gd` + `workshop/case_eval.gd` + `workshop/channel_sum_product.gd` + `workshop/factored_channels.gd` (equivalence-class compilation and left-to-right sum-product posterior marginalization).
* **Slice C4 (Conditional on Post-C3 Profile):** `workshop/reason_attribution.gd` (`_class_like` and `_subset_fits` leave-one-out inner loops, ported only if post-C3 profiling shows attribution > 150ms in late-game meetings).

---

## 3. Bit-Exact Numerical & Marshaling Checklist (`--tol 0`)

1. **Rounding Semantics (`MidpointRounding.AwayFromZero`):** Always call `Math.Round(x, MidpointRounding.AwayFromZero)` and `GodotSnappedf` to match Godot's tie-breaking formula.
2. **64-Bit Integer Width (`long` / `Int64`, Never 32-Bit `int` for Codes):** `CaseEval`'s ternary world codes and bounds (`radix = 3^k`, `rm_bound` up to ~9e18), bitmasks, and packed keys **must** use `long` (`Int64`) and `PackedInt64Array`.
3. **Transcendental Function Parity (`exp`, `log`, `pow`):** Verify 0-ULP parity via `test_csharp_slice_c0.gd` across representative inputs.
4. **Deterministic Packing Order & `PackedFloat64Array` Only:** Pack arrays in the exact iteration order of GDScript's dictionaries/arrays and use `PackedFloat64Array` exclusively.
5. **Full Input Repacking First:** Repack the full input state on every refresh call first and time the packing step separately.
