# "Travel to <block>" with a confirmation (Michael's Nov 28 item 6)

- **Agent:** Claude-Herald
- **Base:** main at 6770f32e
- **Status:** PR open, zero drift (UI only)
- **Next actor:** Bailiff (review, merge)

## What changed

- **Item 6 (Michael, Nov 28, via Seneschal):** in a block's close-up, before you've chosen where to spend the phase, a "Travel to <block>" button sits at the foot of the map. It opens a confirmation in Michael's example layout:
  > Visit the Square this morning?
  > Locations:
  > • Drowned Lamb tavern: Odette
  > • Town well: no one you can see
  > • Town Hall: 3/3 Check Records uses remaining
  > • Living here: Greta
  - It shows only what the player could know:
    - people you can make out, by name, with "(busy)" when they're talking with someone;
    - the rest as "+N other(s)", by the same rule as the map's counts (`can_see_ui` / `unseen_at_ui`);
    - the Town Hall's reads left (mornings and afternoons, when it's open);
    - the block's residents, with "(dead)".
  - A "Don't ask again" tick skips the question from then on. It's kept per viewer in `user://settings.cfg` (`[travel] skip_confirm`), like the VN auto-advance setting.
  - Code: `ui/travel_confirm.gd`; the button is wired in `ui/main_layout.gd` and placed in `ui/main.gd` (`_sync_travel_button`, run each frame).
- The left panel's existing "Visit <block>" goes through the same confirmation, so the two don't behave differently. Clicking a spot on the block still goes straight there.
- **Flaky tests:** the same `test_day_plaque` / `test_audit_ui` fix as #571, #587 and #589, with identical content.

## Small calls made on Michael's behalf

The wording comes from his example. The rest is mine, so he can change it:
- "no one you can see" for an empty spot.
- "Don't ask again", "Stay" and "Travel" on the dialog.
- "Travel to the Square" on the button (his own phrase).
- "Visit" in the left panel asks too.
- The tick shows as "☐ / ✓" in its text, because the theme draws checkboxes without a box. That's true everywhere, and Limner may want to look at it.

## Measured

- New suite `tools/test_travel_confirm.gd` (14 checks, in the fast list; 3 repeat runs):
  - no button on the whole-town map, and "Travel to the Square" in the close-up;
  - the title;
  - nobody out of sight is named, everyone in sight is, and the rest are counted;
  - the Town Hall line, the residents, and the dead marked;
  - it asks before moving, Travel goes, and the tick is kept;
  - the button goes once you've moved, and a ticked setting travels without asking.
- `test_control_flow`'s Visit check now confirms first.
- Suites passing: `test_travel_confirm`, `test_control_flow`, `test_ui`, `test_playtest_ui_nov22`, `test_day_plaque`, `test_audit_ui`.
- Checked by eye at 1280×800 and 1920×1080.
