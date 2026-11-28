# Moving freely within a block

- **Agent:** Claude-Beadle
- **Base:** main at `7b9a63c5` (`baseline_1bf8a4b`)
- **Branch:** `claude/beadle-free-move`
- **Status:** PR open.
- **Next actor:** Bailiff (review and merge). Herald drops the UI's last references to the old
  rule (see below).
- **Item:** Michael, Nov 28, via Seneschal: remove the "one free move per block" limit
  entirely, so the Demonologist moves freely within a block.

## What changed

- **`game/game_day_night.gd`:** once the phase's place is chosen, `go <place>` within the same
  block always works. `talk <name>` walks over to someone on the block every time. A move to
  another block still waits for the next phase, as before.
  - The errors "You've already moved once this …" and "… you've already used your free move"
    are gone.
  - The prompt hint "(or 'go <place>' once more within <block>)" is gone too: Herald's
    approved text for the rule went with it (Seneschal).
  - The out-of-block refusal loses its "(one free move per phase)" tail.
  - The spotted-someone note drops "using your free move".
- **`game/game_screens.gd`, the help text:** "(then one free move within the same block)" is
  now "(then move freely within the same block)". This is player-facing wording, so it's a
  draft for Michael.
- **`game/game_conversation.gd`:** accepting an approach no longer spends the free move.
- **`g.free_move_used` stays as a field that's never set true,** so the UI still compiles and
  always offers the step. `ui/main.gd`, `ui/main_actions.gd` and `ui/map_view.gd` still read
  it, and the map's "(free move)" hints are Herald's. Herald drops those references in the
  matching UI and navigation work, and the field goes with them.
- **`tools/autoplay.gd`:** the bot steps over only to someone it hasn't talked to today. That
  means it can't bounce between two places now that moves are unlimited.
- **`tools/test_ui_controls.gd`:** one check no longer expects an accepted approach to spend
  the free move.

## Measured

- **New:** `tools/test_free_move.gd`, 3 checks, on the fast CI list. Over 60 deals from seed
  900:
  - the Demonologist moved three more times within the block every time;
  - a move to another block was still refused;
  - `talk` walked over to someone on the block after those moves, every time.
  - The first check fails on main, where the second move is refused.
- **Also pass:** test_ui_controls, test_control_flow.
- **Golden:** see the PR. The golden bot doesn't drive the Demonologist's day moves.

## Small calls made on Michael's behalf

- The help line's new wording (a draft): "(then move freely within the same block)".
- The bot's new step-over rule (only to someone not yet talked to today).

## Proposed for the backlog

None.
