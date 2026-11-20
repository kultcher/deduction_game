# Herald: the last of game.gd's forwards (passthroughs, PR 3 of 3)

- **Agent:** Claude-Herald
- **Base:** main (after #424)
- **Status:** PR open
- **Next actor:** Bailiff

## What changed and why

This is the last of three PRs removing game.gd's one-line forwards (Michael, Nov 19). PR 1 (#385) deleted the 25 that nothing called. PR 2 (#424) pointed game/, sim/ and ui/ at the modules and deleted 20. Zero drift.

- **Repointed:** every remaining caller of the 62 forwards #424 left now calls the module that does the work. Most of these are tests and tools (116 files), for example `g.add_card(x)` → `GameBoard.add_card(g, x)`. The rest are game.gd's own command table, such as `_screen(_help())` → `_screen(GameScreens._help(self))`. #424's script missed those calls because they sat inside another call. That was harmless while the forwards still existed.
- **Deleted:** all 62 forwards. game.gd now keeps only the 23 public forwards the UI and CLI call. A new header in game.gd names them and says to call the modules directly.
- **Built by script** (`repoint.py`), with these by hand:
  - test receivers other than `g`/`game` that hold a game: `g2`, `g_press`, `g_req`, `due`, `off`, `on`, `a`, `b`, `lone`;
  - the module preloads in test_roles_registry;
  - test_roles_registry's check that `Game.timeline_data` forwards identically, removed now that the forward is gone (the `filter_cards` check, a kept forward, stays);
  - two comments that named the old forwards, now naming the modules;
  - after merging main: main's side of #420's test removals in test_workshop_integration and test_workshop_reading_identity, and #428's two new `_evaluate_deduction` calls in test_connections_cases.

## Measured

- **All 240 suites pass locally** before the main merge, in two runs of 120. Golden is identical at `--tol 0` on all five seeds (baseline_58cb94a).
- **After merging main:** a scan finds no call to any deleted forward on a game, and the script finds no new callers. test_workshop_integration, test_workshop_reading_identity, test_connections_cases, test_premise_migration, test_workshop_live_ui, test_roles_registry and test_control_flow pass.

## Proposed for the backlog
None.
