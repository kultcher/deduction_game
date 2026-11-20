# Herald: the "points elsewhere" chip on a misframed accusation

- **Agent:** Claude-Herald
- **Base:** main
- **Status:** PR open
- **Next actor:** Bailiff. When it opens, Vicar is told so the item can close.

## What changed and why

Michael approved this on Nov 20, relayed by Seneschal, with the wording as drafted. When an accusation's evidence says more about someone else than about its target, the Workshop's strength chip now adds "· points elsewhere" after the band, e.g. "Weak · points elsewhere". Its tooltip gains: "This evidence may say more about someone else than about <target>." It names no one else.

- **One rule for both.** The rule a listener uses to say "present_points_elsewhere" is now a shared function, `points_elsewhere(w, rivals, skip)` in `sim/dialogue_presentations.gd`. The listener's reply and the test juror both call it. It looks only at the likeliest rival who is alive and not skipped, and counts them if the case raised their chance of being evil by more than 0.2, to above a half. The listener's path is unchanged, so there is zero drift.
- **Where the flag appears.** `test_juror` (`game/workshop_canvas.gd`) sets `points_elsewhere` only for accusing premises ("is evil", "is the Demon", "is a Minion", "is suspicious") whose band is Argues against, Negligible or Weak. The juror skips only the target, since it has no listener of its own.
- **The chip** (`ui/workshop_canvas_view.gd`) adds the suffix and the tooltip line. If the chip already reads "Doesn't fit" (clashing cards), the flag isn't shown, because that warning comes first. Each chip's tooltip record now carries its chip text, so the tests can read it.

## Small calls made on Michael's behalf

- **Which premises and bands get the flag:** the four accusing premises above, in the three bottom bands. "Lied", "is not their gift" and "is unreliable" are left out. Their evidence pointing at someone else is ordinary (the teller, for instance), so the flag would mostly be noise there. Moderate and above are left out because the case already carries the accusation.
- **"Doesn't fit" takes precedence** over the flag, as above.

## What a player will see

- The juror judges with public facts and default trust. A single pairing reading never raises another person past a half, so the flag is rare and needs a real misframe.
- In the new suite's case, three seers each pair the target with one person and get a ping, then clear the target against another. A case that the target is evil then reads "Argues against · points elsewhere". The person it points at is one of the seers, whose readings the accusation would make false.

## Measured

- **`test_points_elsewhere`** (new, added to the fast list): the misframed case is flagged; the same readings behind "is good" aren't; a single pairing reading isn't. 6 checks.
- **`test_badge_text`:** 9 new checks:
  - the chip text and tooltip, with no other name;
  - the band alone without the flag;
  - the shared rule's thresholds, its skip list, and that only the likeliest eligible rival counts.
- **Golden:** identical at `--tol 0` on all five seeds.
- **CI fast suites:** all 150 pass locally, the new one included.

## Proposed for the backlog
None.
