# Backing a case builds trust

- **Agent:** Claude-Beadle
- **Base:** main at 44a9962
- **Branch:** claude/beadle-agreement-trust
- **Status:** PR open. It moves golden and re-baselines to `baseline_74eb971` in the PR (on main with #296).
  Narrowed on Nov 19 to votes and nominations (Michael).
- **Next actor:** Bailiff (review and merge). Michael, through Seneschal, for the reused
  numbers below.
- **BACKLOG item:** "Backing a strong case builds trust" (Michael, Nov 18; owner Beadle),
  narrowed Nov 19. The reading steps became "Trust from readings that confirm what I know or
  strongly believe" (Lantern and Beadle, sized tiers), recorded in #293.

## What changed

Nothing raised one NPC's trust in another for agreeing with it. The only positive step was a
nominee's thanks to those who voted to spare it. This change applies to good NPCs; evil NPCs'
own trust doesn't move, and their shadow copies it as before.

- **Agreement.** A good NPC warms a little to an ally who:
  - votes the same way it does on a nominee, to hang or to spare. A vote to spare is how one
    NPC stands up for another, so this covers defences: NPCs make no other defence of someone
    else;
  - nominates or accuses someone it already suspects, about as much as it would take to
    nominate them itself.

  It's at most once a day for each ally, so a day of agreeing ballots counts as one agreement.

Readings change no trust here. Michael (Nov 19) moved trust from readings to its own item,
with tiers by how sure the listener already is; it waits on Lantern's API.

## Numbers (existing constants, reused, flagged for Michael)

| Step | Constant reused | Value | Its existing use |
|---|---|---|---|
| Agreement (a vote, a nomination, an accusation) | `Social.TRUST_VOTED_FOR` | 0.03 | A nominee's thanks to a voter who spared it |
| "Suspects them too" | `Meeting.NOMINATION_FLOOR` | 0.40 | The lowest suspicion an NPC nominates on |

No new constant. If Michael wants these tuned apart from their original uses, they'd become
named constants of their own.

## Small calls made on Michael's behalf

- **The daily cap per ally.** Without it, a pair that voted together through a day's several
  ballots gained up to 0.49 trust in one game. That's half the scale, not "small".
- **Defences** are covered by vote agreement, because NPCs only ever defend themselves.
- **Evil NPCs' own trust isn't moved** (as with gossip trust).

## Measured

- **New suite:** `tools/test_agreement_trust.gd` (votes and the daily cap, backing, and a
  reading that clears the listener changing no trust), on the fast list.
- **Suites that pass:** test_agreement_trust, test_connections_pairings, test_meeting_flow,
  test_social, test_evil_play, test_held_signals and test_lie_severity_votes (earlier, before
  the narrowing, also the rest listed in the first version of this PR).
- **In play:** 15 passive 10-NPC games, seeds 3000-3014, main 6fcdc32 against this branch.

| | Main | Here |
|---|---|---|
| Winners | 9 good, 6 evil | 9 good, 6 evil |
| Hangings (good hanged) | 42 (14) | 41 (12) |
| Agreement gains a game: votes / accusations / nominations | — | 88.1 / 11.1 / 3.9 |

- **Trust distribution:** `tools/measure_npc_trust.gd` (new) records every living pair's trust
  at each day's end. It was run on the same 15 seeds, on main 634332e and on this branch.
  Michael's soft goal is some NPCs near full trust with some others by about day 4.

  | End of day | Main: pairs near full trust (0.85+) | Here |
  |---|---|---|
  | 1 | 11 (0.8%), in 7 games | 13 (1.0%), in 7 games |
  | 2 | 14 (1.6%), in 7 | 29 (3.3%), in 13 |
  | 3 | 10 (1.8%), in 8 | 48 (8.6%), in 11 |
  | 4 | 7 (3.2%), in 4 | 32 (12.6%), in 10 |
  | 5 | 2 (2.4%), in 2 | 14 (12.1%), in 7 |
  | Game end: median / top tenth | 0.52 / 0.78 | 0.59 / 0.87 |

  - **Distrust:** it isn't worn away. The lowest tenth is within 0.04 of main's through day 4
    (0.24 here, 0.20 on main, on day 4).
  - **When each day is sampled:** as night falls, before that night's kills (Codex on #292),
    and a game's last day is counted once.
  - **Counts by day:** they cover only the games still running that day, and fewer games run
    as days pass.
  - **Pairs already near full trust on day 1:** these are friends set up at the start, the
    same on both.
- **Golden:** `baseline_74eb971`, on main with #296. Two captures were identical, and every seed
  diverges from main's `baseline_21df80d`. 42, 692 and 900 keep their
  outcomes. 54875 now hangs only Edda, on day 3. 98933 is a good win on day 2. Details are in
  `docs/golden_baseline.md`.

## Proposed for the backlog

None.
