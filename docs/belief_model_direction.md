# Belief model direction: connections, not attention

Nov 10, 2026 · Claude-Lantern, Claude-Quill and Claude-Bailiff, with Michael · consolidated by Bailiff, Nov 13

**Status (Nov 13):** Phases 0–5 are done, and Phase 6 (the connections model in the game, behind a switch that is off) is being built. Steps 1–4 are merged (#141, #144, #145, #146), so the switch is ready for Michael's playtests, and the Why report explains it (#148). The stored-case rules (#150), caching (step 6, #151) and the buy-in fade (#153) are merged (Nov 14), and the Workshop's "No new info" note (#154) and the new "suspicious" pressure (#155, stacked on it) are open for Bailiff. Main is `5ac25ab`, and the golden baseline is `baseline_b281427`. Each phase goes to Michael before anything in it changes play.

**How to use this doc:** it holds the agreed design, the live Phase 6 spec, results that later work builds on, standing decisions and open items. Every earlier table, the Phase 4 prototype spec and the dated decision logs are kept word for word in `claude/belief-model-archive.md`. Put new results under "Phase 6 results" and keep them short; detail goes in the PR.

## The problem

Michael:
- It's hard to tell when a presentation actually mattered, and when the NPCs had already reached the right idea and the player was just on the same page.
- So the gap between bot and passive win rates may be mostly an extra good vote, vigils and traces, not the player making connections.
- Three things to solve:
  1. NPCs may be too smart.
  2. Insight and attention backfire in unintuitive ways.
  3. The player can do little with public facts, which are most of the game's information.

**What the evidence showed (Nov 10).** NPCs aren't too smart at winning; they're too smart at reading evidence. Each runs the full solver over its view, so cards connect themselves, and a case built from public cards has nothing left to supply. The view holding those combinations was unstable (the Day 4 Kiran case in playtest 12926 made two of four good listeners *less* suspicious), and a clash was often thrown away rather than counted against whoever's story failed. Single cards are weak; combinations carry the game. Bounded *belief* was never the original decision: in Oct 23–25 the migration decisions said attention should "limit what an NPC can explain in a reply, not what it believes".

**Positions that stand:**
- NPCs model a person's uncertainty, not a perfect reasoner.
- Only a listener's own readings reaching "strong" alone is fine: the game is combining and cross-checking.
- With both demon types on the script, night sightings being a misdirect is intended.
- **Guardrail:** NPCs must not become sheep. The player's theories should hit harder, but NPCs keep their own ideas and can disagree. Votes shouldn't collapse to "unanimous except the nominee" or "only the nominator voted".
- **The town being right is not the aim by itself** (Michael, Nov 12). Sometimes good needs to be wrong so the player can lead it. Results say what changes, not whether the change is good.
- **Soft aim:** legwork (vigils, wards, searches) and meeting play (presenting, nominating) should contribute about equally to a skilled player's edge. Today presenting measures as about zero.

## The design

The limit on an NPC moves from *which cards it reads* to *which cards it weighs together*. Settled by Michael between Nov 10 and Nov 12; the reasons are in the archive.

- **Every card counts alone,** at its single-card value, always. Nothing is ever out of view, so nothing can be evicted. Claims, confessed secrets and profile cards are context: they explain other cards without joining sets together.
- **Built-in pairings:** cards that mean little alone are always read with their partner, for every NPC (a night's movement cards; an Augur reading with that day's sightings; a Psychologist reading with its statements; a trace with profile cards).
- **The core:** each NPC weighs its firsthand knowledge together with whatever is worth more next to it than apart (threshold 0.4 at every town size).
  - The seed is its own readings, the night holding a Night Watch's or Lamplighter's own reports, and a night it was wrongly sighted ("he says he saw me out, and I wasn't").
  - Each candidate is tested against the seed only, so order can't matter and the core can't snowball.
  - Rebuilt at dawn. A newly heard card is tested when it arrives, so an NPC can catch a lie the day it hears it.
  - A presentation never edits the core. What the seed proves alone stays proved.
- **Presented cases** (the player's, and an NPC nominator's cited cards) are connections, weighed jointly and scaled by trust in the presenter.
  - They're re-weighed at every refresh, with no accepted or rejected state.
  - Old cases fade (× 0.5 a day) rather than being pushed out by a cap. Presenting a case again restores its weight, never above full.
  - A case overlapping the core merges with it, so one that clashes with the listener's own readings scores low by itself.
  - A challenge acts only inside its own case.
- **No per-teller bundles:** evil's stories are generated to cohere, so a bundle doesn't catch a liar.
- **Combining:** each card counts once; a connection adds only its interaction (joint minus the parts). Then one common shift so P(evil) sums to the evil count ("A for sure, then B or C", never four people at 70% in a two-evil town).
- **The demon-type declaration** is the player's call alone, at a meeting, at most once a day; single-demon scripts start declared.
  - **Walker:** the nights are strung together into one movement connection.
  - **Hexer:** the day evidence goes live, and night sightings count little against the Demon.
  - **Before a declaration:** each night is read by itself.
  - Changing the declaration costs 0.1 credibility with every NPC.
- **Insight is out for v1.** It may return later as one dial: the core threshold, or a second ring.
- **Smaller points:** a presented copy confirms a card was said but never replaces trust in its teller. The premise type changes what's asked, not how cards are weighed; the declaration is the one premise that changes weighting.

## Phase 6 spec: the connections model in game (Lantern)

Nov 12 · read against main `9e69144`. Michael answered its four questions as recommended (Nov 12); the answers are folded in below.

- **Switch off:** nothing changes, and golden stays identical at every PR.
- **Switch on:** one number changes, the chance an NPC gives each person of being evil at a belief refresh. Everything after it is today's code: suspicion, votes, nominations, who to hang first, trust.
- **Attention stops limiting belief.** The Insight card limit still decides what an NPC cites and explains.

### The switch

`Tuning.Workshop.CONNECTIONS`, off. `--connections` on autoplay, golden capture and sweeps sets a runtime variable, so Tally can run paired cells from one build. The model's memory exists only with the switch on.

### Single cards and pairings

- "Held" is what it is today: source doubt, hearing weights, relays and cards the NPC rejects from its own knowledge all run first. A rejected card has no value.

| Pairing | Read together | Context |
|---|---|---|
| A night | that night's sightings, home alibis, Night Watch reports and Lamplighter counts | the named people's claims and confessed secrets |
| An Augur day | every Augur reading that day, and that day's sightings | claims, known work schedules |
| A Psychologist reading | the reading and its two statements | none |
| A trace | the trace | profile cards |

| Declaration | Nights | Traces | The Hexer's day evidence |
|---|---|---|---|
| None (a script with both kinds) | Each night by itself; the Demon's movement is the 50/50 mix | With profiles | Off until "Hexer" is declared |
| Walker (declared, or walker-only script) | All nights and traces as one always-on movement connection (today's reading) | In the movement connection | Off |
| Hexer (declared, or Hexer-only script) | Each night by itself; sightings count little against the Demon | With profiles | On, as one always-on day connection |

- The always-on connections never merge with the core or a case.
- **#135's sighter contest and #139's self-sightings apply inside a night.** A sighter reporting on several nights is doubted night by night (one fact across nights again under Walker). The 10% "am I the Sleepwalker?" doubt applies per night; being wrongly sighted on two nights is rare (1 in 410 listener-dawns).

### The core

As in the design above. Membership is fixed within a day except for newly held cards and a change in the firsthand cards. What the firsthand cards prove alone (within 0.5% of 0 or 1) stays proved, and the others share what is left of the evil count.

### Stored cases

- **What is stored, per listener:** the case's cards, premise, challenges, presenter and day. That covers the player's presentations (public or private) and an NPC nominator's cited cards, for everyone who hears the nomination.
- **Weight:** trust in the presenter × 0.5 per day since it was presented (with #153, between 0.5 and 0.9 a day by buy-in: the more the case's cards, standing alone, move that listener, up to 0.7 log-odds). Under 0.05 it stops counting. A revision replaces its earlier version, and a "suspicious" premise halves the weight.
- **Reused cards don't stack (#150), per presenter.** It goes by the cited cards, not the premise.
  - A case citing every card of an earlier one, and counting at least as much, takes its place.
  - A weaker one leaves the earlier case in place and adds only what is new, so the cards keep the larger of the two weights.
  - A case sharing only some cards adds nothing for what the earlier one already put together.
  - Cards the movement connection holds add only what they say next to the case's other cards.
- **"Suspicious" pressure (#155; #150 used the held-back half):** how far the case's cards, alone and together, lift its subject for the average listener, × 4, up to 0.5 at a meeting and half that in private, once per filing. NPC nominators' cases fade by buy-in like the player's (Michael, Nov 14).
- **With the core:**
  - A case sharing a card with the core is judged with it as one set. The core's part counts in full; what the case adds is scaled by its weight. Older cases merge first.
  - Otherwise the case adds its interaction, scaled.
- **Cards a case brings become held,** and keep their single value after the case fades.
- **Challenges, inside the case:** "lying" changes no reliability. "Misled" and "failed gift" discount the reading inside the case's set only.

### Combining, normalising and caching

- Standing suspicion + every item's value + what the core adds + what each case adds, then one common shift to the evil count. People fixed by the public record or the NPC's own knowledge stay fixed.
- **P(Demon):** computed the same way, for logs and tools only.
- **Caching:** each value is redone only when its cards, hearing weights, trust in a teller it involves, a death, execution or attack, or the declaration changes. Values are measured against dawn suspicion, so a kept value is exact all day. Everything is redone at dawn.
- **Cost bar:** at or below today's refresh on the same states, counting redone items.

### What changes with the switch on

| Today | Switch on |
|---|---|
| Attention (Insight limit, recency) | Picks what is cited and explained, not what is believed |
| Spillover damping | Off: people a case didn't touch don't move, by construction |
| Headline reading | Off (Insight is out for v1) |
| Reading challenges on everything the NPC believes | Inside their own case only |
| A "lying" challenge's floor under its teller | Kept, scaled by the case's weight |
| Source doubt, rejected cards, hearing weights, relays, Muddler, belief to suspicion, votes, the hub, replies, the bot | Unchanged. **Known gap:** a reason may cite a pairing the model didn't weigh (polish, later) |

### Where it plugs in

- `workshop/connections.gd` is pure: view, case, listener and the core's memory in; chances, a breakdown and new memory out.
- One call site, `Jury._consequences_eval`, on the refresh path.
- Memory lives in `n.workshop_state.connections`. `Ownership._refresh` commits it, and the cached input carries it.
- The breakdown goes in the `workshop_ownership` trace for the why tool.
- The prototype tool (`tools/connections_prototype.gd`) is a harness over the module, so offline and in-game numbers can't drift apart.

### Build order

Small PRs; Bailiff merges. Every PR: golden identical with the switch off, its own suite with the switch on, a handoff-log entry.

| Step | Adds | Status |
|---|---|---|
| 1 | Switch, module, single-card values, normalising | **Merged, #141** |
| 2 | Built-in pairings, the three declaration rows | **Merged, #144** |
| 3 | The core | **Merged, #145** |
| 4 | Stored cases: player's and NPC nominations', fading, merging, challenges inside, "suspicious" halving | **Merged, #146** |
| 4b | Stored-case rules: reused cards don't stack, the movement connection isn't counted twice, "suspicious" pressure | **Merged, #150** |
| 6 | Caching: identical beliefs with the cache on and off; timing against today | **Merged, #151.** Halves a game; the cost bar is not met |
| 4c | Buy-in fade (triage 4.3) | **Merged, #153** |
| 5.2 | The Workshop's "No new info" note | **Open, #154** |
| | "Suspicious" pressure from what the cards point at | **Open, #155, stacked on #154** |
| End to end | The seven prototype criteria through the module on fresh passive seeds (and a new human log if there is one), then Tally's paired cells | Last |

## Phase 6 results

### Step 1 (#141, merged Nov 12)

- In game agrees with offline to within 0.00001 (22 listener-dawns, 3,771 values).
- **Finding:** today's "before" side leaves out the public record, and the judge on no cards includes it. So cards are measured against the judge on no cards, and today's "before" side is kept for the shift that becomes suspicion.
- **The prototype still holds on main `559a201`:**
  - No collapse, and vote shapes hold.
  - Separation at day 4+, today against the prototype: 0.50 / 0.52 (7 NPCs) and 0.39 / 0.44 (10 NPCs).
  - At 10 NPCs, the changed votes put seven more evil nominees on the block.
  - Seedless listener-dawns from day 3: 7 of 34 (7 NPCs) and 19 of 85 (10 NPCs).
- **Cost is setup, not weighing:** about 9 ms for a new card combination at 10 NPCs, against 0.24 ms for a kept one. `CaseEval`'s compile cache (32 entries) overflows in one refresh, so the model's own cache has to sit above it.

### Step 2 (#144, merged Nov 12)

- In game agrees with offline to within 0.00001 (210 listener-dawns). The comparison caught the tool keeping rejected cards; that is fixed.
- **The Hexer factor is read in one place:** every judgement runs with it off, and the day connection's value is its cards with the factor on minus off.
- **Both recent fixes work inside a night,** in today's direction. Under step 2 alone, Odette's view of the evil Constance was 0.42 against today's 0.66. That gap is the missing core (step 3).
- **"Connects little" in practice:** Fenwick and Jory reach 0.41 and 0.28 on the bluffing Hollis, against today's 0.70 and 0.50. Exposing him is left for a case to make.
- **Declaring changes little in passive Hexer games:** a Hexer call adds 2–3 points on the Hexer from day 4, and a wrong Walker call costs 3–8. That is about what today's model does, so the expectation that a declaration matters much more under connections isn't met here. The day connection leans slightly *away* from the true Hexer (−0.04 to −0.12). Not traced.
- **Codex's fixes at merge:**
  - All of a day's Augur readings are one item with that day's sightings, so a second reading no longer loses them by card order.
  - Known work schedules are the Augur item's context.

### Step 3, the core (#145, merged Nov 13; Lantern)

- **Golden** is identical with the switch off (Bailiff: full suite 146/146, two golden captures identical to `baseline_6a22cac`; Codex found nothing).
- **Against the prototype:**
  - With `--legacy-seed` the tool's output is identical to before (896 cores).
  - In game against the tool: 482 listener-moments, and seeds and members agree in all of them. Chances agree to within 1e-7.
- **Two differences from the prototype:**
  - **The seed is a little wider.** A pairing that holds the listener's own reading seeds the core (its Psychologist reading with its statements, its Augur day), so Psychologists now have a core. At 10 NPCs, seedless listener-dawns from day 3 go from 19 of 85 to 9; 7-NPC games don't change.
  - **The test leaves out what a pairing's context says alone.**
- **The wrongly sighted night** (measured before merge, as agreed): rare in passive play, at 3 of 469 listener-dawns, where it moved no chance more than 2 points. On the known games, read as the walker-only scripts they are:

  | Listener on the sighter | Today | With the seed | Without |
  |---|---|---|---|
  | Odette on Constance (evil; invented the sighting) | 0.66 | 0.66 | 0.52 |
  | Edda, a real Sleepwalker, on Constance (good; saw her truly) | 0.22 | 0.18 | 0.15 |
  | Constance on Hollis (evil; invented a Medium relay) | 0.93 | 0.92 | 0.92 |

  Under Walker the movement connection is never tested, so without the seed Odette's own reading never meets that night. With it, her chances match today's.
- **Cores in 22 passive games** (stored cases left out):
  - From day 3, 23 of 37 listener-dawns at 7 NPCs, and 49 of 94 at 10, have a joined card.
  - 11% and 6% of tested items join.
  - Separation at day 4+, today / step 3 / connects everything: 0.47 / 0.50 / 0.47 (7 NPCs) and 0.39 / 0.47 / 0.53 (10 NPCs). *(10 NPCs was 0.45 before step 4's baseline correction.)*
- **The large sets are movement seeds:** a seed holding the movement connection weighs a median of 55% of held cards together (up to 69%), the rest 34%. That answers step 1's open point about the 69%.
- **Distance from today, from day 3:** 59% of chances are within 5 points of today's, and 15% differ by more than 20 *(55% and 17% before step 4's baseline correction)*. The largest are whole reversals (Greta on Odette, seed 929: 0.88 today, 0.04 now). That one is traced below; the rest aren't, and the distance isn't split between steps 1–3.
- **Traced: Greta on Odette, seed 929, day 4 (Lantern, Nov 13).** The gap is today's attention limit, not the core. Odette is the good Lamplighter; Bart is the Demon, bluffing Night Watch.
  - **Today (0.88):** Greta reads 28 of her 44 cards. They include Bart's two "saw Odette pass Chapel Hill" reports on the kill nights and a Seer red herring on Odette. Both sightings of Odette on night 0 are among the 16 left out.
  - **Either of those two flips it:**

    | What Greta weighs | Odette | Bart |
    |---|---|---|
    | The 28 cards she reads today | 88% | 24% |
    | … plus Agnes's true sighting (Odette on the Square, night 0) | 69% | 31% |
    | … plus Kiran's relay ("the dead Lian saw Odette on Chapel Hill, night 0") | 4% | 95% |
    | All 44 cards, today's judge | 0% | 100% |
    | Connections (walker-only script, so every movement card is one connection) | 4% | 99% |
    | The two night-0 sightings and nothing else | 0% | 61% |

  - **Why night 0 is so strong:** the movement model's Demon never leaves home on night 0 (no kill), and a Minion goes out a quarter of the time by one route. Seen in two places that night, Odette fits only a real walking gift. Bart's own reports then place him at both kill scenes.
  - **In the game:** Greta voted to hang Odette and against hanging Bart on day 4; both votes tied 3–3, and Bart hanged on day 5. The other good listeners already had Odette low under today's model.
  - **Two things it turned up** (open items below): the relay was the evil Kiran's invention, meant as a frame, and it clears its target; and the sighter contest cut Kiran out, so his invention counted as the dead Lian's word.
- **Cost, switch on, golden seed 692:** today 92 ms a refresh, step 2 293 ms, step 3 411 ms. A day's first refresh makes about 50 judgements (10 NPCs, day 3); a seed holding the movement connection is the expensive case. Caching is the last step.

### Step 4, stored cases (#146, merged Nov 13; Lantern)

- **Checks:** golden is identical with the switch off (5 seeds); the fast list passes (54 of 54); a capture with the switch on runs clean. (Bailiff at merge: full suite 149/149; golden identical twice; a switch-on capture of all five golden seeds runs to the end with no script errors; Codex clean.)
- **Codex's two fixes at merge (Bailiff):**
  - A stored case's challenges also go on the judged case's `reading_challenges`, as today, so a challenged reading drops out of the Augur crossing and the Psychologist corroboration inside the case.
  - Storing an NPC nomination case queues each listener's refresh. Before, a silenced nominee (no defence to refresh anyone) could leave the vote on beliefs from before the case.
- **In game against the tool:** 15 logs, 586 listener-moments, 1,934 stored cases (516 the player's). The same cases count, in the same order and at the same weights, and chances agree to 0.000004. The bot never challenges, so challenges inside a case are tested by the suite only.
- **An error in steps 1–3, corrected (switch on only).** The model's baseline is a judgement on no cards. In play, a case with no cards reads every day card on the view for "who was near each silencing"; a judgement with a card reads only its own. So in a game with a silencing, every item's value carried the difference, once per item.
  - Found on bot seed 962: presenting "Kiran is evil" took Greta on Kiran from 0.91 to 0.55. It is now 0.93 to 0.93.
  - Six of the 22 passive games have a silencing. In those, chances within 5 points of today's go from 51% to 63%, and separation at day 4+ from 0.46 to 0.53 (today 0.46). The other 16 games are unchanged to the last digit. Step 3's figures above are corrected in place.
  - Not re-run: step 2's Hexer-game figures (1 of those 16 logs has a silencing).
- **A correction to the prototype's arithmetic:** a movement card cited by a case was taken off twice when the core holds the movement connection. It moved 4 of 93 dawn rows and 27 of 158 vote rows.
- **What a presentation does** (six bot games played with the switch off; 18 cases, 72 listener-presentations, all walker-only scripts):

  | | |
  |---|---|
  | Target's chance, mean | 0.54 before → 0.68 with the brought cards held → 0.70 with the case weighed |
  | Presentations that brought a card the listener didn't hold | 57 of 72 |
  | The case's own part on its target | up over a point in 29, down in 1, within a point in 42 |
  | A presentation lowering its target by over 2 points | 0 of 72 (before the baseline correction: 10 of 34, by up to 36) |
  | Presenting the same case twice | identical in 72 of 72 |

  Most of what a presentation does here is bring cards. The joint weighing adds about 2 points on average, and up to 2.2 log-odds.
- **Criterion 1 (people a case didn't touch move ≤ 3 points) on these games:** 18 of 72 are over, the largest 38 points.
  - In all 18 the brought cards do it by themselves, before the case is weighed. A new night card is read with its whole night or the movement connection, and a target who becomes near certain takes an evil place from everyone else.
  - The case's own part does it in 2 of 72, both one case (seed 963, "Agnes is evil").
  - The prototype passed this on 12926 (three cases, 13 listener-presentations, largest 2.8 points). Nothing tuned.
- **NPC nominations as cases, passive games:** separation at day 4+ with them is 0.50 (7 NPCs) and 0.48 (10), against 0.50 and 0.47 without.
- **Cost, switch on, golden seed 692:** 424 ms a refresh (411 at step 3, 93 today).

### The Why report and where the time goes (#148, merged Nov 13; Lantern)

From playtest 44542 (Michael's first with the switch on). Logging and profiling only; the stacking question is untouched.

- **The Why report now explains the connections result.** With the switch on it reads the breakdown the refresh stored, and the one before it; nothing is re-run, and today's stages (attention, change of view, already held, headline) are gone. Per person it shows every part of the chance before and after, the case's weight in its parts, the case's cards alone, the core, and suspicion as stored (it can go below zero; the game reads that as 0).
  - On 44542 it matches Bailiff's replay: Greta on "Fenwick is good", chance 32% → 18%, suspicion +0.07 → −0.18, the case weighed together −0.68 at weight 0.50.
  - On #40 ("Odette is suspicious", the same four cards) it says Odette stays at 34% and the cards, weighed together, fell on Fenwick (−0.34 at weight 0.25).
  - **Cost:** 19 reports took 14.7 s and now take 2.5 s (about 0.4 s for the first listener of a case, 0.09 s for each of the others).
  - **Codex's fix at merge (Bailiff):** a person proved by the listener's own knowledge (or settled by the public record) has their chance set outright, so the report shows a "settled outright" part and the parts still add up.
  - **Bailiff at merge:** full suite 150/150, golden identical twice, switch-on capture of all five seeds clean, Codex clean.
- **Logs say when the switch was on** (`case_start`), and the replay tools turn it on from that; `--connections` covers older logs. `replay_log.gd --time` and `--profile` show what each command cost.
- **Where the time goes in 44542** (this machine; Bailiff measured 4.3, 7.5 and 2.6 s for the last three):

  | Command | Switch off | Switch on | Refreshes | Judgements (time) | Repeats with the same answer |
  |---|---|---|---|---|---|
  | `gossip` | 0.8 s | 3.9 s | 17 | 268 (3.1 s) | 45 (0.4 s) |
  | `present 39` | 2.0 s | 3.3 s | 10 | 168 (1.6 s) | 118 (1.1 s) |
  | `nominate odette #40` | 2.2 s | 5.4 s | 19 | 307 (2.8 s) | 307 (2.8 s) |
  | `press role` | 0.2 s | 1.9 s | 9 | 163 (1.5 s) | 147 (1.4 s) |

  - A refresh makes about 17 judgements at 9–11 ms each, nearly all one card's own value. The time is setup per set of cards.
  - A repeat is a judgement the same listener already made that day with an identical answer. A per-listener cache would skip those: all of the nomination's, nine in ten of `press role`'s, two thirds of the presentation's.
  - A cache can't skip a set seen for the first time. `gossip` has 212 of those (2.6 s), 76 of them core tests (1.2 s). That part needs a cheaper judgement, not a cache.

### Stored-case rules (#150, open; Lantern, Nov 13–14)

Triage 4.2 and 4.4, with two calls Michael made that evening. Switch on only; golden identical to `baseline_4a1a075` with it off.

- **The rules** are in the spec above ("Reused cards don't stack"). The Hexer's day connection needed no change: a case never included it.
- **44542:** #40 "Odette is suspicious" cites the same four cards as #39 "Fenwick is good". Before the rules it counted them again (Greta on Fenwick 18% → 14%); now Fenwick stays where #39 put him (Greta 18%, Hollis 13%, Jory 19%, Kiran 22%). #89 on day 2 holds those cards and one more at a higher weight, so it replaces both.
- **A case's own target moves little** under either rule (per-case table in the handoff log). In six bot games 4.2 changes no chance by over a point, and 4.4 changes the target's by over a point in 9 of 72 listener-presentations (largest 12).
- **"Suspicious" pressure was zero with the switch on** since step 4 (it read a number only today's model fills in). Restored. #40 gives Odette +0.005: those cards say almost nothing about her.
- **The fade (4.3), measured, not built.** Chance Fenwick is evil at dawn of day 2 under 0.5 / 0.7 / buy-in: Greta 24 / 22 / 20%, Hollis 19 / 17 / 15%, Jory 33 / 30 / 27%, Kiran 37 / 34 / 31%. 0.7 takes back 2–3 points of the overnight rise and buy-in 4–6; the rest is other cards arriving overnight. Buy-in: a case keeps 0.5–0.9 of its weight a day, the more the further it moved that listener. Michael picked buy-in (Nov 13 evening); built in #153.
- **97626 no longer replays faithfully after #149** (passive play moved), so its figures are from before that merge.

### Caching, step 6 (#151, open, stacked on #150; Lantern, Nov 14)

- **Each listener keeps the judgements it has made,** keyed on what a judgement reads (the judged cards, the listener's firsthand knowledge and trust in people, deaths, the day), not on the whole input.
- **Beliefs are identical:** 28,644 kept answers judged again across 12 games, none different; both playtest logs give the same suspicions and dev log with the cache on and off.
- **Timing, cache off → on, switch on:**

  | | Off | On |
  |---|---|---|
  | 44542 replayed whole | 193 s | 96 s |
  | 97626 replayed whole | 282 s | 144 s |
  | 44542 `nominate odette #40` (day 1) | 6.5 s | 3.2 s |
  | 44542 `present 89` (day 2) | 7.8 s | 3.7 s |
  | 97626 `present 145` (day 3) | 11.4 s | 7.1 s |
  | 97626 `nominate jory #145` (day 3) | 10.1 s | 5.0 s |
  | 44542 `gossip` (day 1) | 4.8 s | 4.4 s |
  | A night (97626 `vigil square`) | 18.2 s | 11.8 s |

- **The cost bar is not met.** What remains is sets judged for the first time: new cards, and everything at dawn. A first-time judgement is 9–25 ms with no single dominant part. Options, not built: single cards judged for all listeners from one world table a day; dawn's refreshes spread over the night screen; skipping core tests whose cards and seed didn't change.

### Buy-in fade (#153, open, stacked on #151; Lantern, Nov 14)

- **The rule** is in the spec above ("Weight"). Nothing is stored: the rate is read again at each refresh.
- **One difference from what #150 measured:** the move is the case's own cards standing alone, not what it added after the reuse rule, so a repeat of the same cards fades like the original.
- **44542, in the game.** Chance Fenwick is evil at dawn of day 2, 0.5 a day → buy-in: Greta 24 → 20%, Hollis 19 → 15%, Jory 33 → 27%, Kiran 37 → 31% (18, 13, 19 and 22% the evening before). The case keeps 0.86–0.9 a day for these four.
- **It applies to NPC nominators' cases too** (Michael, Nov 14: keep it so). A case can now count for up to 28 days, against 4.

### The Workshop's "No new info" note (#154, open; Lantern, Nov 14)

Triage 5.2 with Michael's five rulings of Nov 14. Switch on only; nothing is computed or shown with it off.

- **Where:** on the Test juror's strength chip ("Moderate · No new info"), with the full sentence in its tooltip. The strength itself is unchanged.
- **How:** the game's stored-case rules run for a neutral listener who holds only this case's cards and the cards of the player's public cases, without the watch record. No NPC's knowledge is read.
- **The notes:**
  - no note if any card is one the town hasn't heard;
  - "No new info" when every card is public and together they add under 0.2 log-odds for anyone, when a public case of yours today already holds these cards, or when the public record settles the subject;
  - "Adds no new belief, but still presses X" for a "suspicious" repeat;
  - "Refreshes your day-D argument" when the same cards were put to the town on an earlier day.
- **Limits:** a bigger case on a later day gets no note even if its extra cards add little; "still presses" shows only from 0.15 pressure (#155); the "settled" note is untested.
- **Not checked against the playtests' own case numbers:** neither log replays faithfully on main after #149 and #152. Wording is Michael's to settle.

### "Suspicious" pressure (#155, open, stacked on #154; Lantern, Nov 14)

Michael: "suspicious" is the early-game tool and should have a solid chance of making someone who is holding back reveal something; about 0.3 from one basic incriminating reading. Switch on only; the switch-off rule is unchanged.

- **Why:** under connections the held-back half was only what the cards add together, so a lone reading pressed by exactly 0 (44542's "Odette is suspicious": 0.005).
- **For scale:** a press in conversation is +0.35, a nomination +0.4, one disclosure tier about 0.65, a hidden gift-holder's lock at a meeting breaks at 0.7, and pressure loses 40% a night. A basic case plus a nomination now lands at about 0.7.
- **Measured** (six fresh 10-NPC games, a reading from someone with no claim):

  | Case | Pressure at a meeting |
  |---|---|
  | Dowser "1 evil of these 2" | 0.26–0.32 |
  | Seer "yes" on a pair | 0.12–0.14 |
  | Dowser "1 evil of these 3" | 0.01–0.07 |
  | Dowser "1 of 2" and a second Dowser clearing the other | 0.18–0.33 |

- **Not measured:** an Archivist reading, a claimed teller (it will press harder; the cap is 0.5), and the playtests' own cases.

Full tables are in the archive.

## What earlier phases established

Full tables are in the archive.

- **Phase 0 (Tally's silent-bot cells, 7 NPCs, 200 paired seeds).** Presenting cases is worth about nothing to winning: bot against no-present −3.0, z −0.9. The bot's edge is its nominations (+9.5, z 3.0), which crowd out evil's, and its vigils, wards and searches (+10.5, z 2.9). Passive towns win about 40%. The no-present cell is the reference to beat.
- **Phase 1 fixes:**
  - **#123:** an accepted "lying" challenge keeps the clash.
  - **#124:** a person's own home alibi is lie-aware.
  - **#126:** the spoken stance follows the direction of the belief change.
  - **#124 caused a ~5-point drop.** Evil's fake sightings framed good stay-at-homes. #135 fixed it by weighing the sighter in the clash (in a world where the sighter is evil, a sighting counts at 0.15), and took the whole drop back: bot 64.5%, no-present 62.5%.
- **Phase 2:** the declaration (#131). Phase 5 had the bot declare (#137), and fixed a cache bug that kept declarations from reaching movement scores.
- **Phase 3 (Quill's interaction table).** It confirmed the 0.4 threshold: the pairs fall into two clusters, and 0.4 is where the second starts. Interactions roughly halve at 10 NPCs.
- **Phase 4 (Lantern's offline prototype, #129).** All seven acceptance criteria pass at 0.4 with fade 0.5:
  - People a case didn't touch move ≤ 3 points.
  - Hollis catches Kiran's lie.
  - The Day 4 case doesn't backfire.
  - Vote shapes hold.
  - Cost, cached.
  - Nothing moves without a reason.
  - The largest set judged together stays under 50% of held cards.
  - The core test checks pairs only. A three-card test would have pulled Lian's reading into Hollis's core (0.23 → 3.8); no fix was proposed.
- **Phase 5 (Tally's cells).** Neither switch moves win rate measurably. Cross-check cases fire in 13% of games, and 195 of 200 games are unchanged. The declaration is worth about +3.5 on Hexer games (z 1.5). The bot calls a Hexer right only 54% of the time; every miss is "walker".
- **Challenges:**
  - **#132, contest:** a clash's strength is the grounds' trust against the reader's. True grounds now land more often than false ones in every mode.
  - **#142, the graded test, content-only:** role-checked gifts (Archivist, Gravedigger and others) were invisible to the graded test. Now they're checked, with Marked registrations excluded. A lying challenge on true grounds lands 40% at 7 NPCs and 27% at 10, up from 20%; false grounds land no more often.
  - **The accepted cost:** a lying challenge against an honest reader already under suspicion lands 35%, up from 19%. Michael: "the player should be able to make that mistake and have it have a real cost."
  - **Not solved by a rule:** misled and failed gift rarely land on honest mistakes (3–12%). To the listener an honest mistake and a lie are the same cards.
- **Fixes from playtests (Nov 11–12):**
  - **#134:** framed defenders no longer contradict their own night account.
  - **#136:** evil's Gravedigger bluff follows what the town believed.
  - **#139:** a good NPC's sighting of itself on a night at home counts against the sighter, with the 10% Sleepwalker doubt. Poison breaks gift readings only and never invents a plain sighting.
  - **#140:** an evil Medium bluffer's relay no longer proves them a good Medium.
  - **#143:** a gift-holder who owned a night out no longer refuses it in private.
- **The Kiran refresh gap** (61% → 29% in 12926) doesn't reproduce on main: the update and the judge agree within 2 points over 402 pairs. Challenges are untested there, since the bot never challenges.

## Standing decisions not covered above

- **Playtesting with the switch on (Nov 13):** set `CONNECTIONS = true` in `sim/tuning.gd` (class `Workshop`) for the build. The game has no launch flag for it; only the tools take `--connections`. Expect slower belief updates (about 4.5× today's) until caching. From #148 a log played this way says so, and the replay tools turn the switch on from the log.

- **The declaration's default ("walker by default"?) and the bot's Hexer call** are on hold until the connections build and Michael's playtests (Nov 12). No change to the bot's thresholds until then.
- **The no-present sweep cell may declare the demon type** (Nov 12).
- **NPC nominators' cases:** no faster fade or cap yet. Revisit if up to nine live cases per listener shows up as a problem in play (Nov 11).
- **For playtesting two-kind games:** dynamic scripts deal one kind by default, so put both the Demon and the Hexer on the script (script editor, Demons).

## Open items

| Item | Owner | Status |
|---|---|---|
| A Night Watch list that wrongly names the listener | Bailiff | Open. Each name is scored as an independent slip, so keeping the list cleared the watch (−0.36). `SourceDoubt` still voids that night's list. Fix: a list that's wrong about the listener is suspect as a whole |
| Honest mistakes vs lies in challenges | Michael | Open. Misled and failed gift land 3–12% on honest mistakes; a rule can't separate them. It would need evidence that does, such as the teller's history or signs of poisoning. Measured on #142's first build only |
| The day connection leans away from the true Hexer | Lantern | Not traced (step 2). Passive games only; may differ with a player gathering day logs |
| Whole reversals against today's beliefs (Greta on Odette 0.88 → 0.04, seed 929) | Lantern | **That one traced (step 3 results):** today's attention left out the two cards that clear Odette. Others not traced. Day 3 of the same game goes the other way (connections 0.83, today 0.49, all cards together 0.13); not traced |
| A relayer cut from the sighter contest by the two-sighter cap | Bailiff | **New (Lantern, Nov 13), main's behaviour with the switch off.** Sighters of a person are ranked by how many sightings they told, then by town order, and only the first two are doubted (`SIGHTER_CONTEST_MAX`). In seed 929 that left out Kiran, an evil Medium who invented a relayed sighting, so it counted as the dead Lian's honest word. With the cap raised to 4 as a test, "today's 28 cards plus the relay" gives Odette 83% and Kiran 91%, against 4% and 71%. With all cards the answer barely moves (Odette 1%), since Agnes's true sighting stands either way. Not changed; it would move golden |
| An evil Medium's relay about the first victim names night 0 | Bailiff | **New (Lantern, Nov 13).** The bluff says the dead saw the scapegoat out "on their last night". For the first victim that is night 0, when the model's Demon never walks, so the frame lowers suspicion of its target (alone: Odette 37% → 31% evil, 12% → 6% the Demon). Not changed |
| A case with no cards can be answered from an older compile | Bailiff | **New (Lantern, Nov 13), main's behaviour with the switch off.** With a silencing on the record it reads the view's day cards, but `CaseEval`'s compile key doesn't include them. On seed 962 the same inputs gave Kiran 0.612 with every cache cleared and 0.579 from a warm one. Not changed; it could move golden |
| Under Walker, a case of night cards counts their meeting twice | Michael | **Decided and built, #150:** a case adds nothing for cards the movement connection already holds. (Step 4.) The movement connection already weighs every night card together in full; a case citing two or more adds what they say together again, at its weight. 25 of 72 listener-presentations in the bot games; over 0.5 log-odds on the target in 9. It is the prototype's arithmetic. Options: leave it (a presented theory hits harder), or have a case add nothing for cards the movement connection already holds |
| An NPC defender's challenge isn't in any stored case | Michael | **New (step 4).** It keeps today's floor and does nothing else. Option: store the defence as a case of its own |
| **Playtest 44542 (Nov 13), saved for later** | Michael | From Michael's first switch-on playtest (10 NPCs, build `c889b3c`). Bailiff replayed the log with the switch on and read the breakdowns |
| … Cases that reuse the same cards stack | Michael | **Decided and built, #150** (results above): replace when the new case holds every card and counts at least as much; otherwise nothing for the shared cards. Each stored case adds its connection separately, so the same cards under a new premise count again. In 44542 the Fenwick-Surveyor combination (Agnes's claim, Fenwick's claim and reading, Edda's Clerk reading) sat in three live cases on day 2 (#39, #40, #89). On Fenwick, Kiran's case leans were −0.39, −0.19 and −0.89 log-odds. Options: a case adds nothing for cards already in a stored case from the same presenter; the newer replaces the older; or both count |
| … The Why report doesn't describe the connections model | Lantern | **Fixed, #148 (merged Nov 13).** With the switch on it now reads the stored breakdown (results above): Greta on Fenwick shows 32% → 18%, suspicion +0.07 → −0.18. The 19 reports take 2.5 s, against 14.7 s |
| … The canvas reverses a premise → card link without saying so | Michael | `CanvasModel.connect_cards` swaps a premise → card link into card → premise. So "Fenwick is good → Archivist reading → Odette is evil" leaves only the Archivist reading under "Odette is evil" (Test juror ×1.1, doesn't support), while premise → premise plus card → premise gives ×2.7 (weak). Options: refuse the link and say why, or treat it as a condition ("given Fenwick is good, this reading points at Odette") |
| … What the strength badge means under connections | Michael | **Decided (keep the badge, one "No new info" note) and built, #154 (results above).** The badge is the Test juror's likelihood ratio on the premise (×1.5 weak, ×3 moderate, ×10 strong): "is the argument sound". What moves NPCs under connections is the case's interaction beyond single values, scaled by credibility, so a strong badge can add nothing and a weak one can land well ("Fenwick is good": weak-ish, moved most listeners about 0.25 suspicion). Proposal: keep the badge as the soundness check and add a "what this adds for the town" indicator. Settle with the agreement-sets-hearing-weight link (presented cards are heard at the case's agreement) |
| … The Test juror ignores answers and challenges | Michael | Answers ("Hollis is the Delusional one", "Isolde is the Seer's red herring") are scored as theory fit, never as evidence, and the juror doesn't apply challenges, grounded or not. On "Isolde is not the demon" (Agnes's Delusional reading + Hollis's Seer yes), six variants with and without answers and challenges all came out ×0.41 (argues against). The badge then can't show what a challenge would do |
| … Linking a teller's claim | Michael | A reading's teller's claim card has to be linked by hand for the juror to count it; under connections the claim is context automatically. Proposal: link it automatically. **Also in 97626:** Nisha's Registrar reading "Kiran holds none of Night Watch, Clerk, Dowser" alone is ×1.26 (doesn't support), because the juror doesn't know Kiran claimed Dowser; next to his Dowser reading (which carries the claim) it multiplies the case by about ×11 |
| … Playtest 97626: why Kiran's Dowser reading alone is "strong" | — | **Explained (Bailiff, Nov 13).** "0 evil among Jory, Odette, Edda, Nisha, Agnes" is itself unlikely to be true: with three evil among the other nine, an honest zero for a five-person group happens about 5% of the time (4 of 84 evil teams). So the reading points at a lying or broken Dowser. Alone it is ×11.7 on day 2 and ×27.5 by day 4, as the public record grows. Agnes's Surveyor claim plus the Town Hall "Surveyor or Dowser, not both" adds about ×3.8 on top (912 against 242), less than it reads, because it is a 50/50 between Agnes and Kiran until the Dowser reading tips it. Related: the backlog's "Dowser clearing strength" |
| … An either/or premise | Michael | Michael's strongest argument was "one of Odette and Kiran is evil", but a nomination needs one name. Options: "suspicious" as the lower-bar vehicle, or an either/or premise judged as written that lets you nominate either name |
| … A sound conclusion fades overnight | Michael | **Decided (buy-in) and built, #153 (results above).** Michael (Nov 13): a slower fade is probably the move, or a fade scaled by how much the listener bought the case, if that isn't hard. In 44542, "Fenwick is good" lost half its weight at dawn of day 2, and suspicion of Fenwick rebounded from about −0.18 to about +0.10 for Greta, Hollis, Jory and Kiran with nothing against it. (Isolde's Archivist reading, which names Fenwick as one of two Scion candidates, pushed the same way.) A slower fade (0.7) barely changed outcomes in the prototype |
| … A good NPC hiding a gift lies about being home | Michael | Jory, the good Warden, told the player privately "Home all last night" (log: "Hiding (hidden Warden gift): lie outright rather than stonewall? yes (p=0.65)"). The player presented it with Greta's true Night Watch sighting, the night pairing read it as a lie, and the town hanged him 7–2 (suspicion of Jory, e.g. Nisha −0.36 → 0.43; the case's own connection was only 0.15–0.3 log-odds). Existing behaviour, made more decisive by connections. Option: a hiding gift-holder declines ("I'd rather not say") instead of inventing "home" |
| … The Test juror's verdict on a case drops at a silencing | Bailiff | "Fenwick is good" (#39, same cards) is moderate ×4.4 through day 2, ×3.25 after Hollis's death at dawn of day 3, and ×0.95 (doesn't support) from the day 3 meeting, when Isolde is silenced. Nothing in the case changed, and its prior stays 0.70. Likely the silencing quirk from step 4 (a case with no cards reads every day card for "who was near each silencing"; a case with cards reads only its own), fixed for the connections baseline but not for the juror. To check |
| The spoken reply to a later-day repeat | — | Polish. Re-presenting a faded case restores its weight, but the reply is today's code and may say the assessment is unchanged |
| Cost with redone items counted | Lantern | **The cache is built (results above) and halves a game, but the bar is not met:** late presentations are 4–7 s and nights 11–21 s. Step 6. The prototype missed the strict bar, and step 4 is at 424 ms against today's 93 ms on seed 692 uncached. **Profiled on 44542 (#148):** repeats a per-listener cache would skip are 1.1 of 3.3 s (`present`), 2.8 of 5.4 s (`nominate`) and 1.4 of 1.9 s (`press role`). First-time sets (`gossip`, 2.6 of 3.9 s) need a cheaper judgement as well |
| Declaration default and the bot's Hexer call | Michael, Bailiff | On hold (above) |
| Sleepwalker self-doubt scaled by confidence | — | Backlog; 10% flat for now |
| A reason citing a pairing the model didn't weigh | — | Polish, after end to end |
| Adjudicating a muddled card | — | Later |
| Brute kills scored as hexes on custom scripts | — | Later |

## Owners

- **Lantern:** Phase 6. Steps 1–4 are merged (#141, #144, #145, #146); the Why report and profiling are merged (#148); the stored-case rules (#150), caching (#151) and the buy-in fade (#153) are merged; the Workshop's "No new info" note (#154) and the "suspicious" pressure (#155) are open; next is a cheaper first-time judgement.
- **Bailiff:** checks, golden and merges (#145, #146, #148 and Steward's maintenance #147 merged Nov 13); the Night Watch list fix when it's scheduled.
- **Quill:** the challenge work is done (#132, #142). Next is whatever step 4's in-case challenges need.
- **Tally:** paired cells once Phase 6 runs end to end.
