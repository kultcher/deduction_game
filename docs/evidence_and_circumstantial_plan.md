# Evidence Rework & Circumstantial Hub Plan

**Status:** Ready for focused vertical-slice prototype (`docs/evidence_and_circumstantial_plan.md`).
**Target Engine:** Godot 4.7.2 (GDScript).

This plan specifies two connected investigation and persuasion reworks for **Demonologist**, incorporating findings from the 200-seed feasibility audit and live Workshop code review:

1. **Multi-Category Crime-Scene Traces & Hidden Profile Receipts**: Replacing deterministic evening-block traces (`World._kill`) and main-board `"home"` / `"haunt"` clutter with a soft-worded (`3:1` LR) physical trace generator, hidden immutable profile receipts (`g.profile_receipts`), three-valued profile evaluation (`matches / contradicts / unknown`), joint two-trace scene evaluation, and a player-facing candidate narrowing summary.
2. **Circumstantial Evidence Hub (Stage 2 "Mob Mentality" Vibes)**: Adding a dedicated patina/sea-slate Workshop hub node (`+0.015` max per qualifying incident, `+0.045` global cap per listener/target across all active cases) that lets players push fence-sitters over the vote threshold using biased social framing while keeping `"is suspicious"` on standard Premise cards for the upcoming *Premises Matter* pass.

It absorbs or resolves these `BACKLOG.md` items:
- *Night movement and trace model* (fixing the evening-shift Demon vulnerability and retiring main-board `"home"` and `"haunt"` cards);
- *The Lamplighter contaminates vigils and traces* (turning passer trace overlap into a joint two-trace assignment puzzle);
- *Repeated trace matches add up* (compounding independent multi-night trace likelihoods in `CaseEval`);
- *Supporting evidence in a case: logical where possible, vibes where not* (separating Stage 1 world-filtering evidence from Stage 2 listener-biased social framing).

## 1. Settled Design & Calibration Decisions

- **Soft-worded `3:1` crime-scene traces across three physical/relational families (no forensic `demeanor`).** Physical crime scenes draw from **`locations`** (2-spot Work/Haunt), **`quarter`** (single unified Home-or-Evening block rule), and **conditional `connection`** (entered into the roll pool only when the killer actually shares a public bond, home block, or daytime location encounter with the victim, guaranteeing 100% generator feasibility across all town sizes and pairings). `demeanor` (personality traits) is excluded from forensic crime scenes so latch marks never pretend to prove `Composure`; observable traits and nerves remain usable in Stage 2 social arguments.
- **Ban duplicate clues, not whole families, to avoid passer meta-leaks.** Strict family exhaustion across nights would reveal which trace at a two-trace scene belongs to a passer whenever an earlier family reappears. Instead, `World._kill` bans repeating the **exact same clue predicate** within a case and biases toward fresh families (`3.0x` weight on unrolled families vs. `1.0x` on previously seen families), keeping two-trace attribution genuinely ambiguous.
- **Additive passer confound ("chance for extra, always the Demon's") with joint evaluation.** Remove the silent 40% overwrite in `World._kill`. When non-victim night-walkers cross the murder block, a roll (`Tuning.Setup.EXTRA_TRACE_CHANCE`, `0.45`) adds a second trace generated from one passing walker alongside the Demon's trace (shuffled order, distinct `fact_id` per slot `trace:<scene>:<slot>`). Rather than granting a flat subtraction bonus, the Workshop evaluator scores both joint assignments (`Demon -> T1, Passer -> T2` and `Demon -> T2, Passer -> T1`) under existing walker route, role, and credibility checks.
- **Prototype trace discrimination at `3:1` LR with soft wording.** Single-trace matching vs. contradicted Demon candidates start at a **`3:1` likelihood ratio** (comparing `1.5:1`, `2:1`, `3:1`, and `4:1` in bot A/B runs), paired with explicitly probabilistic wording (*"Residue near the threshold suggests someone tied to..."* rather than deterministic exclusion) and an explicit **Scion succession boundary** (a trace speaks only to who committed *that night's* murder, matching `chronology.gd` epochs rather than automatically transferring to a post-execution successor).
- **Hidden immutable Profile Receipts (`g.profile_receipts`) instead of main-board cards.** Learning a profile fact (`home`, `work`, a `haunt`, a dated `trait` tier, or a `bond`) creates a standard normalized receipt in `g.profile_receipts` with its own stable `id`, `source`, and `when` timestamp, bypassing `g.board` so the main Case Board stays clean. A **Townsfolk Profile Info** node in the Workshop indexes and cites the specific unlocked receipts selected when the case is filed: learning a second haunt later (or `_bereave` mutating a Lover's `Privacy`/`Gossip`/`Composure` mid-case) adds new dated receipts without silently mutating already-filed arguments.
- **Three-valued profile evaluation (`matches / contradicts / unknown`).** Knowing one of an NPC's two haunts (`Mill`) does *not* prove their second haunt isn't `Bakery`, and having no disclosed bond does *not* prove two people aren't close. Cited profile receipts evaluate to **`matches`** (`3:1` weight), **`contradicts`** (`1:1` baseline only when all slots for that category are accounted for, e.g. `work` + both `haunts` known), or **`unknown`** (neutral, preserving baseline prior weight).
- **Player-facing candidate summary without spoiling persuasion.** In the Case Workshop, combining traces and cited Profile/Sighting evidence displays a crisp investigative breakdown (**Compatible**, **Unresolved / Missing Info**, **Contradicted**, plus viable killer/passer pairings on two-trace scenes) while keeping listener persuasion uncertain because townsfolk hold private beliefs, relationships, and varying `Insight`.
- **Keep `"is suspicious"` on standard Premise cards; add dedicated `"Add Circumstantial Evidence"` hub.** Standard gold Premise cards retain `"is suspicious"` (`"suspicious"`) for the upcoming *Premises Matter* pass (`-suspicion`, `+pressure` relative to `"evil"`), removing only `"Supporting evidence (no claim)"`. The patina/sea-slate Circumstantial Hub (`#cde0dc` / `#7ea69f`, with an amber `"Needs a premise"` orphan badge) applies final post-modifier nudges up to **`+0.015` per qualifying incident** and **`+0.045` combined per listener/target across all active cases/hubs** (`1.0, 0.8, 0.6, 0.4, 0.2` diminishing weights), saturating in the real fence-sitter zone (`~0.35` target suspicion, `~0.55` player trust) and scaled down by `Insight` (`1.0x` at low Insight to `0.4x` at high Insight). Simply failing to persuade costs **`0` trust**; backlash (`-0.005 to -0.015`, keyed by semantic presentation identity) triggers only when pushing implausible/stretched links or smearing someone the listener actively trusts.

## 2. Updated Code Touchpoints

| Area | Files & Functions | Planned Change |
| :--- | :--- | :--- |
| **Hidden profile receipts** | `game/game.gd`, `game/game_board.gd`, `game/workshop_bridge.gd`, `game/workshop_canvas.gd`, `workshop/shared_ledger.gd`, `workshop/live_evidence.gd` | Retire `_home_cards` on `g.board` and `"haunt"` appends to `r["facts"]`. Store immutable `home`, `work`, `haunt`, dated `trait`, and `bond` receipts in `g.profile_receipts` (negative receipt numbers `-1, -2, ...` so they never collide with `1..N` board numbers), resolved alongside `g.board` in `WorkshopCanvas.supports`, `Bridge.capture`, and `SharedLedger.roots`. |
| **Profile UI & Workshop node** | `ui/profile_panel.gd`, `ui/trait_bars.gd`, `workshop/canvas_model.gd`, `ui/live_case_workshop.gd`, `ui/workshop_canvas_view.gd` | Add double-click and right-click (`Add to Case Workshop`) metadata links on Tab 0 (`Home & Work`, `Haunts`, `Bonds`) and `TraitBars` (`Personality`). Add `"Add Townsfolk Profile Info"` button, inline person switcher, 3px character-ink header accent, and receipt-backed facet chips. Remove `"Supporting evidence (no claim)"` from Premise dropdowns while keeping `"suspicious"`. |
| **Trace generator & identity** | `sim/world.gd` (`_kill`), `sim/mind.gd` (`fact_id`), `sim/tuning.gd` | Implement 100%-feasible `locations`, unified `quarter`, and conditional `connection` trace builders with soft probabilistic phrasing, non-duplicate clue history, weighted family draws, and `EXTRA_TRACE_CHANCE` (`0.45`) second passer trace. Key `fact_id` as `trace:<scene>:<slot>` so two-trace scenes never alias. |
| **Joint trace solver & preview** | `workshop/live_assessment.gd`, `workshop/live_activity.gd`, `workshop/case_eval.gd`, `game/workshop_canvas.gd` | Deduplicate by `trace:<scene>:<slot>`; evaluate `matches / contradicts / unknown` (`3:1` LR) from cited receipts only (never generator `match_ids`), scoped to the murder night's Demon epoch (Scion-safe). Score two-trace scenes across both `(T1, T2)` and `(T2, T1)` walker assignments, and expose Compatible / Unresolved / Contradicted candidate lists to the Workshop UI. |
| **Stage 2 circumstantial hub** | `workshop/canvas_model.gd`, `workshop/consequences.gd`, `game/workshop_ownership.gd`, `game/workshop_presentation.gd` | Add patina/sea-slate `"circumstantial"` hub node + `"Needs a premise"` orphan badge, strict eligibility criteria (neutral sightings score `0`), union-level semantic deduplication across all active presentations (`+0.015` item max, `+0.045` target cap, final applied), retractable `workshop_state.circumstantial_applied` vector, and semantic-keyed smear backlash (`-0.005` to `-0.015`). |
| **NPC reactions & disclosure** | `game/game.gd`, `sim/mind_dialogue.gd`, `sim/evil.gd`, `sim/dialogue_voices.gd` | Add deterministic simulation-approved haunt/prong disclosure helper (not the random `_maybe_tell_haunts` roll) for NPC deflection pointers, single-trace brush-offs, multi-trace frame-up denials, and minion Demon-protection prong selection. |

## 3. Hidden Profile Receipts & Three-Valued Contract

### 3.1 Receipt Lifecycle (`g.profile_receipts`)
- Each entry in `g.profile_receipts` uses the exact same dictionary contract as a `g.board` card, assigned a stable negative slot `n = -(g.profile_receipts.size() + 1)` so `WorkshopBridge._collect`, `WorkshopCanvas.supports`, and `SharedLedger.roots` can pass integer references in `supports: Array` without shifting or colliding with `1..N` board card numbers:
  - **`home` & `work` (minted at `new_case` setup, `day = 0, phase = 0`, `source = "town"`)**:
    - `{"kind": "home", "subject": [n.id], "block": n.home_block, "source": "town", "day": 0, "phase": 0, "text": "%s lives on %s." % [n.name, C.block_name(n.home_block)]}`
    - `{"kind": "work", "subject": [n.id], "loc": n.work, "block": w.loc_block(n.work), "work_phases": n.work_phases.duplicate(), "occupation": n.occupation, "source": "town", "day": 0, "phase": 0, "text": "%s works %s at %s." % [n.name, C.phase_list(n.work_phases), w.loc_name(n.work)]}`
  - **`haunt` (minted per newly learned location in `_maybe_tell_haunts` or deterministic deflection disclosure)**:
    - One receipt per individual haunt location `loc_id` (`{"kind": "haunt", "subject": [t.id], "loc": loc_id, "block": w.loc_block(loc_id), "source": speaker.id, "day": w.day, "phase": _phase_now(), ...}`). Splitting each haunt into its own atomic receipt means filing a case when 1 haunt is known snapshots *only* that 1 receipt; learning the 2nd haunt later mints a new receipt available in drafts without mutating the earlier filed case!
  - **`trait` (minted on trait reveal in `_maybe_tell_trait` / conversation end, dated to `when`)**:
    - `{"kind": "trait", "subject": [t.id], "trait": key, "tier": tier, "withdrawn": t.withdrawn_since != "", "source": speaker_or_player, "day": w.day, "phase": _phase_now(), ...}`. If `_bereave` later alters `privacy`, `gossip`, or `composure`, a later observation mints a new dated receipt rather than overwriting the earlier historical record.
  - **`bond` (minted in `_maybe_tell_relationships` and `_remember_spoken_relationship`)**:
    - `{"kind": "bond", "subject": people.duplicate(), "bond_kind": bond.kind, "source": source, "day": w.day, "phase": _phase_now(), ...}`.

### 3.2 Workshop Profile Node (`kind = "profile_info"`)
- Node schema on `CanvasModel`:
  `{"id": "pi:%d" % serial, "kind": "profile_info", "person": npc_id, "facets": ["home_work"], "receipt_ids": [...], "at": [x, y]}`
- Whenever the player toggles a facet chip (`Home & Work`, `Haunts`, `Personality`, `Bonds`) or swaps `person` in the draft editor, `CanvasModel` refreshes `receipt_ids` to the normalized IDs of the currently unlocked `g.profile_receipts` matching `(person, facets)`.
- Once filed via `WorkshopCanvas.file`, those exact `receipt_ids` are frozen into `card.workshop_case.cards`, preserving historical immutability.

### 3.3 Three-Valued Evaluation (`matches / contradicts / unknown`)
For any trace predicate `T` and candidate `X`, the evaluator inspects **only the receipts included in the active Workshop case / listener view** (never hidden `NPC` fields or generator `match_ids`):
- **`locations` (`loc_a` or `loc_b` via Work or Haunt)**:
  - `matches`: Cited `work` receipt or cited `haunt` receipt for `X` is in `{loc_a, loc_b}`.
  - `contradicts`: Cited `work` receipt for `X` is not in `{loc_a, loc_b}` **AND** `X` has **2 distinct cited `haunt` receipts**, neither in `{loc_a, loc_b}` (since every townsperson has 1 workplace and 2 haunts).
  - `unknown`: Fewer than 2 `haunt` receipts are cited and nothing cited matches yet.
- **`quarter` (`home_block == B_home` OR `evening_block(night) == B_ev`)**:
  - `matches`: Cited `home` receipt has `block == B_home`, OR a cited/accepted `evening` sighting on `night` places `X` on `B_ev`.
  - `contradicts`: Cited `home` receipt has `block != B_home` **AND** a cited/accepted `evening` sighting on `night` places `X` on a block `!= B_ev` (or `X`'s cited `work` shift forces `X` onto another block that evening).
  - `unknown`: `home_block != B_home` and `X`'s evening block on `night` is unestablished.
- **`connection` (Bond with `victim`, `home_block == victim.home_block`, or daytime encounter with `victim` on `day`)**:
  - `matches`: Cited `bond` receipt links `X` and `victim`, OR cited `home` receipt puts `X` on `victim.home_block`, OR cited daytime `sighting`/`conversation` pairs `X` and `victim` on `day`.
  - `unknown` / soft non-match: Because undisclosed bonds or unseen daytime overlaps can exist, absence of a positive match when `home_block != victim.home_block` applies only a partial non-match discount (`1.5:1` instead of full `3:1`) unless full daytime whereabouts rule out an encounter.

## 4. Joint Scene Trace Model & Candidate Readout

### 4.1 100%-Feasible Trace Generation (`World._kill`)
- **Eligible families for `(actor, victim)`**:
  - `locations`: Always eligible (`1,800 / 1,800` valid in audit). Picks `1` spot from `[actor.work] + actor.haunts` and `1` decoy spot from the remaining 7 town locations, preferring decoys whose cast match count lands in `[6, 8]` at 10 NPCs (`[4, 5]` at 7 NPCs), with graceful fallback to the closest match count if none hits the band.
  - `quarter`: Always eligible. Single canonical predicate: *"Mud and residue near the threshold suggest someone who either lives on `<B_home>` or spent yesterday evening on `<B_ev>`."* (When `loc_block(actor_ev) == actor.home_block`, pick a second block `B_decoy != actor.home_block` and randomly assign `(B_home, B_ev)` as `(actor.home_block, B_decoy)` or `(B_decoy, actor_ev)` so the single predicate always holds.)
  - `connection`: Eligible **only when** `actor` actually has a public bond with `victim` (`w.town_relationships`), lives on `victim.home_block`, or shared a location with `victim` on `day`. When eligible, pairs `bond(X, victim)` with `home_block == victim.home_block` (or daytime overlap with `victim`).
- **Selection without replacement of exact clues**: Filter out any candidate clue whose canonical `(family, prongs)` key already spawned earlier in the case; weight families not yet used by the Demon at `3.0x` vs. `1.0x` for previously used families.

### 4.2 `3:1` Likelihoods, Joint Two-Trace Assignments & Scion Epoch
- **Murderer identity (`killer_idx`)**: In `CaseEval` / `LiveActivity`, a trace on `crime_night` binds to whoever was the Demon **on `crime_night`** (`TimeModel` original Demon before any Scion promotion, or current Demon if no `>= 5`-alive Demon execution intervened).
- **Single-trace scene (`T1`)**: Relative Demon weight for candidate `d` is `w_match(d, T1)` where `matches -> 3.0`, `unknown -> 1.6`, `contradicts -> 1.0` (giving an exact **`3:1`** ratio between matching and contradicted candidates, and keeping unknown-profile candidates near the prior average).
- **Two-trace scene (`T1, T2`)**:
  - Let `W_pass` be the plausibility-weighted match score of non-Demon night-walkers on `scene_block` for trace `T` (combining any cited/credited walker `w != d` whose route crosses `scene_block` with a baseline unattributed-passer background weight).
  - Joint scene likelihood for Demon candidate `d` averages both assignments:
    `L(d | T1, T2) = 0.5 * (w_match(d, T1) * W_pass(T2, d) + w_match(d, T2) * W_pass(T1, d))`
  - Notice how naturally this behaves: if Constance (Night Watch on `scene_block`) matches *only* `T2`, `W_pass(T2, d)` rises and `T1` cleanly focuses on `d`; if Constance matches *both* `T1` and `T2`, both assignments rise symmetrically without falsely pretending we know which clue Constance left; and explaining a passer restores single-trace `3:1` sharpness rather than inventing an artificial `11:1` spike.

### 4.3 Player-Facing Candidate Narrowing Summary
- On the Workshop canvas / preview panel (`WorkshopCanvas.trace_summary`), compute and display a deterministic, listener-independent summary of what the **currently linked Trace + Profile + Sighting cards** establish across the town:
  - **Fits all cited traces**: list of names;
  - **Unresolved (missing haunts, whereabouts, or bonds)**: list of names + what info is missing;
  - **Pushed against by cited profiles**: list of names (and on two-trace scenes, both viable `Killer / Passer` assignments).
- Listener agreement percentages are **never** shown up front before presenting; social buy-in stays uncertain.

## 5. Stage 2 Circumstantial Evidence Hub Calibration

### 5.1 Eligibility Criteria (Strict Relevance)
A card wired into a patina/sea-slate `"circumstantial"` hub (`#cde0dc` / `#7ea69f`) supporting an accusing Premise on `target` qualifies **only** if it represents a genuinely suggestive incident (ordinary daytime sightings or neutral chatter score **`0.0`**):
1. **Hostile political action by `target`**: `vote` where `target` voted YES on `other` (or NO on a confirmed/hanged evil `other`), or `accusation` / `opinion` by `target` attacking `other`.
2. **Suspicious association or proximity**: `conversation` or off-work `sighting` pairing `target` with a proven-evil NPC or with a townsperson silenced that day (`Breathstealer` proximity), or uncorroborated `refusal` / `withheld` reading by `target`.
3. **Contradicted / nervous behaviour**: caught whereabouts/alibi discrepancy or logged low-Composure pressure tell not already scored in Stage 1 on the same target.

### 5.2 Final Post-Modifier Numbers & Global Union Cap
Evaluated once across the **union of all active endorsed circumstantial incidents** held by listener `L` against `target` (preventing multi-hub or multi-case stacking, and skipping any `fact_id` already owned by Stage 1 alignment/movement factors):
- **Receptiveness (`0..1`)**:
  - `trust_ramp = clampf((L.trust - 0.15) / 0.40, 0.0, 1.0)` *(reaches `1.0` at `0.55` player trust)*
  - `susp_ramp = clampf((S_target - 0.08) / 0.27, 0.0, 1.0)` *(reaches `1.0` at `0.35` target suspicion, right in the fence-sitter zone)*
  - `insight_scale = lerpf(1.0, 0.4, Mind.trait_of(L, "insight"))`
- **Relational Multiplier (`rel_mod` in `[0.0, 1.0]`)**:
  - Hostile act against `other`: `clampf(0.55 + 0.65 * (L.npc_trust.get(other, 0.5) - 0.5) - 0.55 * Mind.susp(L, other), 0.0, 1.0)`.
  - Association with / defence of `other`: `clampf(0.25 + 0.85 * Mind.susp(L, other), 0.0, 1.0)`.
  - Solo refusal / silence proximity: `0.75`.
- **Final Applied Delta (No Post-Scaling by Confidence or Venue)**:
  - Each incident's score is `0.015 * trust_ramp * susp_ramp * insight_scale * rel_mod` (hard ceiling **`+0.015`** per incident, reduced to `0.006` at max `Insight`).
  - Sort qualifying incidents strongest-first, apply weights **`[1.0, 0.8, 0.6, 0.4, 0.2]`**, and clamp the sum to **`+0.045`** total across all active cases for `(L, target)`.
  - Stored on `L.workshop_state.circumstantial_applied[target]` and retracted cleanly before every refresh, withdrawal, or shared-model toggle.
- **Selective Framing & Smear Backlash**:
  - Listeners judge only what they know; omitting an innocent explanation is a valid social gamble unless the listener independently knows the omitted clear.
  - Simply finding a plausible circumstantial point unconvincing costs **`0` trust**.
  - Backlash (`-0.005 to -0.015`, keyed by semantic `(target, incident_fact_ids)` so moving canvas nodes never re-triggers it) applies **only** when: (a) `L == target` (being piled on to their face), (b) the player attaches ineligible/irrelevant filler cards (`rel_mod == 0.0`), or (c) `S_target < 0.12` while `L.npc_trust.get(target, 0.5) >= 0.65` (muckraking against someone `L` actively trusts with zero real grounds).

## 6. Vertical-Slice Rollout & Validation Plan

Because headless Godot tests (`tools/run_gd_tests.py`) run locally and on PR review, we build and verify in **five vertical slices**, stopping after Slice 1 to confirm green tests before layering trace RNG changes:

1. **Slice 1 (Foundation): Hidden Profile Receipts, Board Cleanup & Workshop Profile Node**
   - Implement `g.profile_receipts` (`home`, `work`, atomic `haunt`, dated `trait`, `bond`), retire main-board `"home"` and `"haunt"` cards, and extend `WorkshopCanvas.supports`, `WorkshopBridge.capture`, `SharedLedger.roots`, and `LiveEvidence` to resolve negative profile receipt numbers alongside `g.board`.
   - Add Profile Panel / `TraitBars` double-click & right-click shortcuts, the `"Add Townsfolk Profile Info"` Workshop button/node (parchment + portrait + inline person switcher + character accent + unlocked facet chips), and remove `"Supporting evidence (no claim)"` from Premise dropdowns (retaining `"suspicious"`).
   - Update `test_fixes.gd` and `test_ui.gd` for retired main-board `"home"`/`"haunt"` cards and add `tools/test_workshop_profile_receipts.gd` (testing receipt immutability across later haunt reveals and Lover `_bereave` trait shifts).
   - **Stop & Run Tests** (`test_workshop_profile_receipts`, `test_fixes`, `test_ui`, `test_town_ui`, `test_board`, `replay_54875`).

2. **Slice 2: Single-Trace Multi-Category Generator (`3:1`), Solver Adapter & Candidate Summary**
   - Implement `locations`, unified `quarter`, and conditional `connection` in `World._kill` (single trace first, banning duplicate predicates, soft probabilistic wording), `trace:<scene>:<slot>` identities, `matches / contradicts / unknown` (`3:1` LR, Scion-safe epoch), and the Workshop Compatible / Unresolved / Contradicted candidate readout.
   - Add deterministic simulation-approved NPC deflection disclosures and minion Demon-protection guardrails (`[PH]` strings).
   - **Stop & Run Tests** (200-seed generator feasibility check + `test_workshop_profile_traces` + `test_npc_interactions`).

3. **Slice 3: Additive Passer Second Trace & Joint `(T1, T2)` / `(T2, T1)` Scene Model**
   - Enable `EXTRA_TRACE_CHANCE` (`0.45`) second passer trace in `World._kill` and joint two-trace walker assignment in `LiveActivity` / `CaseEval` + two-trace pairing preview.
   - **Stop & Run Tests** (ambiguous-walker tests where Night Watch matches one vs. both clues + `profile_case_eval_town.gd` latency check).

4. **Slice 4: Circumstantial Evidence Hub & Retractable Stage 2 Vibes**
   - Add `"Add Circumstantial Evidence"` patina/sea-slate hub node + `"Needs a premise"` badge, strict incident eligibility, union-level `+0.015 / +0.045` evaluation, `workshop_ownership.gd` retraction, and semantic smear backlash.
   - **Stop & Run Tests** (`test_workshop_circumstantial` covering neutral-card zeroing, duplicate hubs/cases, withdrawal, and rival baseline safety).

5. **Slice 5: 15-Cast Voice Promotion, Autoplay Bot & 150-Seed Balance Sweep**
   - Replace `[PH]` trace/circumstantial lines with 15-character voiced variants in `sim/dialogue_voices.gd`, teach `tools/autoplay.gd` to cite profile receipts with traces, and compare `1.5:1 / 2:1 / 3:1` trace weights across 150 paired seeds (recording living candidate counts, wrongful executions, trust losses, and presentation latency).