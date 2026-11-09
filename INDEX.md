# Balance sweep archive

Collected Nov 9, 2026 by Claude-Bailiff from the ten `sweep-results/run-<id>` branches, so those branches can be deleted. Each `run-<id>/` folder holds that run's files unchanged:
- `sweep_report.md`: the full report, with role effects and fates;
- `sweep_summary.json`;
- `sweep_merged.jsonl.gz`: one record per game (schema in `docs/balance_sweep.md` on main);
- `sweep_errors.jsonl`;
- `README.md`.

**Seeds:** every run starts at seed 100000, so cells of the same size and mode pair game for game across runs. Paired comparisons only make sense on seeds present in both runs (some cells are partial).

**Insight:** the bot cells use insight 1.0 unless marked 0.6.

## Runs

| Run | Date | Commit | What it measured | Write-up (Project) |
|---|---|---|---|---|
| 41978776824 | Nov 5 | `a0d9641` (#64, sweep tooling) | The first full sweep, pre-M4 bot | `balance-sweep-report-2026-11-05`, `balance-sweep-deep-dive-2026-11-05` |
| 41999201334 | Nov 5 | `a0d9641` | 10 NPCs, bot insight 0.6, the cell cut from the run above | `balance-sweep-report-2026-11-05` |
| 42122866121 | Nov 5 | `b1ca4e9` (evidence honesty) | Partial: cells of 177–695 games | none |
| 42129219721 | Nov 6 | `501b83e` (vigil exclusion) | The 10-passive high point (42.6%) | `balance-sweep-report-2026-11-06` (as the "before") |
| 42174319660 | Nov 6 | `0ca8654` (main `9a1b215` plus the `bot_pre_m4` mode) | M4 bot against pre-M4. The 7-NPC bot cells are partial (shard caps) | `balance-sweep-report-2026-11-06` |
| 42331033313 | Nov 7 | `0743a76` (#94, before premises) | Premises A/B base | `premises-ab-2026-11-07` |
| 42331041617 | Nov 7 | `3d0f210` (#92, premises step 1) | Premises A/B | `premises-ab-2026-11-07` |
| 42331050248 | Nov 7 | `226d566` (#95, premises steps 1–3) | Premises A/B. Step 3 was slow: 33 games failed (timeouts), 10-passive is partial | `premises-ab-2026-11-07` |
| 42564439458 | Nov 9 | `dc2418c` (#96, recency, includes #105–#109) | Main after recency | `balance-sweep-report-2026-11-09` |
| 42610743952 | Nov 9 | `61ba493` (#109, just before #96) | Recency A/B (bot only) | `balance-sweep-report-2026-11-09` |

## Good-win rates by run

Games per cell are in brackets where the cell is partial (below 1,000). Elsewhere it's 1,000 or 2,000 games.

| Run (commit) | 7 bot | 7 passive | 10 bot | 10 passive | Other cells |
|---|---|---|---|---|---|
| 41978776824 (`a0d9641`) | 55.0% | 34.0% | 52.6% | 40.1% | 7 bot at 0.6: 48.9% |
| 41999201334 (`a0d9641`) | | | | | 10 bot at 0.6: 50.8% |
| 42122866121 (`b1ca4e9`) | 57.6% (177) | 37.7% (695) | 57.7% (201) | 42.3% (426) | |
| 42129219721 (`501b83e`) | 57.7% | 37.6% | 56.3% | 42.6% | |
| 42174319660 (`0ca8654`) | 59.7% (978) | 34.8% | 55.8% | 28.7% | pre-M4 bot: 7 NPCs 58.4% (1,756), 10 NPCs 50.9% |
| 42331033313 (`0743a76`) | 58.5% | | 53.1% | 29.9% | |
| 42331041617 (`3d0f210`) | 58.6% | | 52.5% | | |
| 42331050248 (`226d566`) | 58.6% | | 53.3% (963) | 30.4% (886) | |
| 42564439458 (`dc2418c`) | 59.3% | 35.9% | 55.2% | 39.0% | |
| 42610743952 (`61ba493`) | 59.0% | | 53.7% | | |

## Median seconds per game (for sizing shards)

| Run | 7 bot | 7 passive | 10 bot | 10 passive |
|---|---|---|---|---|
| `a0d9641` | 38 | 4 | 172 | 38 |
| `501b83e` | 34 | 3 | 163 | 38 |
| `0ca8654` | 70 | 3 | 300 | 33 |
| `0743a76` | 55 | | 295 | 24 |
| `226d566` | 77 | | 504 | 140 |
| `dc2418c` | 50 | 5 | 286 | 32 |
| `61ba493` | 63 | | 289 | |

These are per game on one core of a GitHub runner. The worst 10-NPC bot game in each run took 1,100–1,800 s. The shard cost table wants roughly the p90 times the cell size: about 120 / 8 / 600 / 70 seconds for the four cells on current main.

## What these runs established

- **The player's edge at 10 NPCs:** bot minus passive was 12.5 points at `a0d9641`, 27 at `0ca8654`, 23 at `0743a76` and 16 at `dc2418c`. Most of that movement is the passive cell.
- **Passive at 10 NPCs:** 42.6% at `501b83e`, 28.7–30.4% from `0ca8654` to `226d566`, then 39.0% at `dc2418c`.
  - The Nov 5→6 drop was never explained.
  - The Nov 9 rise is from #96 and/or #108/#109. Run 42610743952 has no passive cell to split them.
- **The bot at 10 NPCs:** M4 beat pre-M4 by 4.9 points (`0ca8654`). Since then it's flat within noise (53–56%) through premises, recency, the playtest fixes and chatter.
- **7-NPC bot drop:** from `9a1b215` to `0743a76` it fell about 5 points on shared seeds (z −3.0). This came from #90, #91 or #94 and wasn't investigated. It's flat at 58.5–59.3% since.
- **Steady role effects across runs:** at 7 NPCs, Breathstealer games favour good by about 14 points and the Delusional secret favours evil by about 15.
- **Speed:** premises step 3 (`226d566`) roughly doubled the bot's time and made passive play 4–6× slower. #99 and #100 brought it back (`dc2418c`).
