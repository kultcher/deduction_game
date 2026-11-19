# "Is the Demon" about a hanged person means "was the Demon when hanged"

- **Agent:** Claude-Quill
- **Base:** origin/main at 2823c17
- **Status:** PR open; zero drift.
- **Next actor:** Bailiff to review and merge. Herald for the optional wording.
- **Item:** BACKLOG "The Demon before/after premise for the Scion transfer" (triage 1.6,
  [decided: direction]), in the form Michael chose on Nov 19, via Seneschal: no new
  option; the existing premise changes meaning for a hanged person.

## What I found

A world's Demon is the Demon now. Where the hanged X was evil and its world's Demon was alive
at the hanging, the judge reads it as the Scion's succession: LiveActivity's
`SuccessionApplies`, and the role constraints' Scion mask for a Gravedigger or Executor's "X
was the Demon". The premise didn't: "X is the Demon" held only where X is the world's Demon.
For a hanged X, that's "X was the Demon and nobody rose", which a later kill makes
impossible. A plain "Y is the Demon" about the risen Scion already worked.

## What changed

- **`Solver.hanged_demon` and `hanged_context`, and `Solver.holds`:** "is the Demon" about
  someone hanged holds where X is the world's Demon, or where X was evil and the world's
  Demon was alive at a hanging with five or more alive and a Scion possible on the script.
  It reuses `RoleConstraints._scion_exec_alive_demon_mask`, the same rule the readings use.
  "Is not the Demon" is its complement. Anyone not hanged keeps the plain question.
- **`CaseEval._build_premise_mask`:** the same, built in GDScript, one byte per world, with the
  hanging's context computed once. `position_holds` and the C# kernel are untouched.
- **Docs:** DESIGN's premise list, and the BACKLOG item marked built.
- **Tests:** new `tools/test_demon_when_hanged.gd` (10 checks, fast list):
  - a hanged Demon, a hanged Demon whose Scion rose, and a hanged good person;
  - someone not hanged keeps the plain question;
  - with no Scion on the script, or four alive at the hanging, there's no succession;
  - "is not the Demon" is the complement;
  - on a real 10-NPC live universe (15,120 worlds), the judge's mask agrees with the
    solver in every world, and holds in 4,536 against 1,512 for the plain question.

## What I measured

- **Golden:** identical to main's baseline at `--tol 0`, all five seeds. No golden game files
  "is the Demon" about someone hanged.
- **Suites:** these 13 pass: `test_demon_when_hanged`, `test_demon_declaration`,
  `test_demon_types`, `test_mechanics_conclusions`, `test_roles_evil`, `test_premise_step2`,
  `test_premise_step3`, `test_workshop_live`, `test_shared_model`, `test_roles_dead`,
  `test_execution_aftermath`, `test_workshop_integration` and `test_connections_cases`.

## Small calls made on Michael's behalf

- **The Scion's own conditions:** the succession ignores whether the Sexton's bell or poison
  stopped the Scion, as the movement model and the readings already do.

## Proposed for the backlog

None.
