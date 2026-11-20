# Codebase Bloat & Obsolescence Audit (2026-11-19)

**Author:** Argon  
**Snapshot:** `origin/main` `17dd113f` (Nov 19, 2026)  
**Scope:** Module split candidates for navigability (`sim/`, `workshop/`, `game/`, `ui/`) and obsolete/unused systems beyond Lantern's scheduled Connections purge (Phases 5–6). Read-only audit; no code changed here.

---

## Part 1: Module Split Candidates

At `17dd113f`, **27 production files exceed 1,000 lines** (10 exceed 1,800 lines):

| Lines | File |
|---:|---|
| 3,864 | `sim/dialogue_voices.gd` |
| 2,578 | `sim/mind_meeting.gd` |
| 2,380 | `workshop/cs/LiveActivity.cs` |
| 2,078 | `sim/world.gd` |
| 2,031 | `workshop/live_activity.gd` |
| 1,998 | `workshop/solver.gd` |
| 1,909 | `ui/main.gd` |
| 1,882 | `sim/mind_dialogue.gd` |
| 1,845 | `sim/mind.gd` |
| 1,843 | `workshop/case_eval.gd` |
| 1,580 | `workshop/connections.gd` |
| 1,516 | `ui/live_case_workshop.gd` |
| 1,455 | `workshop/reason_attribution.gd` |
| 1,441 | `workshop/cs/RoleConstraints.cs` |
| 1,432 | `sim/social.gd` |
| 1,410 | `ui/workshop_canvas_view.gd` |
| 1,409 | `workshop/jury.gd` |
| 1,409 | `workshop/cs/CaseEvalKernel.cs` |
| 1,394 | `workshop/cs/SolverKernel.cs` |
| 1,355 | `sim/evil.gd` |
| 1,321 | `sim/tuning.gd` |
| 1,300 | `game/workshop_canvas.gd` |
| 1,246 | `workshop/canvas_model.gd` |
| 1,111 | `workshop/cs/ChannelSumProduct.cs` |
| 1,063 | `game/game.gd` |

### Tier 1 — Highest-value splits (multiple distinct subsystems in one file)

1. **`sim/mind_meeting.gd` (2,578 lines)**  
   Already structured along clear phase boundaries:
   - Town testimony, disclosure, and citing reasons → keep in `sim/mind_meeting.gd`
   - Nominator's case (~500 lines) → `sim/mind_nomination.gd`
   - Defence & voting (~800 lines) → `sim/mind_defence.gd` (optionally split voting into `sim/mind_vote.gd`)

2. **`sim/world.gd` (2,078 lines)**  
   Divides cleanly by lifecycle phase:
   - Setup, cast, and town generation (~290 lines) → `sim/world_setup.gd`
   - Meeting, execution, grief, and bereavement (~360 lines) → `sim/world_meeting.gd`
   - Night resolution and night abilities (~730 lines) → `sim/world_night.gd`
   - Leaves `sim/world.gd` as world state + helpers + day phase loop (~650 lines).

3. **`sim/mind_dialogue.gd` (1,882 lines)**  
   - Hints, pressing, and contradictions (~415 lines) → `sim/mind_press.gd`
   - General conversation answers (~1,240 lines) → keep in `sim/mind_dialogue.gd` (or split readings/whereabouts from opinions/requests).

4. **`ui/main.gd` (1,909 lines)**  
   UI controller mixing 4–5 distinct panels:
   - Roles reference panel (~160 lines) → `ui/roles_panel.gd`
   - Command dispatch and scene/meeting log capture (~320 lines) → `ui/main_capture.gd`
   - Action panel & pickers (~675 lines) → `ui/action_panel.gd` + `ui/action_pickers.gd`

5. **`sim/mind.gd` (1,845 lines)**  
   Already delegates meeting and dialogue; still holds two separable subsystems:
   - Shadow-self creation, sync, and evil override (~245 lines) → `sim/mind_shadow.gd`
   - Case & card evaluation (~385 lines) → `sim/mind_cases.gd`

### Tier 2 — Clean medium-priority splits

- **`sim/dialogue_voices.gd` (3,864 lines):** Pure per-NPC voice data tables. Low-risk split into `sim/voices/<npc>.gd` + a thin loader if editing individual characters feels unwieldy.
- **`sim/social.gd` (1,432 lines):** Clean half-way seam between NPC-to-NPC exchanges/agreement trust (top half) and player approaches, gossip, and role-asking (bottom half → `sim/social_approaches.gd`).
- **`ui/live_case_workshop.gd` (1,516 lines) & `ui/workshop_canvas_view.gd` (1,410 lines):** `live_case_workshop.gd` has a ~380-line seam for premise and card-answer editors; `workshop_canvas_view.gd` mixes `_draw_*` rendering, input/drag-drop/tooltips, and evidence-card text formatting.
- **`workshop/live_activity.gd` (2,031 lines) & `workshop/case_eval.gd` (1,843 lines):** Both mix C# packing/bridge marshaling, compilation/caching, and scoring/diagnostics. Separating C# packing helpers or post-eval diagnostics (`_theory_fit`, `_pivotal`, `_rivals`) would keep the core math easier to read.
- **`workshop/connections.gd` (1,580 lines):** Clean seam around `stored cases` (~420 lines → `workshop/connections_cases.gd`).

### Tier 3 — Hold off until Lantern's Connections purge (Phases 5–6)

These files still carry pre-Connections code already scheduled for deletion; avoid splitting them prematurely:
- `workshop/jury.gd` (1,409 lines)
- `workshop/reason_attribution.gd` (1,455 lines)
- `workshop/live_assessment.gd` (993 lines)
- `workshop/shared_ledger.gd` (932 lines)
- `workshop/reasoner.gd` (842 lines)
- `ui/case_workshop.gd` (1,025 lines) — legacy non-live workshop UI base class (still inherited by `ui/case_workshop_canvas.gd` → `ui/live_case_workshop.gd`)

### Tier 4 — Leave as-is (large, but cohesive)

- **`sim/tuning.gd` (1,321 lines):** Central knob table; one searchable file is preferable to scattered constants.
- **C# kernels** (`workshop/cs/LiveActivity.cs` 2,380, `RoleConstraints.cs` 1,441, `CaseEvalKernel.cs` 1,409, `SolverKernel.cs` 1,394): Tight numeric hot loops. Only `LiveActivity.cs` is borderline for a `partial class` split (packing vs. movement factor vs. route solver).

---

## Part 2: Obsolete Systems & Dead Code (Beyond the Connections Purge)

### 1. The `channel_*` factored-evidence stack (~2,420 lines, 0 live callers)

Superseded by `CaseEval`. Nothing in `sim/`, `game/`, `ui/`, or live `workshop/` calls any of these files — only `workshop/caches.gd` (to clear their caches) and their own unit/profiling tests (`test_workshop_channels`, `test_workshop_channel_likelihood`, `profile_channel_likelihood`):

- `workshop/cs/ChannelSumProduct.cs` (1,111 lines) + its bridge methods in `workshop/cs/SolverBridge.cs`
- `workshop/factored_channels.gd` (640 lines)
- `workshop/channel_sum_product.gd` (323 lines)
- `workshop/evidence_channels.gd` (182 lines)
- `workshop/channel_likelihood.gd` (164 lines)
- Cache-clear hooks in `workshop/caches.gd` (`L13–51`)

### 2. The trace viewer & Python/web frontend (~860 lines + sidecar trace plumbing)

- `tools/trace.py` (59 lines)
- `tools/case_viewer.py` (276 lines)
- `tools/case_viewer.html` (269 lines)
- `tools/test_case_viewer.py` (180 lines), `tools/test_case_viewer.js` (79 lines), and `tools/fixtures/case_viewer.trace.jsonl`
- If the viewer is retired, revisit whether the `.trace.jsonl` sidecar (`detailed_logging` / `trace_capture`) in `sim/devlog.gd` and `sim/world.gd` is still needed. Note that `tools/replay_log.gd` and `#280`'s state digest read the main devlog, not the `.trace.jsonl` sidecar.

### 3. Standalone dev labs & fixture-only Workshop scaffolding

- **Dialogue lab (0 production callers):** `ui/dialogue_lab.tscn`, `ui/dialogue_lab.gd` (254 lines), `ui/dialogue_vn_preview.gd` (224 lines).
- **Standalone Workshop lab scenes:** `ui/case_workshop.tscn`, `ui/case_workshop_lab.tscn`, `ui/workshop_comparison.gd` (177 lines). *(Note: `ui/live_case_workshop.gd` still extends `ui/case_workshop_canvas.gd` → `ui/case_workshop.gd`, so those two `.gd` base scripts remain live until flattened.)*
- **Migration/fixture remnants:**
  - `workshop/ledger_audit.gd` (41 lines — only checks legacy-vs-shared ledger aliases)
  - The `movement_experiment` branch in `workshop/movement_model.gd` and `workshop/case_graph.gd` (populated only by `workshop/fixtures.gd` / `workshop/scenario.gd` for fixture tests).

### 4. One-off investigation & prototype scripts in `tools/`

Candidates to archive or delete once their investigations are closed:
- `tools/replay_54875.gd` & `tools/run_replay_54875.py`
- `tools/connections_prototype.gd` & `tools/connections_prototype_summary.py`
- `tools/probe_prior_compare.gd` & `tools/probe_prior_aggregate.py`
- `tools/measure_evidence.gd`, `tools/measure_evidence_summary.py`, `tools/measure_interactions_summary.py`, `tools/measure_npc_trust.gd`, `tools/measure_premise_frames.gd`
- `tools/profile_c0.gd`
- `tools/dialogue_voice_sketches.gd` & `tools/dialogue_voice_sketches.json`
- `tools/make_trace_icons.py`, `tools/slice_sheets.py`
- *(Local workspace note: `logs/migration/resume/adapters/project/` contains an old snapshot of `game/` and `logs/` that adds search noise if still present on disk.)*

### 5. Dead flags & retired constants in `sim/`

- `sim/tuning.gd`:
  - `ALLOW_NO_GIFT_DENIAL = false`
  - `USE_FLAVOR_SECRETS = false`
  - `LEGACY_MUD_DROPS_ENABLED = false`
  - `RIVAL_CLAIM_EFF` (marked retired legacy alias)
  - `PARANOIA_DRIFT_RATE` (marked unused since Oct 30)
  - `LEGACY_EXTRA_SHIFT_DRAW` (kept only for RNG alignment; removing it moves golden)
- `sim/content.gd`: `STRICT_EVALUATOR = false`, `USE_FLAVOR_SECRETS`.
- `sim/world.gd`: `var knell_night = -1` (marked legacy).
- `sim/muddler.gd` (539 lines): still wired in, though tentatively marked for removal in `docs/design/secrets_rework.md`.
