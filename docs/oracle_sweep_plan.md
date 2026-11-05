# Oracle sweep: how winnable is the game?

Spec, Nov 5, Claude-Bailiff, for whoever runs the sweep tooling (Claude-Tally by default).
It follows `DESIGN.md` › Outcome tracking › Balance target.

## Why

**The target:** a skilled player names the Demon in 85–90% of cases and wins 70–75%.

**Today's analyst bot:** names the Demon in 72% and wins 53–55% (Nov 5 sweep, insight 1.0).

The gap could sit in two places, and they need opposite fixes:

- **In the player.** The bot reasons and persuades worse than a good human. Then the
  game is fine, and the bot (M4) or the target needs adjusting.
- **In the game.** Even perfect judgment can't win 70–75% against today's town and evil.
  Then we tune the town or evil.

An **oracle** player settles which one it is. The oracle knows the grimoire but may only
use legal commands and real evidence. Its win rate is the ceiling the town and evil allow
with today's persuasion tools. Paired with the analyst bot on the same seeds, it also shows
where the bot falls short.

## Ground rules

- **Tooling only.**
  - `autoplay.gd` changes must leave the default bot and passive modes bit-identical: same
    records apart from wall time, on a few seeds per mode.
  - The golden capture doesn't use autoplay, so it's unaffected. Check that anyway.
- **The oracle reads the truth only through its scores.**
  - Never add commands a player can't type.
  - Never fabricate cards. `tell`, `present`, `accuse` and the Workshop work as now, on the
    board the oracle actually holds.
- Usual rules: branch from `main`, green before merge, no force push, attribution per the
  session's instructions, a handoff log entry.

## Implementation

### 1. `--oracle MODE` in `tools/autoplay.gd`

`_scores()` returns ground truth instead of `Analyst.belief`:

- Use the living alignment (`n.is_evil()`), so a Revenant-turned good soul counts as evil
  while turned.
- `w.demon_id` gets **1.0**, so a risen Scion is scored as the Demon.
- Minions and the turned get **0.9**. Good gets **0.0**.
- Dead people keep today's handling.

Everything downstream stays as it is: nominations, votes, defend and accuse, clemency,
wards, vigils, and the Workshop cases built by `Analyst.build_case` from these scores. So
it nominates the real evil and argues with whatever real evidence it holds. When
`build_case` can't make a case, the nomination goes ahead on its word (`raw`), exactly as
the bot does today.

Modes:

| `--oracle` | What it does | What it measures |
|---|---|---|
| `full` | Truth scores, every action as above | The game's winnability ceiling with today's persuasion tools |
| `silent` | Truth scores for **votes and clemency only**. Never nominates, presents, tells, accuses or defends. Day actions as passive. | How much the player's vote alone is worth |
| `scion` | As `full`, but while a living Scion is in play and five or more are alive, it ranks the Scion (0.95) above the Demon (0.9) | Whether the Scion problem is ordering or the gate |

The record gets `oracle: "<mode>"`, or `""` for the other modes.

`_record_theory` with truth scores names the Demon correctly by construction. Identification
is therefore 100% for the oracle and isn't a result. Report it as n/a.

### 2. Sweep cells

Use the same seeds as the Nov 5 sweep (from 100000), so every oracle game pairs with its
passive and bot twins in `sweep-results/run-41978776824` and `run-41999201334`:

| Cell | Games | Est. core-hours |
|---|---|---|
| 7 NPCs, oracle full | 2000 | ~20 (like the bot) |
| 10 NPCs, oracle full | 1000 | ~50 |
| 7 NPCs, oracle silent | 1000 | ~2 (like passive) |
| 10 NPCs, oracle silent | 1000 | ~12 |
| 10 NPCs, oracle scion | 1000 | ~50 |

That's about 135 core-hours, roughly 2 h of wall time on 18 jobs. If budget is short, cut
`scion` first, then 10-NPC `silent`. The workflow's `cells` input gains an `oracle` key.
`sweep_shard.py` passes it through, and the cost table needs an `oracle` entry per size
(start from the bot's measured costs).

### 3. Report additions (`tools/sweep_report.py`)

- **Win rates with the oracle cells** beside the existing cells, plus the target band
  (70–75%) as a reference line in the per-cell table.
- **The ladder per size:** passive → bot 0.6 → bot 1.0 → oracle silent → oracle full, as
  win rates with intervals.
- **Paired oracle vs bot** on the same seeds: oracle wins/bot loses, and the reverse. The
  reverse should be rare; if it isn't, that's a finding.
- **Where the oracle loses,** broken down by:
  - end reason;
  - the Demon's bluff (the walking-gift bluffs from the Nov 5 deep dive: does even the
    oracle lose to a Lamplighter or Medium bluff?);
  - Scion rose or not;
  - the oracle's nomination failing (on the block vs voted down) vs never nominating.

  Record the nomination outcomes per player nomination if they aren't already: nominee
  alignment, votes for and the threshold, executed or not.
- **Oracle loss with the Demon nominated at least once:** the persuasion ceiling. With the
  Demon never nominated (the oracle couldn't get a nomination in), that's the procedure
  ceiling: slots, cooldowns, being silenced.

### 4. Verification

1. **Locally:**
   - `--oracle full|silent|scion` over 5 seeds × both sizes;
   - default and passive records unchanged on the same seeds;
   - the same oracle seed twice gives identical records;
   - the report runs on the smoke output.
2. **A tiny dispatch** (2 shards, ~8 games per cell), then the real one from `main`.
3. **Merge when green,** note the run id and sha, and write the report to the Project as
   `claude/oracle-sweep-report-<date>.md`.

## Reading the result

- **The oracle's `full` win rate is the number that matters.**
  - **Well above 75%** (say 90%+): there's room. The target is about how much reasoning
    it takes. Keep tuning the bot (M4) and collect human playtests.
  - **About 70–80%:** the target sits at the ceiling, so only a near-perfect player
    reaches it. Either accept that or make good's tools stronger.
  - **Below 70%:** the target is out of reach. Find out from the loss breakdown why perfect
    judgment loses (unbreakable bluffs, the Scion, evil carrying the vote late, nomination
    procedure) and fix that first.
- **`silent` minus passive** is what one honest vote is worth. **`full` minus `silent`**
  is what talking and nominating are worth.
- **`scion` minus `full`** at 10 NPCs: if smart ordering recovers most of the Scion's −17,
  it's a skill check and fine. If not, the gate needs work.

## Aside (not part of this sweep)

The analyst bot names its demon guess from P(evil), not P(Demon) (`_record_theory`), so it
sometimes names a minion. Part of the 72% identification gap may be this, not reasoning.
It's worth a quick fix in M4: use the Demon-specific posterior if `Analyst` exposes one.
