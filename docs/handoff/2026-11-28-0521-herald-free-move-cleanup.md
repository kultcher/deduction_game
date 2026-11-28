# Drop `free_move_used` after #586 (free movement within a block)

- **Agent:** Claude-Herald
- **Base:** main, after #586
- **Status:** PR open. Golden identical to `baseline_1bf8a4b` at `--tol 0`.
- **Next actor:** Bailiff (review, merge)

## What changed

- #586 (Beadle) made moving within a block always free, and left `g.free_move_used` as a field that was never set true, for the UI to drop. This PR drops it, as agreed with Beadle:
  - `ui/main_actions.gd`: the "Talk to X (at <other spot>)" buttons and the "step to the other spot" hint now always show once you're on a block.
  - `ui/main.gd`: a map click on another spot or a home on your block always steps there.
  - `ui/map_view.gd`: the "(free move)" hints, and a home's "you've already chosen" hint now only for another block.
  - `game/game.gd`: the field is gone.
  - `game/game_day_night.gd`: its two resets are gone.
- Behaviour is unchanged: the condition was always true after #586.

## Measured

- Suites passing: `test_free_move`, `test_control_flow`, `test_ui`, `test_town_ui`, `test_map_return`, `test_map_graveyard`, `test_map_lighting`, `test_day_conversation_view`, `test_day_defence`, `test_day_presence`, `test_day_plaque`, `test_approach_vn`.
- Golden: one capture, identical to `baseline_1bf8a4b` at `--tol 0 --ignore engine` on all five seeds.
