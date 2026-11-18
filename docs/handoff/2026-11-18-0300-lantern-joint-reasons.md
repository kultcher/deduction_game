# 2026-11-18, Claude-Lantern: a "taken together" reason is measured in the belief model (`claude/joint-reasons-in-belief-model`; moves golden, reasons)

- **Base:** main `940ce2c`, with main `80f7605` merged in. **Status:** PR open, re-baselined
  (`baseline_58dac68`). **Next:** Bailiff (review, merge first in the golden queue, per Bailiff).
- **Why:** main went red after #204 on `test_meeting_flow`. Hollis's own Gravedigger reading
  drives Odette from 50% to 81% in the connections model, through the core, but reason
  attribution's leave-one-out ran in the judge's own model, which saw almost nothing. So the
  reason NPCs gave didn't match what had moved them.
- **What:**
  - `Jury` keeps the connections refresh's inputs and result (`cx_args`, a 10th element of
    `reason_inputs`). `WorkshopOwnership` passes them to `ReasonAttribution.attribute_refresh`.
  - `ReasonAttribution._connections_drop` re-runs that same refresh without the card, once per
    card, memoised across suspects. A joint reason's share is the listener's shift with every
    held card less the shift without it.
  - Without those inputs (the earlier model, tools), the old same-model leave-one-out runs as
    before.
- **Small call made on Michael's behalf:** `test_meeting_flow` is added to the fast list, at
  Bailiff's request, so the case that went red is checked on every PR.
- **Golden:** moves on all five seeds. NPCs now give the reasons the belief model gives, which
  changes some of what they say, and so some of what others hear:
  - 42 from record 77 (Fenwick's reason for Agnes, day 3); 54875 from 196 (Edda's reasons,
    day 2); 692 from 38 (Nisha's suspicion, float noise at 1e-17, day 1); 900 from 116 (a few
    listeners' beliefs by about 0.2 points, day 2); 98933 from 117 (Lian's reasons, day 2).
  - **Outcomes unchanged:** the same executions, nominators and winners on every seed.
  - **It is the reasons, not a side effect:** on seeds 900 and 692 the extra refreshes run with
    their results thrown away give a game identical to `baseline_44073d9` at `--tol 0`, with
    the connections cache on or off. The cache verify switch found no wrong kept answers.
- **Capture-time cost:** about 12% more time per refresh (seed 900 37 → 42 ms, 692 151 → 168 ms,
  98933 157 → 177 ms; two timings each, the same machine).
- **Tests:** the fast list (with `test_meeting_flow`) passed on the merge.
  `test_joint_reasons` (6 minds, 9 joint reasons) checks against the connections refresh when its
  inputs are there. It had found 0 minds because its filter excluded the new 10-element inputs,
  which is now fixed. `test_wording_89077` passes.
