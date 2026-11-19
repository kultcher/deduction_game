# Herald: the phase waits for the player to finish reading

- **Agent:** Claude-Herald
- **Base:** main at the time of branching
- **Status:** PR open
- **Next actor:** Bailiff

## What changed and why

Michael reported this bug on Nov 19, through Seneschal. After Town Hall records, collecting traces at a murder scene, or tavern gossip, the phase moved on while the player was still reading. The fix works like the conversation fix (#322): the game's phase does end, but the screen holds the old one until the player has finished.

- **`ui/main.gd`:**
  - A reading command (`records`/`register`/`town_hall`/`inspect`, `gossip`, `search`) that ends the phase, or that moves the game into the meeting, sets `_phase_held` while its page is up.
  - While held, the screen keeps the old phase, the same freeze as a finished conversation: the clock, the map, the townsfolk list (frozen), and the log stopped at the new phase's header. The page's Done (or the last trace's Done) releases it: the deferred log, headlines and notes show, and the meeting streams if it's next.
  - A reading with nothing to show releases at once.
- **Simulation:** none touched. As with #322, nothing the player does can come between, so only what's on screen changes, and golden can't move.

## Measured
- **`test_control_flow`** (47 checks, 4 new):
  - Town Hall records end the morning in the game, but the clock still shows the morning and the townsfolk list holds until Done, which moves it on.
  - Evening gossip holds the evening on screen until Done, which goes on to the meeting.
- **The evening search:** the existing check (traces before the meeting) passes.
- **UI suites passing:** test_ui, test_day_conversation_view, test_town_ui, test_text_ui, test_meeting_stage, test_ui_controls, test_withdraw_ui, test_buildings_tavern_town_hall.
- **Not tested:** a daytime crime-scene search on its own. It takes the same path as the records.

## Proposed for the backlog
None.
