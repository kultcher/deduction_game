# Evidence Rework & Circumstantial Hub Plan

**Status:** Slices 1 & 2 landed; Slice 3 active (`docs/evidence_and_circumstantial_plan.md`).
**Target Engine:** Godot 4.7.2 (GDScript).

This plan specifies two connected investigation and persuasion reworks for **Demonologist**, incorporating findings from the 200-seed feasibility audit, the 20,000-seed token/scent combinatorics sweep, Slice 2 playtest feedback, and live Workshop code review:

1. **Multi-Category Crime-Scene Traces & Hidden Profile Receipts**: Replacing deterministic evening-block traces (`World._kill`) and main-board `"home"` / `"haunt"` clutter with a soft-worded (`3:1` LR) physical trace generator featuring **28 tactile 2-spot Trade Tokens and 56 bespoke 3-spot Lingering Scents (`67% / 33%` mix with a non-subset guard)** alongside tangible Quarter tokens and domestic Victim-Connection staging, hidden immutable profile receipts (`g.profile_receipts`), three-valued profile evaluation (`matches / contradicts / unknown`), additive passer second traces with joint `(T1, T2)` / `(T2, T1)` scene evaluation, and a player-facing candidate & walker-pairing summary.
2. **Circumstantial Evidence Hub (Stage 2 "Mob Mentality" Vibes)**: Adding a dedicated patina/sea-slate Workshop hub node (`+0.015` max per qualifying incident, `+0.045` global cap per listener/target across all active cases) that lets players push fence-sitters over the vote threshold using biased social framing while keeping `"is suspicious"` on standard Premise cards for the upcoming *Premises Matter* pass.

It absorbs or resolves these `BACKLOG.md` items:

* *Night movement and trace model* (fixing the evening-shift Demon vulnerability and retiring main-board `"home"` and `"haunt"` cards);
* *The Lamplighter contaminates vigils and traces* (turning passer trace overlap into a joint two-trace assignment puzzle);
* *Repeated trace matches add up* (compounding independent multi-night trace likelihoods in `CaseEval`);
* *Supporting evidence in a case: logical where possible, vibes where not* (separating Stage 1 world-filtering evidence from Stage 2 listener-biased social framing).

## 1. Settled Design & Calibration Decisions

* **Tactile Trade Tokens & Lingering Scents as the Primary Trace Backbone (`~75%` of Crime Scenes).** Slice 2 playtesting revealed that a `3.0x` fresh-family multiplier pushed `quarter` and `connection` to `50%` on Night 1 and `75%` on Night 2, drowning out the new tokens and scents with old block-residue wording. Setting `TRACE_LOCATIONS_BASE_WEIGHT = 3.5` (vs. `0.65` each for `quarter` and `connection`, with a gentle `1.25x` fresh-family nudge) ensures **`~72–78%` of crime scenes produce tangible Trade Tokens or Lingering Scents**, while `quarter` and `connection` also receive concrete physical objects and domestic staging (stamped quarter tokens, drawn bolts, two pewter cups) rather than generic residue strings.
* **Complete Bespoke Catalog (`28` Trade Tokens + `56` Lingering Scents) & Concise 3-Line Card Copy.** All `\binom{8}{2} = 28` location pairs map to concrete pocket/trade objects (coins, tallies, thimbles, candle-spikes, boat-rivets, rosaries; zero dirt/loam filler), and all `\binom{8}{3} = 56` location triples map to cohesive shared scents that fit every named location. Card text is formatted concisely (`<= 105` chars) so 3-line Workshop canvas nodes display the full item/scent and all associated places without truncating.
* **`67%` 2-Spot Trade Tokens / `33%` 3-Spot Lingering Scents with a Non-Subset Guard.** Blending `67%` 2-spot tokens with `33%` 3-spot scents and banning subset/superset location sets hits **`7.28` left after 1 clue**, **`5.31` left after 2 clues**, and **`3.90` left after 3 clues`**, while both Demon and passer traces draw from the exact same `2:1` ratio so clue width never leaks killer vs. passer identity.
* **Additive Passer Confound ("Chance for Extra, Always the Demon's") with Joint `(T1, T2)` / `(T2, T1)` Evaluation (Slice 3).** When non-victim night-walkers cross `v.home_block`, `World._kill` rolls `EXTRA_TRACE_CHANCE` (`0.45`) to generate a second non-duplicate, non-subset trace from a passing walker alongside the Demon's trace, shuffles their presentation order (`50/50`), and assigns `trace_slot = 0, 1` *after* shuffling so slot order never leaks which trace is the Demon's. Each card records `scene_trace_count` (`1` or `2`): citing only one card from a two-trace scene blends `0.5 * w(d, T1) + 0.5 * E_pass(T1)` (preventing cherry-picking), whereas citing both `(T1, T2)` scores both joint assignments `0.5 * (w(d, T1) * E_pass(T2) + w(d, T2) * E_pass(T1))` weighted by each non-Demon townsperson's route-crossing probability on `scene_block`.
* **Three-Valued Profile Evaluation (`matches = 3.0`, `unknown = 1.6`, `contradicts = 1.0`) & Scion Epoch Boundary.** Knowing 1 of 2 haunts stays `unknown` (`1.6`) rather than `contradicts` (`1.0`), and pre-execution traces blend cleanly across Scion succession splits when an execution occurred with `alive_before >= 5`.
* **Keep `"is suspicious"` on Standard Premise Cards; Add Dedicated `"Add Circumstantial Evidence"` Hub (Slice 4).** Patina/sea-slate hub (`#cde0dc` / `#7ea69f`) with `"Needs a premise"` orphan badge, `+0.015` max per qualifying incident, `+0.045` global union cap per `(listener, target)`, retractable `workshop_state.circumstantial_applied` storage, and semantic smear backlash (`-0.005` to `-0.015`).

## 2. Updated Code Touchpoints

| Area | Files & Functions | Status & Change |
| :--- | :--- | :--- |
| **Hidden profile receipts & UI** | `game/game.gd`, `game/game_board.gd`, `ui/profile_panel.gd`, `ui/trait_bars.gd`, `workshop/canvas_model.gd`, `ui/live_case_workshop.gd` | **Landed (Slices 1–2)**: `g.profile_receipts` (`-10001..`), retired main-board `"home"`/`"haunt"` cards, `Townsfolk Profile Info` node, `prior_links` cleanup on deletion. |
| **Token/Scent flavor & passer 2nd trace** | `sim/content.gd`, `sim/tuning.gd`, `sim/world.gd` (`_kill`) | **Slice 3**: Upgrade all 28 `TRACE_TOKENS` to tactile objects, add all 56 bespoke `TRACE_SCENTS`, give `quarter` & `connection` physical/domestic flavor, boost `locations` weight to `~75%`, and enable `EXTRA_TRACE_CHANCE` (`0.45`) shuffled 2nd passer trace with post-shuffle `trace_slot` and `scene_trace_count`. |
| **Joint `(T1, T2)` / `(T2, T1)` scene solver & pairing readout** | `workshop/live_assessment.gd`, `workshop/live_activity.gd`, `game/workshop_canvas.gd`, `ui/live_case_workshop.gd` | **Slice 3**: Move structured scene traces to a dedicated scene-level joint factor (`L_scene`) scoring single-trace (`3:1`), partial two-trace (`0.5 * killer + 0.5 * passer`), and full two-trace (`0.5 * (T1*P2 + T2*P1)`) assignments using night route-crossing probabilities `cross_prob`, plus viable `(Killer / Passer)` pairing lines in `WorkshopCanvas.trace_summary`. |
| **Stage 2 circumstantial hub** | `workshop/canvas_model.gd`, `workshop/consequences.gd`, `game/workshop_ownership.gd`, `game/workshop_presentation.gd` | **Slice 4**: Patina/sea-slate `"circumstantial"` hub node, strict incident eligibility, union-level `+0.015 / +0.045` evaluation, retraction, and smear backlash. |
| **15-cast voice pass & balance sweep** | `sim/dialogue_voices.gd`, `tools/autoplay.gd` | **Slice 5**: Promote `[PH]` trace/circumstantial lines to 15 cast voices, teach `autoplay.gd` to pair profile + walker + trace receipts, and run 150-seed A/B balance sweep. |

## 3. Joint Two-Trace Scene Math (Slice 3)

For each murder scene `S` on `night` (`victim` at `scene_block`):

1. **Per-Person Route Crossing Probability (`cross_prob[j][align]`)**:
   * Under `LiveActivity._profile_paths` and `_observed` (excluding scene traces so movement is never double-counted), compute for each `j != victim` and `align in {"good", "minion", "converted"}` the normalized probability `cross_prob[j][align] in [0.0, 1.0]` that `j` walked a valid night path containing `scene_block` on `night`.
   * Sighted walkers on `scene_block` (or Night Watch `seen` entries / Warden guards at `scene_block` / Lamplighter tours) have `cross_prob ≈ 1.0`; unchallenged home alibis or Night Watch omissions on `scene_block` have `cross_prob = 0.0`; unobserved townsfolk retain small background walking rates (`~0.06` good, `~0.12` minion).
2. **Expected Passer Trace Weight (`E_pass(T, world, d)`)**:
   * Given world `(evil, d)`, let `Z = eps + sum_{j != d, victim} cross_prob[j][align_j]` (`eps = 0.05` background floor for unmodeled/edge walks) and:
     `E_pass(T, world, d) = (eps * 1.6 + sum_{j != d, victim} cross_prob[j][align_j] * w_match(j, T)) / Z`
3. **Scene Likelihood Factor (`L_scene(world, d)`)**:
   * **Single-trace scene (`scene_trace_count == 1`, `T1` cited)**:
     `L_scene(world, d) = w_match(d, T1)`
   * **Two-trace scene with only one trace `T1` cited (`scene_trace_count == 2`, `1` cited)**:
     `L_scene(world, d) = 0.5 * w_match(d, T1) + 0.5 * E_pass(T1, world, d)`
   * **Two-trace scene with both `T1, T2` cited (`scene_trace_count == 2`, `2` cited)**:
     `L_scene(world, d) = 0.5 * (w_match(d, T1) * E_pass(T2, world, d) + w_match(d, T2) * E_pass(T1, world, d))`
   * **Properties**:
     * Explaining `T2` via a sighted Night Watch / walker who matches `T2` (`3.0`) and contradicts `T1` (`1.0`) sharply boosts `E_pass(T2) -> 3.0` over `E_pass(T1) -> 1.0`, focusing `T1` back onto the Demon without inventing an artificial `11:1` spike.
     * When a sighted walker matches *both* `T1` and `T2` (`3.0, 3.0`), `E_pass(T1) == E_pass(T2)` stays completely symmetric, never pretending to know which clue the walker left.
     * Compatible with Scion succession splits (`exec_idx` pre-execution killer vs. `d_idx` post-execution Scion).

## 4. Vertical-Slice Rollout Status

1. **Slice 1 (Landed)**: Hidden Profile Receipts (`g.profile_receipts`), Board Cleanup & Workshop `Townsfolk Profile Info` Node.
2. **Slice 2 (Landed)**: Single-Trace Token/Scent Generator (`3:1`), Three-Valued Solver, Candidate Summary, NPC Trace Deflections & Codex Test/Metadata Fixes.
3. **Slice 3 (Current PR)**: Upgraded Token/Scent Flavor (`28` tactile tokens + `56` bespoke scents + `~75%` `locations` weight + concise 3-line card text) + Additive Passer Second Trace (`0.45`) + Joint `(T1, T2)` / `(T2, T1)` Scene Solver & Two-Trace Pairing Readout (`tools/test_workshop_two_traces.gd`).
4. **Slice 4 (Next)**: Circumstantial Evidence Hub & Retractable Stage 2 Vibes (`+0.015 / +0.045`).
5. **Slice 5**: 15-Cast Voice Promotion, Autoplay Bot & 150-Seed Balance Sweep.