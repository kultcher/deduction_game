# Herald: saved boards from before the premise trim open cleanly

- **Agent:** Claude-Herald
- **Base:** main (after #416)
- **Status:** PR open
- **Next actor:** Bailiff

## What changed and why

Quill's #416 (Nov 20) removed three premise types and left updating old saved boards to me, as a follow-up (agreed with Quill). Before this, a board saved earlier showed "Agnes is minion" or "is role", and a conflict premise read "<no one> is conflict". All three were refused when presented.

`CanvasModel.migrate_retired_premises()` (workshop/canvas_model.gd) brings each retired premise up to date:

- **"is a Minion" becomes "is evil",** about the same person. It's a weaker claim, and the cards still argue it.
- **"holds their claimed gift" becomes "is good",** matching Michael's merge. The gift field is dropped.
- **"these reports conflict" becomes an unclaimed premise.** It had no subject, so its cards and links stay and the player picks the claim again.
- **Filed cases already on the board stay as filed.** They're history, and the refusal on re-presenting them is fair.

It runs wherever a board is read back:
- the live Workshop loading the case's saved draft (`refresh`);
- undoing a removal (`_undo_remove`);
- `CanvasModel.restore()`, before it validates the premises.

Running it again changes nothing. Zero drift: golden never loads a saved board.

## Measured

- **New `test_premise_migration`** (fast list, 12 checks): each retired type is updated, a current type is left alone, the conflict premise keeps its linked card, and a second run changes nothing. A saved draft opened in the live Workshop shows the new types, and so does an undo snapshot.
- **Workshop suites:** test_workshop_live_canvas, test_workshop_live_ui, test_workshop_canvas, test_workshop_ui, test_workshop_remaining, test_workshop_consequences, test_premise_step1, test_badge_text and test_workshop_nav pass.
- **Golden:** identical at `--tol 0` on all five seeds (baseline_58cb94a).

## Proposed for the backlog
None.
