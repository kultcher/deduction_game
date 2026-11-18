# 2026-11-18, Argon: Consolidate night-to-dawn belief refreshes (`argon/dawn-belief-flush`; golden re-baselined, zero decision/state drift)

- **Base:** `origin/main` `426d7976` (includes `#232`, `#273`, `#278`, `#279`, `#281`). **Code commit:** `fe833dc`. **Reviewers:** Claude-Lantern (beliefs) and Claude-Beadle (scapegoat and evil-team behaviour).
- **What and why:** Implements fix `(a)` from Claude-Seneschal's Nov 18 brief on fewer belief refreshes at dawn (`resolve_night` -> `start_new_day` -> dawn).

## Changes

- **`sim/world.gd` (`World.resolve_night`, L1315–1347):**
  - Keeps `Mind.end_of_day_trust(self)`, all belief-driven night choices (`sexton`, `kill_t`, `poison_t`, `warden_t`, `watch_block`, `medium_t`, `lamp`, `mart`, `confessor_t`), `_night_movement`, and `C.INFO_BEFORE_KILL`'s `_receive_info` running before deferral so night targeting sees end-of-day beliefs.
  - Sets `defer_beliefs = true` across `_kill`, `_quiet_night`, `_warden_credit`, `_night_sightings`, `Evil.gather_night_intel`, `Evil.make_fake_info`, and `Mind.update_from_own_info`, then runs `Mind.flush_beliefs(self)` once and restores `defer_beliefs` right before `snapshot("night_end")` and `start_new_day()`.
  - Because evil shadows (`n.shadow`) are queued in `w.pending_beliefs` alongside good minds without changing `Mind.refresh_beliefs`/`_refresh_beliefs`, night `_kill` + `_shadow_own_info` refreshes fold into one end-of-night shadow flush without altering daytime `shadow_run` / `_shadow_sync` timing.
- **`sim/mind.gd` (`Mind.tell_save`, L1180–1190):**
  - Defers across `hear_claim` + `ledger_hear` and runs `flush_beliefs(w, protectee)` right before reading `susp(protectee, warden.id)`, folding `_quiet_night` + Warden save claim/evidence into one refresh for `protectee`.

## Morning Sites Traced (`start_new_day`, `Social`, `Credibility.dawn`)

1. **`Evil.review_scapegoat(self)` (`sim/world.gd:2012`, `sim/evil.gd:103-151`):** Reads `m.shadow.suspicion` at the start of `start_new_day()`. Because `Mind.flush_beliefs(self)` flushes both good minds and evil shadows at the end of `resolve_night()` before `snapshot("night_end")`, shadow beliefs already reflect the night's death/readings before scapegoat scoring runs.
2. **Morning `npc_share` (`sim/world.gd:685`, `sim/social.gd:84-496`):**
   - `Social.converse` calls `_pick_item(w, p[0], p[1])` and `_deliver(w, p[0], p[1], item)` for `p in [[a, b], [b, a]]`.
   - `_pick_item` reads `Mind.ranked_suspects(w, s)`, `Mind.susp`, and `Mind.citable_reason` (`sim/social.gd:144-148`, `221-228`).
   - `_deliver` updates the listener's ledger (`apply_info` / `hear_claim` / `ledger_hear`) and immediately reads `Mind.susp(l, s.id)` inside `gossip_bond(l, s, item)` (`sim/social.gd:495, 505`) before updating `l.npc_trust[s.id]` and before `[b, a]` runs. Morning conversations remain un-deferred after the night flush.
3. **`Credibility.dawn(g)` (`game/game_day_night.gd:623`, `game/credibility.gd:100-202`) & `" (a new day)"` (`game/game_day_night.gd:627-628`):**
   - `Credibility.dawn` evaluates player claim agreement on living NPCs with non-empty `claim_record` (excluding `PLAYER_WORD` entries) and updates `credibility`; `" (a new day)"` then runs with `day` advanced (`Recency`). Not merged because `credibility` can change between them.

## Verification

- **Measured Profile (Windows `Debug` C# build, default `Connections = true`):**
  - **5 golden seeds (`origin/main` `426d7976` vs `argon/dawn-belief-flush`):**
    - Total refreshes: `1,013 -> 980` (`-33` across Nights 1–3; `seed_42_7` `85 -> 80`, `seed_54875_10` `304 -> 295`, `seed_692_10` `220 -> 215`, `seed_900_7` `149 -> 143`, `seed_98933_10` `255 -> 247`).
    - Night-body refreshes in `resolve_night`: `119 -> 86` (`-27.7%`; `world.gd:1321` `83` + `world.gd:1343` `36` = `21,980.1 ms` -> `world.gd:1346` `86` = `20,109.8 ms`).
    - Total night command wall time (`night_cmd_ms`): `48,708 ms -> 45,540 ms` (`-6.5%`).
  - **`case_16010.jsonl` replay (`Connections = true` from log):**
    - Total refreshes: `176 -> 174` (Night 2 `world.gd:1321` `9` + `world.gd:1343` `2` -> `world.gd:1346` `9`).
    - Night command (`seq=271`, day 2): `1,208 ms -> 1,115 ms` (`-7.7%`).
- **Zero decision / state drift across all 5 golden seeds:**
  - Compared every non-refresh record (`meta`, all `step` records `-1..N`, and `end`) between Windows `origin/main` and `argon/dawn-belief-flush` at `--tol 0` (excluding `refreshes_so_far`/`refreshes`): **100% bit-for-bit identical** on all 5 seeds (`seed_42_7` 27 records, `seed_54875_10` 41 records, `seed_692_10` 31 records, `seed_900_7` 34 records, `seed_98933_10` 36 records). Every decision, vote, nomination, kill, line said, RNG state, and NPC/shadow state is unchanged.
  - Two independent Windows golden captures matched at `--tol 0` across all 5 seeds (`42_7` 107, `54875_10` 336, `692_10` 246, `900_7` 177, `98933_10` 283 records).
  - Baseline `tools/golden/baseline_fe833dc/` built by preserving Linux floats from `tools/golden/baseline_e287b3d` for all 1,129 unchanged/matched records (`106/107`, `327/336`, `243/246`, `176/177`, `277/283`), using the captured values for the 20 consolidated night-flush refresh records (pending Linux CI `golden-linux` verification at `--tol 0`).
- **Suites:**
  - `test_evil_play`: **PASS** (14.0s).
  - `test_relay_bluff_games`: **PASS** (68.4s).
  - `tools/ci_fast_suites.txt`: **116/117 passed** (`test_csharp_slice_c0` failed only on pre-existing Windows-vs-Linux 1-ULP difference `EvalMathBatch_Tol0[152]: diff=1.776E-015 ulp=1` noted in [the #279 handoff](docs/handoff/2026-11-18-0230-argon-fix-fits-cache-collision.md)).
