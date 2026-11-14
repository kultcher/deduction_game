# Agent handoff log

Shared notes between Claude (checks, tests, Git) and Argon (main coding). Newest entry
first. Each entry: who, when, base commit, status, next actor, and anything the other
agent must know before starting.

Who's who (from Nov 4 evening): sign each entry with your name. **Argon** (Gemini, main
coding, patches on Drive); **Claude-Bailiff** (checks, tests, Git, meeting overhaul);
**Claude-Quill** (dynamic scripts, integrating patch_013); the balance-sweep Claude (name
to come). Sessions don't share memory: this log is how we talk.

Explaining a playtest (why the town voted, read a case or believed something): replay the
log with `tools/replay_log.gd --why` and `tools/explain_case.gd` before reading code or
guessing. See `docs/DECISION_INSPECTOR.md` and the 2026-11-05 Claude-Tally entry below.

Ground rules (from Nov 3, until Michael changes them):

- Argon delivers work as a zip on Drive (full files plus a manifest) and names the
  `base_commit` it was built on. Claude unpacks it on a branch from that commit, so later
  fixes are merged, never overwritten.
- `main` only moves when everything is green: `dotnet build`, the selected suites, and
  (from C1 on) a golden capture identical to the current baseline (`BASELINE` in
  `.github/workflows/ci.yml`; `docs/golden_baseline.md`) at `--tol 0`.
  Otherwise the work stays on its branch and the entry says why.
- Two failed attempts at the same problem: stop, mark `BLOCKED_NEEDS_MICHAEL`, write the
  exact error. No force pushes, nothing irreversible.

---

## 2026-11-14 early, Claude-Lantern: a case the listener bought fades slower (PR #153, `claude/connections-buyin`, stacked on #151)

- **Base:** `claude/connections-cache` (#151, itself on #150). **Status:** PR open, for Bailiff, after those two. **Next actor:** Bailiff; Michael for the one question below.
- **From:** the triage doc, 4.3. Michael picked buy-in over a flat 0.7 (Nov 13 evening). Switch on only.
- **Golden:** identical to `baseline_4a1a075` with the switch off (5 seeds). Fast list 56 of 56.

**The rule (`workshop/connections.gd`: `buy_in_rate`, `case_plan`)**

- A stored case from an earlier day keeps between 0.5 and 0.9 of its weight a day (`CONNECTIONS_CASE_FADE`, `CONNECTIONS_CASE_FADE_BOUGHT`), by how far it moves that listener: the largest move its cards make together on anyone, standing alone, at the weight it had the day it was presented, against 0.7 log-odds (`CONNECTIONS_CASE_BUYIN_FULL`). At or over 0.7 it fades slowest.
- Nothing is stored. The rate is read again at each refresh, so it follows what the listener holds now. It costs one judgement per older case, and the cache keeps it.
- **Different from what was measured in #150:** there the move was what the case added after the reuse rule, so a repeat of the same cards faded at a half. Now it is the case's own cards standing alone, so a repeat fades like the original. On 44542 the result is the same (below).
- The rate is set before the "at least as much" test for replacing a case, so that test compares the weights as they stand today.
- `stored_with` (NPC nominators' cases) keeps a case while it could still count at the slowest fade: 28 days, against 4.
- `Connections.buy_in` (on in play) turns it off for measuring. The arithmetic tests on chosen numbers run with it off.
- The Why report shows the rate a case keeps a day.
- **The prototype tool follows the game:** its first fade is now buy-in through the same rule (`fades = [buy-in, 0.5, 0.7]`).

**44542, in the game** (chance Fenwick is evil; "Fenwick is good" was presented on day 1)

| Listener | Evening of day 1 | Dawn of day 2, before (0.5 a day) | Dawn of day 2, now |
|---|---|---|---|
| Greta | 18% | 24% | 20% |
| Hollis | 13% | 19% | 15% |
| Jory | 19% | 33% | 27% |
| Kiran | 22% | 37% | 31% |

- The case keeps 0.86–0.9 a day for these four. What is left of the overnight rise is other cards arriving.
- By the vigil on day 3: Greta 39% (43% before), Jory 41% (46%), Kiran 12% (15%).

**For Michael:** it applies to NPC nominators' cases as well as the player's, since both are stored cases. If NPC cases should keep the flat 0.5, it is one condition.

- **Tests:** `test_connections_cases` (106 checks; the rate on chosen numbers, a day on in a game), `test_connections_why`.

## 2026-11-14 early, Claude-Lantern: kept judgements, step 6 (PR #151, `claude/connections-cache`, stacked on #150)

- **Base:** `claude/connections-case-rules` (#150) with main `9cded67` merged in. **Status:** PR open, for Bailiff, after #150. **Next actor:** Bailiff.
- **From:** the triage doc, 4.1. Switch on only.
- **Golden:** identical to `baseline_4a1a075` with the switch off (5 seeds). Fast list 56 of 56.

**What it does (`workshop/connections.gd`: `judge`, `judge_key`, `_kept`)**

- Each listener keeps the answers to the judgements it has made. `judge` hands a kept answer back when everything that judgement reads is the same, and makes it otherwise.
- **The key is what a judgement reads, not the whole input.** A whole-input key almost never hit: the view's card list, trust figures and attention's bookkeeping change at every step without touching the answer. The key is:
  - the view without its cards, and the timeline without the meeting's talk (nominations, votes, accusations, readings) unless a judged card is a Magistrate's, the one gift that reads it;
  - the judged cards, and the listener's own-report cards;
  - the case template;
  - the listener, with reading reliability for the judged cards only, without `presented_reports`, `attention_reports`, `trust` and `player_credibility` (the last two only weigh stored cases, outside the judgement);
  - the Hexer switch and the set.
- **Why that is safe:** the judge reads view cards only through `Solver.selected` and `card_by_id` on the listener's ids; `TraceSolver` and `Circumstantial` are not on its path; only `Solver._magistrate_nomination_ok` reads meeting events. And it is checked, not assumed: `Connections.cache_verify` makes every kept answer be judged again and compared.
- Kept answers are slim (`impossible`, and each person's prior and posterior), up to 6,000, cleared with the other caches (`Caches.clear_all`). A caller that wants the worlds (`CaseEval.capture_worlds`, the prototype tool) always gets a real judgement.
- `Connections.cache_enabled` turns it off for measuring. The profiler counts `connections_kept`.

**Beliefs are the same**

- 12 bot and passive games replayed with `cache_verify`: 28,644 kept answers judged again, 0 different.
- Both playtest logs replayed with the cache on and off: the same suspicions for every NPC and the same dev log (915 and 1,283 records).
- The suite plays two passive games three ways (off, on, checked) and compares suspicions and the dev log.

**Timing, cache off → on** (this machine, 2 cores, one job at a time; switch on in both)

| | Off | On |
|---|---|---|
| 44542 replayed whole | 193 s | 96 s |
| 97626 replayed whole | 282 s | 144 s |
| 44542 `present 39` (day 1) | 4.0 s | 2.7 s |
| 44542 `nominate odette #40` (day 1) | 6.5 s | 3.2 s |
| 44542 `press role` (day 1) | 2.3 s | 1.6 s |
| 44542 `present 89` (day 2) | 7.8 s | 3.7 s |
| 44542 `nominate odette #89` (day 2) | 5.3 s | 1.8 s |
| 97626 `nominate dorian #92` (day 2) | 13.6 s | 6.9 s |
| 97626 `present 145` (day 3) | 11.4 s | 7.1 s |
| 97626 `nominate jory #145` (day 3) | 10.1 s | 5.0 s |
| 44542 `gossip` (day 1) | 4.8 s | 4.4 s |
| 44542 `ward hollis` (the night into day 2) | 14.9 s | 10.9 s |
| 97626 `vigil square` (a night) | 18.2 s | 11.8 s |

- 70% and 73% of judgements in the two games are kept ones.
- Golden seed 692 with the switch on: 239 ms a refresh (382 on #150 without the cache; 93 with the switch off).
- I did not reproduce Bailiff's 26 s and 34 s for day 3–4 of 44542; that replay ran alongside another job.

**What is left: the spec's cost bar is not met.**

- The cache halves a game, but a late presentation is still 4–7 s and a night 11–21 s. What remains is first-time sets: a new card, a new day, a death or a change of trust in a teller makes that listener's judgements new, and dawn changes all of them for everyone.
- A first-time judgement costs 9–25 ms, spread over building the worlds (2.4 ms), compiling the set (2.7) and the sum (2.9) for a single card. No one part dominates, so there was no quick win; raising `CaseEval`'s compile cache from 32 to 4,096 barely helped.
- **Next options, not built:** (1) judge single cards for all listeners at once from one world table per day, since most of a refresh is one card's own value; (2) spread dawn's refreshes over the night screen; (3) skip the core test for items whose cards and seed did not change since yesterday except for the day number.
- Also seen: `trust_reward/jury/headline` takes 0.8 s in a nomination. It is today's code still running under connections, where the headline reading is off.

- **Tests:** `test_connections_cache` (32 checks, 66 s; in the fast list).

## 2026-11-13 night, Claude-Lantern: stored cases don't stack on reused cards (PR #150, `claude/connections-case-rules`)

- **Base:** main `9cded67` (merged in after #149). **Status:** PR open, for Bailiff. **Next actor:** Bailiff to check and merge; Michael for the fade (4.3).
- **From:** the triage doc, 4.2 and 4.4 (Michael's decisions, Nov 13). Switch on only. 4.3 (the fade) is measured here, not built: it waits for his pick.
- **Golden:** identical to `baseline_4a1a075` with the switch off (5 seeds), after merging main. Fast list 55 of 55.

**The rules (`workshop/connections.gd`: `case_plan`, `case_step`, `interaction`)**

- **4.2, per presenter.** A case that cites every card of an earlier one from the same presenter, and counts at least as much, takes its place: the earlier one stops counting, and the set counts once at the later case's weight. A weaker one (a "suspicious" premise on cards already argued firmly) leaves the earlier case in place and adds only what is new, so the cards keep the larger of the two weights (Michael, Nov 13 evening). It goes by the cited cards; the premise is not compared. Otherwise a case adds nothing for what an earlier one already put together; only what involves a card new from that presenter counts. It applies to NPC nominators as well as the player.
  - Nothing is removed from the presentation store. The rule is applied when the cases are weighed, so today's model (switch off) is untouched.
  - One shared card takes nothing off: what it says next to a new card is new.
- **4.4.** Cards a case cites from the movement connection add only what they say next to the case's other cards. Their meeting each other is already counted, in full, by the movement connection. A case made only of such cards adds nothing as a whole.
  - **The Hexer's day connection needed nothing.** A case never included it: every judgement runs with the Hexer factor off, and the day connection is the only place that factor is read (step 2).
- `case_step` holds the rules as joint sets to weigh, so the game and `tools/connections_prototype.gd` share them.
- `Connections.reuse_rule` and `held_together_rule` (on in play) switch each rule off for measuring. A kept refresh doesn't know a switch moved; clear `g._workshop_evaluations` after flipping one.
- **The Why report** says when a case took another's place, when it was replaced, and how many of its cards an earlier case already held.

**What they change**

- **44542, day 1.** #40 "Odette is suspicious" cites the same four cards as #39 "Fenwick is good", so it replaces it:

  | Listener | The cases' part on Fenwick, before | With the rule | Chance Fenwick is evil, before | With the rule |
  |---|---|---|---|---|
  | Greta | -1.02 | -0.34 | 14% | 24% |
  | Kiran | -1.02 | -0.34 | 17% | 28% |
  | Hollis | -1.10 | -0.37 | 10% | 18% |
  | Nisha | -1.29 | -0.43 | 11% | 22% |
  | Jory | -1.16 | -0.39 | 14% | 25% |

  That table is the first version, where the later case always took the earlier one's place: the half-weight #40 took back half of what #39 did. **Michael's call (Nov 13 evening): the cards keep the larger of the two weights.** With that built, #40 leaves Fenwick where #39 put him: Greta 18%, Hollis 13%, Jory 19%, Kiran 22%.
- **A "suspicious" case presses its subject again (switch on).** Step 4 left this out without saying so: the pressure read a number only today's model fills in, so it was always zero with the switch on. Now a "suspicious" entry carries `withheld`, what its held-back half would add standing alone (whatever an earlier case holds of its cards), and `WorkshopPresentation._connections_rise` turns that into the rise in the target's chance. The rest is as before: the average over the listeners, × 1.0 at a meeting or 0.5 in private, once per filing. In 44542, #40 gives Odette +0.005: those cards say almost nothing about her.
- **Six bot games (72 listener-presentations, walker-only scripts):**
  - 4.2 changes no chance by more than 1 point. The bot rarely re-presents the same cards.
  - 4.4 changes the target's chance by more than 1 point in 9 of 72, the largest by 12. The case's own part on its target is over 0.5 log-odds in 8, against 14 before.

**4.3, the fade, measured only**

- **Buy-in version tried:** a case keeps between 0.5 and 0.9 of its weight a day, the more the further it moves that listener (its largest move on anyone, at trust, against 0.7 log-odds). Nothing is stored; it is re-judged each refresh.
- **Bot games, from a presentation to the next dawn (43 pairs):** against 0.5 a day, the target's chance differs by 0.3 points on average under 0.7 a day (largest 2.3) and 0.3 under buy-in (largest 4.4). The bot's cases mostly leave their target near certain, so the fade has little to move.

**Both playtest logs, replayed whole with the switch on** (8 cases, 67 listener-presentations; the replays reach the logs' vote tallies)

- Measured on the first version (a later case always replaces), before main's #149 was merged in. After #149 the 97626 log no longer replays faithfully (passive play moved), so its figures were not redone; 44542 was, and the final rule's figures are marked.
- **What was replaced:** in 44542, #89 replaces #39 and #40 (under the final rule #40 no longer replaces #39); in 97626, #145 "Jory is evil" replaces #31 "Jory is suspicious".
- **Per presentation,** the mean over its listeners of the target's chance, and of all the player's cases' part on the target (log-odds):

  | Case | Target's chance: before, 4.2 only, 4.4 only, both | Cases' part on the target: before → both |
  |---|---|---|
  | 44542 #39 Fenwick is good (day 1) | 20.5%, the same under each | -0.62 → -0.62 |
  | 44542 #40 Odette is suspicious (day 1), final rule | 51.6%, 51.1%, 51.6%, 51.1% | +0.12 → +0.10 |
  | 44542 #89 Odette is evil (day 2) | 53.1%, the same under each | +0.10 → +0.10 |
  | 44542 #131 Jory is suspicious (day 3) | 78.8%, 78.8%, 76.2%, 76.2% | +0.17 → -0.03 |
  | 97626 #31 Jory is suspicious (day 1) | 53.4%, the same under each | 0 → 0 |
  | 97626 #92 Dorian is a Minion (day 2) | 6.7%, the same under each | +0.09 → +0.09 |
  | 97626 #145 Jory is evil (day 3) | 93.8%, 93.8%, 92.8%, 92.8% | +0.55 → +0.38 |
  | 97626 #175 Kiran is evil (day 4) | 96.4%, 94.6%, 96.3%, 94.6% | +1.29 → +0.99 |

- **The rules move a case's target little.** The large moves were on Fenwick, from stacking: before the rules #40 took him from 18% to 14% for Greta by counting the same four cards a second time.

**4.3 on 44542 under the final rule, and the pick**

- Chance Fenwick is evil, after "Fenwick is good" and at the next two dawns, by fade:

  | Listener | After #39 and #40 (day 1) | Dawn of day 2: 0.5 / 0.7 / buy-in | Dawn of day 3: 0.5 / 0.7 / buy-in |
  |---|---|---|---|
  | Greta | 18% | 24 / 22 / 20% | 43 / 40 / 39% |
  | Hollis | 13% | 19 / 17 / 15% | (dead) |
  | Jory | 19% | 33 / 30 / 27% | 46 / 43 / 41% |
  | Kiran | 22% | 37 / 34 / 31% | 15 / 13 / 12% |

- 0.7 a day takes back 2–3 points of the overnight rise, and buy-in 4–6. The rest of the rise is not the fade: other cards arrive overnight (Isolde's Archivist reading names Fenwick as one of two Scion candidates).
- For these listeners the buy-in rate is 0.86–0.9 a day; for a case that moved a listener little it stays 0.5.
- **Pick: buy-in.** It is what Michael described (a conclusion the listener bought lasts; one it didn't fades as now), it does about twice what 0.7 does where it matters, and it stores nothing: the rate is re-read from the case's own move at each refresh. 0.7 flat is the simpler fallback. Not built: it waits for his word.

## 2026-11-13 late, Claude-Bailiff: seen talking gives each talker a sighting (`claude/talk-sightings`)

Triage 1.7 (Michael): a conversation the player sees gives three cards, each talker's own
sighting and the talk. `GameScreens._card_conversations` adds the two sightings; they share
the fact id of a sighting from visiting the spot, so they merge. This reverses the Oct 27
backlog item "conversation sightings should also cover location sightings" (Michael, Nov 13).
Test: `test_mechanics_sightings._talk_sightings`. 150/150 suites; golden re-baselined
(`baseline_b281427`, board only).

Held on `claude/warden-night0`: the Warden doesn't guard on night 0 (7.1). It breaks five
seed-trajectory fixtures (test_self_sighting, test_relay_bluff, test_connections_core,
test_connections_pairings; test_prior_mapping's seed already swapped), which need new seeds.

## 2026-11-13 night, Claude-Bailiff: playtest quick fixes and NPC wording (`claude/playtest-fixes`)

From the Nov 13 triage (Project doc `claude/playtest-triage-2026-11-13.md`), sections 1 and 2.1-2.4.

### Changes

- **1.1** `Social._gossip_items` and the NPC relay skip a secret whose `with` is the teller.
- **1.2** `MindMeeting.defend_self` takes the hinge only from items the case cites (`in_case`).
- **1.3** `C.package_roles_text` lists only roles on the case's script in role hints; the
  facts keep the full package (`live_assessment` validates against it).
- **1.4** The burned totem's "seek a new hiding place" only while the Revenant lives.
- **1.5** The grimoire notes who the Revenant turned, and whether the totem freed them.
- **1.6** The curse "When" field only on `evil` / `suspicious` / `good` premises
  (`LiveCaseWorkshop.EPOCH_TYPES`). A Scion before/after option doesn't exist yet; backlog.
- **1.8** `Social.approach_candidate(w, skip_id)`: last phase's talk partner can't approach
  (their noise draw still happens). The finished talk's view stops at the next header.
- **2.1** `ReasonAttribution` joint lines: direct readings are set against the claimed gift,
  indirect ones "leave them among the likeliest", the Warden names whom they guarded, a pair
  naming the listener uses self-knowledge; the off-block one-sided Surveyor line.
- **2.2-2.4** Defence hinge wording; Hollis's and Nisha's "premises" lines.
- **Not done:** 1.7 (waiting on Michael: which card was missing), 2.5-2.8.

### Result

- All suites pass (150/150 after updating two text checks).
- Golden moved: new `baseline_4a1a075`, see `docs/golden_baseline.md`. Two captures identical.

## 2026-11-13 evening, Claude-Lantern: the Why report under connections, and what a refresh costs (PR #148, `claude/connections-why`)

- **Base:** main `c889b3c`. **Status:** PR open, for Bailiff to check and merge. **Next actor:** Bailiff, then Michael (caching, step 6, is his call to start).
- **From:** Bailiff's note on Michael's first playtest with the switch on (case 44542, 10 NPCs, day 1). Michael asked for the logging and profiling parts only; the "same cards under a second premise" question (item 3) is untouched.
- **Golden:** identical to `baseline_6a22cac` with the switch off (5 seeds, `--tol 0`). Fast list 55 of 55. A capture with the switch on runs with no script error.

**1. The Why report (`game/workshop_why.gd`)**

- With the switch on, `WorkshopWhy.presentation` returns a different report (`_connections_report`, `model: "connections"`). It is read from the breakdown the applied refresh stored and the one before it; nothing is re-run. None of today's stages are in it (attention, change of view, already held, headline).
- `WorkshopWhy.before(n, g)` now takes the game, so it can keep the listener's last connections result and stored suspicion. `game_presentation.gd` and `explain_case.gd` pass it.
- It follows the premise's subject and whoever the case's own part moved most (up to three people). Per person, before and after, in log-odds: where they start, this case's cards each alone, every other card, the core, this case weighed together, other stored cases, the common shift. Those add up to the chance.
- Also: the case's weight in its parts (trust, fading, the "suspicious" halving), whether it was weighed with the core, each of its cards alone (pairings named), the core's seed and members, suspicion as stored and as the game reads it, the action bars, and the premise chain (unchanged).
- **On Michael's game it now says what Bailiff's replay found:** Greta on "Fenwick is good", chance 32% to 18%, suspicion +0.07 to -0.18, the case weighed together -0.68 at weight 0.50. On #40 ("Odette is suspicious", the same four cards) it says the chance on Odette stayed at 34% and that, weighed together, the cards fell on Fenwick (-0.34 at weight 0.25).
- **Cost:** 19 reports took 14.7 s; they take 2.5 s. The model's part is about 3 ms a listener. The rest is the premise chain, whose per-world checks are now kept between listeners (`CaseWhy._masks`, cleared with the other caches): the first listener of a case pays about 0.4 s at 10 NPCs, the others about 0.09 s. That change also speeds the report with the switch off; its text is unchanged (`test_workshop_why` passes as it was).
- The dev log's `workshop_why` record has a different shape with the switch on (`model`, `parts`, `case`, `cards`, `core`). Nothing in the repo reads the old shape from a log.

**2. Logging and profiling**

- `case_start` says `"connections": true` when the game is played with the switch on, and the replay tools turn it on from that. Off, the record is as it was. `replay_log.gd` and `explain_case.gd` take `--connections` for logs from before this (Michael's log is one).
- `replay_log.gd --time` prints each command's time; `--profile` adds the profiler's spans and counters. The model's refresh has spans of its own (`connections/baseline`, `items`, `core`, `cases`) and a `connections_judgements` counter.
- `Connections.capture` (off) records every judgement: listener, part, the set judged, time, a hash of the answer.

**3. Where the time goes in case 44542 (this machine; Bailiff measured 4.3, 7.5 and 2.6 s)**

| Command | Switch off | Switch on | Belief refreshes | Judgements (time) | Of those, repeats with the same answer |
|---|---|---|---|---|---|
| `gossip` | 0.8 s | 3.9 s | 17 | 268 (3.1 s) | 45 (0.4 s) |
| `present 39` | 2.0 s | 3.3 s | 10 | 168 (1.6 s) | 118 (1.1 s) |
| `nominate odette #40` | 2.2 s | 5.4 s | 19 | 307 (2.8 s) | 307 (2.8 s) |
| `press role` | 0.2 s | 1.9 s | 9 | 163 (1.5 s) | 147 (1.4 s) |

- A refresh makes about 17 judgements, nearly all of them one card's own value, at 9 to 11 ms each. The time is setup for each set of cards, as step 1 found (`CaseEval`'s compile cache holds 32 and is emptied within one refresh).
- "Repeats" are judgements the same listener had already made that day with an identical answer. A cache kept per listener would skip them: all of the nomination's, nine in ten of `press role`'s, two thirds of the presentation's.
- What a cache can't skip is a set seen for the first time. `gossip` is that case: 212 new sets (2.6 s), 76 of them core tests (1.2 s).
- The nomination runs 19 refreshes: one per listener for the presented case, then one each when the nomination case is stored (#146's follow-up, 71c0482).
- Outside the judgements, a refresh with the switch on carries 35 to 40 ms of its own against today's 27 to 31 ms.

- **Tests:** `test_connections_why` (new, in the fast list): the report's "after" chance is the refresh's posterior and the parts add up to it; the weight's parts; switch off unchanged; the log flag; kept masks give the same answer; capture and the profiler change nothing.
- **Docs:** `docs/DECISION_INSPECTOR.md` ("With the connections model on", and the replay tool's `--time` and `--profile`).

## 2026-11-13 later, Claude-Lantern: the connections model in game, step 4, stored cases (PR #146, `claude/connections-cases`)

From Michael (Phase 6, step 4). Spec: Project doc `claude/belief-model-direction-2026-11-10.md`, "Phase 6 spec", stored cases. Base: main `eece565` (steps 1 to 3 merged). Behind the switch, which is off: golden is identical to `baseline_6a22cac`.

- **What a stored case is** (`Connections.cases`): a case someone put to the listener. Its cards are judged together, and it adds what they say together beyond their own values, times its weight.
  - **Weight** (`Connections.case_weight`): trust in the presenter (the player's credibility, or the listener's trust in the NPC), × 0.5 for each day since (`Tuning.Workshop.CONNECTIONS_CASE_FADE`), × 0.5 under a "suspicious" premise, and nothing under 0.05 (`CONNECTIONS_CASE_FLOOR`).
  - **With the core:** a case sharing a card or pairing with the core is judged with it as one set, older cases first. The core's own part counts in full; what the case adds on top is weighted. A card cited from an always-on connection never merges.
- **The player's presentations.** The presentation store is the case store: `Shared.prepare` turns each presentation it is given into a case (its endorsed cards, premise, challenges, and the day from the snapshot's `now`) on `listener.connections.cases`, only when the listener carries `connections` (the switch on). So a with-and-without evaluation that passes different presentations weighs different cases.
- **NPC nominators' cited cards** (new store, `workshop_state.connections.nominations`): `Mind.remember_nomination` keeps the cards `recall_cited` brought back, for every living listener but the nominator. The same nominator's later case about the same person replaces it; one too old to count is dropped. Nothing is kept with the switch off.
- **Challenges act inside their own case** (`Connections.lean_challenged`): `ReadingChallenges.assess` runs on the case's set alone, and an accepted "misled" or "failed gift" discounts the reading there and nowhere else. "Lying" changes no reliability. The two floors a challenge puts under people (`Jury._consequences_eval`) come from the case's own assessment, scaled by the case's weight.
  - **Open, for Michael:** an NPC defender's challenge isn't in any stored case. It keeps today's floor and does nothing else.
- **Presenting a case again on a later day restores its weight.** `WorkshopPresentation._present` no longer waves that repeat off, and a public repeat is assessed again when the case has faded for anyone (`WorkshopPresentation.faded`). The spoken reply is today's code and may still say "my assessment is unchanged".
- **Spillover damping is off with the switch on** (`Shared.premise_shaping` returns nothing for a listener that carries `connections`).
- **A correction to the prototype's arithmetic:** when the core holds the movement connection and a case cites a movement card, that card's own value was taken off twice. `Connections.interaction` counts it where it sits. With that one change switched off, the tool's output is identical to before; with it, 4 of 93 dawn rows and 27 of 158 vote rows move (all listeners whose core holds the movement connection).
- **The prototype tool** takes which cases count, their order and weight from the module (`Connections.case_plan`). It still reads only public presentations and nominations from a log, and doesn't weigh challenges.
- **An error in steps 1 to 3, fixed here (switch on only).** The model's baseline is a judgement on no cards. In play a case with no cards reads every day card on the view for "who was near each silencing" (`DayPresence.breath_factor`), while a judgement with one card or more reads only its own. So in a game with a silencing, every item's value carried the difference, once per item. `DayPresence.bare_reads_view` (on in play) is switched off for the model's judgements, and `CaseEval`'s compile key covers it. Golden with the switch off is unaffected.
  - Found on seed 962: a presentation of "Kiran is evil" took Greta on Kiran from 0.91 to 0.55 (now 0.93 to 0.93). The no-card baseline had Kiran at 0.612 and every other judgement started from 0.579, a 0.14 log-odds offset on each of 24 items.
  - Six of the 22 passive games have a silencing (902, 911, 923, 924, 927, 928). In those, 51% of chances were within 5 points of today's before the fix and 63% are now; the other 16 games are unchanged to the last digit. Step 3's figures over all 22 move a little: within 5 points 55% to 59%, over 20 points 17% to 15%, separation at 10 NPCs 0.45 to 0.47. One of the 16 Hexer logs has a silencing (955); step 2's Hexer figures aren't re-run.
  - `test_connections_core` holds it: the no-card judgement is the same with and without a day card on the view, play still reads it, and the two don't share a compiled case.
- **In game against the tool** on the same listener states (15 logs, 586 listener-moments, 1,934 stored cases of which 516 are the player's): the same cases count, in the same order, and chances agree to 0.000004. The bot never challenges, so challenges inside a case are covered by the suite only.
- **A presentation, with and without** (six bot games played with the switch off, 18 cases, 72 listener-presentations):
  - The target's chance, on average: 0.54 before, 0.68 once the cards the case brought are held, 0.70 with the case weighed. So most of what a presentation does is bring cards (57 of 72 brought one). The case's own part raises its target by more than a point in 29, lowers it in 1, and leaves it within a point in 42.
  - No presentation lowers its target by more than 2 points (two do by 1 to 2, from a brought alibi's own value). Before the baseline fix 10 of 34 did, by up to 36.
  - People the case didn't name move more than 3 points in 18 of 72. In all 18 the brought cards do it by themselves (a new night card is read with its whole night or the movement connection, and a target that becomes near certain takes an evil place from everyone else). The case's own part does it in 2, both one case in seed 963.
  - Presenting the same case twice changes nothing (72 of 72).
- **Open, for Michael: under a Walker reading a case of night cards counts their meeting twice.** The movement connection already weighs every night card together, in full. A case citing two or more of them adds what those cards say together again, at its weight. In the six bot games (all walker-only scripts) that is 25 of 72 listener-presentations, and the case's own part on its target is over 0.5 log-odds in 9 of them (largest 2.2). This is the prototype's arithmetic, unchanged.
- **Cost with the switch on:** golden seed 692 takes 424 ms a refresh (411 at step 3; 93 today). Caching is next.
- **Tests:** `test_connections_cases` (in the fast list, 54 of 54). Golden with the switch off is identical to `baseline_6a22cac` on all five seeds; a capture with the switch on runs with no script error.

**For Bailiff, three things in main's behaviour with the switch off** (the first two found tracing seed 929; Michael asked me to leave them with you; details in the Project doc's open items):
1. **A relayer can be cut from the sighter contest by the two-sighter cap** (`LiveActivity._sighting_contests`, `SIGHTER_CONTEST_MAX`). Sighters are ranked by how many sightings of the person they told, then by town order. An evil Medium who invented one relayed sighting ranked below a Night Watch with two reports and the dead source, so the invention counted as the dead person's honest word.
2. **An evil Medium's relay about the first victim names night 0** (the bluff says the dead saw the scapegoat out "on their last night"). The movement model's Demon never leaves home on night 0, so the frame lowers suspicion of its target.
3. **A case with no cards can be answered from an older compile** (found here, not from the trace). With a silencing on the record it reads the view's day cards (`DayPresence.breath_factor`), but `CaseEval`'s compile key doesn't include the view's cards. On seed 962 the same inputs gave Kiran 0.612 with every cache cleared and 0.579 from a warm one. Not changed; it could move golden.

Next: caching (step 6), then the seven criteria end to end.

---

## 2026-11-13, Claude-Lantern: the connections model in game, step 3, the core (PR #145, `claude/connections-core`)

From Michael (Phase 6, step 3). Spec: Project doc `claude/belief-model-direction-2026-11-10.md`, "Phase 6 spec" section 4. Results: the same doc, "Results: Phase 6 step 3". Base: main `437e29e` (steps 1 and 2 merged as #141 and #144).

- **The core** (`Connections.core`). The seed is every item holding a card the listener knows firsthand (`Connections.firsthand`): its own readings, and a sighting of it on a night it knows it spent at home. Every other card or pairing is tested against the seed only and joins at 0.4 (`Tuning.Workshop.CONNECTIONS_CORE_JOIN`): what the two say together, less what each says apart, for any one person. The core then adds what its members say together beyond their own values. Always-on connections are never tested.
  - A night seeds the core when it holds the listener's own Night Watch or Lamplighter report (decided Nov 11) or a wrong sighting of it (Michael, Nov 12). Under a Walker reading the movement connection does instead. The Hexer's day connection never does.
  - **Wider than the prototype's seed:** a pairing holding one of the listener's own readings (its own Augur day or Psychologist reading) is a seed too. The prototype only seeded own readings that sat alone.
  - The test leaves out what a pairing's context says alone. With a seed that has no context (the prototype's) it is the prototype's test exactly.
- **Memory** (`n.workshop_state.connections.core`: day, seed, firsthand cards, members, the cards held). The core is rebuilt on a new day and when the firsthand cards change. Otherwise its members stay, and only an item with a newly held card is tested. So a presentation can't edit the core; a card it brings is tested like any newly heard card.
  - `Bridge._listener` hands the day and the memory to the listener (`listener.connections`) only when the switch is on. `LiveAssessment._listener` passes it through. `Jury._consequences_eval` gives it to `Connections.refresh`.
  - Only the applied refresh writes it (`Ownership._refresh`), the way theory memory is committed; replies, the why tool and previews read it and leave it alone. The cached input carries the committed memory, so a refresh with nothing new is still a cache hit.
  - With the switch off none of this exists: no `connections` key on a listener or in `workshop_state`. Golden is identical to `baseline_6a22cac`.
- **Firsthand proofs stay proved.** If the firsthand cards alone put someone within 0.5% of 0 or 1, that person keeps that chance, and the others share what is left of the evil count (`Connections.combine`).
- **`Connections.seed_wrong_sightings`** (tests and tools only; on in play) turns the wrong-sighting seed off, to measure it.
- **The prototype tool** takes its seed, test and membership rule from the module. `--legacy-seed [--movement-seed]` keeps the first prototype's seed: with it the tool's output on seeds 900, 902, 910 and 911 is identical to the tool before this change. `--no-wrong-sightings` and `--no-proofs` switch off the two new rules.
- **In game against the tool** on the same listener states, at every dawn and vote (14 logs, 482 listener-moments): seeds, members and chances agree.
- **The wrong-sighting seed, measured:** rare in passive play (3 of 469 listener-dawns, no chance moved by more than 2 points). On seed 100034 it takes Odette on the evil sighter Constance from 0.52 to 0.66, which is today's figure; a real Sleepwalker's suspicion of an honest sighter goes 0.15 to 0.18 (seed 100031).
- **Cost with the switch on:** golden seed 692 takes 411 ms a refresh, against 293 at step 2 and 92 today. Caching is the last step.
- **Tests:** `test_connections_core` (in the fast list); `test_connections` and `test_connections_pairings` updated for the core's term. The fast list passes (53 of 53).
- **Not in this step:** stored cases (step 4) and caching. A dawn refresh now makes about one more judgement per item than step 2, to test it against the seed.

Next: stored cases (step 4).

---

## 2026-11-12 late, Claude-Quill: #142 content-only holds mask (Codex's review)

- **Problem (Codex, `workshop/solver.gd`):** the graded test's mask for role-checked gifts ran the role constraints with `bluffs = false`, which drops every world where the reader is evil and assigns the reader's claimed role. So `q`/`f` measured "could the reader honestly have said this", and evidence against the reader counted twice (it is already in `r`).
- **Fix:** `RoleConstraints.FlagContentOnly` (card flag bit 16; set from a card's `content_only`). It skips the source's alignment check, the source's role assignment and the relayer. `Solver.reading_holds_table` sets it on a copy of the report and drops `relay_source`. No other caller sets it. `ReadingChallenges.graded_rule`: "roles" (content-only, in play), "roles_source" (the first build, harness only), "table".
- **Test:** `test_workshop_reading_challenges._graded_content`.
- **Harness:** `--suspect-reader` adds constructed honest Archivist pairs (from good tellers other than the real Archivist) and an evil Seer bluff naming each teller. At 7 NPCs too few people are alive for it; use 10.
- **Numbers:** in the belief-model doc, "Challenge sides", and the reply to Codex on #142.
- **Checks:** five suites, full suite 145/145, golden identical to `baseline_6a22cac`.
- **Open for Michael:** an honest Archivist reader already under suspicion now loses a lying challenge on false grounds 35% of the time (19% on the old check, 54% on the first build).

---

## 2026-11-12 evening, Claude-Quill: graded test for role-checked gifts (PR #142)

From Bailiff via Michael, who approved the proposal. The results are in the Project doc `claude/belief-model-direction-2026-11-10.md`, under "Challenge sides".

- **Cause:** for the gifts in `CaseEval.ROLE_CONTENT_FIXED` (Archivist, Clerk, Registrar, Night Watch and the rest), the graded test's holds mask was all ones, because the report table doesn't check them. So `q = f = 1`, and the test never saw a clash.
- **Fix:** `Solver.reading_holds_table` now also asks `Roles.fits_table` for those gifts (`ReadingChallenges.graded_rule` is "roles"). The Seer keeps its own holds table and its Red Herring rule.
- **Measured:** a lying challenge on true grounds lands 20% → 45% (7 NPCs) and 20% → 40% (10 NPCs). False grounds land no more often.
- **Tests:** full suite 145/145. Golden is identical.
- **Harness:** `--graded-rule`, plus the graded test's internals on each row.

---

## 2026-11-12 late, Claude-Lantern: the connections model in game, step 2 (`claude/connections-pairings`)

From Michael (Phase 6, step 2). Spec: Project doc `claude/belief-model-direction-2026-11-10.md`, "Phase 6 spec" section 3. Results: the same doc, "Results: Phase 6 step 2". Base: main `8be9681` (step 1 merged as #141).

- **Built-in pairings** (`Connections.items`): a night's movement cards, an Augur reading with that day's sightings, a Psychologist reading with its statements, and a trace with the profile cards each count as one item. Claims, confessed secrets and profile cards are context: an item's value is lean(its cards + context) − lean(context).
- **The declaration decides how movement is read** (`Connections.row`, from the town's demon mix):
  - none: each night by itself;
  - walker: one always-on movement connection (today's reading);
  - hexer: each night by itself, plus the Hexer's day evidence as one always-on day connection.
- **The Hexer factor is read in one place.** Every judgement the model makes runs with `LiveActivity.hex_factor_enabled` off, except the day connection, whose value is the same day cards judged with the factor on minus off. Otherwise every night would count the day evidence again.
- **`CaseEval` compile key:** "hex_off" is appended when the mix has a Hexer and the factor is off, so a compile made without the factor is never reused with it. In play the factor is on and the key is unchanged. Golden is identical to `baseline_6a22cac` with the switch off.
- **The prototype tool** takes its grouping from the module, gains `--declare hexer`, and now leaves out the cards a listener rejects from its own knowledge. The game already did; comparing the two on the same states found it (three of 16 Hexer-forced logs differed by up to 1.9 log-odds on one night, and agree now).
- **`Connections.force_row`** (tests and tools only) reads movement as a given row whatever the mix is.
- **Tests:** `test_connections_pairings` (in the fast list); `test_connections` updated. The fast list passes (52 of 52).
- **Not in this step:** the core and stored cases. So a clash that needs the listener's own reading next to a night isn't made yet (step 3).

Next: the core (step 3), including the night a listener was wrongly sighted seeding it.

## 2026-11-12 evening, Claude-Lantern: the connections model in game, step 1 (`claude/connections-solo`)

From Bailiff via Michael (Phase 6). The spec is in the Project doc `claude/belief-model-direction-2026-11-10.md`, under "Phase 6 spec"; Michael accepted its four recommendations. Base: main `559a201`.

- **The switch:** `Tuning.Workshop.CONNECTIONS`, off. `Connections.enabled` starts from it; `autoplay.gd --connections` and `golden_capture.gd --connections` set it for a run. Autoplay's mode name gains `_connections`, so sweep records of the two settings never merge.
- **`workshop/connections.gd` (new):** the judge on a chosen set of held cards, and step 1 of the model: every held card counts at the value it has alone. In log-odds, a chance is the baseline (the judge on no cards: standing suspicion plus the public record) plus every card's own lean. Then one common shift, so the chances still sum to the evil count (normalising is in this step, as Bailiff agreed). No pairings, core, stored cases or caching yet.
- **One call site:** `Jury._consequences_eval`, on the refresh path. With the switch on, the model's chances replace the single pass's; the "before" side stays today's, so the public record still counts in the shift. Headline reading is off with the switch on (Michael, Nov 12). Attention is still worked out, for what an NPC can cite.
- **Off is untouched:** golden is identical to `baseline_6a22cac` at `--tol 0`.
- **The prototype tool** (`tools/connections_prototype.gd`) now calls the module for its judge and log-odds. Its output on seeds 900 and 902 is identical before and after.
- **In game against offline:** on the same listener states (seeds 900 and 902, 22 listener-dawns, 3,771 card-person values) the game's values and the tool's agree to within 0.00001.
- **Test:** `test_connections` (in the fast list).
- **Known:** with the switch on, a refresh makes one judgement a card, so a 10-NPC game runs about four times slower until the caching step. A night's cards aren't read together yet, so the switch isn't ready for play.
- Also adds the missing `tools/test_relay_bluff.gd.uid`.

Next: the built-in pairings (step 2).

## 2026-11-11 early, Claude-Quill: challenge sides, diagnosis and a proposed fix (`claude/challenge-contest`)

From Bailiff via Michael. The results are in the Project doc `claude/belief-model-direction-2026-11-10.md`, under "Challenge sides".

- `ReadingChallenges.clash_rule`, set to "contest" in play: in a clash, the floor's strength is (q_grounds − q_reader) / (1 − q_reader × q_grounds). At zero or below, the clash supports nothing, and below zero it backfires. "legacy", "posterior" and "graded" stay as dev switches for the harness. Lying is unchanged (fix 2).
- Harness:
  - `--construct-bluffs`: evil tells false Archivist and Seer readings;
  - `--script-roles`, `--force-bluffs`;
  - a trust grid in `--what challenges`;
  - `--keep-state`, `--natural-trust`, `--clash-rule`;
  - profiles alone in `--what player`.
- Full suite 138/138. Golden is identical on all five seeds, because passive games raise no challenges.

---

## 2026-11-11 early, Claude-Lantern: connections prototype, the Nov 10 late decisions (`claude/connections-prototype`, PR #129)

Base: main `edc01cf` (merged in, no force push). **Tools only; golden untouched.** Next
actor: Bailiff (review), then Michael. Results are in the project doc
`claude/belief-model-direction-2026-11-10.md`, "Results: prototype rerun".

- `tools/connections_prototype.gd`:
  - stored cases fade (each day a case keeps `--fade` of its weight; 0.5, 0.7 and 0.85 are
    reported, 0.5 is the main rate) instead of a cap of two; `--cap N` restores the cap;
  - a cited trace touches everyone it matches (it moves them 0.1 log-odds or more when read
    with the profile cards);
  - each refresh is compared with the listener's previous one that day: what a cache of
    solo values and core tests would have had to redo, and how far the rest drifted;
  - threshold 0.3 added to the reported set; `--movement-seed` lets a Night Watch's or
    Lamplighter's own readings seed its core;
  - `--explain listener:person:day`.
- `tools/connections_prototype_summary.py`: rewritten for the above (`--theta`, `--fade`).
- **All seven criteria pass at 0.4 with fade 0.5** on 12926 (at `75b4c8e`), 900 and 902
  (regenerated on `edc01cf`, since main's gameplay changed). Criterion 5 passes cached and
  fails when the redone items are counted.
- **A correction:** the Hexer factor does not lower Kiran (on and off give identical
  results). The gap I blamed on it is inside the game's belief refresh and isn't pinned
  down.

## 2026-11-10 evening, Claude-Lantern: connections prototype, offline (`claude/connections-prototype`)

Base: main `7404873`. **Tools only: no code path the game runs, golden untouched.** Next
actor: Michael and Bailiff (two criteria fail; nothing was tuned).

- `tools/connections_prototype.gd <log> [--out results.json]`: replays a dev log and
  computes what each good listener would believe under the connections design (Phase 4
  spec and the Nov 10 evening decisions in the project doc
  `claude/belief-model-direction-2026-11-10.md`): solo values, structural units, a core
  from the listener's own readings (thresholds 0.2, 0.4 and 0.8), stored cases (cap 2)
  and normalisation. It evaluates each dawn, each vote and each public presentation.
  `--check` confirms the judge on a set sees only that set.
- `tools/connections_prototype_summary.py results.json ...`: the seven acceptance
  criteria from those results.
- Run on 12926 (at its own build `75b4c8e`, by copying the tool into that worktree) and
  passive seeds 900 (7 NPCs) and 902 (10 NPCs) generated on `7404873`.
- **Results at 0.4:** criteria 2, 3, 4, 6 and 7 pass; 1 and 5 fail.
  - 1 (people a case didn't touch): fails. A third case pushes the oldest stored case out
    (cap 2), and that moves people up to 38 points. With nothing dropped, reading-only
    cases stay within 2.5 points; a case with traces reaches 8, since a trace is read
    against every profile card.
  - 5 (cost): fails with nothing cached (about 5x today's refresh from day 3 in 12926);
    under today's when solo values and core tests are cached.
- Build decisions not in the spec, for review: the core is also rebuilt when the
  listener's own readings change; non-"lying" challenges and NPC defences' reading
  challenges are not modelled; the "Hexer declared" run of 12926 wasn't done (no mix
  switch at `75b4c8e`).
## 2026-11-10 evening, Claude-Quill: belief-model Phase 0 gap, fix 3, Phase 3 table (PRs #124, #125)

From Bailiff via Michael. The results are in the Project doc `claude/belief-model-direction-2026-11-10.md`, in its Results section.

- **#125** (tools only, stacked on #118): `tools/read_everything_gap.gd`; `tools/measure_evidence.gd --what interactions|premises`, `--declare`, `--no-hexer`; `tools/measure_interactions_summary.py`. Dev hooks, empty in play: `Reasoner.always_keep_kinds` and `LiveActivity.declared_demon_type`.
- **#124** (draft): own home alibi is lie-aware for an evil subject, in both kernels. Full suite 136/137. `test_workshop_vote_and_alibi`'s "doubting the report raises the watcher" now gives 0.120 against a bar of 0.2. It's held for Michael, and the threshold is unchanged. Golden moves on seeds 42, 54875 and 98933; Bailiff sets the re-baseline.
- A playtest log replays only at its own build: 12926 at `75b4c8e`. Use a worktree.
- Later (after Phase 1 merged): #125 rebased on main; `--what crosschecks|challenges` and `--force-roles` added. Table rerun on `7404873`; the 0.4 core threshold is confirmed. Results are in the doc.

---

## 2026-11-10 afternoon, Claude-Lantern: why breakdown, what challenges and the view did (`claude/why-challenge-view`)

Base: main `07cbbe6`. Debug and logging only: no belief, vote or RNG changes; golden
should be identical. Next actor: Michael (review), then whoever uses it for Phase 1 checks.

- **Three new blocks in the listener breakdown** (`game/workshop_why.gd`; the Workshop's
  recorded breakdowns, the `workshop_why` dev-log row and `explain_case --why`):
  - **Each challenge the case attached:** how the listener graded it (agreement, the
    multiplier on the reading), and the subject's and the challenged reader's chance of
    being evil with the challenge removed.
  - **Citing:** each cited reading whose reliability changed because the case's own copy
    counts, and the subject with those readings heard as before.
  - **Change of view:** which cards left and entered what they read, the subject with the
    old view kept, and up to four people the case didn't name who moved by 5 points or
    more, each with their old-view value.
- **Cost:** one more union evaluation per challenge, one for citing, one for the view.
- **12926, day 4, "Kiran is evil"**, replayed at `75b4c8e`: the view swap moved people the
  case didn't name far more than its subject. Edda: Isolde 12% -> 80%, Nisha 89% -> 23%,
  Fenwick 87% -> 44%, all back to their old values with her old view kept. Fenwick: Lian
  96% -> 52%. Three of four listeners agreed with the "lying" challenge (0.15 to 0.74);
  for Hollis it took Kiran from 78% to 45%.
- Tests: `tools/test_workshop_why.gd` (new `_extras`).

## 2026-11-10 morning, Claude-Lantern: the "why" breakdown (`claude/workshop-why`)

A new session, at Michael's request (Nov 10, 00:05): a debug and logging readout of why an
argument moved a listener as far as it did. No dialogue hookup, no behaviour change.

- **Base:** main at `b40fab1` (#111 merged; Bailiff's #115-#117 are on main).
- **Status:** see the PR for the suite and golden results.
- **New:** `workshop/case_why.gd` (the evidence half: the premise chain, the surviving
  alternatives, and per card its status, world share, the model's `q` and leave-one-out),
  `game/workshop_why.gd` (the belief half for a real listener: the suspicion chain from
  "settled outright" to "applied", the biggest loss, the vote bar), `tools/test_workshop_why.gd`.
- **Where it shows:** the Workshop's Debug menu (three new items), `g.workshop_why`
  (off by default; when on, each presentation logs a `workshop_why` entry per listener),
  and `tools/explain_case.gd --why`. Described in `docs/DECISION_INSPECTOR.md`.
- **Touched outside the new files:** `game/game.gd` (two vars), `game/game_presentation.gd`
  (the recording hook in `_evaluate_deduction_inner`, behind the flag),
  `ui/live_case_workshop.gd` (the menu items), `tools/explain_case.gd` (`--why`),
  `tools/ci_fast_suites.txt`.
- **It reads the model through underscore functions** (`Shared._doubt_adjusted`,
  `Shared._evaluate_adjusted`, `Jury._eval_listener`, `Jury._card_trust`,
  `CaseEval._odds`) and re-states the vote need and nomination bar from `_vote_impl` and
  `_good_nomination_impl`. `test_workshop_why` pins both: the applied step must match what
  the presentation did, and the vote margin must match a real vote's.
- **Things the readout showed** (for Tally and Quill; nothing here is changed). Playtest
  12926 replayed on its own commit (`75b4c8e`), plus bot games on main:
  - **Re-presenting cards the town already holds can lower suspicion of the subject, by
    two routes** (corrected Nov 10 afternoon; this entry first blamed attention for all of
    it). 12926, day 4, "Kiran is evil" (three cards, all already public, with a "lying"
    challenge on Kiran's own reading):
    - Hollis 0.45 -> 0.25: he accepted the challenge. Accepting sets the reading aside, so
      its clash with his own confessions stopped counting against Kiran. Without the
      challenge he rises. Not attention: reading every card he still falls.
    - Dorian 0.17 -> 0.05: he rejected the challenge. The focused pass swapped five cards
      at the edge of his 12-card view; with his old view kept, nothing moves.
    - Not yet attributed to either route: day 2, "Lian is evil" (four of six listeners
      fell by 0.10 to 0.30) and seed 900, day 2 (Jory 0.56 -> 0.27).
    - Discussion and direction: project doc `claude/belief-model-direction-2026-11-10.md`.
  - **"Nothing fresh" lets the voiced stance part from the belief.** With no new card the
    reply keeps the scoped stance (`_present`: `fresh.is_empty()`), so Dorian said the case
    "changes how I see Kiran" while his suspicion of Kiran fell, and then voted no.
  - **The test juror hears every card at full weight; listeners don't.** The preview's
    strength is the ceiling, not a forecast.
  - **World share against `q`:** a Clerk pair held in 93% of the worlds where the Clerk
    is honest, against the fixed `q` of 0.5 (the evidence catalog's finding 2, now
    measured per card).
- **Next:** Michael reads a breakdown on a real playtest log (`explain_case --why`, on the
  log's own commit). Wiring the biggest loss and the strongest alternative into dialogue is
  a later step.

---

## 2026-11-10 early, Claude-Quill: evidence catalog, measured pass (`claude/evidence-measured`, stacked on #111 and #114)

Base: `claude/day-killer` (`75b4c8e`), as Michael asked, since it changes movement. Adds
`tools/measure_evidence.gd` (harness) and `tools/measure_evidence_summary.py`, and
`docs/evidence_catalog_measured.md` (tables and findings). Also a measured column in the
catalog's summary, and catalog entries C8, D7, D8 for the day-killer branch. Real evidence
from 250 + 100 passive towns (more for sightings and finds, plus Hexer-forced runs), measured on
a wiped listener through the game's own belief refresh. No game code changed. Findings to triage:
- **A sighting loses to the subject's home alibi:** held together, the sighting is dropped
  (teller at 0.5) or both are dropped (teller at 0.8). A Poisoner sighted at +0.256 goes back
  to 0 with her false alibi. Looks like a bug.
- **A false home alibi clears an evil person by 0.14–0.18,** more when the alibi-giver is
  trusted less.
- **Clerk, Registrar, Monitor, Executor and Martyr readings barely move the people they
  name** (under 0.01); their effect is all on the reader. Matches the old 37291 note.
- **A Minion seen out at night loses suspicion** (−0.11 / −0.07): an unknown good person is
  about as likely to be out as a Minion (the unclaimed walking-gift prior).
- **The Seer is weak because 42% of its "yes" readings are false** (Red Herring, Marked).
  That's a design question.
- **Traces alone move nobody;** with everyone's work and haunts, about +0.03.

Also removed `tools/_probe_d.gd`, a stray timing probe of mine that came in with recency
(`9a09894`), here and on #114.

## 2026-11-09 afternoon, Claude-Bailiff: haunts as regular knowledge, day log, Whereabouts solver (`claude/day-killer`, #111)

- **Status:** green.
  - 130/130 suites pass.
  - Golden is identical to `baseline_db5b24e`.
- **Haunts:** NPC reasoning knows the haunts that fall on its own spots
  (`view.regular_haunts`), not the town's gossip.
- **The watch leak is closed:** listeners hear the player's watches only through a cited
  day log (`watch_log` receipt).
- **New:** the location solver (`workshop/location_solver.gd`), the Case Board Whereabouts
  panel, and the Workshop node.
- **Details:** `docs/demon_types_plan.md`, "What the town knows about places".
- **Next:**
  - Michael plays it.
  - The bot could cite day logs (a follow-up).

---

## 2026-11-09, Claude-Bailiff: demon types step 3, the Hexer (`claude/day-killer`, held draft)

- **Base:** `claude/day-presence` (#107) plus main at `0d10089`. The PR carries #107 too,
  so the two land together, after Michael has played the Hexer.
- **Status:** green.
  - 129/129 suites pass.
  - Golden is identical to `baseline_db5b24e` (A = B = baseline). The Hexer is only dealt
    when a script lists two demon types.
- **What's in it:**
  - The role `daykiller` (display name "Hexer", a working name), in `sim/roles/daykiller.gd`.
  - The solver's whole-world mixture, `(1-s)*walk + s*day*HexFactor`.
  - People in the solver view now carry `work` / `work_phases`, which are public.
  - `autoplay --force-demon daykiller`.
  - Details: `docs/demon_types_plan.md`, step 3.
- **Test change:** in `test_workshop_circumstantial_hub`, the post-retract check now uses
  the listener's own baseline. With public occupations, the control NPC's Stage 1 differs
  from the listener's before any case.
- **Probe:** in passive play the hex factor is neutral to slightly negative. The real test
  is a player watching public places.
- **Next:** Michael playtests a forced Hexer. Then tune the hex odds and the floor.

---
## 2026-11-09 night, Claude-Quill: evidence catalog, first pass (`claude/evidence-catalog`, from main `407069d`)

Docs only. `docs/evidence_catalog.md` lists every kind of evidence (each gift's reading,
role and gift statements, whereabouts, crime scenes, public behaviour, profile context,
player premises, distorters) and, for each, how the solver reads it, how strong it is,
what it needs and what it interacts with. Code pointers are in
`docs/evidence_catalog_code.md`. **Strengths are judged from the code, not measured**;
Michael asked for this pass first, and a measured pass from tests comes next. Six findings
at the end of the catalog to check, including: poison isn't a world state; the role-table
readings (Seer, Clerk, Archivist, Gravedigger, Executor, Registrar, Monitor) use a fixed
`q` of 0.5; and the Lamplighter's `q` (CaseEval says unchecked, the movement code uses it).

## 2026-11-09 early, Claude-Bailiff: review fixes (`claude/review-fixes`)

- Base `dc2418c` (main after #96). Status: green, golden identical to `baseline_db5b24e`. Next actor: none.
- Codex on #108: a silenced listener shown a trace no longer passes on a haunt (`profile_haunts` cleared).
- Steward Nov 8 A1: the stage button says Continue once the next speaker is queued (`CourtroomStage.push`).
- Steward Nov 7 A1: late relays say the night once (`MindMeeting.relay_body`: the reading's own " on night N"
  dropped, other nights spoken, night 0 natural).
- Steward Nov 7 A2: the protect-preference gate reads the stored agreement (`arg:` meta `agreement`, kept at its
  max), not the weight.
- Steward Nov 7 A4: Poisoner candidates for a failed-gift group come from every reading's night.
- Not done: Steward Nov 7 A3 (a group "don't fit together" challenge overwrites the first card's own challenge).
  Every consumer keys `reading_challenges` by card id, so it needs several challenges per card: its own PR.
- `ci_fast_suites.txt` adds `test_control_flow` (about 10 s) and the new `test_review_fixes` (7 checks).

## 2026-11-08 night, Claude-Bailiff: playtest 1709 fixes (`claude/1709-polish`)

- Base `72407b2` (main after #106). Status: suites green; **golden moves on purpose** (needs Michael's OK to
  re-baseline). Next actor: Michael (re-baseline call, then merge).
- Reason wording: "doesn't fit what we know" -> "doesn't fit the facts as I know them"; a Surveyor reason about
  someone off the block no longer says "and they live there" (`reason_attribution._report_why_pair`).
- No repeated accusations: one accusation per speaker per target per meeting (`MindMeeting.already_accused`;
  testimony and supporter pile-ons). Changes RNG draws, so the golden capture diverges from day 1-2.
- Vote resistance line on an NPC's nomination no longer says "Your case..., Demonologist" (`_resistance_line`).
- Supporter "exonerate by reveal" with nothing new to disclose restates the clearing reading before "That's why
  I won't see X hang" (`mind_support._speak`).
- Silenced in conversation: no greeting; ask/press stay free (they can't answer); showing a card costs a
  question and gets no spoken answer (their beliefs still move).
- Wards and scorched sigils shown at the meeting don't take the day's floor; one button per receipt, naming it.
- Gossip and Town Hall results come up in the conversation view over the building (`main._capture_place_reading`).
- A conversation that runs out of questions and ends the phase holds the next header / meeting opening out of the
  log until the player leaves (`main._run`, `_leave_finished_conversation`).
- Not done: claim icon showing before the claim is spoken (Michael: only if safe).
- Test: `tools/test_playtest_1709.gd` (17 checks); `test_evidence_cards` updated for the free ward showing.

## 2026-11-08 night, Claude-Bailiff: demon types step 2, daytime presence (`claude/day-presence`)

- Base `99fdde1` (main after #105). Status: green, **held unmerged** until the day-killer (step 3) is
  tested (Michael's call). Next actor: whoever builds step 3, on top of this branch.
- Design and details: `docs/demon_types_plan.md`, step 2.
- `Game.watched`: the roster of every public place on the block the player watched each day phase
  (`GameDayNight._note_watch`). Carried by the snapshot (`Evidence.normalize`) and the solver view.
- `workshop/day_presence.gd`: presence table (schedule prior from the sim, updated by the watch record,
  player sightings and NPC reports) and `breath_factor` (Breathstealer by presence).
- CaseEval movement factor kind 3 (`CaseEvalKernel.PresenceScore`, weights via
  `SolverBridge.CaseEvalRegisterPresenceWeights`). The CaseEval compile key adds the watch record when
  someone has been silenced.
- The circumstantial hub no longer makes the one-day "near a silencing" incident. Hub and regression
  fixtures that leaned on it now use a rivalry with the victim.
- Checks: 125/125 suites; golden identical to `baseline_7034f36` (no golden seed has a silencing).
- **Balance flag (Tally):** 24 Breathstealer deals (7 NPCs, dynamic, seeds 1004-1100), analyst bot,
  main vs branch: good wins 15 -> 18, Breathstealer executed 10 -> 17 (now often day 1-2), evil
  executions 23 -> 35, good executions 16 -> 14. Mean game time 57.8 s -> 55.4 s (no slowdown).
  Small sample; the watch roster makes the silencer easy to spot when the player watched the victim's
  block. Worth a proper sweep before merge.
- Evening-loop cleanup in the movement model (dead `evening` variable, 4x inner loop) deliberately left
  out: it should be golden-identical and wants its own PR to prove that.

## 2026-11-08 ~17:50, Claude-Tally: the town map's layout is an editable scene

- Branch `claude/ui-script-map` (PR #106). Block areas, streets, block signs, building lots and
  cottage spots now live in `ui/map_layout/map_layout.tscn`, not in constants in
  `ui/map_view.gd`. Open the scene in the Godot editor to drag things on the base map (image
  pixels); the preview draws buildings, lots and cottages with the game's own geometry
  (`ui/map_layout/map_geometry.gd`, shared with the map view), so the editor shows what the game
  will. The map view reads the scene once at startup; `MapView.MAP_PADS` etc. are now static vars
  with the same shapes. Rendering is pixel-identical to before the move.
- Cottage spots fill in child order; a block needs 3 (the most residents in a 10-person town).
  `test_location_art` checks spots, signs, streets and lots exist.

## 2026-11-08 evening, Claude-Bailiff: demon types step 1 (`claude/demon-types`)

- Base `f167c63` (main after #104). Status: green, ready to merge. Next actor: whoever takes step 2 (daytime presence).
- Design: `docs/demon_types_plan.md` (Project `claude/demon-types-plan.md`). It covers the day-killer rules
  settled with Michael on Nov 8 and the solver maths.
- `C.is_demon` / `C.is_day_demon` (`sim/content.gd`). `daykiller` is a reserved id, not a dealable role.
  Role-id checks now go through the helper. Checks on the demon slot (`world.demon`) and on guess or premise
  types don't.
- The snapshot's rules carry `demons` (`WorkshopBridge.script_demons`), and the live view gets `script_demons`.
- `LiveActivity.day_demon_share` / `mix_demon`: the demon's whole-case movement likelihood is mixed over the
  types (a walking demon, or a day-killer that's out at night like a minion). It's applied to the joint
  factor's main profiles and `_likelihood(..., "demon")`. It isn't applied night by night, which would act
  as if the type were redrawn each night.
- Scion splits (Codex P2 on #105): the before/after scores multiply, so they're mixed after multiplying,
  in C# `ScoreWorldCore`, from a trailing `day_demon_share` double in the compiled factor. Splits keep walking
  profiles in GD.
- Share 0 on every script today: golden identical to `baseline_7034f36`, 124/124 suites.
  New `test_demon_types` (22 checks).

## 2026-11-08 night, Claude-Quill: recency, NPCs' spoken reasons recall their cards (PR #96, on main `7017a98`)

Status: green, ready for review. Next actor: Bailiff (review and merge), then Tally (A/B).
- **New, decided with Michael:** when an NPC nominates or publicly accuses and states a
  reason (headline, "Remember: …" recap, a revealed or relayed reading), the cards behind it
  are refreshed for every living hearer (`MindMeeting.recall_cited`), as a player
  presentation does for its listener. A hinted reason recalls nothing. Shared reasons
  already carry their card ids (`card_id` / `root_ids`), which are the same content ids
  listeners' attention uses. Seed 900 by day 4: 39 recalls, 31 of cards the hearer held.
- **Checks:** `dotnet build`; 124/124 suites (`test_recency` now 26 checks); two golden
  captures identical. **New baseline `baseline_9a09894`** replaces `baseline_06d26bf`
  (never on main, removed). See `docs/golden_baseline.md`.

## 2026-11-08 evening, Claude-Quill: recency (PR #96) refreshed onto main `f167c63`

Status: green, ready for review. Next actor: Bailiff (review and merge), then Tally (A/B).
The orchestration plan listed recency as not built; it has been on PR #96 since Nov 6 (see
the Nov 6 late-night entry below for what it does).
- **Merged main** (#97–#104, including step 3's speed fixes). Only docs and the CI baseline
  conflicted.
- **Codex's finding on #96, fixed:** the topic now halves from its capped value. Each act
  used to fade on its own before the cap, so a busy day kept its subject near 1.0 for days
  (nomination plus accusation: 1.0 then 0.8, not 0.5). Four new checks in `test_recency`
  fail without the fix. With it, seeds 900, 1001 and 1002 have at most three people at the
  cap on any day (before, 900 had five).
- **Checks:** `dotnet build`; 124/124 suites (`test_location_art` and `test_soundtrack` need
  `godot --headless --import` first in a fresh checkout: "No loader found"); two golden
  captures identical. **New baseline `baseline_06d26bf`** replaces `baseline_7034f36`;
  divergence from day 1 is intended (see `docs/golden_baseline.md`). `baseline_b157258` is
  removed.
- **For Tally:** an A/B of PR #96 against main, with long games (day 5+), "identified but
  lost", how long a good day-1 read survives, and topic saturation. Expected: the town a
  bit worse in long games. The 7-NPC bot drop and the 10-NPC passive drop are still open
  on main; merging this first would put recency into those comparisons.

## 2026-11-08 afternoon, Claude-Bailiff: bespoke papercraft map to main (`mock/bespoke-map`)

- Base `862cd27` (main after #102). Status: green, merging on Michael's go-ahead. Next actor: Michael (playtest).
- Brings in the hand-painted town map (`assets/art/map/town_open.png`, `BESPOKE = true` in
  `ui/map_view.gd`) with Michael's and Codex's papercraft buildings and lots, from the mock branch.
- New: each townsperson's own cottage (`assets/art/cottages_poc/<name>-cottage-papercraft-v1.png`,
  `MapView.cottage_art`) replaces the generic cottage and coloured dot. Anyone without art keeps the old look.
- New: daytime talks and location searches in a building or the Town Hall sit in that building's
  interior (`assets/art/interiors_poc/<loc>-papercraft-v1.png`), not the blurred map.
  `DayConversationView.set_location` shows the room; `SCENERY_SHADER` softens it (light blur, dimmed to
  0.7, vignette). Homes and crime scenes keep the map blur.
- Tests: new `test_location_art` (32 checks: every location has an interior, every cast member a
  cottage, the view swaps room and blur). `test_ui_controls` and `test_buildings_tavern_town_hall` were
  failing on the mock branch because they read the old `BLOCK_RECTS`. They now use `_block_rect`, and the
  Square check covers the bespoke lots. Golden identical to `baseline_7034f36`; the map is UI only.

## 2026-11-08 early, Claude-Bailiff: background soundtrack (`audio/soundtrack`)

- Base `f4906ed` (main after #101). Status: green, ready to merge. Next actor: Michael (playtest by ear).
- New autoload `Soundtrack` (`ui/soundtrack.gd`) plays Michael's two Google Flow tracks
  (`assets/audio/music/town_square_a.ogg`, `town_square_b.ogg`) whole, A then B then A, from launch
  to close. It ignores game events for now. The next track starts 6 s before the current one ends, so they
  overlap through each track's own fade-out. Each Flow export had a stray restart in its
  last second or two; that's trimmed off.
- Plays through a `Music` bus created at runtime (default -10 dB, 3 s fade-in). Settings live in
  `user://settings.cfg` `[audio] music_enabled / music_volume_db`; there's no UI for them yet.
- Headless runs (suites, sweeps, golden captures) return in `_ready` and never load the
  streams: golden identical to `baseline_7034f36`, 122/122 suites.
- Tried and set aside: bar-aligned loop points (75 BPM, 3.2 s bars). Michael could hear
  the seams. The tracks are a half step apart (A E-flat minor, B D minor). Raising B a semitone with
  rubberband keeps it on the grid, if we later want a bar-synced A-to-B switch after day 3
  (Godot's `AudioStreamInteractive`).

## 2026-11-07 ~13:00, Claude-Tally: premises steps 1–3 A/B. No outcome change; step 3 is slow

Runs `42331033313` (base `0743a76`), `42331041617` (step 1 `3d0f210`) and `42331050248` (steps
1–3, main `226d566`): M4 bot, seeds 100000–100999, attention budgets unchanged. Project doc
`claude/premises-ab-2026-11-07.md`.
- **Outcomes flat:** step 1 vs base +0.1 (7 NPCs) and −0.6 (10 NPCs); steps 2–3 on top change
  7 of 963 games at 10 NPCs and 2 of 1,000 at 7. Good executions, Demon identified, and
  identified-but-lost (~38% of identified at 10 NPCs; the Nov 6 "29.5%" was of all games)
  are flat.
- **For Quill / Bailiff: step 3 (#95) is 4–6× slower in passive play** (10 NPCs median 140 s
  vs 24 s per game, same outcomes) and ~1.6× for the bot (504 s vs 317 s; 33 games hit the
  30-min game timeout). A local timing pins it to #95: 26 s at step 1, 26 s at step 2,
  105 s at step 3. Likely `ReadingChallenges.graded_challenge`: three full
  `CaseEval.evaluate` calls per challenge, at every refresh, for every listener holding a
  defence. Cache it, or take q/f/r/evil from one enumeration. Sweeps of main need ~3×
  the cost estimates until then.
- **7-NPC bot fell between `9a1b215` and `0743a76`** (#90, #91, #94): 57.4% vs 62.8% on 505
  shared seeds (z −3.0). Not investigated.

## 2026-11-07 night, Claude-Bailiff: UI control-flow pass (`ui/control-flow`)

These are Michael's Nov 7 UX fixes. Nothing moves on while something is being shown.
- **Presentation lock** (`ui/main.gd` `_presenting`). It holds while the stage speaks, the
  vote is counted, traces are up or the town is still testifying. During that time the pane
  offers only Continue or "Finish the count", the command box is off, and map clicks don't
  act. The meeting can't close mid-count, so the vote explanations no longer appear at night.
- **Approaches:** an approach (or a protection request) waits for an answer. Other commands
  are refused, a wait included.
- **Traces first:** traces from a search that ends the evening are read before the meeting.
- **Courtroom stage:**
  - Lines wait for Continue.
  - One speaker's consecutive lines share a window, up to 420 characters.
  - An Auto-advance toggle under the controls is off by default and kept in
    `user://settings.cfg`, with a hold of 2–9 s.
  - The log follows the stage: `logged(events)` fires as each entry comes forward.
  - Testimony is worked out at most one speaker ahead.
- **Day pane before you move:** "Examine <block>"; once zoomed in, "Visit <block>", the
  block's crime scene and "Back to town view". Talk-to appears only for someone you clicked.
- **Sightings:** "ask seen" never covers the current phase. Someone who approached to tell
  you their gift (news, frame, divulge) shares all their sightings in that conversation.

New suite `test_control_flow`; 21 of its checks fail on the old code. Checks: 298 parse,
121/121 suites, golden identical to `baseline_7034f36`. Not done: Workshop presentations at
a meeting still print straight to the log rather than through the stage.

## 2026-11-07 night, Claude-Bailiff: bare defences ungraded (`perf/bare-defence-skip`)

Michael's call: an NPC's defence with no grounds isn't put through step 3's graded test. It
brings nothing new; the listener already weighed the rest of the evidence. `SharedLedger`
marks such challenges `bare`, and `ReadingChallenges.assess` skips them. They still count
through the older challenge rules, and Workshop challenges are graded as before. A check in
`test_defence_grounds` fails without the change. Passive 10-NPC game (seed 100000): 35 s
became 20 s, about where it was before step 3.

Checks: 297 parse, 120/120 suites, two captures identical. New baseline `baseline_7034f36`, a
small behaviour change (see `docs/golden_baseline.md`).

(My local check script's suite line read an old results file when copied with sed, so it
printed a stale count. The real results were 120/120 for #99 and here, and CI agreed for #99.
The script is fixed.)

## 2026-11-07 evening, Claude-Bailiff: step 3 speed fix (`perf/step3-speed`)

The step 3 slowdown in the Nov 7 A/B (`claude/premises-ab-2026-11-07.md`) comes from NPC
bare defences. Every challenge in a passive game and in an M4-bot game was a bare defence:
no grounds, hearing 0.03–0.05. Every listener holding one ran `graded_challenge` at every
refresh, and each run made three full CaseEval evaluations. Caching doesn't help: 541 of 586
inputs were distinct. Two of the evaluations were avoidable without changing a decision:
- **r's prior** comes from the holds evaluation's per-person prior. The separate "good"
  evaluation agreed to 1e-14.
- **The cause is skipped when the effect is zero.** That covers the source-evil and
  Delusional evaluations, and 91% of challenges in a passive game.
One game, 10 NPCs: passive (seed 100000) went from 71 s to 35 s; M4 bot (seed 100003) from
214 s to 152 s. Outcomes were the same.

Checks: 297 parse, 116/116 suites, two captures identical. New baseline `baseline_5ba1d64`;
the games are the same (see `docs/golden_baseline.md`).

**Open, for Michael:** skipping graded scoring for bare defences altogether (no supports,
hearing < 0.1) takes those two games to 19 s and 112 s. That would end bare defences' slight
step 3 effect. Not done.
## 2026-11-06 late night, Claude-Quill: recency and the headline blend on `claude/recency` (from main `226d566`)

Plan: `docs/premises_plan.md`, "Recency as built" and "The headline blend". All attention;
no card weight, solver or C# changes.
- **Recency** (`sim/recency.gd`, in `Reasoner._salience`): a card loses salience with age
  (0.5 a day at Insight 0 to 0.1 at Insight 1, capped at 3), the town's topic of the day
  (nominations 1.0, accusations 0.6, cases the player argued at a meeting 0.6, defences
  0.3; halved daily) draws attention, and presenting a card resets its age for that
  listener. Own readings stay pinned; presented cards are always attended.
- **Headline blend** (`workshop/jury.gd`): the low-Insight pull toward a reading's literal
  claim is scaled by `min(1, headline / 0.1)`. A faint ping no longer halves a clearing;
  the step 2 test now checks that a trusted player's word clears more than a doubted one's.
- **Dawn refresh** (`game_day_night.gd`): every living mind refreshes at dawn, so age and
  the cooled topic take hold each morning. Without it, minds that heard nothing overnight
  kept yesterday's attention (two in seeds 900 and 1001, off by up to 0.21).
- **Presentation order:** the card refresh and meeting topic are set before the capture.
  `test_workshop_live_cognition`'s reuse check now refreshes once after the meeting, since
  the meeting's topic is a real input change; the check itself is unchanged.

Checks: `dotnet build`; 121/121 suites (new `test_recency` in the fast list); two golden
captures identical. **New baseline `baseline_b157258`** replaces `baseline_4e54261`;
divergence from day 1 is intended (see `docs/golden_baseline.md`).
**For Tally:** an A/B against main on long games (day 5+), "identified but lost", how long a
good day-1 read survives, and whether the topic saturates (seed 900 had five people at 1.0
on day 3). Expected: the town a bit worse in long games.

## 2026-11-06 night, Claude-Bailiff: premises step 3 reviewed and merged (PR #95)

Base: Quill's `0b87978` with main merged in. Two Codex findings fixed, with regression checks
in `test_premise_step3` (each fails without its fix):

- **Content-only "holds" mask.** `CaseEval._holds_mask` now calls
  `Solver.reading_holds_table`. That uses the C# report table with a new optional
  `contentOnly` spec flag (`specInts[18]`), which skips the source's alignment, health and gift
  timing. The old mask also required a good, healthy source. `graded_challenge` already
  counts that through r, so it was counted twice, and "readings don't fit together" held in
  every world where the source was evil. `Solver.holds` "inconsistent" uses the same table.
- **The Poisoner check reads the script's minions.** `WorkshopBridge.capture` adds
  `rules.minions`, live_assessment passes it on as `view.script_minions`, and
  `poisoner_possible` reads it. `rules.roles` (`possible_roles`) lists every ready role
  whatever the script.

Checks: `dotnet build`; 297 scripts parse; 120/120 suites; two golden captures identical.
**New baseline `baseline_4e54261`** replaces Quill's `baseline_858495d`, which was never on
main and is removed. The changes are small, at the same meeting refreshes. See
`docs/golden_baseline.md`. Next: Tally's step 1–3 A/B.

## 2026-11-06 evening, Claude-Quill: premises step 3 on `claude/premises-step3` (on Bailiff's step 2 fixes, `5514f14`)

Plan: `docs/premises_plan.md`, "Step 3 as built".
- **Graded challenges:** a reading challenge lands as far as the rest of the attended
  evidence, against the reading's own chance (one CaseEval "holds" question, before and
  after), says it's wrong. Neutral challenges do nothing; old hard cases are floors.
- **Causes:** lied (raises the reader), failed gift (new; needs a Poisoner in the script;
  points at people seen out that night without a reason), misled (no blame).
- **Backfire** costs 0.02 trust, separately from the case's own reward or cost. Threshold
  is a 0.25 shift toward the reading holding: the plan's "0.1 below the prior" is
  unreachable (flagged to Michael).
- **New premise "has readings that don't fit together"** with a cause; scored jointly.
- **The Seer's "holds" is the Demon's place** (a Red Herring ping is "misled").
- **For Tally:** an A/B row for steps 2–3 alongside step 1's would separate them.

---

## 2026-11-06 evening, Claude-Quill: premises step 2 on `claude/premises-step2` (stacked on step 1, PR #92)

Plan: `docs/premises_plan.md`, "Step 2 as built". Decided with Michael: both Marked pickers
go; "lied", "misled" and "unreliable" leave the premise menu now; a secret premise counts as
the player's word.
- **Claim menu:** evil, suspicious, good, conflict, Demon, Minion, not the Demon, holds a
  secret, holds their claimed gift. Old types still evaluate in filed cases.
- **Live editor only** (fixture workshop unchanged, via `CanvasModel.marked_answers` and
  `contradiction_links`): no "registered as Marked" answers or "Good · Marked" identity;
  contradictions are a `contradicts` link (both cards stay, red border and "Contradicted by"
  tag; Inspect offers doubt the report / remove); claim citations fill themselves.
- **Secret premise = player's word:** a pinned, player-sourced secret reading of X, weighted
  like any card heard only from the player; joins the dawn track record.
- **Suspicious:** its cards count at half for everyone, plus pressure on the target from the
  average listener's full-weight rise, once per filing.
- **Flagged for Michael, not changed:** `Jury`'s headline blend pulls toward any positive
  headline signal, however small, when the evidence clears someone (see the plan).
- **Not visually checked:** the canvas drawing (red border, tag, "contradicts" link label)
  was written headless; worth a look in the editor.

---

## 2026-11-06 evening, Claude-Quill: premises step 1 on `claude/premises-step1`. For Tally: the step 1 A/B

**What step 1 does** (plan: `docs/premises_plan.md`, "Step 1 as built"; decided with Michael:
the shaping is remembered, and the premise's type adds nothing to the target beyond the
evidence):
- **Spillover.** Cards that only presentations brought, under an alignment premise about
  someone, are shaped: the target takes their full effect, everyone else 40% (Insight 0) to
  80% (Insight 1). Every refresh does it (`SharedLedger.premise_shaping`, two union passes,
  with and without those presentations), so it doesn't fade at the next refresh.
- **Wrong-premise cost** 0.02 trust at agreement −0.25 or less. Agreement is
  `CaseEval.shift` (−1..1), so the plan's "below 0.25" is read as its mirror; flagged to
  Michael.
- **Rejected-case preference fixed:** a presented premise's protect / believed-role
  preference needs agreement ≥ 0.5.
- **Movement notes** only follow killer-side premises (playtest issue #5); **preview hint**
  for a "good" premise whose cards raise its subject.
- **Invariants changed on purpose** (`test_workshop_live_cognition`): another premise type,
  same target, moves beliefs no differently; another target moves that person only; a later
  refresh reproduces the shaping exactly. New suite `tools/test_premise_step1.gd`.
- **Docs:** the plan's Nov 5 late-night decisions (suspicious as half-weight hearing, q and f
  on the same footing, neutral challenges cost nothing, "role" stays) were lost in the 22:50
  rebuild; restored in "Decisions".

**For Claude-Tally, the step 1 acceptance A/B** (tonight's sweep): M4 bot, main vs this
branch, same seeds, attention budgets unchanged (step 1 doesn't touch attention). Numbers:
win rate, wrong nominations that get through (moderately supported), and "identified but
lost" (the bot knows the Demon but loses; 29.5% on Nov 6). Expect bot cells to cost more:
listeners holding presented cards run a second union pass per refresh.

---

## 2026-11-06 afternoon, Claude-Bailiff: premises 0b revised, maintenance fixes. For Quill: the premises pass is yours

**Landed in this PR** (116/116 suites; golden identical to `baseline_50bd642` at `--tol 0`, since the passive golden player never presents a case, so no new baseline):
- **Premises step 0b revised.** The belief update has no premise target, and nothing
  about an argument is remembered between presentations. The per-listener
  `attention_target` is gone (bridge, ledger, reasoner fallback, presentation).
  - The judging pass (agreement, reasons, trust reward) still ranks attention against the
    premise's target, via the case's `conclusion.target`.
  - The belief update ranks by what was just shown: the people the presented cards name
    and come from, plus the listener's pinned own readings.
- **Two invariants that hold until step 1** (`test_workshop_live_cognition`):
  - The same cards under any premise move beliefs the same way.
  - A later refresh isn't steered by an earlier argument's framing.

  Step 1 deliberately breaks the first one, by conditioning on the premise. Keep the second.
- **Maintenance Nov 6 fixes:**
  - The courtroom stage drops speech from before the meeting opened.
  - The Sexton keeps the toll out of gossip while the bell holds
    (`RoleDef.may_share_reading`).
  - The toll, Monitor and Confessor texts store no time; late relays say when.

**For Claude-Quill, building the rest of the premises pass today** (Michael's plan: steps
1–4 land today, before tonight's sweep). Everything is in `docs/premises_plan.md`; the
Decisions section wins over the earlier proposal text. Read these parts first:
1. **The status block at the top**, including "Step 0b revised".
2. **"Decisions (settled Nov 5)" and its order list.** Step 1 is the core: conditioning,
   40–80% Insight spillover, the 0.02 trust cost, the rejected-case preference fix, reply
   text from the conditioned result, and the preview hint.
3. **"Tally's Nov 5 findings"**, including the own-readings pin and the "replies: two
   sources" rule.
4. **"Recency: the topic of the day".** This is **not** part of steps 1–4: build it after
   step 1, with its own A/B. Its rule for repeats is binding: **re-presenting restores
   attention, never weight.**
   - Bounded by what full attention to that card would give, and never past it.
   - No change while the card is still recent, so repetition can't ratchet belief.
   - Low Insight drifts more, so it gains more from being reminded.
   - Cited at a meeting, it refreshes the card for the town.

   Until recency exists, "re-presenting evidence they already hold adds nothing" stays true
   and tested.

Measuring: the M4 bot (`tools/autoplay.gd`, `--pre-m4` for the old policy) is the step 1
acceptance A/B. Hold attention budgets fixed between arms. Add "identified but lost" (from
the Nov 6 sweep report) as an acceptance number. The bot knows the Demon in 77% of games
but loses 29.5% of those.

---

## 2026-11-06 ~14:15, Claude-Tally: overnight sweep (M4 vs pre-M4 vs passive) results

- Run `42174319660` at `0ca8654` (main `9a1b215` plus this PR's `bot_pre_m4` cell mode),
  results branch `sweep-results/run-42174319660`, report in the Project doc
  `claude/balance-sweep-report-2026-11-06.md`. 10,734 games, 0 failed.
- **M4 bot beats pre-M4 at 10 NPCs:** 55.8% vs 50.9% on the same 2,000 seeds (z 4.0). At 7 NPCs
  it's +2.5 on 978 shared seeds, not significant.
- **10-NPC passive fell:** 30.0% vs 42.6% at `501b83e` on the same 1,000 seeds (z −6.7). Fewer
  evil executions on days 2–3, more good ones late, shares +23%, lies +24%. The cause isn't
  pinned. A per-seed bisect would mislead (seeds regress to the mean at the first commit that
  changes play), so test with fresh 1,000-seed passive cells at candidate commits instead.
- The 7-NPC bot cells timed out (single shards; costs were 4× low). 7 M4 has 978 of 2,000
  games, 7 pre-M4 has 1,756. This PR now carries measured costs. M4 takes ~1.7× the
  pre-M4 bot's time per game.

---

## 2026-11-06 ~02:30, Claude-Bailiff: Codex review fixes (game) on main; main settled for the sweep

- From the Codex review of the Nov 5 PRs (#69, #77):
  - A Sexton who claimed before tolling tells the town of the toll once the bell wears off
    (`RoleDef.on_public_update`), and a podium account of the toll tells evil the bell rang
    (`RoleDef.on_public_duty_account`).
  - A refusal about the toll night is reconsidered once pressure rises or they're nominated
    (`MindDialogue._honest_outing`).
  - A late relay is public grounds for every mind, the teller's own copy included
    (`Mind.apply_info(..., public)`; `Tuning.Meeting.LATE_RELAY_TELLER_MARK`).
- New `tools/test_codex_fixes.gd` (fast list, 10 checks; 4 fail without the fixes).
- 116/116 suites; golden identical to `baseline_50bd642` at `--tol 0` (none of the five
  seeds hits these cases), so no new baseline.
- The tooling half (#63, #72) merged earlier as PR #85.
- **Main is settled for tonight's sweep.** For Tally: M4 bot (default) against `--pre-m4`,
  plus passive, on dynamic scripts at 7 and 10 NPCs. The last big run for comparison is
  `sweep-results/run-42129219721` (4,000 games at `501b83e`). Since then: evidence honesty,
  M2c/M2d, step 0, step 0b, M4 and these fixes, so expect the passive numbers to move too.

---

## 2026-11-06 ~01:45, Claude-Bailiff: premises step 0b checked and merged

- Merged main into `claude/premises-0b` and ran the full checks. 0b broke 9 checks in 3
  older suites (they pass on main). Fixed:
  - **The belief update's focus target follows alignment premises only**
    (`WorkshopPresentation.ATTENTION_TARGET_TYPES`). A Marked, secret or conflict premise
    leaves the last alignment target in place. Before, "Merrin is Marked" with the same two
    cards moved Merrin +0.11 and Lian -0.10 through attention alone, against the plan's
    secrets decision (step 2) and its "condition, don't reshuffle attention" rule (step 1).
    Clearing the target wasn't enough: dropping an earlier target moved beliefs as much.
  - `test_workshop_live_cognition`: three checks now expect the pinned own reading in view.
  - `test_workshop_attention`, `test_workshop_reasoning`: the "a Low mind can miss a line"
    fixtures aim the case at Lian (named only by the Dowser reading). Under 0b a line that
    names the target outranks a gift reading, so the old target made the movement line win.
- 115/115 suites; two captures identical; new baseline `baseline_50bd642`.
- Next: the Codex game fixes (`claude/codex-sim-fixes`) stack on this with their own baseline.

---

## 2026-11-06, Claude-Tally: premises pass step 0b (one attended set) on branch, merged above

- Branch `claude/premises-0b` from main `93d24f3`. **Not tested beyond its own unit test, no
  baseline yet:** Michael has a couple of small fixes to land on top before new baselines.
  Expect every presentation's stance, agreement and belief change to move.
- What it does (plan: Project doc `claude/premises-plan.md`, step 0b):
  - **Salience** (`Reasoner._salience`, weights in `Tuning.Workshop.SALIENCE_*`): naming the
    target +4; else naming someone a presented card names, or a presented card's source, +2;
    else a counted-group gift reading (Dowser, Surveyor, Seer, Clerk, Rumormonger, Archivist,
    Registrar) +1 for exclusion; gift reading +2; trust in the source 0.1 (tiebreak). Warden,
    Monitor, Confessor and Psychologist joined the live gift roles. Mentions use the full keys
    (subject(s), target, who, data.pair/group/seen/nbrs/trio/target/chosen/executed/guarded/
    nominator/nominee).
  - **Focus target** (`Reasoner._focus`): the case target, else
    `knowledge.attention_target`. The belief update after a presentation had no target at
    all (probe, seed 42 Day 3); `workshop_presentation.gd` now records the headline's target
    in `state.attention_target`, plumbed via `workshop_bridge._listener` and the focus block
    in `shared_ledger.gd`.
  - **Own readings pinned** outside the budget in focused passes (bounded listeners): every
    report whose source is the listener. Before, a Low listener facing a 4-card case dropped
    all of them.
  - **Trust reward** judges agreement on the case cards plus own readings only
    (`Shared.response(..., own_only = true)`, `WorkshopPresentation._reward_agreement`); the
    second pass runs only when hearsay was in view.
- Probe finding for the plan: both the judging pass and the belief update already use the
  all-holdings pool when focused; the drift between them was the missing target, not the pool.
- Test: `tools/test_attention_0b.gd` (fast list), including the plan's worked example.
- Opt-in `Reasoner.capture_attention` / `captured` for tools; off in play.

---

## 2026-11-06 early, Claude-Bailiff: meeting plan M4, the bot (sweep for Tally)

Branch `claude/m4-bot`, on main after step 0 (PR #81). Golden identical to
`baseline_55cea76` at `--tol 0` (the passive golden player doesn't use the bot); 114/114 suites.

- `tools/autoplay.gd` (default policy; `--pre-m4` keeps the old one for A/Bs):
  - **Podium press:** a sighting or trace card about the nominee, else their gift (or
    readings they haven't shared), else last night. It skips a nominee it doesn't suspect
    (P(evil) < 0.35) unless it nominated them.
  - **Nominates less:** bar 0.6 → 0.7, and only 0.1 above whoever is on the block.
  - **Vigils:** the home of the most trusted (P(evil) < 0.35) public claimant of an
    information gift, the Warden or the Veteran, avoiding a suspected walker claimant's
    home block. If nobody qualifies, it falls back to the top suspect's home, as before.
  - **Demon guess:** the highest P(Demon) among the top 3 by P(evil) (`Analyst.demon_posterior`,
    cached per board state). The Minion guess is the top P(evil) among the rest.
- `tools/analyst.gd`: `_bears_on` lets an empty vigil or a complete vigil list that leaves
  someone out bear on a claimed walker (Lamplighter, Night Watch, Medium, Warden, Sexton).
  The greedy builder still keeps it only if it raises the strength.
- New `tools/test_bot_m4.gd` (fast list, 9 checks): the exclusion rule both ways, and
  P(Demon) ≤ P(evil), summing to 1.000 over the town.
- Small A/B, seeds 1000–1015, 7 NPCs, Default script: good wins 5 → 6 of 16; Demon
  identified 8 → 12 of 16; wrongful executions 15 → 14; evil executed 15 → 15. Too small to
  read beyond "nothing broke, and the Demon guess is better".
- **For Tally:** the M4 sweep (meeting plan slice M4: 150 seeds at 7 and 10 NPCs,
  `--dynamic`, M4 against `--pre-m4`) once this is merged (step 0b too, if it's close). Worth adding the
  hidden night-walker hang rate and how often the press and exclusion cards fire.

---

## 2026-11-06 early, Claude-Tally: premises pass step 0 (defence grounds) on main

Base `ce26d25`. Branch `claude/defence-empty-grounds`. New baseline `baseline_55cea76`.

- Step 0 of the "Case Workshop: what premises actually do" plan (Quill's spec): a bare
  defence ("X is lying" / "X's gift was turned") is a reading challenge with no grounds
  (`workshop/shared_ledger.gd`; a scope that names `supports` keeps them). Before, its
  grounds were every fact the listener held, and Reasoner's "never attend a challenged
  report without its grounds" pulled them all in. So every listener who heard a defence
  reasoned with full attention for the rest of the game. Defences are now judged on
  their own merits at their 5% hearing.
- New suite `test_defence_grounds` (fast list): 21 failures without the fix, none with it.
  Full suite 112/112.
- Corrected the earlier wrong cause (the "source is evil" assumption) in this log and in
  the Project playtest report.
- Passive A/B (`docs/golden_baseline.md`): 7 NPCs flat; 10 NPCs good wins 3 → 1 of 12. That's
  plausible, since the town loses accidental full attention, but small. Tonight's sweep
  should include it.
- Rode along (the plan suggested it): dev logs' `case_start.build` now records the git
  commit (`sim/build_info.gd`), and `log_replay.gd` notes when a log came from other code,
  with the worktree command to replay it there.
- Next: step 0b (own readings pinned during presentations), then step 1 goes back to Quill.
  Hold attention budgets fixed between the A/B arms.

---

## 2026-11-05 late night, Claude-Bailiff: meeting plan M3a (courtroom stage) on main

- `ui/vn_portraits.gd`: the 15 VN portraits and five expressions, shared by the day
  conversation view and the meeting.
- `ui/courtroom_stage.gd`, mounted inside `ui/meeting_view.gd`: each townsperson who speaks
  at the meeting comes forward with their portrait and expression over a lighter, warm blur of
  the ring. Lines reveal at 90 cps, hold, then auto-advance. A click finishes the line, a second
  click or Continue brings the next speaker, and "Back to the circle" skips the rest (the log
  keeps everything). The status pill shows the step: Opening Testimony, Accuser's Case,
  Nominee's Defence, Podium Press, Town Speaks, After the Count or Last Words, plus the block
  and what the vote needs.
- Beats: a 1.2s dusk arrival on the full ring. A vote waits for the speakers before it, then the
  hand goes round. Anything said after the tally (resistance lines) waits for the count. Last
  words keep the circle up after the meeting closes, and the map returns once they're heard.
- `main.gd` passes each meeting command's and testimony step's `last_events` to
  `meeting_view.consume`. Sim-neutral: golden capture identical to `baseline_a64553d`.
- Tests: `tools/test_meeting_stage.gd` (24 checks); `test_ui`, `test_town_ui`, `test_headline`,
  `test_day_conversation_view` and `test_ui_controls` pass.
- Not seen on a real screen yet (headless only). Michael: worth a look at layout and pacing.

---

## 2026-11-05 late night, Claude-Bailiff: M2c follow-up (defence goes after the case's hinge) on main

- When the player nominates on a filed case, the nominee ranks the case's items by weight and
  answers the heaviest one. If it's a night sighting, they give their account of that night
  before the town (`dispute_night`, the podium's `press_night`, plea scope). If it's a reading,
  they open with "Your whole case rests on X's reading." and challenge it. Raw nominations and
  NPC nominations keep the ordinary defence (`sim/mind_meeting.gd` `defend_self`).
- Tests: `test_meeting_m2d` `_test_case_hinge` (17 checks). 111/111 suites pass; golden capture
  is identical to `baseline_a64553d` (the passive golden player never nominates).
- **For Tally:** no A/B yet. It only affects games where the player files a case.

## 2026-11-05 night, Claude-Tally: NPCs more open with each other (step 1) on main (PR #77)

Base `440800d`, main (M2c) merged in. Merged at Michael's request; the big sweep runs overnight.
New baseline `baseline_7a96d27` (with M2c).

- Michael wants NPCs more open with each other, especially friends and anyone who's come to
  trust each other. It also brings back some of the meeting spark that the backlogged
  accusation floor would remove. Built:
  - Up to three items per chat (`Tuning.Social.SHARE_EXTRA_ITEM_BOND` = 0, 0.5, 0.65).
  - Readings to trusted listeners: +4.0 x (bond - 0.6) on the share weight.
  - Hint bar 0.45 (was 0.55); claim bar 0.58 (was 0.68), pressured 0.5, floor 0.45.
  - The dead's private readings: offered for relay across all hearsay, weighted by trust
    in the dead; and `MindMeeting._late_relay`, where a good NPC names the dead's reading
    at the meeting ("Before Dorian died, they told me...").
  - Fix: a speaker who comes round again no longer agrees with their own accusation.
- Not built (next): evil inventing a dead NPC's never-shared reading.
- Tests: new `test_npc_openness` (fast list). `test_peer_role_gossip` (the hint-only bond
  is now 0.5) and `test_meeting_flow` (the hearing weight check now tracks trust; an
  accused target's trust has dropped) were updated. Full suite green after those.
- Passive A/B in `docs/golden_baseline.md`: shares up 50-70%, good wins lean down (9 → 6
  of 24) on small samples. Worth a sweep before merging.
- New voice key `meeting_late_relay` (English fallback only).

---

## 2026-11-05 evening, Claude-Tally: playtest 13910 dialogue fixes on main (PR #73)

Base `42708ec`, main (`0c06b6f`, evidence honesty fixes) merged in. Merged at Michael's
request. New baseline `baseline_b9a0376`: identical to `baseline_e9f1e47` except wording fields.

- Fixes from the case 13910 playtest (Michael chose them; the Project doc
  `claude/playtest-report-2026-11-05.md` has the context):
  1. Owning a night out follows what was actually said: a false alibi ("whatever I
     told you"), a refusal ("That's why I wouldn't say where I was"), or nothing.
  2. A gift reveal under a night card opens "All right, you saw me", not a
     doubted-sighting stem.
  3. `ask why` with no live hint is free and says so, or names the dead person it was about.
  6a. Readings spoken with a time lead drop their own "last night" and full stop
     (`MindMeeting.reading_body`).
  6b. An alibi that already says it saw nobody skips the extra saw-nobody line.
  7. A meeting broadcast about someone logs no share line to that person (they still
     get the public receipt; `test_meeting_flow` asserts every mind holds it).
  10. "My stronger suspicion remains that X is the Demon" names the listener's own
     standouts (`Presentations._own_standouts`), or hedges. Before, it named the rival
     world's Demon, so every listener said the same name.
  13. **Reverted before merging:** a 0.2 floor on good NPCs' accusations
     (BACKLOG, NPC behaviour). It silenced some Day-1 meetings: base-suspicion
     accusations are what start the reactive chain. Passive A/B, 12 games per cell, good
     wins main → floor: 7 NPCs 3 → 2 and 4 → 6 (two seed blocks); 10 NPCs 4 → 2. A
     floor-off run matched main exactly, so the other fixes are wording only.
  15. Reasons and "X is lying" already said at a meeting are pointed back to ("As Dorian
     said, …"). Dowser and Surveyor reasons say what the reading found.
  17/18. NPCs leave out sightings the player made themselves (ask seen, ask about).
- Not done: 5 (muddled presentation reply). Michael deferred it to the "premises
  matter" overhaul.
- New keys with English fallbacks, not yet voiced per character: `own_night_refusal`,
  `own_night_out`, `pressed_caught_out`, `hint_why_moot`, `present_alt_open`,
  `meeting_accuse_reason_echo`, `defence_lying_echo`.
- Tests: new `test_playtest_13910_dialogue` (in the fast list). `test_meeting_flow`'s
  owned-lie case now has a real alibi.
  Locally, with the floor: full suite 104/106. Both failures were intended changes, fixed and
  rerun green. After the revert, not rerun locally (Michael: no further tests); CI covers it.

---

## 2026-11-05 late night, Claude-Bailiff: meeting plan M2d (player's turn, resistance lines) on main

**Base:** `main` at `f999e09`, with main (NPC openness, `8554730`) merged in. **Branch:** `claude/meeting-m2d`. **Baseline:** `baseline_a64553d`.
**Status:** merged. 111/111 suites; two golden captures identical.

- **Step 5, the player's turn after the town.**
  - New nomination command `hear` (also `listen`). The "Hear the town" button runs the
    supporters, then a "Your turn" prompt offers the statement, Clemency or the vote.
  - `press skip` and a finished press do the same.
  - The UI shows the statement and Clemency buttons only once the town has spoken. Voting
    straight away still works: the supporters speak first.
- **Step 6.**
  - `World.vote_pending` flushes beliefs first. It records each voter's vote parts
    (`res.voter_parts`, from `_vote_impl`; evil voters' come from their shadow under the
    same id) and the block before the vote (`prev_block`, `prev_block_count`).
  - `MindMeeting.vote_resistance_lines` gives at most 2 lines.
    - **Priority 1:** a voter who accepted the player's public case against the nominee
      today (new `dialogue_memory.accepted_cases`, written by
      `WorkshopPresentation._present`) and voted no. They voice their real vote part:
      prefers the block / reluctant (spare preference or a role's own reluctance part) /
      distrusts the nominator / short of rope (margin within 0.35).
    - **Priority 2:** on a count within one of what was needed, the swing voter.
    - An evil voter whose good self would have voted yes gives an ordinary
      prefers-block / short-of-rope line, never the override.
- **For Claude-Tally.** Behaviour changes (the pre-vote flush moves votes). No A/B was run.
  Resistance lines need player presentations, so they show up in bot games, not passive
  ones.
- **Not built.** Voice-pack lines for the new keys (`vote_no_*`, `vote_yes_swing`); they
  fall back to the canonical text.

## 2026-11-05 late night, Claude-Bailiff: meeting plan M2c (supporters) on main

**Base:** `main` at `cd21755`. **Branch:** `claude/meeting-m2c`. **Baseline:** `baseline_a9e0301`.
**Status:** merged. 109/109 suites; two golden captures identical.

**What it is.** Step 4 of the trial (`sim/mind_support.gd`, plan section 3 Step 4). After the
defence and the press, bystanders get the floor in seat order from the nominee. Each
decides for themselves. At most `MAX_SUPPORTERS_SHOWN` (3) speak.

Moves:
- **`counter_claim`:** the nominee claims your gift. In practice good-only, since evil
  never bluffs an in-play role.
- **`exonerate`:** an unshared clearing reading (reveal or hint), or a window alibi on a
  night the case puts the nominee out.
- **`vouch`:** M1 peer gossip, a gift confided before today.
- **`pile_on`:** your own reason, voiced through the accusation tiers
  (`MindMeeting.accuse_named`, split out of `_public_accusation` without changing it).
- **`vibes`:** for or against.

**The weighing** (`support_reveal`) follows plan 4B: belief the nominee is good, what their
role is still worth (new `RoleDef.score_protect_value`), what speaking costs you
(`reveal_cost` × `SUPPORT_REVEAL_COST_SCALE`, 3), and danger.
- Danger is re-read before every offer.
- Defenders you trust cut it; accusers add.
- The plan's three examples are tested.

**Evil.** An evil bystander decides as its shadow would, and breaks cover via
`evil_override`, to defend a teammate or pile onto the scapegoat. Words are the cheap
place to keep cover:
- Defend-a-teammate stakes are 0.3 × teammate value × danger.
- At 1.0, 20 of 30 smoke-run supporters were evil defending evil, which was a tell.
- Now it's 18 good to 12 evil, mostly evil playing its fake readings.

**Flow.**
- Supporters run once per nomination: when the press resolves, or before the player's
  statement, Clemency or vote, whichever comes first. So the player's word already comes
  after the town's.
- M2d still has to make the prompt sequence explicit and add the resistance lines.
- `w.defences` (supporter → {target, day}) takes back a little crowd pressure in
  `refresh_consensus` (`VIBES_SWAY`).

**For Claude-Tally:**
- This changes behaviour. No win-rate A/B was run (Michael: balance checks go to Tally).
- Worth watching in the next sweep:
  - wrongful hangs;
  - supporters per nomination (the smoke run had about 0.3);
  - the good/evil mix of supporters by move (`supporter` dev-log entries carry move, side
    and how).

**Not built:**
- Martyr and Warden-specific exonerations.
- Evil counter-claims (no double-claim logic yet).
- Voice-pack lines for the new keys: they fall back to the canonical text.

## 2026-11-05 ~20:40 ET, Claude-Bailiff: for Claude-Tally: three bluff checks queued after the oracle sweep

Michael wants sweeps and balance checks with Tally from now on. These three are queued
after tonight's oracle sweep. None is urgent: the Night Watch gap is much smaller than the
Lamplighter's was. Background is in the entry below (evidence honesty fixes, PR #74) and in
`claude/balance-sweep-deep-dive-2026-11-05.md`.

1. **Night Watch bluff: find what's protecting it.**
   - **Data.** After PR #74, good wins less when the Demon bluffs Night Watch (same seeds):

     | Cell | Before | After |
     |---|---|---|
     | 7 bot | 57% | 42% |
     | 10 bot | 48% | 45% |
     | 7 passive | 22% | 15% |
     | 10 passive | 33% | 24% |

     NW bluffers are hanged less (7 bot: 63% → 47%).
   - **Suspected cause.** Evil's fake NW report names the victim's block as the one it
     watched (`Evil` sighting logic, `bluff in ["nightwatch", ...]`). The claimed duty then
     sends the Demon exactly where it really went, as with the Medium. PR #74's walker-claim
     binding (0.95 duty) makes that duty count for more.
   - **Check.** The same leave-one-out probe used for the Lamplighter:
     - pick 4–8 seeds where the Demon bluffs Night Watch and has claimed by Day 3
       (`sweep-results/run-42129219721`, people rows with `bluff == "nightwatch"`);
     - play passively to Day 3;
     - run `Analyst.belief` on the full board;
     - remove one accepted card at a time and record the Demon's P(evil).

     The probe script is in the Lamplighter write-up: same shape, `Analyst.evaluate` with
     one card left out. The card whose removal raises P(evil) most is the protector.
   - **Possible counter, for Michael** (design, not code yet): a real NW on the victim's
     block would have seen the killer arrive. A report that names only the scapegoat
     amounts to "the scapegoat did it", which other evidence can check.

2. **Medium bluff: check the relays.**
   - **Data.** Unchanged by PR #74 (good wins 14–45%). The hearth restriction rarely binds.
   - **Suspected cause.** The fake Medium's reports of what the dead knew are relay cards,
     not `report` cards, so `CaseEval.chance_content` doesn't touch them. They may self-
     certify the way the Lamplighter count did.
   - **Check.** The same leave-one-out probe on Medium-bluff seeds. Then look at how
     relay credence is computed: `reasoner.gd` relays and `source_doubt.gd`.

3. **Detection rate (Michael, Nov 5): an idea, not a fix yet.**
   - The movement model scores a sighting as "fits the route or not". It ignores how
     likely the route is to be seen. So a Lamplighter or Sexton spotted on several blocks in
     one night gets no extra credit, and a Lamplighter nobody sees costs nothing.
   - Michael's view: same-night sightings on several blocks should mostly back the
     Lamplighter and Sexton (anyone on any block can spot them), less so the Night Watch.
   - Revisit only if the oracle sweep shows Lamplighter or Sexton claims still misread.

## 2026-11-05 evening, Claude-Bailiff: evidence honesty fixes on main (Lamplighter bluff, soft vigil exclusion, Medium hearths)

**Base:** `main` at `4d370f8`. **Branch:** `claude/evidence-honesty-fixes`. **Baseline:** `baseline_e9f1e47`.
**Status:** merged. 107/107 suites (after the test consolidation); two golden captures identical.

**Why.** The Nov 5 sweep showed good winning 3–10% when the Demon bluffs the Lamplighter.

**Root cause.**
- `CaseEval.chance_content` gave the Lamplighter's count a fixed 1/(people) chance of
  fitting a bluff. The count isn't checked anywhere, so every fake report counted about
  7× toward the claimant's honesty.
- A claimed walker's good worlds kept 30% "stayed home anyway" weight, so even an empty
  vigil only cost the claim about 3×.

**Changes.**
- **`chance_content`** is now the share of valid worlds in which the report's content holds,
  so uncheckable content (the Lamplighter count, the Augur, the Confessor) earns nothing.
  Three groups keep the old constants:
  - readings checked elsewhere: role readings, via the role constraints (Archivist, Clerk,
    Executor, Gravedigger, Registrar, Monitor, Martyr);
  - readings checked by the movement model (Night Watch, Warden, Veteran) and the Seer,
    whose red herring is a separate weight;
  - the Chronicler and Rumormonger, which have exact prior formulas.
- **Vigil exclusion is soft in the score.** A complete or empty player vigil that should
  have seen someone scores `VIGIL_MISS` (0.05), not 0: the town allows that the
  Demonologist missed them. Route *consistency* checks (`routes`, challenges, conflict
  notes) stay strict, because they ask "if both cards are true".
- **Walker claims bind.** A good claimed walker's nights split 0.95 duty / 0.03 home /
  0.02 secret (was 0.7 / 0.2 / 0.1). An empty vigil on their claimed block is now about
  10:1 against the claim. (`Tuning.Workshop.WALKER_CLAIM_*`, mirrored in
  `LiveActivity.cs`.)
- **The Medium** is modelled visiting earlier Demon victims' hearths only, not the
  hanged.
- **New test:** `test_evidence_honesty`.
- **Updated tests:** `test_shared_model` picks seeds that reach Day 4 (seed 42 now ends on
  Day 3).

**A/B.** Same 1000 seeds per cell as the Nov 5 sweep; run `42129219721`, results on
`sweep-results/run-42129219721`.

| Cell | Good wins | Wrongful hangs/game | Bot names the Demon |
|---|---|---|---|
| 7 passive | 33.4% → 37.6% | 1.01 → 0.94 | |
| 10 passive | 40.0% → 42.6% | 1.42 → 1.30 | |
| 7 bot | 56.2% → 57.8% | 0.80 → 0.76 | 72.0% → 73.0% |
| 10 bot | 53.4% → 56.6% | 1.15 → 1.10 | 72.6% → 75.8% |

Good wins when the Demon bluffs:

| Bluff | 7 bot | 10 bot | 7 passive | 10 passive |
|---|---|---|---|---|
| Lamplighter | 19% → 51% | 5% → 58% | 1% → 29% | 0% → 37% |
| Augur | 53% → 67% | 43% → 62% | | |
| Night Watch | 57% → 42% | 48% → 45% | 22% → 15% | 33% → 24% |
| Medium | unchanged, 18–45% | | | |

- **Lamplighter bluffers** are hanged in 31–61% of games, up from 1–15%. True Lamplighters
  are hanged in 8–11%, up from 2–4%: the claim is no longer near-proof.

**Open, for Michael and the next pass.**
- **The Night Watch bluff got stronger.** Binding walker claims makes "I was out on duty"
  explain any night sighting. NW bluffers are hanged less: 47% vs 63% (7 bot). The fix is
  Michael's same-night rule: several blocks on one night support a route; a single
  sighting supports little. That needs a per-night support measure in `LiveActivity`.
- **The Medium is unchanged.** The hearth fix rarely binds. The likely cause is the fake
  Medium's relays from the dead (relay cards, not reports), which `chance_content`
  doesn't touch. Next step: check how relays are credited.
- **The bot doesn't test claims** with vigils yet. That's M4 (meeting plan).

## 2026-11-05 evening, Claude-Tally: playtest analysis tools on main (PR #72)

Base `d043da9`. Merged to `main` by Claude-Tally at Michael's request; all CI green.

### For every agent: use these when a playtest needs explaining

When Michael asks *why* the town voted, read a case or believed something, run these
before reading code or guessing. Each takes a playtest dev log (`logs/case_<seed>.jsonl`,
or the attachment) and replays it exactly, dynamic scripts included. About 10 seconds per run.

```text
# What every good mind believed just before each vote (or only --at SEQ,...)
godot --headless --path . --script res://tools/replay_log.gd -- <log> --why [--at 480]

# How each mind read a filed case, and variants of it
godot --headless --path . --script res://tools/explain_case.gd -- <log> --card 78 [--add fenwick] [--drop] [--challenge fenwick=lying]

# Which heard items hold up each mind's suspicion of someone at a point in the log
godot --headless --path . --script res://tools/explain_case.gd -- <log> --belief fenwick --at 372
```

- `--why` prints each mind's suspicion (the number the vote reads), joint-world P(evil),
  P(Demon) and the likeliest evil teams.
- Case mode prints premise prior → posterior, LR, rivals, and per-card reliability and
  acceptance.
- Belief mode is a leave-one-out over the mind's ledger.
- Seqs come from the log's `seq` field. Check the replay's closing `votes_match=true`.
  Text DIVERGE lines at meeting testimony are expected.
- Details: `docs/DECISION_INSPECTOR.md`. Worked example: the case 13910 playtest report
  in the Project (`claude/playtest-report-2026-11-05.md`, issues 9–10 and the
  vote section).

### What changed

- Folded into Claude-Bailiff's `tools/replay_log.gd` rather than a second replay tool.
  Its interface is unchanged (`-- <log> [stop_seq]`, same DIVERGE/FILED/REPLAY lines).
  Added:
  - The case is rebuilt with the log's `case_script`, so dynamic and custom-script cases
    replay. Before, they were dealt from the Default script and replayed a different game.
  - A closing vote-tally check against the log (`votes_match`), since testimony text
    diverges harmlessly.
  - `--why [--at S,..] [--worlds N] [--json OUT]`: before each vote, each good mind's
    suspicion, joint-world P(evil), P(Demon) and likeliest evil teams
    (`tools/belief_views.gd`). See `docs/DECISION_INSPECTOR.md`.
- `workshop/case_eval.gd`: opt-in `CaseEval.capture_worlds` / `captured` (developer use
  only). Off, the code path and results are unchanged.
- New `tools/explain_case.gd` (and `tools/log_replay.gd`, the replay loop both tools
  share). Case mode presents a filed case and variants of it (`--add`, `--drop`,
  `--challenge`) to each good mind and prints premise prior → posterior, LR, rivals and
  per-card reliability and acceptance. Belief mode (`--belief X --at SEQ`) finds which
  heard items hold up a mind's suspicion of X, by leave-one-out. See
  `docs/DECISION_INSPECTOR.md`.
- **Finding for whoever owns the solver (case 13910, seq 372):** Fenwick's podium defence
  "Merrin is lying" moves every listener's suspicion of Fenwick by −0.08 to −0.18
  (Constance 0.18 → 0.00), even though each listener's own challenge assessment rejects
  it (`supported: false`, `multiplier 1.0`). P(Merrin evil) barely moves. Removing just
  that ledger entry restores the old values. **Corrected later the same night:** the
  cause isn't the challenge's "source is evil" assumption, as first guessed here. The
  defence's grounds were every fact the listener held, and Reasoner's attention rule pulls
  a challenge's grounds in, so bounded listeners went to full attention (Constance 8 → 22
  cards). Fixed by the premises pass, step 0 (`claude/defence-empty-grounds`).
- `tools/replay_54875.gd` stays separate: it's a fixed-fixture performance and fallback
  check, not a general replay.
- Checked on playtest case 13910 (10 NPCs, dynamic script): all five votes replay
  identically, with and without `--why`. CI: Suites 1–4 and the Linux golden diff pass.

---

## 2026-11-05 evening, Claude-Quill: maintenance report fixes (#69); golden false red fixed (#68); `baseline_a42ef71`

- **Base:** `main` at `3932e86` (maintenance PR #66 merged), then `e09dbbd` (#68).
- **#68 (merged): the red golden gate was the dev-log path**, as the Steward said:
  `baseline_9187b09` recorded `/root/.local/share/...` in the game-over reply. Captures now
  write `user://`; `golden_diff.py` normalizes `app_userdata` paths (Linux and Windows).
  Main vs `baseline_9187b09`: identical on all five seeds. CI green again.
- **#69: every Section A item, done here rather than by Argon.** Argon: nothing to pick up.
  - A1/A2 + Michael's bell design: Breathstealer suppressed; the honest Sexton never lies
    about the toll night (refuses while the bell holds unless pressed, open from the morning
    after it wears off); evil plays the bell only once told of it (no Scion fallback, a
    Revenant not worth hanging); a Revenant with its curse ready is cheap to let hang.
    New RoleDef hooks: `honest_outing`, `on_public_claim`.
  - A3 Monitor bluffer night-scoped (`override_night_sightings` now gets the filtered list).
  - **A4 was a real C# bug:** `CaseEvalKernel` packed card states base 3 into a long, which
    overflows from 40 report cards (silently merged classes, then IndexOutOfRange). Wide
    cases key classes by digits. Seed 101032 plays clean. Compiled cases also carry their
    own handle and generation now.
  - A5 script spare role; A6 bot/stuck games; A7 Monitor "nobody walked by" is a movement
    fact (move-role 7, GD and C#); A8 Confessor clears; A9/A10/A13 sweep workflow and
    shards; A11 Marked rolled once; A12 `World.night_killer()`; A14 tavern trend.
  - Dialogue: Nisha's patch-006 lines follow the Nov 2 round-2 rule (that pass hadn't been
    lost: patch 006 added new lines in the old style); "on night {night}" in speech is now
    `C.spoken_when`.
- **`baseline_a42ef71`:** only seed 42 changes vs `baseline_9187b09` (day 3: the Demon votes
  to let the Revenant hang). Two captures identical.
- **Still open from the report:** section B's win-rate question (Michael's call); the
  test-audit suggestions in section E; housekeeping branch deletions (not done).
- **Next actor:** Michael (merge #69).

## 2026-11-05 ~05:30 ET, Claude-Tally: balance sweep done (11,000 games); tooling on main

- **Landed** (PRs #63, #64, sim-neutral): `autoplay.gd --dynamic --results-jsonl --sha`,
  `tools/sweep_record.gd`, `tools/sweep_shard.py`, `tools/sweep_report.py`,
  `.github/workflows/balance-sweep.yml`, `docs/balance_sweep.md`. Artifact downloads are
  blocked from Claude workspaces, so the collect job also pushes results to an orphan
  branch `sweep-results/run-<id>` (Michael: these can be deleted whenever).
- **Runs** from `main` at `a0d9641`: 41978776824 (5 cells × 2,000 games) and 41999201334
  (10 NPCs, bot insight 0.6, 1,000 games). Seeds 100000+. Report:
  `claude/balance-sweep-report-2026-11-05.md` in the Project; records on
  `sweep-results/run-41978776824` and `sweep-results/run-41999201334`.
- **Headline:** good wins 34% (7) / 40% (10) passive, 55% / 53% with the analyst bot.
  Breathstealer weak (+12 to +17 for good), Poisoner and Scion strong, Delusional the
  worst secret, Lamplighter strongest gift and its claim almost never hanged (evil
  Lamplighter bluffers 2–4%).
- **For Argon (bug, reproducible):** `IndexOutOfRangeException` in
  `CaseEvalKernel.ComputeClassLikeCore` (`workshop/cs/CaseEvalKernel.cs:890`, the
  `f[3 * c + states[at + c]]` read), from `CaseEval._evaluate_posterior_cs` in a belief
  refresh after `World._kill`. Seed 101032, 10 NPCs, `autoplay.gd --passive --dynamic`
  (also seed 100291, 10 NPCs, bot `--insight 0.6`). The refresh then fails
  (`CaseEvalEvaluatePosterior` reported missing, `people`/`effects`/`impossible` on an
  empty result).
- **Also seen:** 13 bot games exhausted the 600-command guard (seeds in the report's Health
  section); 50 games had a shared-model fallback.
- **For Claude-Bailiff: main's golden check is red,** and not from the sweep: on
  `31a8914` (patch_015 + town vibe) seeds 54875 and 692 diverge from `baseline_9187b09` at
  the final `done` step (the game-over reply text). Probably needs a re-record.
- **Next actor:** Argon (the C# exception), Bailiff (golden re-record). Re-run the sweep
  after M4 by dispatching the workflow (inputs in `docs/balance_sweep.md`; on runners
  a 10-NPC bot game is ~200 s of CPU, 7-NPC bot ~40 s, 10-NPC passive ~40 s).

## 2026-11-05 early, Claude-Bailiff: patch_015 (Sexton rework, Brute) checked, fixed, on main

- **Base:** `ce3c2d8` as declared (good, current), then main (`2ec1a80`, town vibe) merged in.
  Targeting C# for the constraint change was right.
- **It still didn't parse,** so the suite's "passed" was every test crashing before its
  checks. Argon: you can't run Godot, so please re-read each edited function top to bottom
  for variables you renamed or moved into a branch. What I fixed:
  - `world._kill`: `passers` was declared inside the non-Brute `else` but read after it,
    and three `demon_trace` references survived the rename to `killer_trace`.
  - `content.gd`: the Brute was in `MINION_ROLES`/`EVIL_ROLES` but missing from `ROLES`,
    so any lookup crashed (your notes said it was registered there).
  - Sexton: `try_toll` walked the Sexton, then `_night_movement` reset the walkers and
    walked them again only when the bell worked. Now there is one walk, in
    `_night_movement`, on any toll night (a broken bell still walks).
  - `test_chunk6a`: the victim check assumed `living_good()[0]` was the target. It now
    reads the Brute's actual hunt.
- **Brute is `experimental` (not dealt automatically) until the solver models it.** The
  workshop's night movement and trace models (`LiveActivity`, `demon_events`, the
  passer/two-trace scoring, "seen elsewhere argues against being that night's killer")
  assume the Demon walks to each victim. With a live Brute the Demon stays home and both
  traces are the Brute's, so NPC and player reasoning would exonerate the real Demon on
  a home sighting and pin the Demon on the Brute.
  - New: `RoleDef.status` is now enforced. `ScriptBuilder` draws only `ready` roles (plus
    playtest-favoured), and the Default script leaves experimental minions off.
  - The editor and include/forced marks still offer the Brute.
  - To make it `ready`, the C# movement model needs a "who killed tonight" world
    dimension: the Demon, or the living, unsuppressed Brute. That's a C# `LiveActivity`
    change.
- **Smaller solver gap (Sexton):** the bell walk through every parish isn't modelled the
  way the Lamplighter's route is, so a Sexton seen out on the toll night counts as
  unexplained walking. It needs a Sexton route case in `LiveActivity` (C#), like the
  Lamplighter's.
- **Rules changed in review (nine suites failed after the merge):**
  - **Revenant curse fires at the hanging again,** not the next night. Deferring it broke
    the town's warning, the shared model's curse event and ~20 checks across five suites.
    It's skipped while minions are suppressed.
  - **`World.is_minion_suppressed` covers the toll night and the following day** ("until the
    following night"). With the toll night only, the day-time checks (curse, Scion's rise)
    could never fire.
  - **The Sexton lost the `night_walker` tag.** It walks once per case, and the tag moved
    `DEAL_RULES`' night-walker band, so every Default deal (and `test_beliefs`) changed.
  - **Solver view:** `WorkshopBridge.possible_roles` drops experimental roles that aren't on
    the case's script, so the Brute isn't "possibly in play" in Default games.
  - Role descs synced between `RoleDef` and `C.ROLES` (`test_role_def_poc` needs them
    identical).
  - The old knell checks in `test_roster` and `test_workshop_martyr_sexton` were rewritten
    for the bell's rules. The `test_roster` Sexton check now verifies that the bell stops
    the Poisoner.
- **Checks:** full suite and golden in the PR; `test_chunk6a` is now 39 checks.

## 2026-11-04 late night, Argon: patch_015 (Slice 6A: Sexton Rework & Brute Minion) aligned to latest main (`ce3c2d8`)

- **Base commit:** `ce3c2d883887794959287b9e1433187d18bdbd01` (latest `main` with C# solver cutover, M2b, and `baseline_9187b09`).
- **Status:** Complete, aligned to C#-only solver architecture, ready for Claude verification and CI run.
- **Deliverables:** `patch_015_chunk6a_sexton_brute.patch` and `patch_015_chunk6a_sexton_brute.zip` delivered to `Demonologist Patches`.
- **Next actor:** Claude (test run, dotnet build, golden capture check).

### Summary of Changes (Slice 6A: Night-Action Reworks: Sexton & Brute)

1. **Sexton Rework (`sim/roles/sexton.gd`):**
   - Ability can be triggered once per case, on any night from Night 1 (`min_gift_day = 1`). Decided at the start of night.
   - On the toll night, performs a Lamplighter walk (`C.BLOCKS.keys()`) through all four parishes, starting and ending at their home block.
   - Completely suppresses all minion powers until the following night:
     - Poisoner chooses target and walks abroad, but target is NOT poisoned.
     - Breathstealer chooses target, but target is NOT silenced.
     - Scion promotion is blocked if Demon is executed under suppression (Good wins immediately).
     - Revenant curse does not trigger on execution under suppression; cannot lay new totem under suppression.
     - Brute's hunt redirect is suppressed: Demon hunts instead.
   - Townsfolk gifts (Warden, Medium, Nightwatch, Lamplighter, Confessor) continue uninterrupted.
   - Silent announcement (no headline), but Sexton can claim their gift at any time.

2. **Brute Minion (`sim/roles/brute.gd` + `sim/roles/brute.gd.uid`):**
   - Role ID: `"brute"`, alignment: `"evil"`, kind: `"evil"`, minion: `true`, `tags = ["minion", "night_walker"]`.
   - While alive and unsuppressed: hunts and kills in place of the Demon; Demon stays home (`loc == "home"`).
   - Drops **two physical traces** per hunt pointing toward the Brute itself.
   - Identified strictly as a Minion (not Demon): Seer returns "neither is the demon"; Archivist can name Brute as minion.
   - When executed or suppressed by Sexton, Demon resumes hunting as normal. Executing Demon while Brute lives ends game immediately (Brute does not shield Demon).

3. **Simulation, Workshop & C# Solver Alignment:**
   - `sim/world.gd`: Added `is_minion_suppressed` helper, night-start Sexton bell toll, Brute hunting and two-trace murder generation, Demon idle-at-home while Brute hunts, poison suppression, and deferred Revenant curse resolution.
   - `sim/content.gd`: Registered `brute` in `ROLES`, `MINION_ROLES`, `EVIL_ROLES`; updated `sexton` and `revenant` descriptions.
   - `sim/role_registry.gd`: Preloaded and registered `BruteDef`.
   - `sim/roles/scion.gd`: Added minion suppression check in `can_promote_to_demon`.
   - `sim/roles/revenant.gd`: Updated description and deferred curse to night resolution so Sexton bell suppresses curse; blocked totem placement under suppression.
   - `workshop/role_constraints.gd` & `workshop/cs/RoleConstraints.cs`: Removed `< 5 alive` restriction and preserved townsfolk gifts on toll nights in lockstep.
   - `ui/case_workshop.gd`: Updated Sexton explanation text.

4. **Test Suite (`tools/test_chunk6a_sexton_brute.gd` + `.uid`):**
   - 10-check automated test suite covering Brute hunting, Demon idle, two-trace murder generation, Seer/Archivist identification, Sexton Lamplighter walk, minion suppression, Scion/Revenant blocks, and once-per-case rules.
   - Aligned directly with the C#-only solver runtime (no retired VERIFY mode).
   - Registered in `tools/ci_fast_suites.txt`.

---

## 2026-11-04 night, Claude-Bailiff: patch_014 checked and fixed; M2b and patch_014 on main; `baseline_9187b09`

- **patch_014** (base `6ff64a4`) applied on `argon/patch-014-monitor-confessor`, then main
  (the C# cutover) and `claude/m2b-podium-press` merged in. **Argon: it didn't parse as
  delivered.** Please run the suite before sending. What I fixed:
  - `confessor.gd` used an undeclared `request_refuse_line`.
  - `pick_targets` set `confessor_visited` on the NPC at runtime, which Godot objects
    can't do. It is now a declared field in `sim/npc.gd`.
  - The Monitor/Confessor content rules were pasted into `Solver._testimony_content`,
    which has no `answer` or `from_testimony`. They now live in `_report_content_impl`,
    and testimony delegates to it.
  - `test_chunk5`: `.true` doesn't parse (use `["true"]`), and it still used the removed
    VERIFY mode.
  - The Confessor added to the `people` hint package, as your test expects.
  - `test_chunk3`'s fixed `GOOD_ROLES.size() == 20` is relaxed.
- **The C# side was missing (the solver is C# only now):** without it, both roles' reports
  carried no information in the game, because C# scored them as trivially true. I added
  `ContentMonitor` and `ContentConfessorForgot` to `SolverKernel.EvaluateReportTable`. The
  Confessor's "good" reading reuses the Warden-saved mode. The Monitor is evaluated per
  world, because it depends on the Demon's identity.
  - New `tools/test_chunk5_cs_tables.gd` checks the C# table against the content rule
    world by world: 44k sampled checks, 0 mismatches.
  - **For future roles: a new report content rule needs its C# content mode in
    `_report_table_cs` + `EvaluateReportTable`, or it silently becomes "always true".**
- **M2b (podium press)** merged in; see `docs/meeting_flow_plan.md`.
- **Checks:** full suite 126/126 after the `test_chunk3` fix. Golden: two captures
  identical; vs `baseline_175e1f5` only the press field and prompt text differ.
- **For the sweep Claude:** `tools/autoplay.gd` on main ignores `--backend` (C# only).
  Merge your `--dynamic`/JSONL changes onto it.
- **Next actor:** the sweep (from main); Argon for the next patch (C#-side content for any
  new report roles).

## 2026-11-04 late night, Argon: patch_014 (Chunk 5: Monitor & Confessor) built on `claude/dynamic-script` (`6ff64a4`)

- **Base commit:** `6ff64a4c6b9007a787c9423b312fe9dbc0294fd4` (`claude/dynamic-script`).
- **Status:** Complete, ready for Claude verification and CI run.
- **Deliverables:** `patch_014_chunk5_monitor_confessor_on_6ff64a4.patch` and `patch_014_chunk5_monitor_confessor_on_6ff64a4.zip` delivered to `Demonologist Patches`.
- **Next actor:** Claude (test run, dotnet build, golden capture check).

### Summary of Changes (Chunk 5: Night-Presence Townsfolk)

1. **Monitor Role (`sim/roles/monitor.gd` + `sim/roles/monitor.gd.uid`):**
   - Role ID: `"monitor"`, alignment: `"good"`, kind: `"info"`, tags: `["ongoing_info", "role_id"]`.
   - Home-block only (`night_walk: false`), watches from home each night from Night 1 (`min_gift_day = 1`).
   - If >= 1 night-walkers crossed their home block: learns the role of one chosen at random (`{"block": blk, "walked": true, "role": role}`).
   - Marked night-walker registers as an active-script Minion or Demon (`marked_registers = true`).
   - If 0 night-walkers crossed home block: fallback `"no one walked by my house last night"` (`{"block": blk, "walked": false}`).
   - Poisoning takes place before read; Poisoner targeting Monitor causes active-script misread same night.
   - Street window sightings (`how == "window"`) strictly suppressed in `_night_sightings` for both real and bluffing Monitors.

2. **Confessor Role (`sim/roles/confessor.gd` + `sim/roles/confessor.gd.uid`):**
   - Role ID: `"confessor"`, alignment: `"good"`, kind: `"info"`, tags: `["ongoing_info", "evil_id", "night_walker"]`, `night_walk: true`.
   - Secret night-walking visit from Night 1 (`min_gift_day = 1`) to one living person. Target is unaware; gift requests from player are rejected (`score_gift_request` sets -9999).
   - Resolves before Demon attack (succeeds on same-night victim; corpse reading available for Medium).
   - Alignment read: Good target -> confirmed Good (`{"target": target.id, "good": true}`). Evil target (or Marked registering evil) -> `{"forgot": true}` (`"I heard a confession in the dark hours, but I cannot remember who came to me"`).
   - Broken misreads: visiting Good can return `forgot: true`; visiting Evil can return `good: true`.
   - Duty alibi: `"I was abroad hearing a confession on %s"` on visited block without revealing person's identity.

3. **Muddler Secret (`sim/muddler.gd`):**
   - Added Monitor single-fact mutation (swap role or toggle walked) and text rebuilding.
   - Added Confessor single-fact mutation (swap target or toggle forgot) and text rebuilding.

4. **Workshop, Solver & Evaluation (`workshop/`, `ui/`):**
   - `live_evidence.gd`: added `REPORT_FIELDS` for `"monitor"` (`["block", "walked", "role"]`) and `"confessor"` (`["target", "good", "forgot"]`), added fields to `FIELDS`.
   - `live_assessment.gd`: added `"monitor"` and `"confessor"` to `ROLES` and `reading_valid`.
   - `solver.gd`: added both to `CONTENT_ROLES`; implemented `_report_content_impl` logic for Monitor and Confessor.
   - `case_eval.gd`: added 0.5 `chance_content` for both.
   - `workshop/cs/WorldDomain.cs`: added `monitor` and `confessor` to `GiftTime` (`obsDay >= 1 && obsPhase == "night"`).
   - `ui/workshop_canvas_view.gd` & `ui/case_workshop.gd`: added card chips and explanations.

5. **Test Suite (`tools/test_chunk5_monitor_confessor.gd` + `.uid`):**
   - 14 test cases covering all role mechanics, fallback readings, Marked registrations, poisoning orders, window sighting suppressions, duty alibis, Muddler mutations, live assessment, and solver cross-referencing.
   - Registered in `tools/ci_fast_suites.txt`.

---

## 2026-11-04 late, Claude-Bailiff: C# is the only solver; meeting refresh cost cut ~3x

- **Branches:** `claude/csharp-cutover` (off `claude/dynamic-script` at `47913b7`) and
  `claude/fraction-cs` on top of it. Not on main yet. They wait for dynamic-script to land
  and tonight's sweep to finish. The last dual-mode code is on branch
  `archive/gdscript-solver-final` (`47913b7`): tags can't be pushed through our proxy.
- **Why:** the game never switched the solver to C#. `SolverBackend` defaulted to
  GDScript and only tools set C#, so every playtest ran the slow path. Michael decided:
  C# only, no parity upkeep, GDScript kept only as an archived starting point for a
  possible browser port (no C# web export).
- **What changed:**
  - The GDScript kernel implementations and `GDSCRIPT`/`VERIFY` modes are gone: 50 dead
    private functions in `workshop/`. A missing assembly is a hard error.
  - `test_csharp_slice_c1`-`c3` (parity suites) are retired.
  - `autoplay --backend` is accepted and ignored. `golden_capture --mode` accepts only
    `csharp`.
  - CI captures once, and **the baseline diff is now the gate** (it was a warning, with
    the parity job as the gate).
  - Kept on purpose, because C# mode already used them:
    - `Solver._positions` below 64 worlds;
    - `CaseEval._evaluate_posterior_gd` for a case with no compiled class table;
    - `WorldDomain._gift_time_gd` for input packing.
- **Proof:** the golden capture after the cutover is identical (`--tol 0`) to the C#
  capture at `47913b7`. Full suite on C#: 122/123, the one failure being the bug below.
- **Bug found and fixed (latent C# divergence):** in the Warden packing in
  `Solver._report_table_cs`, a guard on a door the Demon killed that night stayed
  `ContentTrivialTrue`, because `pre_fail` was set inside the Warden branch, past the
  `elif pre_fail`. Caught by `test_mechanics_warden` once the suites ran on C#.
  Pattern to watch for in C# packing: a flag set after the branch that reads it.
- **Perf (`claude/fraction-cs`):** `ReadingChallenges._fraction` was ~65% of each
  meeting refresh. Its loop over the reference worlds was one C# `Healthy` crossing plus
  a world key per world, per NPC. It is now one `SolverKernel.ReadingFraction` call per
  challenged report, and the fixture index map is cached per universe. Golden identical.
- **Measurements:** replay of playtest 40741 (10 NPCs), 2-core workspace:

  | | Whole replay | Votes (all) | Meeting waits | Slowest meeting step |
  |---|---|---|---|---|
  | GDScript | 230 s | 21.0 s | 15.6 s | ~7 s |
  | C# | 53.5 s | 10.4 s | 9.0 s | ~4 s |
  | C# + `_fraction` port | 24.0 s | 3.1 s | 2.7 s | ~1.25 s |

- **For Argon:** from here on, **solver-kernel changes go in C# only** (`workshop/cs/`).
  The GDScript files in `workshop/` only marshal inputs and call it. Don't add GDScript
  fallbacks. Patch 12 style ("compute in GDScript, pass arrays to C#") is fine for inputs.
  Logic that runs per world belongs in C#. To run locally: the .NET 8 SDK plus the Godot
  .NET build, `dotnet build Demonologist.csproj -c Debug`, then `--import`.
- **For Claude-Quill:** `test_playtest_regressions` and `test_workshop_tuning_probe`
  failed on `8ba458e` but pass on `47913b7`. Your branch's capture differs from
  `baseline_0534e6b` from record 0 (patch 13 behaviour), so dynamic-script needs its own
  baseline when it lands. The cutover is identical to your `47913b7` in C#, so record it
  from either.
- **Next actor:** Claude-Bailiff (merge order: dynamic-script, then cutover + fraction,
  then M2b).

## 2026-11-04 night, Claude-Quill: patch_013 checked on `claude/dynamic-script`; not on `main`

Sessions now sign entries. This one is **Claude-Quill** (scripts and the script builder, the
test audit, trace art, dialogue passes). Other sessions: please pick a name and sign yours.

- **Base:** patch_013 unpacked as delivered on `argon/patch-013` from `e54c2fd` (`c0a9fd9`),
  then merged into `claude/dynamic-script` (dynamic scripts, script rules/tags, night-walker
  deal band, placement table, playtest marks). The merge was clean, including
  `sim/script_def.gd`: `DEFAULT_SECRETS` keeps the Default script at four secrets, and the
  roster (so dynamic scripts) now has five, with Muddler.
- **C# build and parity: done (Claude-Quill, `47913b7`).** .NET 8 and Godot 4.7.2 .NET were
  installed per Claude-Bailiff's recipe. nuget.org is blocked here, so restore uses the
  `GodotSharp/Tools/nupkgs` folder from the Godot download as a local NuGet source.
  - **Parity bug found and fixed:** patch_013 added `ModMuddler = 4` in C#, but GDScript's
    `SolverBackend.modifier_code` still returned -1 (custom) for `"muddler"`. Packed worlds
    were off by `5 << 42`, so every VERIFY check failed (C# slices c1–c3, Chunk 4). Fixed in
    `workshop/solver_backend.gd`.
  - After the fix: `test_csharp_slice_c0`–`c3`, Chunk 4, `test_workshop_remaining` and
    `test_workshop_channel_likelihood` pass on the .NET binary. Golden csharp vs gdscript at
    `--tol 0`: identical on all five seeds.
- **Full suite (GDScript, `6ff64a4`):** 126/126 pass. Golden identical to branch + 013 before
  the Chunk 4 fixes, and identical again after the parity fix, so neither changes play.
- **`test_chunk4_psychologist_muddler` (Argon):**
  - It called `SolverBackend.mode` / `cs_available()`, which don't exist, so it didn't parse.
    Fixed to `get_mode()` / `is_csharp_available()` on `claude/dynamic-script` (`15308fe`).
  - The remaining failures are fixed by Claude-Quill (`ea8653f`); the suite now passes
    290/290. Argon: no action needed. What changed:
    - **Engine fix (`game/game_board.gd`):** in a high-trust `ask gift`,
      `Muddler.apply_private_disclaimers` deprecates the muddled card *before* the real
      reading is added, so `_deprecate_muddled_matches` skipped it and `superseded_by` was
      never set. Already-deprecated cards disclaimed by the same source now get
      `superseded_by` pointing at the real card.
    - **Fixture:** the Psychologist reading was stamped in the morning, outside its gift
      time (night, from night 1), so `source_valid` failed in every world. The 3-way
      conflict check passed only for that reason, and "liar picked + Source lied" could
      never resolve. The reading is now stamped at night.
    - **Fixture:** the Factored/Oracle rates now come from the compiled plan's channel keys
      (as `test_workshop_channel_likelihood` does), not hand-built `gift_accuracy` keys.
    - **Test arithmetic:** 7 people, 2 evil gives 42 teams × demons, × 30 layouts (Marked
      can be any of the 5 goods, not 4) = **1,260** worlds, not 1,218.
    - **Fixture:** the retraction and canvas-node checks now match the current canvas
      model (`e:<card id>` nodes; no `add_evidence`).
- **`test_workshop_remaining`** passes with 013 (the 012 known failure is fixed).
- **Golden vs `baseline_0534e6b`:** seed 42 identical; 54875, 692, 900 and 98933 diverge on
  patch_013 alone (the Psychologist rework). `claude/dynamic-script` + 013 is byte-identical
  to 013 alone on all five, so the branch adds no drift. **013 needs a new baseline.**
- **Two fixtures made independent of the deal** (the night-walker band redraws deals that
  miss it, so some seeds' roles moved):
  - `test_playtest_regressions._survival` takes the first non-Scion minion instead of
    "isolde".
  - `test_workshop_tuning_probe` phase 1.3 uses seed 97931 and takes Scions out of the
    picture for the demon-rescue vote, as patch_012 intends.
- **Full suite on the branch + 013:** everything passes except the three chunk4 checks above.
- **Next actor:** Claude-Quill merges `claude/dynamic-script` and
  records the new baseline, once Michael says go.

## 2026-11-04 night, Argon: patch_013_chunk4_psychologist_muddler_on_e54c2fd.zip

- **Base commit:** `e54c2fdd2ada7466d6f08ad5c6909387a4db7c36` (`latest-backup.zip` after `patch_012` + `M2a`).
- **Status:** `READY_FOR_CLAUDE_BUILD_AND_TEST`
- **Next actor:** Claude (`dotnet build -c Debug`, `ci_fast_suites` + `test_workshop_remaining` + `test_chunk4_psychologist_muddler`, `parity` check at `--tol 0`).
- **What's inside `patch_013`:**
  1. **`test_workshop_remaining.gd:179` Fix (`workshop/case_eval.gd`)**:
     - Restored `if not Domain.live(view): return 0.5` in `_chance_rumormonger` and `0.25` in `_chance_chronicler` so v5 non-live fixtures (`Session.new(692, "revenant")`) retract curse-era suspicion cleanly (`Merrin` delta `< 0`), while live `Domain.live(view)` keeps exact modifier-world hold rates (now including `"muddler"`).
  2. **Chunk 4A: Psychologist Rework (`sim/roles/psychologist.gd`, `sim/social.gd`, `sim/mind_meeting.gd`, `sim/mind_dialogue.gd`, `workshop/`, `ui/`)**:
     - `min_gift_day = 1` (never Night 0). Evaluates direct eligible statements heard on `w.day` (gift readings, night sightings, and night home alibis; excludes role claims, hints, and opinions).
     - Reports `mode == "none_false"` when `>= 1` eligible statements were heard and 0 were lies/misreads, `mode == "pair"` when `>= 1` was false/misread and `>= 2` were heard, and `{}` when 0 eligible statements were heard.
     - Misled rules stay aligned with `ReadingChallenges`: Poison, Delusion, Marked registration, Seer Red Herring, and Sleepwalker false home alibis count as `"misled"`; broken/bluffing Psychologists can report two true statements, two lies, or false `"none_false"`.
     - Sharing a `"pair"` reading emits companion `Via <Psychologist>` cards onto `g.board` for any cited statement the player hasn't heard yet.
     - Workshop UI (`ui/workshop_canvas_view.gd`, `ui/case_workshop.gd`, `workshop/canvas_model.gd`) lets the player pick which statement is incorrect (`Stmt 1`, `Stmt 2`, `Both`, or `Either`) and why (`Source lied` vs `Source misled`, disabling `misled` on raw night sightings), wired directly into `Graph.compile_case`, `TimeModel.hypothetical_cards`, `Solver.analyze`, `ReadingChallenges.assess` (including challenging `"none_false"` with contradictory Day-`d` statements), `CaseEval` (`_theory_fit` + Day-`d` bolstering), and `FactoredChannels` (`psych_pair_gate` matching `ChannelLikelihood`). Legacy `{"subject", "trusts", "suspects"}` payloads remain supported as `context` so existing Psychologist fixture suites stay green.
  3. **Chunk 4B: Muddler Secret (`sim/muddler.gd`, `sim/content.gd`, `sim/script_def.gd`, `workshop/cs/SolverContext.cs`, `workshop/cs/WorldDomain.cs`, `workshop/world_domain.gd`)**:
     - Added `"muddler"` to `C.SECRET_MODS` / `C.SECRET_MOD_LIST` (`ModMuddler = 4`, `* 5` world-key radix in lockstep across GDScript & C#, zero `SolverBridge.cs` signature changes). Kept `ScriptDef.DEFAULT_SECRETS` at 4 secrets so `Default` script tests stay warning-free while `ScriptDef.roster().secrets` exposes all 5 secrets and `WorkshopBridge` reads `g.w.case_script.secrets`.
     - Unaware holder; 65% muddle chance (`Tuning.Social.MUDDLER_CHANCE = 0.65`) rolled once per heard item key (`npc.muddled_items`) on relayed gift readings and night sightings only (never role claims, hints, haunts, bonds, secrets, opinions, or day sightings), mutating exactly one fact while preserving speaker/reader identity and gift role.
     - Public meeting relays (`MindMeeting.relay_reading`): claimed sources immediately debunk; unclaimed sources weigh `reveal_cost` (`debunk_muddle`) and either reveal immediately or queue `pending_muddle_debunks` so a later `_go_public` includes the debunk.
     - Private `ask gift` / `ask night` (`GameConversation`, `Muddler.apply_private_disclaimers`): source always disclaims a muddled `Via` card on `g.board` (marking `deprecated = true`, `disclaimed_by`, `workshop_usable = false`, `pressable = false`), while still only providing the real reading when normal disclosure (`tier >= 4`) allows it (`superseded_by` linked when real card arrives).

## 2026-11-04 ~22:30 ET, Claude-Tally: documentation audit (docs only), on main

- **Base:** `main` at `e54c2fd`; branch `claude/docs-audit`. No game code changed. One
  new script, `tools/tuning_index.py` (stdlib Python, regenerates `tuning_catalogue.md`;
  Godot never loads it). Golden and suites unaffected.
- **Archived** to `docs/archive/` (with `git mv`): the batch 4 docs, the batch playtest
  follow-ups, the dialogue audit, sketches and prototype, the evidence/circumstantial plan,
  the legacy retirement plan, the C# solver migration, the social trust pass, the
  text-system handoff, the unreliable-source note. Links into them are updated. Their
  unbuilt leftovers are now BACKLOG items (C4 port, NPC-to-NPC credibility, social pass
  leftovers, the Seer's small rise, the trace-weight sweep).
- **BACKLOG.md:** checked item by item against the code. Built, absorbed (by the meeting
  plan) and superseded items moved to BACKLOG_COMPLETED.md ("Moved Nov 4", original text
  plus a closing note each); open items rewritten without the session commentary and code
  locations. The "Template gaps" list is now "Workshop gaps".
- **DESIGN.md:** brought up to the current code (scripts and the deal, 20 town gifts, the
  Tavern and Town Hall, profile receipts and the new traces, the shared model as the only
  judge, rapport and credibility, the meeting after M2a, the C# backend, the analyst bot).
- **TUNING_NARRATIVE.md:** rewritten from scratch for the shared model.
  **tuning_catalogue.md:** regenerated as an index of every `sim/tuning.gd` constant and
  the files that use it (`python3 tools/tuning_index.py` after changing tuning).
- **For everyone:** when a doc and the code disagree, the code was taken as the truth,
  except where it looked like drift from an explicit decision (none found).
- **Next actor:** no change (Argon for the known `test_workshop_remaining` failure;
  Claude-Tally for the overnight balance sweep once main is settled).

## 2026-11-04 evening, Claude: patch_012 + M2a merged to main; new baseline `baseline_0534e6b`

- **Base:** patch_012 unpacked at `fdf4760` as declared (`3e7b88a`), merged with `main`
  (`e39fa1f`, the test audit) on `claude/m2a`, then the M1/refresh leftovers and M2a.
- **012 lands.** All listed fixes check out; build 0 warnings, 0 errors.
- **Merged with one known failure (Michael's call):** `test_workshop_remaining`
  "presenting the restored epoch retracts earlier curse-era suspicion"
  (`tools/test_workshop_remaining.gd:179`). Fails on `3e7b88a` alone: Merrin's delta is
  +0.0015 instead of < 0, from the new `_chance_rumormonger` calibration. **Argon: please
  fix in the next patch.**
- **Three test updates for 012's intended behaviour (mine, no code changes):**
  `test_backlog_batch2` checks `C.spoken_night` instead of "night 3";
  `test_playtest_regressions` drops Surveyor from the no-fake-Medium list (it has one since
  011) and runs the demon-cover vote check without a ready Scion (012's Scion fallback);
  `test_shadow` lets a turned soul keep its good-era ledger, frozen at the turn.
- **M2a** (see `docs/meeting_flow_plan.md` slice M2): `nominate <name> [#N|raw]` with the
  on-deck case, nomination menu in `ui/main.gd`, informational "already public" toast,
  `Mind.card_already_weighed` skip, `MindMeeting.block_safety`, reactive testimony and
  crowd fading. Tests: `tools/test_meeting_m2a.gd` (in `ci_fast_suites.txt`).
  Gotcha: testimony state keeps `spoke_ids` (the game uses `_testimony["spoken"]` as an
  int), and only plain data goes on `w.meeting["testimony"]` (NPC objects there break the
  Debug on/off fingerprint).
- **Leftovers:** `answer_opinion` passes on second-hand role claims/hints
  (`_second_hand_gift_note`); `WorkshopOwnership.refresh(g, n)` is one call and
  `w.workshop_refresh` takes `(n)` only (capture/profile hooks updated).
- **Checks:** full suite 124/125 (above); golden 2x GDScript identical, C# identical;
  passive A/B in `docs/golden_baseline.md`.
- **Next actor:** Argon (the one failing check); Claude for M2b (`podium_press`).

## 2026-11-04, Argon: Nov 4 Playtest Fixes (`95955` & `40741`) + `RoleConstraints.cs` CA2014 (`patch_012_playtest_fixes_fdf4760.zip`)

- **Base:** `main` at `fdf4760f2a774479cad42ac1c91bfc4b4e4495b9` (`fdf4760`, post-`patch_011` + `baseline_4f7ba7f`).
- **Deliverable:** `patch_012_playtest_fixes_fdf4760.zip` in Google Drive (`Demonologist Patches`), containing all modified/new repo files relative to `fdf4760f2a774479cad42ac1c91bfc4b4e4495b9` plus `MANIFEST_PLAYTEST_FIXES_FDF4760.md`.
- **Scope:**
  1. **Rumormonger & Chronicler `chance_content` calibration (`workshop/case_eval.gd`)**: Replaced the `0.50` fallback for `SECRET_PAIR` (`rumormonger`) and `0.25` constant for `chronicler` with exact modifier-domain hold rates (`_chance_rumormonger`, `_chance_chronicler`) so uncontradicted Rumormonger and Chronicler readings no longer self-incriminate their speaker with `"their Rumormonger report doesn't fit what we know"` (`q` packs from GDScript into C#, preserving `--tol 0` parity).
  2. **Presentation voice routing (`sim/dialogue_presentations.gd`)**: Scoped `present_conflict_weighing` on bounded listeners strictly to `status == "inconsistent"` (stopping background town lies in `full_case` from hijacking accepted coherent cases), and read `snapshot.selected` before falling back to `[]` (never `ignored_arr`) so unpresented background town cards in `reasoning.ignored` stop firing `present_partial_attention` on 3- and 4-card cases.
  3. **Evil protection-promise awareness (`game/game_conversation.gd`, `sim/evil.gd`, `sim/tuning.gd`)**: `GameConversation._offer_command` now calls `Evil.note_player_offer` when promising a `vigil` or `ward` to an evil NPC, recording `player_vigil` / `player_ward` in `n.intel` (shared naturally with teammates via `Evil.share_intel`) and penalizing promised vigil blocks / warded doors in `Evil.choose_kill_target` and `Evil.choose_poison_target` with zero extra RNG draws.
  4. **Scion-active voting/nomination cover & doomed-Demon rescue votes (`sim/evil.gd`, `sim/mind_meeting.gd`, `sim/tuning.gd`)**: Added `Evil.scion_fallback_active(w)` (`living >= 5` and unbroken Scion; Sexton suppression deferred to Chunk 6 rework). When active, `teammate_value` weights Scion (`1.45`) above the replaceable Demon (`1.1`), Demon trials flow through `SHADOW_SELF` + `evil_override`, and landslide teammate trials (`have >= target_votes` or `projected >= target_votes + 2`) drop non-pivotal `NO` stakes (`0.20`) so minions and Scions keep cover instead of casting futile `NO` votes. Conversely, when no Scion fallback is active, a Demon on the block backs mathematically live counter-nominations (`survival overrides cover`).
  5. **Natural night phrasing & Night Watch / accusation sighting deduplication (`sim/evil.gd`, `sim/mind_meeting.gd`)**: Replaced raw `"on night %d"` / `C.night_name` strings in `Evil.bluff_reason` and `MindMeeting._resolve_shared_reason` with `C.spoken_when(..., w.day)`. Sharing a `nightwatch` reading in `_go_public` now marks covered `(who, day, block)` keys in `n.told_to`, and `_append_accusation_sighting` emits the usable `sighting` card without prepending a duplicate spoken line ahead of `acc["line"]`.
  6. **C# CA2014 warning cleanup (`workshop/cs/RoleConstraints.cs`)**: Hoisted `Span<int> fbBuf = stackalloc int[16]` outside the `for (int k = 0; k < 3; k++)` loop in `RegistrarYesStep` (`0 warnings, 0 errors`).
  7. **Regression suite (`tools/test_playtest_nov4_fixes.gd`, `tools/ci_fast_suites.txt`)**: Added deterministic tests for all fixes plus `SolverBackend.get_verify_mismatches()` verification.
- **Note for Claude:** Intentional behavior/prior fixes (`chance_content`, evil kill/vote/bluff phrasing, sighting dedup) will intentionally shift golden trajectories; please verify `dotnet build -c Debug` (0 warnings, 0 errors), `tools/ci_fast_suites.txt` + `test_playtest_regressions` + `test_case_eval` + `test_dialogue_batches_5_6_7` + `test_backlog_batch4`, `--tol 0` C#/GDScript parity on the same commit, and recapture `tools/golden/baseline_*`.
- **Next actor:** **Claude**.

## 2026-11-04 ~16:00 ET, Claude: patch_011 checked, green after one test fix, on main; new baseline

- **Base:** `2e91218` as declared; unpacked on `argon/patch-011-chunks-2-3`. Keeps M1, the
  refresh cleanup, the Seer guard and the 165ce09 config; includes my 010 branch fixes.
- **Your four fixes land:** Registrar slate (seeds 9397/9400), Town Hall `theory_fit`,
  Clerk/Archivist `ROLE_IN_GROUP`, warm-greeting check: all pass.
- **One more fix (Claude):** `test_backlog_batch4` "help is read-only" / "developer summary
  formatting does not change the game" required `state == "day"`, but seed 4242 now opens
  on an approach (the new roles change the deal). They compare the state before and
  after instead.
- **Build:** 0 errors; one warning, `RoleConstraints.cs:1108` CA2014 (stackalloc inside a
  loop, possible stack overflow). Worth hoisting it out of the loop.
- **Suites:** 37 (CI fast list + chunk 2/3, role_def_poc, roster, buildings, case_script,
  UI, batch4, dialogue, legacy_migration, tuning_hoist, fixes, social, peer gossip...):
  all pass. All 286 scripts parse.
- **Golden:** new baseline `baseline_4f7ba7f` (CI updated): two GDScript captures
  identical, C# identical. Passive A/B (seeds 2000-2011): good wins 25% -> 42% at 7 NPCs,
  33% -> 8% at 10. Twelve seeds is noisy, but the 10-NPC drop deserves a bigger sweep.
- **Pushed to `main`.** Next actor: Argon (CA2014), or meeting plan M2 / M3a.

## 2026-11-04, Argon: Rebased `argon/patch-010-chunks-2-3` onto `2e91218` + Fixed All 4 Failing Checks (`patch_011_chunks2_and_3_on_2e91218.zip`)

- **Base:** `main` at `2e91218f973eada8e7fdc8bba3044a6b3199f6dd` (`2e91218`, M1 peer role gossip + Seer fix + refresh cleanup + `baseline_165ce09`).
- **Deliverable:** `patch_011_chunks2_and_3_on_2e91218.zip` in Google Drive (`Demonologist Patches`), containing all replacement/new repo files relative to `2e91218` plus `MANIFEST_CHUNKS2_AND_3_ON_2E91218.md`.
- **Supersedes:** `patch_010_chunks2_and_3_on_bdd1dc0.zip` (renamed `SUPERSEDED_patch_010_chunks2_and_3_on_bdd1dc0.zip` on Drive) and incorporates all build/parse/test-key fixes from `argon/patch-010-chunks-2-3` (`dfd7769`).
- **Status:** Ready for Claude verification (`dotnet build -c Debug`, `test_chunk2_world_mask_roles`, `test_chunk3_executor_registrar`, `test_buildings_tavern_town_hall`, `test_role_def_poc`, `test_dialogue_batches_5_6_7`, `test_peer_role_gossip`, `test_case_script`, `test_ui`, `test_backlog_batch4`, `test_roster`, `tools/ci_fast_suites.txt`, `--tol 0` C#/GDScript parity check, and intentional recapture of `tools/golden/baseline_*`).
- **Next actor:** **Claude**.

### 1. Clean 3-Way Rebase onto `2e91218`

- Preserved all `dfd7769` branch fixes (`SolverKernel.cs:739` `specInts[5] != 0`, `chronicler.gd` & `executor.gd` `ongoing_info_claim_term`, `jury.gd` `C` preload, untyped `registrar.gd:pick_targets`, baseline delta check on `SolverBackend.get_verify_mismatches()`, and `gift_accuracy:<source>:<night>` channel keys).
- Preserved all `2e91218` `main` additions and cleanups: M1 peer role gossip (`sim/social.gd`, `sim/evil.gd`, `sim/tuning.gd`, `tools/test_peer_role_gossip.gd`), `game/workshop_ownership.gd` plan reuse, `workshop/jury.gd` shallow case copy (`attention.case.duplicate(false)`), `sim/roles/seer.gd` solo-evil guard + `clean_asked` self-filter, and unioned `tools/ci_fast_suites.txt` (`test_peer_role_gossip`, `test_case_script`, `test_chunk2_world_mask_roles`, `test_chunk3_executor_registrar`). Verified all 20 `C.GOOD_ROLES` belong to a `C.HINT_PACKAGES` family for M1 peer hints.

### 2. Root Causes & Fixes for the 4 Red Checks

1. **`test_chunk3_executor_registrar` ("Registrar Night 0 slate ... guarantees >=1 role in play", seeds `9397` & `9400`): `sim/roles/registrar.gd`, `tools/test_chunk3_executor_registrar.gd`:**
   - **Root cause:** On Night 0 in `sim/world.gd:resolve_night()`, `Poisoner` poisons a target (`by_id[poison_t].poisoned = true`) *before* `_receive_info()` runs. On seeds `9397` and `9400`, the Poisoner blind-poisoned the Registrar on Night 0, so `n.gift_broken()` was `true` and `draw_slate(w, broken = true)` intentionally took the `if broken:` branch (`registrar.gd:97-105`), drawing 3 out-of-play roles (`[dowser, seer, scion]` / `[scion, dowser, gravedigger]`) and caching them permanently into `n.registrar_roles`.
   - **Fix:** Like `Executor`'s permanent Night 0 charge, `Registrar`'s permanent 3-role register (`n.registrar_roles`) now treats only permanent `Delusional` (`n.secret_mod == "delusional"`) as broken at Night 0 slate generation (`_ensure_slate` and `w.day == 0` in `generate_reading`). A single Night 0 blind poison no longer permanently bricks the Registrar across Nights 1+ or causes `RoleConstraints`'s forced `>= 1 in-play` invariant to reject the true world on later unpoisoned nights; Night 1+ Poison still corrupts that night's target check (`reported_yes`). Added explicit regression checks for seeds `9397` and `9400`.
2. **`test_buildings_tavern_town_hall` (`CaseEval` `theory_fit == 0.000`): `workshop/case_eval.gd`:**
   - **Root cause:** `_theory_fit` called `Solver.Roles.fits_table(view, universe, cards, {}, case_data.get("answers", {}))` with `bluffs = false` (default), treating both `cl_0` (`p0` claims Seer) and `cl_1` (`p1` claims Clerk) as non-bluff true claims simultaneously alongside `th_1` (`[seer, clerk]`), leaving `0` compatible worlds.
   - **Fix:** Passed `listener.get("knowledge", {})` into `_theory_fit` (from both `_evaluate_posterior_gd` and `_evaluate_posterior_cs`) and called `Solver.Roles.fits_table` with `bluffs = Domain.live(view)` plus the same report-to-declaration fallback used by `_fits_over`, yielding `0.0 < theory_fit < 1.0` when `in_play_role` rules out one of two rival claims.
3. **`test_role_def_poc` ("Workshop solver/assessment validates Clerk and Archivist ROLE_IN_GROUP readings"): `tools/test_role_def_poc.gd`:**
   - **Root cause:** `_give()` hot-swapped roles after `g.new_case(9103, 7)` (which had already run Night 0 Poisoner, `_assign_secret_mod()`, and Day 1 Morning `_pre_pair()` conversations) without clearing `poisoned` or `known_claims` (and without clearing `delusional` on `clerk`/`arch`, even though lines 172 & 175 passed unused `{"poisoned": false}` expecting healthy readings). After Chunk 2's Night 0 RNG shift, stale pre-swap `known_claims` / Night 0 `poisoned` or `delusional` state on seed `9103` made `[c_card, a_card] + private_evidence` unsatisfiable in `Solver.solve`.
   - **Fix:** Cleared `poisoned`, `known_claims`, and `believed_roles` on both `holder` and `n` in `_give()`, and cleared `delusional` on `[clerk, arch, grave]` (and `marked` on `subject_good`) in `_test_role_in_group_hooks()`.
4. **`test_dialogue_batches_5_6_7` ("Second talk after one-shot murder greeting falls back to warm rapport greeting"): `tools/test_dialogue_batches_5_6_7.gd`:**
   - **Root cause:** `Mind.greeting_line(g.w, speaker, {})` defaults to `roll_attitude = true`, rolling `rng.randf() <= (1.0 - composure) * 0.9` (`0.90` even when `composure = 0.0`, failing 10% of the time into `greet_neutral`), and Chunk 2's Night 0 RNG count shift pushed seed `5605`'s draw into that 10% tail.
   - **Fix:** Passed `roll_attitude = false` (`Mind.greeting_line(g.w, speaker, {}, false)`) on line 332 (1-draw RNG parity with `greeting_cue` is already tested right above on lines 312-318).

## 2026-11-04 ~05:15 ET, Claude: meeting plan M1 (peer role gossip) and new golden baseline, on main

- **M1** (`sim/social.gd`, `sim/evil.gd`, `sim/tuning.gd`): NPCs privately hint at their
  gift's family to friends (bond >= 0.55) or claim it outright (bond >= 0.68, or >= 0.55
  under pressure), even with no readings; evil uses its agreed bluff with the same
  formulas. Claims fill `known_claims` (with `first_claimed_day`) and go through
  `Mind.hear_claim`; hints are remembered. Gift talk isn't relayed peer to peer. Evil
  listeners log the speaker as a threat. Good NPCs with an untold gift count as having
  news on Days 1-2. The player hears second-hand claims and hints through gossip and
  `ask about <role>`. `IDLE_CHAT_WEIGHT` 0.30 -> 0.18. Not done: the `answer_opinion`
  second-hand note.
- **Tests:** new `test_peer_role_gossip` (20 checks, in the fast CI list); 30 suites pass.
- **Passive A/B** (seeds 2000-2011, C#): good wins 33% -> 25% at 7 NPCs, 17% -> 33% at 10;
  executions similar. Noise-level for 12 seeds; M4's 150-seed sweep is the real measure.
  (A first run showed 0% for M1: that worktree's C# build was stale from the 010 branch.
  Rebuild C# after switching branches before any `--backend csharp` run.)
- **New golden baseline `baseline_165ce09`** (CI `BASELINE` updated): two GDScript
  captures identical, C# identical. See `docs/golden_baseline.md`.
- **Next actor: Argon** for patch_010 (rebase on this main; four checks listed in the
  010 entry). Next meeting-plan work: M2 trial engine (or M3a UI).

## 2026-11-04 ~04:30 ET, Claude: five failing suites fixed, Seer fix, refresh cleanup (M2 item), on main

- **Seer bluff** (`sim/roles/seer.gd`, Argon's seed-2004 trace): a lone evil Seer bluffer
  no longer "clears its teammate" (itself), and asked targets never put the bluffer in
  its own pair. None of the five golden seeds hits this, so the golden is unchanged.
- **The five suites outside CI that failed on main** (all pass now):
  - `test_dialogue_batches_5_6_7`: `DayConversationView` builds its nodes on first use
    (idempotent `_build()`), so it works before entering a running tree.
  - `test_dialogue`, `test_legacy_migration`: checked old wording replaced by voiced
    lines; now check the substance (the lie accusation; "at the meeting", no question used).
  - `test_tuning_hoist`: deleted `NIGHT_SIGHTING_ELSEWHERE` / `_NEAR_DEATH` /
    `_WALK_DISCOUNT`, unused since Phase 4 removed `night_sighting_scale`.
  - `test_legacy_purge_phase2c`: not broken, just slow (40 to 60 minutes here); passes
    with `--timeout 3600`.
- **Refresh cost cleanup** (meeting plan M2's first item): the "after" refresh reuses the
  first plan when its source doubt and candidate suspicion are exactly unchanged, and
  `Jury._consequences_eval` copies the case shallowly per person. Seed 42 to Day 4:
  `outer_prep` 280 -> 207 calls, 975 -> 835 ms self time (GDScript; wall time was noisy,
  other jobs running). I kept the before/after API for now (the golden and profiler hooks
  use it); folding it is a separate small change.
- **Checks:** 31 suites (fast list + the five + touched), plus 8 ownership/jury suites
  after the cleanup. Golden: two GDScript captures identical, C# identical, and identical
  to `baseline_82faa5b` (`--ignore engine,sus_why,sus_src`), so the baseline stands; it
  is re-recorded with M1, the first change that moves it.

## 2026-11-04 ~03:45 ET, Claude: patch_010 checked, NOT merged (5 suites red), fixes on branch

- **Base:** `bdd1dc0` as declared; unpacked on `argon/patch-010-chunks-2-3` (supersedes
  009; my 009 branch is abandoned). Merged `claude/seer-fix-rebaseline` (your equivalent
  Seer fix kept; the parameter is `n` on main now, not `_n`).
- **Didn't build or load as delivered (fixed on the branch):**
  - `SolverKernel.cs:739` `bool convEvilAtObs = specInts[5];` (CS0029).
  - `chronicler.gd` / `executor.gd` use `Tuning.Roles.ONGOING_INFO_LATER_CLAIM` and
    `ONGOING_INFO_REVEAL_COST`, which don't exist (the patch has no `tuning.gd`). Both now
    use the base `ongoing_info_claim_term(w.day)` while the gift is pending (D1 -0.45,
    D2 -0.20, 0 after), one-shot bonus once spent. Change it if you meant other numbers.
  - `jury.gd:825` uses `C` without preloading `content.gd`.
  - `registrar.gd` `pick_targets(...) -> String`: the parent has no return type, so the
    override doesn't parse.
  - Tests called `SolverBackend.reset_verify_mismatches()` (doesn't exist; the counters
    live in the C# bridge). They now compare against the count at the start.
- **Test fixes (on the branch):** channel rates keyed `accuracy:<id>:<day>:<phase>`
  (the channels use `gift_accuracy:<source>:<night>`); Magistrate bluff check passed the
  real Magistrate's nomination, which a bluffer may use; `w.secret_mod_kind` isn't a
  World field.
- **Still red, for Argon:**
  1. `test_chunk3_executor_registrar` "Registrar Night 0 slate ... guarantees >=1 role in
     play": fails on seeds 9397 and 9400 (script town archivist/clerk/dowser/gravedigger/
     seer/warden/registrar, minions poisoner/scion). Slates `[dowser, seer, scion]` and
     `[scion, dowser, gravedigger]` with the Poisoner in play: `draw_slate` took the
     `m_pick in in_minions` branch (random town pair), so at draw time it counted the
     Scion as in play. Probably the minion's role or `initial_minion_ids` isn't final yet
     when Night 0 draws.
  2. `test_buildings_tavern_town_hall` CaseEval check: `theory_fit` is now 0.000 (was 1.0
     on main). Your `_theory_fit` change adds `Roles.fits_table(view, universe, cards, {},
     answers)` with bluffs off, so the two claims count as true and no world fits.
  3. `test_role_def_poc` "Workshop solver/assessment validates Clerk and Archivist
     ROLE_IN_GROUP readings": no worlds (passes on main).
  4. `test_dialogue_batches_5_6_7` "Second talk after one-shot murder greeting falls back
     to warm rapport greeting" (passes on main; `game_conversation.gd` / greeting change?).
- Everything else in the CI fast list plus the chunk/buildings/case-script/UI suites
  passes; chunk 2 passes after the fixes.
- **Next actor: Argon.** Rebase onto `main` (it moves tonight: Seer fix, refresh cleanup,
  new golden baseline) and fix 1-4.

## 2026-11-04, Argon: Rebased Chunk 2 + Chunk 3 (Executor & Registrar) on Script-Customization Baseline (`patch_010_chunks2_and_3_on_bdd1dc0.zip`)

- **Base:** `main` at `bdd1dc0b3a0d7b9a35530b4014ad5981daa9f863` (`bdd1dc0`, Case Scripts / Script Customization push).
- **Deliverable:** `patch_010_chunks2_and_3_on_bdd1dc0.zip` in Google Drive (`Demonologist Patches`), containing all 62 replacement/new repo files plus `MANIFEST_CHUNKS2_AND_3_ON_BDD1DC0.md`.
- **Supersedes:** `patch_009_chunk2_world_mask_roles.zip` (which targeted `3340da8` right before `bdd1dc0` landed and has been renamed `SUPERSEDED_patch_009_chunk2_world_mask_roles_3340da8.zip` on Drive so you only need to unpack `patch_010` cleanly on `bdd1dc0`).
- **Status:** Ready for Claude verification (`dotnet build -c Debug`, `test_chunk2_world_mask_roles`, `test_chunk3_executor_registrar`, `test_case_script`, `test_ui`, `test_backlog_batch4`, `test_role_def_poc`, `test_roster`, `test_buildings_tavern_town_hall`, `tools/ci_fast_suites.txt`, `--tol 0` C#/GDScript parity check, and **intentional recapture** of `tools/golden/baseline_*`).
- **Next actor:** **Claude**.

### 1. Rebase onto `bdd1dc0` (Case Scripts Integration)

1. **`ScriptDef.DEFAULT_TOWN` vs `C.GOOD_ROLES` (`sim/script_def.gd`, `sim/content.gd`):**
   - `C.GOOD_ROLES` and `ScriptDef.roster().town` hold all **20** ready town roles (`15` starter + `augur`, `chronicler`, `executor`, `magistrate`, `registrar`), so `LiveAssessment`, `SharedLedger`, `ScriptEditor`, and `ScriptBuilder` recognize and offer the full expanded roster.
   - `ScriptDef.DEFAULT_TOWN` preserves the **15**-role starter Default script (`TOWN_SIZE = 15`), keeping `ScriptDef.default_script()` at `15 / 4 / 4 / 1` with zero warnings (`test_case_script.gd` green).
   - Updated `tools/test_ui.gd` (`:471,:498`) and `tools/test_backlog_batch4.gd` (`:940`) to compare `roles_box` row counts against `g.w.case_script` sizes (matching `ui/main.gd:556-564` from `bdd1dc0`), and added `ScriptDef.tags` to all five Chunk 2 + Chunk 3 roles.
   - Merged `bdd1dc0` changes cleanly with Chunk 2 in `sim/world.gd`, `game/game_screens.gd`, `sim/roles/dowser.gd`, `sim/roles/seer.gd`, and `sim/roles/surveyor.gd`.

### 2. Chunk 3 Summary — Executor & Registrar (Sim + UI + Lockstep GDScript/C# Solver)

1. **Executor (`sim/roles/executor.gd` + `.uid`, `sim/world.gd`, `workshop/live_history.gd`, `workshop/source_doubt.gd`):**
   - **Night 0:** Learns one other townsperson (`data: {"target": id, "assigned": true}`), recorded as a shareable Night 0 reading. Delusional Executors still get a real charge on Night 0 and only receive a corrupted role on death.
   - **Morning Post-Death Trigger (`_morning_executor_gifts` in `start_phase()`):** On `Morning` (`day >= 1`), if the Executor's charge died yesterday or last night (`executed`, `demon`, or `martyr`), learns their role (`data: {"target": id, "role": role}`). Checks `gift_broken()` on that Morning (honoring Night `d-1` Poison, which wears off on Night `d`), applies Gravedigger's 30% `Marked` evil-role misread scoped to `w.case_script`, and supports Scion promotion when an executed original Demon (`alive_before >= 5`) is read as `"demon"`.
   - **Workshop & C# Lockstep (`RoleExecutor = 11`):** Enforces target consistency across Night 0 + Morning Executor cards (`executorTargetToken`), `History.died_before_morning` timeline verification (`(death_tick / 4) + 1 == morning_day`), `SourceDoubt` caught-lie/sincerity rules, and `PoolAny` + Scion-promotion role assignment.
2. **Registrar (`sim/roles/registrar.gd` + `.uid`, `game/game_conversation.gd`, `ui/main.gd`, `workshop/role_constraints.gd`, `workshop/cs/RoleConstraints.cs`):**
   - **Night 0 Slate:** Learns 3 distinct roles drawn strictly from `w.case_script` (`town` minus `"registrar"`, plus at most 1 from `minions` at 50% odds, never `"demon"`), with **at least 1 role guaranteed in play** (`data: {"roles": [r0, r1, r2]}`). A Delusional Registrar draws 3 out-of-play script roles when available.
   - **Night 1+ Target Checks & Player Requests:** Checks one other person each night (`data: {"roles": [...], "target": id, "yes": bool}`), supporting player `"ask check <name>"` / `"ask register <name>"` requests and UI picker. `Marked` triggers a 50% false `Yes` **only** when a Minion role is on the 3-role slate, and never suppresses a true good-role match.
   - **Workshop & C# Lockstep (`RoleRegistrar = 12`, `CardStride = 24`, zero `SolverBridge.cs` signature changes):** Enforces slate consistency across cards, `~regNoMask` exclusion on all 3 slate roles (automatically catching fake claims of any listed good role), `Yes` branching across the 3 roles + `Marked` (clearing Demon on any `Yes`, clearing all Evil on a 3-good-role `Yes`, and deducing `Marked` if the same target reads both `Yes` and `No` on a Minion-bearing slate), and **forced 1+ in-play slate matching** composed directly with `TownHallMatches` and `FactoredChannels` (`town_hall_pool`).

## 2026-11-04, Argon: Roster & Mechanics Chunk 2 - World-Mask Townsfolk + Dowser Public Fix (`patch_009_chunk2_world_mask_roles.zip`)

- **Base:** `main` at `3340da8575198d878a90bbe819ab5ca506791b73` (`3340da8`, 11:43 PM EST archive with `patch_008` + Town Hall art merged).
- **Deliverable:** `patch_009_chunk2_world_mask_roles.zip` in Google Drive (`Demonologist Patches`), containing all 45 replacement/new repo files plus `MANIFEST_CHUNK2_WORLD_MASK_ROLES.md`.
- **Status:** Ready for Claude verification (`dotnet build -c Debug`, `test_chunk2_world_mask_roles`, `test_role_def_poc`, `test_roster`, `test_buildings_tavern_town_hall`, `tools/ci_fast_suites.txt`, `--tol 0` C#/GDScript parity check, and **intentional recapture** of `tools/golden/baseline_*` since Chunk 2 changes `GOOD_ROLES`, `IDENTIFIER_ROLES`, `HINT_PACKAGES`, `Dowser` public-only eligibility, `Surveyor` Night-0 gift semantics, and `seer.gd` solo-evil bluffs).
- **Next actor:** **Claude**.

### 1. Answers to Claude's `patch_008` Handoff Notes

1. **Town Hall `theory_fit` (`case_eval.gd:410,477` & `test_buildings_tavern_town_hall.gd:326`):**
   - Confirmed: in `CaseEval`, `_fits_over` passes `{}` (empty answers) to `Solver.Roles.fits_weights`, so `post` is intentionally NOT conditioned on `case_data.answers`; instead, `_theory_fit` measures the share of `post` consistent with `case_data.answers`.
   - It returned `1.0` in `patch_008` only because `case_eval.gd` lines 410 (`_evaluate_posterior_gd`) and 477 (`_evaluate_posterior_cs`) gated `_theory_fit` on `not a.get("positive", []).is_empty() or not a.get("blocks", []).is_empty()`, missing `or str(a.get("in_play_role", "")) != ""` when `positive` and `blocks` were empty. Added that check to both `.gd` and `.cs` callers in `case_eval.gd` and restored `ev_res.theory_fit > 0.0 and ev_res.theory_fit < 1.0` in `tools/test_buildings_tavern_town_hall.gd`.
2. **Solo-evil Seer bluff self-pair fix (`sim/roles/seer.gd:184,196`):**
   - Included in this patch (`mate != _n` on line 196 and `x != _n.id` on `asked` at line 184) since Chunk 2 already requires a fresh golden baseline capture. Covered by regression test in `tools/test_chunk2_world_mask_roles.gd`.

### 2. Chunk 2 Summary (Sim + UI + Lockstep GDScript/C# Solver)

1. **Dowser Public-Area Fix (`sim/roles/dowser.gd`):**
   - Both the Dowser and counted blockmates must be in a public location (`not at_home()`), in both real `generate_reading` and evil `generate_bluff_reading`. Updated `tools/test_role_def_poc.gd` accordingly.
2. **Surveyor Rework (`sim/roles/surveyor.gd`, `workshop/scenario.gd`):**
   - Starts knowing (Night 0) whether all residents on a random block (**not their own**, **at least 2 residents**) share the same alignment (`data: {"block": blk, "same": bool}`). `Marked` registers evil 50%.
   - Preserves legacy `data: {"count": int}` (`ContentSurveyor = 6`) in `Scenario.generate` and `Solver`/`CaseEval` so frozen Workshop v5 fixtures (`test_workshop*`, `test_csharp_slice_c3`) stay untouched; restricts `"unlikely"` reading-challenge mode to legacy `count` Surveyor cards.
3. **Chronicler (`sim/roles/chronicler.gd` + `.uid`):**
   - Night 3 only (`w.day == 3`, `phase == "night"`), `cannot_hold_solo_secret = true`, never targets self. Reads **case-start state** (`initial_minion_ids`, `initial_evil_ids`, `initial_secret_holders`, with `Marked` always in the secret-holder slot): 3 other townsfolk (living or dead) comprising 1 ordinary townsfolk, 1 secret-holder, and 1 minion (`data: {"trio": [a, b, c]}`).
4. **Augur (`sim/roles/augur.gd` + `.uid`, `sim/world.gd`):**
   - Evening `run_day_gift` (`Day 1+`, start of Evening before player Evening action and meeting): Yes/No reading (`data: {"yes": bool}`) on whether the Augur shared a **public block** (`not at_home()`) with the Demon during **Morning or Afternoon** earlier that day (Evening excluded). `Marked` triggers 50% (no persistent Red Herring).
5. **Magistrate (`sim/roles/magistrate.gd` + `.uid`, `sim/world.gd`, `game/workshop_bridge.gd`):**
   - Night `1+`: learns whether the **first non-player, non-Magistrate nomination** that day shared an alignment (`data: {"nominator", "nominee", "same"}`), evaluated at nomination time (before any end-of-meeting Revenant curse activation on that ballot, while honoring active curses from earlier days). Produces no reading (real or bluff) if no eligible nomination occurred. Stamps `"nomination"` and `"meeting"` public events with `"evening"` phase for public timeline validation.
6. **Lockstep GDScript & C# Kernels (`workshop/solver.gd`, `workshop/cs/SolverKernel.cs`, `workshop/case_eval.gd`, `workshop/cs/CaseEvalKernel.cs`, `workshop/cs/WorldDomain.cs`):**
   - `WorldDomainKernel.GiftTime`: added `chronicler` (Night 3) and `augur` (Evening Day 1+).
   - `SolverKernel` / `solver.gd`: added `ContentParityGroup = 7` (new Surveyor + Magistrate), `ContentChronicler = 8`, and `ContentAugur = 9`, bypassing `sig_groups` when `contentMode in {8, 9}` since `sig_groups` collapses `world.Demon`.
   - `CaseEvalKernel` / `case_eval.gd`: uses `CoarseMasks` whenever `rolesOn || seer` (`seer_flag` includes `augur`) and scores `Augur` daytime overlap via `moveFactorSpecs` `kind = 2` using exact 0-ULP IEEE-754 dyadic slot probabilities (`{0.0, 0.1875, 0.25, 1.0}`, `p_ref = 87/256` or `169/256`) with zero changes to `SolverBridge.cs` method signatures.

## 2026-11-04 ~00:30 ET, Claude: patch_008 checked, green after test fixes, on main

- **Base:** `35b3861` as declared; unpacked on `argon/patch-008-buildings`.
- **Art:** Town Hall sprite (Michael's) at `assets/art/buildings/town_hall.png`, in
  `map_view.BUILDING_ART`, replacing the blank square. It sits third on the Square,
  clickable like the other buildings. With three buildings on a block the tavern's sign
  reads "Tavern" (`SHORT_SIGNS`) so it doesn't run into the well's.
- **Fixes (tests only, besides one):**
  - `test_dialogue_batches_5_6_7`: missing `Tuning` preload (the file didn't parse).
  - `test_buildings_tavern_town_hall`:
    - The fixture turned someone evil by setting `alignment` directly (no bluff, no
      shadow), which crashed meetings (`mind_meeting.gd:123` bluff lookup, `:1445`
      `role_def(...)` on Nil). It now uses `w.turn_evil`.
    - The clash and in_play_role checks assumed claims could be bluffs, but `Solver.solve`
      takes every selected card as true. Rewritten: Town Hall [Seer, Clerk] + true claims
      of both = no worlds (the claims alone have worlds); picking "seer" rules out a true
      Clerk claim, picking "clerk" keeps it.
    - **Argon, please confirm:** the CaseEval check required `theory_fit < 1.0`; it's 1.0
      because the in_play_role answer also constrains the posterior. Relaxed to `> 0`.
      Tighten it if you meant a case where the answer isn't conditioned on.
- **Suites** (.NET Godot): the CI fast list plus `test_dialogue_batches_5_6_7`,
  `test_backlog_batch4`, `test_workshop_presentation`, `test_buildings_tavern_town_hall`,
  `test_fixes`, `test_board`, `test_town_ui`, `test_ui`, `test_claude_batch`,
  `test_workshop_slice5_voices_and_bot`, `test_mechanics_claims`: all pass. `dotnet build` 0
  warnings; all scripts parse.
- **Golden** vs `baseline_82faa5b`, `--tol 0` (`--ignore engine,sus_why,sus_src`):
  identical in both modes, C#/GDScript parity identical, no script errors.
- **Pushed to `main`.** Next actor: **Argon** (the theory_fit question above; the Seer
  `mate != n` fix from your seed-2004 diagnosis when a baseline change is acceptable).

## 2026-11-03, Argon: Phase 4 Test Fixes + Rebased Chunk 1 Buildings (`patch_008_buildings_and_phase4_fixes.zip`)

- **Base:** `main` at `35b38614a00fec608b0f9e3da7aee4ba3ae596ac` (`35b3861`, post-PR #53 Legacy Purge Phase 4 + Analyst Bot).
- **Deliverable:** `patch_008_buildings_and_phase4_fixes.zip` in Google Drive (`Demonologist Patches`), containing all 40 replacement/new files plus `MANIFEST_BUILDINGS_AND_PHASE4_FIXES.md`. Supersedes `patch_007_buildings_tavern_town_hall.zip` (which was built on pre-Phase-4 `96fb5ea` and has been renamed `SUPERSEDED_patch_007_buildings_tavern_town_hall_96fb5ea.zip` on Drive so there are zero merge conflicts against Phase 4's deleted `sim/argue.gd`, `link`/`conclude`, and rewritten `tools/autoplay.gd`).
- **Status:** Ready for Claude verification (`dotnet build -c Debug`, the 3 previously red suites `test_dialogue_batches_5_6_7`, `test_backlog_batch4`, `test_workshop_presentation`, plus `test_buildings_tavern_town_hall` + `tools/ci_fast_suites.txt`, `--tol 0` golden check vs `tools/golden/baseline_82faa5b`, and Town Hall sprite placement in `ui/map_view.gd`).
- **Next actor:** **Claude**.

### 1. Fixes for All 5 Test Failures Flagged on `main` (`35b3861`)

1. **`tools/test_dialogue_batches_5_6_7.gd:412-423` ("Accepted hint follow-up voices `hint_why_lead` and `hint_why_confidential` without `[PH]`"):**
   - Uses a clean fixture game (`_game(5702, 10)`), resets `h_speaker.ledger = {}`, records `Mind.hear_claim(..., "seer", ..., "own")`, appends the Night 0 Seer reading, and calls `Mind.update_from_own_info(g_hint.w)` (matching `tools/test_fixes.gd:_setup_private_reading`) so `reason_status` resolves `"private"` through the shared model instead of colliding with the speaker's previously dealt role claim or unapplied `info_log`.
2. **`tools/test_backlog_batch4.gd:206` ("the repeated gift refusal has a different line"):**
   - Checks `first != second` on rendered output alongside `Speech.said(...)` on the emitted `speech` event in `a.last_events` (`"You've had my answer"` or `"puts a target on my back"`), keeping gameplay checks decoupled from character voice pack phrasing per `tools/speech.gd`.
3. **`tools/test_backlog_batch4.gd:682` ("arrival narration adds no phase advance or RNG draws"):**
   - Added `roll_attitude: bool = true` to `Mind.greeting_line` / `MindDialogue.greeting_line` and passed `false` on `"divulge"` `accept` in `game/game_conversation.gd:103` (where the NPC already approached and spoke their divulge lines). Preserves the VN stage greeting speech event while consuming **0 RNG draws** and **0 phase advances**; ordinary `talk` visits still perform the exact single `greeting_attitude_visible` roll.
4. **`tools/test_workshop_presentation.gd:69-70` (`_trapped_group_response`, 2 checks):**
   - In `game/workshop_presentation.gd`, preserved the full `text` (`trapped_voiced` + `" About <name>: <note>"` + optional `hub_voiced_tail`) in both `spoken_line["text"]` and `descriptor["special"]` when `trapped_out` is active, while keeping `trapped_canonical` + tails on `spoken_line["statement"]`. All non-`trapped_out` presentation descriptors (`Speech.said(line) == dialogue.special`) remain untouched.

### 2. Diagnosis of Seed 2004 Shared-Model Warning (`Incomplete or invalid reading payload`)

- Traced `fact:9a9474...` on Seed 2004 (7 NPCs, Day 3): in `sim/evil.gd:685-687`, when one evil member has been executed so the survivor is alone (`Evil.mate(w, n) == null`), `evil.gd` sets `mate = n`. On an even night (`w.day == 2`, read on Day 3), `sim/roles/seer.gd:196-197` (`elif mate.alive and w.chance(...)`) fabricates `pair = [mate.id, w.pick(others_m)]` = `[n.id, other]`, putting the Seer bluffer inside their own `data.pair`, which `workshop/live_assessment.gd:822` (`receipt.source in data.pair`) rightly rejects as impossible for a real Seer. (Also noted a dormant copy-paste in benched `sim/roles/hearthwitch.gd:66,73` `fake_medium_reading` writing `"group"` instead of `"nbrs"`.)
- Left `sim/roles/seer.gd` untouched in this patch so `baseline_82faa5b` stays bit-exact at `--tol 0` for immediate merge; adding `mate != n` on `sim/roles/seer.gd:196` (and `x != n.id` on `asked` at line 184) will eliminate that invalid payload class whenever we next recapture goldens or verify none of the 5 golden seeds hit solo-evil Seer bluff on an even night.

### 3. Rebased Roster & Mechanics Chunk 1 - Tavern Gossip Rework & Town Hall

- Cleanly rebased all 36 code/test files from `patch_007` onto `35b3861` (`Deduction.filing_problem`, `PresentationReply`, `Mind.card_implicates` / `card_clears` / `card_weight_against`, deleted-card check in `game_conversation.gd`, and Analyst-powered `tools/autoplay.gd` + `WorkshopCanvas.view` excluding `tavern_gossip` / `workshop_usable == false` cards so the Analyst juror never ingests unattributed rumours):
  1. **Evening-Only Tavern Gossip (`sim/tuning.gd`, `sim/world.gd`, `sim/social.gd`, `sim/mind.gd`, `sim/mind_dialogue.gd`, `sim/deduction.gd`, `game/game_day_night.gd`, `game/game_board.gd`, `game/game_conversation.gd`, `game/game_presentation.gd`, `game/card_model.gd`, `ui/board_view.gd`, `ui/main.gd`, `ui/case_view.gd`, `ui/workshop_drawer.gd`, `ui/live_case_workshop.gd`, `tools/autoplay.gd`):** Evening-only phase action, resolves evening `_post_pair` once via `World.finish_evening_conversations`, harvests 3-5 two-tier anonymized items from `w.daily_npc_shares` + unlearned haunt/public-bond backfill (never Secret Lovers), marks board cards `source = "rumour"`, `tavern_gossip = true`, `workshop_usable = false`, `pressable = false` with `"rumour|"` `fact_id` isolation and `"dotted"` timeline markers (`?` in CLI `timeline`).
  2. **Town Hall & Lockstep GDScript/C# Solver (`sim/content.gd`, `sim/world.gd`, `game/game.gd`, `game/game_day_night.gd`, `game/card_model.gd`, `game/workshop_canvas.gd`, `ui/map_view.gd`, `ui/main.gd`, `ui/workshop_canvas_view.gd`, `workshop/live_evidence.gd`, `workshop/live_assessment.gd`, `workshop/canvas_model.gd`, `workshop/session.gd`, `workshop/case_graph.gd`, `workshop/solver.gd`, `workshop/case_eval.gd`, `workshop/factored_channels.gd`, `workshop/role_constraints.gd`, `workshop/cs/RoleConstraints.cs`, `tools/test_buildings_tavern_town_hall.gd`, `tools/ci_fast_suites.txt`):** `C.PLAYER_BUILDINGS["town_hall"]` on `the Square` (blank square placeholder in `ui/map_view.gd`, `C.LOCATIONS` untouched), Morning/Afternoon only, 3 uses/case, 6 unique roles (`[in_play, out_of_play]` from `initial_good_roles`), lockstep `.gd`/`.cs` `KindTownHall = 6` solver + `FactoredChannels` role-pool merging + Workshop `in_play_role` chips.

## 2026-11-03 ~23:30 ET, Claude: legacy purge Phase 4 (purge + analyst bot)

- **Branch:** `claude/phase4-purge-bot`, merged with `main` at `96fb5ea` (Argon's dialogue
  batches 5–7 and the trace art). Plan: `docs/legacy_retirement_plan.md` Phase 4.
- **What's gone:** `sim/argue.gd`, the link templates and their matcher, `link` /
  `conclude` / `deduce`, `find_links` / `link_cards`, the template parts of
  `file_deduction` (cases are filed only through the Workshop now), every role
  `card_strength` / `defend_strength` / `reading_strength` hook, `night_sighting_scale`,
  46 legacy tuning keys, `sus_why` / `sus_src`, and the legacy-only tests (`test_argue`,
  template parts of `test_roster`, `test_fixes`, `test_playtest_regressions` and others).
- **What replaced it:**
  - `sim/presentation_reply.gd`: repeat counting and the evil mask with the shadow self,
    moved unchanged. **Argon:** your patch_006 change to `Argue.evaluate`'s shadow-self
    block (same-stance reuse, `render_evil_override` lines) is ported here; `argue.gd` is
    deleted, so edit `presentation_reply.gd` from now on.
  - A good listener the Workshop can't serve answers socially (protect/spare or bare
    belief, from trust and lean), feeding only social preferences. There's no template
    fallback any more.
  - `Mind.card_implicates` / `card_clears` (card structure) decide presentation direction
    and self-support; `Mind.card_weight_against` (the shared model's own reason weight,
    or `Tuning.Dialogue.UNMODELLED_CARD_WEIGHT`) sets press strength.
  - The merge conflict in `Mind.hear_defence` resolves to Argon's voiced lines with the
    structural `card_clears` test.
- **Visible changes:** "has a secret" and "red herring" conclusions can no longer be
  presented (blocked with a reason: the town can't weigh them). Press outcomes move a
  little.
- **Analyst bot** (`tools/analyst.gd`, used by `tools/autoplay.gd`): a neutral juror reads
  the player's board through the shared model (CaseEval) and gives everyone a posterior;
  ranking, nominating, voting and case building use it. Cases are built greedily (each
  card must raise the juror's ratio by 3%, at most 8 cards, presented at ratio 1.45 or
  more, hub at 1.55 or more), conclusion "evil" only. `--insight 0.6` makes it miss 40%
  of cards. `--backend csharp` for sweeps.
- **Checks:** all scripts parse. Before the merge: the CI fast list plus every touched
  suite were green (after two test fixes: legacy template checks removed from
  `test_roster`; the analyst passes the hub picker a signed lean instead of a 0–1
  probability). Golden vs `baseline_82faa5b`: identical in both modes with
  `--ignore engine,sus_why,sus_src`, and C#/GDScript parity identical. After the merge:
  see Result.

### Bot baselines (seeds 2000–2011, C# backend, 2 runs at a time on 2 cores)

| Setup | NPCs | Good wins | Wrongful exec / game | Evil exec / game | Demon identified | s / game |
|---|---|---|---|---|---|---|
| Passive | 7 | 4/12 (33%) | 1.08 | 0.67 | – | 6 |
| Old bot (`9df96cc`) | 7 | 3/12 (25%) | 1.25 | 0.58 | 6 | 16 |
| Analyst, insight 0.6 | 7 | 5/12 (42%) | 1.00 | 0.67 | 5 | 23 |
| Analyst | 7 | 7/12 (58%) | 0.75 | 0.92 | 10 | 53 |
| Passive | 10 | 2/12 (17%) | 2.00 | 1.08 | – | 77 |
| Old bot (`9df96cc`) | 10 | 5/12 (42%) | 1.58 | 1.50 | 9 | 128 |
| Analyst, insight 0.6 | 10 | 3/12 (25%) | 1.50 | 1.58 | 8 | 162 |
| Analyst | 10 | 6/12 (50%) | 1.50 | 1.33 | 8 | 247 |

- 12 seeds is noisy (one game is 8 points). The analyst clearly beats the old bot at 7
  NPCs; at 10 it's only slightly ahead, and its wrongful executions stay high (1.5 a game),
  so the town's votes, not the bot's reading, look like the limit there.
- The old bot did worse than passive at 7 NPCs.
- Juror cost: about 200 evaluations a game at 7 NPCs (41 s) and 240 at 10 (137 s), so most
  of the analyst's time is the juror. A smaller `MAX_CANDIDATES` or caching single-card
  ratios across a day are the obvious speedups if sweeps get too slow.
- **For Argon (shared model):** seed 2004 at 7 NPCs, Day 3: 12 "kept last good vector"
  events, all `Incomplete or invalid reading payload` for one fact
  (`fact:9a9474…`), at `ownership_before` / `preflight_union` / `preflight_assessment`.
  The old bot also triggers this class (45 events across 3 seeds at 10 NPCs), so it
  predates Phase 4, but it's a card the shared model can't read.

### Result

- **`main` is already red.** PR #52 (patch_006, dialogue batches 5–7) was merged with
  three suites failing: `test_dialogue_batches_5_6_7` (8 failures plus script errors),
  `test_backlog_batch4` (2), `test_workshop_presentation` (2). I ran them on `96fb5ea`
  itself and got exactly the same failures as on this branch, so Phase 4 adds none.
- **Fixed on this branch:**
  - `dialogue_presentations._pick_rival_pair`: on a "now" claim a dead starting Demon was
    still picked as the accomplice. The pool now holds the living only.
  - `test_dialogue_batches_5_6_7`: the test hand-built `workshop_case` dictionaries in a
    shape the game never files (a `root` key, board numbers instead of card ids), which
    caused all the script errors. It now files real cases through `WorkshopCanvas.file`.
    The self-support checks passed cards that don't concern the listener (a 0.1 or 0.15
    old strength, under the 0.2 bar, so they'd fail on the old system too); each listener
    now gets their own claim.
- **Still failing (Argon, patch_006; 2-attempt cap reached on the first):**
  1. `test_dialogue_batches_5_6_7` "Accepted hint follow-up…": the test writes a Seer
     reading straight into `speaker.info_log`. The shared model never sees it, so
     `reason_status` is "none" even after `Mind.refresh_beliefs` and the speaker declines.
     The reading needs to go in the way a real one does (or the test needs a mind
     whose reading came from a real night).
  2. `test_backlog_batch4:206` "the repeated gift refusal has a different line" and
     `:682` "arrival narration adds no phase advance or RNG draws". Voiced lines likely
     replaced the expected English text; the second may be a real RNG draw added to
     arrival narration (the golden didn't move, but it doesn't cover arrivals).
  3. `test_workshop_presentation:69–70`: the group-response text no longer starts with
     the expected admission / isn't shown in full.
- Golden: identical to `baseline_82faa5b` in both modes after the merge
  (`--ignore engine,sus_why,sus_src`), C#/GDScript parity identical, no script errors.
- **Not pushed to `main`** (rule: `main` moves only when green). Opened a PR from
  `claude/phase4-purge-bot` instead. It makes `main` strictly better (fixes 3 checks, adds
  no failures), so Michael may merge it as is; otherwise it waits for Argon's fixes
  to the five checks above. **Next actor: Argon** (patch_006 failures), or Michael (merge).
- **Update 22:15 ET:** Michael said to merge as is; merged to `main` as PR #53 (`3ea25b5`).
  **Next actor: Argon** (the five patch_006 checks above).

## 2026-11-03, Argon: Combined Dialogue Batches 5, 6 & 7 delivered (`patch_006_dialogue_batches_5_6_7.zip`)

- **Base:** `main` at `9df96cc7f7f64f567cf99c5fd060cc44bfc4799a` (`9df96cc`).
- **Deliverable:** `patch_006_dialogue_batches_5_6_7.zip` in Google Drive (`Demonologist Patches`), containing full replacement/new files plus `MANIFEST_DIALOGUE_BATCHES_5_6_7.md` (supersedes `patch_006_dialogue_batches_5_6.zip`).
- **Status:** Ready for Claude verification (`dotnet build -c Debug`, `test_dialogue_batches_5_6_7` + targeted dialogue/UI/Workshop/role suites + `ci_fast_suites.txt`, and `--tol 0` golden capture check vs `tools/golden/baseline_82faa5b`).
- **Next actor:** **Claude**.

### What's in `patch_006_dialogue_batches_5_6_7.zip`

1. **Full 230-Key Symmetric Cast Voice Pack (`sim/dialogue_voices.gd` - 143 -> 230 keys per character, zero `[PH]` codebase-wide):**
   - **Batch 5 (+31 keys):** Workshop case-presentation reactions, BotC 2-suspect rival framing, movement/trace/role-fit tails, repeats, and self-support replies.
   - **Batch 6 (+8 keys):** `greet_neutral` (x3), `greet_cold` (x2), `greet_warm` (x2), and 5 contextual overrides (`greet_friend_killed`, `greet_after_murder`, `greet_after_execution`, `greet_after_friction`, `greet_after_protection`).
   - **Batch 7 (+46 new keys + 2 completed cast hooks):** Populates the remaining 14 characters on `private_reveal_early` and `doubted_visual` (so all 15 characters share an identical 230-key schema) and adds bespoke character voices for all 25 remaining `[PH]` sites across conversations, `press` edge cases, 1st/2nd-press night-walking duty reconfirmations (`warden`, `nightwatch`, `lamplighter`, `medium`), all 5 `HINT_PACKAGES`, fear-withheld readings, protection-promise trust, `_repeat_refusal` pushbacks, role queries (`answer_about_role` / `answer_is_role`), Seer Red Herring defence, Warden door/save reports, and town-meeting anonymous relays and block pleas.
   - Zero `[PH]` tags remain anywhere across `sim/`, `game/`, `workshop/`, or `ui/`; `"data"` remains exclusive to Nisha; `greet_neutral` avoids burning `Dialogue.TICS` caps; zero `"when it's safer"` or `"stand by it"` boilerplate on Batch 7 lines.
2. **Batch 5 - Voiced Case-Presentation Composer & Good/Evil Parity (`sim/dialogue_presentations.gd`, `game/workshop_presentation.gd`, `sim/argue.gd`, `sim/mind.gd`, `sim/evil.gd`):**
   - Keeps `workshop/` (`jury.gd`, `reasoner.gd`, C# solver kernels) and `WorkshopPresentation._belief_stance_text` 100% untouched; canonical diagnostic strings remain on `spoken_line["statement"]` and `descriptor["special"]`.
   - Uses BotC-style top-Demon + `#2` highest-suspicion `{accomplice}` rival framing (never naming a 3rd evil, promoting a living evil successor if the starting Demon died on `"now"` claims, and appending `present_alt_marked` only when Marked explains an attended ping/conclusion) and unifies Good and Evil presentation phrasing.
   - **Merge note for Claude's Purge Phase 4 (`sim/argue.gd` retirement):** All presentation and Evil-override voicing lives in `sim/dialogue_presentations.gd` (with zero dependency on `sim/argue.gd`). When Phase 4 deletes `sim/argue.gd`, retain `Presentations.render_evil_override(...)` in the unified presentation path and reuse `sr.dialogue.voiced_text` when Evil adopts its shadow's assessment.
3. **Batch 6 - VN Conversation Intro & Greeting System (`sim/mind_dialogue.gd`, `sim/mind.gd`, `game/game_conversation.gd`, `game/game_day_night.gd`, `game/game.gd`, `ui/day_conversation_view.gd`):**
   - `Mind.greeting_line(w, n, context)` consumes the exact same single `greeting_attitude_visible` Composure RNG draw as `Mind.greeting_cue`, emits spoken `speech` events with 5-state VN portrait expressions (`neutral`, `warm`, `harsh`, `concerned`, `sorrowful`) on `talk` entry and `divulge` `accept`, removes `"Choose a question to begin."`, and preserves zero-cost `bye`.
4. **Batch 7 - Final `[PH]` Sweep (`sim/mind_dialogue.gd`, `sim/social.gd`, `sim/mind_meeting.gd`, `sim/role_def.gd`, `sim/roles/seer.gd`, `sim/roles/warden.gd`, `sim/roles/nightwatch.gd`, `sim/roles/lamplighter.gd`, `sim/roles/medium.gd`, `game/game_conversation.gd`):**
   - Preserves `C.role_def(f_role).pressed_night_line(...)` as the canonical `statement` (keeping `test_role_def_poc` green) while adding `pressed_night_slots(...)` to feed `pressed_<role>_night` / `pressed_<role>_night_alt`.
   - Normalizes relayed `known_claims` readings in `Social.answer_about_role` via `C.third_person(e["text"])` while retaining canonical `statement` on all voiced lines.
5. **New Unified Suite:** `tools/test_dialogue_batches_5_6_7.gd` (`uid://c5w7mp3qn8kvr`).

---

## 2026-11-03 ~18:30 ET, Claude: `game.gd` separation checked, green, no fixes, on main

- **Base:** `b061bb3` as declared; unpacked on `refactor/game-gd-separation`, no changes
  needed. `game.gd` 2,886 to 1,020 lines; four new helpers (conversation, meeting,
  day/night, screens). This is also meeting-plan slice **M0**.
- **Static checks:** every function, `var` and `const` that was on `Game` still is. All
  91 moved function bodies are identical to the originals once `self.`/implicit member
  access is rewritten as `g.` (mechanical comparison), and all 91 forwarders call the
  same-named helper with `self` plus the same arguments (3 that never touched instance
  state correctly omit `self`). `dotnet build` 0 errors; all 268 scripts parse.
- **Suites** (.NET Godot, targeted per Michael): `test_npc_interactions`,
  `test_dialogue_decisions`, `test_social`, `test_playtest_followups`,
  `test_mechanics_defences`, `test_outcomes`, `test_backlog_batch3`,
  `test_mechanics_sightings`, `test_mechanics_curse`, `test_town_ui`, `test_text_ui`,
  `test_ui`, `test_fixes`, `test_role_def_poc`, `test_workshop_slice5_voices_and_bot`:
  15/15 pass.
- **Golden** `--mode gdscript` vs `baseline_82faa5b`, `--tol 0`: identical on all five
  seeds, 0 script errors. Not re-run in csharp mode (no `workshop/` changes; CI's parity
  job covers it on the push).
- **Active play, which the golden doesn't exercise:** 3 active bot games (seeds
  1000-1002, 7 NPCs) at `b061bb3` and at this branch. Transcripts identical line for line
  and dev logs byte-identical.
- **Pushed to `main`.** Next actor: Claude (bot rewrite + final legacy purge, Phase 4).

---

## 2026-11-03, Argon: `game/game.gd` 4-slice separation delivered (`patch_005_game_separation.zip`)

- **Base:** `main` at `b061bb3f7e3054b4f922cdb08189070dd322fe3e` (`b061bb3`).
- **Deliverable:** `patch_005_game_separation.zip` in Google Drive (`Demonologist Patches`), with
  full replacement/new files plus `MANIFEST_SLICE_GAME_SEPARATION.md`.
- **Status:** Ready for Claude verification (`dotnet build -c Debug`, domain suites + `ci_fast_suites.txt`,
  and 5-seed `--tol 0` golden capture in both `gdscript` and `csharp` modes vs
  `tools/golden/baseline_82faa5b`).
- **Next actor:** **Claude**.

### What's in `patch_005_game_separation.zip`

1. **All 4 `game/game.gd` static domain helper extractions (100% simulation-neutral):**
   - `game/game_conversation.gd` (856 LOC, `uid://c4m8kq2vx7pbn`): `# --- approaches` and
     `# --- conversation` (`_maybe_approach`, `_promised_to`, `_maybe_divulge`, `_approach_command`,
     `_protect_approach_answer`, `_grant_protection`, `_phase_header`, `_remember_dialogue_exchange`,
     `_talk_options`, `_repeat_refusal`, `_talk_command`, `_record_trace_profile_haunts`,
     `_answer_request`, `_answer_request_now`, `_gift_request`, `_grievance_menu`, `grievance_text`,
     `_offer_command`, `offer_text`, `_settle_offers`, `OBSERVABLE_TRAITS`, `TRAIT_WORDS`,
     `MAX_BONDS_TOLD`, `_maybe_tell_haunts`, `_record_trait_receipt`, `sync_bereaved_traits`,
     `_maybe_tell_trait`, `_maybe_tell_relationships`, `_remember_spoken_relationship`,
     `known_relationship_notes`, `known_haunt_names`, `_close_conversation`).
   - `game/game_meeting.gd` (321 LOC, `uid://c7n3rw5tb2kdm`, **Meeting Overhaul Slice M0**):
     `# --- meeting` (`_start_meeting`, `meeting_streaming`, `testimony_step`, `_testimony_turn`,
     `_meeting_opened`, `_meeting_command`, `_next_npc_nomination`, `_defend_pending`,
     `vote_requirement_text`, `_show_nomination`, `_nomination_command` coroutine with `await`,
     `_after_vote`, `_last_words`, `_close_meeting` passing bound `g._last_words` to
     `g.w.end_meeting`).
   - `game/game_day_night.gd` (495 LOC, `uid://b8p6vy3qf4hlk`): `# --- day` and `# --- night`
     (`unseen_at`, `unseen_at_ui`, `can_see`, `can_see_ui`, `_present`, `_resolve_go`,
     `_best_location_on`, `_day_command`, `_warn_busy_visit`, `_who_here`, `_observe`, `_search`,
     `_end_phase`, `_night_homes`, `_night_command`, `_resolve_night`, `_fallbacks_text`,
     `_morning_report`).
   - `game/game_screens.gd` (614 LOC, `uid://c2t5wx8jm3rqp`): `# --- info screens` and
     player theory/prediction/debug/profile helpers (`_intro`, `_help`, `_look`, `_card_workers`,
     `_card_conversations`, `_map`, `_cast`, `_profile`, `_script`, `_tools`, `_board`, `_ending`,
     `_grimoire`, `_exchanges`, `_lies`, `_write_logs`, `set_note`, `set_guess`,
     `set_secret_guess`, `capture_prediction`, `theory_status`, `_outcome_text`,
     `set_debug_overlay`, `_spread`, `debug_card_text`, `debug_npc_text`, `named_in`,
     `_death_text`, `_claim_text`, `profile_data`).
2. **Refactored `game/game.gd` (2,886 LOC -> 1,020 LOC):**
   - Retains all 72 session variables, all 25 existing constants/preloads (preserving `g.Argue`,
     `g.Mind`, `Game.OBSERVABLE_TRAITS`, `g.OBSERVABLE_TRAITS`, and static `Game.grievance_text`),
     adds `GameConversation`, `GameMeeting`, `GameDayNight`, and `GameScreens` preloads, and
     delegates all extracted functions via 1-line forwarders (including
     `await GameMeeting._nomination_command(self, verb, rest, progress)`).

---

## 2026-11-03 ~17:00 ET, Claude: slice C3 checked, green after 2 small fixes, on main

- **Base:** `4077dce` as declared; unpacked on `csharp/slice-c3`, main merged in (meeting
  plan + CI parity change, `9c4affd`), no conflicts.
- **Build:** `dotnet build -c Debug`: 0 warnings, 0 errors. All 264 scripts parse. The C2
  gotchas held: no `Packed*Array` consts, C2's `.get("source")` fixes kept, `GdFloor1e30` shared.
- **Fixes needed (2), both in the C3 test's fixture paths, not the live game:**
  1. **`Solver._movement_cs` night keys.** The GDScript twin keys `nights` by `str(night)`;
     the C# wrapper used `str(int(night))`. The checkpoint v5 fixtures are JSON, so their
     nights are floats and the keys came out `"1.0"` vs `"1"` (counts and forced-out
     lists were identical). In-game nights are ints, so the golden never saw it. The
     wrapper now keeps the cards' own key. **General rule for C4+:** where a GDScript
     result is keyed or formatted from a value, format the original value, not a converted one.
  2. **Warden report without `block`.** `live_activity._paths` read `card.block` on Warden
     self-reports; the fixture's `r_ward` has none, so GDScript crashed while C# treated it
     as "no match" (`wBlk >= 0` fails). Now `card.get("block", "")`, same result as C#.
- **Suites** (.NET Godot, Linux): all 24 from the manifest plus `ci_fast_suites.txt` pass,
  including `test_csharp_slice_c0`..`c3`, `test_case_eval`, `test_channel_sum_product`,
  `test_workshop_factored_channels`/`_classes`, `test_prior_mapping`.
- **Golden, `--tol 0`, 0 script errors:** `--mode gdscript` and `--mode csharp` both identical to
  `baseline_82faa5b` on all five seeds, and csharp identical to gdscript (the new CI parity
  check); csharp re-run after fix 1, still identical. Side by side: GDScript 823 s, C# 242 s
  (**3.4x**; C2 was 1.8x).
- **VERIFY:** profile_c0 seed 42, 21,750 boundary calls, 0 mismatches.

### Profile, seed 42 (7 NPCs, to Day 4), self time

| Stage | GDSCRIPT ms | CSHARP ms | C2 CSHARP ms |
|---|---:|---:|---:|
| outer_prep | 990 | 1001 | 1477 |
| pack_inputs | 0 | 396 | 725 |
| world_domain | 6684 | 923 | 703 |
| live_activity | 3138 | 358 | 391 |
| case_eval_compile | 344 | 103 | 570 |
| channel_sum_product | 264 | 161 | 256 |
| reason_attribution | 251 | 253 | 243 |
| **total self** | **11672** | **3195** | **4365** |
| **wall** | **12109** | **3662** | **4937** |

`world_domain` now includes the `Solver.*` work you re-attributed, so its C# rise from 703
to 923 ms is a relabel, not a regression (GDScript's rose the same way, 5825 to 6684).

### Notes for Argon

1. **C# is 3.3x faster end to end on seed 42** (wall 12.1 s to 3.7 s).
2. **C4 (`reason_attribution`):** 253 ms self in C# over 26 calls (9.7 ms each), above the
   150 ms threshold you set, and unchanged since C1. Its inclusive time is 653 ms. By that
   test C4 is worth doing, but the bigger targets are `outer_prep` (1.0 s, 31% of C# self,
   still pure GDScript) and `pack_inputs` (396 ms over 15,792 calls). `LiveActivity.routes`
   is still the top packer (126 ms, 613 calls at 206 us) despite the env memo, so card
   packing is now the cost there; `fits_weights` is next (113 ms, 754 calls).
3. **CI change you should know about (`9c4affd`):** a new required `parity` job diffs the
   csharp capture against the gdscript capture of the same commit. The diff against
   `baseline_82faa5b` is now a warning, because meeting-overhaul slices will change behaviour
   on purpose and re-record the baseline. For your slices nothing changes in practice:
   both must still be identical. See `docs/golden_baseline.md`.
4. **Kernel changes are now two-sided:** until the GDScript solver is retired, any change
   to a ported file (including new roles touching possible worlds, bluffs or movement)
   needs both implementations. Worth planning when the GDScript copies can be deleted.

### Result

- **Pushed to `main`.** Next actor: **Argon** (C4 or the `outer_prep`/packing work; your call).

---

## 2026-11-03, Argon: slice C3 + C2 profile follow-ups delivered (`patch_004_slice_c3.zip`)

- **Base:** `main` at `4077dcedb0aef0a4a8a2463a739214a8aa389eba` (`4077dce`).
- **Deliverable:** `patch_004_slice_c3.zip` in Google Drive (`Demonologist Patches`), with
  full replacement/new files plus `MANIFEST_SLICE_C3.md`.
- **Status:** Ready for Claude verification (`dotnet build -c Debug`, `ci_fast_suites.txt`
  including `test_csharp_slice_c3`, `test_case_eval`, `test_channel_sum_product`,
  `test_workshop_factored_channels`, `test_workshop_factored_classes`, `test_prior_mapping`,
  Seed 42 Day 4 `tools/profile_c0.gd` run, and `--tol 0` golden capture vs
  `tools/golden/baseline_82faa5b`).
- **Next actor:** **Claude**.

### What's in `patch_004_slice_c3.zip`

1. **Slice C3 C# kernels (`workshop/cs/`):**
   - `workshop/cs/SolverKernel.cs` (+ `.uid`, `uid://do19o1k4et4jx`) & `workshop/solver.gd`:
     1:1 bit-exact C# port of `world_bits`, `sig_groups` (cached per universe handle on
     `SolverContext`), `valid_table`, `report_table` (all `CONTENT_ROLES`, `positive` /
     `blocks` / `marked` answers, `testimony_only` shapes `ROLE_IN_GROUP` / `PING` /
     `SECRET_PAIR`, and `curse` events across live and fixture universes), `_solve`
     candidate & position filtering, fixture `_movement` bitmask enumeration,
     `question_table` (`misled` & `unreliable`), and `premise_mask`.
   - `workshop/cs/CaseEvalKernel.cs` (+ `.uid`, `uid://dnwp18om6galx`) & `workshop/case_eval.gd`:
     1:1 bit-exact (`--tol 0`) C# port of `_index`, `compile` (ternary card-state codes,
     64-bit `long` vs tuple class keys, `group` / `group_bits`, `test_hold`, and fused C#
     class movement scoring directly via registered `LiveActivity` factor handles),
     `_own_counts` (preserving `tools/test_case_eval.gd`'s synthetic `_own_cache` override),
     `_team_prior` (passing dynamic `CaseEval.prior_k`, preserving `prior_k = -1.0` probe
     mode), `_class_like`, and the full `evaluate` posterior marginalization pass (`own_like`
     in reverse `ko-1..0` order, `test_like`, `theory_bias`, `_class_share`, `_people`,
     `_joint`, `_pivotal`, and `_expand`).
   - `workshop/cs/ChannelSumProduct.cs` (+ `.uid`, `uid://dwr8kf4qmbl8z`),
     `workshop/channel_sum_product.gd`, & `workshop/factored_channels.gd`:
     1:1 bit-exact (`--tol 0`) C# port of `ChannelSumProduct.compile` (preserving insertion-
     order variable tie-breaking), `evaluate` (forward + zero-safe reverse adjoints),
     `circuit` (constant-folded register DAG registered in `SolverContext`), `run`, and
     batched `FactoredChannels.assess` (`FactoredAssessBatch`, pre-populating missing coarse
     signatures once and running all worlds/representatives + signature memoization +
     marginals in a single C# call).
   - `workshop/cs/SolverContext.cs`, `workshop/cs/SolverBridge.cs`, & `workshop/caches.gd`:
     Added `UniverseMeta` per-handle caches plus `CompiledCaseEntry`, `CompiledProgram`, and
     `CompiledCircuit` arenas, all cleared atomically in `WorkshopCaches.clear_all()`.
2. **Follow-ups on Claude's C2 profile notes (`pack_inputs` 725 ms & `outer_prep` 1,477 ms):**
   - **Handle propagation on subset & solver role checks:** Fixed
     `RoleConstraints._fits_weights_dispatch` so non-empty `sub_indices` (`personal` open
     subsets in `CaseEval._class_fits` and `ReasonAttribution._subset_fits`) map
     `miss_sub.append(sub_indices[i])` against `u_handle` instead of repacking `miss_worlds`;
     passed `u_handle` (+ surviving `PackedInt32Array` indices) in `Solver._solve`,
     `Solver.question_table`, and `ReadingChallenges._fraction`.
   - **`LiveActivity._pack_view_env` memoization:** Cached `_pack_view_env` on `LiveActivity`
     (cleared in `WorkshopCaches.clear_all()`) so the 613 `routes` calls per Seed 42 game
     reuse the packed homes/deaths/timeline arrays instead of rebuilding them per call.
   - **`outer_prep` reductions:** Added O(1) indexed `Solver.card_by_id` lookup (safe under
     in-place `view.cards.append(...)` and mutations), attributed `Solver.*` work to
     `world_domain`, and made `Jury`'s recursive `JSON.stringify(_canonical(...))`
     `common_key` lazy so it only runs when `confidence_mode == "persistence"` (or legacy
     engine), skipping unused stringification on live refreshes.
   - **C2 gotchas enforced:** Zero `Packed*Array()` in GDScript `const`, safe `.get(...)` on
     card fields, shared `SolverContext.GdFloor1e30` (`0x39B4484BFEEBC29FL`), and a float
     literal `var_to_bytes()` + `VerifyFloat64Buffer` audit at the start of
     `tools/test_csharp_slice_c3.gd` (`uid://dsjyh3rxwvsyc`, registered in
     `tools/ci_fast_suites.txt`).

---

## 2026-11-03 ~15:00 ET, Claude: slice C2 checked, green after fixes, on main

- **Base:** `0498fce` as declared; unpacked on `csharp/slice-c2`, main merged in (CI
  test_trace park), no conflicts.
- **Build:** `dotnet build -c Debug`: 0 errors.
- **Fixes needed (4):**
  1. **Parse errors in 8 scripts.** `const _EMPTY_INT32 := PackedInt32Array()` and
     `_EMPTY_INT64` in `role_constraints.gd` and `live_activity.gd` are not constant
     expressions in Godot 4.7, so both scripts (and everything preloading them) failed to
     compile. Replaced with inline `PackedInt32Array()` / `PackedInt64Array()`.
  2. **Crash on cards without `source`.** `role_of`, `role_hearing` and the two
     `hearing_weight` lambdas in `live_activity.gd` read `card.source` directly; `context`
     cards have none. Now `card.get("source", "")`. No behaviour change for cards that
     have a source (the golden never hit the crash), but the C2 test's fixtures did.
  3. **1-ULP VERIFY mismatches in `LiveActivity.scores`** (values around 1e-29, seen in
     test_csharp_slice_c1/c2 and profile_c0). Cause: **Godot parses the literal `1e-30`
     one ULP low** (`0x39B4484BFEEBC29F`; IEEE nearest, which C# uses, is `...C2A0`). The
     floor in `_base_score` therefore differed. `LiveActivity.cs` now uses Godot's bits
     (`GdFloor1e30`). I checked the other exponent literals in the C# ports: `1e-12`,
     `1e-20` (and `1e-9`, `1e-6`) parse identically in both. **For C3:** check every
     float literal you port against GDScript's bits, not the decimal text.
  4. **test_csharp_slice_c2 fixtures:** it read `Ownership.reasons_for(...)`'s return
     value (it returns nothing; it fills `workshop_state.reasons`) and its passive player
     used `g.actions_left`, which doesn't exist. It now reads the state and uses
     `golden_capture.gd`'s passive player.
- **Suites** (.NET Godot, Linux): `test_csharp_slice_c0`, `c1`, `c2`,
  `test_workshop_live_activity`, `test_lamplighter_drops`, `test_workshop_profile_traces`,
  `test_mechanics_sightings`, `test_workshop_integration`, `test_workshop_reading_challenges`,
  plus (before fix 3) mechanics_warden/curse, workshop_ownership/efficiency, headline,
  claude_audit_cleanup: all pass. VERIFY 0 mismatches on the passive seeds 42 and 54875
  (2.1M boundary checks on 54875).
- **Golden vs `baseline_82faa5b`, `--tol 0`:** identical on all five seeds in both
  `--mode gdscript` and `--mode csharp`, 0 script errors (re-run after the fixes).
  Before the fixes, side by side: GDScript 776 s, C# 433 s (about 1.8x).

### Profile, seed 42 (7 NPCs, to Day 4), self time

| Stage | GDSCRIPT ms | CSHARP ms | C1 CSHARP ms |
|---|---:|---:|---:|
| outer_prep | 1434 | 1477 | 1654 |
| pack_inputs | 0 | 725 | 1932 |
| world_domain | 5825 | 703 | 892 |
| live_activity | 3309 | 391 | 3329 |
| case_eval_compile | 560 | 570 | 1168 |
| channel_sum_product | 279 | 256 | (0 calls) |
| reason_attribution | 280 | 243 | 309 |
| **total self** | **11687** | **4365** | |
| **wall** | **12248** | **4937** | **9918** |

`case_eval_compile` halved because `CaseEval.evaluate` now records under
`channel_sum_product` (note 3), not because it got faster.

### Notes for Argon

1. **C# is now 2.5x faster end to end on seed 42** (wall 12.2 s to 4.9 s). `live_activity`
   dropped 8.5x and `pack_inputs` 2.7x.
2. **`pack_inputs` is still 725 ms over 19,036 calls (38 us each).** The heaviest packers
   by boundary table: `fits_weights` (232 ms, 754 calls), `coarse_masks` (196 ms, 819),
   `LiveActivity.routes` (130 ms, 613 calls at 212 us). Routes repack the view env and cards
   per call; a per-refresh handle like the universe arena would remove most of it.
3. **`outer_prep` (1.5 s) is now the largest stage in C# mode**, about a third of self time,
   and unchanged by C1/C2. Worth a look alongside C3's `solver.gd` + `case_eval.gd` move.
4. **Literal bits** (fix 3 above): the cheapest guard is a C0-style audit that prints
   `var_to_bytes()` for each constant a slice ports and compares it with the C# value.

### Result

- **Pushed to `main`.** Next actor: **Argon** (slice C3).

---

## 2026-11-03, Argon: slice C2 + C1 packing handles delivered (`patch_003_slice_c2.zip`)

- **Base:** `main` at `0498fce6c5def9f70f15c0015ac8e8e1cb403ab2` (`0498fce`).
- **Deliverable:** `patch_003_slice_c2.zip` in Google Drive (`Demonologist Patches`), with
  full replacement/new files plus `MANIFEST_SLICE_C2.md`.
- **Status:** Ready for Claude verification (`dotnet build -c Debug`, `ci_fast_suites.txt`
  including `test_csharp_slice_c2`, Seed 42 Day 4 `tools/profile_c0.gd` run, and `--tol 0`
  golden capture vs `tools/golden/baseline_82faa5b`).
- **Next actor:** **Claude**.

### What's in `patch_003_slice_c2.zip`

1. **Follow-ups on all 5 notes from Claude's C1 report:**
   - **Note 1 (`pack_inputs` 1,932 ms bottleneck):** Added a handle-based packed universe
     arena in `SolverContext.cs` (`RegisterPackedUniverse`, `RegisterIndexedSubUniverse`,
     `ResolveWorlds`) and `SolverBackend` (`get_universe_handle`, `get_sub_universe_handle`),
     cleared atomically in `WorkshopCaches.clear_all()`. Wired `u_handle` / `cc_reps_handle`
     and `sub_idx` / `failed_cc_idx` through `CaseEval._coarse`, `CaseEval._fits_over`, and
     `RoleConstraints` (`coarse_masks`, `fits_weights`, `fits_table`, `bluff_weights`), so
     the 5,040- / 15,120-world universe and each equivalence-class `cc.rep` table pack once
     per key instead of repacking ~2,000 times per Seed 42 game.
   - **Note 2 (`VERIFY` skipping `coarse_masks`):** `RoleConstraints.fits_weights` in
     `VERIFY` mode previously delegated to `_fits_weights_gd`, whose coarse-mask cache hit
     skipped calling `RoleCoarseMasks`. `VERIFY` now explicitly invokes
     `RoleCoarseMasksByHandle` + `VerifyInt64Buffer("RoleConstraints.coarse_masks", ...)` on
     every `fits_weights` call alongside `VerifyFloat64Buffer("RoleConstraints.fits_weights")`.
   - **Note 3 (`channel_sum_product` showing 0 calls):** Live `CaseEval` evaluates posterior
     marginals over compiled equivalence classes in `CaseEval.evaluate`, whereas the
     treewidth sum-product circuit (`FactoredChannels` / `ChannelSumProduct`) only runs in
     circuit/probe suites. `CaseEval.evaluate` now records under `channel_sum_product` while
     `CaseEval.compile` stays under `case_eval_compile`, cleanly separating class compilation
     from per-listener posterior evaluation ahead of Slice C3.
   - **Note 4 (`live_activity` 2,904 ms):** Ported in full below as Slice C2.
   - **Note 5 (`profile_c0.gd` `refreshes=0`):** Promoted `_refreshes` from a value-captured
     local `int` inside the lambda to a `SceneTree` member variable (matching
     `golden_capture.gd`).
2. **Slice C2 (`LiveActivity.cs` + batched `LiveActivity.scores`):**
   - `workshop/cs/LiveActivity.cs` (+ `.uid`, `uid://dwxl3uolgi3pa`) & `workshop/live_activity.gd`:
     1:1 bit-exact C# port of `routes` / `_paths` (4-block pairwise bitmask `PathSpec`,
     Medium `relay_source` hearth checks, complete vigils, `guard_claim`, `coverage`,
     Night Watch / Warden / Medium / Lamplighter strict reports, Lamplighter walker counts +
     `positive` answers, and `dropped` / `item_drop` Hall matching), single & all-person
     batched `_likelihood` (`LiveAllProfiles`), single & scene-batched
     `crossing_probability` (`LiveSceneCrossings`), pre-registered compiled movement factor
     handles (`LiveRegisterMovementFactor`, cleared atomically in `WorkshopCaches.clear_all()`),
     and single + handle-batched world scoring (`LiveScoreWorld`, `LiveScoreWorldsByHandle`)
     covering Revenant `converted` profiles, 1-trace & 2-trace passer contractions, and Scion
     succession splits.
   - Wired `CaseEval._movement_scores` (`workshop/case_eval.gd`) to score all equivalence-class
     representatives `rep` in a single `LiveScoreWorldsByHandle(u_handle, rep, ...)` call per
     `CaseEval.compile` (1 boundary crossing and 0 `pack_world` loops instead of ~1,000).
   - Added `tools/test_csharp_slice_c2.gd` (+ `.uid`, `uid://dbbsd0qc7quhn`) and registered
     `test_csharp_slice_c2` in `tools/ci_fast_suites.txt`.

### Notes for Claude's check pass

- Pure .NET 8 BCL + `GodotSharp` only (zero external NuGet dependencies).
- Please post the updated `tools/profile_c0.gd` Seed 42 Day 4 table so we can see how much of
  both `pack_inputs` (`1,932 ms`) and `live_activity` (`2,904 ms` / `3,329 ms`) dropped before
  Slice C3 moves `solver.gd` + `case_eval.gd` compilation & marginalization into C#.

---

## 2026-11-03 ~13:30 ET, Claude: slice C0b + C1 checked, green, on main

- **Base:** `1821db3` as declared; unpacked on `csharp/slice-c1`, no conflicts, no
  changes needed to Argon's code.
- **Build:** `dotnet build -c Debug`: 0 warnings, 0 errors. All 262 scripts parse on the
  .NET binary.
- **Suites** (.NET Godot, Linux): all 13 from the manifest checklist pass, plus
  `test_workshop_ownership` and `test_headline`.
- **Golden vs `baseline_82faa5b`, `--tol 0`:** identical on all five seeds in **both**
  `--mode gdscript` (default) and `--mode csharp`; 0 script errors. Captures ran side by
  side under equal load: GDScript 750 s total, C# 568 s (about 24% faster end to end).
- **VERIFY:** `profile_c0` reports 18,207 boundary calls, 0 mismatches.

### Profile, seed 42 (7 NPCs, to Day 4), self time

| Stage | GDSCRIPT ms | CSHARP ms |
|---|---:|---:|
| outer_prep | 1406 | 1654 |
| pack_inputs | 0 | 1932 |
| world_domain | 5701 | 892 |
| live_activity | 2904 | 3329 |
| case_eval_compile | 1094 | 1168 |
| reason_attribution | 267 | 309 |
| **wall** | **11923** | **9918** |

(Profiled while a suite run used the other core, so absolute numbers are noisy; the
ratios are the useful part.)

### Notes for Argon

1. **Packing is now the bottleneck of what C1 moved.** `world_domain` dropped 6.4x
   (5.7 s to 0.9 s), but repacking inputs per call costs 1.9 s, about 1 ms per call for
   `coarse_masks` (819 calls), `bluff_weights` (314), `bluff_weights_temporal` (132) and
   `fits_weights` (754). The universe and role tables are the same across most of those
   calls within one refresh, so packing them once per refresh (or per universe key) and
   passing a handle should recover most of the 1.9 s. Same rule as before: key the cache
   on everything that varies, and clear it in `clear_context`.
2. **VERIFY barely exercises `coarse_masks`:** 4 calls in VERIFY against 819 in CSHARP.
   VERIFY seems to take a path where cached masks skip the comparison. Worth checking that
   VERIFY compares on every call, or it can miss a mismatch that CSHARP mode would ship.
3. **`channel_sum_product` shows 0 calls** in both modes on seed 42, so either that path
   doesn't run in this game or the timers are on functions that aren't the hot entry
   points. Confirm before C3 targets it.
4. **`live_activity` (2.9 s) is now the largest pure-GDScript stage after outer prep**,
   which supports C2 as the next slice, per the plan.
5. **The profile header says `refreshes=0`:** the refresh counter in `profile_c0.gd` isn't
   wired (the golden capture counts 67 for this seed). Cosmetic.

### CI (new, Michael's go-ahead)

`.github/workflows/ci.yml` now runs on every pull request and on main:

- builds the C# project on the Godot .NET binary;
- runs suites (`tools/ci_fast_suites.txt` on PRs, everything on main, 4 shards);
- diffs golden captures (gdscript and csharp modes) against `baseline_82faa5b` at
  `--tol 0`, failing on any `SCRIPT ERROR`.

A Windows golden job runs on main and manual runs and is informational until it first
agrees with Linux. Add new C# slice suites to `tools/ci_fast_suites.txt`.

Next actor: **Argon** (C2 `live_activity`, after the packing cache in note 1 if it's quick).

---

## 2026-11-03 11:55 ET, Argon: slice C0b + C1 delivered (`patch_002_slice_c1.zip`)

- **Base:** `main` at `1821db368bf22ec5d3436b8aa5407a54c6b3db86` (`1821db3`).
- **Deliverable:** `patch_002_slice_c1.zip` in Google Drive (`Demonologist Patches`), with
  full replacement/new files plus `MANIFEST_SLICE_C1.md`.
- **Status:** Ready for Claude verification (`dotnet build`, suites, Seed 42 profile run,
  and `--tol 0` golden capture vs `baseline_82faa5b`).
- **Next actor:** **Claude**.

### What's in `patch_002_slice_c1.zip`

1. **C0b hierarchical stage profiler & `tools/profile_c0.gd`:**
   - `workshop/solver_backend.gd` now maintains a re-entrant stage stack (`begin_stage` /
     `end_stage`) tracking both exclusive (`Self (ms)`) and inclusive (`Incl (ms)`) time
     with zero nested double-counting, plus per-boundary-function call counts and packing
     microseconds (`record_boundary_call` -> `pack_inputs`). Completely inert when
     `SolverBackend.profiling_enabled == false`.
   - Wired across `shared_ledger.gd`, `jury.gd`, `circumstantial.gd` (`outer_prep`),
     `world_domain.gd` & `role_constraints.gd` (`world_domain` + `pack_inputs`),
     `live_activity.gd` (`live_activity`), `case_eval.gd` (`case_eval_compile`),
     `channel_sum_product.gd` & `factored_channels.gd` (`channel_sum_product`), and
     `reason_attribution.gd` (`reason_attribution`).
   - Added `tools/profile_c0.gd` (+ `.uid`): plays Seed 42 (7 NPCs) to Day 4 across
     `GDSCRIPT`, `CSHARP`, and `VERIFY` modes, exercising lazy meeting `reasons_for`,
     asserting bit-exact state parity and 0 `VERIFY` mismatches, and printing
     `SolverBackend.format_profile_report`.
2. **C0b full kernel math call-site audit:**
   - Audited every `exp`, `log`, `pow`, `snappedf`, and `lerpf` call site in `workshop/`
     and recorded the full table in `docs/csharp_solver_migration.md` (Section 4).
   - Added `SolverBridge.GodotLerpf` (`from + (to - from) * weight` in `double`) +
     `EvalLerpfBatch`, and expanded `tools/test_csharp_slice_c0.gd` from 164 samples to
     the full kernel argument grid (`prior_k * suspicion`, `pow(2.0, log2_ratio)`,
     `pow(3.0, k)`, `log(x)`, `snappedf(..., 1e-9)`, and all `lerpf` endpoints) at 0 ULP.
3. **Slice C1 (`WorldDomain` + `RoleConstraints` + `SolverContext`):**
   - `workshop/cs/SolverContext.cs` (+ `.uid`): 8-byte `WorldEntry` struct (`Pack = 1`,
     58-bit layout inside `long Raw` covering up to 18 people, lossless distinction
     between absent vs `-1` `demon`/`converted`/`modifier` fields) and `SolverContext`
     universe cache cleared atomically by `SolverBridge.ClearContext()`.
   - `workshop/cs/WorldDomain.cs` (+ `.uid`) & `workshop/world_domain.gd`: 1:1 C# port of
     `worlds`, 64-bit `key`, `claims_compatible`, `healthy`, `gift_time`, and `rumor`,
     wired for `GDSCRIPT | CSHARP | VERIFY`.
   - `workshop/cs/RoleConstraints.cs` (+ `.uid`) & `workshop/role_constraints.gd`: 1:1 C#
     port of 64-bit `coarse_mask` + batched `coarse_masks` (wired into `CaseEval._coarse`
     so compilation crosses the boundary once per universe instead of 5,040 times),
     `fits` / `fit_weight` / `fits_table` / `fits_weights` (supporting both `reuse = true`
     and `reuse = false`, hoisted `Activity.routes` / Veteran `demon_routes` masks,
     Medium relays, Sleepwalker claims, Martyr, Sexton, Revenant curse/totem, all
     `ROLE_IN_GROUP` RoleDefs, and Seer Red Herring marginalization), and simple +
     temporal/curse `bluff_weights`.
   - Added `tools/test_csharp_slice_c1.gd` (+ `.uid`): tests 8-byte `WorldEntry`, cache
     reset, 7- & 10-NPC `WorldDomain`, 64-bit `coarse_masks`, every role constraint family,
     all 4 `Session` fixtures, and multi-day passive games on Seed 900 (7 NPCs) and Seed
     54875 (10 NPCs) across `GDSCRIPT`, `CSHARP`, and `VERIFY` at `--tol 0`.

### Notes for Claude's check pass

- Zero external NuGet packages used (pure .NET 8 BCL + `GodotSharp`).
- Keep `Demonologist.csproj` and `tools/run_gd_tests.py` (`Debug` build) as you adjusted
  in C0; neither file is touched by this slice.
- `tools/golden_capture.gd` now accepts `--mode csharp` (and `--mode verify`), while
  defaulting to `GDSCRIPT` when `--mode` is omitted. So you can capture C# golden output
  directly via `golden_capture.gd -- --out /tmp/golden_c1 --mode csharp` and diff against
  `tools/golden/baseline_82faa5b` at `--tol 0`. Please also post the `tools/profile_c0.gd`
  output table here so we have the Seed 42 Day 4 stage & marshaling numbers before Slice C2.

## 2026-11-03 05:43 ET, Claude: no new slice yet

- Checked Drive and `main`: no slice newer than `patch_001_slice_c0.zip`, and no new
  notes from Argon. `main` is still at the C0 entry below. Nothing to apply; stopping
  until Michael or Argon picks this up.
- Next actor: **Argon** (slice C1, or a C0b that wires the profiler first).

## 2026-11-03, Claude: slice C0 checked

- **Base:** `main` at `2273c8f` (PR #50: purge 2c/3, tuning hoist, post-purge baseline).
- **Patch:** `patch_001_slice_c0.zip` applied on `csharp/slice-c0`.
- **Status / next actor:** see the result section at the bottom of this entry.

### Container toolchain (works, offline)

- .NET SDK 8.0.133 from Ubuntu's archive; Godot 4.7.2 .NET build from GitHub releases.
- NuGet (`api.nuget.org`) and Microsoft's download sites are blocked here. The build
  resolves `Godot.NET.Sdk`, `GodotSharp` and `Godot.SourceGenerators` from the packages
  bundled with the Godot .NET download (`GodotSharp/Tools/nupkgs`) through a user-level
  NuGet config. **So C# code can't depend on any other NuGet package**: anything beyond
  the .NET base library and GodotSharp won't build in the test container.
- Tests and golden captures now run on the .NET Godot binary.

### Changes Claude made to C0

1. `project.godot`: `dotnet/project/assembly_name` changed from
   `"Demonologist (text prototype)"` to `"Demonologist"`. Godot looks for
   `<assembly_name>.csproj`, and the project file is `Demonologist.csproj`. **Michael's
   Windows editor will regenerate its own `.godot/mono` output under the new name; if it
   had a `Demonologist (text prototype).csproj` locally, that file is now unused.**
2. `tools/run_gd_tests.py`: builds `Demonologist.csproj` before running suites. It uses
   **Debug**, not Release as the manifest said: the editor binary (what headless test
   runs use) loads `.godot/mono/temp/bin/Debug`. A failed build fails the whole run.
3. `workshop/caches.gd`: `SolverBackend.clear_context()` added at the end of
   `clear_all()`, as the manifest asked.

### Notes for Argon

- **Static calls work.** GDScript calls the C# static methods on the loaded script
  (`SetMode`, `ClearContext`, `EvalMathBatch`, `VerifyFloat64Buffer`) without trouble on
  4.7.2, and `PackedFloat64Array`/`PackedInt32Array` marshal to `double[]`/`int[]`.
  Keep that pattern for C1.
- **The profiler isn't wired yet.** `SolverBackend.record_stage` and the stage list exist,
  but nothing calls them, so the C0 deliverable "late-game stage breakdown and marshalling
  budget" hasn't been measured. Suggest C1 (or a small C0b) adds timers around the real
  call sites (jury/shared_ledger outer prep, world_domain, live_activity `_likelihood`,
  case_eval compile, channel sum-product, reason attribution) behind
  `SolverBackend.profiling_enabled`, plus call counts per boundary function, and
  a `tools/profile_c0.gd` that plays seed 42 to Day 4 and prints
  `format_profile_report`. Claude will run it and post the numbers here.
- **The math audit covers a sample, not the kernel.** `test_csharp_slice_c0` checks 164
  hand-picked inputs at 0 ULP (all pass on Linux). The kernels' actual `exp`/`log`/`pow`
  call sites and argument ranges still need listing before C1; any that differ at a
  boundary need the shared implementation the plan describes.
- **Windows vs Linux check** (plan section 1.2) needs Michael's machine: run
  `tools/golden_capture.gd` there and diff it against `baseline_82faa5b`. Until then,
  only the Linux container is a valid golden platform.
- **Integer widths for C1:** `case_eval` world codes (`radix = 3^k`, `rm_bound`) need
  `long`. `Math.Round` must be `MidpointRounding.AwayFromZero` everywhere (the bridge
  does this). Pack people/cards in the same order GDScript iterates its dictionaries.
- **Golden runs need a clean log:** Godot keeps running when a script fails to compile, so
  check a capture's log for `SCRIPT ERROR` before trusting a diff. That's how two broken
  purge scripts got through on Nov 2.

### Result

- `dotnet build`: succeeds, 0 warnings (Debug and Release).
- Suites on the .NET Godot binary: `test_csharp_slice_c0` (164 checks, 0 ULP),
  `test_headline`, `test_workshop_ownership`, `test_legacy_purge_phase3`,
  `test_role_def_poc`, `test_beliefs`, `test_workshop_tuning_probe`: all pass.
  All 260 scripts parse.
- Golden capture on the .NET binary vs `baseline_82faa5b`, `--tol 0`: **all five seeds
  identical**, no script errors. So the .NET build of Godot plays the same game as the
  standard one, and C0 changed nothing.
- **Pushed to `main`.** Next actor: **Argon** (slice C1, or a C0b that wires the
  profiler first; see notes above). Claude checks Drive again around 05:40 ET.
