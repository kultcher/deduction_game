# Retiring the old belief system: inventory and plan

Prepared by Claude, Oct 30, 2026. **Status (Nov 1):** phase 1 done (PR #45). Decisions 1, 3 and 4 answered; 2 proposed. Full plan for phases 2–4 below.

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

- **Done:** phase 1 (`sim/deduction.gd`, PR #45).
- **The shared model owns every ledger entry** in normal play, but legacy arithmetic still runs on every refresh, and its by-products are still *read*:

| Legacy by-product | Made by | Still read by |
|---|---|---|
| Effect magnitudes on ledger entries (`effects`, `applied`) | role `info_effects`, `ledger_hear` | meeting reasons (`case_against`, `reason_status`), `defend_self` |
| `n.discounted` (per-source, per-night reading doubt) | `_night_doubt` in `_recompute_beliefs` | `SharedLedger.prepare` / `evaluate` (reading reliability, relay hearing, the 4.3 relayed-sighting collapse), `LiveAssessment._listener`, `Credibility.dawn`, presentation keys |
| `n.honesty` | `_honesty` in `_recompute_beliefs` | `Mind.reliability` (legacy), the bridge, a debug view in `game.gd` |
| `n.sus_why` / `n.sus_src` | `Mind.adjust` | `reason_status` fallback, accusation hints |
| `night_sighting_scale`, `reading_strength`, `card_strength`, `defend_strength` | legacy helpers | `defend_self`, `_disclosed_items_against`, legacy hearing paths |
| Direct suspicion changes | grief (`World._grief`), freed soul (`World.free_turned`), Revenant curse (`revenant.gd`) | the "outside" layer the shared model starts from |
| Role side effects inside `info_effects` | Gravedigger rapport changes | rapport |

- **`recompute_beliefs` is not only legacy.** It is the refresh entry point: the shared model's `workshop_refresh` hook runs inside it (about 20 production call sites). Phase 3 keeps a refresh function and deletes only the legacy arithmetic around the hook.

### Phase 2a: reasons and defences from the shared model (one PR)

Goal: nothing in meetings reads legacy effect magnitudes.

1. **Per-card attribution, computed once per refresh.** After a listener's shared refresh, for the listener's top suspects only (those above the nomination or accusation floor), score each held card that mentions them by its own direction and strength in the shared model: the single-card likelihood ratio from `CaseEval`'s existing report and movement tables, signed by whether it raises or lowers that person. Store as `workshop_state.reasons[target] = [{card, why, strength, kind}]`. Cost: one cheap per-card table lookup per card mentioning a top suspect, cached with the refresh; no extra full evaluations.
2. **Joint reasons.** When a contradiction carries the suspicion (my reading against your claim; a vigil against a walking claim), record it as a joint reason from the reading-challenge and role-constraint results the refresh already computes. This replaces Phase 4.3's `_workshop_cross_card_own_reason` hand-written rules.
3. **`case_against` and `reason_status` read `workshop_state.reasons`** instead of ledger effects. `sus_why` / `sus_src` stop being read.
4. **`defend_self` uses the same attribution** for the cards against the defender, replacing `night_sighting_scale` and `reading_strength`. Its existing visibility rules (what the defender knows was disclosed) stay.
5. **Tests:** the 98933 Gravedigger case (Hollis cites his own reading against Odette), Kiran's sightings, the 4.3 fixtures, plus a check that every nomination with suspicion above the floor has a cited reason.
6. **Measure:** passive bot chunk; target that most NPC nominations cite a reason (the old figure was 0%).

### Phase 2b: doubt, side effects and the social layer (one PR)

Goal: no legacy by-product feeds the shared model or the social layer.

1. **Replace `discounted` with shared-model source doubt.** Build `workshop_state.source_doubt` (same `source:night` / `source:*` keys) from what the shared model already establishes: reading-challenge results (`ReadingChallenges.assess` source penalties and report multipliers), caught lies and impossible claims, and public proofs (Gravedigger, Revenant curse, Demon victims). Switch every consumer listed above to it. `honesty` goes with it.
2. **Gravedigger rapport side effects** move out of `info_effects` into the world's execution-result handling, gated on the listener's own belief that the hanged person was innocent (or evil).
3. **Revenant curse:** delete the direct `adjust(+1.0)` and its `recompute_beliefs`; the chronology already pins the executed Revenant.
4. **Grief → resentment records** (decision 3): private, fading, citable, a term in that NPC's own nomination, vote and accusation scores; never a suspicion change. No grief if the mourner voted yes; a grudge clears if the hanged person is later shown evil.
5. **Freed souls → snapshot at turning**, restore on freeing, carry forward public receipts only; drop the 0.25 cap and the `shadow_adopt` + `recompute_beliefs` path.
6. **Votes and nominations as circumstantial evidence, both ways:** record no votes in the vote receipts; add the "shielding" incident (voted no on, or didn't vote for, someone the listener believes evil) next to the existing `hostile_vote`; confirm vote receipts reach every NPC's shared input from the public record. This also covers the evidence half of grief ("pushed to hang someone later shown innocent") before the Gravedigger's legacy "nominator of an innocent" effect disappears.
7. **After 2b the outside layer is the flat 0.1 start.** Check: every NPC's `outside` equals the base for all targets through Day 4 on fixed seeds.
8. **Measure:** passive and active bot chunks; fallbacks 0; no runtime regression on the meeting suites.

### Phase 2c: stop generating legacy effects (one PR, should be identical play)

1. `ledger_hear` keeps receipts, metadata and weights (they are hearing weights the shared model reads); `effects` become empty.
2. Delete role `info_effects` (12 role files) and the legacy hearing evaluators that only feed them: `card_strength` / `defend_strength` paths in `mind.gd`, `_night_doubt`, `_honesty`, `_claimants`-based effect expansion, the parking of native contributions (`Argue._apply` in `workshop_presentation.gd`) and the retraction of `applied`.
3. `_recompute_beliefs` shrinks to: run the shared refresh, apply its vector over the flat start.
4. **Proof:** suspicions identical through Day 4 on fixed seeds against the 2b result, plus `test_trace` and the 54875 replay. Anything that differs is a reader 2a or 2b missed.

### Phase 3: remove the switch and the fallback (one PR)

1. Delete `Game.workshop_effects`, `set_workshop_effects`, the Debug toggles (`ui/live_case_workshop.gd`, `ui/workshop_comparison.gd`) and the bot's `--native` mode.
2. **When a refresh can't be prepared:** keep the last good vector and log the issue (proposed default; confirm). Also fix the one known not-ready case worth fixing first: a Gravedigger report with no matching public execution on that night.
3. Rename `recompute_beliefs` to `refresh_beliefs` (the shared refresh only) across its call sites.
4. **Tests:** about 40 suites mention the switch. Delete native-parity checks; keep and rewrite anything that tests behaviour; drop `test_legacy_migration`'s native half.
5. Baselines: native is gone (decision 1); record the first post-purge bot baseline here once the tuning overhaul settles.

### Phase 4: retire the template evaluator (after the bot builds Workshop cases)

1. The bot files Workshop cases instead of two-card template deductions (backlog item "Bot builds Case Workshop cases").
2. Delete `Argue.evaluate`, `_apply`, `effects_of`, `support_refs`, the evil argument masks and argument lines, then `sim/argue.gd` itself; point remaining `Argue.*` callers at `Deduction`.
3. Remove the `link` / `conclude` text commands.
4. **Decision needed then:** whether the case board's template matcher (`Deduction.check`, which files "matched" deductions and powers the link helper) stays as a player-facing helper or goes with the board if the Workshop canvas replaces it.

### Order and timing

- 2a next. It also fixes the "no citable reasons" playtest problem.
- 2b after 2a; it is the behaviour-changing one (grief, freed souls, votes).
- 2c and 3 back to back, before the overhaul's phase 5 sweeps, so the sweeps measure the final structure.
- 4 whenever the bot rewrite happens.

### Open items

- Decision 2 (keep last good vector) is proposed, not yet confirmed.
- Grief numbers (strength, fade, cap) are tuning, set in 2b and measured.
- NPC-to-NPC credibility (splitting `npc_trust` into rapport and credibility, Nov 1 discussion) is deferred; 2b's source doubt is the natural place it would plug in later.
- `test_meeting_stream` takes about 15 minutes in the container; run the suite with `--timeout 1500` or mark it slow.

## Decisions (user)

**Answered Nov 1:**
- **3. Social effects outside the shared model** (decided with the user Nov 1):
  - **Grief becomes a private, citable action reason, not a suspicion change.** On an execution of someone a mourner trusted, the mourner gets a resentment record (`target`, strength, the hanged friend, day) that fades nightly like slights. It adds a term to *that NPC's* nomination, vote and accusation scores, and `reason_status` can return it as its own reason kind ("they pushed to hang Isolde"). It never enters anyone's shared model, so it only sways others through ordinary crowd pressure (accusations aren't evidence, Q4). Every friend of the hanged person gets their own record, so shared grief needs nothing extra.
  - **Votes and nominations are circumstantial evidence, in both directions.** "Nominated or voted to hang someone I believe is good" stays circumstantial (the existing `hostile_vote` family in `workshop/circumstantial.gd`, nominator weighted above yes voters). Add the mirror: **record no votes too**, and count "voted no on (or didn't vote for) someone I believe is evil" as a separate shielding incident. Check first that vote receipts reach every NPC's shared input from the public record, not only when the player presents a vote card. The evidence half of grief ("pushed to hang someone later shown innocent") is covered here, for everyone, before phase 2 removes the Gravedigger's legacy "nominator of an innocent" effect.
  - **Freed souls revert to a snapshot.** At `turn_evil`, snapshot the fields the shadow copies (`SHADOW_COPY`: suspicion, ledger, workshop state, beliefs, hearsay, claims, credibility). On freeing, restore it, carry forward only public receipts from the turned period (public claims and readings; deaths and executions arrive from the world record), and drop the 0.25 suspicion cap. Private things from those days are forgotten. This replaces `shadow_adopt` + `recompute_beliefs` + the cap.
  - **The Revenant curse's direct `adjust` (+1.0) and `recompute_beliefs` are removed.** The shared model already pins the executed Revenant through the chronology.
  - **The flat 0.1 starting suspicion stays.**
- **1. Native A/B baseline: dropped.** Old baselines (native and pre-overhaul shared) are set aside; new baselines are taken once the tuning overhaul settles.
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
