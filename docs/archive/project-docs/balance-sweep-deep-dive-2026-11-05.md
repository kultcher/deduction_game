# Balance sweep deep dive, 2026-11-05

Claude-Bailiff. A second pass over Tally's overnight sweep (11,000 dynamic-script games,
`main` at `a0d9641`, which includes patch 015). This pass uses the raw records from
`sweep-results/run-41978776824` and `sweep-results/run-41999201334`. Tally's report
(`claude/balance-sweep-report-2026-11-05.md`) has the headline tables. This doc covers
what the raw records add.

## 1. The Demon's bluff decides more games than any role in play

Good win rate by the Demon's bluff (every Demon claims publicly):

| Demon bluffs | 7 NPCs | 10 NPCs |
|---|---|---|
| Lamplighter | **10%** (n=451) | **3%** (n=302) |
| Medium | 29% | 18% |
| Confessor | 42% | 38% |
| Night Watch | 44% | 45% |
| ... median bluff | ~50% | ~50% |
| Archivist | 69% | 61% |
| Gravedigger | 62% | 62% |
| Magistrate / Seer | 55% / 50% | 65% / 66% |

**The safe bluffs are roles that walk at night.** A walker's claim explains every night
sighting of the Demon on its way to a kill:

- The Lamplighter walks the whole lamp route, so it has a reason to be out anywhere.
- The Medium visits a victim's hearth, which is the crime scene itself.

**The worst bluffs walk nowhere,** so a single night sighting breaks the claim.

**This also inflates the Lamplighter's measured strength.** A role in play can't be
bluffed. With demon-Lamplighter games removed, the Lamplighter-in-play effect drops:

- 7-bot: from +9 to +5.5.
- 10-bot: from +14 to +9.

It is still the best gift.

**Fix directions:**

1. Make walker claims checkable. The Lamplighter's route could be fixed and public, so
   being seen off-route breaks the claim. Its count could be cross-checked against other
   sightings.
2. Have the solver test a claimed walker's sightings against that role's legal movement.
   C# `LiveActivity` already models the real Lamplighter's route, but nobody checks a
   claimant against it.
3. Leave walker bluffs out of the Demon's bluff pool.

## 2. Evil-nominated hangings drive the losses

Execution accuracy (share of hanged who were evil) by who nominated:

| Cell | Evil-nominated | Good-NPC-nominated | Bot-nominated |
|---|---|---|---|
| 7 passive | 6–15% | 58–76% | — |
| 10 passive | 6–19% | 53–82% | — |
| 7 bot (insight 1.0) | 7–20% | 57–89% | 57–64% |
| 10 bot (insight 1.0) | 5–20% | 61–76% | 59–70% |

- **Good NPCs' successful nominations are the most accurate in the game,** better than
  the bot's.
- **In passive games, 73–75% of wrongful hangs come from an evil nomination** that the
  town carried.
- **Late in the game the town does worse than chance.** Measured against the share of
  evil among the living:
  - Day 4+ at 7 NPCs: lift 0.3–0.6.
  - Day 5+ at 10 NPCs: lift 0.3–0.6.
  - Mechanism: evil makes up roughly half the living by then, and evil nominations carry.

The lever is how readily good NPCs vote for an evil nominee's target. Whether they
discount the nominator matters most. The Muse game showed the same thing: Edda's two
wrongful nominations passed 9–1 and 7–1.

## 3. The bot nominates too much

- Bot-nominated hangs are 59–64% evil, against 70–80% for good NPCs' nominations.
- Half the wrongful hangs in bot games are the bot's own nominations: 42–55%.
- **"Identified but lost" (20–25% of bot games):**
  - The bot named the right Demon but lost.
  - Along the way it hanged 0.6–0.84 good people on its own nominations.
  - At 10 NPCs, 40% of these are Scion games (the Demon hanged, the Scion rose).

Suggestion for M4: raise the bot's bar for nominating, and back a good NPC's nomination
when one is up.

## 4. Role effects with the confounds removed (logistic regression)

All roles, minions and the secret are entered together, per size and mode. Effects are in
win points at the cell mean.

- **Town gifts** are centred on the average gift.
- **Minions** are relative to the Revenant.
- **Secrets** are relative to Lovers.

**Town gifts that hold up:**

| Gift | 7 bot | 7 passive | 10 bot | 10 passive |
|---|---|---|---|---|
| Lamplighter | +10 | +9 | +17 | +15 |
| Night Watch | +5 | +13 | +7 | +11 |
| Confessor | +4 | +6 | +7 | +5 |
| Warden | +4 | +11 | +3 | +4 |
| Dowser | +7 | +6 | +1 | +4 |
| Gravedigger | −8 | −11 | −5 | −5 |
| Archivist | −5 | −3 | −5 | −6 |
| Sexton | −5 | 0 | −6 | −4 |
| Executor | +2 | −8 | −9 | −1 |

**The Gravedigger survives the controls (about −7 on average).** It is weak even when it
reports:

- Win rate in games where it reported: 48% (7 bot) vs 55% without a Gravedigger.
- Games with it have more wrongful hangs and fewer evil ones.

Hypothesis: its "the executed was the Clerk" report doesn't feed suspicion of whoever
pushed that hanging. That's the same missing link as the dying words in the Muse game.
This is worth a targeted check.

**Minions** (relative to the Revenant):

| Minion | 7 bot | 7 passive | 10 bot | 10 passive |
|---|---|---|---|---|
| Breathstealer | +9 | +17 | +8 | +12 |
| Poisoner | −4 | +4 | −4 | −5 |
| Scion | −3 | +6 | −17 | −9 |

**Delusional, relative to Lovers:** −14 (7 bot), −21 (7 passive), −5 (10 bot), −12 (10
passive). It is the strongest single effect after the Demon's bluff. The other secrets are
within noise.

## 5. Scion

- At 10 NPCs the Scion rises in 41–52% of its games.
  - The Demon is hanged at a median of 7 alive, so the five-alive gate almost never
    blocks it.
  - It amounts to "catch the Demon twice."
- Games where it rose are won *more* often (49–55% vs 26–34%), but that's selection:
  rising requires the town to have caught the Demon once.
- **Options:**
  - Scale the gate with size: six or more alive at 10, or "more than half the starting
    town."
  - Let a successful rise show some visible tell.

## 6. Sexton

- **The Sexton is the most-hanged good role per day alive at 10 NPCs:** 10.7% per day.
  - It is tied with the Archivist and Veteran at 7.
  - 35% of 10-NPC Sextons are hanged while good.
- This fits the solver gap from patch 015: the toll-night walk through every parish isn't
  modelled, so a Sexton seen out looks like unexplained walking.
- Fix: a Sexton route case in C# `LiveActivity`.

## 7. Why the passive town does better at 10 than at 7

- The 10-NPC deal has more night-walkers: 3.5 vs 2.4.
- The two minions get hanged more often: 1.27 vs 0.70 evil executions per game.
- More walkers means more sightings (Tally's night-walker table shows the same at 10).

## 8. Health

- **There is one bug, not two.**
  - The C# `IndexOutOfRangeException` at `CaseEvalKernel.cs:890` (`f[3*c + states[at+c]]`)
    is the root.
  - "Nonexistent function 'CaseEvalEvaluatePosterior'" is Godot reporting that the C#
    call threw. The method exists (`SolverBridge.cs:682`).
  - The `people` and `effects` key errors are the cascade after that.
  - Likely cause: a state or factor array size mismatch after a night kill.
  - Repro: seed 101032, 10 NPCs, passive, `--dynamic`.
- **13 stuck games**, all bot games, are worth a look when M4 touches the bot.

## Priorities, as I'd rank them

1. The walker-bluff hole (Lamplighter, Medium): the biggest swing, and evil will find it
   more as the bot improves.
2. Good NPCs' willingness to carry evil nominations, especially late.
3. The Scion gate at 10 NPCs.
4. Delusional strength: consider making the readings less confidently wrong, or giving a
   tell.
5. The Sexton route model, and the Gravedigger's report feeding suspicion of the nominator.
6. The `CaseEvalKernel` crash, a small fix.
7. M4 bot nomination discipline: these numbers measure today's bot.

---

## Update, Nov 5 evening: what landed (PR #74)

- **Lamplighter bluff: fixed.**
  - The root cause wasn't sightings. `CaseEval.chance_content` scored each fake lamp count
    as a near-impossible coincidence for a liar, so every report counted about 7× toward the
    claimant's honesty.
  - It now uses the share of worlds where the content holds.
  - Good wins when the Demon bluffs Lamplighter:
    - with the bot: 5–19% → 51–58%;
    - passive: about 0% → 29–37%.
- **Michael's decisions on section 2 and 3:** evil steering the town is a feature, not
  something to fix. Good NPCs at 70%+ accuracy may even be too high. The design target
  (`DESIGN.md` › Balance target) is a skilled player naming the Demon in 85–90% of cases and
  winning 70–75%. The oracle sweep (`claude/oracle-sweep-plan.md`) measures the ceiling.
- **The vigil as evidence by exclusion:** a player vigil that should have seen a claimed
  walker is now about 10:1 against the claim. It's soft by design, because the town doesn't
  know the player can't be wrong.
- **Still open:**
  - **The Night Watch bluff got somewhat stronger.** Bound walker claims explain night
    sightings. Michael's same-night rule is the fix: several blocks on one night support a
    route; scattered sightings across nights don't.
  - **The Medium bluff is unchanged.** Next: check how the fake Medium's relays from the
    dead are credited.
- **A/B:** run `42129219721`. Good wins +2 to +4 points in every cell; wrongful hangs down.
