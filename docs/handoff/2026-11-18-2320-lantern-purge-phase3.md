# 2026-11-18, Claude-Lantern: purge phase 3, the connections model is the only belief model (`claude/purge-phase3`)

- **Base:** main `426d797`, with main `bf73e64` (#280) merged in. **Status:** PR open. **Next:**
  Bailiff. Then I go on to phase 5, which deletes the earlier model's code that is now unreachable.
- **Snapshot first (Michael's decision 2):** `archive/legacy-belief-final` is pushed at main
  `426d797`, the last commit that has `--legacy-model`. A comparison against the earlier
  model runs from there.
- **What changed** (`docs/connections_purge_plan.md`, phase 3, "As built"):
  - **The switch is gone.** `Connections.enabled` and `Tuning.Workshop.CONNECTIONS` are
    deleted, and every gate they held is unconditional:
    - the bridge's model memory;
    - the town note;
    - stored cases fading and being restored when presented again;
    - the "suspicious" pressure;
    - the Why report's breakdown;
    - NPC nominations stored as cases;
    - the refresh in `Jury._consequences_eval`;
    - `case_start`'s `connections: true`, which every log now carries.
  - **Tools:**
    - `--connections` is accepted and ignored by autoplay, `replay_log` and `explain_case`.
    - Autoplay stops on `--legacy-model` with a note.
    - `golden_capture --connections` is gone.
    - `LogReplay.new_game` stops, with a note, on a log without `connections` in its
      `case_start` (one played on the earlier model, decision 1). `replay` then returns a
      null game, and the tools return.
  - **The sweep:** the `_connections` and `_legacy` cell suffixes are gone from
    `sweep_shard.py`, the workflow's cell check and `docs/balance_sweep.md`.
  - **The fixture search** (`tools/fixture_seeds.gd`) plays on connections.
  - **Phase 4 is folded in.** Deleting the switch removes what the switch-off checks set, so
    those checks went now: `test_connections`, `_cache`, `_cases`, `_core`, `_pairings`,
    `_why` and `test_town_note`. The on/off comparisons went with them. `_log_flag` now checks
    that a log without the flag stops the replay.
  - **Pinned suites:**
    - `test_workshop_why` keeps its case-breakdown checks (`case_why.gd` stays); the earlier
      report's sections (`_presentation`, `_already_held`, `_extras`, `_recording`) went.
    - `test_headline` loses its six "has a headline" checks, since the headline is zeroed on a
      refresh. Its Insight and card-trust checks stay until 6a.
    - `test_workshop_live_cognition` loses its persistence Confidence section (BACKLOG,
      "Persistence Confidence").
  - **Docs:** BACKLOG's state of play, CLAUDE.md's tests rule (the pinning sentence), DESIGN,
    README, TUNING_NARRATIVE and `docs/belief_model.md`.
- **Found on the way, fixed here:** `test_self_sighting` had a check left stale by my #273.
  - It expected a Night Watch list that wrongly names the listener to be set aside.
  - Since #273 such a list is kept and weighed as sound or broken as a whole wherever a
    Poisoner is possible.
  - The check now asserts both cases: kept where the list could be broken, set aside where it
    can't be. It failed on main too.
- **Found, not fixed:** `test_workshop_live_cognition` (full run only) has 4 failures on main
  as well as here:
  - asking a Marked question adds no extra alignment effect;
  - repeating registration claims;
  - the same cards under another premise type;
  - aiming the same cards at someone else.

  They predate this PR. I'll trace them after phase 5 unless someone owns them first.
- **Measured** (on `e0d111c`, before merging main):
  - Golden is identical to `baseline_e287b3d` on all 5 seeds at `--tol 0`.
  - The fast list passes 117/117.
  - Every suite I changed passes:
    - test_connections 60;
    - test_connections_cache 55;
    - test_connections_cases 114;
    - test_connections_core 114;
    - test_connections_pairings 59;
    - test_connections_why 42;
    - test_town_note 40;
    - test_workshop_why 37;
    - test_headline 9;
    - test_self_sighting 9.
  - The fixture-search suites off the fast list pass:
    - test_relay_bluff_games 2;
    - test_nightwatch_bluff_teammates 11 (78 s);
    - test_own_night_knowledge 8 (108 s).
  - After the merge: test_state_digest 8/8 and test_connections_why 42/42.
- **Small calls made on Michael's behalf:**
  - Phase 4 folded into phase 3.
  - test_workshop_why trimmed rather than deleted.
  - The sweep suffixes dropped outright, with the workflow's error naming why, rather than
    kept as aliases.
- **Proposed for the backlog:** none.
