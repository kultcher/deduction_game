# 2026-11-20, Argon: Burdens rework performance feasibility (`argon/burdens-feasibility`, docs only)

- **Base:** `origin/main` `1e45f93d` (reads [docs/design/burdens.md](docs/design/burdens.md) at `eec8716b` and the Tier 2 `case_eval` / `live_activity` splits).
- **What and why:** Read-only performance feasibility report for Claude-Seneschal's Nov 20 brief, added at [docs/design/burdens_perf_feasibility.md](docs/design/burdens_perf_feasibility.md):
  - **World count:** Dropping Lovers and enumerating at most 1 hidden burden (+1 `holders = 0` "no hidden burden" placement per team) cuts 10-NPC identity worlds from **15,120 -> 2,880** (`5.25×` fewer; `360` with 0 hidden burdens). Listing up to 4 possible burdens with `N` in play adds zero worlds; 12 NPCs (6,600) fits comfortably inside today's 10-NPC budget.
  - **Hot paths:** Maps the touch points across `WorldDomain.cs`, `case_eval_classes.gd` / `case_eval_content.gd` / `CaseEvalKernel.cs`, `live_activity_pack.gd` / `live_activity_factors.gd` / `live_activity_profiles.gd` / `LiveActivity.cs`, and `connections.gd`.
  - **Cost & caching:** Estimates **20–40% net speedup** per refresh/presentation on 10 NPCs (bounded by non-world-scaled `LiveActivity` and `Connections` work), and flags three specific `Connections.cache_verify` / cache-key hazards (dynamic general allowance, `Marked` `secret_claim` on non-night reading units, and `Ill-Omened` hanging night).
  - **Prototype measurements:** Lists exact stage-timing, `nc`, `cache_verify`, cache-hit-rate, and 12-NPC headroom checks to run on the `mock/` prototype.
- **Overlap with Lantern:** Judge probability semantics (unenumerated `Marked` weights, general-allowance formula, `Ill-Omened` doubt combination) are deferred to Lantern's report; this covers world counts, hot paths, cache keys, and timing.
- **Verification:** Docs only; zero code or golden changes.
- **Overlaps:** None (two new markdown files under `docs/design/` and `docs/handoff/`).
