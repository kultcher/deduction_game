# Split world.gd (Tier 1)

- **Agent:** Claude-Beadle
- **Base:** main at `174191e` (`baseline_9fa5a74`, with #397, #404, #405 and #421)
- **Branch:** `claude/beadle-split-world`
- **Status:** PR open. Zero drift: golden is identical to `baseline_9fa5a74` on all five seeds.
- **Next actor:** Bailiff (review and merge).
- **Item:** Michael's Nov 20 order, item 1, the cleanup: "File splits", Tier 1, the third of four
  (after #404's mind_meeting.gd and #417's mind_dialogue.gd). It was waiting on Quill's #397.

## What changed

No change to play. Code moves only. World's methods are instance methods on one object, so the
split is a single inheritance chain, not separate modules:

| File | Lines | Holds |
|---|---|---|
| `sim/world_base.gd` (new) | 422 | the case's state (every `var`), the constants, the helpers, `is_minion_suppressed`, the dev snapshots |
| `sim/world_meeting.gd` (new) | 372 | the meeting's flow, votes, executions, the Martyr and the Scion, grief |
| `sim/world_night.gd` (new) | 753 | the night: kills, movement, sightings and traces, gifts and abilities, day gifts |
| `sim/world.gd` | 537 | setup and the deal, the day phases, the start of a new day |

- **The chain:** `world.gd` extends `world_night.gd`, which extends `world_meeting.gd`, which
  extends `world_base.gd`.
- **No caller changes:** `World.new()` and every `w.<method>` and `w.<field>` caller are unchanged,
  and there are no forwarders.
- **The layout keeps every call pointing down the chain.** GDScript can't call a subclass's method
  bare from its base, so:
  - `is_minion_suppressed` (used by the meeting) went to the base;
  - `start_new_day` (it calls `start_phase`) stayed on top.

  The split script checks that no call points up.
- **Line check:** every non-blank line of the old world.gd appears exactly once across the four
  files.
- **Docs and tests:** `test_tuning_hoist` checks each moved constant in its new file, and the
  README code map is updated.
- **The split was done by a script,** so it re-runs on a newer main. It was re-run once on top of
  #405, which edited world.gd.

## Measured

- **Golden:** identical to `baseline_9fa5a74` at `--tol 0`, on main with #405 and #421.
- **Suites:**
  - **The CI fast list:** 159 of 159 pass on the first build, on main with #397. That run also
    covered test_tuning_hoist, the role suites (evil, people, dead, shelter, night sight) and
    test_decision_inspector.
  - **After rebuilding on main with #405:** 17 of 18 pass across the role, meeting, evil-play,
    state-digest, haunt, social and vote suites. The 18th, test_kill_score_roles, wasn't on main
    yet.
  - **After merging #421:** test_kill_score_roles, test_tuning_hoist, test_roles_registry and
    test_evil_play pass.

## Proposed for the backlog

None.
