# Retiring the old belief system: inventory and plan

Prepared by Claude, Oct 30, 2026. **Status (Nov 1):** phase 1 done (PR #45); phase 2a implemented (`workshop/reason_attribution.gd` + `sim/mind_meeting.gd`). Decisions 1, 2, 3 and 4 all confirmed (including keeping vote-based circumstantial evidence player-presented rather than auto-evaluated in every NPC refresh). Full plan for phases 2-4 below.

The user asked for the old belief system to be purged. On Oct 24–25 the user had decided to keep a deliberate hybrid, recorded in the Project doc `claude/legacy-migration-plan.md`. That decision included "not deleting the legacy ledger wholesale", and it kept the native rules as the baseline for the bot A/B test. Purging reverses part of that, so this note lists what exists, what is still live, and the questions that need answers first.

## What is still live in normal play (measured Oct 30)

I played seeds 37291, 42, 1005 and 3 (ten townsfolk, player idle) to Day 4, then checked every living NPC's ledger:

| Ledger entries | Count | Owned by the shared model |
| --- | ---: | --- |
| `claim:*` (role claims) | 112 | all |
| `info:*` (readings, own and heard) | 130 | all |
| `heard:*` (relayed sightings and testimony) | 64 | all |
| `def:*` (defences) | 49 | all |
| `silenced:*` | 31 | all |
| `demon_death:*` | 28 | all |

**No ledger entry is judged by the legacy rules in normal play.** Their legacy effects are calculated and then taken back out. The suspicion the shared model doesn't own (the "outside" layer, which now sets its starting estimate) comes from:

- **the cast seeds** (`World` setup: base 0.1, friend −0.1, rival +0.15, Lovers 0.0);
- **paranoia drift** (`Social`);
- **grief** after an execution (`World`, around line 988);
- **"freed soul"** after a Revenant curse lifts (`World`, around line 952).

That's the social layer the hybrid decision meant to keep.

## What the old system still is in code

1. **Legacy effect generation.**
   - `Mind.ledger_hear`, `Mind.recompute_beliefs` and `Mind.apply_info` live in `sim/mind.gd`, with copies in `mind_dialogue.gd` and `mind_meeting.gd`.
   - Each role's `info_effects` (12 role files) produces the suspicion changes that the shared model then takes back out.
   - The ledger is also the **receipt store** the shared model reads, which is what NPCs heard and when. That part must stay; only the numeric effects are legacy.
2. **The shared-model switch.**
   - The toggles are `Game.workshop_effects` and `set_workshop_effects`, plus the Debug menu entries (`ui/live_case_workshop.gd`, `ui/workshop_comparison.gd`).
   - The bot has a `--native` mode.
   - There are 26 non-test references, and 37 test suites toggle the switch.
3. **Fallback.** When a shared plan isn't ready, `WorkshopOwnership.fallback` runs `Mind.recompute_beliefs`. Normal play has recorded zero fallbacks since Oct 25.
4. **`sim/argue.gd` (1,753 lines).** It does two jobs:
   - **the deduction schema**, which the case board, the Workshop canvas and presentation all need: conclusion types, `normalize`, `conclusion_text`, `conclusion_key`, `check`, `filing_problem`, `group_of`, `bears_on`, `conflict_of`, `from_builder`, `assertions`;
   - **the legacy template evaluator**, which only the native and fallback paths and the bot need: `evaluate`, `_apply`, the templates, `support_refs`.

   `game_board.gd` alone makes 17 calls, nearly all to the schema half.
5. **The bot.** `tools/autoplay.gd` builds two-card template deductions (`Argue.check`) and has the `--native` A/B mode. The backlog item "Bot builds Case Workshop cases" is its replacement.

## Proposed phases

Each phase is its own PR, with the full suite, `test_trace`, the 54875 replay and a passive bot chunk before and after.

1. **Split `argue.gd`.** Move the schema into `sim/deduction.gd` and keep forwarders. This is a pure move with no behaviour change, and it takes about one day.
   - **As built (Nov 1):** `sim/deduction.gd` holds the conclusion vocabulary, assertions, the template matcher (`check` and its `_match_*` helpers), text, keys and the filing checks (33 functions, 7 constants; it needs only `content.gd` and `gifts.gd`). `sim/argue.gd` keeps the evaluator (`evaluate`, `_apply`, `effects_of`, `support_refs`, the evil masks and argument lines) plus forwarders for the 16 schema functions and the constants still called through `Argue.*`. `game_board.gd` now calls `Deduction` directly. Same-seed active bot games are byte-identical before and after.
2. **Phases 2–4: see "Remaining phases: full plan" below** (Nov 1). The original one-line plan for phase 2 assumed nothing read the legacy numbers any more; the overhaul (Oct 31–Nov 1) added several readers, so a prep phase comes first.

## Remaining phases: full plan (Nov 1)

### Where things stand

- **Done:** phase 1 (`sim/deduction.gd`, PR #45) and phase 2a (`workshop/reason_attribution.gd` + `sim/mind_meeting.gd`).
- **The shared model owns every ledger entry** in normal play, and after 2a meetings and defences no longer read legacy effect magnitudes, `sus_why`/`sus_src`, `night_sighting_scale`, or `reading_strength` when the shared model is active. Remaining legacy by-products for 2b/2c:

| Legacy by-product | Made by | Still read by |
|---|---|---|
| Effect magnitudes on ledger entries (`effects`, `applied`) | role `info_effects`, `ledger_hear` | **retired from shared-mode meetings in 2a** (only unowned native compatibility paths until 2c/3) |
| `n.discounted` (per-source, per-night reading doubt) | `_night_doubt` in `_recompute_beliefs` | `SharedLedger.prepare` / `evaluate` (reading reliability, relay hearing, the 4.3 relayed-sighting collapse), `LiveAssessment._listener`, `Credibility.dawn`, presentation keys |
| `n.honesty` | `_honesty` in `_recompute_beliefs` | `Mind.reliability` (legacy), the bridge, a debug view in `game.gd` |
| `n.sus_why` / `n.sus_src` | `Mind.adjust` | **retired from shared-mode meetings in 2a** |
| `night_sighting_scale`, `reading_strength`, `card_strength`, `defend_strength` | legacy helpers | **retired from shared-mode `case_against` / `defend_self` / `_go_public` in 2a** (`card_strength` / `defend_strength` remain only in legacy hearing / `Argue` / pressing) |
| Direct suspicion changes | grief (`World._grief`), freed soul (`World.free_turned`), Revenant curse (`revenant.gd`) | the "outside" layer the shared model starts from |
| Role side effects inside `info_effects` | Gravedigger rapport changes | rapport |

- **`recompute_beliefs` is not only legacy.** It is the refresh entry point: the shared model's `workshop_refresh` hook runs inside it (about 20 production call sites). Phase 3 keeps a refresh function and deletes only the legacy arithmetic around the hook.

### Phase 2a: reasons and defences from the shared model (one PR, implemented Nov 1)

Goal: nothing in meetings reads legacy effect magnitudes.

- **As built (Nov 1, `workshop/reason_attribution.gd` + `sim/mind_meeting.gd`):**
  1. **Hybrid refresh-time attribution (`workshop_state.reasons[target]`).** Computed once inside `Jury._consequences_eval` (`refresh == true`) for active suspects (`requested >= 0.025` or `evil_change >= 0.05`), cached alongside `proposal` in `g._workshop_evaluations`, and augmented in `WorkshopOwnership.refresh` with Stage 2 `circumstantial_incidents` and an explicit elimination/joint residual fallback. Stores up to the top 6 ranked entries per suspect so `case_against`, `reason_status`, `nomination_case`, and `defend_self` all read pre-computed attribution without extra solver passes at the podium.
  2. **Three-pass shared-model scoring (replaces `_workshop_cross_card_own_reason`, `reading_strength`, and `night_sighting_scale`):**
     - **Direct channel pass:** evaluates attended reports (`Solver.report_table` + `CaseEval._fits_over` + `_headline_chance`), role counter-claims, night sightings and contradicted alibis (`LiveActivity._likelihood` with claimed walking roles and secrets), crime-scene traces (`LiveActivity.evaluate_trace_for_person`), and `ReadingChallenges` caught lies. Firsthand NPC night sightings (`n.beliefs` of `kind == "saw"`) now surface directly as citable reasons and emit sighting cards when spoken during accusations or nominations.
     - **Leave-one-out joint/contradiction pass:** when a suspect's joint shift (`evil_change >= 0.08`) exceeds single-card effects, tests dropping candidate own/attended reports, claims, and coverage/vigil observations across `_class_like`, `_subset_fits`, and `LiveActivity`. Catches multi-card traps (such as Hollis's Gravedigger vs. Odette's Archivist in `#98933`, complete Vigils vs. Night Watch claims, and Dowser + Rumormonger squeezes) without role-specific rules.
     - **Elimination/joint residual fallback:** when `requested + circumstantial_requested >= 0.15` with no single card or pair carrying it, emits a citable elimination/joint reason (`"narrowing down who hasn't been cleared points toward them"` / `"the reports considered together point toward them"`).
  3. **Live visibility resolution at read time (`_visibility_maps` + `_resolve_shared_reason`).** Separates cached evidence strength from live disclosure state (`claim_public`, `info_log[i].shared`, `told_readings`, `presentations`, `disclosures`, and `told_to`), preserving private/player/public/relay boundaries without invalidating evaluation caches when a card is shared. `sus_why` and `sus_src` are no longer read in shared mode.
  4. **Podium defence & disclosure scoring (`_disclosed_items_against`, `_go_public`).** Uses `ReasonAttribution.score_disclosed_fact_in_world` and `score_reading_entry_in_world` on public world state for newly spoken podium facts, keeping defender visibility non-leak rules intact.
  5. **Tests:** `tools/test_legacy_purge_phase2a.gd` covers `#98933` Hollis Gravedigger vs. Odette Archivist, firsthand night sightings (Kiran window/murder-block vs. off-block sightings), Vigil vs. Night Watch contradiction attribution, elimination fallback, and `defend_self` visibility and shared-model `out_weight`.

### Phase 2b: doubt, side effects and the social layer (one PR)

Goal: no legacy by-product feeds the shared model or the social layer.

1. **Replace `discounted` with shared-model source doubt.** Build `workshop_state.source_doubt` (same `source:night` / `source:*` keys) from what the shared model already establishes: reading-challenge results (`ReadingChallenges.assess` source penalties and report multipliers), caught lies and impossible claims, and public proofs (Gravedigger, Revenant curse, Demon victims). Switch every consumer listed above to it. `honesty` goes with it.
2. **Gravedigger rapport side effects** move out of `info_effects` into the world's execution-result handling, gated on the listener's own belief that the hanged person was innocent (or evil).
3. **Revenant curse:** delete the direct `adjust(+1.0)` and its `recompute_beliefs` (the premature `recompute_beliefs` was already removed); the chronology already pins the executed Revenant.
4. **Grief → resentment records** (decision 3): private, fading, citable, a term in that NPC's own nomination, vote and accusation scores; never a suspicion change. No grief if the mourner voted yes; a grudge clears if the hanged person is later shown evil.
5. **Freed souls → snapshot at turning**, restore on freeing, carry forward public receipts only; drop the 0.25 cap and the `shadow_adopt` + `recompute_beliefs` path.
6. **Votes and nominations as player-presented circumstantial evidence, both ways (updated Nov 1):** record `no` votes in the vote receipts and add the `"shielding"` incident (voted `no` on, or didn't vote for, someone the listener believes is evil) next to the existing `hostile_vote` in `workshop/circumstantial.gd`. **Do NOT auto-inject public vote receipts into every NPC's ambient refresh:** keep vote-based circumstantial evidence as a player-presented tool via Circumstantial hubs so NPCs behave like human townsfolk rather than omniscient vote-tallying spreadsheets unless the pattern is pointed out to them.
7. **After 2b the outside layer is the flat 0.1 start** (plus cast relationship seeds / paranoia until otherwise changed). Check: every NPC's `outside` matches only intended non-ledger baseline through Day 4 on fixed seeds.
8. **Measure:** passive and active bot chunks; fallbacks 0; no runtime regression on the meeting suites.

### Phase 2c: stop generating legacy effects (one PR, should be identical play)

1. `ledger_hear` keeps receipts, metadata and weights (they are hearing weights the shared model reads); `effects` become empty.
2. Delete role `info_effects` (12 role files) and the legacy hearing evaluators that only feed them: `card_strength` / `defend_strength` paths in `mind.gd`, `_night_doubt`, `_honesty`, `_claimants`-based effect expansion, the parking of native contributions (`Argue._apply` in `workshop_presentation.gd`) and the retraction of `applied`.
3. `_recompute_beliefs` shrinks to: run the shared refresh, apply its vector over the flat start.
4. **Proof:** suspicions identical through Day 4 on fixed seeds against the 2b result, plus `test_trace` and the 54875 replay. Anything that differs is a reader 2a or 2b missed.

### Phase 3: remove the switch and the fallback (one PR)

1. Delete `Game.workshop_effects`, `set_workshop_effects`, the Debug toggles (`ui/live_case_workshop.gd`, `ui/workshop_comparison.gd`) and the bot's `--native` mode.
2. **When a refresh can't be prepared (confirmed Nov 1):** keep the last good vector and log the issue. Also fix the one known not-ready case worth fixing first: a Gravedigger report with no matching public execution on that night.
3. Rename `recompute_beliefs` to `refresh_beliefs` (the shared refresh only) across its call sites.
4. **Tests:** about 40 suites mention the switch. Delete native-parity checks; keep and rewrite anything that tests behaviour; drop `test_legacy_migration`'s native half.
5. Baselines: native is gone (decision 1); record the first post-purge bot baseline here once the tuning overhaul settles.

### Phase 4: retire the template evaluator (after the bot builds Workshop cases)

1. The bot files Workshop cases instead of two-card template deductions (backlog item "Bot builds Case Workshop cases").
2. Delete `Argue.evaluate`, `_apply`, `effects_of`, `support_refs`, the evil argument masks and argument lines, then `sim/argue.gd` itself; point remaining `Argue.*` callers at `Deduction`.
3. Remove the `link` / `conclude` text commands.
4. **Decision needed then:** whether the case board's template matcher (`Deduction.check`, which files "matched" deductions and powers the link helper) stays as a player-facing helper or goes with the board if the Workshop canvas replaces it.

### Order and timing

- 2a done (Nov 1). Fixes the "no citable reasons" playtest problem and retires meeting/defence reads of legacy magnitudes.
- 2b next; it is the behaviour-changing one (grief, freed souls, `source_doubt`, player-presented `shielding` vote incidents).
- 2c and 3 back to back, before the overhaul's phase 5 sweeps, so the sweeps measure the final structure.
- 4 whenever the bot rewrite happens.

### Open items

- Grief numbers (strength, fade, cap) are tuning, set in 2b and measured.
- NPC-to-NPC credibility (splitting `npc_trust` into rapport and credibility, Nov 1 discussion) is deferred; 2b's source doubt is the natural place it would plug in later.
- `test_meeting_stream` takes about 15 minutes in the container; run the suite with `--timeout 1500` or mark it slow.

## Decisions (user)

**Answered Nov 1:**
- **1. Native A/B baseline: dropped.** Old baselines (native and pre-overhaul shared) are set aside; new baselines are taken once the tuning overhaul settles.
- **2. When a shared refresh cannot be prepared after Phase 3 (confirmed Nov 1):** keep the NPC's last good shared suspicion vector and log the issue, rather than resetting to baseline or hard-blocking.
- **3. Social effects outside the shared model** (decided with the user Nov 1):
  - **Grief becomes a private, citable action reason, not a suspicion change.** On an execution of someone a mourner trusted, the mourner gets a resentment record (`target`, strength, the hanged friend, day) that fades nightly like slights. It adds a term to *that NPC's* nomination, vote and accusation scores, and `reason_status` can return it as its own reason kind ("they pushed to hang Isolde"). It never enters anyone's shared model, so it only sways others through ordinary crowd pressure (accusations aren't evidence, Q4). Every friend of the hanged person gets their own record, so shared grief needs nothing extra.
  - **Votes and nominations are player-presented circumstantial evidence, in both directions (refined Nov 1).** "Nominated or voted to hang someone I believe is good" stays circumstantial (the existing `hostile_vote` family in `workshop/circumstantial.gd`, nominator weighted above yes voters), and 2b adds the mirror: **record `no` votes too**, and count "voted no on (or didn't vote for) someone I believe is evil" as a separate `shielding` incident. Vote-based evidence stays **player-presented** (requiring a presented Circumstantial hub rather than automatic ambient calculation on every NPC refresh) so NPCs only weigh complex voting patterns when pointed out to them.
  - **Freed souls revert to a snapshot.** At `turn_evil`, snapshot the fields the shadow copies (`SHADOW_COPY`: suspicion, ledger, workshop state, beliefs, hearsay, claims, credibility). On freeing, restore it, carry forward only public receipts from the turned period (public claims and readings; deaths and executions arrive from the world record), and drop the 0.25 suspicion cap. Private things from those days are forgotten. This replaces `shadow_adopt` + `recompute_beliefs` + the cap.
  - **The Revenant curse's direct `adjust` (+1.0) and `recompute_beliefs` are removed.** The shared model already pins the executed Revenant through the chronology.
  - **The flat 0.1 starting suspicion stays.**
- **4. Bot rewrite: no rush.** Phases 1–3 go ahead without it; phase 4 waits.

**Ordering (Nov 1):** see "Order and timing" in the full plan above.

**Original questions:**

1. **Does the purge reverse the Oct 24–25 "keep native as the A/B baseline" decision?**
   - The last A/B (Oct 25) still had native ahead on town agreement: 35% vs 20% sharing a top suspect at Day 3, with top-3 overlap 1.93 vs 1.30.
   - Without native, a replacement baseline is a frozen commit's shared results.
2. **What happens when a shared refresh can't be prepared** after phase 3? I propose keeping the last good vector and logging the issue. The other option is to block, as presentations do.
3. **Do the social effects stay outside the shared model as they are?** The seeds, paranoia drift, grief and freed soul would remain direct suspicion changes. Each could instead become a receipt with a fixed effect.
4. **Bot first, or after?** Phase 4 depends on the bot building Workshop cases. Phases 1 to 3 don't.

## Cost and risk

- **2a:** medium. New attribution code in the refresh; behaviour changes only in what NPCs cite and how they defend.
- **2b:** medium. Intended behaviour changes (grief, freed souls, vote evidence, source doubt); measure with bot chunks.
- **2c:** low if 2a and 2b caught every reader; proven by identical suspicions.
- **3:** medium, mostly test churn (about 40 suites) and the Debug UI.
- **4:** medium to high; depends on the bot rewrite, which resets every bot baseline.
