# Belief model direction: archive (to Nov 13)

The full doc as it stood on Nov 13, 2026, before Bailiff consolidated it. It has every phase's tables, the Phase 4 prototype spec and results, and the decision logs. The live doc is `docs/belief_model.md`. Nothing here is current unless the live doc says so.

---

# (Archived) Belief model direction: connections, not attention

Nov 10, 2026 · Claude-Lantern, Claude-Quill and Claude-Bailiff, with Michael · condensed and revised by Bailiff

**Status:** the design is agreed in outline. Phase 0 and Phase 1 are done (main `7404873`). Lantern's spec questions are settled ("Decisions, Nov 10 evening" below). The offline prototype is built (PR #129): five of seven criteria passed, and Michael has settled the two failures ("Decisions, Nov 10 late"). Lantern's fixes are built and rerun: all seven criteria pass. **Merged Nov 11: the prototype (#129) and Quill's challenge fix (#132, "contest"); Michael's choices are under "Decisions, Nov 11".** Tally pinned the Phase 1 drop on #124 (evil's fake sightings now convict good stay-at-homes). **Fixed Nov 11: a sighter's word is now weighed by the sighter's alignment (#135, golden `baseline_bd1b404`). Tally's cell: it takes back the whole Phase 1 drop (bot 64.5%, no-present 62.5%). Evil's Gravedigger bluffs now follow what the town believed (#136, golden `baseline_f40ca05`). Phase 5 is merged (#137, main `645fa16`; golden unchanged): the bot builds cross-check cases and declares the demon type, and a Workshop cache bug that kept a declaration from reaching movement scores is fixed. Tally's Phase 5 cells: neither switch moves win rate measurably; the bot calls Hexers right only 54% of the time. The declaration's default and the bot's Hexer call are on hold until the connections build and Michael's playtests ("Decisions, Nov 12"). Fixed Nov 12: a good NPC's sighting of themselves on a night at home now counts against the sighter (#139, golden `baseline_300fe18`). The Kiran refresh gap doesn't reproduce on main. Fixed Nov 12: an evil Medium bluffer's relay no longer proves them a good Medium (#140, golden `baseline_6a22cac`). Next: the connections build (Phase 6). Lantern's in-game spec is written ("Phase 6 spec"), and Michael has accepted all four of its recommendations (Nov 12). Step 1 (the switch, single-card values and normalising) is merged as #141 (main `8be9681`; golden identical while the switch is off); the prototype still holds on main `559a201` ("Results: Phase 6 step 1"). Step 2 (built-in pairings and the declaration's three readings of movement) is merged as #144 (main `beaa212`; golden identical while the switch is off; "Results: Phase 6 step 2"). Quill's graded-test fix for challenges is merged as #142 (main `437e29e`; golden unchanged), content-only after Codex's review; Michael accepted the cost to an honest suspected reader ("Challenge sides"). Step 3 (the core) is open as PR #145 (golden identical while the switch is off; "Results: Phase 6 step 3").** Each phase goes to Michael before anything in it changes play.

## The problem

Michael:
- It's hard to tell when a presentation actually mattered, and when the NPCs had already reached the right idea and the player was just on the same page.
- So the gap between bot and passive win rates may be mostly an extra good vote, vigils and traces, not the player making connections.
- Three things to solve:
  1. NPCs may be too smart.
  2. Insight and attention backfire in unintuitive ways.
  3. The player can do little with public facts, which are most of the game's information.

Positions that stand:
- NPCs model a person's uncertainty, not a perfect reasoner.
- Only a listener's own readings reaching "strong" alone is fine: the game is combining and cross-checking.
- With both demon types on the script, night sightings being a misdirect is intended.
- **Guardrail:** NPCs must not become sheep. The player's theories should hit harder, but NPCs keep their own ideas and can disagree. Votes shouldn't collapse to "unanimous except the nominee" or "only the nominator voted". Hollis catching that Kiran's reading was probably a lie is behaviour to keep.

## What the evidence showed

- **The Day 4 case on Kiran (human playtest 12926, `tools/replay_log.gd --why`).** Three public cards plus a "lying" challenge on Kiran's Chronicler reading. Two of four good listeners became *less* suspicious of Kiran.
  - **Hollis (69% → 45%).** The accepted challenge multiplies down the reading's reliability (`reading_challenges.gd`). In `CaseEval`, error only applies in good-source worlds, so the reading then fits everywhere, and the clash that was the evidence of the lie disappears. Citing the card also raised its reliability (0.28 → 0.88): in `Shared.prepare`, a reading takes the highest weight among the ways the listener holds it, and the presentation's `case:` copy counts as one.
  - **Dorian (36% → 27%).** The presentation reshuffled his 12-card view: three cards left and two entered. With his old view kept, Kiran stays at 36%, and the swap moved bystanders more than the subject (Nisha 48% → 10%).
- **A home alibi wins against any sighting (measured catalog, `LiveActivity._observed`).** A person's own home alibi scores every route with them out at 0 in every alignment. So a sighting of them carries no information, and a false alibi clears its giver by 0.14–0.18. Relayed alibis already get a lie-aware value.
- **Single cards are weak, and combinations carry the game.** A source's readings together are worth about three times one. Several cards are worth nothing alone: Augur, Psychologist, Lamplighter, traces. Clerk, Registrar, Monitor, Executor and Martyr readings land mostly on the reader's credibility.
- **Spillover damping misses the common case.** `Shared.premise_shaping` only damps cards held solely through the presentation, so a case built from public cards isn't damped. The view reshuffle cancels out of it too.
- **Sweeps.** Passive towns win 29–35% and the bot 56–60%, but no run separates presenting from the bot's other actions. In passive games, 73–75% of wrongful hangs come from an evil nomination the town carried.
- **History.** Bounded *belief* was never the original decision. The Oct 23–25 migration decisions said attention should "limit what an NPC can explain in a reply, not what it believes". The Oct 19–20 north star was "NPCs judge the player's theory; they don't search for theories." Bounded attention has misfired before (migration lesson 2; playtest 13910).

**Reading:** NPCs aren't too smart at winning; they're too smart at reading evidence. Each runs the full solver over its view, so cards connect themselves, and a case built from public cards has nothing left to supply. Meanwhile the view that holds those combinations is unstable, and a clash is often thrown away rather than counted against whoever's story fails.

## The design: connections

The limit on an NPC moves from *which cards it reads* to *which cards it weighs together*.

### Every card counts alone

Every card an NPC holds counts at its single-card ("solo") value, always. Nothing is ever out of view, so nothing can be evicted.

### Structural pairings

Cards that mean nothing alone always connect with their partner, for every NPC, because that is how the card is read rather than an inference:

| Card | Connects with |
|---|---|
| Night sighting | that night's murder block, and the person's claimed gift or confessed secret (is the outing explained?) |
| Home alibi | a sighting of the same person that night: the clash counts against whoever's story fails, at trust in each teller |
| Augur reading | that day's sightings |
| Psychologist reading | its two statements |
| Lamplighter count | that night's sightings |
| Crime-scene trace | profile context (work, haunts, home, bonds) |

A card that names people (Dowser, Archivist, a Veteran's attacker block, and so on) has solo meaning and isn't structural. No change to the Augur for now.

### The core

Each NPC's own connections grow from its firsthand knowledge: its own readings, its own sightings and vigils, and knowing it is good.
- **Joining the core:** a held card joins if it is worth more next to the core than alone: the card and core together, minus the core alone, minus the card alone, above a threshold. A strong solo card (a Demon victim, a Gravedigger read) doesn't join and keeps its full solo value.
- **Rebuilt once a day, at dawn.** Beliefs stay steady within a day and can shift overnight, for example when a source dies to the Demon and becomes more credible.
- **A newly heard card is tested against the core when it arrives** (one interaction check), so an NPC can catch something the day it hears it. The full rebuild is still at dawn.
- **A presentation never edits the core.**

### Per-teller bundles (not in the first prototype)

The idea was to weigh each teller's statements together, so a person who contradicts themselves gets caught. **Dropped for the first prototype** (Michael, Nov 10): Quill's table shows a bundle doesn't catch a liar (an evil teller's two bluffs together move them +0.06), because evil's stories are generated to cohere. Thin cores (a Veteran's) are protected instead by presenter credibility and watched through the vote-shape numbers. Revisit if those show low-information roles being herded.

### Presented cases

A presented case, and an NPC nomination's case, is a connection:
- It's weighed jointly and scaled by the listener's trust in the presenter.
- It's stored as its list of cards and re-weighed at every refresh, so it gains or loses force as the facts and trust change. No separate "accepted" or "rejected" state.
- If it overlaps the core, it merges with it. A case that clashes with the listener's own readings then scores low by itself, with no special rule.
- **Old cases fade** instead of being dropped by a cap (Michael, Nov 10 late): a hard cap of two made a third case push the oldest out, which moved the people it concerned. A revision replaces its earlier version. The fade rate is a knob.

### Combining

- Each card counts once, at its solo value. A connection adds only its interaction (joint minus the sum of its solos), and this can be negative, as in a defence.
- Overlapping connections merge.
- **Normalised afterwards:** P(evil) sums to the evil count, and P(Demon) to 1. That allows "A for sure, then B or C", without four people at 70% in a two-evil town.

### The demon-type declaration

- **Who and when:** only the player, as a public declaration at a meeting, at most once per day: "We're dealing with a <type> Demon." It's the Demonologist's expertise, so NPCs don't judge it.
- **Single-demon scripts** start with it already declared.
- **Effect (town-wide):**
  - **Walker:** the full movement model goes live (routes, nights strung together, vigil exclusions, trace routes), and the Hexer factor fades.
  - **Hexer:** day logs, haunts and the Hexer factor go live, and night sightings lose most of their weight against the Demon.
- **Before a declaration:** movement is limited to the structural pairings above. Evidence that applies to either type still counts at its solo value; for example, a Veteran's "the attacker came by way of the Docks" raises suspicion of the Docks' residents.
- **Being wrong costs:** the town looks at the wrong evidence. Changing the declaration is a straight credibility penalty, which weakens every case the player has stored and every case they make afterwards.

### Insight

Insight is out for the first version, to get a clean baseline. It returns later as one dial: the core threshold, or a second ring.

### Settled smaller points

- A presented copy can confirm that a card was said, but it never replaces trust in the person who said it.
- Hearing weight still matters for relays and the Muddler. **Flagged for later:** how to adjudicate a muddled card.
- **The premise type doesn't change how cards are weighed,** only what's asked (Quill measured this). Premises keep their jobs: naming the case's target and question, the suspicious/pressure split, and the secret reading. The demon-type declaration is the one premise meant to change weighting.
- New NPC reply lines (for example "that squares with what my gift showed me") are polish, for after the prototype.

### Soft aim (Michael)

Legwork (vigils, wards, searches) and meeting play (presenting, nominating) should contribute about equally to a skilled player's edge. That's an aim, not a pass mark. Today presenting measures as about zero (Phase 0).

### Open knobs (numbers, for after measurement)

- The core threshold.
- How fast an old stored case fades.
- The size of the change-of-mind penalty (start near what one failed case costs today).
- Whether credibility should scale how fully the town adopts a declaration (start: full adoption).

## Plan

Small samples first, so work isn't waiting on a full sweep. Golden-moving PRs merge one at a time, each with its own re-baseline.

### Phase 0: a baseline on today's model

- **Vote-shape logging** in autoplay summaries and the sweep records (Bailiff). **Done: PR #122, merged; Tally's baseline pins `400ce06`.**
  - votes unanimous apart from the nominee;
  - votes where only the nominator says yes;
  - how often an evil nomination carries.
- **Silent-bot cells (Tally):**
  - **no-present:** the bot files cases to nominate (M2a) but never presents privately;
  - **present-and-vote:** no vigils, wards or searches.

  Paired seeds, small sample. **Done (PR #127); results below.** No-present files a case each meeting, so nominations rest on it, but doesn't present at the meeting, convince or tell.
- **Read-everything gap (Quill):** bounded view against all cards, on real day-3 and day-4 listener states. **Done; results below.**

### Phase 1: fixes valid under any design

One PR each:
1. **A presented copy doesn't raise a challenged card's reliability** (Bailiff). **Dropped (Michael):** the code shows the rise is the presentation confirming the card was said (its hearing discount lifted), not the presenter's credibility replacing trust in the teller. Since nobody misreports what others said, that's fine. **Flagged for later:** how to adjudicate a muddled card (the Muddler is the one case where "was it said this way" is in doubt).
2. **An accepted "lying" challenge keeps the clash:** reliability unchanged in lying mode, the flat `JURY_CHALLENGE_LYING_SCALE` nudge dropped there, and the discount kept for misled and failed gift (Bailiff). **PR #123, merged** (golden `baseline_73b103a`). The floor nudge was kept, since it's a floor, not an addition. Golden: only 98933 moves, by about 1e-6.
3. **A person's own home alibi becomes lie-aware** (Quill). The listener's own alibi stays hard. **PR #124, merged.**
   - Michael accepted the lower watcher rise (0.120): the alibi-giver lying is a real third explanation. Trust in the subject doesn't scale it, since in a world where they're evil they lie however trusted they are.
   - Codex's fix: own and witness alibis now count separately, so card order can't drop a witness's alibi.
   - Golden `baseline_a03bf72`.
4. **The spoken stance follows the direction of the belief change, not just its size** (Bailiff). **PR #126, merged** (golden unchanged). Cause, from the 12926 replay: a retold case (nothing new) kept the scoped reply's "accept" whatever the belief did. Dorian's suspicion of Kiran fell 0.17 → 0.05 and he still said "it changes how I see Kiran". Now it needs the belief not to have fallen. Replayed at `75b4c8e`: Dorian's voiced stance becomes reject, and the other five listeners are unchanged.

Then a small paired check against Phase 0: Tally reruns bot and no-present at 7 NPCs on `7404873`.

**Paired check (Tally, Nov 10).** Run `42926424433` on `7404873` plus the PR #127 modes (tools only). 7 NPCs, dynamic scripts, seeds 100000–100199, paired with the Phase 0 runs (`42891633471` bot, `42908805272` no-present).

| Cell | Good wins, Phase 0 → Phase 1 | Paired change (discordant, z) | Wrongful exec/game | Evil exec/game |
|---|---|---|---|---|
| bot | 59.5% → 55.0% | −4.5 (25 / 34, z −1.2) | 0.62 → 0.82 | 1.12 → 1.03 |
| no-present | 62.5% → 56.0% | −6.5 (20 / 33, z −1.8) | 0.58 → 0.78 | 1.17 → 1.03 |

- **Presenting's value is unchanged:** bot vs no-present is −1.0 (21 / 23, z −0.3), against −3.0 in Phase 0. Still about nothing.
- **The baseline may have dropped about 5 points,** through more wrongful hangs (+0.2 a game in both cells) and slightly fewer evil ones. Each cell alone is noise. Pooled, the two cells give 45 / 67 discordant (z about −2.1), and they share seeds, so that overstates it somewhat. **Suggestive, not established.**
- **The likely cause is fix 3.** The bot never challenges readings, so fix 2 rarely applies; fix 4 is wording only. With an evil subject's own home alibi now lie-aware, a sighting against it convicts (Quill's table), and good night-walkers sighted against their own alibi pay too. Not isolated: that would take one more paired cell with #124 reverted.

| Vote shape (7 NPCs) | Votes/game | Unanimous but the nominee | Only the nominator | Evil nominations/game | …carried | …hanged |
|---|---|---|---|---|---|---|
| bot, Phase 0 → 1 | 5.2 → 4.9 | 18.0% → 21.0% | 29.0% → 29.5% | 2.08 → 1.96 | 14.5% → 18.6% | 13.0% → 17.6% |
| no-present, Phase 0 → 1 | 5.1 → 5.0 | 17.9% → 19.3% | 28.6% → 29.6% | 2.21 → 2.01 | 12.0% → 12.7% | 11.6% → 11.9% |

The guardrail holds: unanimous votes rose 1–3 points, within noise. The bot's evil nominations carry a bit more often (+4 points, about 8 more over 200 games), which fits the extra wrongful hangs.

**#124 reverted (Tally, Nov 11).** Run `42962576861` on the experiment branch `claude/exp-revert-124` (`7404873` with #124's merge reverted, plus the #127 modes; never merged). Same cells and seeds.

- **#124 is the whole Phase 1 change.** With it reverted, both cells reproduce Phase 0 game for game: identical outcomes on all 200 seeds, identical executions and vote shapes. Everything else merged between `400ce06` and `7404873` is play-neutral at 7 NPCs.
- **Against Phase 1 (isolates #124):** bot +4.5 (34 / 25, z 1.2), no-present +6.5 (33 / 20, z 1.8). Wrongful hangs 0.82 → 0.62 and 0.78 → 0.58 a game. Vote shapes are exactly the Phase 0 rows above.
- **The effect is real, even though the win rate alone is borderline.** Take the first execution that differs between the two versions of each game. #124 hangs a good person where the revert hanged an evil one in 43 games (bot) and 44 (no-present). The reverse happens in 19 and 12. Adding "hanged nobody" cases: 51 against 22, and 48 against 15.
- **Which hangs it adds: not good night-walkers.** Of the hangs #124 adds, 29% (bot) and 19% (no-present) are night-walking gifts (Confessor, Lamplighter, Medium, Night Watch, Warden), the same as their 26–27% share of wrongful hangs without #124. Most are Rumormongers, Clerks and Archivists, mostly on day 2, and mostly nominated by the bot (31 of 51; 35 of 48), with the town now carrying the vote.
- **The mechanism is evil's fake sighting of its scapegoat.** Of five added hangs I traced in the logs, four follow one pattern. The Demon or Minion bluffs a night gift, plants a sighting of its good scapegoat ("I watched Chapel Hill: I saw Constance pass by"), and the scapegoat truthfully says she stayed home.
  - **Before #124,** her own alibi was hard, so the clash pointed at the sighter. In seed 100084 the vote on Constance got 0 yes, and the Demon Lian was hanged next.
  - **With #124,** "she's evil and lying about home" absorbs the clash. 6 of 7 vote yes and Constance (Clerk) hangs; the Demon is never caught.
  - The same pattern holds in 100017 and 100113 (a Rumormonger each), and in 100012 (a Rumormonger framed by the Demon at the meeting). Seed 100024 doesn't fit: there, a Gravedigger was framed by fake readings.
- **For Bailiff's fix:** the suspected cause (only trust in the sighter enters the clash, and good people are assumed truthful) holds, but it's the framed good stay-at-home who pays, not the night-walker. A fix should make the clash weigh both tellers: the sighter can be evil too, which the old hard alibi got right by accident.

**Sighter contests (Bailiff, Nov 11; PR #135, merged; golden `baseline_bd1b404`).** The fix for evil's fake sightings, agreed with Michael on playtest 30987. He didn't want to overcorrect: "his word against theirs" should come down to priors, and Dorian should stay a strong frame.
- **Rule:** in a world where the sighter is evil, a sighting (or a Night Watch's "saw X pass by") of a person counts at `EVIL_SIGHTER_TRUTH` (0.15), since evil tells the truth when it suits them. Otherwise it counts as invented, scaled so an invented sighting is as likely as an honest one on average. In worlds where the sighter is good, nothing changes.
- **A sighter converted by the Revenant's curse** is doubted only for what they told while converted (Codex's review).
- **Not covered:** the Scion's split branches, and the single-person likelihood used for dialogue explanations.
- **Playtest 30987, simulated, then built** (before → after):

  | Vote | Listener: person | Before | Built |
  |---|---|---|---|
  | Day 2 | Edda: Dorian | 100% | 74% |
  | Day 2 | Isolde: Dorian | 80% | 70% |
  | Day 2 | Fenwick: Dorian | 69% | 63% |
  | Day 3 | Edda: Hollis | 97% | 82% |

  Dorian stays the frame, the sighter Merrin rises, and the day-3 overconfidence comes down. Ignoring the sighting altogether or counting it at 10–15% changed these by 1–3 points.
- **Side effect:** a good NPC's true sighting is also discounted in worlds where that NPC is evil. So walking evidence is weaker, and the demon-type declaration has less to work with. Over 21 two-kind games, the right kind averages 0.171 on the Demon against 0.143 for the wrong kind (0.197 against 0.154 before). Expected to cost good some win rate; Michael's playtests suggest evil is the weaker side. Measured below (Tally).

**Paired cell on #135 (Tally, Nov 12).** Run `43133420431` on main `12cd656`. Same cells, seeds and settings as Phase 1.

| Cell | Phase 0 → Phase 1 → #135 | #135 vs Phase 1 (discordant, z) | #135 vs Phase 0 (discordant, z) | Wrongful / evil exec per game |
|---|---|---|---|---|
| bot | 59.5% → 55.0% → **64.5%** | +9.5 (29 / 10, z 3.0) | +5.0 (33 / 23, z 1.3) | 0.69 / 1.17 (P0 0.62 / 1.12; P1 0.82 / 1.03) |
| no-present | 62.5% → 56.0% → **62.5%** | +6.5 (22 / 9, z 2.3) | 0.0 (24 / 24) | 0.67 / 1.16 (P0 0.58 / 1.17; P1 0.78 / 1.03) |

- **#135 takes back the whole Phase 1 drop, and good doesn't lose net.** The discount on true sightings of the Demon costs less than the frames it stops, so the trace step wasn't needed.
  - **Against Phase 1**, at the first execution that differs, #135 hangs evil where Phase 1 hanged good in 36 games (bot) and 34 (no-present). The reverse happens in 14 and 13.
  - **Against Phase 0** the tilt runs the other way: 40 and 35 against 27 and 21, with wrongful hangs about +0.08 a game. That is the expected side effect, at a size that doesn't show in win rate.
- **Presenting is still worth about nothing:** bot vs no-present +2.0 (27 / 23, z 0.6).

| Vote shape (7 NPCs) | Votes/game | Unanimous but the nominee | Only the nominator | Evil nominations/game | …carried | …hanged |
|---|---|---|---|---|---|---|
| bot, P0 → P1 → #135 | 5.2 → 4.9 → 4.9 | 18.0 → 21.0 → 20.7% | 29.0 → 29.5 → 29.4% | 2.08 → 1.96 → 2.09 | 14.5 → 18.6 → 17.9% | 13.0 → 17.6 → 16.7% |
| no-present, P0 → P1 → #135 | 5.1 → 5.0 → 5.1 | 17.9 → 19.3 → 19.5% | 28.6 → 29.6 → 30.3% | 2.21 → 2.01 → 2.12 | 12.0 → 12.7 → 14.4% | 11.6 → 11.9 → 13.5% |

The guardrail holds. The bot's evil nominations still carry a little more often than in Phase 0 (about 4 points, within noise).

### Phase 2: the demon-type declaration

It can ship before the restructure, since today's model already mixes types by script share. The declaration sets the town's mix. "Before a declaration" naivety waits for the connections model.

**Built: PR #131, merged (main `9fad758`; golden unchanged).**
- `declare walker` / `declare hexer` at a meeting (and meeting buttons): its own action, once a day, offered only on scripts that deal both kinds. One-kind scripts start declared.
- It reaches every view and sets the demon mix (walker = no day demon, hexer = day demon only); every NPC re-reads its beliefs.
- Changing it costs 0.1 credibility with every NPC (`Trust.CRED_DECLARATION_CHANGE`, about one failed case), kept in the dawn target.
- Test check, 7 two-kind games to day 3: the declaration moves the town on the Demon in most, and the right kind puts 2–10 points more on the Demon than the wrong kind in 5 of 7.
- **The bot now declares (Phase 5, #137),** so a sweep can value it. #137 also fixed a cache bug that could keep a declaration from reaching movement scores.

### Phase 3: prototype data (Quill)

- Premises, challenges and the demon declaration added to the measurement harness. **Done in PR #125; the declaration is a stand-in that sets the town's mix.**
- **An interaction table:** each card alone, its partner alone and both together, on the same listener. It feeds the prototype and the bot. **Rerun on main `7404873`, with constructed challenges and cross-teller pairs; results below. 0.4 confirmed.**

### Phase 4: offline prototype (Lantern)

Replay existing logs and compute what listeners would believe under connections, with no gameplay change. **The spec, with measurable acceptance criteria, is below ("Phase 4 spec"); its review points are settled ("Decisions, Nov 10 evening"). Built and run: see "Results: Phase 4 prototype".** Acceptance criteria are agreed before the build:
- people a case didn't touch don't move;
- Hollis (Confessor) catches Kiran's lie unaided;
- the Day 4 case moves listeners toward Kiran, or leaves them where they were;
- vote shapes stay healthy;
- refresh cost is no higher than today.

### Phase 5: the bot builds cross-check cases

It picks pairs from the interaction table (Quill's ranking is under "Challenge sides"). No sweep of the new model means anything until this works.

**Built: PR #137, merged (main `645fa16`; golden unchanged, since the golden player is passive).**
- **Cross-check cases** (`Analyst._best_cross_pair`). The bot looks for two accepted cards that are stronger together than apart, and seeds its case with the best pair. Partners, from Quill's ranks 1, 2 and 5:
  - a group or pair reading naming the target, with a reading on another member of the group;
  - a night sighting of the target, with that night's Lamplighter count.

  A pair qualifies when its joint log-odds beat the two alone by 0.4 and beat the strongest single card. Challenges aren't used yet.
- **The declaration** (`Analyst.demon_type_odds`). The bot sums every possible world's weight with the town's mix set to Hexer, then to walker. It declares at a Bayes factor of 3, changes only at 10, and tries once a day.
- **A game bug, fixed:** `CaseEval`'s compile cache key left out the town's demon mix. An evaluation after a declaration could reuse movement scores compiled under the old mix, so in-game declarations may not have reached every NPC's movement reading. That may be part of why the declaration's effect looked inconsistent in tests. Codex also caught the bot's own belief cache ignoring the declaration; fixed.
- **Switches:** `--no-crosscheck` and `--no-declare` give back the earlier bot, for paired cells. Sweep records gain `cross_cases`, `declarations` and `declarations_right`.

**Measured** on 21 two-kind games at a day-3 meeting (`test_demon_declaration`'s setup, after the cache fix):

| | Walker games | Hexer games |
|---|---|---|
| Games | 9 | 12 |
| The bot's odds lean the true kind | 8 | 5 (plus one tie) |
| Would declare at a factor of 3: right / wrong | 3 / 0 | 1 / 2 |
| Town on the Demon, right declaration beats wrong | 4 of 9 | 11 of 12 |
| Mean gain, right over wrong declaration | +0.03 (one game carries it) | +0.07 |

- **The declaration helps against Hexers and does little against walkers.** Against walkers the sightings already carry the case; against Hexers it switches on the day evidence.
- **The bot is worst at spotting Hexers,** where declaring helps most. Both wrong calls at the bar are "walker" on a Hexer game. If the sweep shows them costing games, the first lever is a higher bar for "walker", or waiting until day 4.

**Paired cells (Tally, Nov 12).** Main `645fa16` plus sweep tooling for the switches and a forced demon (PR #138, tools only). 7 NPCs, seeds 100000–100199, same settings as the #135 cell. Runs: `43177054548` (dynamic scripts) and `43177065645` (Hexer forced: `--force-demon daykiller`, which keeps the walking Demon on the script).

| Cell | Good wins (95% CI) | Wrongful / evil exec per game | Cross-check cases / game | Declarations / game (right) |
|---|---|---|---|---|
| Dynamic: bot | 61.5% (55–68) | 0.70 / 1.16 | 0.14 | 0 |
| Dynamic: `_nocross` | 62.5% (56–69) | 0.70 / 1.16 | 0 | 0 |
| Dynamic: `_nodeclare` | 61.5%, identical to bot | 0.70 / 1.16 | 0.14 | 0 |
| Hexer forced: bot | 52.5% (46–59) | 0.85 / 1.10 | 0.12 | 0.74 (80 of 149) |
| Hexer forced: `_nodeclare` | 49.0% (42–56) | 0.92 / 1.09 | 0.13 | 0 |

- **Dynamic scripts never dealt both kinds on these seeds** (0 of 200), so the dynamic `_nodeclare` cell is the bot game for game. On dynamic scripts the declaration can only be tested with the demon forced.
- **Cross-check cases are rare and change almost nothing.** They're filed in 26 of 200 games (0.14 a game). Bot vs `_nocross` is −1.0, and only 2 games differ (0 / 2, z −1.4): 195 of 200 games are identical.
- **The declaration helps a little on Hexer games:** bot vs `_nodeclare` +3.5 (15 / 8, z 1.5), not significant. The bot declares in 142 of 200 games, and once in all but 7.
  - **When it calls Hexer (right):** 73 games, 59% against 52% without declaring (9 / 4).
  - **When it calls walker (wrong):** 62 games, 32% against 31% (5 / 4). These are hard games either way, and the wrong call costs almost nothing.
  - **7 games changed their call:** 29% against 14%.
- **The bot calls a Hexer right only 54% of the time** (80 of 149), barely above a coin. Every wrong call is "walker" on a Hexer game (69), as in the 21-game check, since every game in this cell is a Hexer game. A walker-forced cell would show whether it calls walkers right; dynamic scripts give no two-kind games to check.
- **In games where the bot declared,** the first differing execution against `_nodeclare`:
  - 80 games are identical.
  - Toward the bot: it hangs the Demon where `_nodeclare` hanged a good person or nobody in 12 games, and hangs nobody or an evil person where `_nodeclare` hanged someone good in 12.
  - Against the bot: it loses the Demon, to a good person or to nobody, in 11 games. It hangs a good person where `_nodeclare` hanged an evil one or nobody in 5.
- **Against the #135 bot cell** (information only, since #136 also changed play): −3.0, with 187 of 200 games identical (0 / 6, z −2.4). `_nocross` against #135 is 0 / 4, so #136 accounts for most of it, and cross-checks for the other 2.

| Vote shape (7 NPCs) | Votes/game | Unanimous but the nominee | Only the nominator | Evil nominations/game | …carried | …hanged |
|---|---|---|---|---|---|---|
| Dynamic: bot | 4.9 | 20.8% | 29.1% | 2.08 | 18.2% | 16.8% |
| Dynamic: `_nocross` | 4.9 | 20.7% | 28.9% | 2.10 | 18.4% | 16.9% |
| Hexer forced: bot | 5.7 | 18.9% | 32.8% | 2.19 | 16.6% | 14.6% |
| Hexer forced: `_nodeclare` | 5.6 | 19.2% | 32.2% | 2.17 | 18.5% | 17.1% |

**Reading:** neither switch moves win rate measurably. Cross-checks rarely fire; the declaration is worth about 3 points on Hexer games, and only when the call is right. The lever is the Hexer call: the bot spots a Hexer about half the time. Raising the bar for "walker" (or waiting until day 4) should cost little, since a wrong walker call loses almost nothing.

### Phase 6: in game behind a toggle

Golden re-baseline, then a sweep against Phase 0.

**Spec written (Lantern, Nov 12): see "Phase 6 spec" below. Michael accepted all four of its recommendations the same day. Step 1 is merged as #141 (see "Results: Phase 6 step 1"). Step 2 is merged as #144 (see "Results: Phase 6 step 2"). Step 3 is open as PR #145 (see "Results: Phase 6 step 3").**

## Results: silent-bot cells (Phase 0, Tally)

Nov 10 · branch `claude/silent-bot-cells` (main `400ce06` plus the two modes; tools only, PR #127). M4 bot, dynamic scripts. 7 NPCs on seeds 100000–100199; 10 NPCs on seeds 100000–100099. Every comparison is paired on the same seeds. Sweep runs `42891633471` and `42891646162`; the no-present reruns are `42908805272` and `42908816739`.

**Cells:**
- **bot:** today's M4 bot.
- **no-present:** files a case each meeting, so its nominations rest on one (M2a), but never presents a case. That means no meeting presentation, no "convince" and no "tell". It still asks people about traces, and still presses and accuses at the podium.
- **no-present, no-nominate:** the first no-present run had a bug: skipping the presentation also skipped the nomination (0.01 player nominations a game). It's kept, because it isolates nominating.
- **present-and-vote:** no vigils, wards, scene searches or protection offers.
- **passive:** the floor.

### Win rates and executions (7 NPCs, 200 seeds)

| Cell | Good wins (95% CI) | Wrongful exec/game | Evil exec/game | Player nominations/game |
|---|---|---|---|---|
| bot | 59.5% (53–66) | 0.62 | 1.12 | 1.56 |
| no-present | 62.5% (56–69) | 0.58 | 1.17 | 1.63 |
| no-present, no-nominate | 53.0% (46–60) | 0.73 | 1.09 | 0.01 |
| present-and-vote | 49.0% (42–56) | 0.76 | 0.99 | 1.49 |
| passive | 39.5% (33–46) | 0.83 | 0.87 | 0 |

### Paired comparisons (7 NPCs)

| Comparison | What it isolates | Difference | Discordant (A only / B only) | z |
|---|---|---|---|---|
| bot vs no-present | presenting | **−3.0** | 19 / 25 | −0.9 |
| no-present vs no-present, no-nominate | the player's nominations | **+9.5** | 29 / 10 | 3.0 |
| bot vs present-and-vote | vigils, wards, searches | **+10.5** | 36 / 15 | 2.9 |
| no-nominate vs passive | everything else: votes, podium press, traces, talk | +13.5 | 53 / 26 | 3.0 |
| bot vs passive | all of it | +20.0 | 65 / 25 | 4.2 |

### 10 NPCs (100 seeds)

| Cell | Good wins | Wrongful / evil exec per game |
|---|---|---|
| bot | 56% | 1.04 / 1.76 |
| no-present | 56% | 1.13 / 1.65 |
| no-present, no-nominate | 53% | 1.16 / 1.54 |

Bot vs no-present: 0 (16 / 16). No-present vs no-nominate: +3 (18 / 15, z 0.5).

### Vote shapes

| Cell | Votes/game | Unanimous but the nominee | Only the nominator voted yes | Evil nominations/game | Evil nominations carried | …hanged |
|---|---|---|---|---|---|---|
| 7 bot | 5.2 | 18.0% | 29.0% | 2.08 | 14.5% | 13.0% |
| 7 no-present | 5.1 | 17.9% | 28.6% | 2.21 | 12.0% | 11.6% |
| 7 no-present, no-nominate | 5.3 | 19.8% | 30.2% | 2.63 | 25.3% | 20.9% |
| 7 present-and-vote | 5.5 | 18.0% | 30.9% | 2.04 | 17.2% | 14.7% |
| 7 passive | 6.3 | 18.6% | 39.2% | 2.94 | 26.8% | 24.6% |
| 10 bot | 9.7 | 14.2% | 25.4% | 3.94 | 10.7% | 10.7% |
| 10 no-present | 9.3 | 13.5% | 23.2% | 4.15 | 17.1% | 15.7% |
| 10 no-present, no-nominate | 9.3 | 12.8% | 21.9% | 4.77 | 27.7% | 20.5% |

Nearly all evil nominations land on good people (2.00 of 2.08 a game in the 7 bot cell).

### Reading

- **Presenting cases adds nothing measurable to winning today.** At 7 NPCs, the bot without presenting is 3 points *ahead* (noise, z −0.9). At 10 NPCs it's level. A 200-seed paired test would show an effect of about 6–7 points, so presenting is worth less than that, and plausibly zero. This supports Michael's suspicion: NPCs already reach on their own what the bot's cases say.
- **The bot's edge is its own actions:**
  - **Nominations:** about +9.5 at 7 NPCs, z 3.0. The 10-NPC sample (+3) is too small to say.
  - **Vigils, wards and searches:** about +10.5 at 7 NPCs, z 2.9.
  - **The rest:** about +13.5 over passive comes from the bot's votes, podium press, accusations, trace questions and talk, none of which this run separates.

  Each of these is ±7 points or so on its own. They aren't strictly additive either, since the cells overlap.
- **How nominating helps:** it crowds out evil's. With the bot nominating, evil makes fewer nominations (2.1 against 2.6–2.9 a game), and fewer of them carry (12–15% against 25–27%). Wrongful hangs fall from 0.73–0.83 to about 0.6 a game.
- **The guardrail is healthy today.** Unanimous-but-the-nominee votes sit at 13–20% in every cell, with or without the bot. "Only the nominator voted yes" is lower when the bot plays (22–31%) than passive (39%), because the bot adds a yes vote.
- **For the connections design:** the target is that presenting should be worth something. Today it measures as about nothing. The no-present cell is now the reference for Phase 5 and Phase 6 to beat.

**Noise:** one cell's win rate is ±7 points at 200 seeds and ±10 at 100. The paired z values above are the reliable part. I'd trust the presenting null, and the sizes of the nomination and vigil effects, only to within about 5 points.

## Results: the read-everything gap, fix 3 and the interaction table (Quill)

Nov 10 · tools in PR #125. The interaction table below is on main `7404873` (Phase 1 in). P(evil) and P(Demon) are the shared model's posterior.

### Read-everything gap (Phase 0)

29 good listeners. Human playtest 12926 was replayed at its own build (`75b4c8e`), where its votes match; on main it diverges at the first command. The passive seeds are 900 and 901 (7 NPCs) and 902 (10 NPCs).

| States | Listeners | Cards read / held | Mean gap, P(evil) | Mean largest gap | Worst | Mean gap, P(Demon) | Separation, bounded → all |
|---|---|---|---|---|---|---|---|
| 12926 day 2 | 6 | 61 / 61 | 0 | 0 | 0 | 0 | +0.23 → +0.23 |
| 12926 days 3–4 | 10 | 111 / 356 | 0.13 | 0.33 | 0.58: Edda on Fenwick (good), 72% → 14% | 0.06 (worst 0.47) | **+0.08 → +0.27** |
| Passive, days 3–4 | 13 | 247 / 293 | 0.02 | 0.08 | 0.68: Agnes on Isolde (good), 69% → 1%, seed 902 | 0.01 (worst 0.31) | +0.25 → +0.29 |

Separation is the mean P(evil) on the truly evil minus the mean on the truly good.

- **The gap is a human-game problem.** In passive games listeners read most of what they hold. In 12926 from day 3 they read 7–15 of 29–44 cards, and 8 of 10 have a gap over 10 points. **Reading everything reads the town better**, not worse: separation goes from +0.08 to +0.27. The truly evil Lian and Isolde rise (Fenwick on Lian 71% → 99%; Dorian on Isolde 45% → 97%), and Edda clears the good Fenwick. Not every move is right: Nisha's worst gap raises the good Hollis from 38% to 80%.
- **Readings are what gets left out.** Adding the unread readings back alone closes 68–99% of the largest gap for 7 of the 10 listeners. By gift: Surveyor (Nisha, Edda and Agnes, day 3), Dowser (Edda and Dorian, day 4), Archivist, and Registrar (Fenwick, day 3). Movement cards close most of the rest: sightings (Agnes; seed 902) and location cards (Hollis). For Dorian on day 3, no kind closes the gap alone; it takes a combination. Hollis, the most insightful, has the smallest gaps (about 0.05).

### Fix 3: own home alibi (PR #124, merged)

The hard rule predated the repo history and matched the case convention that accepted cards are facts. Read as deliberate for cases, an oversight for beliefs. Now an evil subject's own alibi is 0.7 if out and 0.9 if home; good subjects, the listener and witnesses stay hard. Michael accepted the lower watcher rise; golden `baseline_a03bf72`.

### Interaction table (Phase 3, on main)

The rows follow spec section 11: one per pair, listener and person, with P(evil) and P(Demon) for no cards, A alone, B alone and both. "Interaction" is the largest |joint − A − B + none| over people, in log-odds.

**Sample:**
- 7 NPCs on seeds 1–10, dynamic and with the Hexer forced. Cross-checks and challenges ran on seeds 1–24 with the roles forced onto the script.
- 10 NPCs on seeds 1–6.
- Trust 0.4 and 0.8.

**Movement pairs, rerun after #124:**

| Pair | 7 NPCs: pairs, median, ≥ 0.4 | 10 NPCs: pairs, median, ≥ 0.4 | On the subject |
|---|---|---|---|
| Sighting + home alibi | 36, **1.44**, 64% | 36, 1.62, 50% | **The cancel is gone: the clash now convicts.** Evil subjects: none 53%, sighting 71%, alibi 54%, both 82% (before #124: the alibi offset the sighting, −0.54) |
| … with the subject's claim as context | 38, 1.25, 79% | 36, 1.59, 67% | Evil 49% → 81% |
| Sighting + subject's claim | 32, 0.51, 59% | 36, 0.35, 44% | +0.26 if evil, −0.53 if good: the claim explains the outing |
| Lamplighter count + that night's sighting | 20, 0.51, 65% | 18, 0.02, 17% | |
| Augur reading + sighting | 10, 0.05, 10% | 4, 0.02, 0% | |

- **Caveat on good subjects:** the alibi is constructed for whoever was sighted. Good subjects here are mostly night-walking gifts (Lamplighter, Surveyor, Archivist), who in play would claim their gift rather than say "home". The rows still show them rising 35% → 70%.
- **Declarations** (Hexer forced, 7 NPCs). Each cell is sighting + alibi / Lamplighter + sighting / own reading + heard reading:
  - undeclared: 2.08 / 0.79 / 0.12;
  - "Hexer" declared: 3.37 / 2.12 / 0.06;
  - "Walker" declared: 1.45 / 0.27 / 0.13.

**Readings:**

| Pair | 7 NPCs: pairs, median, ≥ 0.2 / ≥ 0.4 / ≥ 0.8 | 10 NPCs: pairs, median, ≥ 0.4 | Notes |
|---|---|---|---|
| Own reading + heard reading (core test) | 116, 0.13, 45 / 28 / 10% | 44, 0.07, 9% | Threshold, below |
| Own reading + heard sighting | 26, 0.06, 27 / 15 / 4% | 22, 0.04, 0% | |
| Reading + its teller's claim | 84, 0.04, 0 / 0 / 0% | 36, 0.04, 0% | Still additive (review 1 stands) |
| Cross-teller readings sharing a name | 48, 0.14, 40 / 21 / 4% | 38, 0.19, 8% | |
| One teller's two readings (low priority) | 80, 0.08, 36 / 19 / 6% | 36, 0.07, 11% | |

**Cross-teller pairs a player would present** (the Confessor readings are constructed: true content, told by a good NPC who claims Confessor):

| Pair | 7 NPCs: pairs, median, ≥ 0.4 | 10 NPCs: pairs, median, ≥ 0.4 | On the uncleared accused |
|---|---|---|---|
| Dowser count (1+) + a Confessor reading clearing one of the group | 14, **0.56**, 71% | 14, 0.24, 21% | +0.27 / +0.18 |
| Archivist pair + a Confessor reading clearing one of the two | 24, 0.16, 0% | 10, 0.21, 20% | −0.02 / +0.21. Weaker than the logic suggests; explained under "Challenge sides" |
| Psychologist pair reading + its two statements | 54, 0.03, 0% | 16, 0.04, 0% | **Today's model doesn't connect them at all.** The structural unit has to be built, not inherited |

**Challenges with constructed contradicting grounds** (first pass; superseded by "Challenge sides" below). 34 cases, 32 of them honest readings against false grounds. At trust 0.8 in the grounds' teller the challenge was "supported" 88–91% of the time and the reading's reliability fell to × 0.67; at 0.4 the grounds fall below the 0.4 witness-quality bar and nothing happens.

**Core threshold: 0.4 confirmed.**
- Over all 160 own-reading pairs, the deciles are 0, 0, .03, .05, .06, .11, .15, .28, .44, .60.
- The distribution has two clusters:
  - 94 pairs below 0.15;
  - a thin band of 29 from 0.15 to 0.4;
  - a second cluster of 37 from 0.4 up.
- 0.4 is where that second cluster starts. 28% of 7-NPC pairs join (36% at trust 0.8).
- **The watch-point is town size:** at 10 NPCs interactions roughly halve, and only 9% join. If 10-NPC cores come out too thin in the prototype, 0.3 is the fallback, adding about 10 of the 160 pairs.

### Challenge sides: diagnosis and a proposed fix (Quill, Nov 11)

PR #132 (`claude/challenge-contest`); tools plus one rule in `reading_challenges.gd`. Bailiff owns merging and re-baselining.

**Diagnosis**
- **The clash is taken as proof against the reading.** In `assess`, the clash test asks whether the grounds alone are possible and the grounds plus the reading are not. It treats the grounds as true. Its strength is the lowest witness quality among the grounds' tellers, so the discount is 1 − 0.65 × that.
- **Trust in the reading's teller never enters the discount.** It appears only in the lying cause agreement (× (1 − its quality)). Misled and failed gift ignore it entirely.
- **The evil premise does the work on the verdict,** not the challenge. A lying challenge leaves reliability alone (fix 2). In most trust cells it adds 0 to +0.2 log-odds on the teller beyond the unchallenged evil premise. Its agreement reaches the 0.6 floor in under 20% of cases.
- **My last table overstated the flaw.** Its "supported" flag is set by the graded test for any positive effect, however small. Measured by an actual discount (× 0.9 or less; for lying, agreement 0.6+), the flaw is narrower: the discount depends on the grounds' trust alone.
- **Many clashes aren't contradictions.** A Seer "yes" can be a Red Herring, and with a Poisoner on the script the Confessor may be poisoned. So the floor often never fires on true grounds.

**Sample.** Constructed evil bluffs (an Archivist pair and a Seer "yes", each naming two living good people) against true Confessor clears: 37 cases. Honest Archivist, Dowser and Seer readings against false clears: 14. 7 NPCs on seeds 1–24, 10 NPCs on seeds 1–8. Two listener settings:
- **fresh,** with a trust grid of 0.4 and 0.8 on each side;
- **natural,** where the listener keeps its own state and trust.

**Trust already points the right way.** With natural trust, listeners rate a bluffer's witness quality 0.39 against 0.68 for the grounds. An honest reader gets 0.73 against 0.65. The grounds are more credible in 86% of true-grounds cases and 14% of false ones.

**Natural trust (true / false grounds):**

| Rule | Lying lands | Misled lands | Misled × | Failed gift lands | False grounds backfire | True grounds backfire |
|---|---|---|---|---|---|---|
| Old | 19% / 7% | 30% / **36%** | 0.88 / 0.86 | 43% / **50%** | 21–43% | 0–3% |
| **Contest (proposed)** | 19% / 7% | **22% / 14%** | 0.94 / 0.93 | **35% / 29%** | 21–43% | 5–8% |
| Posterior | 19% / 7% | 24% / 29% | 0.87 / 0.87 | 38% / 43% | 21–43% | 5–8% |

- **Contest:** in a clash, the floor's strength is (q_grounds − q_reader) / (1 − q_reader × q_grounds). That's the chance the reading is the broken side, minus the chance the grounds are. At zero or below, the clash supports nothing, and below zero it backfires.
- **Posterior:** when the grounds are the more credible side, it discounts by (1 − q_reader) / (1 − q_reader × q_grounds) instead.
- **Fresh listeners, 7 NPCs.** Under the old rule, misled lands 39% on true grounds whenever grounds trust is 0.8, whatever the reader's trust. Under contest it's 39% when the reader is trusted less, 0% at equal trust, and false grounds land 11% at equal trust.
- **Proposal: contest.** It is the only rule under which true grounds land more often than false in every mode. False grounds still backfire 21–43%, and fix 2 holds.
- **Not met: "true grounds mostly supported."** No rule gets past 44%. The rest needs the graded test to carry real weight when a clash can be explained by poisoning or registration: today its effect is about 0 in these cases. That's the next lever, and it isn't built.
- **Tests:** the five challenge, premise and alibi suites pass on contest. The full suite passes (138/138), and golden is identical on all five seeds (passive games raise no challenges).

**Leftovers from Phase 3**
- **Traces against profiles alone** (7 NPCs, seeds 1–16, presented). A trace alone moves suspicion of the Demon by +0.012, profiles alone by −0.001, and both by +0.014. The interaction is about zero (median 0; 31% of pairs over +0.02), so presented traces barely move anyone today, with or without profiles.
- **Archivist pair plus a clearing reading** (7 NPCs): the uncleared accused goes 51% with nothing, 65% with the pair, 56% with the clear, 69% with both. The cleared person only falls from 35% to 19%. "The other is the minion" needs three uncertain links at once:
  - the Archivist's teller is good;
  - the reading is reliable at that trust (0.5 + 0.5 × trust);
  - the clear is reliable.

  At trust 0.4 their product, about 0.3, matches what's measured. Not a bug: when the other person is already firmly cleared, the pair alone takes the accused from 42% to 90% (one 10-NPC case).

**For Phase 5: cross-teller pairs ranked.** Columns: median interaction; share at 0.4 or more; how often the largest move is in the right direction; joint separation (evil minus good).

| Rank | Pair | Interaction | ≥ 0.4 | Right direction | Joint separation |
|---|---|---|---|---|---|
| 1 | Dowser count + Confessor clearing one of the group | 0.36 | 46% | 82% | **+0.84** |
| 2 | Lamplighter count + that night's sighting | 0.28 | 42% | 100% | +0.38 (7 NPCs; about 0 at 10) |
| 3 | Sighting + the subject's claimed gift (a defence) | 0.47 | 51% | 82% | +0.22 |
| 4 | Archivist pair + a clearing reading | 0.17 | 6% | 50% | +0.44 (mostly solo value) |
| 5 | Two readings sharing a name | 0.16 | 15% | 34% | +0.30 |

Not for the bot yet:
- **Sighting + home alibi:** the largest interaction (1.44), but only 44% in the right direction in my sample. Constructed alibis convict good night-walkers, the mechanism suspected behind the Phase 1 drop.
- **Psychologist reading + its statements** (0.03): the unit has to be built first.
- **Augur reading + sighting** (0.04).

### Challenges that are right but rarely land: the graded test (Quill, Nov 12)

PR #142 (`claude/challenge-graded`), tools plus one rule. Michael approved the proposal on Nov 12; Bailiff merges.

**Why the graded test added about nothing**
- **Role-checked gifts were invisible to it.** The graded test asks how often a reading's content holds before and after the rest of the evidence (`q`, `f`), and reads that from the report table. Gifts whose content the role constraints check instead came out as "holds in every world", so `q = f = 1` and the test could never see a contradiction. They are Archivist, Clerk, Executor, Gravedigger, Registrar, Monitor, Martyr, Night Watch, Warden and Veteran (`CaseEval.ROLE_CONTENT_FIXED`).
- **Red Herring and registration:** the Seer has its own holds table, in which a Red Herring is how a false "yes" happens. So its lying and failed-gift challenges were already graded normally (effect about 0.5). A Seer "misled" challenge is skipped on purpose: a Red Herring or Marked registration misleads an honest gift without breaking it, so it never discounts the reading. That stays.
- **Poisoned Confessor:** worlds where the Confessor was poisoned stay possible and soften the clash, but don't erase it. Where the test runs, it sees the clash.

**Fix (first build):** for those gifts, `Solver.reading_holds_table` also asks the role constraints (`Roles.fits_table`) whether the reading fits each world. `ReadingChallenges.graded_rule` is "roles" in play; "table" keeps the old mask for the harness. **Replaced by a content-only check after Codex's review (below).**

**Measured (first build)** on the same harness, on `9e69144`. The true sample is evil bluffs (an Archivist pair or a Seer "yes" naming two good people) against true Confessor clears. The false sample is honest readings against false clears. "Lands" means a real discount (× 0.9 or less); for lying, agreement 0.6+. Cells are true / false grounds; n is cases per side.

| Listeners | n (true / false) | Lying lands | Misled lands | Failed gift lands | False backfire |
|---|---|---|---|---|---|
| Natural, 7 NPCs: before → after | 20 / 8 | 20% → **45%** / 12% → 12% | 20% → 25% / 25% → 25% | 25% → 30% / 38% → 38% | 29% → 29% |
| Natural, 10 NPCs | 15 / 3 | 20% → **40%** / 33% → 33% | 13% → 13% / 33% → 33% | 33% → 33% / 33% → 33% | 33% → 33% |
| Fresh grid, 7 NPCs | 20 / 8 | 5% → 10% / 0% → 0% | 10% → 10% / 22% → 25% | 19% → 19% / 22% → 25% | 19% → 19% |
| Fresh grid, 10 NPCs | 15 / 3 | 13% → 15% / 8% → 8% | 13% → 13% / 75% → 75% | 17% → 17% / 75% → 75% | 0% → 0% |

- **By gift (natural):** a lying challenge against a bluffed Archivist reading lands 12% → 59%, and still 0% against an honest one. Seer and Dowser are unchanged, since they were already graded.
- **Misled and failed gift barely move, and that's right here.** Every true-grounds case in this sample is a deliberate lie. Once the clash is visible, the test blames it on the evil reader, so "honest mistake" and "failed gift" correctly carry little. A sample of honest mistakes (a poisoned Archivist, a Marked registration) would be needed to test those two.
- **Fresh listeners gain little:** with no history, the listener has nothing to weigh the clash against.
- **Not fixed:** at 10 NPCs, false grounds land 33% (natural) and 75% (fresh) for misled and failed gift, as before. The false sample is 3 cases; it needs more seeds before anyone tunes on it.
- **Checks:** the five challenge, premise and alibi suites pass. With main `559a201` merged in, the full suite passes (145/145) and golden is identical on all five seeds. The 7-NPC natural run on the merged branch is identical to the one above. The harness uses readings told directly, not relayed, so #140 doesn't touch it.

**Honest mistakes (Nov 12 evening).** Harness `--construct-mistakes` (pushed to the #142 branch): a *good* teller tells the same false readings (an Archivist pair or a Seer "yes" naming two good people), against true Confessor clears. That is what a poisoned Archivist or a misregistered Seer produces, so "misled" or "failed gift" is the right challenge. Measured at day 2, so enough of the accused are alive; same seeds as above. A Seer "misled" challenge never discounts, so it counts by agreement 0.6+. Cells are bluff / mistake / honest (false grounds), roles rule, with the table rule in brackets.

| Listeners | n | Lying lands | Misled lands | Failed gift lands | Backfire |
|---|---|---|---|---|---|
| Natural, 7 NPCs | 44 / 65 / 15 | 50 / **57** / 0% (25 / 20 / 0) | 25 / **8** / 33% (18 / 5 / 27) | 32 / **9** / 53% (25 / 6 / 47) | 14 / 22 / 13% (13 / 14 / 20) |
| Natural, 10 NPCs | 32 / 33 / 11 | 34 / 21 / 9% (19 / 9 / 0) | 12 / 12 / 18% (12 / 9 / 18) | 19 / 30 / 27% (19 / 27 / 27) | 0 / 9 / 21% (3 / 4 / 24) |
| Fresh grid, 7 NPCs | 44 / 65 / 15 | 14 / 28 / 0% (14 / 3 / 0) | 19 / 3 / 23% (19 / 3 / 13) | 20 / 3 / 35% (20 / 3 / 25) | 4 / 37 / 7% (2 / 17 / 7) |
| Fresh grid, 10 NPCs | 32 / 33 / 11 | 9 / 12 / 0% (9 / 6 / 0) | 13 / 5 / 34% (unchanged) | 15 / 14 / 34% (unchanged) | 1 / 8 / 0% (unchanged) |

- **Misled and failed gift still rarely land on honest mistakes** (3–12%; failed gift 30% at natural 10 NPCs, mostly the Seer's). The fix makes the clash visible, and the graded test then blames it on lying: a lying challenge against an honestly mistaken teller lands 57%, as often as against a real bluffer (50%).
- **Why:** to the listener the two cases are the same cards. The clash says the reading is wrong, not why, and the test splits it by the chance the teller is evil, which is the same for both. Evil is the likelier explanation in the model's worlds, so lying takes most of it. A challenge rule alone can't separate them; it would need evidence that does, such as the teller's history or signs of a poisoning.
- **Caveat:** the mistakes are constructed. The teller isn't really poisoned, so the worlds carry none of the evidence a real poisoning leaves. A real poisoned Archivist could score differently.
- **By gift (natural, 7 NPCs):** Archivist misled and failed gift 12%; Seer failed gift 6% (47% at 10 NPCs).
- **False grounds, on this day-2 sample, land a little more under roles** for misled and failed gift (+6 at natural 7 NPCs, +10 fresh), and lying at natural 10 (0 → 9%). Each is one case. The day-3 sample above didn't move. Small, but the wrong direction, so reported rather than tuned.
- **For Michael:** if a lying challenge landing on a good but mistaken teller counts as a false challenge, #142 raises that too (20% → 57% at natural 7 NPCs). The backfire rise on mistakes (fresh 7 NPCs 17% → 37%) isn't traced.

**Codex's review of #142 (Bailiff, Nov 12), and the content-only fix (Quill, Nov 12 late).** The first build ran the role constraints with `bluffs = false`. That rules out every world where the reader is evil and gives the reader their claimed role, so `q` and `f` measured whether the reader could *honestly* have given the reading, not whether its content holds. Since `graded_challenge` already weighs the reader's goodness in `r`, evidence against the reader counted twice.
- **Fix (pushed to #142, `81a8d0a`):** the mask is content-only. A per-card `FlagContentOnly` in `RoleConstraints.cs` skips the source's alignment, the source's role and any relayer; everything the card asserts is still checked. Only `Solver.reading_holds_table` sets it, so puzzles and other callers are unchanged. `graded_rule = "roles_source"` keeps the first build's mask for the harness. Regression check: an Archivist pair now holds in all 1,302 worlds where the reader is evil and a Minion is in the pair (0 before), and in no world without one.
- **Re-measured,** same harness and seeds. Lying lands on true grounds (evil bluffs); old check → first build → content-only:

  | Listeners | Lying lands, true grounds | False grounds |
  |---|---|---|
  | Natural, 7 NPCs | 20% → 45% → **40%** | 12%, unchanged |
  | Natural, 10 NPCs | 20% → 40% → **27%** | 33%, unchanged |
  | Fresh grid, 7 NPCs | 5% → 10% → 8% | 0% |
  | Fresh grid, 10 NPCs | 13% → 15% → 15% | 8% |

  Bluffed Archivist readings at natural 7 NPCs go 0% → 50% → 40%. Misled, failed gift and backfire are unchanged, except fresh 7 NPCs, where misled and failed gift on false grounds go 25% → 31% (2 of 32 rows).
- **The case Codex raised** (`--suspect-reader`): an honest Archivist pair from a good reader whom an evil Seer bluff has also accused (P(evil) 0.39 before the challenge), challenged as lying on false Confessor clears. Natural listeners, 10 NPCs, 19 seeds; 7 NPCs leaves too few living people for it.

  | Lying lands | Old check | First build | Content-only |
  |---|---|---|---|
  | Honest reader under suspicion (n 26) | 19% | **54%** | 35% |
  | Evil bluffs, true grounds (n 58) | 31% | 53% | 45% |
  | Other honest readings (n 12) | 0% | 0% | 0% |

  - **The first build made no difference between an honest suspected reader and a real bluffer** (54% against 53%). Content-only brings back a 10-point gap.
  - **An honest suspected reader still loses more often than under the old check** (35% against 19%). The remainder is the test now seeing the clash with the grounds, which here are false; the old check couldn't see any clash for these gifts. It isn't a second count of the reader. **For Michael:** whether that is acceptable.
- **Not re-measured:** the honest-mistake sample above ran on the first build, so its 57% lying figure on mistaken tellers may be partly the double count.
- **Checks:** the five challenge, premise and alibi suites pass, the full suite passes (145/145), and golden is identical to `baseline_6a22cac` on all five seeds. Codex's comment is answered on the PR.

**Merged (Bailiff, Nov 12 late; PR #142, main `437e29e`; golden unchanged).**
- **Michael's call on the 35%:** merge as it is. "The player should be able to make that mistake and have it have a real cost." A lying challenge against an honest reader who already looks suspicious can land.
- **Codex's last finding, fixed at merge:** a Marked good person registers as evil to an honest Gravedigger, Executor or Martyr. The content-only mask still counted those readings as true, which would have made a correct "misled" challenge hard to land. With `FlagContentOnly`, the kernel now skips the three Marked registration exceptions; role fits elsewhere keep them. Check: a Gravedigger's Poisoner read of a hanged good Marked person held in 252 of 252 such worlds before, 0 now, and holds exactly where the hanged person was a Minion.

## Results: Phase 4 prototype (Lantern)

Nov 10 evening · PR #129, tools only (`tools/connections_prototype.gd`, `tools/connections_prototype_summary.py`), built on main `7404873`. **Five of the seven criteria pass; 1 and 5 fail. Nothing was tuned.** Threshold 0.4 unless stated.

**Logs:**
- **12926** (human, 10 NPCs), replayed at its own build `75b4c8e`. A two-demon script, so it runs undeclared: per-night units, Hexer factor off. Eleven votes. Three cases were presented publicly: #81 (Lian), #152 (Kiran, day 4) and #178 (Kiran, day 5). "#87 Nisha is the Demon" was filed but never presented in the log.
- **Passive 900** (7 NPCs) and **902** (10 NPCs), generated on `7404873`. Single-demon scripts, so "Walker" counts as declared. Seven votes each. No player cases; NPC nominators' cited cards are the stored cases.

**Checks on the tool:**
- Judging one card with the whole view behind it, and alone, gives identical results. The judge sees only the set it's given.
- On the passive seeds, the judge on every held card matches today's read-everything posterior exactly.
- Every vote tally in all three replays matches its log.

### Against each criterion

| # | Criterion | Result | Numbers |
|---|---|---|---|
| 1 | People a case didn't touch move 3 points or less | **Fails** | 13 listener-presentations. Largest move 38 points (Edda on Lian, #178); 4 of 13 over 3 points. With no stored case dropped: largest 8 points, 2 of 13 over |
| 2 | Hollis catches Kiran's lie unaided | Passes, with a note | The reading joins his core on day 4, once he hears it firsthand, not at that day's dawn. Before the player's case he is at 80% (today: 69%). At dawn on day 5 it is in his core at every threshold, and he is at 63% |
| 3 | The Day 4 case doesn't backfire | Passes | Kiran rises for all four: Fenwick 53% → 62%, Hollis 80% → 85%, Edda 27% → 41%, Dorian 60% → 71%. Today two fell, by 24 and 9 points |
| 4 | Vote shapes no worse than today (+1) | Passes | Identical counts to today in all three logs. Individual good votes that flip: 4 of 45 (12926), 1 of 12 (900), 3 of 36 (902). One outcome changes (below) |
| 5 | Refresh cost at or below today's | **Fails** uncached; passes cached | 12926 from day 3, median / 90th percentile: today 70 / 237 ms; prototype with nothing cached 397 / 754 ms; prototype with solo values and core tests cached 34 / 58 ms. Seed 902: 32 / 52, 335 / 446 and 1 / 1 ms |
| 6 | Nothing moves without a reason | Passes | Recomputing at a dawn is identical in every case; so is presenting a case twice |
| 7 | Largest set judged together is 50% of held cards or less | Passes | 12926: median 22%, largest 48%. Seeds 900 and 902: 42% (the movement connection) |

### Why 1 fails

Two causes, in order of size.

1. **The cap of two stored cases is the new view swap.** A third case pushes the oldest out, and the people that old case concerned move.
   - #152 pushed out "Isolde nominates Fenwick" for Edda and Dorian: Edda on Lian 71% → 53%, Dorian on Nisha 55% → 67%.
   - #178 pushed out "Kiran nominates Fenwick": Edda on Lian 93% → 55%, Dorian on Lian 64% → 28%.
   - With nothing dropped, cases made of readings (#81, #152) move untouched people by 2.5 points at most. That remainder is the common shift that keeps the evil count, and it is the same for everyone.
2. **A trace is read against every profile card the listener holds.** #178 brought three traces and three profile cards. They move whoever's profile fits, named in the case or not: Nisha by 4.5 points (Edda) and 8 points (Dorian).

**Options, none applied:**
- drop the cap, or let an old case fade instead of vanishing;
- count people whose profiles a trace matches as touched;
- accept criterion 1 as "no more than the evil-count shift" for reading-only cases.

### Why 5 fails

A refresh with nothing cached makes 32 judgements at the median (65 at the 90th percentile) where today makes one large pass. Each is small, but together they cost about five times today's refresh from day 3 in 12926, and ten times in seed 902.

With solo values and core tests cached, only the joint sets are re-judged, and that is under today's cost. **Caveat:** those caches hold only while the listener's standing suspicion, its trust in tellers and the public record are unchanged. I haven't measured how often that is true within a day.

### Thresholds (for Quill's rerun)

| | 0.2 | 0.4 | 0.8 |
|---|---|---|---|
| Candidates that join, 12926 / 900 / 902 | 14% / 18% / 4% | 6% / 9% / 4% | 3% / 0% / 4% |
| Joined members per listener from day 3, median (most), 12926 | 3 (10) | 0 (7) | 0 (4) |
| Listeners from day 3 with at least one joined card, 12926 / 900 / 902 | 7 of 13 / 2 of 3 / 1 of 5 | 6 of 13 / 2 of 3 / 1 of 5 | 4 of 13 / 0 of 3 / 1 of 5 |
| Criterion 1: over 3 points, as built / nothing dropped | 3 / 2 of 13 | 4 / 2 of 13 | 5 / 3 of 13 |
| Criterion 2: Hollis on Kiran before the Day 4 case | 87% | 80% | 80% |
| Criterion 3: smallest rise on Kiran from #152 | +1 (Hollis) | +5 (Hollis) | +5 (Hollis) |
| Criterion 4: good votes flipped, 12926 | 3 of 45 | 4 of 45 | 4 of 45 |
| Criterion 7: largest set, median (most), 12926 | 28% (66%) | 22% (48%) | 22% (35%) |

**Cores are thin at 10 NPCs,** as Quill expected. At 0.4 the median listener from day 3 has no joined card, in both 10-NPC logs. At 0.2 criterion 7's worst case goes over 50%.

### Other things the run showed

- **How well each model tells evil from good** (mean chance on the truly evil minus the truly good):

  | | Today | Read everything | Prototype |
  |---|---|---|---|
  | 12926, day 3 | 0.23 | 0.34 | 0.21 |
  | 12926, day 4 | 0.23 | 0.49 | 0.36 |
  | Seed 902, day 3 | 0.44 | 0.51 | 0.36 |

  In the human game the prototype reads the town better than today's bounded view by day 4, and worse than reading everything. In the passive game it reads worse than today, which is the intent: less is connected without a player.
- **One vote outcome changes.** Day 4 on Isolde (the Scion): Hollis's chance falls from 62% to 50%, he votes no, and four yes votes become three of the four needed. An evil nominee comes off the block.
- **#81 "Lian is evil" moves nobody on Lian** (under 0.5 points for all six listeners). Its two Dowser readings were already held and barely interact. Today four of six fell.
- **The largest single case effect was an evil nominator's.** "Kiran nominates Fenwick" (four cited cards; Kiran is the Demon) shifted Edda's beliefs by up to 2.3 in log-odds. This is the evil-herding risk, on a listener with no joined cards.
- **Some listeners have no seed.** A Night Watch's and a Lamplighter's readings are movement cards, so they seed nothing: Fenwick on days 3 and 4 of 12926, and one listener in each passive seed from day 3. "Every NPC has a seed" doesn't hold for them.
- **#178 lowers Hollis on Kiran in two of its four versions** (by 4 points with nothing dropped; 71% → 64% when presented again). Not investigated.

### Build decisions that weren't in the spec

1. **The core is also rebuilt when the listener's own readings change,** not only at dawn. An own reading arriving is new firsthand knowledge, and every held card needs testing against it.
2. **Votes are converted by difference:** today's logged vote total plus today's belief-to-suspicion scale times (prototype chance − today's chance) on the nominee.
3. **The "without this case" side** uses the case's cards as the listener held them before the presentation.
4. **Not modelled:** "misled" and "failed gift" challenges (none in these logs), and the reading challenges NPC defences leave in a listener's ledger.
5. **Not run:** 12926 with "Hexer" declared. There's no switch for the town's mix at `75b4c8e`.
6. **12926 runs on its own build,** so its judge lacks Phase 1 fix 3 (the own-alibi change). That affects its night units.

### Decisions needed before any tuning

1. **The cap:** keep it and accept the swap, remove it, or fade old cases? **Decided (Michael): fade.**
2. **Criterion 1's bar:** is the evil-count shift (up to 2.5 points) and a trace's reach onto unnamed people acceptable? **Decided: people whose profile a trace matches count as touched; the common evil-count shift is accepted.**
3. **Cost:** is "cached except at dawn" acceptable, given the caveat? **Decided: caching is part of the design, and criterion 5 is judged cached.** Lantern measures how often the cache is invalidated within a day.
4. **Thin cores and seedless listeners:** lower the threshold at 10 NPCs (Quill's 0.3), and should a Night Watch's own readings seed its core? **Open: Lantern tests both next.**

## Results: prototype follow-up (Lantern, Nov 10 late)

**Decision (Michael):** old stored cases should fade, not vanish when a third arrives. Not built yet.

### Where the big gaps from "connects everything" come from (12926)

`connections_prototype.gd --explain listener:person:day` (PR #129) shows which cards carry a belief. Two cases:

- **Edda on Hollis, day 5** (connects everything 90–97%; prototype 6%; today's game 5%). One card carries it: Fenwick's Night Watch report "I saw Hollis pass by" on night 3. Without that night's cards the figure is 2%. Alone, the night lowers Hollis (24%); it convicts only when chained with the Surveyor's Market reading, Lian's Registrar reading and Kiran's false Chronicler reading. **It is wrong:** Hollis is the good Confessor and this was a Hexer game. It also cascades, clearing the evil Lian to 8%. The prototype keeps each night in its own unit and doesn't make the chain.
- **Lian, day 3** (connects everything 85–97%; prototype 22–39%). Two connections are lost:
  1. **Elimination inside a group.** Agnes's Dowser reading "one evil among Odette and Lian" still counts (61–70% alone), but not the cards that clear Odette.
  2. **A liar's own reading helps the liar.** Lian's Registrar reading about Fenwick, alone, makes her look credible (28%, below the 39% baseline). It exposes her only next to the cards that contradict it; without it Hollis's figure falls from 97% to 47%.
- **A limit of the core test.** Hollis's own confession of Fenwick didn't pull Lian's reading into his core. Likely cause, not confirmed: the two don't clash as a pair, and it takes a third card (Fenwick's Night Watch claim). The test only checks pairs.
- ~~**The Hexer factor lowers the actual Hexer.**~~ **Wrong; corrected in "Results: prototype rerun".** The factor changes nothing here. The 29% is the game's belief refresh, against 61–74% from the raw judge on the same cards.

### Twenty passive games against the truth

Seeds 910–919 (7 NPCs) and 920–929 (10 NPCs) on `7404873`; single-demon scripts; every vote in every replay matches its log.

**Separation** (mean chance on the truly evil minus the truly good):

| | Snapshots | Today | Prototype (0.4) | Connects everything |
|---|---|---|---|---|
| 7 NPCs, day 3 | 23 | 0.35 | 0.36 | 0.38 |
| 7 NPCs, day 4+ | 11 | 0.53 | 0.50 | 0.58 |
| 10 NPCs, day 3 | 48 | 0.40 | 0.36 | 0.43 |
| 10 NPCs, day 4+ | 42 | 0.54 | 0.50 | 0.57 |

- **No collapse:** the prototype reads passive towns about as well as today's model. Thresholds 0.2, 0.4 and 0.8 land within 0.01–0.03 of each other.
- **Headroom for a player is modest here** (about 0.07 between the prototype and connecting everything). These are single-demon games with the movement connection fully on.
- **Votes:** 57 of 641 individual good votes flip (9%). 13 of 171 outcomes change: evil nominees gain four blocks and lose three; good nominees lose four and gain two. Evil nominations that carry: 23 → 20.
- **Seedless listeners are common:** about 28% of listener-dawns from day 3 (35 of 124).
- **Cores:** from day 3, 18 of 34 listener-dawns have at least one joined card at 7 NPCs, and 33 of 90 at 10.

### Why good loses while "top suspect is evil" is high (same 20 games, today's model)

| | 7 NPCs | 10 NPCs |
|---|---|---|
| Top suspect is evil, day 3 | 65% | 79% |
| Top suspect is **the Demon**, day 3 | 13% | 22% |
| Mean chance on the Demon, day 3 | 50% | 62% |
| Hangings: good / Minion / Demon | 9 / 4 / 5 | 10 / 12 / 7 |
| Good nominations of the Demon: on the block / not | 6 / 7 | 8 / 13 |
| Good voters saying yes to hanging the Demon | 77% | 75% |
| Evil nominations of a good person: on the block / not | 10 / 24 | 10 / 35 |

- **NPCs find evil, but usually a Minion first.** Only the Demon's hanging wins.
- **Accuracy arrives late.** On day 2 the top suspect is evil about half the time (51% and 64%), and the median game is over by day 3.5–4.
- **A vote on the Demon fails more often than not,** even with three in four good voters saying yes. Evil votes no, and in a passive game the player's vote is a no.
- Small sample (20 games, 34 votes on the Demon); the direction matches the sweeps' finding that passive towns lose to wrongful hangs.

## Results: prototype rerun on the late decisions (Lantern, Nov 11 early)

PR #129, tools only, main `edc01cf` merged in. **All seven criteria pass at threshold 0.4 with stored cases keeping half their weight each day.** Criterion 5 passes as decided (cached) and fails once the items a cache would have had to redo are counted. Nothing else was tuned.

**Logs:** 12926 at its own build `75b4c8e`; passive 900, 902 and 910–929 regenerated on `edc01cf`, because main's gameplay changed since `7404873` and the old logs no longer replay. Every vote in every replay matches its log.

**What was built:**
- **Fading.** A stored case's weight is trust in the presenter × rate^(days since it was presented). Nothing is pushed out; a revision still replaces its earlier version; a case under 0.05 stops counting. Rates 0.5, 0.7 and 0.85 are reported.
- **Traces.** A cited trace touches everyone it moves by 0.1 log-odds or more when read with the profile cards.
- **Cache check.** Each refresh is compared with the listener's previous one that day.

### The seven criteria (0.4, rate 0.5)

| # | Criterion | Result | Numbers |
|---|---|---|---|
| 1 | People a case didn't touch move 3 points or less | **Passes** | Largest move 2.8 points (Edda on Lian, #152); 0 of 13 over. It was 38 points with the cap |
| 2 | Hollis catches Kiran's lie unaided | Passes, same note | 82% before the Day 4 case; the reading is in his core at dawn on day 5 (69%). At dawn on day 4 the copy he holds wasn't told to him by Kiran, and it doesn't join |
| 3 | The Day 4 case doesn't backfire | Passes | Kiran rises for all four: +9.1, +4.4, +3.7, +3.2 points |
| 4 | Vote shapes no worse than today (+1) | Passes | Identical counts in all three logs. Good votes flipped: 2 of 45, 1 of 12, 3 of 36. No outcome changes |
| 5 | Refresh cost at or below today's, cached | Passes cached | From day 3, median / 90th percentile, today against cached: 12926 57 / 289 against 40 / 152 ms; 900 15 / 15 against 3 / 3; 902 29 / 50 against 1 / 1 |
| 6 | Nothing moves without a reason | Passes | |
| 7 | Largest set judged together is 50% of held cards or less | Passes | Median 25% (12926), 42% (900, 902). Largest for any listener: 49% in 12926, 58% across seeds 910–929 |

### Fade rates

| | 0.5 a day | 0.7 a day | 0.85 a day |
|---|---|---|---|
| Criterion 1, largest untouched move (12926) | 2.8 | 2.6 | 2.5 |
| Criterion 3, rises on Kiran from #152 | +3.2 to +9.1 | +3.2 to +9.0 | +3.2 to +9.0 |
| Good votes flipped, 12926 | 2 of 45 | 3 of 45 | 4 of 45 |
| Vote outcomes changed, 12926 | 0 | 1 | 1 |
| Separation, 10 NPCs, day 4+ (seeds 920–929) | 0.51 | 0.52 | 0.53 |
| Good votes flipped, seeds 910–929 | 57 of 641 | 57 of 641 | 58 of 641 |

- **The rate barely matters on these logs.** The one visible effect: at 0.7 and 0.85, Hollis again votes no on Isolde (the Scion) on day 4 and she comes off the block; at 0.5 she stays on.
- **Cases pile up without a cap:** from day 3 a listener in 12926 has a median of 3 stored cases still counting, and up to 9. Most are NPC nominators' cited cards.

### Caching (criterion 5)

Comparing each refresh with the listener's previous one the same day (65 comparisons in 12926, 12 in 900, 36 in 902):

| Share of a listener's items | 12926 | 900 | 902 |
|---|---|---|---|
| New since the last refresh | 8.9% | 21.7% | 18.3% |
| Invalidated by a death or execution | 0% | 0% | 11.9% |
| Invalidated by a hearing-weight change | 2.6% | 5.6% | 2.0% |
| Invalidated by a trust change | 3.3% | 7.0% | 3.8% |
| Kept | 85.2% | 65.7% | 64.1% |
| Refreshes that invalidated nothing | 35% | 33% | 25% |

- **Refresh cost counting the redone items** (the joint pass plus two judgements per new or invalidated item), median / 90th percentile: 12926 119 / 329 ms against today's 57 / 302; 900 24 / 41 against 7 / 15; 902 121 / 381 against 16 / 29. **That is above today's.** Most of it is new cards arriving, which today's model also pays for inside its single pass.
- **Kept items do drift a little.** 1.3% of kept items in 12926 (6.4% in 900, 0.5% in 902) moved more than 0.02 log-odds with none of the three triggers firing; the worst is 0.26. Every drift came when the meeting's nominations, accusations or votes had changed, so those are a fourth, weak dependency.
- Within a day the public record changed only in 902.

### The two tests (reported, not chosen)

**Threshold 0.3 at 10 NPCs** (seeds 920–929; 12926 in brackets):

| | 0.4 | 0.3 |
|---|---|---|
| Listener-dawns from day 3 with at least one joined card | 33 of 90 (6 of 13) | 38 of 90 (7 of 13) |
| Seedless | 25 of 90 (2 of 13) | the same |
| Separation, day 3 / day 4+ | 0.35 / 0.51 | 0.36 / 0.51 |
| Criterion 1, largest move (12926) | 2.8 | 2.8 |
| Criterion 4: good votes flipped; outcomes changed | 42 of 462; 9 | 40 of 462; 8 |
| Criterion 7: median, largest | 33%, 58% (25%, 49%) | the same |

**A Night Watch's or Lamplighter's own readings seed its core** (the unit, or the movement connection, they sit in joins the seed):

| | Off | On |
|---|---|---|
| Seedless from day 3: 7 NPCs / 10 NPCs / 12926 | 10 of 34 / 25 of 90 / 2 of 13 | 7 of 34 / 19 of 90 / 0 of 13 |
| At least one joined card: 7 / 10 / 12926 | 18 of 34 / 33 of 90 / 6 of 13 | 20 of 34 / 37 of 90 / 8 of 13 |
| Separation, day 3 / day 4+, 7 NPCs | 0.36 / 0.51 | 0.37 / 0.54 |
| Separation, day 3 / day 4+, 10 NPCs | 0.35 / 0.51 | 0.35 / 0.51 |
| Criterion 1, largest move (12926) | 2.8 | 2.8 |
| Criterion 4, 10 NPCs: good votes flipped; outcomes changed | 42 of 462; 9 | 43 of 462; 9 |
| Criterion 7, largest (10 NPCs) | 58% | 65% |

- **Both changes are small.** 0.3 adds a joined card for 5 more listener-dawns in 90.
- **Most seedless listeners stay seedless** with the second change: they hold a gift with no reading at all, or no reading yet. It fixes the Night Watch and Lamplighter cases only (9 of 35 in the passive seeds, both in 12926).

### Separation, seeds 910–929 (regenerated)

| | Listener-dawns | Today | Prototype | Connects everything |
|---|---|---|---|---|
| 7 NPCs, day 3 | 23 | 0.35 | 0.36 | 0.38 |
| 7 NPCs, day 4+ | 11 | 0.53 | 0.51 | 0.58 |
| 10 NPCs, day 3 | 48 | 0.40 | 0.35 | 0.43 |
| 10 NPCs, day 4+ | 42 | 0.54 | 0.51 | 0.57 |

Votes: 57 of 641 good votes flip, and 13 of 171 outcomes change (evil nominees gain four blocks and lose three; good nominees lose four and gain two). Evil nominations that carry: 23 → 20.

### The three explanations

1. **The Hexer factor does not lower the actual Hexer. My earlier line was wrong.** With the factor on and off, every person's chance is identical, for Hollis and for Dorian on day 5. What differs is where the 29% comes from: it is the game's belief refresh, not the raw judge. For Hollis, on the same cards, the judge alone gives Kiran 61% and the refresh gives 29%. Emptying the union's reading challenges moves that to 24% for Hollis and 45% for Dorian, so they are part of it for Dorian and none of it for Hollis. **Not pinned down further.** It also means "the judge on every held card matches read-everything exactly" holds for the passive seeds and not for 12926.
2. **#178 lowers Hollis on Kiran because his own core answers it.** The case's nine cards judged alone put Kiran at 85%. Hollis's core alone has 52%, and the two together 51%. Leaving out the Archivist pair, a trace or one of his later confessions each removes about a third of the drop. This is the design's "a case that clashes with the listener's own readings scores low by itself". It fits the truth that Isolde, not Kiran, was the Scion the pair pointed at, though I haven't traced that link.
3. **A three-card test would have pulled Lian's reading in.** Lian's "Fenwick is a Poisoner, Chronicler or Warden" against Hollis's seed scores 0.23 as a pair. With any one of Fenwick's three Night Watch reports as a third card it scores 3.8. No other third card lifts it (3 of 19).

**Codex fixes at merge (Bailiff, Nov 11; PR #129).** Two corrections to the tool, rerun on 12926, 900 and 902; all seven criteria still pass at 0.4, fade 0.5.
- Successive core merges keep the movement cards that earlier merged cases cited (it only affects declared-Walker runs with two merging cases).
- A presentation's "without" side keeps the listener's whole store, including an earlier version of the same case. So #178 is now measured against the Day 4 version each listener already held: Edda +7.9 (was +10.2), Dorian +1.2 (was +2.0), Hollis −1.5 (was −1.3). #152's second telling (seq 851) now adds 0 for Hollis, as it should.

### Left open

- What inside the belief refresh takes Kiran from 61% to 29% in 12926.
- Whether "cost counting the redone items" needs its own bar, since criterion 5 as decided is the cached pass.
- Whether meeting talk should invalidate cached values (worst drift 0.26).
- A cap or faster fade for NPC nominators' cases, if nine live cases per listener is too many.

## Phase 4 spec: how the offline prototype computes beliefs (Lantern, for Michael's review)

Nov 10, 2026 · **A spec, not a build.** The prototype is an offline tool (`tools/connections_prototype.gd`) that replays logs and prints what listeners would believe. It adds no code path the game runs and changes no gameplay.

Five points depart from, or pin down, the design above. They're marked **(review)** and gathered at the end.

### 1. Terms

- **The judge:** today's shared evaluator (`CaseEval` over the possible worlds), run on a chosen set of cards instead of the whole view. For one listener and one set it gives every person's chance of being evil and of being the Demon. The listener's trust, hearing weights, the public record (deaths, executions) and the fact that the listener knows it is good are part of every run.
- **Baseline:** the judge run on no cards.
- **Lean:** how far a set of cards moves a person from the baseline, measured in log-odds (so leans add). Chances are clipped to 1%–99% first. Every person has an "evil" lean and a "Demon" lean; both follow the same arithmetic.
- **Context cards:** role claims, confessed secrets and profile cards (work, haunts, home, bonds). They explain other cards. A context card can sit in any number of sets without joining them together.
- **Value of a set given its context:** lean(set + context) − lean(context). The context's own lean is counted once, separately.

### 2. Solo values

Every held card counts once: its lean given its context (for a reading or a sighting told by someone, that teller's role claim, if held).

Cached per listener and card. Recomputed when the listener's trust in the teller, the card's hearing weight or the public record changes.

### 3. Structural units

Each row of the structural-pairings table makes a **unit**: a set of cards judged together, which then behaves as one card everywhere else. A unit's value replaces its members' solo values.

| Unit | Members | Context |
|---|---|---|
| A night's movement | every sighting, home alibi and Lamplighter count for that night | the named people's claims and confessed secrets |
| An Augur day | the Augur reading and that day's sightings | claims |
| A Psychologist reading | the reading and its two statements | — |
| A trace | the trace | profile cards |

- Units are per night or per day. **They never join across nights** (see section 9).
- A reading is judged with its teller's claim as context. That is one more structural pairing than the table lists. **(review 1)**

### 4. The core, built at dawn

- **Seed:** the listener's own readings, judged together. (Own sightings and vigils sit in their night's movement unit; that unit is always a candidate.)
- **Candidates:** every other card or unit held at dawn.
- **Test:** for each candidate, lean(seed + candidate) − lean(seed) − lean(candidate), for every person. The candidate joins if the largest of these, in size, reaches the threshold.
- **Each candidate is tested against the seed only,** never against cards that already joined. So the result doesn't depend on order, and the core can't snowball.
- **Threshold:** the prototype reports three settings, 0.2, 0.4 and 0.8 (about 5, 10 and 19 points for someone at 50%). Acceptance uses 0.4 unless Quill's table shows a clearer gap.
- **The core connection** is the seed plus what joined, judged together.
- **Rebuilt only at dawn.** A card first heard during the day counts solo until the next dawn. **(review 2)**
- **"Knowing it is good" is in every judgement,** not a member of the core. A giftless NPC has an empty seed and so no core; cards that name it still use what it knows about itself in their solo values. Its own opinions come from bundles. **(review 3)**

### 5. Per-teller bundles

- For each teller with two or more statements held: all of that teller's statements (readings, sightings, alibis, claims), judged together.
- A bundle adds only its **interaction**: lean(bundle) − the sum of its members' solo values.
- **A bundle never merges with anything.** If it shares two or more cards with another connection, the shared cards' own interaction is subtracted once, so no pair is counted twice. **(review 4)**

### 6. Stored cases

- **What is stored, per listener:** the case's cards, its premise, its challenges, the presenter and the day. At most two, newest first. A case from the same presenter with the same premise type and target replaces the earlier one.
- **Cards the listener didn't hold** become held when the case is presented, and stay held if the case later drops off the cap. A presented copy confirms the card was said (full hearing weight) and leaves trust in its teller as it was.
- **Weighing:** the case's cards are judged together.
  - If the case shares a card with the core, the two are judged as one set. The core's own interaction counts in full; what the case adds on top is scaled by trust in the presenter.
  - Two stored cases that both overlap the core join the same set, the older one first.
  - A case that doesn't touch the core adds its interaction, scaled by trust in the presenter.
- **Challenges** in a case apply inside that case's set only. "Lying" changes no reliability (Phase 1 fix 2). "Misled" and "failed gift" discount the reading as today, inside the set; the card's solo value is untouched. **(review 5)**
- **Re-weighed at every refresh.** No accepted or rejected state is kept.

### 7. Combining and normalising

For each person, in log-odds:

> baseline + every card's or unit's solo value + the core's interaction + each bundle's interaction + each stored case's scaled interaction − the overlap corrections

Then:
1. **Evil:** one common shift is added to everyone the listener isn't certain about, chosen so the chances sum to the script's evil count.
2. **Demon:** the same, so the Demon chances sum to 1. Nobody's Demon chance may exceed their evil chance.
3. People the public record or the listener's own knowledge fixes (itself, a confirmed death result) stay fixed.

The prototype outputs chances. For votes it converts them to suspicion with today's rule and reuses the other vote terms (resentment, town pressure, the bars) from the log.

### 8. What a refresh costs

- Solo values: cached.
- One judgement per unit, one for the core, one per bundle, one per stored-case set, plus overlap corrections.
- Each set is small, so each judgement is cheaper than today's whole-view pass. The prototype times both on the same listener states.

### 9. Movement before and after a declaration

- **Before a declaration** (a two-demon script with none made, which is every existing two-demon log): movement counts only through the per-night units in section 3. No routes across nights, no vigil exclusions across nights, no trace routes, no day-log or Hexer factor. The prototype needs a switch for the Hexer factor if it enters from the public record alone; I'll confirm that in the build.
- **Single-demon scripts start declared (Walker):** all movement cards form one always-on movement connection for every listener, as today. It behaves like a bundle: it never merges, and overlaps are corrected.
- **12926 is a two-demon script with a Hexer.** It is run undeclared for the acceptance criteria, and once more as if "Hexer" had been declared on day 1, for information only.

### 10. Acceptance criteria

Run on three logs: human playtest **12926** (10 NPCs, four filed cases, eleven recorded votes) and **two passive seeds**, one at 7 NPCs and one at 10, generated on the commit the prototype is built on so they replay exactly. Each criterion is compared with today's model on the same listener states, using the why tool (#119, #121).

| # | Criterion | Measure | Pass |
|---|---|---|---|
| 1 | People a case didn't touch don't move | For every presentation and every good listener: the change in chance of being evil for each person who isn't the premise's target, isn't named in or the teller of a case card, and isn't named in a core card the case joined | Every such change is 3 points or less. Today on 12926 day 4 the largest is 68 points (Edda on Isolde) |
| 2 | Hollis catches Kiran's lie unaided | Kiran's Chronicler reading joins Hollis's core at the first dawn after he holds it; from then, with no presentation, his chance that Kiran is evil | The reading joins, and the chance is 50% or more. The day it happens is reported |
| 3 | The Day 4 case doesn't backfire | Change in each of the four good listeners' chance that Kiran is evil when case #152 is presented | No listener falls by more than 1 point. Today two fall, by 24 and 9 points |
| 4 | Vote shapes stay healthy | On the recorded nominations, votes recomputed from prototype beliefs: votes unanimous apart from the nominee, votes where only the nominator says yes, evil nominations that carry | Each count is no more than today's on the same nominations, plus one |
| 5 | Refresh cost is no higher | Time per listener refresh, median and 90th percentile, both models on the same machine and states | Prototype at or below today's on both |
| 6 | Nothing moves without a reason | Beliefs recomputed within a day with no new card and no presentation; a case presented twice | Identical both times |
| 7 | NPCs connect little | The largest set a listener judges together, as a share of the cards it holds, from day 3 | Median 50% or less. Reported per listener |

Reported without a pass mark:
- how far prototype beliefs sit from today's and from the read-everything answer;
- how well each model separates the truly evil from the truly good, by day;
- core sizes and what joined, per listener and day;
- the Day 2 "Lian is evil" and "Nisha is the Demon" cases and the Day 5 Kiran case, per listener.

**A limit of offline replay:** each vote and presentation is judged on the state the log recorded. The prototype can't follow what a different vote would have changed later. Criterion 4 is therefore a count over eleven-plus independent votes, not a game outcome.

### 11. What I need from Quill's interaction table

One row per seed, listener, card A, card B and person, with the chance of evil and of Demon in four conditions: no cards, A alone, B alone, both. Plus each person's true alignment and enough to reproduce the listener (seed, day, trust setting). Chances, not rounded steps, so I can work in log-odds.

Pair types, in order of need:
1. **An own reading with a heard card** (the core test). This sets the threshold: I'm looking for a gap between pairs that really combine and noise.
2. **Two statements from one teller,** including pairs where one is false (does a bundle catch a liar?).
3. **Each structural pairing,** with and without the context card.
4. **A reading with its teller's claim,** to settle (review 1).
5. **Cross-teller pairs a player would present** (Archivist pair with a clearing reading, Dowser count with a Confessor result). These are the cases Phase 5's bot will build.

At 7 and 10 NPCs, at trust 0.4 and 0.8, with and without the Hexer on the script.

I'll also use the table's solo values as a check: the prototype's solo values for the same listener states should match them.

### 12. For review

1. **Readings are judged with their teller's claim as context.** Without it, a heard reading loses the "what it says about the reader" part that the measured catalog found to be most of its effect.
2. **A dawn-built core delays an unaided catch.** If Hollis first hears Kiran's reading at the Day 4 meeting, his core picks it up at dawn on Day 5. On Day 4 the catch would come from the player's case, which joins his core through his own Confessor reading. If that delay is unwanted, the alternative is to test a newly heard card against the core when it arrives.
3. **"Knowing it is good" applies to every judgement** instead of being a core member. This is stronger than the doc's wording, and it means giftless NPCs have no core.
4. **Bundles never merge; overlaps are subtracted.** With "overlapping connections merge" applied to everything, one case would chain the core and every cited teller's bundle into a single set, which is today's whole-view solver again. Only the core and stored cases merge.
5. **A challenge acts inside its case only.** Today an accepted challenge changes the reading for everything the listener believes.

Depends on: Phase 1 fixes 1 and 2 being merged (or the prototype copies their rule), and Phase 3's table for the threshold.

## Decisions, Nov 10 evening (Michael, with Bailiff)

On Quill's findings and Lantern's spec review:
- **Review 1, no.** Readings aren't judged with their teller's claim as context: the table shows the two simply add up (median interaction 0.04).
- **Review 2, test on arrival.** A newly heard card is tested against the core when it arrives; the full rebuild stays at dawn. Hollis can catch Kiran's lie the day he hears it.
- **Review 3, moot.** Every good NPC has a gift, so every NPC has a seed. "Knowing it is good" in every judgement is fine.
- **Review 4, moot.** Without bundles, only the core and stored cases merge.
- **Review 5, yes.** A challenge acts inside its own case only.
- **No per-teller bundles** in the first prototype (see the design section).
- **Core threshold:** 0.4, provisional, to be confirmed on Quill's rerun after #124. Trust in the teller moving it is accepted. **Confirmed on the rerun (Quill, results above);** watch 10-NPC core sizes, with 0.3 as the fallback.
- **Fix 3:** the lower watcher rise is accepted (see Phase 1).


## Decisions, Nov 10 late (Michael, with Bailiff)

On Lantern's prototype results and Tally's Phase 1 check:
- **Old stored cases fade** instead of a cap of two (see the design section).
- **Criterion 1:** people whose profile a trace matches count as touched by the case. The common shift that keeps the evil count is accepted.
- **Caching is part of the design,** not an optimisation. Criterion 5 is judged with solo values and core tests cached, plus a measure of how often the cache breaks within a day.
- **The possible ~5-point Phase 1 drop:** one more paired Tally cell, on `7404873` with #124 reverted on an experiment branch (never merged), to see whether fix 3 is the cause. Suspected mechanism: only trust in the sighter enters the clash, and good people are assumed truthful, so a good night-walker who says "home" when sighted now looks guilty.
- **Must fix, tracked: challenges can't tell which side is lying.** At trust 0.8 a challenge is accepted whichever side is false (Quill's table: false grounds against an honest reading win as often as true ones). Parked behind the prototype work, but it isn't optional: Quill diagnoses it and proposes a fix next, and it has to be resolved before Phase 5's bot uses challenges.

## Decisions, Nov 11 (Michael, with Bailiff)

- **Fade rate 0.5 a day.** It is the only rate that changed no vote outcome in 12926.
- **A Night Watch's or Lamplighter's own readings seed its core.** It fixes a real gap cheaply.
- **The core threshold stays 0.4 at every town size.** 0.3 barely changes anything.
- **NPC nominators' cases:** no faster fade or cap yet. Revisit if up to nine live cases per listener shows up as a problem in play.
- **Challenges:** contest is merged (#132). The graded test for clashes that poisoning or registration can explain waits until after Phase 5, since contest already gets the direction right.
- **The 61% → 29% refresh gap on Kiran** (Lantern's framing, with Bailiff's note). On the old playtest build, the game's belief refresh and the raw judge disagree about Kiran: 29% against 61% for Hollis on day 5, reading everything. It shows up only in the human game. Unexplained and low priority; worth one check on current main before anyone treats it as a problem. *Note:* the old challenge bug (fixed in #123) explains part of Dorian's gap but none of Hollis's: emptying the challenges gives him 24%, not 61%.

## Decisions, Nov 12 (Michael, with Bailiff)

On Tally's Phase 5 cells:
- **Why the declaration barely matters today:** the current model already infers the Demon's kind. On an undeclared two-kind script it treats the kind as one hidden fact for the whole case (`LiveActivity.mix_demon`), so evidence about it builds night by night, and every NPC does roughly what the bot's Bayes factor does. A declaration mostly repeats what the town can reach alone, and a wrong one costs little because the evidence was murky anyway. Under connections the declaration decides which movement connections exist, so it should matter much more, both ways.
- **Option raised: "walker by default".** Undeclared would mean walker, and declaring Hexer would become the expert call. It conflicts with the design's "before a declaration, per-night pairings only". **On hold:** decide during the connections build, after Michael playtests the declaration. No change to the bot's thresholds until then.
- **Why the bot misses Hexers (unchecked):** the walker story predicts route evidence, so it wins wherever evil's planted sightings or Minions' real outings fit a route to the kill. The Hexer story wins only on the absence of routes, which is thin by day 3. Check: replay wrong calls without evil's sightings.
- **For playtesting:** dynamic scripts deal one kind by default, so a two-kind game needs both the Demon and the Hexer on the script (script editor, Demons).
- **The no-present sweep cell may declare the Demon's type** (Michael, on Steward's question in #133). It does so since #137; the cell isolates presenting, not declaring.

- **The Kiran refresh gap doesn't reproduce on main** (Bailiff). I ran six bot games on main (7 NPCs, seeds 100000–100005), in which the bot presented 50 cases. At every dawn (67 listener-dawns, 402 listener-on-person pairs), the game's belief update and the raw judge on the same held cards agree to within 2 points. The bot never challenges cards, so challenges are the one ingredient left untested. Their handling has been rewritten twice since 12926 (#123, #132), and under connections a challenge acts only inside its own case. A playtest with challenges can close it: the comparison takes minutes on any log.
- **Self-sightings (Bailiff; PR #139, merged; golden `baseline_300fe18`).** Michael's catch from the check above. A good NPC who knows they were home rejected any sighting of themselves (`Reasoner.direct_checks`), which spared them, but also threw away the one piece of evidence that its teller lied.
  - **Plain sightings are now kept:** the clash counts against the sighter through #135's contest.
  - **"Am I the Sleepwalker?"** With the secret on the script, the listener's own home nights carry a 10% doubt (`Tuning.Workshop.SLEEPWALK_SELF_DOUBT`). Michael: a bit above the true chance, matching the self-doubt of games like Blood on the Clocktower. Backlog: scale it with confidence.
  - **Poison breaks gift readings only** and never invents a plain sighting (Michael). That is already the rule.
  - **Measured** over 40 passive games, 46 cases: 10 rise by more than 5 points against the sighter, and none fall. Examples: Odette on Constance 25% → 66%; Dorian on Greta 32% → 52%; Nisha on Kiran 37% → 56%. A real Sleepwalker seen by an honest sighter stays low (Edda on Constance: 22%).
  - **Still set aside:** Night Watch lists (an open item below). Medium relays were set aside here too, until #140.
- **Medium relays (Bailiff; PR #140, merged; golden `baseline_6a22cac`).** Found while building #139. `RoleConstraints` scored every world with a held relay's relayer evil at 0, so an evil player bluffing Medium could invent a relay "from the dead" and be cleared by everyone who held it.
  - **The fix, in play:** a world with the relayer evil stays possible, and the relay is their bluff. Its health and visit checks don't apply, its implied Medium claim is treated like any evil claim, and a relayed reading says nothing about the dead source. Puzzles keep the hard rule.
  - **Relayed self-sightings are now kept** too: their relayer can be the liar.
  - **Measured** on 60 passive games (seeds 100000–100059):
    - **Evil relayers:** 47 listener readings in 11 games. Before, 43 of them were under 2%. Now the mean is 0.69 (range 0.06–1.00), depending on the rest of the evidence.
    - **Genuine Mediums:** 5 readings, 0.00 → 0.00–0.10.
  - Golden: 42 and 98933 move on day 3, and both outcomes are unchanged.

## Phase 6 spec: the connections model in game (Lantern)

Nov 12, 2026 · **A spec, not a build.** Michael has answered its four questions (section 11): all as recommended. Built from the prototype (#129) and the decisions of Nov 10–12, read against main `9e69144`.

**In short:**
- **Switch off:** nothing changes. Golden stays identical at every PR.
- **Switch on:** one number changes: the chance an NPC gives each person of being evil at a belief refresh. Everything after that number is today's code: suspicion, votes, nominations, who to hang first, trust.
- **Attention stops limiting what an NPC believes.** The Insight card limit still decides what an NPC can cite and explain in a reply.
- **Four questions for Michael** are at the end. **All four are decided as recommended (Nov 12).**

### 1. The switch

- `Tuning.Workshop.CONNECTIONS`, off by default.
- Tuning values are fixed at build time. So tests, autoplay and sweeps turn it on with a flag (`--connections`), which sets one runtime variable that starts from the Tuning value. Tally can then run paired cells from one build.
- The model's memory (section 6) is created only when the switch is on, so an off game's saved state and golden capture are untouched.

### 2. Every card counts alone

- Every card the NPC holds has a value by itself: how far that one card moves each person, in log-odds, from the NPC's standing suspicion.
- **"Held" is what it is today.** Source doubt, hearing weights, relays, and the cards an NPC rejects from its own knowledge all run first, unchanged. A rejected card has no value.
- Role claims, confessed secrets and profile cards (work, haunts, home, bonds) are **context**: they explain other cards, and can sit beside any of them without joining sets together.

### 3. Built-in pairings

Cards that mean little alone are always read with their partner, for every NPC. Each pairing counts as one card everywhere else.

| Pairing | Read together | Context |
|---|---|---|
| A night | that night's sightings, home alibis, Night Watch reports and Lamplighter counts | the named people's claims and confessed secrets |
| An Augur day | the Augur reading and that day's sightings | claims |
| A Psychologist reading | the reading and its two statements | none |
| A trace | the trace | profile cards |

**The demon-type declaration decides how movement is read:**

| | Nights | Traces | The Hexer's day evidence (day logs, daytime sightings, haunts) |
|---|---|---|---|
| **No declaration** (a script with both kinds) | Each night by itself. Inside a night the Demon's movement is today's 50/50 mix | With profiles only | Off (question 1) |
| **Walker** (declared, or a walker-only script) | All nights strung together with the traces, as one always-on movement connection. This is today's reading | In the movement connection | Off |
| **Hexer** (declared, or a Hexer-only script) | Each night by itself; a sighting counts little against the Demon, who doesn't walk | With profiles only | On, as one always-on day connection |

- The always-on connections never merge with the core or a case. A case that cites one of their cards adds only what that card does next to the case's other cards.
- **The Hexer row was never run in the prototype.** I'll measure it on Hexer-forced seeds at step 2, before that PR.

**How the two recent fixes fit a night:**

- **#135, sighter contests.** The rule lives inside the movement reading, so it applies to whichever movement cards are read together. Inside a night: in a world where the sighter is evil, their sighting counts 15% of the time, and otherwise as invented. The sighting, the subject's alibi and the subject's claim are always in the same night, so "his word against theirs" is still settled by priors.
  - A case can't cite a sighting without the alibi: citing any card of a night brings the whole night into the case.
  - A sighter who reports on several nights is doubted night by night, and the doubts add up. Today their honesty is one fact across all nights. Under a Walker declaration it is again.
  - The limit of two sighters per person is counted per night.
- **#139, self-sightings.** "I was home that night" isn't a card. It's part of what the NPC knows about itself, which is in every judgement. So a sighting of the NPC on a night it was home sits in that night's pairing, clashes with what it knows, and counts against the sighter through #135. The 10% "am I the Sleepwalker?" doubt applies inside that judgement, as today.
  - Night Watch lists that wrongly name the listener stay set aside, as today. *(Bailiff, Nov 12: Medium relays are kept since #140, so a relayed self-sighting sits in its night like a plain one, with its relayer in the contest.)*
  - **One difference:** an NPC wrongly sighted on two different nights applies the 10% doubt to each night separately. Today it is one doubt shared by both. I'll count how often that happens at step 2; I expect it to be rare.

### 4. The core

- **Seed:** the NPC's own readings. For a Night Watch or Lamplighter, also the night (or the movement connection) that holds its own reports (decided Nov 11).
- **Joining:** any other card or pairing joins if it is worth more next to the seed than apart: seed and card together, minus the seed alone, minus the card alone, at 0.4 or more for any person.
- **Tested against the seed only,** never against what already joined. So the order doesn't matter and the core can't snowball.
- **When:** rebuilt at dawn, and when the NPC gets a new reading of its own. A card first heard during the day is tested once, when it arrives. Otherwise membership is fixed for the day.
- **A presentation never edits the core.** If it brings a card the NPC didn't hold, that card is tested like any other newly heard card.
- **What an NPC knows firsthand stays certain.** If the seed alone proves someone good or evil, later cards can't argue it away. The prototype softened such proofs to 1%; this is new.

### 5. Stored cases

- **What is stored, per listener:** the case's cards, premise, challenges, presenter and day.
  - The player's presentations, public or private. Today's presentation store already holds these; it gains the day.
  - An NPC nominator's cited cards, for everyone who hears the nomination. This store is new.
- **Weight:** trust in the presenter (the player's credibility, or the listener's trust in the NPC) × 0.5 for each day since it was presented. Under 0.05 it stops counting. A revision replaces its earlier version. A "suspicious" premise halves the weight; today it halves the cards only it brought.
- **Weighing:** the case's cards are judged together.
  - If the case shares a card with the core, the two are judged as one set. The core's own part counts in full; what the case adds on top is scaled by the weight. Older cases merge first.
  - A case that doesn't touch the core adds what its cards do together beyond their single values, scaled by the weight.
- **Cards a case brings become held** and keep their single value after the case fades. A presented copy confirms the card was said; it never replaces trust in its teller.
- **A challenge acts only inside its own case** (the contest rule, #132). "Lying" changes no reliability. "Misled" and "failed gift" discount the reading inside the case's set; the card's single value is untouched. The prototype didn't model those two, so they're tested at step 4.

### 6. Combining, normalising and caching

- **Combining,** for each person, in log-odds: standing suspicion + every card's or pairing's value + what the core adds + what each stored case adds.
- **Normalising:** one common shift, so the chances of being evil sum to the script's evil count. People the public record or the NPC's own knowledge fixes stay fixed.
- **P(Demon):** computed the same way, summing to 1. Nothing in the game reads a Demon chance today, so it goes to the logs and tools only. NPCs using it to choose whom to hang first is a later lever: in the 20 passive games, towns usually reached a Minion before the Demon.
- **Caching:** each value is kept per NPC and redone only when something it depends on changes:
  - the cards in it, or how well the NPC heard them;
  - the NPC's trust in a teller it involves;
  - a death, execution or attack;
  - the declaration.
- **Values are measured against the NPC's standing suspicion as of dawn.** That makes a kept value exact for the whole day. The day's talk still moves beliefs, through the standing suspicion itself. This settles the prototype's open point about meeting talk (it drifted kept values by up to 0.26).
- Everything is redone at dawn.
- **Cost:** at or below today's refresh on the same states, counting the redone items. The prototype missed that stricter bar (119 against 57 ms at the median in 12926). If the build misses it too, I'll report before optimising.

### 7. What happens to today's mechanisms with the switch on

| Today | With the switch on |
|---|---|
| Attention (the Insight card limit, recency) | No longer limits belief. Still picks what an NPC cites and explains |
| Spillover damping for bystanders | Off. People a case didn't touch don't move, by construction |
| Headline reading (a low-Insight NPC takes a strong reading at its word) | Off: Insight is out for v1 (question 2) |
| Reading challenges applied to everything the NPC believes | Inside their own case only |
| The floor a "lying" challenge puts under its teller | Kept, scaled by the case's weight, so it fades with the case |
| Source doubt, rejected cards, hearing weights, relays, the Muddler | Unchanged |
| Belief to suspicion (scale, confidence, lean, hard proof), who to hang first, votes | Unchanged, fed the new chance |
| The circumstantial hub (stage 2) | Unchanged |
| The reasons NPCs give | Unchanged code. **Known gap:** a reason may cite a pairing the new model didn't weigh. Polish, after it works end to end |
| The reply to a presentation | Unchanged code. The stance follows the belief change (Phase 1 fix 4), so it follows the new model |
| The bot | Unchanged |

### 8. Where it plugs in (for Bailiff)

- **New module `workshop/connections.gd`.** Pure: prepared view, case and listener in; each person's chance and a breakdown (items, core, cases, what each added) out.
- **One call site:** `Jury._consequences_eval`, on the refresh path only. With the switch on, the module's chance replaces `ev.people[id].posterior`.
- **Memory** in `n.workshop_state.connections`: core membership, the dawn suspicion, cached values, NPC nomination cases.
- **The breakdown** goes in the `workshop_ownership` trace event, for the why tool.
- **The prototype tool becomes a harness over the module,** so offline and in-game numbers can't drift apart. The check for that move: the tool's output on seeds 900 and 902 is the same before and after.

### 9. Build order

Small PRs; Bailiff merges. Every PR: golden identical with the switch off, its own test suite with the switch on, and a handoff-log entry.

| PR | Adds | Checked against |
|---|---|---|
| 1 | The switch, the module, single-card values, normalising. **Merged: PR #141** (Codex's fix: a Workshop listener in persistence mode keeps the model's result) | The prototype's single values on seeds 900 and 902 |
| 2 | Built-in pairings and the three declaration rows. **Merged: PR #144** (Codex's fix: a day's Augur readings share its sightings, with work schedules as context) | #135's and #139's test cases read through a night: same direction, sizes reported. The Hexer row measured first |
| 3 | The core. **Open: PR #145** | The prototype's core members per listener and day |
| 4 | Stored cases: the player's and NPC nominations', fading, merging, challenges inside | The prototype's with-and-without-the-case numbers |
| 5 | ~~Normalising~~ (moved into PR 1) | The prototype's final beliefs, checked at step 4 |
| 6 | Caching | Beliefs identical with the cache on and off; timing against today |

- **A suggestion for Bailiff:** move normalising into PR 1. It is small, and every later PR's numbers could then be compared with the prototype's final beliefs. Without it the model isn't playable until PR 5. *(Bailiff: agreed, normalising goes in PR 1.)*
- **Rebase point:** the relay fix landed as #140 (main `559a201`).
- **Rebase** onto main once the Medium-relay fix lands. Measurements are taken after it.
- **End to end:** the seven criteria rerun through the module on fresh passive seeds, and on a new human playtest log if there is one (12926 only replays on its old build). Then Tally's paired cells.

### 10. What is new since the prototype

Each of these was not in the tested prototype, so each gets its own check:
1. #135 and #139 inside a night (step 2).
2. The Hexer-declared row (step 2).
3. Night Watch and Lamplighter readings seeding the core, now always on (step 3). The prototype measured it as a small change.
4. Firsthand proofs staying certain (step 3).
5. "Misled" and "failed gift" challenges inside a case, and the "suspicious" premise halving a case (step 4).
6. Values measured against dawn suspicion (step 6).
7. **Votes are real now.** The prototype recomputed votes on the log's states. In game a changed vote changes what happens next, so outcomes will diverge from today's. That's what Tally's cells measure.

### 11. Questions for Michael

**Decided (Michael, Nov 12): the recommendation on all four.**
- The Hexer's day evidence stays off until "Hexer" is declared.
- Headline reading is off with the switch on.
- A night on which the NPC was wrongly sighted seeds its core, measured at step 3 before it merges.
- Presenting a case again on a later day restores its weight, never above full.

1. **Before a declaration, does the Hexer's day evidence count?**
   - **(a) Not until "Hexer" is declared.** This is the design as written and what the prototype tested. Each declaration then switches on its own evidence: Walker strings the nights together, Hexer turns on the day logs.
   - **(b) At half weight, once.** This is closest to today.
   - **I recommend (a).** Its cost: on a script with both kinds, a town with no declaration loses the day evidence it has today. Dynamic scripts deal one kind by default, so that only happens on scripts built with both.
2. **Headline reading off with the switch on?** It depends on Insight, and Insight is out for v1. I expect single-card values to do most of its job, since a card read alone is already taken close to its word. **I recommend off.**
3. **Should a night on which the NPC was wrongly sighted seed its core?** It is firsthand knowledge: "he lied about seeing me." The NPC would then weigh that sighter's other statements against the lie. Without it the liar's readings still count at face value. **I recommend yes.** It is new, so I'd measure it at step 3 and report before it merges.
4. **Does presenting the same case again on a later day restore its weight?** Today a repeat does nothing. With fading, a repeat could bring the case back to full weight, never above it. **I recommend yes:** the town is being reminded, and it costs the player a presentation.

## Results: Phase 6 step 1, and the prototype on current main (Lantern, Nov 12 evening)

**In short:** step 1 is open as PR #141 and golden is identical with the switch off. The prototype still holds on main after the three recent fixes. Profiling shows where the cost is: setting up each new combination of cards, not weighing it.

### Step 1: the switch, single-card values and normalising (PR #141, merged Nov 12)

Branch `claude/connections-solo`, on main `559a201`.

- **The switch:** `Tuning.Workshop.CONNECTIONS`, off. `autoplay.gd --connections` and `golden_capture.gd --connections` turn it on for a run; autoplay's mode name gains `_connections`.
- **`workshop/connections.gd`:** every held card counts at the value it has alone, then one common shift so the chances sum to the evil count.
- **One call site,** `Jury._consequences_eval` on the refresh path. Headline reading is off with the switch on.
- **A finding while building:** today's "before" side leaves out the public record (deaths, executions), and the judge on no cards includes it. So the model measures each card against the judge on no cards, and keeps today's "before" side for the shift that becomes suspicion. Otherwise the public record would stop counting.

| Check | Result |
|---|---|
| Golden, switch off | Identical to `baseline_6a22cac` on all five seeds |
| Golden capture, switch on (seeds 900 and 692) | Runs with no script errors, and diverges as it should |
| The prototype tool before and after moving its judge into the module (seeds 900 and 902) | Identical output |
| In game against offline on the same listener states (22 listener-dawns, 3,771 card-person values) | Agree to within 0.00001 |
| `test_connections` and seven related suites | Pass |

- **Not ready for play yet:** a night's cards aren't read together until step 2.
- **Slow when on:** one judgement a card, so golden seed 692 took 62 s against 17 s. Caching is the last step.
- No listener state in these seeds had a card rejected from its own knowledge, so that exclusion is only covered by the test's comparison of card lists.

### The prototype on main `559a201` (after #135, #139 and #140)

The offline tool as merged, threshold 0.4, fade 0.5, Night Watch and Lamplighter readings seeding the core. Seeds 900, 902 and 910–929 were regenerated on `559a201`, so these are different games from the Nov 11 run and only the columns within this table compare. Every vote in all 22 replays matches its log.

| | 7 NPCs (910–919) | 10 NPCs (920–929) |
|---|---|---|
| Separation, day 3: today / prototype / connects everything | 0.36 / 0.37 / 0.39 | 0.33 / 0.32 / 0.38 |
| Separation, day 4+ | 0.50 / 0.52 / 0.50 | 0.39 / 0.44 / 0.51 |
| Top suspect is evil, day 4+ | 90% / 81% / 90% | 65% / 88% / 86% |
| Good votes flipped | 12 of 180 | 40 of 416 |
| Vote outcomes changed | 3 of 68 | 10 of 103 |
| … evil nominees put on the block / taken off | 1 / 1 | 7 / 1 |
| … good nominees put on the block / taken off | 0 / 1 | 0 / 2 |
| Votes unanimous but the nominee: today → prototype | 0 → 0 | 0 → 0 |
| Votes where only the nominator says yes | 25 → 26 | 30 → 27 |
| Evil nominations that carry | 7 → 6 | 17 → 18 |
| Largest set judged together, share of held cards: median, largest | 33%, 69% | 35%, 63% |
| Listener-dawns from day 3 with a joined card | 21 of 34 | 34 of 85 |
| Seedless listener-dawns from day 3 | 7 of 34 | 19 of 85 |
| Stored cases still counting per listener: median, most | 3, 6 | 3, 7 |
| Recomputing at a dawn | Identical | Identical |

- **No collapse, and vote shapes hold.** The prototype reads these towns about as well as today's model, and a little better late in 10-NPC games.
- **At 10 NPCs the changed votes go mostly one way:** seven more evil nominees reach the block and one fewer; two fewer good nominees do. One sample of ten games. *(Reworded Nov 12: the town being right isn't by itself the aim.)*
- **The largest set** stays under the criterion's median of 50%. The largest for any single listener is 69%; I haven't traced which listener that is.
- Criteria 1 to 3 are about playtest 12926, which only replays on its old build, so they weren't rerun.

### Where a judgement's time goes

Passive seeds 902 (10 NPCs, 15,120 possible worlds) and 900 (7 NPCs, 1,050 worlds), single judgements with nothing kept.

| One reading, 10 NPCs | Time |
|---|---|
| Sorting the worlds into groups for this card set (`CaseEval.compile`) | 3.7 ms |
| Role checks for those groups (`_class_fits`, with and without the cards) | 5.0 ms |
| The weighing itself | 0.35 ms |
| The prototype tool's own Demon-chance tally (script code; the game doesn't need it) | about 3.3 ms |

- **The price is setup, and it barely depends on the cards:** no cards 10 ms, one reading 12.7 ms, all 31 held cards 41 ms. At 7 NPCs one reading costs 3 ms.
- **A kept judgement costs 0.24 ms.**
- **In game a new combination should cost about 9 ms** at 10 NPCs, so a new card (two judgements) about 18 ms. A meeting refresh with six new cards would be about 110 ms. That is a projection from these timings.
- **`CaseEval`'s compile cache holds 32 entries** and clears itself when full. A refresh that makes 40 to 55 judgements overflows it, so the model's own cache has to sit above it.
- **A lighter path for single-card values looks possible** (no grouping needed for one card). Not sized; it touches the C# solver, so it is a question for the caching step.
- **Today's refresh may have got slower.** In seed 902 from day 3 it measures 62 ms at the median, against 29 ms on Nov 11. These are different games, so I haven't traced whether the cards or the code changed.

### Cache and cost on these seeds (the tool's estimate, as before)

| | 7 NPCs | 10 NPCs |
|---|---|---|
| Items kept between a listener's refreshes in a day | 73% | 78% |
| New since the last refresh | 17% | 13% |
| Worst drift of a kept item (log-odds) | 0.32 | 0.39 |
| Refresh cost counting redone items, median / 90th percentile | 24 / 72 ms | 169 / 826 ms |
| Today, same listener-days | 11 / 20 ms | 63 / 133 ms |

The 10-NPC timings were taken with two runs in parallel, and they include the tool's Demon tally, so they overstate both sides.

## Results: Phase 6 step 2, built-in pairings and the declaration (Lantern, Nov 12 late)

**In short:** step 2 is merged as PR #144, and golden is identical with the switch off. The two recent fixes work inside a night. The Hexer reading works, but in passive games a declaration changes little, and the Hexer's day evidence leans slightly away from the true Hexer.

**A note on wording (Michael, Nov 12):** the town being right is not by itself the aim; sometimes it needs to be wrong so the player can lead it. The figures below say what changes, not whether the change is good.

### What was built (PR #144, on main `8be9681`)

- **Pairings** (`Connections.items`): a night's movement cards, an Augur reading with that day's sightings, a Psychologist reading with its statements, and a trace with the profile cards each count once. Claims, confessed secrets and profile cards are context.
- **The declaration decides how movement is read** (`Connections.row`): no declaration, each night by itself; Walker, one always-on movement connection; Hexer, each night by itself plus one always-on day connection.
- **The Hexer factor is read in one place.** The factor (kills against day logs, daytime sightings and haunts) fires on any movement or day card, so each night's pairing would have counted it again. Every judgement the model makes now runs with the factor off. The day connection's value is the day cards judged with the factor on, minus the same cards with it off.
- **`CaseEval`'s compile key** gains "hex_off" when the mix has a Hexer and the factor is off. In play the factor is on and the key is unchanged.
- **The offline tool** takes its grouping from the module and gains `--declare hexer`.

| Check | Result |
|---|---|
| Golden, switch off | Identical to `baseline_6a22cac` on all five seeds |
| In game against the offline tool on the same listener states: 16 Hexer-forced two-kind passive games and seeds 900 and 902 | 210 listener-dawns, about 29,000 values, agree to within 0.00001 |
| The offline tool before and after the move (seeds 900 and 902) | Identical output |
| Golden capture, switch on | Runs with no script errors |
| The fast suite list | 52 of 52 pass |

- **The comparison found a gap in the offline tool,** not the game. The game leaves out a card the listener rejects from its own knowledge (here a Night Watch list that wrongly names it); the tool kept it. Three of the 16 logs differed by up to 1.9 log-odds on one night. The tool now leaves such cards out too. This is the real-data check of rejected cards that step 1 lacked.

### The two recent fixes inside a night

The real games from `test_self_sighting`, read night by night:

| Case | Today | Connections | Connections without the sighter contest |
|---|---|---|---|
| #139: Odette, wrongly sighted by the evil Constance, on Constance | 0.66 | 0.42 (the night leans +0.80 on Constance) | 0.22 |
| #135: the bystander Isolde on Constance, the sighter | 0.25 | 0.53 | 0.36 |
| #135: Isolde on Odette, the subject | 0.40 | 0.57 | 0.74 |
| The Sleepwalker Edda on the honest Constance | 0.22 | 0.15 | |
| #140: Constance on Hollis, who invented a relay | 0.93 | 0.82 | |
| #140: Fenwick and Jory on Hollis | 0.70, 0.50 | 0.41, 0.28 | |

- **Both fixes work inside a night,** in the same direction as today.
- **Odette's 0.42 against today's 0.66 is the missing core.** Alone, her own Archivist reading lowers Constance (−0.62). Next to the night she was wrongly sighted, it stops doing so: all her cards together give 0.69. Weighing a listener's own reading next to such a night is step 3, and it is the "wrongly sighted night seeds the core" decision.
- **Fenwick and Jory are what "connects little" looks like.** Today they reach 0.70 and 0.50 on the bluffing Hollis unaided. Under connections they reach 0.41 and 0.28 read night by night, and 0.22 and 0.20 read as the walker-only script that game is. The combination that exposes him is left for a case to make.
- **A listener wrongly sighted on two different nights is rare:** 1 of 410 listener-dawns over 36 passive games (3 had any such sighting). In that one, the same sighter named her both nights.

### The Hexer reading, measured

16 passive games with the Hexer forced onto a two-kind script (seeds 940–949 at 7 NPCs, 950–955 at 10), as played with no declaration. Each listener state was then read offline under each declaration, with the prototype's core and stored cases. The figures are the mean chance on the true Hexer.

| | No declaration | Hexer | Walker (the wrong call) |
|---|---|---|---|
| 7 NPCs, day 3 (27 listener-dawns) | 0.48 | 0.48 | 0.44 |
| 7 NPCs, day 4+ (20) | 0.64 | 0.66 | 0.56 |
| 10 NPCs, day 3 (28) | 0.45 | 0.44 | 0.45 |
| 10 NPCs, day 4+ (34) | 0.70 | 0.73 | 0.67 |
| Today's model, every card together, 7 NPCs day 4+ | 0.54 | 0.58 | 0.45 |
| Today's model, every card together, 10 NPCs day 4+ | 0.54 | 0.56 | 0.54 |

- **Declaring changes little here.** A Hexer declaration adds 2 to 3 points on the Hexer from day 4. The wrong call costs 8 points at 7 NPCs and 3 at 10. That is about what today's model does on the same cards, so the expectation that a declaration would matter much more under connections isn't met in these games.
- **The day connection leans slightly away from the true Hexer:** −0.12 log-odds on average at 7 NPCs and −0.04 to −0.09 at 10. It is present for every listener.
- **Today's model shows the same.** With every card judged together under a Hexer declaration, the Hexer sits at 0.58 with the factor on and 0.64 with it off (7 NPCs, day 4+). So what a Hexer declaration gains comes from no longer reading the Demon as a walker, not from the day evidence.
- **Not traced:** why the day evidence leans that way. These are passive games, with no player gathering day logs, so it may differ in play.

### Not in this step

The core and stored cases (steps 3 and 4), then caching. The switch isn't ready for play.

### Codex's review at merge (Bailiff, Nov 12 late)

Two fixes to the Augur pairing, on the #144 branch:
- **All of a day's Augur readings are one item with that day's sightings.** Before, the first reading took every same-day location card, so a second one (an honest reading beside a bluff) lost the day evidence by card order.
- **Known work schedules are the Augur item's context.** `Solver.augur_day_spec` reads them as day evidence, and they now make the item on their own when there are no sightings.

`test_connections_pairings` checks both, in either card order.

## Results: Phase 6 step 3, the core (Lantern, Nov 13)

**In short:** step 3 is open as PR #145, and golden is identical with the switch off. An NPC's own knowledge is now weighed together with the cards that bear on it. The game and the offline tool agree on every state checked. The wrongly sighted night (question 3) is rare in passive play and changes little there; on the known framed game it takes the framed NPC's view of her accuser from 0.52 to 0.66, which is today's figure. With the switch on a refresh now costs about 4.5 times today's; caching is still the last step.

### What was built (PR #145, on main `437e29e`)

- **Seed:** every card or pairing holding something the NPC knows firsthand:
  - its own readings;
  - a sighting of it on a night it knows it spent at home (question 3).
- **A night seeds the core** when it holds the NPC's own Night Watch or Lamplighter report, or such a sighting. Under a Walker reading the movement connection does instead. The Hexer's day connection never does.
- **Joining:** every other card or pairing is tested against the seed only, and joins at 0.4 for any one person. The always-on connections are never tested.
- **The core adds** what its members say together beyond their own values.
- **Memory:** the core is rebuilt on a new day and when the firsthand cards change. Otherwise its members stay for the day, and only a card heard since is tested. A presentation can't edit it.
- **Firsthand proofs stay proved.** If the firsthand cards alone put someone within 0.5% of 0 or 1, that person stays there, and the others share what is left of the evil count.
- **With the switch off** none of it exists, including the memory.

**Two things differ from the prototype:**
1. **The seed is a little wider.** A pairing that holds one of the NPC's own readings is a seed: its own Psychologist reading with its statements, or its own Augur day. The prototype only seeded own readings that sat alone, so a Psychologist had no seed.
2. **The test leaves out what a pairing's context says alone.** With a seed that has no context, which is all the prototype had, it is the prototype's test exactly.

| Check | Result |
|---|---|
| Golden, switch off | Identical to `baseline_6a22cac` on all five seeds |
| The offline tool with the prototype's seed (`--legacy-seed`), against the tool before this change (seeds 900, 902, 910, 911) | Identical output: 896 cores and every number |
| In game against the offline tool on the same listener states, at every dawn and vote (10 passive and 4 Hexer-forced logs) | 482 listener-moments, 389 with a seed, 244 reusing the day's members. Seeds and members agree in all; chances agree to within 0.0000001 |
| Golden capture, switch on (seeds 692 and 900) | Runs to the end with no script errors |
| The fast suite list | 53 of 53 pass (`test_connections_core` is new) |

### The wrongly sighted night (question 3)

**In passive play it is rare, and changed little.** 3 listener-dawns of 469, in 29 passive games, held a sighting of the listener on a night it was home. With and without the seed, no chance there differed by more than 2 points. In one game the night joined the core by the test anyway. In the other the movement connection added little next to the listener's own reading.

**On the known games** (`test_self_sighting`), read as the walker-only scripts they are:

| Listener on the sighter | Today | With the seed | Without it |
|---|---|---|---|
| Odette on Constance (evil; she invented the sighting) | 0.66 | 0.66 | 0.52 |
| Edda, a real Sleepwalker, on Constance (good; she saw her truly) | 0.22 | 0.18 | 0.15 |
| Constance on Hollis (evil; he invented a Medium relay about her) | 0.93 | 0.92 | 0.92 |

- **Odette is the case the decision was for.** Under a Walker reading the movement connection is always on and never tested, so without the seed her own Archivist reading never meets the night she was wrongly sighted. With it, her chances match today's on every person, to two decimals.
- **The other side of it:** a real Sleepwalker holds an honest sighter 3 points higher (0.15 to 0.18; today 0.22).
- **Read night by night** (no declaration), the seed made no difference for Odette: that night joins her core by the test either way (0.66 both ways).

### What cores look like in passive games

22 passive games (seeds 900, 902 and 910–929; walker-only scripts), read offline at every dawn. Stored cases are left out, since they are step 4.

| | 7 NPCs (11 games) | 10 NPCs (11 games) |
|---|---|---|
| Listener-dawns from day 3 | 37 | 94 |
| … with no seed | 7 | 10 |
| … with at least one joined card | 23 | 49 |
| Cards and pairings tested from day 3 that join | 11% of 410 | 6% of 1,836 |
| Listener-dawns whose seed includes the movement connection (all days) | 20 of 132 | 20 of 234 |
| Largest set weighed together, share of held cards: median, largest | 35%, 69% | 35%, 63% |
| Separation, day 4+: today / step 3 / connects everything | 0.47 / 0.50 / 0.47 | 0.39 / 0.45 / 0.53 |
| Someone proved by a firsthand reading (listener-dawns) | 3 | 3 |

- **Against the prototype's seed, 7-NPC games don't change:** the seed differs in 3 of 132 listener-dawns, the members in none, and no chance by more than 2 points.
- **At 10 NPCs the wider seed gives Psychologists a core.** On seeds 920–929, listener-dawns from day 3 with no seed go from 19 of 85 to 9, and those with a joined card from 34 to 45.
- **The large sets are the movement seeds.** A listener whose seed includes the movement connection weighs a median of 55% of its cards together (up to 69%); the others 34% (up to 53%). That answers the open point from step 1 about the 69%.
- **The proofs** are single strong readings: Agnes's Rumormonger reading alone puts Hollis under 0.5%, and Greta's Dowser reading does the same for Odette.
- **Distance from today's beliefs,** from day 3: 55% of listener-on-person chances are within 5 points of today's, and 17% differ by more than 20. The largest gaps are whole reversals (Greta on Odette, seed 929: 0.88 today, 0.04 under connections). Not traced, and not split between this step and the two before it.

### Cost

Golden capture on the same machine, per belief refresh:

| | Today | Step 2, switch on | Step 3, switch on |
|---|---|---|---|
| Seed 692 (10 NPCs) | 92 ms | 293 ms | 411 ms |
| Seed 900 (7 NPCs) | | 61 ms | 69 ms |

- **A day's first refresh tests every item against the seed:** about 50 judgements for a 10-NPC listener on day 3, against about 28 later that day, when the core is reused.
- **A seed that includes the movement connection is the expensive case:** every test then carries every movement card.
- This is the cost the spec said I would report before optimising. Nothing is kept between refreshes yet; that is the caching step.

### Not in this step

Stored cases (step 4), then caching. The switch isn't ready for play.

## Open items (tracked)

| Item | Owner | Status |
|---|---|---|
| **Challenge accepted whichever side lies** | Quill, Bailiff | **Fixed: contest, PR #132 merged** (golden unchanged). **True challenges that rarely land: graded-test fix merged, PR #142** (content-only after Codex's review, and Marked registrations excluded; "Challenge sides"). A lying challenge on true grounds lands 40% at 7 NPCs and 27% at 10, up from 20%; false grounds land no more often. An honest reader already under suspicion: 19% → 35%, accepted by Michael as a real cost of a mistaken challenge. **Honest-mistake sample:** misled and failed gift still land 3–12% there (measured on the first build); a challenge rule can't separate an honest mistake from a lie; open for Michael |
| Framed defenders contradicted themselves ("I was out because I'm the Medium", then "I was home") | Bailiff | **Fixed: PR #134, merged** (golden unchanged). From playtest 30987 (build `9fad758`): the good Medium Dorian, framed by Merrin's fake sighting, hanged 9–1 on day 2. A good defender sighted on a night spent at home now gives their night account instead of explaining an outing |
| **Framed stay-at-homes: a sighting against an own home alibi convicts the alibi-giver** | Bailiff | **Fixed: PR #135, merged** (golden `baseline_bd1b404`). See "Sighter contests" under Phase 1. **Tally's cell:** the Phase 1 drop is fully recovered (under Phase 1) |
| Evil's Gravedigger bluff ignores what the town believes (Hollis vouched for the hanged Dorian, whom the town thought evil, and was hanged next) | Bailiff | **Fixed: PR #136, merged** (golden `baseline_f40ca05`). The hanging vote's yes share (the player's vote included) sets how sure the town was. An evil Gravedigger calls the hanged a Minion with chance 0.05 + 0.2 × confidence + 0.75 × certainty: about 9 in 10 after a unanimous hanging, about 1 in 4 after a 4–3 one. Otherwise it confirms their claim. Not yet in a sweep |
| The demon-type declaration's "right kind beats wrong kind" in tests | Bailiff | **Reported, not checked** (#136), until the bot declares and a sweep can measure it (Phase 5). On six games it follows listeners' bounded views: in walker seed 13, Edda holds the walking Demon at 0.37 declared walker and 0.85 declared Hexer, but 0.67 and 0.93 reading every card she holds. Over 21 games, Hexer declarations helped where they mattered in 6 of 7; walker declarations in 2 of 4 after #135, against 6 of 6 before |
| Night-walking roles' own posts (Night Watch, Warden, Medium, Lamplighter) | Bailiff | **Checked, fine:** a report of where the reporter stood is hard only when they're good, and carries no weight when they're evil |
| Did fix 3 cause the ~5-point drop? | Tally | **Yes** (under Phase 1): the revert reproduces Phase 0 exactly. The added hangs are good stay-at-homes framed by evil's fake sightings, not night-walkers |
| Fading cases, traces-touched rule, cached cost | Lantern | **Done, merged (#129).** Fade 0.5 chosen. Open: cost when redone items are counted; nine live cases per listener (no action yet) |
| Thin cores at 10 NPCs (0.3?) and seedless Night Watch / Lamplighter listeners | Lantern | **Decided:** keep 0.4; Night Watch and Lamplighter readings seed the core |
| The core test only checks pairs (Hollis didn't pull Lian's reading in) | Lantern | **Confirmed:** a three-card test would have pulled it in (0.23 → 3.8). No fix proposed |
| ~~The Hexer factor lowers the actual Hexer~~; #178 lowers Hollis on Kiran | Lantern | **Explained** (rerun section) |
| The refresh vs judge gap on Kiran (61% → 29%, 12926) | Bailiff | **Doesn't reproduce on main** ("Decisions, Nov 12"): the update and the judge agree within 2 points over 402 pairs in six bot games. Challenges are untested (the bot never challenges) |
| A held Medium relay reads as proof its relayer is a good Medium | Bailiff | **Fixed: PR #140, merged** (golden `baseline_6a22cac`). Evil relayers were under 2% in 43 of 47 listener readings; now mean 0.69. Genuine Mediums are unchanged ("Decisions, Nov 12") |
| A Night Watch list that wrongly names the listener | Bailiff | Open. Each name is scored as an independent slip, so keeping the list cleared the watch (−0.36) and cast the rest of the list as out. `SourceDoubt` still voids that night's list. Fix: a list that's wrong about the listener is suspect as a whole |
| Sleepwalker self-doubt scaled by confidence | — | Backlog (Michael, Nov 12); 10% flat for now |
| Traces with profiles alone; bluffed readings for true-grounds challenges | Quill | **Done** ("Challenge sides"): profiles add about nothing to a presented trace; a constructed bluff sample is in the harness |
| Archivist pair + clearing reading weaker than its logic | Quill | **Explained:** three uncertain links multiply; not a bug |
| The bot declaring the demon type | Bailiff | **Built: PR #137, merged** (Phase 5). **Tally's cells (under Phase 5):** about +3.5 on Hexer games (z 1.5); the bot calls Hexers right 54% of the time; cross-check cases fire in 13% of games and change about nothing |
| The declaration's default (walker by default?) and the bot's Hexer call | Michael, Bailiff | On hold for the connections build and Michael's playtests ("Decisions, Nov 12") |
| How to adjudicate a muddled card | — | Later |
| Brute kills scored as hexes on custom scripts | — | Later |

## Owners

- **Bailiff:** Phase 0 logging, Phase 1 fixes 2 and 4 (done); golden and merge order; the PR queue (cleared: #114, #118, #121, #125, #127, #128, #130, #97); the demon-type declaration (Phase 2, done: #131); merged #132 and #129 with Codex's fixes, and #134, #135 and #136 from playtest 30987 (Nov 11); Phase 5 (the bot's cross-check cases and declaration: #137, merged Nov 12); self-sightings (#139), the Kiran check and the relay fix (#140) (Nov 12); merged #141 (connections step 1) and #143 (a gift-holder who owned a night out no longer refuses it in private, Steward's A1) on Nov 12; merged #144 (connections step 2) and #142 (the graded test) with Codex's fixes, Nov 12 late; next the connections PRs as Lantern opens them.
- **Quill:** the read-everything gap (done); Phase 1 fix 3 (done, #124); Phase 3 (done, PR #125); the challenge diagnosis and fix (done, PR #132, merged); the Phase 5 pair ranking (done); the graded test for role-checked gifts (PR #142, approved by Michael; content-only fix after Codex's review; merged as #142, Nov 12). The honest-mistake sample (done, under "Challenge sides").
- **Tally:** the silent-bot cells (done: PR #127, results above); the Phase 1 paired check (done, under Phase 1); the #124-revert cell (done, under Phase 1); the #135 cell (done, under Phase 1); the Phase 5 paired cells (done, under Phase 5).
- **Lantern:** the why-tool follow-up (done: PR #121, merged with Codex's two fixes; it adds what each challenge, the citing and each view change did); the Phase 4 prototype spec (settled) and build (PR #129, tools only): the late decisions are built, all seven criteria pass, merged Nov 11. Phase 6: the in-game spec is written ("Phase 6 spec") and Michael has accepted its four recommendations (Nov 12). Step 1 is merged (#141). Step 2, the built-in pairings, is merged (#144). Step 3, the core, is open as PR #145; next stored cases (step 4).
