# 2026-11-17, Claude-Lantern: a "taken together" reason's weight follows what its card moved (`claude/count-reading-reasons`)

- **Base:** main `cee8811`. **Status:** PR open. **Golden moves** (what NPCs cite and say);
  it re-baselines when its turn in the golden queue comes (after #194, #199, #201 and
  Beadle's 89077 routing PR, per Bailiff). **Next actor:** Bailiff, in queue order.
- **The finding** (Coroner, playtest 89077 note 3; Seneschal relayed, with Herald's addition):
  Constance's three Lamplighter counts were each cited against Kiran as a strong reason
  (weight 0.23, strength 0.72), yet together they moved her good self's suspicion of Kiran
  only from 0.36 to 0.31, and any one by under 0.005.
- **Cause:** the leave-one-out behind "taken together" reasons
  (`ReasonAttribution._augment_joint_leave_one_out`) took its "with" side from the belief's
  own shift (`effects[pid].evil_change`, from the connections model) and its "without" side
  from the attribution's own whole-case model. Every card tested was credited with whatever
  the two models disagreed by. At seq 779 the attribution's model gives Kiran a 0.06 shift
  with or without any count; connections gives 0.44; each count got the 0.38 difference.
  (Coroner's guess, the role re-check, was close: the re-check isn't the cause; the full
  and subset fits agree exactly there.)
- **Fix:** each removal is measured within the attribution's model: against its own
  posterior with every card (`_loo_post` with `LOO_FULL`), re-checked the same way when the
  removal needs a role re-check (`LOO_NONE`). Beliefs don't change; only what's cited.
  `ReasonAttribution.same_model_loo` (on) turns it off for comparing on a replay.
- **At Coroner's moment** (89077 replayed to seq 779 with the switch off, then on):
  before, three identical count reasons against Kiran (0.23) and against Nisha (0.41);
  after, no count is cited: against Kiran only the general "the reports considered together
  point toward them" (strength 0.37), against Nisha only Edda's sighting. A count that
  squares with the owned outings now cites nothing (Herald's point).
- **How widespread:** `tools/test_joint_reasons.gd` (new, in `ci_fast_suites`, about 9 s)
  plays 7-NPC games on 89077's script with connections on and checks each "taken together"
  reason against what removing its card really does. With the old measurement 6 of the first
  11 such reasons fail; with the fix none do.
- **Checked:** `ci_fast_suites` plus the reason, Why and nomination suites, 72/72 (on
  `59a387c`); `test_joint_reasons` again on `cee8811`. Golden twice, identical to each other;
  every seed diverges where a cited reason changes (42 day 3, the rest day 2).
- **Not here:** merging same-gift reasons into one ("my counts on three nights"; Beadle's
  routing) and the fallback wording (Herald's draft, Michael's call).
