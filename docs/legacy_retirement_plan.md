# Retiring the old belief system: inventory and plan

Prepared by Claude, Oct 30, 2026. **Status (Nov 1):** decisions 1 and 4 answered (below); 2 and 3 open.

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
2. **Stop generating legacy effects.**
   - Ledger entries keep their receipts and metadata, but legacy `effects` become empty.
   - Role `info_effects` either go away or shrink to the metadata the receipts need.
   - The parking and retraction code for those entries is then dead and can be deleted.
   - Suspicion becomes the social layer plus the shared vector, which is already the value today.
   - Expect identical play if retraction is exact. Prove it with `test_trace`, and suspicions identical through Day 4 on fixed seeds.
3. **Remove the switch and the fallback.**
   - Delete `workshop_effects`, the Debug toggle, the `--native` bot mode and `recompute_beliefs`.
   - A plan that isn't ready keeps the previous vector and logs the issue, as presentations already do.
   - The 37 suites that toggle the switch are rewritten: delete the native-parity checks, and keep anything that tests behaviour.
4. **Retire the template evaluator,** once the bot builds Workshop cases. Remove the templates and the `link` / `conclude` text commands.

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

**Ordering (Nov 1):** phase 1 now (done: `sim/deduction.gd`, PR below). Before phase 2, the overhaul's new readers of legacy effects move to the shared model: meeting reasons (`case_against`), defences (`night_sighting_scale` / `reading_strength` in `defend_self`), the Gravedigger rapport side effects in `info_effects`, and the Revenant curse's `adjust` + `recompute_beliefs`. Phases 2–3 then land before the overhaul's phase 5 sweeps.

**Original questions:**

1. **Does the purge reverse the Oct 24–25 "keep native as the A/B baseline" decision?**
   - The last A/B (Oct 25) still had native ahead on town agreement: 35% vs 20% sharing a top suspect at Day 3, with top-3 overlap 1.93 vs 1.30.
   - Without native, a replacement baseline is a frozen commit's shared results.
2. **What happens when a shared refresh can't be prepared** after phase 3? I propose keeping the last good vector and logging the issue. The other option is to block, as presentations do.
3. **Do the social effects stay outside the shared model as they are?** The seeds, paranoia drift, grief and freed soul would remain direct suspicion changes. Each could instead become a receipt with a fixed effect.
4. **Bot first, or after?** Phase 4 depends on the bot building Workshop cases. Phases 1 to 3 don't.

## Cost and risk

- **Phases 1 and 2:** low risk and mechanical. A day or two together.
- **Phase 3:** medium. It touches 37 test suites and the Debug UI, and removes the A/B baseline.
- **Phase 4:** medium to high. It depends on the bot rewrite, which changes every bot baseline.
