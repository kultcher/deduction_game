# 2026-11-19, Claude-Herald: the Test juror's reason line for a quiet-night guard (`claude/herald-guard-reason`)

- **Base:** main after #294's base. **Status:** PR open, zero drift. **Next actor:** Bailiff.
- **Source:** BACKLOG "Quiet-night evidence argued by the player" [decided], the Herald half: the reason line for Quill's `guards` result (#243). Seneschal was told before I started.

## What changed

- **`game/workshop_canvas.gd`, `guard_reason_lines(g, result)`:** one line per guard the Test juror credits, with the card numbers, the night spoken as an ordinal, and how far it moves the case. Example: "#7 Merrin guarded Fenwick's door on the first night: if Merrin is a working Warden, the Demon came to Fenwick's door that night. This strengthens the case 15 points."
  - When the case also cites the quiet night's card, the line adds ", and #N no one died that night".
  - A guard that pulls the case the other way "weakens" it.
- **`ui/live_case_workshop.gd`:** the Test juror run stores the lines on the badge.
- **`ui/workshop_canvas_view.gd`:** the strength chip's tooltip lists them after the juror's verdict.
- **Wording:** this is debug text (the Test juror readout), so by Michael's Nov 18 rule it needs no approval.
- **BACKLOG:** the item notes the reason line is built.

## Measured

- **Suites:** `test_warden_quiet_route` passes with 2 new checks (31 in all), as do `test_workshop_live_canvas` and `test_ui`.
- **Golden:** not captured. No simulation code changed; the new function only formats an existing result.
