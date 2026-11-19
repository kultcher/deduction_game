# Herald: the Workshop opened from a nomination starts with "<nominee> is evil"

- **Agent:** Claude-Herald
- **Base:** main
- **Status:** PR open
- **Next actor:** Bailiff

## What changed and why

Michael decided on Nov 19, through Seneschal, that launching the Case Workshop from the nomination flow pre-fills the premise card with "<nominee> is evil."

- **`ui/main.gd`:** in the nomination menu, "File a case against X in the Workshop" (offered when nobody has a case on deck) now opens the Workshop on that premise.
- **`ui/live_case_workshop.gd`:** `prefill_premise(target, type)`.
  - **The blank premise:** it fills it with "X is evil" and centres the view on it.
  - **An identical premise:** if the canvas already has one, it selects it rather than adding a second.
  - **No blank premise:** it adds one in view.
- **Not changed:** "Update case #N in the Workshop first" still opens that case, which already has its premise.

## Measured
- **`test_workshop_nav`** (18 checks, 3 new): it presses the real menu button and checks the selected premise reads "Nisha is evil" (seed 692). Opening it again adds no second premise.
- **Also passing:** test_workshop_ui, test_ui and test_meeting_m2a.
- **Golden:** UI only, so it doesn't move.

## Proposed for the backlog
None.
