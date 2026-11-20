# Herald: split ui/main.gd into modules

- **Agent:** Claude-Herald
- **Base:** main
- **Status:** PR open
- **Next actor:** Bailiff

## What changed and why

This is step 2 of the cleanup rollout (Michael, Nov 19, via Seneschal). `ui/main.gd` had grown to 1,909 lines. It now keeps only the screen's state and the command flow, 692 lines:
- `_run` and the held phases (a finished conversation, a reading);
- the meeting stream;
- `_refresh_all`;
- the side panel and the log.

Four static modules, each taking the main control as `m`, hold the rest:

| Module | Lines | What it holds |
|---|---|---|
| `ui/main_layout.gd` | 380 | the screen as `_ready` builds it: the title bar, the map and its views, the townsfolk, the profile, the action pane and log, the card sidebar, the notes and script windows |
| `ui/main_actions.gd` | 324 | the action pane for each state of the game, the approach's VN steps, "Talk to" |
| `ui/main_pickers.gd` | 344 | the menus the pane opens (cards, people, blocks, questions), the nomination and podium menus, the ward and withdraw confirmations |
| `ui/main_roles.gd` | 165 | the script sheet: opening, pinning and building it, team colours |

- **The widgets and state stay on main.** Tests that read `scene.actions`, `scene.roles_box` or `scene.popup` are unchanged.
- **Callers call the modules directly,** tests included (`MainActions.refresh(scene)`, `MainRoles.open(scene)`). No forwarding function is left behind, in line with Michael's direction on passthroughs.
- **Three local variables named `m` were renamed** so the modules can use `m` for the main control.
- **Behaviour is unchanged.** The split was done by a script, which prefixed main's members with `m.` and routed calls to the moved functions. Only eight callable references needed a hand edit.

## Measured

- **Suites:** all 239 pass locally on the split (one run hit the hour limit after 159; the other 80 ran separately). After merging main, the eleven suites that drive the main screen pass again.
- **Golden:** identical at `--tol 0` on all five seeds.
- **Screenshots:** the real screen in five states (the script sheet at the start, the day, a conversation, after it, the meeting) matches main by eye. Pixel diffs aren't usable here, because two runs of main differ from each other in where the log has scrolled to.

## Proposed for the backlog
None.
