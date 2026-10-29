# Evidence Rework & Circumstantial Hub Plan

**Status:** All 5 slices + Stage 1/Stage 2 boundary & Codex fixes implemented (`docs/evidence_and_circumstantial_plan.md`), ready for playtest and 150-seed balance sweep.
**Target Engine:** Godot 4.7.2 (GDScript).

This plan specifies two connected investigation and persuasion reworks for **Demonologist**, incorporating findings from the 200-seed feasibility audit, the 20,000-seed token/scent combinatorics sweep, Slice 2-5 playtest and Codex review feedback, and live Workshop code audits:

1. **Multi-Category Crime-Scene Traces & Hidden Profile Receipts**: Replacing deterministic evening-block traces (`World._kill`) and main-board `"home"` / `"haunt"` clutter with a soft-worded (`3:1` LR) physical trace generator featuring **28 tactile 2-spot Trade Tokens and 56 bespoke 3-spot Lingering Scents (`67% / 33%` mix with a non-subset guard)** alongside tangible Quarter tokens and domestic Victim-Connection staging, hidden immutable profile receipts (`g.profile_receipts`), three-valued profile evaluation (`matches / contradicts / unknown`), additive passer second traces with joint `(T1, T2)` / `(T2, T1)` scene evaluation, exact Scion pre/post-execution night splits, and persistent haunt recording across both bare and pressed trace confrontations.

2. **Circumstantial Evidence Hub (Stage 2 "Mob Mentality" Vibes)**: Adding a dedicated patina/sea-slate Workshop hub node (`+0.015` max per qualifying incident, `+0.045` global cap per listener/target across all active cases) that lets players push fence-sitters over the vote threshold using listener-dependent social framing while routing hard logical/movement evidence (including contradicted night alibis) exclusively through Stage 1, scoring testimony refusals (with the `0.25 / 0.35` fear discount) exclusively in Stage 2, preserving both Stage 1 and Stage 2 owned layers across native suspicion adjustments (`Mind.adjust`), and keeping `"is suspicious"` on standard Premise cards for the upcoming *Premises Matter* pass.

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

* **Exact Scion Succession Timing, Pressed-Trace Haunt Persistence & Breathstealer Public-Only Rule.**

  * **Scion Epoch Boundary (`workshop/live_activity.gd`)**: Because `World.execute` runs at Day `exec_day` Evening (`tick = exec_day * 4 + 2`) and promotes the Scion via `_scion_rises` *before* `resolve_night()` runs Night `exec_day` (`tick = exec_day * 4 + 3`), pre-takeover nights belonging to the hanged original Demon are strictly `0 <= night < exec_day`, while post-takeover nights belonging to the Scion start on **that execution day's night** (`night >= exec_day`), with `alive_demon_mask` checking `History.alive_at_night(view, p.id, exec_day)`.

  * **Trace Confrontation Haunt Saving (`game/game.gd`, `sim/mind.gd`, `sim/mind_dialogue.gd`)**: `Mind.press` forwards `known_haunts` into `react_to_trace` (preferring not-yet-known matching haunts when deflecting), and `Game._talk_command` persists `r.get("profile_haunts", [])` into both `known_haunts` and `add_profile_receipt({"kind": "haunt", ...})` across all conversation verbs (`trace_ask`, `press`, and `confront`).

  * **Breathstealer Public-Location Constraint (`sim/roles/breathstealer.gd`, `workshop/circumstantial.gd`)**: Neither the Breathstealer nor their target may be inside a private home (`not bs.at_home()` and `not m.at_home()`). Stage 2 Breathstealer proximity therefore requires either a witnessed daytime conversation with the silenced victim or witnessed public sightings placing both on the same block in the same daytime slot, never a home-block assumption.

* **Dedicated `"Add Circumstantial Evidence"` Hub, Clean Stage 1 / Stage 2 Split & Native Adjustment Preservation (Slices 4-5).**

  * **Strict Stage 1 vs. Stage 2 Evidence Boundary**:
    * **Contradicted Night Alibis -> Stage 1 Only**: Caught night-alibi contradictions (`alibi` + night `sighting` or `disputes`) are hard logical movement evidence (`2.33:1` in `LiveActivity`) and award `0.0` in Stage 2 even if wired through a Circumstantial Hub.
    * **Refusals -> Stage 2 Only (with `0.25 / 0.35` Fear Discount)**: Because good townsfolk have legitimate reasons to withhold testimony in a social deduction game, `SpeechEvidence.factors` emits zero Stage 1 weight for `refusal` cards; instead, Stage 2 scores `refusal` on `target` at `INCIDENT_MAX` (`+0.015`) when unafraid and `INCIDENT_MAX * (0.25 / 0.35)` (`~+0.0107`) when `fear` is `true`, taking `maxf` across days so repeated reluctance never stacks.
    * **Trace-Context Non-Double-Dip Guards**: Profile `rival` bonds already backing a cited `connection` trace on the same victim and `evening` sightings already backing a cited `quarter` trace on that evening block stay in Stage 1 (`3:1`) without paying a second Stage 2 bonus.

  * **Evidence-Driven Channel Routing**: Cards wired into a `"circumstantial"` hub still flow into `result.cards` so Stage 1 (`CaseEval` / `LiveActivity` / `SpeechEvidence`) evaluates logical and movement evidence identically regardless of how the player wires the canvas. Players never lose Stage 1 credit by organizing supporting material through the hub.

  * **Patina / Sea-Slate Hub Node (`#cde0dc` / `#7ea69f`)**: Displays a `"Needs a premise"` chip when unlinked, validates non-empty inputs and accusatory target premises (`evil`, `demon`, `minion`, `suspicious`) when compiled, and supports roster-independent JSON export/restore (`CanvasModel.restore`), undo, and context-menu removal.

  * **Stage 2 Union Evaluation (`+0.015` Incident Max, `+0.045` Target Cap)**: Evaluated once on the frozen post-Stage-1 snapshot (never iterating, never feeding Stage 1 priors), gated by specific Stage 1 grounding above town-wide public-event survivor redistribution (`gate = clampf((maxf(0.0, specific_stage1 - 0.01) + 0.35 * maxf(0.0, outside - 0.15)) / 0.06, 0.0, 1.0)`), deduplicated across all active cases per `(listener, target, incident_key)`, and stored in a separately retractable `workshop_state.circumstantial_requested` / `circumstantial_applied` vector.

  * **Stage 2 Preservation Across Native Adjustments (`sim/mind.gd`, `sim/mind_meeting.gd`)**: `Mind.adjust` rebuilds active Workshop listeners' stored suspicion as `outside + state.requested.get(target_id, 0.0) + state.get("circumstantial_requested", {}).get(target_id, 0.0)` so native suspicion deltas (such as execution grief or social shifts) never drop the active Stage 2 layer or corrupt `state.outside` on the next ownership refresh, and `MindMeeting.reason_status` includes `circumstantial_requested` when checking whether an NPC's combined Workshop case reaches public-reason strength.

  * **Semantic Smear Backlash (`-0.005` to `-0.015`)**: Presenting a hub padded with unrelated non-target cards or pure vibes without Stage 1 backing (`gate == 0.0`) triggers a one-time trust penalty (`-0.005` to `-0.015`) per presentation signature, whereas genuine target-involving social reads (such as `"talking with suspected evil"`) simply yield `0.0` sway with zero backlash on listeners who think the conversation partner is good.

* **15-Cast Voice Pass & Workshop-Capable Autoplay Harness (Slice 5).**

  * **Bespoke 15-Cast Voices (`sim/dialogue_voices.gd`, `sim/mind_dialogue.gd`, `game/workshop_presentation.gd`)**: All `[PH]` trace reaction, haunt/work/quarter/connection deflection, multi-trace frame-up denial, and Stage 2 Circumstantial Hub addendum lines (`trace_fit_locations`, `trace_fit_quarter`, `trace_fit_connection`, `trace_not_me`, `trace_point_haunt`, `trace_point_work`, `trace_point_quarter`, `trace_point_connection`, `pressed_multi_trace_case`, `circumstantial_hub_landed`, and `circumstantial_smear_pushback`) are promoted across all 15 cast voices while preserving canonical `statement` metadata.

  * **Workshop-Capable Autoplay Bot & Adjusted Readiness Metrics (`tools/autoplay.gd`, `tools/autoplay_workshop.gd`)**: `_scores()` incorporates structured crime-scene traces and discovered profile receipts (`work`, `haunts`, `home`, `bonds`), `_scale_snapshot()` measures `could-nominate` against exact adjusted nomination scores (`action_susp - own_clear - nomination_cooloff` on non-silenced minds), and `_build_workshop_case()` assembles full `CanvasModel` cases pairing Stage 1 reports, two-trace scenes, night-walker sightings, `Townsfolk Profile Info` nodes, and verified Stage 2 `Circumstantial Evidence` hubs (with `--no-workshop-cases` and `--no-hub` flags for controlled 150-seed A/B sweeps).

## 2. Updated Code Touchpoints

| Area | Files & Functions | Status & Change |
| ----- | ----- | ----- |
| **Hidden profile receipts & UI** | `game/game.gd`, `game/game_board.gd`, `ui/profile_panel.gd`, `ui/trait_bars.gd`, `workshop/canvas_model.gd`, `ui/live_case_workshop.gd` | **Landed (Slices 1-2 + Codex Fix)**: `g.profile_receipts` (`-10001..`), retired main-board `"home"`/`"haunt"` cards, `Townsfolk Profile Info` node, `prior_links` cleanup on deletion, roster-independent `CanvasModel.restore`. |
| **Token/Scent flavor, passer 2nd trace & Breathstealer** | `sim/content.gd`, `sim/tuning.gd`, `sim/world.gd` (`_kill`), `sim/roles/breathstealer.gd`, `sim/mind_dialogue.gd`, `sim/argue.gd` | **Landed (Slices 3-5 + Codex Fixes)**: 28 `TRACE_TOKENS`, 56 `TRACE_SCENTS`, `~75%` `locations` weight, `EXTRA_TRACE_CHANCE` (`0.45`) shuffled 2nd passer trace, public-location-only Breathstealer targeting (`not m.at_home()`), discovered-receipt-only `Argue.trace_fit_from_receipts`, and pressed-trace `profile_haunts` persistence. |
| **Joint `(T1, T2)` scene solver & Scion timing** | `workshop/live_assessment.gd`, `workshop/live_activity.gd`, `game/workshop_canvas.gd` | **Landed (Slices 3-4)**: Scene-level joint factor (`L_scene`), `crossing_probability`, walker-pairing summary, and exact Scion succession night split (`night < exec_day` vs. `night >= exec_day`). |
| **Stage 2 circumstantial hub, refusals & ownership** | `workshop/circumstantial.gd`, `workshop/speech_evidence.gd`, `workshop/factored_channels.gd`, `workshop/canvas_model.gd`, `workshop/live_assessment.gd`, `workshop/shared_ledger.gd`, `workshop/jury.gd`, `game/workshop_ownership.gd`, `game/workshop_presentation.gd`, `game/workshop_canvas.gd`, `sim/mind.gd`, `sim/mind_meeting.gd`, `ui/live_case_workshop.gd`, `ui/workshop_canvas_view.gd`, `ui/workshop_drawer.gd` | **Landed (Slices 4-5 + Boundary Pass)**: Patina/sea-slate `"circumstantial"` hub node, Stage 2-only fear-discounted refusals (`0.25 / 0.35`), Stage 1-only contradicted night alibis, audience-dependent `"talking with suspected evil"`, trace-context non-double-dip guards, union-level `+0.015 / +0.045` evaluation, retractable ownership vector preserved across `Mind.adjust`, and smear backlash. |
| **15-cast voice pass & balance sweep** | `sim/dialogue_voices.gd`, `sim/mind_dialogue.gd`, `game/workshop_presentation.gd`, `tools/autoplay.gd`, `tools/autoplay_workshop.gd`, `tools/test_workshop_slice5_voices_and_bot.gd` | **Landed (Slice 5 + Codex Fixes)**: 11 bespoke trace/hub voice keys across all 15 cast voices, adjusted nomination readiness (`could-nominate`), adapted-card hub selector (`autoplay_workshop.gd`), and `tools/test_workshop_slice5_voices_and_bot.gd`. |

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

## 4. Stage 2 Circumstantial Evidence Hub Specification (Slices 4-5 + Boundary Pass)

1. **Qualifying Incident Families (`workshop/circumstantial.gd`)**:

   * **Breathstealer Public Proximity (`breath_prox:<target>:<day>`)**: Public `silenced` event on `day` for `victim != target` paired with a witnessed daytime `conversation` with `victim` (`"Spoke with..."`) or witnessed public sightings placing `target` and `victim` on the same block in the same daytime slot (`"Seen on <block> in the same <phase> slot..."`), weighted by `1.0 - post_stage1_susp(victim)`. Because the Breathstealer cannot target anyone inside their home (`not m.at_home()`), mere presence on a silenced victim's home block without a public co-sighting never qualifies. Evening sightings already corroborating a cited `quarter` trace on that evening block stay Stage 1 only.

   * **Suspicious Association / Talking with Suspected Evil (`assoc:<target>:<partner>`)**: Daytime/evening `conversation` or `friend` profile bond between `target` and `partner != target` where the listener already suspects `partner` (`post_stage1_susp(partner) >= 0.32`), judged strictly by the listener's beliefs about `partner` rather than `target`. Listeners who think `partner` is good (`< 0.32` or `known_good`) award `0.0` sway without treating the genuine `target` conversation as unrelated smear padding.

   * **Hostile Vote or Nomination Against Trusted Soul (`hostile_vote:<target>:<day>:<nominee>`)**: Public `vote` receipt where `target` nominated or voted yes against `nominee != target` whom the listener considers proven good or strongly trusted (`post_stage1_susp(nominee) <= 0.28` and `npc_trust(nominee) >= 0.45`).

   * **Victim Rivalry (`victim_rival:<target>:<victim>`)**: Profile `rival` bond between `target` and a public `demon_death` `victim`, weighted by `1.0 - post_stage1_susp(victim)`, skipped whenever the case already cites a Stage 1 `connection` trace for `victim`.

   * **Demeanor / Evasiveness Tell (`demeanor_tell:<target>`)**: Stage 2-only `refusal` receipt on `target` (`INCIDENT_MAX` when unafraid, discounted by `0.25 / 0.35` when `fear` is `true`, non-stacking across days) or `trait` receipt showing `low` Composure / `high` Privacy when paired with Stage 1 scrutiny. Contradicted night alibis remain strictly Stage 1 (`LiveActivity`).

2. **Stage 1 Grounding Gate, Caps & Retractable Ownership**:

   * **Single-Pass Gate**: Subtracts town-wide passive survivor redistribution (`passive_floor` across living non-cleared peers with no arbitrary `0.06` ceiling and a `0.01` geometry-jitter deadband) so public deaths and silences alone never unlock vibes: `gate = clampf((maxf(0.0, specific_stage1 - 0.01) + 0.35 * maxf(0.0, outside - 0.15)) / 0.06, 0.0, 1.0)`.

   * **Caps**: Each distinct `(target, incident_key)` across the listener's active non-withdrawn presentations contributes at most `+0.015`, and the union sum per `(listener, target)` is capped at `+0.045` (zeroed if `target` is the listener or `known_good`).

   * **Retractable Storage & Native Delta Safety**: `WorkshopOwnership` retracts both `state.requested` and `state.circumstantial_requested` in `phase == "before"` before Stage 1 `CaseEval` runs, `Mind.adjust` preserves `outside + requested + circumstantial_requested` whenever a native suspicion adjustment lands while Workshop ownership is active, and `workshop_retract` or `set_workshop_effects(false)` cleanly restores the exact pre-case baseline plus intervening external deltas.

3. **Semantic Smear Backlash**:

   * Presenting a hub that pads the case with unrelated non-target cards (`specific_stage1 < 0.02` or zero qualifying incidents) or pushes pure vibes (`gate == 0.0`) applies a one-time trust penalty in `[-0.015, -0.005]` (`CIRCUMSTANTIAL_SMEAR_MIN` to `CIRCUMSTANTIAL_SMEAR_MAX`) keyed by presentation signature.

## 5. 150-Seed Balance Sweep Commands (Slice 5)

Run these headless commands in Godot 4.7.2 to compare passive baseline, Stage-1-only Workshop cases (`--no-hub`), and full Stage 1 + Stage 2 Circumstantial Hub play across identical 150-seed sequences:

* **Passive town baseline**:
  `godot --headless --path . --script res://tools/autoplay.gd -- --seed 1 --games 150 --npcs 7 --passive --no-trace --results logs/sweep_passive.json`

* **Active bot (Stage 1 Workshop + Traces + Profiles, no Circumstantial Hub)**:
  `godot --headless --path . --script res://tools/autoplay.gd -- --seed 1 --games 150 --npcs 7 --no-hub --no-trace --results logs/sweep_stage1.json`

* **Active bot (Full Stage 1 Workshop + Stage 2 Circumstantial Hub)**:
  `godot --headless --path . --script res://tools/autoplay.gd -- --seed 1 --games 150 --npcs 7 --no-trace --results logs/sweep_full.json`

## 6. Vertical-Slice Rollout Status

1. **Slice 1 (Landed)**: Hidden Profile Receipts (`g.profile_receipts`), Board Cleanup & Workshop `Townsfolk Profile Info` Node.

2. **Slice 2 (Landed)**: Single-Trace Token/Scent Generator (`3:1`), Three-Valued Solver, Candidate Summary, NPC Trace Deflections & Codex Test/Metadata Fixes.

3. **Slice 3 (Landed)**: Upgraded Token/Scent Flavor (`28` tactile tokens + `56` bespoke scents + `~75%` `locations` weight + concise 3-line card text) + Additive Passer Second Trace (`0.45`) + Joint `(T1, T2)` / `(T2, T1)` Scene Solver & Two-Trace Pairing Readout.

4. **Slice 4 (Landed)**: Scion Succession Timing Fix + Pressed-Trace Haunt Persistence Fix + Circumstantial Evidence Hub & Retractable Stage 2 Vibes (`+0.015 / +0.045`, smear backlash, `tools/test_workshop_circumstantial_hub.gd`).

5. **Slice 5 + Tuning & Codex Pass (Landed)**: `Mind.adjust` Stage 2 Layer Preservation Fix + 15-Cast Voice Promotion + Nomination/Cooloff/Evil Readiness Tuning + Stage 2-Only Fear-Discounted Refusals + Stage 1-Only Contradicted Alibis + Public-Only Breathstealer Targeting + Discovered-Receipt-Only `Argue` Trace Checks + Roster-Independent `CanvasModel.restore`.