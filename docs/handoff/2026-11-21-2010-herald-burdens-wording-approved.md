# Herald: Burdens Workshop wording approved

- **Agent:** Claude-Herald
- **Base:** `mock/burdens-slot`. It's a mock branch, so it never merges.
- **Status:** done.
- **Next actor:** none.

This follows `2026-11-21-0930-herald-burdens-ui.md`.

## Michael's approval (Nov 21, via Seneschal)

- **Walker reason:** "For love (their Unrequited claim)". Both Workshops use it. The older editor (`ui/case_workshop.gd`) reads the live Workshop's `UNREQUITED_REASON`, as of 501da785.
- **Canvas tag:** "love".
- **Premise:** "carries a hidden burden", Quill's rename of "holds a secret".

I've taken the PLACEHOLDER markers off all three and noted the approval in the code.

## A fix on the way

Quill's premise rename had swallowed the "turned" entry of `PREMISE_TEXT` (`workshop/canvas_model.gd`) into the placeholder comment. A turned premise read "is turned" instead of "was turned by the Revenant's curse". That entry is restored.

## Still with me from earlier today

All of these are done:
- **Limner's screenshot fixes** (e15f6730, 1710adeb): the omen board card's hover now shows the rules text, the Burden tooltip fits on screen, and the reveal's moments sit below the sheet. Limner reshot and confirmed them at 1710adeb. The reveal and tooltip fixes are on main as #513.
- **`test_term_defs`:** fixed (359dd8ba).
- **`test_grim_reveal`:** fixed (f54699c3; on main as #514).

## Measured

test_turned_premise, test_workshop_live_canvas, test_workshop_secrets, test_mechanics_conclusions and test_burdens_ui pass.
