# Scripts, script builder and New Case flow (2026-11-04)

Groundwork for an expanded role roster. Slices S1–S4 merged to `main` in PR #54 (`bdd1dc0`). The golden capture (seeds 42, 900 and 54875) is byte-identical to the previous `main`, so the Default script deals exactly what the game dealt before.

## Decisions

1. **Script**: the 15 town roles, 4 secrets, 4 minions and up to 4 demons that may be in play. It is public. Evil never bluffs or names an off-script role.
2. **Constraints are soft.** The editor and the New Case screen warn when a script doesn't cover the suggested tags, and the player may launch anyway. Only a script that can't be dealt at all is blocked (for example, too few town roles for a 10-person town, or more forced roles than there are slots).
3. **One script for every town size.** The in-play counts stay as they are: 7 players = 5 town / 1 secret / 1 minion / 1 demon; 10 players = 7 / 1 / 2 / 1.
4. **One demon per game.** A *Beginner* script lists only the default Demon; an *Advanced* script lists up to 4 demon types, depending on the solver cost. This is a property of the script, not a separate switch. No count-changing roles for now, but nothing rules them out.
5. **Exclude**: removing a role takes it off the script, so it can never be in play and claiming it is a giveaway. **Force in play** is for debugging and custom games, and can't exceed the counts.
6. **Every role gets at least basic solver integration before it goes live.**
7. **Tags:** first_night_info, ongoing_info, evil_id, demon_id, role_id, protection, night_walker. Difficulty ratings come later.
8. **The New Case screen** opens at launch and from More ▸ New case: Town Population → Script (Default / Load / Custom) → Start. Headless runs and `--quick-start` skip it.
9. **Scripts are saved as files** in `user://scripts/*.json`. A text code may come later.
10. **The draw guarantee stays.** The deal still retries until at least 2 start-knowledge gifts and one of Seer/Dowser/Gravedigger are in play. It is best effort if the script can't meet it, and the editor warns.

## Role tags (as built)

| Role | Tags |
|---|---|
| Archivist, Surveyor | first_night_info, evil_id |
| Clerk, Rumormonger | first_night_info |
| Seer | ongoing_info, demon_id |
| Dowser | ongoing_info, evil_id |
| Gravedigger | ongoing_info, evil_id, role_id |
| Medium | ongoing_info, night_walker, role_id |
| Psychologist | ongoing_info |
| Lamplighter | ongoing_info, night_walker |
| Night Watch | night_walker |
| Warden | protection, night_walker |
| Martyr, Sexton, Veteran | protection |
| Poisoner (minion) | night_walker |

Hearthwitch is `status = "benched"`, so it stays off the roster.

## What's where

- `sim/script_def.gd`:
  - script data and `default_script()`
  - `check(count)`, returning errors and warnings, with `SUGGESTED_TAGS`
  - `roster()`, `summary()`, `fingerprint()` and JSON save/load
- `sim/script_builder.gd`: `build()` / `fill()` top a script up to size, favouring the tags it is short of. It respects exclusions and keeps the base. It uses its own RNG, so building a script never shifts a case's world RNG.
- `sim/role_def.gd`: `tags` and `status` on every role.
- `sim/world.gd`:
  - `case_script` is set before `setup()`; null means Default.
  - `_assign_roles` deals forced roles first, then draws as before.
  - Bluffs and the Town Hall's out-of-play roles read the script.
  - A non-default script is logged as a `case_script` event.
- **Random false picks** read the script: Archivist, Clerk, Gravedigger and Rumormonger.
- **UI reads the script**: the Roles window, the ask menus, the profile guess dropdowns and the `script` screen.
- `ui/new_case_screen.gd`: the New Case screen.
- `ui/script_editor.gd`: the working-set editor. It has add/remove, *In play* forcing, a tag filter, *Fill to size*, *Reset to Default* and save/load.
- `game/game.gd`: `new_case(seed, size, case_script)`.
- `ui/main.gd`: `current_script`; the top-bar size picker is now hidden and set by the screen.
- **Tests**: `tools/test_case_script.gd` covers:
  - Default deal parity
  - exclusions never being dealt or bluffed
  - forced roles always being dealt
  - the checks
  - the builder
  - save/load
  - tags

## Still to do

- **S5, the off-script tell.** NPC reasoning (`deduction.gd`) and the solver should treat a claim to an off-script role as a lie. The solver's role options (`workshop_bridge.gd` sends `C.ROLES.keys()`; `live_case_workshop.gd` and `workshop_canvas.gd` use `C.GOOD_ROLES`) still cover the whole roster. This changes behaviour, so it needs a golden re-record and the C# port.
- **Multiple demon types.** Code across the sim checks `role == "demon"`. A second demon type needs an `is_demon` helper and solver support.
- **Builder rules** beyond tag counts (requires/excludes "jinxes", weights) once the roster is bigger than one script.
- **Remember the last script between runs** (it is session-only now).
