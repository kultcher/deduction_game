# Evidence Rework & Circumstantial Hub Plan

**Status:** Design locked; ready for phased implementation (`docs/evidence_and_circumstantial_plan.md`).
**Target Engine:** Godot 4.7.2 (GDScript).

This plan formalizes two tightly connected reworks for **Demonologist**:
1. **Multi-Category Crime-Scene Traces & Townsfolk Profile Info**: Replacing deterministic evening-block traces (`World._kill`) and scattered `"home"` / `"haunt"` board cards with a four-family physical/behavioral clue generator and on-demand **Townsfolk Profile Info** Workshop nodes.
2. **Circumstantial Evidence Hub (Stage 2 "Mob Mentality" Vibes)**: Adding a dedicated greenish-blue Workshop hub node that evaluates soft behavioral/relational cards by listener disposition, social bonds, and `Insight`, while preserving `"is suspicious"` on standard Premise cards for the upcoming *Premises Matter* pass.

It absorbs or resolves these `BACKLOG.md` items:
- *Night movement and trace model* (specifically fixing the evening-shift Demon vulnerability and evaluating whether `"home"` and `"haunt"` board cards still earn their place);
- *The Lamplighter contaminates vigils and traces* (turning passer trace overlap into a solvable subtraction puzzle);
- *Repeated trace matches add up* (compounding independent multi-night trace likelihoods in `CaseEval`);
- *Supporting evidence in a case: logical where possible, vibes where not* (Stage 1 logical evaluation vs. Stage 2 gated impressions).

## 1. Settled Design Decisions

- **Roll one trace family per murder without replacement.** Each Demon kill draws from a pool of four orthogonal factor families (`Work & Haunt Locations`, `Personality / Demeanor Tier`, `Home & Evening Quarter`, and `Victim Bond & Turf`) so consecutive murders never repeat the same clue axis and narrow a 10-person town by roughly **2 to 3 candidates per clue** (**4 to 6 remaining** across two independent clues).
- **Additive passer confound ("chance for extra, always the Demon's").** Remove the silent 40% trace overwrite in `World._kill`. When one or more non-victim night-walkers cross the murder block, a single roll (`Tuning.Setup.EXTRA_TRACE_CHANCE`, default `0.45`) adds a **second trace drawn from one passing walker's profile** alongside the Demon's trace (capped at 2 traces per crime scene, presented in shuffled order). The Demon's true trace is always at the scene; identifying a legitimate night-walker on that block lets the player subtract the extra trace.
- **Keep profiles off the main Case Board.** Stop generating the 10 opening `"home"` cards (`GameBoard._home_cards`) and gossip `"haunt"` cards (`Game._maybe_tell_haunts`) on the main board. Instead, profile categories in `ui/profile_panel.gd` (`Home & Work`, `Haunts`, `Personality`, `Bonds`) become double-clickable and right-clickable (`Add to Case Workshop`), paired with an **"Add Townsfolk Profile Info"** button inside the Case Workshop.
- **Profile Info nodes behave as normal Stage 1 factual evidence.** They use the standard Evidence parchment palette (`#e8dfc8` body, `#c4b185` header) with the subject's circular portrait, an inline person-switcher dropdown, a thin character-ink accent rule under the header, and toggleable facet chips unlocked only as the player learns them. Because townsfolk already know their neighbors' habits and observable traits once pointed out, presented Profile facets act as player-investigation gates rather than fragile hearsay chains.
- **Keep `"is suspicious"` on standard Premise cards; remove `"Supporting evidence (no claim)"`.** Standard gold Premise cards keep `"is suspicious"` (`"suspicious"`) so the upcoming *Premises Matter* pass can treat it as a lower-bar claim than `"is evil"` (reduced suspicion shift, higher `+pressure` modifier). Only the claimless `"Supporting evidence (no claim)"` option is removed from Premise dropdowns.
- **Dedicated `"Add Circumstantial Evidence"` hub node.** Spawns a patina/sea-slate node (`#cde0dc` body, `#7ea69f` header) with no stated premise of its own and an amber `"Needs a premise"` header chip whenever it is not linked into a proper Premise card. Cards wired into this hub are scored by Stage 2 vibes (`~0.03 to 0.04` max per item, hard-capped around `0.10` for the whole hub) using listener trust in the player, existing suspicion of the target, `Insight`, and relationship trust/suspicion toward secondary named parties. Listeners who do not buy in penalize player trust (`-0.02 to -0.04`) for sloppy, mob-mentality detective work.
- **Strict Stage 1 / Stage 2 deduplication.** A single underlying `fact_id` cannot pay out twice on the same Premise: if a card is already evaluated logically in Stage 1 for that Premise, any duplicate routing through the Circumstantial hub contributes `0.0` (and flags an idle-link note in the Workshop UI).
- **Safe NPC reactions and minion haunt guardrails.** Single traces trigger casual deflection (`"Half the town stops by the bakery"`), while multi-trace cases trigger forceful denials or accusations of a frame-up. When suggesting other townsfolk who fit a trace, NPCs never fabricate false haunts: good NPCs name a genuine match they already suspect, while minions cherry-pick a genuine townsperson who matches the *other* prong of the clue (or matches the passer's second trace) and withhold haunt disclosures when asked about their Demon.

## 2. Current Code Touchpoints

| Area | Files & Functions | Current Behavior & Planned Change |
| :--- | :--- | :--- |
| **Crime-scene generation** | `sim/world.gd` (`_kill`), `sim/content.gd`, `sim/tuning.gd` | Currently stores `{trace_block, trace_true}` from evening block + 40% passer overwrite. Replace with `traces: Array` (1 Demon trace + optional 1 passer trace) rolled without replacement across `w.unused_trace_families`. |
| **Scene search & board cards** | `game/game.gd` (`search`, `_maybe_tell_haunts`), `game/game_board.gd` (`_home_cards`) | Currently emits `"trace"` (`block` + `day`), 10 `"home"` cards, and `"haunt"` cards. Emit structured `"trace"` cards per found clue and retire main-board `"home"` and `"haunt"` cards (keeping route lookups on `view.people`). |
| **Profile UI & shortcuts** | `ui/profile_panel.gd` (`_render_page`), `ui/trait_bars.gd`, `ui/case_view.gd`, `ui/main.gd` | Tab 0 renders plain text; Tabs 1-2 use `push_meta("card:%d")`. Wrap Tab 0 lines and trait rows in `push_meta("profile:<id>:<facet>")` with double-click and right-click `Add to Case Workshop` routing. |
| **Workshop model & toolbar** | `workshop/canvas_model.gd`, `ui/live_case_workshop.gd` | Has `"Add premise"` and `"Supporting evidence (no claim)"`. Remove `"Supporting evidence (no claim)"`; add `"Add Circumstantial Evidence"` (`kind = "circumstantial"`) and `"Add Townsfolk Profile Info"` (`kind = "profile_info"`). Keep `"suspicious"` in `TYPES`. |
| **Workshop canvas rendering** | `ui/workshop_canvas_view.gd` (`_draw_premise`, `evidence_layout`, `_draw_evidence`) | Add patina/sea-slate styling + `"Needs a premise"` orphan chip for `"circumstantial"` nodes; add person dropdown, character-ink header accent rule, and unlocked facet chips for `"profile_info"` nodes. |
| **Stage 1 trace likelihoods** | `game/workshop_bridge.gd`, `workshop/live_assessment.gd`, `workshop/live_activity.gd`, `workshop/case_eval.gd` | Replace evening-block `0.60 + 0.40/4` trace formula with `O(N)` per-suspect profile-fit likelihoods (`fit_demon` vs. `passer_explained`), validating that cited `"profile_info"` chips match the trace card in the case. |
| **Stage 2 circumstantial vibes** | `workshop/consequences.gd`, `game/workshop_ownership.gd`, `game/workshop_presentation.gd` | Replace provisional `max(circumstantial, abs(alignment))` envelope with additive, retractable Stage 2 hub scoring + one-shot listener trust loss when skeptical listeners reject weak mob-mentality cases. |
| **NPC reactions & Evil AI** | `sim/mind.gd`, `sim/mind_dialogue.gd`, `sim/evil.gd`, `sim/dialogue_voices.gd` | Add single-trace brush-offs, multi-trace frame-up denials, and true-prong deflection suggestions (with `[PH] ` prefix first, followed by 15-cast voice lines). |

## 3. Part 1: Multi-Category Crime-Scene Trace Model

### 3.1 The Four Orthogonal Factor Families

At world setup (`sim/world.gd`), initialize `w.unused_trace_families = ["locations", "demeanor", "quarter", "connection"]` (shuffled via `w.rng`). On each murder (`_kill`), pop the next unused family (refilling and reshuffling only if a game somehow exceeds 4 Demon kills) and build a clue dictionary `{family, prongs, text, match_ids}` guaranteed to include the killer (`actor_id`):

| Family ID | Generator Rule (Anchored on `actor`) | Avg. Eliminated (10 NPCs) | Player Discovery Loop | Example Flavour Text |
| :--- | :--- | :---: | :--- | :--- |
| **`locations`** *(Work & Haunts)* | Pick 1 location from `[actor.work] + actor.haunts`, plus 1 random decoy location from the remaining 7 town spots (sorted so order never leaks which is real). Matches anyone whose `[work] + haunts` intersects the 2 locations. | **~3.6** (`C(6,3)/C(8,3) = 35.7%`) | `work` is public; `haunts` require `ask about` or daytime spotting. | *"Fine flour dust mixed with coal clinker near the threshold: someone who works at or frequents the Bakery or the Smithy."* |
| **`demeanor`** *(Personality Tier)* | Pick 1 trait from `OBSERVABLE_TRAITS` (`privacy`, `gossip`, `confidence`, `composure`, or `insight` at 0.5x weight). Exclude 1 extreme tier (`low` or `high`) that `C.tier(actor.traits[t])` does **not** occupy (if `actor` is `mid`, randomly exclude `low` or `high`). Matches the remaining 2 tiers. | **~2.8 to 3.3** | Learned via conversation reveals, `ask about`, or behavioral tells. | *"The latch was slipped without a splinter out of place: not the work of someone jumpy or rattled (rules out Low Composure)."* |
| **`quarter`** *(Home & Evening)* | Take `b_home = actor.home_block` and `b_ev = loc_block(actor_evening_loc)`. If `b_home != b_ev`, the clue points to **living on `b_home` OR spending that evening on `b_home` / `b_ev`** (tuned to 2 blocks: `home_block in [B1, B2]` or `home_block == B1 or evening == B1`). If `b_home == b_ev`, pair `b_home` with 1 random adjacent block for `home_block` or evening presence on `b_home`. | **~2.5 to 3.5** | `home_block` is public; evening presence uses `ask seen` sightings. | *"Damp river silt ground into straw: left by someone who either lives on the Docks or spent yesterday evening on the Square."* |
| **`connection`** *(Bond & Turf)* | Combine **public bond with victim** (`victim.id in actor.friends or victim.id in actor.rivals` via `w.town_relationships`) with **1 fallback structural hook** (lives on `victim.home_block`, or works the same `work_phases` shift as `victim`), choosing whichever two-part disjunction covers `actor` and lands closest to `6-8` living+dead matches (`60-75%` of cast). | **~2.5 to 3.5** | Bonds require `ask about` or spoken disclosures; homes/shifts are public. | *"The bolt was drawn from inside for a familiar face, or by a close neighbour: someone with a personal tie to Hollis, or who lives on Chapel Hill."* |

**Target-band guardrail (`_build_trace_for_actor`)**: When sampling the decoy half of a disjunction (e.g., which decoy location in `locations` or which fallback hook in `connection`), evaluate candidate pairings against `w.npcs` and prefer candidates whose total match count in a 10-person town lands in **`[6, 8]`** (`[4, 5]` in a 7-person town). That guarantees no single roll accidentally narrows the whole town to 2 people or matches all 10.

### 3.2 Additive Passer Confound (`World._kill`)

1. Generate `demon_trace = _build_trace_for_actor(demon, v, family_a)` where `family_a` is popped from `w.unused_trace_families`.
2. Collect eligible passers: `passers = night_walkers.filter(func(wk): return wk["id"] != demon_id and wk["id"] != v.id and v.home_block in wk.get("path", [wk["block"]]))`.
3. If `not passers.is_empty()` and `chance(Tuning.Setup.EXTRA_TRACE_CHANCE)` (`0.45`):
   - Pick `wk = pick(passers)` and `passer = by_id[wk["id"]]`.
   - Pick a *different* family `family_b` (without consuming `w.unused_trace_families` for future Demon kills, or peeking at the next unused family) and build `passer_trace = _build_trace_for_actor(passer, v, family_b)` (skipping only if `passer_trace` has identical text/prongs to `demon_trace`).
   - Store `[demon_trace, passer_trace]` in shuffled RNG order on `scenes[sid]["traces"]`, logging full provenance (`actor = demon_id` vs. `actor = passer.id`, `wk["why"]`) to `dlog`.
4. When the player runs `search` at `scene_<victim>`, emit **1 `"trace"` card per entry** in `sc["traces"]` (so a two-trace scene produces two numbered board cards, e.g., `#18` and `#19`, linked by shared `scene` and `day` metadata). That lets the player drag both into the Case Workshop, link one to a claimed Night Watch's profile/duty to explain it away, and link the other to their Demon suspect!

### 3.3 Stage 1 Solver Integration (`workshop/live_activity.gd` & `workshop/case_eval.gd`)

Because `home_block`, `work`, `haunts`, `traits`, and `town_relationships` are fixed per case on `view.people` (never latent world variables in `world_domain.gd`), evaluating multi-category traces adds **zero combinatorial state** to `channel_sum_product.gd`:

- **Citation Gate (Player Must Do the Detective Work)**: A `"trace"` card in a Workshop case only activates its full person-specific likelihood bonus/penalty on suspect `X` if the player has linked a matching **Profile Info** card (for `locations`, `demeanor`, `home_block`, or `bonds`) or **Evening Sighting** card (for an evening-block prong) that connects `X` (or rules out rivals) on that trace's prongs. An unlinked trace card sitting raw on the canvas applies only a weak background prior unless paired with the corresponding Profile/Sighting evidence.
- **Single-Trace Scene (`scene_trace_count == 1`)**:
  - In a world where `i == world.demon`: likelihood is `0.92` if person `i` satisfies the trace's predicate (allowing a tiny `0.08` residual floor for future Framer/weirdness edge cases so no single circumstantial trace is a `1.0 / 0.0` mathematical proof), vs. `0.08` if person `i` does not satisfy it. Because ~7 people satisfy the predicate, each matching suspect gets a modest `~1.35x` relative nudge over baseline while the ~3 non-matching suspects drop sharply as Demon candidates.
- **Two-Trace Scene (`scene_trace_count == 2`, Traces `T1` and `T2`)**:
  - One trace came from `world.demon` and one came from a non-Demon night-walker on `scene_block`.
  - If `world.demon` matches **neither** `T1` nor `T2`, likelihood is `0.08`.
  - If `world.demon` matches **one** of `{T1, T2}`:
    - Base likelihood is `0.55` when the other trace is unexplained (since either trace could be the Demon's, and a matching suspect might only match the passer's trace).
    - **Walker Subtraction Bonus**: If the Workshop case *also* cites a valid night-walking claim/sighting on `scene_block` for another townsperson `W != world.demon` (e.g., Constance's Night Watch watch on `scene_block`, Isolde's Lamplighter tour, or a Warden guard on `scene_block`) AND `W`'s linked Profile Info satisfies the *other* trace, the Demon's likelihood rises from `0.55` to **`0.88`**!
  - If `world.demon` matches **both** `T1` and `T2`, likelihood is `0.90`.
- **Compounding Across Nights**: Because Night 1, Night 2, and Night 3 traces are distinct incidents (`trace:<scene_id>:<idx>`), `CaseEval._movement_score` multiplies their likelihoods across nights automatically, directly satisfying *"Repeated trace matches add up"* without custom special cases.

## 4. Part 2: Townsfolk Profile Info Nodes & UI Flow

### 4.1 Removing Main-Board Clutter
- In `game/game_board.gd`: Remove `_home_cards(g)` from case initialization so the Case Board no longer starts with 10 `"<Name> lives on <Block>"` cards.
- In `game/game.gd` (`_maybe_tell_haunts`): Keep updating `known_haunts[t.id]`, speaking the line, and logging `player_learns_haunts`, but stop appending `{"kind": "haunt", ...}` to `r["facts"]`.
- `workshop_bridge.gd` continues passing `home` (and now `work`, plus `player_unlocked_profile` metadata for `known_haunts`, `revealed_traits`, and `known_relationships`) on `view.people` so route validation (`live_activity.gd`) keeps working seamlessly without board cards.

### 4.2 Profile Panel -> Case Workshop Shortcuts (`ui/profile_panel.gd` & `ui/trait_bars.gd`)
In `ui/profile_panel.gd` (`_render_page`, Tab 0 `About`) and `ui/trait_bars.gd`:
- Wrap each unlocked profile line in clickable/hoverable metadata tags:
  - `"Works <shift> at <loc>; lives on <block>."` -> `meta = "profile:<id>:home_work"`
  - `"Off work, often at <haunts>."` (only when `known_haunts` is non-empty) -> `meta = "profile:<id>:haunts"`
  - Each learned relationship line (`"Agnes and Greta don't get along."`) -> `meta = "profile:<id>:bonds"`
  - Each revealed row in `TraitBars` (`Privacy: high`, etc.; hidden `"?"` rows excluded) -> `meta = "profile:<id>:personality"`
- **Interactions**:
  - **Double-clicking** a tagged profile segment opens (or focuses) the Case Workshop drawer, creates or reuses `<Name>'s Profile` (`p_info:<id>`), turns **on** that facet chip (`home_work`, `haunts`, `personality`, or `bonds`), and selects the node.
  - **Right-clicking** a tagged profile segment opens a compact popup menu with **`Add to Case Workshop (<Facet>)`**, matching the right-click UX on Case Board cards.

### 4.3 `"Add Townsfolk Profile Info"` Node in Case Workshop
- **Toolbar Button (`ui/live_case_workshop.gd`)**: Add **`Add Townsfolk Profile Info`** next to `Add premise`. Clicking it opens a cast dropdown (or spawns a card defaulting to the currently selected premise's target) and adds/focuses node `profile:<id>`.
- **Card Visuals (`ui/workshop_canvas_view.gd`)**:
  - **Body & Header**: Standard Evidence parchment (`#e8dfc8` body, `#c4b185` header) so players read it immediately as normal factual Stage 1 evidence.
  - **Character Identity**: Circular portrait (`_draw_face(person)`) on the left of the header + inline clickable **person name dropdown** (`field = "profile_person"`) so you can swap which townsperson the card targets right on the canvas + a **3px horizontal accent bar** (`C.npc_color(person).darkened(0.15)`) along the bottom edge of the header.
  - **Selectable Facet Chips**: Four toggleable chips (`Home & Work`, `Haunts`, `Personality`, `Bonds`) rendered via `_draw_element` (`t = "chip"`):
    - `Home & Work`: Always unlocked; displays e.g. *"Lives on the Docks · Miller (Afternoons at the Mill)"* when toggled on.
    - `Haunts`: Enabled once ≥1 haunt is known in `g.known_haunts[id]` (disabled with tooltip *"Ask around town to learn where they spend idle hours"* when unknown).
    - `Personality`: Enabled once ≥1 trait is in `n.revealed_traits` (displays only revealed trait tiers, e.g., *"Composure: high · Privacy: high"*).
    - `Bonds`: Enabled once ≥1 relationship involving `id` is in `g.known_relationships`.
  - Multiple chips can be toggled on simultaneously on the same person's Profile card if a case cross-references both their Haunts and their Personality.

## 5. Part 3: Circumstantial Evidence Hub & Stage 2 Vibes

### 5.1 Premise Dropdown Cleanup & Hub Toolbar Button
- **Keep `"is suspicious"` on standard Premise cards**: `TYPES` in `ui/case_workshop.gd` / `ui/live_case_workshop.gd` retains `"suspicious"` (`"is suspicious"`). No change to existing `"suspicious"` premises now; when the *Premises Matter* pass lands, `"suspicious"` will carry a lower support expectation, a smaller suspicion multiplier (e.g., `0.55x` of `"evil"`), and a higher `+pressure` bump on the target.
- **Remove `"Supporting evidence (no claim)"`**: Delete `+ ["Supporting evidence (no claim)"]` from `premise_type` in `ui/live_case_workshop.gd` and `ui/case_workshop_canvas.gd` (retaining `draft = true` solely for newly spawned blank premises before the user picks a claim).
- **Add `"Add Circumstantial Evidence"` button**: Spawns a node `{"id": "c:%d" % serial, "kind": "circumstantial", "at": [x, y]}`.
- **Visual Design (`ui/workshop_canvas_view.gd`)**:
  - **Palette**: Desaturated Patina / Sea-Slate (`paper = Color("cde0dc")`, `header = Color("7ea69f")`, border `Color("4f6d68")`, dark ink `Color("1f2b29")`). Distinct from gold Premises (`#e4c598`), cream Evidence (`#e8dfc8`), and dusty-plum Challenges (`#e3d6e6`).
  - **Title & Body**: Header reads **`Circumstantial evidence`**; body helper text reads *"Link general suspicious activity here, then connect this card to the premise it supports."* (or lists a compact count/summary of attached items).
  - **Orphan Indicator**: Whenever a `"circumstantial"` node has no outgoing `"supports"` link to a non-draft `"premise"` node, draw an amber pill badge (`Color("b87a28")`) in the top-right header reading **`Needs a premise`** with tooltip *"Connect this circumstantial group to a Premise card so listeners know whom you're pointing at."* Filing a case with an orphaned circumstantial hub either warns or excludes the unlinked hub cleanly.

### 5.2 Stage 2 Evaluation Math ("Mob Mentality" & Skeptic Backlash)

Let `P` be a Premise targeting `target` (with accusing type in `["demon", "evil", "minion", "suspicious", "lied"]`), and let `C_cards` be the deduplicated set of board cards linked into `P` via a `"circumstantial"` hub **excluding any `fact_id` already evaluated in Stage 1 on `P`**.

For each good listener `L` (`L.id != target`) after Stage 1 updates `L`'s baseline suspicion `S_target = clampf(Mind.susp(L, target), 0.0, 1.0)`:

1. **Per-Item Relevance & Relational Polarity (`item_polar(L, target, card)`)**:
   - Inspect whether `card` touches `target` (`target in CardModel.about(card)` or `card.source == target`; cards that don't mention `target` at all score `0.0`).
   - Identify any secondary named townsperson `other` on the card (for example: in a `vote` card where `target` voted YES on `nominee`, `other = nominee` with hostile polarity `-1`; if `target` voted NO on a hanged evil or defended `other`, polarity `+1`; in an `accusation` / `opinion` card by `target` against `other`, `other` has hostile polarity `-1`; in a `conversation` or daytime `sighting` pairing `target` with a silenced victim or proven evil, compute accordingly; if no secondary party exists, `rel_mod = 1.0`):
     - When `target` acted *against* `other` (e.g., `"Constance voted against Agnes"`):
       `rel_mod = clampf(1.0 + 0.8 * (L.npc_trust.get(other, 0.5) - 0.5) - 0.6 * Mind.susp(L, other), 0.35, 1.45)`
       *(Moves `L` much more if `L` likes Agnes and trusts Agnes is innocent; fizzles if `L` already suspects Agnes too.)*
     - When `target` associated *with* or defended `other` (e.g., `"Constance was whispering with Greta"`, or `"Constance voted no on hanging Greta"`):
       `rel_mod = clampf(0.6 + 1.0 * Mind.susp(L, other), 0.4, 1.5)`
       *(Moves `L` when `L` already suspects Greta.)*
   - Base item ceiling: `BASE_CIRC_ITEM = 0.035` (tunable in `Tuning.Workshop`).

2. **Listener Buy-In ("This accuses someone I already suspect") & `Insight` Damping**:
   - Let `ins = Mind.trait_of(L, "insight")` (`0..1`) and `tr = L.trust` (`0..1`).
   - Listener receptiveness to vibes against `target`:
     `vibe_receptiveness = clampf((0.25 + 0.75 * tr) * (0.20 + 1.15 * S_target) * lerpf(1.15, 0.45, ins), 0.0, 1.25)`
   - Notice what this captures:
     - High `S_target` (either from prior suspicion or from a solid Stage 1 logical case evaluated right before Stage 2!) + decent player trust + low/mid `Insight` -> `vibe_receptiveness ≈ 0.8 to 1.1`, giving **`+0.025 to +0.04` per resonant item**.
     - Near-zero `S_target` (`0.05`) + high `Insight` (`Hollis`, `Nisha`, `Lian`) -> `vibe_receptiveness ≈ 0.08`, giving almost zero movement (`+0.002`).
   - Sum across `C_cards` with mild diminishing returns (`1.0, 0.8, 0.6, ...`) and clamp total hub contribution to **`MAX_CIRC_HUB = 0.10`**:
     `circ_delta = minf(MAX_CIRC_HUB, raw_sum)`

3. **Skeptic Trust Penalty (Sloppy Detective Work)**:
   - Compute how poorly the case earned its pile-on for listener `L`:
     - If `S_target < 0.22` (neither Stage 1 nor `L`'s existing beliefs make `target` look meaningfully suspect) **and** `C_cards.size() >= 1`:
     - Buy-in check: `buy_in = S_target * 1.8 + (0.5 - ins) * 0.35 + (tr - 0.5) * 0.25`.
     - If `buy_in < 0.28` (and always when `L.id == target`!), listener `L` rejects the vibes pile-on as unfair muckraking and docks player trust **once per presentation** (keyed by case revision + target so re-reading doesn't double-burn):
       `trust_loss = clampf(0.015 + 0.025 * ins + 0.005 * mini(C_cards.size(), 3), 0.015, 0.045)`
       applied via `Mind.set_trust(w, L, L.trust - trust_loss, "the Demonologist padded a weak case with circumstantial smears")` (which also records an apologisable grievance if it crosses `GRIEVANCE_MIN_DROP`!).

4. **Ownership Persistence (`game/workshop_ownership.gd`)**:
   - Store `circ_delta` on a separate retractable sub-key in `n.workshop_state` (`state.circumstantial_applied[target]`, retracted in `_refresh(..., "before")` alongside `state.outside`, but **never** fed back into `S_target` on subsequent refreshes so Stage 2 cannot bootstrap itself). Meanwhile, any `trust_loss` on skeptical listeners is a permanent social consequence via `Mind.set_trust`.

## 6. Part 4: NPC Dialogue & Reaction Routing

When the player presents a raw `"trace"` card or a filed Workshop case containing trace/circumstantial links (`game/game_presentation.gd` / `sim/mind_dialogue.gd`):

1. **Presenting a Single `"trace"` Card Privately (`present <#trace>`)**:
   - **Listener matches a prong of the trace (`listener.id in trace.match_ids`)**:
     - Emits a calm brush-off acknowledging the shared habit without conceding guilt (e.g., `[PH] "Half the town stops by the bakery, Demonologist. That proves nothing about me."`), with a small nerves roll (`(0.5 if is_demon else 0.15) * (1.0 - composure) * 0.4`) only if another trace already implicates them.
   - **Listener does NOT match (or after brushing off) -> Deflection Tip**:
     - **Good NPC**: Picks the living townsperson with highest `Mind.susp(listener, other)` whose **publicly known or town-known profile** genuinely matches one of the trace's prongs (and is not in `listener.friends`), offering a lead: `[PH] "If it's bakery flour or forge soot, look at Bartholomew. He's forever round the smithy."` (If pointing out a haunt the player hasn't unlocked yet, calls the existing `_maybe_tell_haunts` unlock helper for that specific haunt!)
     - **Evil NPC (Minion or Demon)**:
       - **Hard Guardrail**: Never fabricates a false haunt, trait, or bond, and **never volunteers a haunt belonging to `w.demon_id`**.
       - Instead, `Evil.pick_trace_deflection(w, listener, trace, scene)` checks `evil_plan["scapegoat"]` first: if the scapegoat genuinely fits *either* prong of `trace` (or fits the *second* trace at a two-trace scene), spotlights that prong (`[PH] "Forget the bakery; that clinker is from the smithy, and <scapegoat> practically lives there."`). Otherwise picks any non-evil townsperson who genuinely fits the non-Demon prong, or gives a non-committal shrug if only evil fits.

2. **Presenting a Multi-Trace / Narrowed Case Against Listener**:
   - When `target == listener` and the case links **2+ traces** (or 1 trace + a night sighting on the murder block) that lift `evil_agreement >= 0.55`:
     - Triggers a cornered defence/frame-up line (`[PH] "Someone's trying to pin their dirt on me! Anyone could have tracked mud from the wharf past that door."`), even when no Framer role exists on the script.

3. **Skeptic vs. Mob-Mentality Replies on Circumstantial Cases**:
   - Listeners with `circ_delta >= 0.03` append a brief Stage 2 nod (`[PH] "Put alongside everything else around them lately, I don't like the look of it."`).
   - Skeptics who dock trust (`trust_loss > 0`) surface why (`[PH] "Bringing up how they voted isn't proof of murder. Bring me real evidence, not gossip."`), routed through `Dialogue.voice_line` once `[PH]` lines are promoted in the voice pass.

## 7. Implementation Sequence (6 Clean Commits)

This work sits in **Track 1B / Phase 2** and touches almost none of the conversational slice lines if coordinated cleanly after (or alongside) the `game/game.gd` 4-slice extraction:

1. **Commit 1: Multi-Category Trace Generator & Additive Passer Confound (`sim/`)**
   - Add `EXTRA_TRACE_CHANCE` and trace-family weights to `sim/tuning.gd`.
   - Implement `w.unused_trace_families` and `_build_trace_for_actor` across the 4 families (`locations`, `demeanor`, `quarter`, `connection`) + 2-trace passer roll in `sim/world.gd:_kill`.
   - Update `game/game.gd` (`search`) and `game/case_metrics.gd` to emit/score the new structured `"trace"` cards while keeping legacy fixture tests green.
   - *Check*: New unit suite `tools/test_multi_trace.gd` verifying candidate match counts (`6..8` in 10-NPC seeds across 200 seeds), zero duplicate families within 4 kills, Demon trace always present, and deterministic seed replay.

2. **Commit 2: Retire Main-Board `"home"`/`"haunt"` Cards & Add Profile Panel Links (`game/` & `ui/`)**
   - Remove `GameBoard._home_cards` and the `"haunt"` card append in `_maybe_tell_haunts`; expose unlocked profile metadata (`work`, `known_haunts`, `revealed_traits`, `known_relationships`) through `game/workshop_bridge.gd`.
   - Add `push_meta("profile:<id>:<facet>")` double-click and right-click (`Add to Case Workshop`) handlers to `ui/profile_panel.gd` and `ui/trait_bars.gd`.
   - *Check*: `test_board`, `test_town_ui`, and `test_ui` pass; board starts clean without 10 `"home"` cards.

3. **Commit 3: Workshop `"Townsfolk Profile Info"` Node & Stage 1 Trace Adapter (`workshop/` & `ui/`)**
   - Add `"Add Townsfolk Profile Info"` button in `ui/live_case_workshop.gd`, `"profile_info"` node handling in `workshop/canvas_model.gd`, and parchment + portrait + person-dropdown + character-accent + facet-chip rendering in `ui/workshop_canvas_view.gd`.
   - Wire `O(N)` per-suspect trace-predicate likelihoods and two-trace walker subtraction into `workshop/live_assessment.gd`, `workshop/live_activity.gd`, and `workshop/case_eval.gd`.
   - *Check*: New `tools/test_workshop_profile_traces.gd` testing single-trace nudge, multi-night compounding, two-trace dilution, Night Watch / Lamplighter walker subtraction, and locked-chip gating; profile `tools/profile_case_eval_town.gd` to confirm zero solver regression.

4. **Commit 4: Workshop `"Circumstantial Evidence"` Hub & Stage 2 Vibes Evaluator (`workshop/` & `ui/`)**
   - Remove `"Supporting evidence (no claim)"` from Premise dropdowns while preserving `"suspicious"`.
   - Add `"Add Circumstantial Evidence"` button, patina/sea-slate `#cde0dc` / `#7ea69f` rendering, and `"Needs a premise"` orphan badge in `ui/workshop_canvas_view.gd`.
   - Implement Stage 1/Stage 2 `fact_id` deduplication, relational polarity math (`item_polar`), `Insight`-damped `circ_delta` (capped at `0.10`), retractable storage in `game/workshop_ownership.gd`, and one-shot skeptic trust penalties in `game/workshop_presentation.gd`.
   - *Check*: New `tools/test_workshop_circumstantial.gd` verifying zero double-counting, fence-sitter boost when Stage 1 suspicion is high, near-zero movement + trust penalty on high-Insight skeptics when Stage 1 is empty, and clean retraction on case withdrawal/revision.

5. **Commit 5: NPC Trace Reactions & Minion Prong-Selection Guardrails (`sim/` & `game/`)**
   - Route `present <#trace>` and trace-backed cases through brush-off, true-prong deflection (with minion Demon-protection rules in `sim/evil.gd`), frame-up denials, and skeptic/mob replies using `[PH]`-prefixed strings.
   - *Check*: `tools/test_npc_interactions.gd` + new assertions verifying evil never leaks Demon haunts or invents false haunts, and good NPCs unlock cited haunts cleanly.

6. **Commit 6: Cast Voice Pass & Autoplay Bot Hookup**
   - Promote the `[PH]` trace/circumstantial reaction keys into all 15 character voices in `sim/dialogue_voices.gd`.
   - Update `tools/autoplay.gd` to attach unlocked Profile Info facets to searched scene traces so active-vs-passive 150-seed bot runs measure the new evidence loop end-to-end.
   - *Check*: `test_dialogue`, `test_trace`, full `run_gd_tests.py` suite, and 150-seed bot A/B baseline check.
