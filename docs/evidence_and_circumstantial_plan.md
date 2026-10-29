# Evidence Rework & Circumstantial Hub Plan

**Status:** Slice 1 landed; Slice 2 active (`docs/evidence_and_circumstantial_plan.md`).
**Target Engine:** Godot 4.7.2 (GDScript).

This plan specifies two connected investigation and persuasion reworks for **Demonologist**, incorporating findings from the 200-seed feasibility audit, the 20,000-seed token/scent combinatorics sweep, and live Workshop code review:

1. **Multi-Category Crime-Scene Traces & Hidden Profile Receipts**: Replacing deterministic evening-block traces (`World._kill`) and main-board `"home"` / `"haunt"` clutter with a soft-worded (`3:1` LR) physical trace generator featuring **2-spot Trade Tokens and 3-spot Lingering Scents (`67% / 33%` mix with a non-subset guard)** alongside unified Quarter and Victim-Connection traces, hidden immutable profile receipts (`g.profile_receipts`), three-valued profile evaluation (`matches / contradicts / unknown`), joint two-trace scene evaluation, and a player-facing candidate narrowing summary.
2. **Circumstantial Evidence Hub (Stage 2 "Mob Mentality" Vibes)**: Adding a dedicated patina/sea-slate Workshop hub node (`+0.015` max per qualifying incident, `+0.045` global cap per listener/target across all active cases) that lets players push fence-sitters over the vote threshold using biased social framing while keeping `"is suspicious"` on standard Premise cards for the upcoming *Premises Matter* pass.

It absorbs or resolves these `BACKLOG.md` items:

* *Night movement and trace model* (fixing the evening-shift Demon vulnerability and retiring main-board `"home"` and `"haunt"` cards);
* *The Lamplighter contaminates vigils and traces* (turning passer trace overlap into a joint two-trace assignment puzzle);
* *Repeated trace matches add up* (compounding independent multi-night trace likelihoods in `CaseEval`);
* *Supporting evidence in a case: logical where possible, vibes where not* (separating Stage 1 world-filtering evidence from Stage 2 listener-biased social framing).

## 1. Settled Design & Calibration Decisions

* **Soft-worded `3:1` crime-scene traces across three physical/relational families (no forensic `demeanor`).** Physical crime scenes draw from **`locations`** (diegetic **2-spot Trade Tokens** and **3-spot Lingering Scents** mapped onto `Work + 2 Haunts`), **`quarter`** (single unified Home-or-Evening block rule), and **conditional `connection`** (entered into the roll pool only when the actor actually shares a public bond, home block, or daytime location encounter with the victim, guaranteeing 100% generator feasibility across all town sizes and pairings). `demeanor` (personality traits) is excluded from forensic crime scenes so latch marks never pretend to prove `Composure`; observable traits and nerves remain usable in Stage 2 social arguments.
* **`67%` 2-Spot Trade Tokens / `33%` 3-Spot Lingering Scents with a Non-Subset Guard.** Across 20,000 simulated 10-NPC towns, pure 2-spot location clues leave `3` or fewer suspects by Day 2 in `22.2%` of games, whereas blending **`67%` 2-spot Trade Tokens** (e.g., *grease-darkened brass farthing* from the bakery or tavern) with **`33%` 3-spot Lingering Scents** (e.g., *hearth-smoke* from the smithy, bakery, or tavern) and banning any new location set that is a subset or superset of a previously rolled location clue hits **`7.28` left after 1 clue** (eliminates `2.72`), **`5.31` left after 2 clues** (eliminates `4.69`), and **`3.90` left after 3 clues**, while cutting Day 2 spiky solves nearly in half (`13.4%`). Both Demon and passer traces use the same `2:1` token-to-scent ratio so clue width never leaks which trace on a two-trace scene belongs to the killer.
* **Ban duplicate clues and subset overlaps, not whole families, to avoid passer meta-leaks.** Strict family exhaustion across nights would reveal which trace at a two-trace scene belongs to a passer whenever an earlier family reappears. Instead, `World._kill` bans repeating the **exact same clue predicate** (and subset/superset location sets) within a case and biases toward fresh families (`3.0x` weight on unrolled families vs. `1.0x` on previously seen families), keeping two-trace attribution genuinely ambiguous.
* **Additive passer confound ("chance for extra, always the Demon's") with joint evaluation.** Remove the silent 40% overwrite in `World._kill`. When non-victim night-walkers cross the murder block, a roll (`Tuning.Setup.EXTRA_TRACE_CHANCE`, `0.45`, enabled in Slice 3) adds a second trace generated from one passing walker alongside the Demon's trace (shuffled order, distinct `fact_id` per slot `trace:<scene>:<slot>`). Rather than granting a flat subtraction bonus, the Workshop evaluator scores both joint assignments (`Demon -> T1, Passer -> T2` and `Demon -> T2, Passer -> T1`) under existing walker route, role, and credibility checks.
* **Prototype trace discrimination at `3:1` LR with soft wording.** Single-trace matching vs. contradicted Demon candidates start at a **`3:1` likelihood ratio** (`matches = 3.0`, `unknown = 1.6`, `contradicts = 1.0`), paired with explicitly probabilistic wording that names the associated places directly on the card (*"A smell of hearth-smoke clings to the latch, common around the smithy, the bakery, or the Drowned Lamb tavern"*) so players deduce from town profiles rather than memorizing an item wiki, plus an explicit **Scion succession boundary** (a trace binds to whoever was the active killer on *that murder night* rather than falsely clearing a post-execution Scion successor).
* **Hidden immutable Profile Receipts (`g.profile_receipts`) instead of main-board cards.** Learning a profile fact (`home`, `work`, a `haunt`, a dated `trait` tier, or a `bond`) creates a standard normalized receipt in `g.profile_receipts` using disjoint negative slots (`-10001, -10002, ...` via `PROFILE_RECEIPT_BASE = 10000` so they never collide with `1..N` board numbers or synthetic `-1` draft roots). A **Townsfolk Profile Info** node in the Workshop indexes and cites the specific unlocked receipts selected when the case is filed: learning a second haunt later (or `_bereave` mutating a Lover's `Privacy`/`Gossip`/`Composure` mid-case) adds new dated receipts without silently mutating already-filed arguments.
* **Three-valued profile evaluation (`matches / contradicts / unknown`).** Knowing one of an NPC's two haunts (`Mill`) does *not* prove their second haunt isn't `Bakery`, and having no disclosed bond does *not* prove two people aren't close. Cited profile receipts evaluate to **`matches`** (`3.0`), **`contradicts`** (`1.0` only when all slots for that category are accounted for, e.g. `work` + both `haunts` known), or **`unknown`** (`1.6`, preserving near-prior baseline weight).
* **Player-facing candidate summary without spoiling persuasion.** In the Case Workshop, combining traces and cited Profile/Sighting evidence displays a crisp investigative breakdown (**Fits cited traces**, **Unresolved / Missing Info**, **Pushed against (`3:1`)**) while keeping listener persuasion uncertain because townsfolk hold private beliefs, relationships, and varying `Insight`.
* **Keep `"is suspicious"` on standard Premise cards; add dedicated `"Add Circumstantial Evidence"` hub.** Standard gold Premise cards retain `"is suspicious"` (`"suspicious"`) for the upcoming *Premises Matter* pass (`-suspicion`, `+pressure` relative to `"evil"`), removing only `"Supporting evidence (no claim)"`. The patina/sea-slate Circumstantial Hub (`#cde0dc` / `#7ea69f`, with an amber `"Needs a premise"` orphan badge) applies final post-modifier nudges up to **`+0.015` per qualifying incident** and **`+0.045` combined per listener/target across all active cases/hubs** (`1.0, 0.8, 0.6, 0.4, 0.2` diminishing weights), saturating in the real fence-sitter zone (`~0.35` target suspicion, `~0.55` player trust) and scaled down by `Insight` (`1.0x` at low Insight to `0.4x` at high Insight). Simply failing to persuade costs **`0` trust**; backlash (`-0.005 to -0.015`, keyed by semantic presentation identity) triggers only when pushing implausible/stretched links or smearing someone the listener actively trusts.

## 2. Updated Code Touchpoints

| Area | Files & Functions | Planned Change |
| :--- | :--- | :--- |
| **Hidden profile receipts (Landed in Slice 1)** | `game/game.gd`, `game/game_board.gd`, `game/workshop_bridge.gd`, `game/workshop_canvas.gd`, `workshop/shared_ledger.gd`, `workshop/live_evidence.gd` | Retire `_home_cards` on `g.board` and `"haunt"` appends to `r["facts"]`. Store immutable `home`, `work`, `haunt`, dated `trait`, and `bond` receipts in `g.profile_receipts` (`-10001, -10002, ...`), resolved alongside `g.board` in `WorkshopCanvas.supports`, `Bridge.capture`, and `SharedLedger.roots`. |
| **Profile UI & Workshop node (Landed in Slice 1 + Codex Fix)** | `ui/profile_panel.gd`, `ui/trait_bars.gd`, `workshop/canvas_model.gd`, `ui/live_case_workshop.gd`, `ui/workshop_canvas_view.gd` | Double-click and right-click (`Add to Case Workshop`) metadata links on Tab 0 and `TraitBars`; `"Add Townsfolk Profile Info"` node; clean `prior_links` filtering on `remove_profile_info` so unmerging contradictions never restores edges to deleted profile nodes. |
| **Token/Scent catalog & trace generator (Slice 2)** | `sim/content.gd`, `sim/world.gd` (`_kill`), `sim/mind.gd` (`fact_id`), `sim/tuning.gd` | Add 28 bespoke 2-spot Trade Tokens and curated 3-spot Lingering Scents in `sim/content.gd`. Implement 100%-feasible `locations` (`67%` 2-spot token / `33%` 3-spot scent, non-subset guard), unified `quarter`, and conditional `connection` trace builders in `World._kill`, keying `fact_id` as `trace:<scene>:<slot>`. |
| **Three-valued `3:1` solver & preview (Slice 2)** | `workshop/live_assessment.gd`, `workshop/live_activity.gd`, `workshop/case_eval.gd`, `game/workshop_canvas.gd`, `ui/live_case_workshop.gd` | Normalize `profile_home`, `profile_work`, `profile_haunt`, `profile_bond`, and structured `trace` cards; evaluate `matches / contradicts / unknown` (`3:1` LR) from cited receipts only, scoped to the murder night's active killer epoch (Scion-safe); expose Compatible / Unresolved / Contradicted candidate summary in Workshop UI. |
| **NPC trace reactions & minion guardrail (Slice 2)** | `game/game.gd`, `game/game_presentation.gd`, `sim/mind.gd`, `sim/mind_dialogue.gd`, `sim/argue.gd` | Route bare `present <trace#>` to `Mind.react_to_trace`: single-trace brush-offs, deterministic simulation-approved haunt/location deflection pointers that never volunteer `w.demon_id` when spoken by a Minion, multi-trace frame-up denials on pressed cases, and structured `Argue` templates. |
| **Additive passer 2nd trace & joint model (Slice 3)** | `sim/world.gd`, `workshop/live_activity.gd`, `game/workshop_canvas.gd` | Enable `EXTRA_TRACE_CHANCE` (`0.45`) second passer trace in `World._kill` and joint `(T1, T2)` / `(T2, T1)` walker assignment scoring + two-trace pairing preview. |
| **Stage 2 circumstantial hub (Slice 4)** | `workshop/canvas_model.gd`, `workshop/consequences.gd`, `game/workshop_ownership.gd`, `game/workshop_presentation.gd` | Add patina/sea-slate `"circumstantial"` hub node + `"Needs a premise"` orphan badge, strict eligibility criteria, union-level `+0.015 / +0.045` evaluation, retractable `workshop_state.circumstantial_applied` vector, and semantic-keyed smear backlash. |

## 3. Hidden Profile Receipts & Three-Valued Contract

### 3.1 Receipt Lifecycle (`g.profile_receipts`)

* Each entry in `g.profile_receipts` uses the exact same dictionary contract as a `g.board` card, assigned a stable negative slot `n = -(10000 + g.profile_receipts.size() + 1)` (`-10001, -10002, ...`) so synthetic `-1` draft roots and `1..N` board numbers stay completely disjoint while `WorkshopBridge._collect`, `WorkshopCanvas.supports`, and `SharedLedger.roots` pass integer references in `supports: Array`:
  * **`home` & `work` (minted at `new_case` setup, `day = 0, phase = 0`, `source = "town"`)**:
    * `{"kind": "home", "subject": [n.id], "block": n.home_block, "source": "town", "day": 0, "phase": 0, "text": "%s lives on %s." % [n.name, C.block_name(n.home_block)]}`
    * `{"kind": "work", "subject": [n.id], "loc": n.work, "block": w.loc_block(n.work), "work_phases": n.work_phases.duplicate(), "occupation": n.occupation, "source": "town", "day": 0, "phase": 0, "text": "%s works %s at %s." % [n.name, C.phase_list(n.work_phases), w.loc_name(n.work)]}`
  * **`haunt` (minted per newly learned location in `_maybe_tell_haunts` or deterministic trace deflection disclosure)**:
    * One atomic receipt per individual haunt location `loc_id` (`{"kind": "haunt", "subject": [t.id], "loc": loc_id, "locs": [loc_id], "block": w.loc_block(loc_id), "source": speaker.id, "day": w.day, "phase": _phase_now(), ...}`).
  * **`trait` (minted on trait reveal in `_maybe_tell_trait` / conversation end, dated to `when`)**:
    * `{"kind": "trait", "subject": [t.id], "trait": key, "tier": tier, "withdrawn": t.withdrawn_since != "", "source": speaker_or_player, "day": w.day, "phase": _phase_now(), ...}`.
  * **`bond` (minted in `_maybe_tell_relationships` and `_remember_spoken_relationship`)**:
    * `{"kind": "bond", "subject": people.duplicate(), "bond_kind": bond.kind, "source": source, "day": w.day, "phase": _phase_now(), ...}`.

### 3.2 Workshop Profile Node (`kind = "profile_info"`)

* Node schema on `CanvasModel`:
  `{"id": "pi:%d" % serial, "kind": "profile_info", "person": npc_id, "facets": ["home_work"], "receipt_ids": [...], "at": [x, y]}`
* Removing a `profile_info` node cleans up both active `links` and any saved `prior_links` on `"contradiction"` and `"modifier"` nodes so `unmerge()` never restores dangling links to deleted profile nodes.

### 3.3 Three-Valued Evaluation (`matches / contradicts / unknown`)

For any structured trace predicate `T` and candidate `X`, the evaluator inspects **only the receipts included in the active Workshop case / listener view** (never hidden `NPC` fields or generator `match_ids`):

* **`locations` (`locs` of 2 Trade-Token locations or 3 Lingering-Scent locations)**:
  * `matches` (`3.0`): Cited `work` receipt or cited `haunt` receipt for `X` is in `locs`.
  * `contradicts` (`1.0`): Cited `work` receipt for `X` is not in `locs` **AND** `X` has **2 distinct cited `haunt` receipts**, neither in `locs` (all 3 habitual spots accounted for).
  * `unknown` (`1.6`): Fewer than 2 `haunt` receipts are cited (or `work` is uncited) and nothing cited matches yet.
* **`quarter` (`home_block == B_home` OR `evening_block(night) == B_ev`)**:
  * `matches` (`3.0`): Cited `home` receipt has `block == B_home`, OR a cited/accepted `evening` sighting (or cited evening `work` shift) on `night` places `X` on `B_ev`.
  * `contradicts` (`1.0`): Cited `home` receipt has `block != B_home` **AND** a cited/accepted `evening` sighting (or cited evening `work` shift) on `night` places `X` on a block `!= B_ev`.
  * `unknown` (`1.6`): `home` is uncited or `X`'s evening block on `night` is unestablished.
* **`connection` (Bond with `victim`, `home_block == victim_block`, or daytime encounter with `victim` on `day`)**:
  * `matches` (`3.0`): Cited `bond` receipt links `X` and `victim`, OR cited `home` receipt puts `X` on `victim_block`, OR cited daytime `sighting`/`conversation` pairs `X` and `victim` on `day`.
  * `contradicts` / soft non-match (`1.5`, or `1.0` when home != `victim_block` and full daytime sightings exclude `victim` overlap): Because undisclosed bonds or unseen daytime overlaps can exist, absence of a positive match when `home_block != victim_block` applies a gentler `2:1` discount unless daytime whereabouts also rule out an encounter.

## 4. Joint Scene Trace Model & Candidate Readout

### 4.1 100%-Feasible Trace Generation (`World._kill`)

* **Eligible families for `(actor, victim)`**:
  * `locations` (base family weight `2.0`): Always eligible. Draws **2-spot Trade Token (`67%`)** vs. **3-spot Lingering Scent (`33%`)**. Picks `1` spot from `[actor.work] + actor.haunts` and `1` or `2` decoy spots from the remaining 7 town locations, filtering out any location set `S` that is a subset or superset of an earlier location trace (`S <= prev_S` or `prev_S <= S`) and preferring sets sharing at most `1` location with earlier traces. Every card names the concrete token/scent and spells out the 2 or 3 associated locations directly in its text.
  * `quarter` (base family weight `1.0`): Always eligible. Single canonical predicate: *"Tracks near the threshold suggest someone who either lives on `<B_home>` or spent the evening of day `<day>` on `<B_ev>`."* (When `loc_block(actor_ev) == actor.home_block`, picks a decoy block `B_decoy != actor.home_block` and randomly orders `(actor.home_block, B_decoy)` vs. `(B_decoy, loc_block(actor_ev))`.)
  * `connection` (base family weight `1.0`): Eligible **only when** `actor` actually has a public bond with `victim` (`w.town_relationships`), lives on `victim.home_block`, or shared a location with `victim` on `day`.
* **Selection without replacement of exact clues**: Filters out any candidate clue whose canonical `(family, trace_key)` already spawned in `w.case_traces`; multiplies unrolled families by `3.0x` vs. `1.0x` for previously rolled families.

### 4.2 `3:1` Likelihoods, Joint Two-Trace Assignments & Scion Epoch

* **Murderer identity (`killer_idx`)**: On `crime_night`, a trace binds to whoever was the active Demon on `crime_night`. If a world's designated `world.demon` was publicly executed before `crime_night` (Scion succession), the surviving evil teammate (`world.evil`) acts as killer for `crime_night`; conversely, if an evil teammate was executed with `alive_before >= 5` *after* `crime_night`, pre-execution traces blend across pre-succession evil Demon assignments so a legitimate Scion successor is never falsely hard-cleared by the original Demon's Night 1 trace.
* **Single-trace scene (`T1`, Slice 2)**: Relative Demon weight for candidate `d` is `w_match(d, T1)` (`matches -> 3.0`, `unknown -> 1.6`, `contradicts -> 1.0`), giving an exact **`3:1`** ratio between matching and contradicted candidates while keeping legacy block-material fixture traces (`not data.has("family")`) on their original fixture likelihood formula.
* **Two-trace scene (`T1, T2`, Slice 3)**: Joint scene likelihood averages `(Demon -> T1, Passer -> T2)` and `(Demon -> T2, Passer -> T1)` against non-Demon walker plausibility `W_pass`.

### 4.3 Player-Facing Candidate Narrowing Summary

* `WorkshopCanvas.trace_summary(g, value)` computes and displays a deterministic, listener-independent breakdown whenever structured traces are linked into the selected case:
  * **Fits cited traces**: townsfolk matching every cited trace;
  * **Unresolved (missing profile/whereabouts)**: townsfolk with at least one `unknown` trace check and zero `contradicts`, noting which facet or evening is still missing;
  * **Pushed against (`3:1`)**: townsfolk contradicted on one or more cited traces.
* Listener agreement percentages are **never** shown before presenting.

## 5. Stage 2 Circumstantial Evidence Hub Calibration

### 5.1 Eligibility Criteria (Strict Relevance)

A card wired into a patina/sea-slate `"circumstantial"` hub (`#cde0dc` / `#7ea69f`) supporting an accusing Premise on `target` qualifies **only** if it represents a genuinely suggestive incident (ordinary daytime sightings or neutral chatter score **`0.0`**):

1. **Hostile political action by `target`**: `vote` where `target` voted YES on `other` (or NO on a confirmed/hanged evil `other`), or `accusation` / `opinion` by `target` attacking `other`.
2. **Suspicious association or proximity**: `conversation` or off-work `sighting` pairing `target` with a proven-evil NPC or with a townsperson silenced that day (`Breathstealer` proximity), or uncorroborated `refusal` / `withheld` reading by `target`.
3. **Contradicted / nervous behaviour**: caught whereabouts/alibi discrepancy or logged low-Composure pressure tell not already scored in Stage 1 on the same target.

### 5.2 Final Post-Modifier Numbers & Global Union Cap

* **Receptiveness (`0..1`)**: `trust_ramp = clampf((L.trust - 0.15) / 0.40, 0.0, 1.0)`, `susp_ramp = clampf((S_target - 0.08) / 0.27, 0.0, 1.0)`, `insight_scale = lerpf(1.0, 0.4, Mind.trait_of(L, "insight"))`.
* **Final Applied Delta**: `0.015 * trust_ramp * susp_ramp * insight_scale * rel_mod` (`+0.015` max/item), sorted strongest-first with weights `[1.0, 0.8, 0.6, 0.4, 0.2]` and clamped to **`+0.045`** total across all active cases for `(L, target)`, stored retractably on `L.workshop_state.circumstantial_applied[target]`.
* **Smear Backlash**: `0` trust loss for unconvincing plausible points; `-0.005` to `-0.015` (keyed by semantic `(target, incident_fact_ids)`) only when piling on `L == target`, attaching irrelevant filler (`rel_mod == 0.0`), or muckraking against someone `L` actively trusts (`>= 0.65`) when `S_target < 0.12`.

## 6. Vertical-Slice Rollout & Validation Plan

1. **Slice 1 (Landed): Hidden Profile Receipts, Board Cleanup & Workshop Profile Node**
   * `g.profile_receipts` (`-10001..`), retired main-board `"home"`/`"haunt"` cards, `ProfilePanel`/`TraitBars` Workshop shortcuts, `"Add Townsfolk Profile Info"` node, Premise dropdown cleanup, and `test_workshop_profile_receipts.gd`.
2. **Slice 2 (Current PR): Codex `prior_links` Fix + Single-Trace Token/Scent Generator (`3:1`), Three-Valued Solver & NPC Deflections**
   * Clean `prior_links` when removing `profile_info` nodes (`workshop/canvas_model.gd`).
   * Add 2-spot Trade Token (`67%`) & 3-spot Lingering Scent (`33%`, non-subset guard) catalog in `sim/content.gd`, plus unified `quarter` and conditional `connection` in `World._kill` (`trace:<scene>:<slot>` identities).
   * Implement three-valued `matches / contradicts / unknown` (`3:1` LR, Scion-safe epoch) in `LiveAssessment` / `LiveActivity`, Workshop Compatible / Unresolved / Pushed-Against candidate summary, structured `Argue` templates, and deterministic simulation-approved `[PH]` NPC trace reactions with minion Demon-protection guardrails.
   * **Stop & Run Tests** (`test_workshop_profile_receipts`, `test_workshop_profile_traces`, `test_fixes`, `test_workshop_live_activity`, `test_workshop_remaining`, `replay_54875`).
3. **Slice 3: Additive Passer Second Trace & Joint `(T1, T2)` / `(T2, T1)` Scene Model**
   * Enable `EXTRA_TRACE_CHANCE` (`0.45`) second passer trace in `World._kill` and joint two-trace walker assignment in `LiveActivity` / `CaseEval` + two-trace pairing preview.
4. **Slice 4: Circumstantial Evidence Hub & Retractable Stage 2 Vibes**
   * Add `"Add Circumstantial Evidence"` patina/sea-slate hub node + `"Needs a premise"` badge, strict incident eligibility, union-level `+0.015 / +0.045` evaluation, `workshop_ownership.gd` retraction, and semantic smear backlash.
5. **Slice 5: 15-Cast Voice Promotion, Autoplay Bot & 150-Seed Balance Sweep**
   * Replace `[PH]` trace/circumstantial lines with 15-character voiced variants in `sim/dialogue_voices.gd`, teach `tools/autoplay.gd` to cite profile receipts with traces, and compare `1.5:1 / 2:1 / 3:1` trace weights across 150 paired seeds.