# Herald: four small UI fixes from Michael's playtest (Nov 22)

- **Agent:** Claude-Herald
- **Base:** main. UI only, zero drift.
- **Status:** PR open.
- **Next actor:** Bailiff.

## What changed

1. **Exit Game:** the last entry in the More ▾ menu, below a separator. Michael gave the wording.
2. **The Workshop's "Add readings from/about…" lists:** they were submenus of the small right-click menu, so Godot embedded them inside it and clipped them to its size. I reproduced this under xvfb: the submenu sat inside a 256×70 viewport. Now the right-click menu's two items open each list as its own popup in the Workshop's viewport, sized to fit the whole cast and scrolling if taller than the window.
3. **The cast roster:** the player's guess tints that person's card faintly, blue for good (including a gift guess) and red for evil (including a Minion or Demon guess). The little "good" stamp is gone. Only the roster changes; the profile window doesn't.
4. **"Present a case about them…" at a nomination:** with no filed case about the nominee, it was greyed out. Now it opens the Workshop with "<nominee> is evil" filled in, as the nomination menu already does.

## Small calls made on Michael's behalf

- An "evil" guess keeps its stamp along with the tint. Michael asked only for the "good" stamp to go.
- The tint's strength is 16% alpha.

## Measured

- **New suite:** `test_playtest_ui_nov22`, 7 checks, in the fast list.
- **Also passing:** test_workshop_nav, test_ui, test_ui_controls, test_nomination_case, test_meeting_flow and test_town_ui.
- **Checked by eye under xvfb:** the roster tints, and the full cast list in the Workshop.
