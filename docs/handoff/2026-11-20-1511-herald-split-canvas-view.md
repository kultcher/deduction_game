# Herald: the Workshop canvas's card layouts move to their own file

- **Agent:** Claude-Herald
- **Base:** main
- **Status:** PR open
- **Next actor:** Bailiff

## What changed and why

This is the second Tier 2 split (Argon's audit; Seneschal's go, Nov 20). It's one file, and zero drift.

`ui/workshop_canvas_view.gd` (1,412 lines) mixed drawing, input and card text. Its card layouts move to `ui/workshop_card_layout.gd` (417 lines): what each kind of card shows, with its rows, faces, fields and tooltips, and its height. The view keeps the drawing and the input, at about 970 lines.

- **What moved** (each now takes the view as `m`):
  - the five layouts: `evidence_layout`, `profile_layout`, `circumstantial_layout`, `trace_chain_layout` and `whereabouts_layout`;
  - their helpers: `time_text`, `people_home`, `unsupported`, `again_clause`, `chain_traces` and `chain_trace_text`.
- **Callers call the module directly:** the view itself, and test_workshop_nav's `unsupported` check.
- **Built by the same split script.** No callable needed a hand edit.

## Measured

- **All 31 suites that open the Workshop UI or use the view or the new module pass locally.**
- **Golden:** not captured, since the change is UI only. CI runs the diff.

## Proposed for the backlog
None.
