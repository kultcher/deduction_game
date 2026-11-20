# Herald: remove the Workshop's fixture-only code

- **Agent:** Claude-Herald
- **Base:** main
- **Status:** PR open
- **Next actor:** Bailiff. When it merges, tell Lantern, who can then drop the `legacy_path` stub in `workshop/jury.gd`.

## What changed and why

This follows the dead-labs PR (#381): the standalone Workshop lab scenes are gone, so the code only they reached goes too. Seneschal took it as a small call on Michael's behalf (Nov 20), under the approved dead-labs group. Zero drift.

`ui/case_workshop.gd` (1,025 → 326 lines) and `ui/case_workshop_canvas.gd` (586 → 171 lines) are the live Workshop's base classes. A reachability pass took every method of `ui/live_case_workshop.gd`, any method other UI calls on the editor, and Godot's callbacks as roots. It then followed calls through the class chain, where a call runs the most-derived definition and `super` reaches the parent's.

- **Removed:** 25 methods of the base and 18 of the canvas that never run under the live Workshop. They're the fixture case pane, evidence list, jury window, Save/Open, the experiment picker, Load mockup and the scene's own `_ready`, plus copies the live Workshop overrides. Unused members and preloads went with them.
- **Kept as stubs:** ten methods (seven in the base, three in the canvas) that shared helpers call but only a subclass defines (base: `_active_choices`, `_card_available`, `_edit`, `_refresh_case`, `_identity_hint`, `_marked_answers`, `_auto_claims`; canvas: `_session_changed`, `_sync`, `_extend_context`). GDScript needs them declared where they're called, and each notes which class overrides it.
- **The jury window's "Show calculation" block** is gone with the jury window, so `jury.gd`'s `legacy_path` stub has no reader.

## The four suites (per Seneschal: move what the live Workshop still has, cut fixture-only checks)

**Moved to the live Workshop** (a new section in `test_workshop_canvas`, on real readings in a live game):
- left-drag moves an evidence card;
- the link handle, then a destination, connects two cards without starting a drag;
- a reading's answer slot records the chosen answer;
- the chosen slot survives the answer window's rebuild;
- a count-two Dowser reading offers two slots, and a later slot can be answered while an earlier one stays unknown;
- a duplicate slot is blocked with specific feedback.

**Cut: already covered on the live Workshop:**
- dialogs share the embedded layer (`test_workshop_live_canvas`, `_main_ui`);
- the preview opens a separate window and changes nothing (`test_workshop_live_canvas`).

**Cut: fixture-only.** The live Workshop has no such control or behaviour:
- **Merging and unmerging:** linking a vigil and an alibi merges them into one contradiction card, and right-click Unlink restores them. The live editor keeps contradicting cards separate, joined by a link (`contradiction_links`), and the model-level merge and unmerge stay covered in `test_workshop_canvas`.
- **The fixture's mockup, jury and Save/Open:** Load mockup; Present opening the jury window; remembered-mode no-farming through the fixture's Present; Save/Open of fixture canvas files, in `test_workshop_canvas`, `test_workshop_ui` and `test_workshop_remaining`. The game's own no-repeat rule stays covered in `test_presentation_contracts`.
- **The fixture's list editor** (`test_workshop_ui`): the Surveyor block slot, the gift citation picker, the conflict-argument target and scope, reasoning lines, the test-factor ratio, Compare Insight, and the reasoning and confidence modes.
- **The fixture case pane's controls** (`test_workshop_remaining`): the experiment picker, the poison explanation, the converted voter on a fixture curse event (live curse cards are `curse`, not `event`), and the claim epoch. The live premise editor has its own epoch control.
- **The jury window's collateral-effects and claim panels** (`test_workshop_consequences`).

`test_workshop_ui` keeps its three main-menu checks; `test_workshop_consequences` and `test_workshop_remaining` keep all their model checks.

## Measured

- **Golden:** identical at `--tol 0` on all five seeds.
- **The four suites:** pass (canvas 69 checks, consequences 44, remaining 51, ui 3).
- **The fast list plus every `test_workshop*`, `test_ui*` and `test_mistake_signpost` suite:** see the PR.

## Proposed for the backlog
None.
