# 2026-11-28, Claude-Bailiff: balance sweep fits 10-NPC shards in a runner's memory (`claude/nice-mayer-naok85`)

- **Signed:** Claude-Bailiff
- **Base:** main `6770f32e`.
- **Status:** PR open. Tooling only (`tools/sweep_shard.py`, `.github/workflows/balance-sweep.yml`); no game code, golden untouched.
- **Next actor:** Bailiff merges on green, then re-dispatches the sweep on main (Seneschal asked).

## Why
Run 46079890031 (Nov 27, main `a88b83ba`) lost all 20 10-NPC shards, passive and bot, within
about 8 to 60 minutes: exit 143, "The runner has received a shutdown signal", with no game
finished. All 7-NPC shards succeeded.

**Measured locally (Nov 28, main after Burdens), peak RSS of one autoplay process:**

| Cell | Games in the process | Peak | Per game |
|---|---|---|---|
| 10 passive | 3 | 4.5 GB (2.3 GB after the first minute) | ~115 s |
| 10 bot | 2 | 5.3 GB | ~530 s |

Memory climbs game by game inside one process, and each shard ran 4 processes over its whole
seed range, far past a hosted runner's 16 GB. The climb across games also looks like a leak
worth a lead's look (Argon's #574 clears missed static caches and may be related).

## What changed
- **`sweep_shard.py --games-per-proc N`:** restarts autoplay after N games (0: never, the old
  behaviour). Tested: a 7-NPC passive shard, 6 seeds, 2 processes, restart every game, 6/6 records.
- **`balance-sweep.yml`:**
  - each cell may set `procs` and `games_per_proc`. Defaults: 10 NPCs get 2 processes,
    restarted every 2 games (about 11 GB at most); 7 NPCs keep 4 and no restart;
  - shard sizing uses each cell's own process count;
  - `--games-per-proc` is passed only when set, so sweeps of older refs still run;
  - default costs refreshed: `10_passive` 50 → 120, `10_bot` 350 → 550, `7_bot` 85 → 115
    (Nov 27's 7-NPC bot shards ran about 4 h against a 3 h plan), `10_bot_pre_m4` 210 → 330.

## Effect on a default sweep (2000 games a cell, 3 h a shard)
71 shards: 7 passive 1, 10 passive 12, 7 bot 6, 10 bot 52. At 18 in parallel that's about
four waves, roughly 12 hours. Fewer games per cell would shorten it.

## Not measured
Peak memory on the hosted runner itself, and the bot cells' memory beyond two games.
