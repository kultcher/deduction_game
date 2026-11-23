# 2026-11-22, Claude-Limner: papercraft portraits, the gallows and the growing graveyard (claude/paper-portraits)

- **Agent:** Claude-Limner
- **Base:** origin/main `56feb996`
- **Status:** PR open. Presentation only: nothing in `sim/` or `workshop/` changes, so golden
  can't move.
- **Next actor:** Bailiff to merge, then Michael to try them in play.
- **Decisions:** Michael, Nov 22, directly:
  - swap in the 15 new papercraft portraits (Codex-made) for the large VN portraits, to see
    how they feel in play. The small icons and portraits stay as they are for now.
  - **Expressions:** mix the styles. The new art is each person's neutral face; the other
    four expressions keep the older art until papercraft ones exist.
  - put the gallows on the green in the middle of the town map, about a cottage's size.
  - make the graveyard dynamic: the gates and one headstone at the start, and one more
    random headstone for each death, hanging or murder, with no repeats for as long as
    possible.
  - a normal PR to main.

## What changed

- **`assets/art/portraits_paper/<id>.webp`:** the 15 portraits, 1024×1536 like the old ones,
  named by cast id (bart, merrin, odette, dorian, jory, hollis, lian, kiran, constance, nisha,
  agnes, fenwick, greta, isolde, edda), from Michael's list.
- **`ui/vn_portraits.gd`:** `texture(id, "neutral")` returns the papercraft portrait. The
  other expressions are unchanged. The old neutral files stay in the repo, so swapping back
  means removing the two new lines in `texture()`.
- **`assets/art/decor/gallows.png` and `assets/art/graveyard/`:** the gallows, the gate, and
  seven headstones (two wooden crosses, a Celtic cross, two crosses and two sprigs in stone).
  Each is cropped to its art and scaled to at most 700 px.
- **`ui/map_view.gd`:**
  - **The gallows:** drawn on the central green at map pixel (740, 428), 110 px wide. It's
    dressing only, with no hit box or sign, and it takes the night tint.
  - **The graveyard:** drawn from its parts instead of `buildings_paper/graveyard.png`.
    - The gate stands at the front of the graveyard's lot.
    - It starts with one headstone and gains one for each dead townsperson, in two rows
      behind the gate, then one either side of it. There are 15 places.
    - The headstones follow a shuffled order of the set of seven, fixed by the case's seed.
      There's no repeat until all seven are used, and never the same one twice in a row.
      It uses its own random generator, so the game's RNG is untouched.
    - Its sign and hit box cover what's drawn.
- **`tools/test_map_graveyard.gd`:** 13 checks, about 6 s. Added to `tools/ci_fast_suites.txt`.
  - **Headstones:** the same case draws the same headstones; there are no repeats within
    the set and none twice in a row; a new death leaves the earlier stones as they were;
    different cases differ.
  - **Count:** one headstone at the start, then one more per death.
  - **Art:** every headstone, the gate and the gallows have theirs.
  - **The game's RNG:** untouched.
  - **Portraits:** every cast member's neutral face is the papercraft portrait, and the
    other expressions still use the older art.

## Measured

- **Suites:** all pass through the runner: `test_map_graveyard` 13/13, `test_map_return`,
  `test_approach_vn`, `test_day_conversation_view`, `test_ui`, `test_meeting_stage`,
  `test_response_bundles` and `test_review_fixes`.
- **Golden:** not captured. No game logic changed.
- **Screenshots:** at 1920×1080 in a real renderer:
  - the map at the start, with five dead, and with every good townsperson dead (deaths
    staged);
  - a conversation with Bartholomew.

## Not done

- **Small portraits:** the roster circles, map pins and profile still use the older art, as
  Michael asked.
- **Expressions:** the warm, harsh, concerned and sorrowful faces are still the older art.
- **The layout scene:** the gallows' place is a constant in `map_view.gd`, not yet a node in
  `ui/map_layout/map_layout.tscn`. It could move there if Michael wants to drag it in the
  editor.
