# Quill: a reading of the hanged person's role refutes "was the Demon when hanged"

Claude-Quill, Nov 19. Base: main. Status: PR open. Next actor: Lantern (review: premise
code in `solver.gd`), then Bailiff.

## What changed

Michael approved this: on a Scion script, a Gravedigger reading of the hanging (or an
Executor reading of its target) that names a non-Demon role refutes "was the Demon when
hanged".

**The problem.** A judge's world can't tell "X was the Demon and the Scion rose" from "X was a
Minion hanged while the Demon lived". Both are X evil and not the Demon, with the Demon alive
at the hanging. So the premise held in both, and the reading fit both.

**The fix.** Lantern chose option (a), a per-world rule.
- `Solver.hanged_refuters(view, cards, target)` collects the case's judged readings that name
  X's role as a non-Demon (`C.is_demon`, plus the script's Demon list).
- `Solver.hanged_context` carries them, and `hanged_demon_in` returns 0 in any world where X
  isn't the world's Demon and a refuting reading's teller is good. For a relayed reading, both
  the reader and the Medium must be good.
- Quoted, duty-only and testimony-only cards don't count, and nor does X's own reading. With
  no Scion on the script, nothing changes.
- `CaseEval._premise_mask` takes the judged cards, and its cache key carries the refuters.
  Other callers (`Solver.holds`, the support model) are unchanged.

**A known understatement, in the docstring.** A good teller's reading is taken as healthy, as
in every premise test. In those worlds the premise loses the share a poisoned or Delusional
reading would leave it: the reader's broken chance, about 0.1 to 0.3 on such a script.

## Measured

`test_demon_when_hanged` gains 10 checks (30/30). On a live 10-NPC deal, with a Gravedigger's
"X was the Poisoner" in the case, "X was the Demon when hanged" holds in 2,184 of 15,120 worlds
instead of 4,536. It never drops below the 1,512 where X is the world's Demon.

These suites pass:
- `test_turned_premise`
- `test_execution_aftermath`
- `test_connections_core`
- `test_connections_cache`
- `test_juror_listener`
- `test_gravedigger_bluff`
- `test_workshop_regressions`

Golden is identical to `baseline_ee15238`.

## Review fixes (Lantern, Codex)

- **Every judge reads it alike (Lantern).** The refuters ride on the conclusion
  (`Solver.with_hanged_refuters`, as `[teller, relayer, reading time, relay time]`). They're
  attached at each module's entry: CaseEval's evaluate and compile, Jury's evaluate and
  refresh, Reasoner's prepare, search and direct_checks, SupportModel's assess and explain,
  CaseWhy's run and evidence, and Solver.analyze. So `Solver.holds` and CaseEval's mask agree,
  and every cache keyed on the conclusion keys on them. The support model's per-person
  comparison uses them for the conclusion's target.
- **A turned reader (Codex).** A teller's alignment is read at the reading's time
  (`TimeModel.evil_at`), so a reader the Revenant's curse has turned refutes nothing from its
  turning on.

`test_demon_when_hanged` is now 32/32. It adds a check that the mask and `Solver.holds` agree
on every live world, and a check for the turned reader.

## Proposed for the backlog

None. Michael dropped the "hanged role as a world variable" idea: it would hardly ever decide
a game.
