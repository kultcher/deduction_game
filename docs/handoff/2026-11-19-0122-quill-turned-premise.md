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
  and refuses it:
  - with no public curse: "No curse has been announced, so no one was turned.";
  - for someone the curse couldn't have turned: "Only someone who voted to hang the
    Revenant, and survived, could have been turned.";
  - both lines are placeholders, for Herald.
- **The menu:** the live workshop lists "was turned by the curse" always. Its menu is built
  once and picked by index, so hiding it before a curse could shift the other entries.
  Herald can hide it with the index handling. `CanvasModel.PREMISE_TEXT` has the same
  text.
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
- **The menu:** listed always, refused before a curse, rather than shown only after one.

## Proposed for the backlog

None.
