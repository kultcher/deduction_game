# 2026-11-18, Claude-Lantern: test_relay_bluff built by hand, with a played-game guard for #265 (`claude/relay-bluff-by-hand`; tests only, zero drift)

- **Base:** main `3aef738`. **Status:** PR open. **Next:** Bailiff.
- **What:** BACKLOG "Build test_relay_bluff's evil-relayer and invented-relay checks by hand"
  ([decided], Michael, Nov 18).
  - **`test_relay_bluff`:** every check is now a town built by hand on the 7-NPC deals of
    seeds 692, 900 and 42, with no play and no seed search. One builder (`_built_relay`)
    gives a good or evil Medium, and a relayed sighting of a good person, an evil one, or the
    listener on a night they were home. It runs in about 6 s (was about 3 min), so it's added
    to the fast list.
  - **`test_relay_bluff_games` (new):** the two searched evil-relayer checks, kept as the
    regression guard for #265's bug, which the built towns don't reach. Michael chose this
    (option A, Nov 18). It runs on main with the full list, not the fast list.
- **Measured on main:**

  | Check | Result |
  |---|---|
  | Genuine Medium, true relay | costs it 3–8 points (692: 0.46 → 0.54/0.53; 900: 0.48 → 0.51/0.53; 42: 0.35 → 0.43) |
  | Evil relayer | relays raise it 3–10 points, never clear it (692: 0.36 → 0.39/0.41; 900: 0.48 → 0.52/0.58; 42: 0.53 → 0.60/0.58) |
  | Invented relay of the listener while home | relayer at 0.83 / 0.88 / 0.90 |
  | Games suite | seeds 100009 (0.84 → 0.97) and 100031 (0.96 → 1.00) |

- **What the built towns don't catch:** on pre-#265 `832bd17` the hand-built suite passes too.
  I made two attempts to build #265's case by hand, both failing to reproduce it:
  - a crowded contest, with one other sighter telling two sightings and the dead ahead of the
    relayer in town order;
  - the same with a Seer's "yes" on the relayer first.
  The old and new code gave nearly the same numbers, hence the games suite. Its checks caught
  the bug on `832bd17` earlier today (Hollis 0.83 → 0.46).
- **Also:** `tools/test_nightwatch_whole_list.gd.uid`, missing since #273 (it missed #274's merge).
- **Tests:** `test_relay_bluff` 3/3, `test_relay_bluff_games` 2/2 on main. Tests only, so golden
  is untouched.
