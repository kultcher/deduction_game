# Herald: the live Workshop's field editors move to their own file

- **Agent:** Claude-Herald
- **Base:** main
- **Status:** PR open
- **Next actor:** Bailiff

## What changed and why

This is the first Tier 2 split (Argon's audit; Michael, Nov 19; Seneschal's go, Nov 20, once the Tier 1 splits were on main). It's one file per PR, and zero drift.

`ui/live_case_workshop.gd` (1,515 lines) loses its premise and card-answer editors, about 380 lines, to `ui/live_workshop_fields.gd`. The audit pointed at that seam. The file is now about 1,110 lines.

- **What moved** (each now takes the editor as `m`): `premise_details`, `add_premise`, `set_premise_field`, `prefill_premise`, `default_detail`, `reports_for`, `detail_label`, `field_popup`, `field_chosen`, `set_evidence_field` and `reason_menu`. That's the premise card's fields and their pop-up menus, filling a premise in, and the reading-challenge and reason controls on a card.
- **Callers call the module directly**, with no forwards left behind: `ui/main_pickers.gd` (the nomination's "prefill a premise") and five suites: test_workshop_live_canvas, test_workshop_reading_challenges, test_mechanics_conclusions, test_workshop_nav and test_workshop_secrets.
- **Built by the same script** as the `ui/main.gd` split, extended with the base classes' members. Four callables were rewritten by hand: the "Add premise" button, the canvas's `field_requested` and `detail_label`, and the field menu's `id_pressed`. The state, the widgets and the rest of the editor stay put.

## Measured

- **All 29 suites that open the Workshop UI or call the new module pass locally.**
- **Golden:** not captured, since the change is UI only. CI runs the diff.

## Proposed for the backlog
None.
