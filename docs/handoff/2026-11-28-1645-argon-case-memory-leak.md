# Handoff — Argon (`argon/case-memory-leak`)

**Date:** 2026-11-28 16:45 UTC  
**Branch:** `argon/case-memory-leak` (from `main`)  
**Goal:** Diagnose and fix multi-GB memory usage across consecutive 10-NPC games (without golden drift).

## Diagnosis (on `main` after PR #574)
1. **Cross-game retention is already flat after PR #574:**
   - Across 4 consecutive 10-NPC passive games (`seeds 100000–100003`, `--dynamic --no-trace`), Godot's `OBJECT_COUNT` stayed locked at `1,718` on games 1–4, `WorkshopCaches.clear_all()` zeroed all C# `SolverContext` handles (`u=0 mf=0 cc=0 cu=0`), and `ui/main.gd:_new_case()` already frees previous modal overlays (`Pacing`, `GrimReveal`, `DailyGuess`) and calls `g.new_case()` → `WorkshopCaches.clear_all()`.
   - However, C#'s `SolverContext.Clear()` only called `.Clear()` without trimming list capacities or compacting freed Large Object Heap (LOH) arrays back to the OS.
2. **The real cause of the 3–5+ GB footprint (and 16 GB runner OOMs) is massive within-game cache bloat during a single 10-NPC game:**
   - Per-cache drop measurement on `seed 100000` (10 NPCs passive; `1,795.7 MB` Godot static heap, `317.8 MB` C# GC, `3,010.6 MB` OS WorkingSet):
     - `CaseEval._fits_cache` (`12,524` entries, cap `16,384`): **930.9 MB** (each entry calls `ref.duplicate(true)`, deep-copying `view.people`, the entire timeline `tl`, `cc.rep`, and `role_cards` alongside `out`).
     - `CaseEval._compiled` (`3,191` entries, cap `4,096`): **318.4 MB** in GDScript (plus matching C# `SolverContext.CompiledCases` entries).
     - `LiveActivity.route_cache` / `cache` (caps `2,048` each, storing `input.duplicate(true)`): **153.4 MB** + **23.0 MB**.
   - Together those caches held **~1.4 GB** of Godot heap inside a single 10-NPC game (and 10-NPC bot game 1 hit **3.58 GB** private memory), so 4 concurrent 10-NPC processes easily exceeded 16 GB RAM on `ubuntu-latest` even on game 1 or 2.

## Changes (zero behaviour/golden drift)
- `workshop/case_eval_classes.gd`:
  - Tightened `CaseEval._fits_cache` cap from `16384` → `1024`.
  - Tightened `CaseEval._compiled` cap from `4096` → `1024` (already calls `SolverBridge.ClearCompiledCases()` on clear).
- `workshop/live_activity_pack.gd`: Tightened `route_cache` cap from `2048` → `512`.
- `workshop/live_activity.gd`: Tightened `cache` cap from `2048` → `512`.
- `workshop/cs/SolverContext.cs`: Added `TrimExcess()` on cleared handle lists in `Clear()`.
- `workshop/cs/SolverBridge.cs`:
  - Added conditional LOH compaction (`GCSettings.LargeObjectHeapCompactionMode = CompactOnce; GC.Collect(2, Forced, true, true)`) in `ClearContext()` only when `GC.GetTotalMemory(false) > 64 MB` (zero overhead for fast unit tests).
  - Added `GetMemoryStats(bool forceGc)` diagnostic helper for tests.
- `tools/test_case_memory.gd` (registered in `tools/ci_fast_suites.txt`): Plays 4 consecutive 7-NPC games and asserts `SolverContext` handles reset to 0 and Godot static heap, object count, and C# GC heap stay bounded after game 4 vs game 1.

## Before vs After (4 consecutive 10-NPC passive games, `seeds 100000–100003`)
| Game | Before (`main`) WS | After Fix WS | Delta | Wall Time (Before → After) |
|---|---:|---:|---:|---|
| 1 (`100000`) | 3,025.4 MB | **1,348.2 MB** (Peak 1,373.7 MB) | **-55.4%** | 61.1s → 63.1s |
| 2 (`100001`) | 2,266.3 MB | **1,277.3 MB** | **-43.6%** | 42.4s → 41.5s |
| 3 (`100002`) | 2,783.1 MB | **1,384.6 MB** | **-50.2%** | 35.4s → 35.8s |
| 4 (`100003`) | 2,404.7 MB | **1,313.3 MB** (Peak 1,385.7 MB) | **-45.4%** | 40.8s → 41.7s |

- **Zero drift:** All 4 games produced identical winners, days, executions, kills, lies, nominations, suspicion scales, and vote tallies.
- **Sweep restart workaround (#585):** With peak RSS cut from ~3.0+ GB down to ~1.38 GB and flat across games, 4 parallel 10-NPC passive processes fit comfortably (~5.5 GB total) in 16 GB RAM without restarting every 2 games. For `10_bot`, restarting is no longer needed for cross-game leaks, though keeping `--procs 2` (or verifying `10_bot` peak RSS) is still prudent if a single 10-NPC bot game peaks near 2.5–3 GB.
