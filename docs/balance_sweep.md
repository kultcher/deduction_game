# Balance sweep

Large autoplay sweeps on **dynamic scripts**, run on GitHub Actions, then a report of win
rates and what goes with them. The tooling reads finished games only: it draws nothing
from the world RNG and changes no decision, so the golden capture is unaffected.

## Running it

Actions ▸ **Balance sweep** ▸ Run workflow (or `gh api
repos/kultcher/deduction_game/actions/workflows/balance-sweep.yml/dispatches -f ref=main
-F inputs[...]`). Inputs:

| Input | Default | Meaning |
|---|---|---|
| `seed_start` | 100000 | First case seed. Every cell uses the same seeds, so a seed pairs across modes. |
| `games_per_cell` | 2000 | Games per cell. |
| `cells` | 7/10 NPCs × passive/bot | JSON list of `{"npcs", "mode": "passive"\|"bot", "insight"}`. |
| `costs` | measured | Seconds per game per core, by `<npcs>_<mode>`. Only sizes the shards. |
| `target_hours` | 3 | Planned hours per shard job (the hard cap is 6). |
| `max_shards` | 200 | Safety bound on the number of jobs. |
| `ref` | dispatched ref | What to sweep. |

The **plan** job splits each cell into seed ranges sized to `target_hours`. Each
**shard** job builds the game and runs `tools/sweep_shard.py`: four `autoplay.gd`
processes over disjoint seed ranges. At most 18 shards run at once, leaving two runner
lanes for ordinary CI. The **collect** job merges every shard's records and writes the
report. Its artifact, `sweep-report`, holds `sweep_report.md`, `sweep_summary.json`, the
merged records (`sweep_merged.jsonl.gz`) and `sweep_errors.jsonl`. Each shard's own
artifact (`sweep-<cell>_<first seed>`) has its records and the dev logs of flagged games.
The collect job also pushes the report, summary, merged records and errors to a branch
`sweep-results/run-<run id>` (an orphan branch with only those files), because artifact
downloads can be blocked from some workspaces; `git fetch origin sweep-results/run-<id>`
gets them. Michael deletes old results branches.

Locally, one cell:

```sh
python3 tools/sweep_shard.py --godot <Godot .NET binary> --npcs 7 --mode passive \
    --seeds 100000:100020 --procs 2 --out /tmp/sweep
python3 tools/sweep_report.py /tmp/sweep/results_*.jsonl --md report.md --json summary.json
```

(`sweep_report.py` takes one file: `cat` the parts together first.)

## The pieces

- `tools/autoplay.gd --dynamic` deals each case from `ScriptBuilder.dynamic({"seed": s})`,
  seeded by the case seed, so a game is reproducible from its seed and size alone.
  Experimental roles (the Brute) aren't drawn. `--results-jsonl FILE` appends one record
  per finished game and flushes after each; `--sha` tags them. The game prints
  `SWEEP_BEGIN n` / `SWEEP_END n` around each case.
- `tools/sweep_record.gd` builds the record.
- `tools/sweep_shard.py` runs the processes, counts engine error lines between the
  markers against that seed, restarts a process that crashed or ran past
  `--game-timeout` (default 30 minutes for one game) on the next seed, and writes a
  `failed` record for the lost one. It deletes each game's dev logs once it's recorded,
  keeping only flagged games' (engine errors, stuck, or wall time over 5× the running
  median).
- `tools/sweep_report.py` writes the report (standard library only).

## Record schema (`sweep_v1`)

One JSON object per game. Flat fields:

- **Identity:** `seed`, `npcs`, `mode` (`passive` / `bot`), `insight`, `backend`, `sha`,
  `dynamic`, `script_fingerprint`, `script` (the full script).
- **Deal:** `town_roles`, `minion_roles` (as dealt: a risen Scion is still `scion`),
  `demon_roles`, `secret`, `secret_holders`, `night_walkers_dealt` (including the Demon),
  `start_knowledge_dealt`, `identifiers_dealt`, `deal_fallback` (the guarantees or the
  night-walker band weren't met: the 200-try fallback), `scion_rose`.
- **Outcome:** `winner`, `reason`, `days`, `outcome`, `loss_hint`, and the autoplay
  counters `exec_good`, `exec_evil`, `kills`, `lies`, `nominations`, `clemency`, `pairs`,
  `shares`, `evil_shares`, `approaches`, `deductions`, `arguments`, `workshop_cases`,
  `hub_cases`.
- **From `case_summary`:** `demon_evidence_on_board`, `demon_evidence_reachable`
  (booleans), `nights`, `executions` (one row each), `demon_identified`,
  `both_identified`, `identified_but_lost`, `good_initial`, `good_surviving`,
  `good_survival_fraction`.
- **People:** `people`, one row per NPC: `role` (dealt), `role_now`, `alignment`,
  `evil_at_start`, `turned`, `alive`, `death_day`, `death_cause`, `claimed_role`,
  `claim_public`, `public_claim_day`, `bluff`, `claim_contested` (someone else publicly
  claimed the same role), `secret`, `executed_while_bluffing`.
- **Pace:** `exec_good_by_day`, `exec_evil_by_day`, `first_evil_exec_day` (−1 if none),
  `meetings_with_activity`, `meetings_without_execution`, `nominations_by_day`,
  `kills_by_night`.
- **Vote shape** (`tools/vote_shape.gd`, the belief-model guardrail): `votes`,
  `votes_unanimous` (every NPC voter but the nominee voted yes), `votes_only_nominator`
  (the nominator's was the only yes, the player's included), `evil_nominations` (by
  someone evil at case start), `evil_nominations_carried` (put on the block),
  `evil_nominations_executed`, and the same three for good targets
  (`evil_nominations_good_target`, `…_carried`, `…_executed`). The report adds a
  "Vote shape" table per cell.
- **Night-walkers:** `good_gift_walkers_executed` (a good night-walking gift hanged),
  `good_secret_walkers_executed` (Lovers or Sleepwalker hanged).
- **Information:** `impaired_readings` (good readings that were false: poison,
  Delusional, Marked), `impaired_readings_shared`, `fake_info` (evil fabrications).
- **Bot:** `player_commands`, `player_nominations`, `player_nominations_executed_evil`,
  `player_nominations_executed_good`.
- **Health:** `wall_s`, `guard` (commands issued), `stuck` (the 600-command guard ran
  out), `legacy_fallbacks` (shared-model fallbacks), `complete`.

A lost game has only identity fields plus `failed` (`crash` / `timeout` / `startup`) and
`complete: false`.

## Reading the report

- **Win rate by cell** gives good wins with a 95% Wilson interval. At 2000 games a cell is
  good to about ±2 points.
- **Role effects** compare the good win rate in games with each role (minion, secret,
  night-walker count) dealt against games without it. A role dealt in a third of games
  resolves differences of about 6–8 points. These are associations: deal rules tie roles
  together (night-walker bands, start-knowledge guarantees), so a role's effect can be
  another role's.
- **Fate tables** show how each town gift ends: average death day, how often the Demon
  kills it in the first two nights (target priority), how often it's hanged while good,
  how often it claims publicly. **Bluff tables** show what evil claims and how it fares.
- **Pairs** only list role pairs with n ≥ 200 both ways and a 10-point difference.
- **Paired seeds** compare bot and passive on the same deal: how often the player turns
  a loss into a win, and the reverse.
- **Health** lists stuck, failed and error games with seeds, seeds with no record, wall
  times and the slowest seeds. Stuck games are left out of every rate.

Caveats: bot win rates describe today's bot, not a skilled human (the M4 policy is the
default; `--pre-m4` keeps the earlier one). Passive results mostly measure
NPC meeting behaviour. Dynamic scripts aren't the Default script, so these numbers don't
compare directly with older Default-script sweeps.
