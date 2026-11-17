# 2026-11-17, Claude-Tally: Trace weight, 1.5:1 vs 2:1 vs 3:1 (claude/trace-weight-report)

- **Base:** `main` at `98cb948` for the sweeps and probes; this docs-only PR is on `babb7d6`.
- **Status:** measurement done. No game code or tuning changed. **3:1 is live on main**
  (`TRACE_MATCH_WEIGHT = 3.0`, `TRACE_UNKNOWN_WEIGHT = 1.6`). The 3:1 row is in every
  table below.
- **Next actor:** Michael, who picks a ratio by feel (BACKLOG "Trace weight", `[open]`),
  through Seneschal. Bailiff merges this PR.

## Result

- **No measurable outcome difference.** Good's win rate and wrongful hangings in bot play
  are the same at all three ratios, within noise. Passive play is identical game for game,
  as expected: traces only enter play when the player searches.
- **What the ratio changes is how hard traces push a listener.** A single trace is never
  decisive at any ratio. Grouped traces, three or four across two to four scenes, narrow
  the field to two or three suspects. The Demon is almost always among them (94–97%),
  alongside good people who fit just as well. At 3:1 the grouped traces lift the Demon
  10+ suspicion points in a fifth to a third of games. At 1.5:1 that never happens, and
  the narrowing is left to the player.
- **Chaos in information:** at every ratio, the people traces point to include good people
  who fit as well as the Demon does. A hanging made on trace evidence stays explainable in
  hindsight, and the ratio decides how loudly the town repeats it.

## Outcome sweeps (balance-sweep.yml, 10-NPC town, seeds 100000–101199, paired)

Runs: 34 `44015483209` (1.5:1, `mock/trace-weight-1p5`), 35 `44015487162` (2:1,
`mock/trace-weight-2`), 38 `44016114728` (3:1 control, main at `98cb948`). Results are on
`sweep-results/run-<id>`. The bot runs at insight 1.0.

| Mode | Ratio | Games | Good wins (95% CI) | Good hanged / game | Evil hanged / game | Good hanged on the player's nomination | Demon identified | Days |
|---|---|---|---|---|---|---|---|---|
| passive | 1.5:1 | 1200 | 41.8% (39.1–44.6) | 1.24 | 1.35 | 0 | 0% | 4.53 |
| passive | 2:1 | 1200 | 41.8% (39.1–44.6) | 1.24 | 1.35 | 0 | 0% | 4.53 |
| passive | 3:1 | 1200 | 41.8% (39.1–44.6) | 1.24 | 1.35 | 0 | 0% | 4.53 |
| bot | 1.5:1 | 1197 | 64.0% (61.2–66.7) | 0.91 | 1.72 | 0.36 | 84% | 4.09 |
| bot | 2:1 | 1197 | 63.7% (60.9–66.3) | 0.90 | 1.72 | 0.35 | 86% | 4.09 |
| bot | 3:1 | 1197 | 65.3% (62.6–68.0) | 0.90 | 1.74 | 0.35 | 86% | 4.06 |

Standard error on hangings per game is about 0.03.

- **Passive:** all 1,200 games are identical across the three ratios (same hangings, same
  winner).
- **Bot, paired flips** (games good wins at only one of the two ratios):
  | Pair | Identical games | Good wins only at the lower ratio | Good wins only at the higher ratio | z |
  |---|---|---|---|---|
  | 1.5:1 vs 2:1 | 910 / 1197 | 41 | 37 | +0.45 |
  | 2:1 vs 3:1 | 862 / 1197 | 40 | 60 | −2.00 |
  | 1.5:1 vs 3:1 | 739 / 1197 | 60 | 76 | −1.37 |

  The ratio changes how about a third of bot games play out, but win and loss flips
  roughly cancel. The one z near 2 is among three comparisons, and 1.5:1 vs 3:1 isn't
  significant. Read it as at most a point or two for good at 3:1, not a real effect.
- **Excluded:** 3 bot games per ratio. Seed 100258 hit an engine error at every ratio (see
  below). Seeds 101057, 101147 and 100236 timed out (exit −9), each at one ratio.
- **The bot is a strong, systematic player.** It doesn't mind how loud a trace is, so the
  sweep can't show how a person reads a louder or quieter town. That is what the probes
  below measure.

## Probe: how much traces move a listener

A local probe, `tools/_probe_trace.gd`: a copy of `tools/measure_evidence.gd` with two extra
modes. It isn't committed (CLAUDE.md: never commit `_probe*`). It plays passive to the given
day, has the player search every scene so far, and adds every NPC's work and haunt
profiles. It then files an evil case on a target and measures one listener's suspicion of
that target, with and without the trace cards cited. The same seeds and slots are paired
across ratios. "Points" are suspicion on a 0–100 scale. The worktrees were on the two mock
branches, and the repo checkout was the control.

### Single traces (day 3, 133 seeds of 100000–100149 that reached day 3, 316 traces)

About 7.4 people alive. A trace fits about 5.6 of them (77%), the Demon fits it 92% of the
time, and 41% of scenes carry a second trace.

| Ratio | Demon | Good person who fits | Good person who doesn't fit | A fitting target rises 5+ pts | 10+ pts | Effective field left by the trace alone |
|---|---|---|---|---|---|---|
| 1.5:1 | +0.7 | +1.0 | −2.9 | 0–1% | 0% | 7.2 of 7.4 |
| 2:1 | +1.1 | +1.5 | −4.6 | 2–4% | 0% | 7.0 |
| 3:1 | +1.5 | +2.1 | −6.6 | 7–12% | ~1% | 6.6 |

Standard error is about 0.1–0.2 points. One trace works by clearing the people who don't
fit, not by pointing at anyone.

### Grouped traces (all of a game's searched scenes together)

Targets: the Demon; a good person who fits every searched scene; a good person who misses
one scene. The comparison is profiles alone against profiles plus every trace.

**Day 4** (118 paired seeds): 2.8 scenes and 3.5 traces on average. 5.7 people alive, 3.4
of whom fit every scene. The Demon fits every scene 97% of the time, and about 1.7 evil fit
every scene. People who fit every scene, per seed: 1 (5 seeds), 2 (22), 3 (38), 4 (32),
5 (16), 6 or more (5).

| Ratio | Demon | Good, fits all | Good, misses one | Demon rises 10+ | Good fit-all rises 10+ | Miss-one drops 10+ | Demon rises 20+ |
|---|---|---|---|---|---|---|---|
| 1.5:1 | +2.3 | +3.0 | −2.5 | 0% | 1% | 2% | 0% |
| 2:1 | +3.8 | +4.7 | −4.2 | 4% | 10% | 6% | 0% |
| 3:1 | +5.6 | +6.6 | −6.4 | 19% | 26% | 14% | 0% |

**Day 5** (87 paired seeds; the rest ended before day 5): 3.8 scenes and 4.5 traces. 4.2
people alive, 2.2 of whom fit every scene. The Demon fits every scene 94% of the time.

| Ratio | Demon | Good, fits all | Good, misses one | Demon rises 10+ | Good fit-all rises 10+ | Miss-one drops 10+ | Demon rises 20+ |
|---|---|---|---|---|---|---|---|
| 1.5:1 | +3.0 | +2.9 | −2.1 | 0% | 0% | 2% | 0% |
| 2:1 | +5.1 | +4.6 | −3.6 | 10% | 5% | 7% | 0% |
| 3:1 | +7.8 | +6.6 | −5.5 | 34% | 31% | 18% | 3% |

Standard error is 0.2–0.8 points; fewer good fit-all targets exist on day 5 (n = 39).
Paired, the Demon and a good person who fits every scene move by the same amount (within
about a point) at every ratio. Grouped traces don't tell the Demon from an innocent who
keeps the same places.

## Small calls made on Michael's behalf

- **The unknown weight scaled with the match weight.** "Unknown" is a person whose places
  the listener doesn't know. On main it sits between a match and a miss (1.6 against 3.0
  and 1.0). The mocks kept it at the same relative place: 1.15 at 1.5:1 and 1.3 at 2:1.
  `TRACE_CONTRADICT_WEIGHT` stayed 1.0. The connection and base weights were untouched.
- **Insight 1.0 for the bot cell**, as in the standing sweep.

## Mistakes, for the record

The first 3:1 control dispatch used a short sha, which the checkout rejected (run 36). I
then typed a full sha from memory and got it wrong (run 37). Both were cancelled, and run
38 used the sha from `git rev-parse`. Runs 34 and 35 weren't affected.

## Proposed for the backlog (sent to Seneschal)

- **The C# kernel exception is still live.** `IndexOutOfRangeException` in
  `CaseEvalKernel.ComputeClassLikeCore`, already handed to Argon on Nov 5 (frozen
  `docs/handoff_log.md`, the sweep entry). It hit seed 100258, 10-NPC bot, at all three
  ratios on `98cb948`. Suggested: `[decided]`, owner Argon (C# kernel), repro
  `autoplay.gd -- --seed 100258 --games 1 --npcs 10` (bot mode, no `--passive`).
- **Commit the trace probe as a tool,** with a name that isn't `_probe*`, so a later trace
  or evidence change can be re-measured the same way. Suggested: `[open]`, owner Quill
  (evidence).

## Cleanup

Mock branches `mock/trace-weight-1p5` and `mock/trace-weight-2` stay on the remote, for
Michael to delete. Local worktrees removed.
