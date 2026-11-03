# Retiring the old belief system: inventory and plan

Prepared by Claude, Oct 30, 2026. **Status (Nov 2):** phases 1, 2a, and 2b merged on `main`; **phases 2c and 3 implemented** (empty ledger `effects`, all 12 role `info_effects` deleted, `workshop_effects` / `set_workshop_effects` / Debug toggles / `--native` removed, Gravedigger missing-execution readiness fixed, unready refreshes keep the last good vector and log the issue, and `recompute_beliefs` renamed to `refresh_beliefs`). Only Phase 4 (template evaluator retirement after the bot rewrite) remains below.

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

- **Done:** phase 1 (`sim/deduction.gd`, PR #45), phase 2a (`workshop/reason_attribution.gd` + `sim/mind_meeting.gd`, PR #47), phase 2b (`workshop/source_doubt.gd` + social layer), and **phase 2c** (stop generating legacy effects).
- **The shared model owns every ledger entry and no legacy suspicion/doubt/honesty arithmetic runs anymore.** Summary of retired legacy by-products across 2a-2c:

| Legacy by-product | Made by | Status after 2c |
|---|---|---|
| Effect magnitudes on ledger entries (`effects`, `applied`) | formerly role `info_effects`, `ledger_hear` | **deleted in 2c** (`ledger_hear` stores `effects: []` with no `applied` dict; all 12 role `info_effects` deleted) |
| `n.discounted` (per-source, per-night reading doubt) | formerly `_night_doubt` in `_recompute_beliefs` | **deleted in 2c** (`_night_doubt` removed; `Mind.reliability` and `night_reliability` read `workshop_state.source_doubt`) |
| `n.honesty` | formerly `_honesty` in `_recompute_beliefs` | **deleted in 2c** (`_honesty` removed; `answer_opinion` word-doubt caveat and `debug_npc_text` read `reliability` / `source_doubt`) |
| `n.sus_why` / `n.sus_src` | `Mind.adjust` | **retired from shared-mode meetings in 2a** |
| `night_sighting_scale`, `reading_strength`, `card_strength`, `defend_strength` | legacy helpers | **retired from shared-mode meetings in 2a and hearing tails in 2c** (`card_strength` / `defend_strength` remain only for `press`, `present` direction inference, self-support rapport, and `Argue` until Phase 4) |
| Direct suspicion changes | grief (`World._grief`), freed soul (`World.free_turned`), Revenant curse (`revenant.gd`) | **retired in 2b** (grief -> private `resentments`, freed soul -> pre-turn snapshot restore, Revenant `+1.0` deleted; `outside` stays flat `0.1`) |
| Role side effects inside `info_effects` | Gravedigger rapport changes | **moved out of `info_effects` in 2b** (`World.on_execution_reading_heard` post-refresh hook) |

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

### Phase 2b: doubt, side effects and the social layer (one PR, implemented Nov 2)

Goal: no legacy by-product feeds the shared model or the social layer.

- **As built (Nov 2, `workshop/source_doubt.gd` + `sim/world.gd` + `sim/mind.gd` + `sim/mind_meeting.gd` + `workshop/circumstantial.gd`):**
  1. **Shared-model source doubt (`workshop_state.source_doubt`).** `SourceDoubt.derive` (`workshop/source_doubt.gd`) builds `source:night` and `source:*` doubt without touching `n.discounted`, `n.honesty`, or ledger `effects`: `pre_eval` captures caught lies (unique gift clashes, false Night Watch sightings of a home-staying listener, firsthand-contradicted night alibis, impossible Gravedigger claims against a public Revenant), public proofs (Revenant curse, own/trusted Gravedigger execution proofs, Martyr and Demon-victim sincerity clearing `source:*` while keeping `source:night`), and unowned template argument metadata (`meta.conclusion` + `weight`); `full` merges in `ReadingChallenges.assess` report multipliers and lying-source penalties without double-multiplying inside `CaseEval.reading_error`. `WorkshopBridge`, `LiveAssessment`, `SharedLedger`, `WorkshopOwnership`, `WorkshopPresentation`, `Credibility.dawn`, `Mind.reliability` / `night_reliability`, and `game.gd:debug_npc_text` all read `source_doubt`.
  2. **Post-refresh execution rapport (`World.on_execution_reading_heard`).** Removed `set_trust` mutations from `sim/roles/gravedigger.gd:info_effects` and moved them into `World.on_execution_reading_heard`, invoked after `Mind.apply_info` refreshes the listener's shared beliefs and gated on the listener's own belief about both the reader and the hanged person (`settled_execution_rapport` prevents duplicate triggers).
  3. **Revenant curse cleanup (`sim/roles/revenant.gd`).** Deleted the direct `mind.adjust(..., +1.0)` on `rv.id`; chronology (`curse.executed`) already pins the executed Revenant in the shared universe.
  4. **Private, fading, citable resentment records (`n.resentments`).** `World._grief` skips mourners who voted `yes` to hang `ex` and records private `{target, strength, friend, day, role}` grudges (`RESENTMENT_NOMINATOR_SCALE = 0.30`, `RESENTMENT_VOTER_SCALE = 0.12`, `RESENTMENT_FADE = 0.35`, `RESENTMENT_CAP = 0.45`) instead of mutating `suspicion`. Resentment fades nightly in `Mind.end_of_day_trust`, clears automatically (both live and on refresh) if the hanged friend is later believed/proven evil, enters only that NPC's own accusation, nomination, and vote scores, and surfaces in `case_against` / `reason_status` as a citable public reason (`"they pushed to hang X"` / `"they voted to hang X"`).
  5. **Freed-soul pre-turn snapshots (`capture_pre_turn_snapshot` / `restore_pre_turn_snapshot`).** `World.turn_evil` snapshots `SHADOW_COPY` + `credibility` / `beliefs` / `hearsay` / public cursors; `World.free_turned` disowns fake turned readings, emits `curse_lifted`, restores the pre-turn mind, replays only public claims and publicly shared readings from the turned period, drops `shadow_adopt` and the `0.25` suspicion cap, and runs one clean belief refresh.
  6. **Two-way player-presented vote circumstantial evidence (`shielding`).** Recorded `no` votes on execution records (`w.executions`) alongside `vote_pending` and board vote cards, and added the `"shielding"` incident family in `workshop/circumstantial.gd` (`"Voted against hanging X on Day d"` -> `"they voted against hanging X on Day d"`) when `target` voted `no` on someone the listener believes is evil (`post_stage1_susp >= 0.48` or proven Revenant), strictly when presented via a Circumstantial hub.
  **Review changes before merge (Nov 2):**
  - *Star doubt counted once.* `Mind.reliability` applied `source:*` twice for testimony; now once.
  - *A poisoned watch isn't a liar.* A Night Watch report naming the listener on a night they stayed home voids that night (`source:night = 1.0`) and halves general trust (`source:* >= 0.5`) instead of `source:* = 1.0`. Third-party Night Watch vs home-alibi conflicts are untouched: the shared model's worlds weigh them both ways by trust (new test).
  - *Freed souls keep public hearings.* Public ledger entries the good-self shadow heard while turned (meeting testimony, defences) carry forward on restore.
  - *Curse-proven Revenant pinned in the jury.* The chronology proves the executed Revenant evil in every world, so prior and posterior were both 1 and the shift was 0; with the `+1.0` gone its suspicion stayed at baseline. `Jury` now gives it the full alignment shift.
  - *Shielding is rarely citable.* It fires from 0.48 belief, but incidents are capped at `CIRCUMSTANTIAL_INCIDENT_MAX = 0.015` and reasons cite from 0.01 applied, so it only becomes a spoken reason when the listener is firm (about 0.7+) or the nominee is a proven Revenant. Seer pings alone top out near 0.35 (red herring), so this mostly needs corroboration.
  7. **Outside layer invariance & tests (`tools/test_legacy_purge_phase2b.gd`).** Zero non-ledger `Mind.adjust` calls remain in normal shared-mode play, keeping `workshop_state.outside` flat at `0.1` across multi-day games with hangings, grief, Revenant curses, and freed souls.

### Phase 2c: stop generating legacy effects (one PR, implemented Nov 2)

Goal: stop computing, parking, or retracting legacy effect arrays while preserving identical shared-mode play.

- **As built (Nov 2, `sim/mind.gd` + `sim/role_def.gd` + 11 `sim/roles/*.gd` + `sim/mind_meeting.gd` + `sim/mind_dialogue.gd` + `game/workshop_presentation.gd`):**
  1. **Receipt-only `ledger_hear` (`effects = []`).** `Mind.ledger_hear` (and its forwarders in `mind_dialogue.gd` and `mind_meeting.gd`) retains receipts, provenance metadata, justifications, and hearing weights read by the shared model while storing `"effects": []` and omitting `"applied"`. All production callers (`hear_claim`, `apply_info`, `press`, `defend_self`, `Social` relays, `World` silence/quiet-night/death events, `Martyr`, `Revenant`, `Argue._apply`, and `WorkshopPresentation._present`) pass `[]`. `SharedLedger.prepare` (`martyr:`) and `LiveProtection.owns` (`quiet:`) certify ownership from receipt/event metadata when `effects` is empty.
  2. **Role `info_effects` deleted across all 12 role files.** Removed `RoleDef.info_effects`, `Mind._info_effects`, and all 11 role overrides (`archivist`, `clerk`, `dowser`, `gravedigger`, `hearthwitch`, `martyr`, `medium`, `nightwatch`, `rumormonger`, `seer`, `veteran`). Preserved Seer's first-hearing own `no`-reading `listener.cleared` side effect via `RoleDef.on_reading_heard` (`sim/roles/seer.gd`).
  3. **Legacy evaluators, doubt/honesty passes, presentation parking, and `applied` loops removed.** Deleted `Mind._eff`, `_claimants`, `_expand`, `_final_weight`, `_night_doubt`, `_honesty`, `_support_factor`, `_ledger_apply`, `word_factor`, `_tell_meta`, the native hearing tails of `hear_accusation` / `hear_defence` / `hear_group_case` / `_public_case_hear`, the transitional `applied` loop in `MindMeeting.case_against`, and `Argue._apply` native deduction parking in `WorkshopPresentation._present`. Also switched the missed `n.honesty` reader in `MindDialogue.answer_opinion` (`WORD_DOUBT_BELOW`) and `Game.debug_npc_text` to `Mind.reliability` / `source_doubt`.
  4. **Shrunk `_recompute_beliefs`.** Runs `workshop_refresh` (`"before"` / `"after"`) over the outside baseline, refreshes metadata-backed non-suspicion preferences and role beliefs (`protect_pref`, `spare_pref`, `believed_roles`, and `e["eff"]`), prunes stale resentments, and captures the devlog snapshot.
  5. **Tests:** `tools/test_legacy_purge_phase2c.gd` verifies empty ledger `effects` across all receipt kinds, deletion of `info_effects` / `_night_doubt` / `_honesty` / `Argue._apply` presentation parking, Seer `on_reading_heard` `cleared` preservation, metadata-derived preferences/role beliefs, and multi-day shared-mode stability with zero fallbacks.

### Phase 3: remove the switch and the fallback (one PR, implemented Nov 2)

Goal: make shared Workshop evaluation unconditional, eliminate the native belief toggle, and keep the last good shared vector on any unprepared refresh.

- **As built (Nov 2, `game/`, `sim/`, `workshop/`, `ui/`, `tools/`):**
  1. **Switch, Debug toggles, and `--native` deleted.** Removed `Game.workshop_effects`, `Game.set_workshop_effects`, `GamePresentation.set_workshop_effects`, `DebugItem.EFFECTS` in `ui/live_case_workshop.gd`, `effects_toggle` in `ui/workshop_comparison.gd`, `--native` in `tools/autoplay.gd`, and `workshop_state["enabled"]` checks across `sim/`, `game/`, and `tools/`.
  2. **Atomic unready-refresh handling (`game/workshop_ownership.gd`).** `WorkshopOwnership._refresh` checks `Shared.prepare` readiness (both before and after `SourceDoubt.derive`) against the candidate outside baseline prior to retracting or mutating `n.suspicion` or `n.workshop_state`. When a refresh cannot be prepared, the listener retains its last good shared suspicion vector (plus any independent `outside` adjustments) and logs the issue via `WorkshopOwnership.fallback` (`g.shared_fallbacks` / `legacy_fallback` devlog). Presentation rollbacks in `WorkshopPresentation._present` restore prior `presentations` and `attention_focus` cleanly if `g._workshop_plans` has no prepared union.
  3. **Gravedigger missing-execution readiness (`workshop/live_assessment.gd`, `workshop/role_constraints.gd`, `workshop/solver.gd`, `workshop/reading_challenges.gd`, `workshop/source_doubt.gd`, `workshop/reason_attribution.gd`).** Removed the `LiveAssessment.prepare` readiness blocker on Gravedigger reports without a matching public execution on that night. When `view` carries `timeline`, `RoleConstraints._fits` and `Solver._report_content` / `_testimony_content` reject worlds where a good source reports a Gravedigger reading without a matching execution (since poison/Delusion only falsify `data.role`, never the existence or target of a public hanging), `SourceDoubt.derive` marks an unquoted non-sincere claimant `source:* = 1.0`, `ReadingChallenges.assess` backs `"lying"` challenges, and `ReasonAttribution` cites the bogus hanging claim.
  4. **Renamed `recompute_beliefs` -> `refresh_beliefs`** (and `_recompute_beliefs` -> `_refresh_beliefs`) across `sim/mind.gd`, `sim/mind_meeting.gd`, `game/game_presentation.gd`, `game/workshop_presentation.gd`, and all test suites in `tools/`.
  5. **Tests:** Updated all 37 affected suites in `tools/` (removing switch toggles and native-parity blocks, dropping `test_legacy_migration`'s native migration toggle, and rewriting fallback/Gravedigger checks to assert Phase 3 behaviour) and added `tools/test_legacy_purge_phase3.gd`.
  6. **Baselines:** Native is gone (decision 1); record the first post-purge bot baseline once the tuning overhaul settles.

### Phase 4: retire the template evaluator and the last legacy numbers (Nov 3 plan)

Decided with Michael, Nov 3: **purge everything left of the old deduction system**, and
build the bot on the shared model. Claude implements it. Order:

**4a. Presentations stop going through `Argue.evaluate` (should not change behaviour).**
`GamePresentation._evaluate_deduction_inner` still calls `Argue.evaluate` for every
presentation. For good listeners it hands straight to `w.workshop_present`, but it also
does three jobs the Workshop path doesn't:
1. **Evil listeners.** `WorkshopPresentation._present` returns `{}` for evil NPCs; `Argue`
   answers for them with the evil mask (`_evil_mask`, `_argument_descriptor`,
   `_evil_reason`, intel on `player_suspects`) and, through `shadow_eval`, as their good
   self unless breaking cover is worth it. Move this into a small presentation-reply module
   beside `WorkshopPresentation`, unchanged.
2. **Repeat counting** (`n.heard["ded:<conclusion>|<facts>"]`). Move unchanged.
3. **The template fallback** (good listener, Workshop returned `{}`: the
   `_workshop_native_submission` path and stale-wrapper cases). Delete it: per the standing
   rule, presentations never fall back; the listener answers with the Workshop's
   `_unavailable` reason instead. This is the one behaviour change in 4a; log how often it
   fired before removing it.

Check: active bot games before/after on the same seeds (the golden's passive player never
presents), plus the presentation and shadow-self suites.

**4b. Replace the hand-set strength numbers.** `Mind.card_strength` / `defend_strength`
(and the 12 role `card_strength` / `defend_strength` hooks, `night_sighting_scale`) no
longer touch beliefs but still drive social reactions to evidence, which breaks "no
evidence judged by both systems":
- **Presentation direction** (`game_presentation.gd`, incriminate vs clear per target):
  from card structure only (`Gifts.implicated`, `subjects`, clears). No strengths.
- **Pressing with a card** (`mind_dialogue.gd`) and **self-support rapport**
  (`workshop_presentation.gd`, `mind.gd`): read the shared model's own weight for that
  card from the reason attribution the jury already computes; a small fixed value
  (new `Tuning` constant) for cards it has no entry for.
- Delete the role hooks, `night_sighting_scale`, the strength tuning tables.
Changes press outcomes slightly; covered by a before/after pressing test.

**4c. The bot builds Workshop cases** (backlog "Bot builds Case Workshop cases", decided):
- **Strength settings:** passive bot stays the floor; the new active bot is an
  "analyst", near-ideal reader of the player's board, with an `--insight` setting
  (default 1.0) that degrades it (misses cards / noisy weights) for a human-ish run.
- **Information:** the player's board only. The hidden `w.dropped` peek goes.
- **Ranking:** a neutral test juror's posterior over the board replaces `_scores`.
- **Case building:** once a day, against the top suspect: add cards greedily while each
  raises the juror's strength, try each card's answers, cap about 8 cards. Conclusion:
  "evil" by default; also try "demon" only if checking both is cheap (Michael: timing
  decides).
- **Nominate / vote / defend** from the juror's belief, with thresholds tuned once.
- Meeting-overhaul slice M4 extends it later (Podium Press, supporters).

**4d. Delete the old system.** `Argue.evaluate`, `_apply`, `effects_of`, `support_refs`,
the evil masks' old home, argument lines, then `sim/argue.gd`; the template matcher
(`Deduction.check` and `_match_*`), `find_links` / `link_cards` and the template checks
inside `file_deduction` (Workshop filing keeps its path); the `link` / `conclude` /
`deduce` text commands (Michael, Nov 3: purge them); legacy tests (`test_argue`, template
parts of others). `sim/deduction.gd` keeps the conclusion vocabulary (`normalize`,
keys, text) that the Workshop and board use.

**4e. Re-baseline.** Old bot vs new bot on the same seeds once, for continuity; then the
first post-migration bot baseline: passive, analyst, analyst at reduced insight, at 7
and 10 NPCs. Bot games now run the shared model, so sweeps run in C# mode and the seed
count is set by time, not fixed at 150.

### Order and timing

- 2a done (Nov 1–2, `ff13ea6`). Fixes the "no citable reasons" playtest problem, lazily attributes shared-model reasons on demand, and retires meeting/defence reads of legacy magnitudes.
- 2b done (Nov 2; about 5% slower than 2a over four seeds to Day 4). Retires shared-mode reads of `discounted` / `honesty` via `source_doubt`, moves Gravedigger rapport out of `info_effects`, converts grief to private fading `resentments`, restores freed souls from pre-turn snapshots, deletes the Revenant `+1.0` `adjust`, and adds player-presented `shielding` vote circumstantial evidence.
- 2c done (Nov 2): empties ledger `effects`, deletes all 12 role `info_effects` and legacy doubt/honesty/hearing/parking/retraction arithmetic, and shrinks `_recompute_beliefs` to the shared refresh plus metadata preferences.
- 3 done (Nov 2): removes `workshop_effects` / `set_workshop_effects` / Debug toggles / `--native`, keeps the last good shared vector on unprepared refreshes, supports Gravedigger reports with no matching execution on that night, and renames `recompute_beliefs` to `refresh_beliefs`.
- 4 started Nov 3 (Claude): 4a presentation path, 4b strengths, 4c bot, 4d deletion, 4e baselines.

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
