# Balance sweep, Nov 9: main after recency (#96)

Nov 9, 2026 · Claude-Bailiff · run `42564439458` at `dc2418c`. That's main after #96, which also includes #105–#109. Results branch: `sweep-results/run-42564439458`. 4,000 games: 0 failed, 0 stuck, no errors.

## Headline

- **Bot win rates are flat.** 59.3% at 7 NPCs and 55.2% at 10 NPCs, against 58.5% / 53.1% at `0743a76` (Nov 7 base), on the same 1,000 seeds per cell. The differences are +0.8 (z +0.4) and +2.1 (z +1.1), both within noise.
- **Do-nothing play at 10 NPCs is back up by 9 points:** 39.0%, against 29.9% at `0743a76`, 30.4% at steps 1–3 and 30.0% at Nov 6 (z +4.9 on paired seeds). That nearly reverses the unexplained Nov 5→6 drop (42.6% → 30%).
  - The source is one or more of recency (#96), the playtest-1709 fixes (#108: one accusation per speaker per meeting) and NPC chatter (#109).
  - Run 2 (main just before #96, bot cells only) will tell recency apart from the rest. See "Run 2" below.
- **Do-nothing play at 7 NPCs is unchanged:** 35.9% against 35.4% (Nov 6).
- **The player matters less at 10 NPCs.** Bot minus do-nothing is now 16 points, down from 23. At 7 NPCs it's still 23.
- **Speed recovered after the step 3 slowdown.** Median per game:

  | Cell | Steps 1–3 | Now |
  |---|---|---|
  | 10 bot | 504 s | 286 s (max 1,228 s, no timeouts) |
  | 10 passive | 140 s | 32 s |
  | 7 bot | 77 s | 50 s |

## Win rates

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game |
|---|---|---|---|---|---|
| 7 NPCs, bot | 1000 | 59.3% (56.2–62.3) | 3.15 | 0.69 | 1.06 |
| 7 NPCs, passive | 1000 | 35.9% (33.0–38.9) | 3.50 | 0.91 | 0.75 |
| 10 NPCs, bot | 1000 | 55.2% (52.1–58.3) | 4.29 | 1.12 | 1.58 |
| 10 NPCs, passive | 1000 | 39.0% (36.0–42.1) | 4.58 | 1.35 | 1.33 |

## Against `0743a76` (paired seeds)

| Cell | Then | Now | Diff | z |
|---|---|---|---|---|
| 7 bot | 58.5% | 59.3% | +0.8 | +0.4 |
| 10 bot | 53.1% | 55.2% | +2.1 | +1.1 |
| 10 passive | 29.9% | 39.0% | +9.1 | +4.9 |

At 10 NPCs, do-nothing play now executes fewer good people and more evil ones:

| 10 NPCs, passive | Then | Now |
|---|---|---|
| Good executions per game | 1.52 | 1.35 |
| Evil executions per game | 1.11 | 1.33 |
| Win rate in Breathstealer deals (441 games) | 40% | 51% |

## The follow-ups #96 asked for

- **Identified but lost:** 283 of 767 games where the Demon was identified (37%) at 10-NPC bot, against 294 of 778 before. 226 of 745 (30%) at 7 NPCs, against 254 of 774. A little lower at both sizes, but not significant.
- **Long games (6 days or more) at 10-NPC bot:** 157, against 204 before. Good wins 21 of them (13%), against 34 (17%). Fewer games drag on.
- **Day-1 reading survival:** not in the sweep record, so not measured here.

## Chatter

Conversations per game at 10 NPCs are up a little: 10.2 against 8.7 (bot) and 11.0 against 9.5 (passive). Shares per game are flat at 46–47. The record doesn't count role claims or hints separately. The local 8-game counts from Nov 8 are in the #109 notes.

## Role effects of note (7-NPC bot)

- **Breathstealer:** good wins 70% when it's dealt, against 56% without (+14, significant). Same as in earlier sweeps.
- **Delusional secret:** good wins 48% when it's dealt, against 62% without (−15, significant).

## Run 2: recency alone (bot)

Run `42610743952` is at `61ba493`, main just before #96 (so it already has #105–#109). It covers the bot cells on the same seeds as run 1: 2,000 games, 0 failed, 0 stuck. (The first launch, `42564441341`, failed at checkout because it was given a short sha. Bailiff's error.)

| Bot, paired seeds | Before #96 | After #96 | Diff | z | Seeds only one side won (after / before) |
|---|---|---|---|---|---|
| 7 NPCs | 59.0% | 59.3% | +0.3 | +0.2 | 94 / 91 |
| 10 NPCs | 53.7% | 55.2% | +1.5 | +0.9 | 145 / 130 |

- **Recency doesn't move the bot's outcomes.**
  - Execution mix and days are unchanged at both sizes, apart from 4.38 → 4.29 days at 10 NPCs.
  - Identified but lost: 296 of 762 → 283 of 767 at 10 NPCs, and 237 of 763 → 226 of 745 at 7 NPCs.
  - Games of 6 days or more at 10 NPCs: 189 → 157. Good won 30 of them before and 21 after.
- **It changes how games unfold, though.** Only 161 of 1,000 10-NPC games (415 at 7 NPCs) play out identically, but the flips cancel.
- **#108 and #109 don't move the bot either.** `61ba493` (before #96) against `0743a76` at 10 NPCs: 53.7% against 53.1%.
- **The 10-NPC do-nothing jump (+9 points) is still unattributed.** Run 2 has no passive cells. The bot result suggests it isn't recency, but passive play mostly measures NPC meeting behaviour, so that doesn't follow. A 10-NPC passive cell at `61ba493` (about 3 shards, 1–2 hours) would settle recency against #108/#109.
