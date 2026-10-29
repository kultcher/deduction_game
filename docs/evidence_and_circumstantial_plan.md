# Evidence Rework & Circumstantial Hub Plan

**Status:** Slices 1-3 landed; Slice 4 active (`docs/evidence_and_circumstantial_plan.md`).
**Target Engine:** Godot 4.7.2 (GDScript).

This plan specifies two connected investigation and persuasion reworks for **Demonologist**, incorporating findings from the 200-seed feasibility audit, the 20,000-seed token/scent combinatorics sweep, Slice 2-3 playtest and review feedback, and live Workshop code audits:

1. **Multi-Category Crime-Scene Traces & Hidden Profile Receipts**: Replacing deterministic evening-block traces (`World._kill`) and main-board `"home"` / `"haunt"` clutter with a soft-worded (`3:1` LR) physical trace generator featuring **28 tactile 2-spot Trade Tokens and 56 bespoke 3-spot Lingering Scents (`67% / 33%` mix with a non-subset guard)** alongside tangible Quarter tokens and domestic Victim-Connection staging, hidden immutable profile receipts (`g.profile_receipts`), three-valued profile evaluation (`matches / contradicts / unknown`), additive passer second traces with joint `(T1, T2)` / `(T2, T1)` scene evaluation, exact Scion pre/post-execution night splits, and persistent haunt recording across both bare and pressed trace confrontations.

2. **Circumstantial Evidence Hub (Stage 2 "Mob Mentality" Vibes)**: Adding a dedicated patina/sea-slate Workshop hub node (`+0.015` max per qualifying incident, `+0.045` global cap per listener/target across all active cases) that lets players push fence-sitters over the vote threshold using listener-dependent social framing while routing logical/action cards into Stage 1 regardless of wiring and keeping `"is suspicious"` on standard Premise cards for the upcoming *Premises Matter* pass.

It absorbs or resolves these `BACKLOG.md` items:

* *Night movement and trace model* (fixing the evening-shift Demon vulnerability and retiring main-board `"home"` and `"haunt"` cards);
* *The Lamplighter contaminates vigils and traces* (turning passer trace overlap into a joint two-trace assignment puzzle);
* *Repeated trace matches add up* (compounding independent multi-night trace likelihoods in `CaseEval`);
* *Supporting evidence in a case: logical where possible, vibes where not* (separating Stage 1 world-filtering evidence from Stage 2 listener-biased social framing).

## 1. Settled Design & Calibration Decisions

* **Tactile Trade Tokens & Lingering Scents as the Primary Trace Backbone (`~75%` of Crime Scenes).** Setting `TRACE_LOCATIONS_BASE_WEIGHT = 3.5` (vs. `0.65` each for `quarter` and `connection`, with a `1.25x` fresh-family nudge) ensures **`~72-78%` of crime scenes produce tangible Trade Tokens or Lingering Scents**, while `quarter` and `connection` use concrete physical objects and domestic staging (`QUARTER_TOKENS`, drawn bolts, two pewter cups).

* **Complete Bespoke Catalog (`28` Trade Tokens + `56` Lingering Scents) & Concise 3-Line Card Copy.** All 28 location pairs map to concrete pocket/trade objects and all 56 location triples map to cohesive shared scents, formatted concisely so 3-line Workshop canvas nodes display the full item/scent and all associated places without truncating.

* **`67%` 2-Spot Trade Tokens / `33%` 3-Spot Lingering Scents with a Non-Subset Guard.** Blending `67%` 2-spot tokens with `33%` 3-spot scents and banning subset/superset location sets hits **`7.28` left after 1 clue**, **`5.31` left after 2 clues**, and **`3.90` left after 3 clues**, while both Demon and passer traces draw from the same `2:1` ratio so clue width never leaks killer vs. passer identity.

* **Additive Passer Confound with Joint `(T1, T2)` / `(T2, T1)` Evaluation.** When non-victim night-walkers cross `v.home_block`, `World._kill` rolls `EXTRA_TRACE_CHANCE` (`0.45`) to generate a second non-duplicate, non-subset trace from a passing walker alongside the Demon's trace, shuffles their presentation order (`50/50`), and assigns `trace_slot = 0, 1` and `scene_trace_count` *after* shuffling. Citing 1 of 2 cards blends `0.5 * w(d, T1) + 0.5 * E_pass(T1)` (cherry-pick guard), whereas citing both `(T1, T2)` scores `0.5 * (w(d, T1) * E_pass(T2) + w(d, T2) * E_pass(T1))`.

* **Exact Scion Succession Timing & Pressed-Trace Haunt Persistence (Slice 3 Follow-Up Fixes).**
  * **Scion Epoch Boundary (`workshop/live_activity.gd`)**: Because `World.execute` runs at Day `exec_day` Evening (`tick = exec_day * 4 + 2`) and promotes the Scion via `_scion_rises` *before* `resolve_night()` runs Night `exec_day` (`tick = exec_day * 4 + 3`), pre-takeover nights belonging to the hanged original Demon are strictly `0 <= night < exec_day`, while post-takeover nights belonging to the Scion start on **that execution day's night** (`night >= exec_day`), with `alive_demon_mask` checking `History.alive_at_night(view, p.id, exec_day)`.
  * **Trace Confrontation Haunt Saving (`game/game.gd`, `sim/mind.gd`, `sim/mind_dialogue.gd`)**: `Mind.press` forwards `known_haunts` into `react_to_trace` (preferring not-yet-known matching haunts when deflecting), and `Game._talk_command` persists `r.get("profile_haunts", [])` into both `known_haunts` and `add_profile_receipt({"kind": "haunt", ...})` across all conversation verbs (`trace_ask`, `press`, and `confront`).

* **Dedicated `"Add Circumstantial Evidence"` Hub & Stage 1 / Stage 2 Split (Slice 4).**
  * **Evidence-Driven Channel Routing**: Cards wired into a `"circumstantial"` hub still flow into `result.cards` so Stage 1 (`CaseEval` / `LiveActivity` / `SpeechEvidence`) evaluates logical and movement evidence identically regardless of how the player wires the canvas. Players never lose Stage 1 credit by organizing supporting material through the hub.
  * **Patina / Sea-Slate Hub Node (`#cde0dc` / `#7ea69f`)**: Displays a `"Needs a premise"` chip when unlinked, validates non-empty inputs and accusatory target premises (`evil`, `demon`, `minion`, `suspicious`) when compiled, and supports full Workshop inspect, undo, context-menu removal, and JSON export/restore.
  * **Stage 2 Union Evaluation (`+0.015` Incident Max, `+0.045` Target Cap)**: Evaluated once on the frozen post-Stage-1 snapshot (never iterating, never feeding Stage 1 priors), gated by specific Stage 1 grounding above passive public-event survivor redistribution (`gate = clampf((specific_stage1 + 0.35 * maxf(0.0, outside - 0.15)) / 0.06, 0.0, 1.0)` so vibes alone cannot carry a case even after public deaths or silences), deduplicated across all active cases per `(listener, target, incident_key)`, and stored in a separately retractable `workshop_state.circumstantial_requested` / `circumstantial_applied` vector.
  * **Semantic Smear Backlash (`-0.005` to `-0.015`)**: Presenting a hub padded with ungrounded smear cards or pure vibes without Stage 1 backing triggers a one-time trust penalty (`-0.005` to `-0.015`) per presentation signature.

## 2. Updated Code Touchpoints

| Area | Files & Functions | Status & Change |
| :--- | :--- | :--- |
| **Hidden profile receipts & UI** | `game/game.gd`, `game/game_board.gd`, `ui/profile_panel.gd`, `ui/trait_bars.gd`, `workshop/canvas_model.gd`, `ui/live_case_workshop.gd` | **Landed (Slices 1-2)**: `g.profile_receipts` (`-10001..`), retired main-board `"home"`/`"haunt"` cards, `Townsfolk Profile Info` node, `prior_links` cleanup on deletion. |
| **Token/Scent flavor & passer 2nd trace** | `sim/content.gd`, `sim/tuning.gd`, `sim/world.gd` (`_kill`), `sim/mind_dialogue.gd` | **Landed (Slice 3) + Slice 4 Fix**: 28 `TRACE_TOKENS`, 56 `TRACE_SCENTS`, `~75%` `locations` weight, `EXTRA_TRACE_CHANCE` (`0.45`) shuffled 2nd passer trace, plus pressed-trace `profile_haunts` persistence in `Mind.press` and `Game._talk_command`. |
| **Joint `(T1, T2)` scene solver & Scion timing** | `workshop/live_assessment.gd`, `workshop/live_activity.gd`, `game/workshop_canvas.gd` | **Landed (Slice 3) + Slice 4 Fix**: Scene-level joint factor (`L_scene`), `crossing_probability`, walker-pairing summary, and exact Scion succession night split (`night < exec_day` vs. `night >= exec_day`). |
| **Stage 2 circumstantial hub** | `workshop/circumstantial.gd`, `workshop/canvas_model.gd`, `workshop/live_assessment.gd`, `workshop/shared_ledger.gd`, `workshop/jury.gd`, `game/workshop_ownership.gd`, `game/workshop_presentation.gd`, `game/workshop_canvas.gd`, `ui/live_case_workshop.gd`, `ui/workshop_canvas_view.gd`, `ui/workshop_drawer.gd` | **Slice 4**: Patina/sea-slate `"circumstantial"` hub node, `"Needs a premise"` orphan chip, 5 qualifying incident families, Stage 1 grounding gate, union-level `+0.015 / +0.045` evaluation, retractable ownership vector, smear backlash, and `tools/test_workshop_circumstantial_hub.gd`. |
| **15-cast voice pass & balance sweep** | `sim/dialogue_voices.gd`, `tools/autoplay.gd` | **Slice 5**: Promote `[PH]` trace/circumstantial lines to 15 cast voices, teach `autoplay.gd` to pair profile + walker + trace + hub receipts, and run 150-seed A/B balance sweep. |

## 3. Joint Two-Trace Scene Math & Scion Boundary (Slices 3-4)

For each murder scene `S` on `night` (`victim` at `scene_block`):

1. **Per-Person Route Crossing Probability (`cross_prob[j][align]`)**:
   * Under `LiveActivity._profile_paths` and `_observed` (excluding scene traces so movement is never double-counted), compute for each `j != victim` and `align in {"good", "minion", "converted"}` the normalized probability `cross_prob[j][align] in [0.0, 1.0]` that `j` walked a valid night path containing `scene_block` on `night`.
2. **Expected Passer Trace Weight (`E_pass(T, world, d)`)**:
   * Given world `(evil, d)`, let `Z = eps + sum_{j != d, victim} cross_prob[j][align_j]` (`eps = 0.05`) and `E_pass(T, world, d) = (eps * 1.6 + sum_{j != d, victim} cross_prob[j][align_j] * w_match(j, T)) / Z`.
3. **Scene Likelihood Factor (`L_scene(world, d)`)**:
   * Single-trace scene: `w_match(d, T1)`.
   * Two-trace scene with 1 trace cited: `0.5 * w_match(d, T1) + 0.5 * E_pass(T1, world, d)`.
   * Two-trace scene with both traces cited: `0.5 * (w_match(d, T1) * E_pass(T2, world, d) + w_match(d, T2) * E_pass(T1, world, d))`.
4. **Scion Succession Epoch Split**:
   * For an execution on `exec_day` with `alive_before >= 5`, `pre_cards` covers `night < exec_day` (scored with `exec_idx` as original Demon) and `post_cards` covers `night >= exec_day` including the execution day's own night (scored with surviving `d_idx` as promoted Scion).

## 4. Stage 2 Circumstantial Evidence Hub Specification (Slice 4)

1. **Qualifying Incident Families (`workshop/circumstantial.gd`)**:
   * **Breathstealer Daytime Proximity (`breath_prox:<target>:<day>`)**: Public `silenced` event on `day` for `victim != target` paired with a daytime `conversation` or same-block `sighting` placing `target` with `victim` (or on `victim`'s home block) that day, weighted by `1.0 - post_stage1_susp(victim)`.
   * **Suspicious Association (`assoc:<target>:<partner>`)**: Daytime/evening `conversation` or `friend` profile bond between `target` and `partner != target` where the listener already suspects `partner` (`post_stage1_susp(partner) >= 0.32`), judged strictly by beliefs about `partner` rather than `target`.
   * **Hostile Vote or Nomination Against Trusted Soul (`hostile_vote:<target>:<day>:<nominee>`)**: Public `vote` receipt where `target` nominated or voted yes against `nominee != target` whom the listener considers proven good or strongly trusted (`post_stage1_susp(nominee) <= 0.28` and `npc_trust(nominee) >= 0.45`).
   * **Victim Rivalry (`victim_rival:<target>:<victim>`)**: Profile `rival` bond between `target` and a public `demon_death` `victim`, weighted by `1.0 - post_stage1_susp(victim)`.
   * **Demeanor / Evasiveness Tell (`demeanor_tell:<target>`)**: `refusal` receipt on `target`, contradicted `alibi` on `target`, or `trait` receipt showing `low` Composure / `high` Privacy when paired with Stage 1 scrutiny.

2. **Stage 1 Grounding Gate, Caps & Retractable Ownership**:
   * **Single-Pass Gate**: Subtracts passive town-wide survivor redistribution (`passive_floor` across living non-cleared townsfolk) so public deaths and silences alone do not unlock vibes: `gate = clampf((specific_stage1 + 0.35 * maxf(0.0, outside - 0.15)) / 0.06, 0.0, 1.0)`.
   * **Caps**: Each distinct `(target, incident_key)` across the listener's active non-withdrawn presentations contributes at most `+0.015`, and the union sum per `(listener, target)` is capped at `+0.045` (zeroed if `target` is the listener or `known_good`).
   * **Retractable Storage**: `WorkshopOwnership` retracts both `state.requested` and `state.circumstantial_requested` in `phase == "before"` before Stage 1 `CaseEval` runs, preventing Stage 2 vibes from feeding back into Stage 1 priors on subsequent refreshes, and cleanly removing them on `workshop_retract` or `set_workshop_effects(false)`.

3. **Semantic Smear Backlash**:
   * Presenting a hub that cites ungrounded/unrelated cards with weak Stage 1 support (`specific_stage1 < 0.02`) or pushes pure vibes (`gate == 0.0`) applies a one-time trust penalty in `[-0.015, -0.005]` (`CIRCUMSTANTIAL_SMEAR_MIN` to `CIRCUMSTANTIAL_SMEAR_MAX`) keyed by presentation signature.

## 5. Vertical-Slice Rollout Status

1. **Slice 1 (Landed)**: Hidden Profile Receipts (`g.profile_receipts`), Board Cleanup & Workshop `Townsfolk Profile Info` Node.
2. **Slice 2 (Landed)**: Single-Trace Token/Scent Generator (`3:1`), Three-Valued Solver, Candidate Summary, NPC Trace Deflections & Codex Test/Metadata Fixes.
3. **Slice 3 (Landed)**: Upgraded Token/Scent Flavor (`28` tactile tokens + `56` bespoke scents + `~75%` `locations` weight + concise 3-line card text) + Additive Passer Second Trace (`0.45`) + Joint `(T1, T2)` / `(T2, T1)` Scene Solver & Two-Trace Pairing Readout.
4. **Slice 4 (Current PR)**: Scion Succession Timing Fix + Pressed-Trace Haunt Persistence Fix + Circumstantial Evidence Hub & Retractable Stage 2 Vibes (`+0.015 / +0.045`, smear backlash, `tools/test_workshop_circumstantial_hub.gd`).
5. **Slice 5 (Next)**: 15-Cast Voice Promotion, Autoplay Bot & 150-Seed Balance Sweep.