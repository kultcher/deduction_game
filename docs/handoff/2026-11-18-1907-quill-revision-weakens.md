# "This weakens your previous case": the detection

- **Agent:** Claude-Quill
- **Base:** origin/main `4ec65e1`
- **Status:** PR open. Zero drift.
- **Next actor:** Bailiff to merge, then Herald for the UI.
- **Decision:** Michael, Nov 18, via Seneschal. "A revised case must not score below the
  version it replaces" becomes a warning, not a rule, because belief follows the evidence.
  The wording is approved as written: "This weakens your previous case".

## What changed

- **`WorkshopCanvas.revision_weakens(g, value, previous, listener_id = "")`** returns {}
  or `{"text", "before", "after"}`. It compares the chance that the case's premise holds
  under the old version and under the revision.
  - With no `listener_id`, the Test juror judges.
  - With a `listener_id`, that listener's own view judges (`snapshot` with the listener).
  - Both cases are judged on their own.
- **When it warns:** only when the revision keeps the same conclusion (type, target and
  any secret). A revision that changes whom or what the case concludes is a different
  case, so it gets no warning.
- **It only warns.** Filing is unchanged.
- **Tests:** five checks added to `tools/test_public_revisions.gd`, now 31.
  - A card that clears the subject warns: the Test juror's chance goes from 69% to 24%,
    and one listener's from 70% to 24%.
  - Added support doesn't warn.
  - A revision about someone else doesn't warn.

## For Herald

Call `revision_weakens` when the player is about to file a revision. The function gives
the Test juror's view. For the audience a case is about to go to, pass a `listener_id`.
Show `text` as the warning. `before` and `after` are there if the UI wants to show how
much it drops.

## Small calls made on Michael's behalf

- "Less suspected" is read as "the case's own premise is less likely". For "X is evil"
  that's exactly less suspicion of X. For a "X is good" case it means more suspicion of X.
- No threshold: any drop warns, apart from rounding noise below one in a billion. Adding a
  threshold would mean a new number.

## Measured

- **Golden:** identical to `baseline_e287b3d` at `--tol 0`, all five seeds. Nothing in
  play calls the function yet.
- **Suites:** test_public_revisions, test_workshop_live_canvas and test_workshop_cases pass.
