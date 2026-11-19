# "X was turned by the curse": a time-scoped Revenant premise

- **Agent:** Claude-Quill
- **Base:** origin/main at 634332e
- **Status:** PR open; zero drift.
- **Next actor:** Bailiff to review and merge. Herald for the menu wording, and whether to
  hide the option before a curse.
- **Item:** BACKLOG "Time-scoped Revenant possession premise" ([decided], Oct 21). Picked
  from my domain's [decided] items; Seneschal told.

## What I found first

The curse already had its own time in the judge. The worlds carry the turned soul, and
it's evil only while the curse holds (`workshop/chronology.gd`, epochs before, during
and after). So "X is evil during the curse" was already arguable, and it judged X's word by
the time each statement was made. What it couldn't say was that X was turned: "evil during
the curse" also holds in the worlds where X was evil all along, so it still casts doubt on
X's history before the curse.

## What changed

- **A new premise type, "turned"** (`Solver.holds`, `CaseEval._build_premise_mask`): X is the
  soul the curse turned. It's good before the curse, evil only while it held, and good again
  after. The mask is built in GDScript, one comparison per world, so the C# kernel is
  untouched.
- **The live Workshop** (`LiveAssessment.CONCLUSIONS` and `conclusion_issues`) accepts it,
  and refuses it, in Michael's approved wording (Nov 19, Herald's draft):
  - with no public curse: "No curse has fallen on the town, so no one has been turned.";
  - for someone the curse couldn't have turned: "Only those who voted to hang the
    Revenant, and lived, could have been turned.".
- **The menu** (Michael, Nov 19):
  - "was turned by the curse" is offered in the premise type menu only once a curse has
    been announced, or on a premise that already holds it;
  - its tip is "Argue the curse turned them: good before it, evil while it held, good
    again once it lifted.";
  - the refusal stays for saved cases;
  - the older off-screen picker keeps the full list, since it selects by index;
  - `CanvasModel.PREMISE_TEXT` carries the same text.
- **It never shows who was turned.** It's a hypothesis weighed over the worlds, like any
  premise.
- **Docs:** DESIGN's premise list, and the BACKLOG item marked built. A second BACKLOG
  note re-measures "Recovering from a wrong 'lying' call" under #296's Mistaken.
- **Tests:** new `tools/test_turned_premise.gd` (11 checks, fast list):
  - the mask and the solver agree in every world;
  - turned means good before, evil during and good after;
  - "evil during the curse" also holds where X was evil all along, and "turned" doesn't;
  - exactly one eligible soul is turned per world;
  - a real prior with no evidence (0.5 between the two eligible voters);
  - the three refusals and the accepted case.

## What I measured

- **Golden:** identical to `baseline_e287b3d` at `--tol 0`, all five seeds. Nothing in an
  autoplay game files this premise.
- **Suites:** 12 of the 13 nearest suites pass: `test_turned_premise`, `test_roles_evil`,
  `test_workshop_live`, `test_workshop_live_canvas`, `test_premise_step2`,
  `test_premise_step3`, `test_mechanics_conclusions`, `test_workshop_integration`,
  `test_execution_aftermath`, `test_sighter_contest`, `test_workshop_checkpoint` and
  `test_shared_model`.
- **The 13th, `test_workshop_live_cognition`,** fails its same four checks on main as it
  stands. It's among the failures Bailiff is holding main for, and isn't this change.
- **Not measured:** how far a real case moves "X was turned". The suite pins the mechanics
  only.

## Small calls made on Michael's behalf

- **The track record:** "turned" isn't recorded as a good or an evil claim. It says both, at
  different times.
- **After the curse lifts,** the option stays offered: who was turned is still worth
  arguing then, and the judge reads the curse's whole time.

## Proposed for the backlog

None.
