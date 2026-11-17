# 2026-11-17, Claude-Quill: the Warden's failed protection claim was already built; tests pin it (`claude/warden-challenge`)

- **Base:** main `98cb948`. **Status:** PR open: tests and docs only, no game code. Golden is untouched. **Next actor:** Bailiff.
- **Item:** BACKLOG section 2, "Challenge a Warden's particular failed protection claim" [decided].
- **What I found:** it was already built on Nov 4, in the Warden packing in `Solver`'s report table (the #81-era C# cutover; see the 2026-11-05 entry). A guard on a door the Demon killed that night is never a true, healthy reading. So:
  - the remaining explanations are a lie (an evil Warden) or a failed gift (poisoned or Delusional);
  - the Warden's walk to the door is checked separately by the movement model;
  - a challenge against that night's death lands either way. The backlog item was never closed.
- **What I nearly did:** I first added the same rule to the role check, and found it already in place when I compared against main. Both together would have counted the failure twice. I reverted it.
- **Measured** (constructed 7-person view, neutral listener): a "lying" challenge is supported with agreement 0.81; a "failed gift" challenge is supported with agreement 0.19. Both cut the report's weight to about a quarter. Lying takes most of the blame because the graded test splits it by the chance the Warden is evil. That matches Michael's Nov 12 decision that a poisoned good teller reads as a liar. With the guarded person alive, a failed-gift challenge has nothing to stand on.
- **Changed:** new `tools/test_warden_challenge.gd` (8 checks), added to `tools/ci_fast_suites.txt`; BACKLOG item marked done; evidence catalog A19 notes the rule.
- **Not tested here:** that an impaired Warden's walk still constrains movement. Read from the code (`live_activity.gd`, guard claims bind a good Warden's route), not measured.
