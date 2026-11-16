# Purging what the connections model replaced: inventory and plan

Nov 16, 2026 · Claude-Lantern · read against main `c8ef1e7` (#167). **Status:** plan for
Michael. No code has been changed. Michael has decided the purge will happen; this says how.

The model is `docs/archive/legacy_retirement_plan.md` (the Nov 1–3 retirement): an
inventory, phases that are one PR each, and the switch removed before the code behind it.

**How this was put together:** by reading the code on main. Nothing was built, run or
timed. Each "expected golden" below is a prediction from the code, to be checked by the
phase's own capture at `--tol 0`.

## The short version

- The connections model has been on since #160. The earlier model runs only when something
  sets `Connections.enabled = false`: `autoplay --legacy-model`, the replay tools on a log
  from before #160, seven pinned test suites (plus switch-off sections in the connections suites), and the fixture-seed search.
- **Most of what connections replaced is already dead in play** but still computed: the
  refresh still runs the earlier model's whole joint judgement on the attended cards and
  its headline reading, then throws both away. Removing those is safe and should save time.
- **Some of the earlier model still runs in play whatever the switch says** (section 2).
  Removing it changes behaviour, so it waits for Michael (section 7).
- Eight phases are proposed (section 5). Only phase 6 is expected to move golden, and only if
  Michael approves it.

## 1. What only the earlier model uses

These run only with `Connections.enabled = false`, or run but are thrown away with it on.
Line numbers are main `c8ef1e7`.

### 1a. The switch itself and the code paths it gates

| Where | What | What reads it |
|---|---|---|
| `sim/tuning.gd:903` `Workshop.CONNECTIONS` | The default (true) | `workshop/connections.gd:90` |
| `workshop/connections.gd:90` `static var enabled` | The runtime switch | Everything below |
| `workshop/jury.gd:937` `_consequences_eval` | Runs `Connections.refresh` on a refresh | The one call site |
| `game/workshop_bridge.gd:157` `capture` | Puts `listener.connections` (day, core, nominations) in the input | `Shared.prepare` (`with_cases`, line 104), `premise_shaping` (line 600) |
| `game/workshop_ownership.gd:101` `_refresh` | Adds `"connections"` to the cache key | Union cache |
| `game/workshop_presentation.gd:47` `faded`, `:95` `restores` | A case faded since another day is assessed again, not waved off | Presentation repeats |
| `game/workshop_presentation.gd:434, 452` `_suspicious_pressure` | Connections rise and pressure, or the earlier rule | Pressure on the subject |
| `sim/mind_meeting.gd:1431` `remember_nomination` | Stores an NPC nominator's cited cards as a case | Each listener's memory |
| `sim/world.gd:404` | Writes `connections: true` in `case_start` | `tools/log_replay.gd:34-41` |
| `game/workshop_canvas.gd:337` `town_note` | The "No new info" note exists only with the model on | Workshop chip |
| `game/workshop_why.gd:154` `before` | Keeps the last breakdown for the Why report | `_connections_report` |

**Gated without naming the switch** (they test for `listener.connections`, so they follow
the switch through `Bridge.capture`): `Shared.prepare` stored cases (`shared_ledger.gd:104,
158`), `Shared.premise_shaping` (`:600`), `Ownership` committing the core (`:154`),
`workshop_why.gd:227` choosing the report. These become unconditional with the switch.

### 1b. The earlier model's belief arithmetic

| Mechanism | Where (file, function) | With connections on | What still reads it |
|---|---|---|---|
| **The attention limit on belief:** the joint CaseEval on the attended cards | `jury.gd:925-932` `_consequences_eval` (`_eval_case` → `scoped`, `_case_eval` → `ev`) | Computed in full on every refresh, then `Connections.overlay` (`connections.gd:1126`) replaces every person's chance; only `ev.impossible` is replaced too. Wasted work | Nothing on a refresh. Non-refresh evaluations use it (section 2) |
| Working-theory bias for committed listeners | `jury.gd:966-994` (`persistence and connections.is_empty()`) | Skipped on a refresh | Workshop sandbox listeners in `Jury.evaluate` (`workshop/session.gd`); NPCs never use persistence |
| **Spillover damping** (premises step 1) and the "suspicious" half-hearing as card shaping (step 2) | `shared_ledger.gd:594` `premise_shaping`, `:667` `without_shaping`, `:683` `_field_base`, `:690` `_shape_effect`, `:781` in `_evaluate_adjusted`; `workshop_ownership.gd:99-126` (the `shaping_eval` passes); `workshop_why.gd:98-112` `_union` | Returns `{}` (`:600`), so none of it runs | Nothing in play. `PREMISE_SPILLOVER_MIN/MAX` (`tuning.gd:1097-1098`) have no other reader |
| **The headline reading** on a refresh | `jury.gd:1002-1012` (`_headline` at `:776`, `_headline_group_key` `:739`, `_headline_chance` `:807`) | Computed, then multiplied by `dull = 0`. This is the ~0.8 s in a nomination I saw in a profile (`trust_reward/jury/headline`) | `headline_signal` in the effects, read only by the earlier Why report (`workshop_why.gd:283, 872`) |
| **Reading challenges applied to everything** | `jury.gd:930` (`ReadingChallenges.assess` on the attended cards → `eval_listener` → `ev`), and `shared_ledger.gd` merging every presentation's challenges into one `reading_challenges` | Inside `ev` they're thrown away with it. A challenge inside a stored case acts only in that case (`:1028` skips its floor; `:1036` applies the case's floor scaled by weight) | Reason attribution (`challenged` in `reason_inputs`); the floor for a challenge made outside any case (an NPC's defence) |
| The earlier "suspicious" pressure (premises step 2, the held-back half) | `workshop_presentation.gd:503` `_other_suspicious`, `:516` `_filing_rise`, and `:437-438`, `:451` | Skipped | Nothing in play |
| The earlier Why report | `workshop_why.gd:176-400` (`presentation` after `:227`), `_union` `:80`, `_reliability` `:124`, `_scale_reliability` `:131`, `_post` `:139`, `describe` `:828`, `_describe_extras` `:896` | `_connections_report` and `describe_connections` take over | `tools/test_workshop_why.gd`. **Not** `workshop/case_why.gd`: the Test juror (`workshop_why.gd:54`) and the connections report (`:652`) use it, so it stays |
| `"Today's damping applies"` comparisons | `tools/test_connections_cases.gd:395` and similar | Only the suite | The suite |

### 1c. Tools and the sweep

| Where | What |
|---|---|
| `tools/autoplay.gd:121-161, 641` | `--legacy-model` (mode suffix `_legacy`); `--connections` (names the mode, otherwise a no-op since #160) |
| `tools/sweep_shard.py:34-37, 136-139, 221-244` | The `_legacy` and `_connections` cell suffixes |
| `.github/workflows/balance-sweep.yml:14, 61-64` | Accepts `_connections` only. **It rejects `_legacy`**, so `_legacy` cells can't be run from the workflow today (a bug, moot after the purge) |
| `docs/balance_sweep.md:17` | Documents both suffixes |
| `tools/golden_capture.gd:8, 46-48` | `--connections` (a no-op since #160) |
| `tools/replay_log.gd:11, 42-43`, `tools/explain_case.gd:24, 62` | `--connections` for logs from before #148 |
| `tools/log_replay.gd:34-41` | Turns the switch off for a log without `case_start.connections` |
| `tools/fixture_seeds.gd:44-56` `search` | **Plays every fixture search on the earlier model** ("several times faster"), then restores the switch. Four suites use it: `test_connections_core`, `test_connections_pairings`, `test_relay_bluff`, `test_self_sighting` |

### 1d. Older leftovers found on the way (not connections, same domain)

- **The pre-CaseEval engine.** `Jury.engine` (`jury.gd:26`) can be `"legacy"`, which runs
  `_assess_target` (`:201-420`) and `Consequences.assess` (`jury.gd:146`;
  `workshop/consequences.gd`). Only `tools/test_workshop_checkpoint.gd:14` and
  `tools/profile_live_presentation.gd:22` set it. `shared_ledger.gd:414` and
  `live_assessment.gd:114, 234` check for it.
- **Attention experiments that no longer test belief:** `Reasoner.unlimited_cards`
  (`autoplay --no-attention`) and `Reasoner.always_keep_kinds` with
  `tools/read_everything_gap.gd`. With connections, attention only changes what is cited, so
  "read everything" no longer changes what NPCs believe.
- **Stale comments:** 7 in game code say the model is "off by default" (`jury.gd:933`,
  `workshop_ownership.gd:220`, `workshop_bridge.gd:153`, `shared_ledger.gd:101`,
  `workshop_presentation.gd:43, 93`, `mind_meeting.gd:1426`), and so does the header of
  `tools/test_connections.gd:4`. Others call the earlier model "today's"
  (`connections.gd:68` "today's reading", `jury.gd:1027` "today's floor") or the spec's
  "today" (the `belief_model.md` note).

## 2. The earlier model where it still runs, whatever the switch says

The connections model replaces the chance an NPC gives each person **on a belief refresh**.
Other evaluations still use the earlier model's arithmetic. These all stay live after the
switch goes, unless Michael decides otherwise (section 7). Removing any of them changes
behaviour.

| What | Where | Effect in play |
|---|---|---|
| **Headline reading in evaluations that aren't refreshes** | `Jury.evaluate` → `_consequences_eval(refresh = false)`: `dull` is only zeroed when `connections` is non-empty, which needs a refresh | Scoped replies to a presentation (`Shared.response`, `shared_ledger.gd:514`), the Test juror (`live_assessment.gd:673`), the ghost juror (`ghost_juror.gd:53`), and the secret-claim check at dawn (`credibility.gd:159`, through `evaluate_question`) |
| **Reason attribution's headline route** | `reason_attribution.gd:111, 204-215` | A low-Insight NPC can cite a reading it isn't attending to, if the reading's headline names the suspect. Changes what NPCs say, not what they believe |
| **The attention limit still feeds belief in four places on a refresh** | `jury.gd:946` `Protection.assess(view, attended, …)`; `:1016-1020` the circumstantial pattern on `attention.case` (when movement isn't available); `:1025-1034` the floor of a challenge made outside any case, which only applies if the challenged card is attended; `:1049` `Reasoner.direct_checks` on `attention.case` | A quiet-night protection signal, a circumstantial pattern, a "lying" floor from a defence, or a fatal direct check can depend on which cards attention picked. Everything else in the chance doesn't |
| **Attention-limited joint judgement in replies** | `jury.gd:529-530` (`_assess_target_eval`) | The stance and wording of a reply to a presentation come from the attended cards. The spec calls this "replies: unchanged", and lists it as a known gap (a reason may cite a pairing the model didn't weigh) |

The last row is the hub of the reply system and stays. The first three are the earlier
model surviving inside play.

## 3. What stays because connections uses it

| Kept | Why |
|---|---|
| Attention: `Reasoner.prepare`, `PROFILE_LOW/MEDIUM/HIGH`, `INSIGHT_LOW/MEDIUM_CUTOFF` (`tuning.gd:1143-1144`), Recency (`sim/recency.gd`, `RECENCY_*`) | Picks what an NPC cites and explains (`effects.cards`, reason attribution, replies) |
| `ReadingChallenges.assess` | Stored cases' challenges (inside the case) and defences made outside any case |
| `Shared.premise_targets`, `_root_type`, `PREMISE_SHAPING_TYPES` (`tuning.gd:1101`) | A stored case's target and type (`shared_ledger.gd:153-158`). The constant's name describes the earlier use; rename it in phase 8 |
| `SUSPICIOUS_HEARING` (`tuning.gd:1110`) | Halves a "suspicious" case's weight (`connections.gd:794`) |
| `SUSPICIOUS_PRESSURE_PER_RISE` (`tuning.gd:1111`) | The private/meeting scale on connections pressure (`workshop_presentation.gd:450`) |
| `held_back_chance`, `connections_pressure`, `_connections_rise` | Connections pressure (#155) |
| `_source_trust`, `_card_trust`, `_directional`, lean and committed requests, the outside layer, `JURY_*` | Turning a chance into suspicion (the spec: "unchanged") |
| `Jury.evaluate`, `Shared.response`, `_assess_target_eval`, Theory and persistence | Replies, the Test juror, Workshop sandbox listeners |
| `ReasonAttribution` (except the headline route, section 2) | What NPCs cite |
| `workshop/case_why.gd` (`Why.evidence`, `describe`, `strongest_alternative`) | The Test juror and the connections Why report |
| `Connections.cache_*`, `reuse_rule`, `held_together_rule`, `buy_in` | The model's own measuring switches |
| `case_start.connections` in the dev log | Tells a log from after #160 from one before it (section 7, decision 1) |

## 4. Tests that pin the earlier model, and what happens to each

**Pinned with `Connections.enabled = false`:**

| Suite | What it checks | Plan |
|---|---|---|
| `test_recency` (CI fast) | Cards fade from attention, the day's topic draws it, presenting brings a card back; and the headline blend's strength scaling | Unpin. Keep the attention checks, reading what is attended or cited instead of belief. The headline part goes with phase 6, or stays pinned to a non-refresh evaluation if Michael keeps the headline there |
| `test_premise_step1` (CI fast) | Spillover by Insight; a clearly wrong premise costs trust; a rejected premise steers no preference; movement notes; the Test juror's defence note | Delete the spillover checks. Unpin the rest and re-fit them; stored-case targets are already covered by `test_connections_cases` |
| `test_premise_step2` (CI fast) | Secret premise as the player's word; "suspicious" at half weight and its one push; contradictions keep both cards; a public role claim joins a case | Unpin. Replace the half-weight and push checks with connections equivalents (#155's measures). Re-fit the rest |
| `test_execution_aftermath` (CI fast) | Gravedigger rapport, the Revenant curse, resentments, freed souls | Model-independent mechanics; pinned in #160 because numbers moved. Unpin and re-fit thresholds |
| `test_beliefs` (CI fast) | Credibility, source doubt, belief revision | As above |
| `test_workshop_why` (CI fast) | The earlier Why report, and that it changes nothing | Delete with phase 5. First port its "changes nothing" check to `test_connections_why` if that suite doesn't have one |
| `test_workshop_live_cognition` | Native profiles, committed memory, scoped replies, reversible ownership | Unpin; drop the spillover check (`:208`) |
| `tools/fixture_seeds.gd` | Searches on the earlier model for speed | Search on connections. Suites using it get slower (passive games ran about 3× longer in Tally's Nov 14 cells); time them in phase 2 |

**Switch-off sections in the connections suites** (`test_connections`, `_pairings`, `_core`,
`_cases`, `_why`, `_cache`, `test_town_note`): some check that nothing runs with the switch
off, or compare against "today's" numbers. Those go in phase 4. Others turn it off only to
play a game quickly; those switch to connections or to `fixture_seeds`.

**Not pinned, but likely to test nothing with connections on** (to check in phase 2):

- `test_headline` (CI fast): its checks are "a dull holder moves at least as far as a sharp
  one", which is trivially true when the headline is zeroed on a refresh. Its
  `Jury._card_trust` checks are still real.
- Suites that mention the headline, Insight or spillover and use evaluations that aren't
  refreshes, where the headline still runs: `test_workshop_reasoning`,
  `test_workshop_consequences`, `test_social_credibility`, `test_ui_controls`,
  `test_workshop_attention`, `test_attention_0b`. I haven't read each one.
- `test_workshop_checkpoint` sets `Jury.engine = "legacy"` (section 1d).

## 5. Phases

One PR each, in order. Every phase: build, the fast list, the suites it touches, a golden
capture at `--tol 0`, and a handoff entry. **Golden plays the five seeds passively**, so it
never exercises player presentations, spillover, "suspicious" pressure, the Test juror or
the Why report. Golden matching for those phases proves little; the suites prove it.

| # | PR | Expected golden |
|---|---|---|
| 0 | This plan | n/a (docs) |
| 1 | **Handed to Argon (Nov 16).** Performance work on the model is Argon's now, and its speed patch already skips the dead CaseEval and `_headline` calls on a connections refresh (`jury.gd:925-932`, `:1002-1012`). What's left for the purge is to check that the skip keeps `attention`, `challenged` and `eval_listener` (reason attribution and the four signals in section 2 read them) and takes `impossible` from the connections result. I review that in Argon's PR rather than building it | Identical (Argon checks at `--tol 0` with `cache_verify`) |
| 2 | **Move the tests off the earlier model** (section 4). `fixture_seeds` searches on connections. No game code changes | Identical (tests only) |
| 3 | **Snapshot, then remove the switch.** First push a snapshot branch `archive/legacy-belief-final` at the last commit with `--legacy-model` (decision 2). Then: delete `Connections.enabled` and `Tuning.Workshop.CONNECTIONS`; make every gate in 1a unconditional; remove `--legacy-model`, the `_legacy` and `_connections` suffixes (accepting `--connections` as a no-op for a release so old commands don't fail), `golden_capture --connections`, `replay_log` and `explain_case --connections`; `log_replay` warns and stops on a log from before #160 instead of switching models | **Identical** (the default is already on) |
| 4 | **Clean the connections suites** of switch-off checks and on/off comparisons | Identical (tests only) |
| 5 | **Delete the earlier model's refresh-only code** (1b): spillover and card shaping, the earlier "suspicious" pressure, the earlier Why report's branch of `workshop_why.gd` (`case_why.gd` stays), and their constants (`PREMISE_SPILLOVER_MIN/MAX`). Regenerate `tuning_catalogue.md` | **Identical.** All of it is unreachable after phase 3 |
| 6 | **Only if Michael approves (section 7, decisions 3–5):** remove the headline reading everywhere (`_headline*`, `HEADLINE_*`, reason attribution's route), and have the four signals in section 2 read the held cards instead of the attended ones. Probably two PRs (6a headline, 6b the four signals), merged one at a time | **Moves.** 6a changes what NPCs cite and possibly reply stances; 6b changes suspicion wherever a protection, pattern, defence floor or direct check depended on attention. Re-baseline in each PR, with each seed's outcome in `docs/golden_baseline.md` |
| 7 | **The pre-CaseEval engine and the attention experiments** (1d), if Michael agrees: `Jury.engine`, `_assess_target`, `Consequences.assess`, `unlimited_cards`, `always_keep_kinds`, `read_everything_gap.gd`, `--no-attention` | Identical (tools only reach them) |
| 8 | **The naming sweep** (section 6) | Identical (comments, labels, docs). If a dev-log or report label is renamed, the golden `step` records may carry it; check |

**Argon's speed patch lands first** (Seneschal, Nov 16). It edits `workshop/jury.gd`
(`_consequences_eval`), `workshop/connections.gd` and `workshop/case_eval.gd`. No phase that
edits those files starts until it has merged: that rules out 3, 5 and 6 (and 7, which edits
`jury.gd`). Phases 2 and 4 are tests only and can start at once. Phase 3 needs 2. Phase 5
needs 3. Phase 6 can come any time after 3, but it moves golden, so it goes alone.

## 6. The final sweep: names the purge leaves behind

Michael's direction for the migration was to catch what earlier purges left. The last one
left `WorkshopOwnership.fallback` logging as `legacy_fallback`, and the dev report saying
"the legacy rules judged N things" when no legacy rules exist (migration notes, audit B).
This purge shouldn't leave anything like that. Phase 8 checks for:

- **In code:** `legacy`, `fallback`, `earlier model`, `today's` (and `(today)`), `off by
  default`, `switch on` / `switch off` / `with the switch`, `--connections`,
  `--legacy-model`, `_legacy`, `native`, `Insight spillover`, `headline` (after phase 6),
  `premise_shaping` / `PREMISE_SHAPING_TYPES` (rename to what it is now, a stored case's
  premise types). Each hit is fixed, or listed in the PR with why it stays.
- **Reports and logs:** any dev-log key, Why report line or `case_summary` field that names
  the connections model as an option ("connections on") or the earlier model as current.
  `replay_log --time` prints "(connections on)" (`replay_log.gd:115`).
- **Test headers** that still say "pinned to the earlier model".
- **Docs:** `DESIGN.md`'s belief section (bounded attention, Insight-scaled spillover, the
  Insight row "swayed by headlines"; around lines 620, 649, 671); `README.md`'s code map;
  `docs/DECISION_INSPECTOR.md` ("x0.5 a day", stored-case replacement);
  `docs/premises_plan.md` ("Suspicious = half-weight hearing plus pressure", around line
  343); `tuning_catalogue.md` (`SUSPICIOUS_HEARING` row); `docs/balance_sweep.md`;
  `docs/belief_model.md`'s status line and "today" note. My final handoff lists these.
- **`sim/tuning.gd` comments**, then `python3 tools/tuning_index.py`.

## 6b. Where this touches NPC behaviour (for Claude-Beadle)

Claude-Beadle owns what NPCs do with their beliefs (`sim/mind*.gd`, `sim/evil.gd`). The
purge changes belief, not how belief turns into action, but these phases touch that side:

| Phase | What touches NPC behaviour |
|---|---|
| 3 | `sim/mind_meeting.gd:1431` `remember_nomination`: the `Connections.enabled` guard goes, so storing a nominator's cited cards as a case becomes unconditional. Same behaviour as play today |
| 6a | `workshop/reason_attribution.gd:111, 204-215`: low-Insight NPCs stop citing readings they aren't attending to. This changes what NPCs say in accusations, nominations and defences (`MindMeeting.case_against`, `reason_status`, `nomination_case`, `defend_self` read these reasons). Reply stances to presentations may change too |
| 6b | Suspicion moves in some games, so votes and nominations can follow. No code in `sim/mind*.gd` changes |
| 8 | Comments only in `sim/mind_meeting.gd` ("off by default" at `:1426`) |

Nothing in the plan touches `sim/evil.gd`. I'll tag Beadle on the phase 6 PRs before they
merge.

## 7. Decisions for Michael

1. **Old logs.** After phase 3 a log from before #160 can't be replayed on the earlier model.
   (The two playtest logs, 44542 and 97626, already don't replay faithfully on main since
   #149 and #152.) **Recommendation:** accept it; the replay tools say so and stop. Keep
   writing `connections: true` in `case_start` so the tools can tell old logs from new.
2. **The comparison baseline.** With `--legacy-model` gone, an A/B against the earlier model
   means running a frozen commit. **Recommendation:** a snapshot branch
   `archive/legacy-belief-final`, as the solver retirement did with
   `archive/gdscript-solver-final`. I would push it; only you delete branches.
3. **The headline reading outside refreshes** (section 2, first two rows). It still shapes
   reply stances, the Test juror, the ghost juror, the secret-claim check at dawn, and what
   low-Insight NPCs cite. **Recommendation:** remove it everywhere (phase 6a). Insight is out
   for v1, and the Test juror would then match the town's own judgement more closely. This
   changes what NPCs say and moves golden.
4. **The four places attention still feeds belief on a refresh** (section 2, third row).
   **Recommendation:** read the held cards (phase 6b), which is what "attention picks what is
   cited, not what is believed" says. It moves suspicion in some games and moves golden. I
   would measure how often each one differs from the held-card version before building it,
   and report that first.
5. **Behaviour you set explicitly that goes with the switch.** Each is only reachable with
   the switch off now, but you decided each one, so I'm asking rather than assuming:
   spillover damping by Insight (premises step 1); "suspicious" as a half-weight hearing
   of its cards with pressure from the held-back half (premises step 2; you released it only
   for connections, Nov 14); the earlier Why report. **Recommendation:** delete all three in
   phase 5.
6. **What Insight does after the purge.** With the headline gone, Insight only sets how
   many cards an NPC attends to (what it cites) and how fast cards fade from attention. It
   no longer changes belief. DESIGN's Insight row needs new wording, which is yours; I'll
   draft it in phase 8.
7. **Older leftovers** (1d and the migration audit). **Recommendation:** phase 7 for the
   pre-CaseEval engine and the attention experiments. Also fold audit B's belief-related
   items into phase 8: the mislabelled `legacy_fallback` reporting, `legacy_evidence`,
   `fallback_count`, and the Workshop canvas's `"mode": "legacy"`. If you'd rather Steward or
   Bailiff took audit B, I'll leave it.

## 8. Small calls I'd make myself

These are mine if you've delegated the batch. I'll list them again in each PR that uses
them.

- The phase order above, and splitting phase 6 in two.
- `--connections` stays accepted as a no-op for one release after phase 3, with a note in
  its help text, so saved sweep commands keep working. `--legacy-model` fails with a message
  pointing at the snapshot branch.
- The sweep workflow's cell validator drops `_connections` from its help text and keeps
  accepting it as a no-op, like the flag.
- `fixture_seeds` keeps its seed range; if a scenario stops being found under connections,
  widen the range for that scenario rather than pinning the model.
