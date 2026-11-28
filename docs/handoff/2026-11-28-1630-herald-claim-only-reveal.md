# A claim without its readings says so (Michael's Nov 28 item 3)

- **Agent:** Claude-Herald
- **Base:** main at baseline_2e97efe
- **Status:** PR open. Golden identical to `baseline_2e97efe` at `--tol 0` on all five seeds.
- **Next actor:** Bailiff (review, merge)

## What changed

- **Item 3 (Michael, Nov 28, via Seneschal):** when someone comes out with their gift at the meeting but not their readings, the claim used to hang there with no follow-up. This happens at a podium outing, or when a burden holds the readings back. Now, straight after a *new* public claim, if the gift has readings still unshared, the speaker gives their own "keeping my readings" line.
  - Michael's call: reuse each voice's existing `withhold_readings_privacy` line, with no new lines except where one doesn't fit. Thirteen fit as they are. Fenwick ("…my friend") and Edda ("…love") spoke to one listener, so he approved town forms for them:
    - Fenwick: "What my gift has revealed must wait for the proper scene, friends."
    - Edda: "What it's shown me can stay in my own cupboard for now, if it's all the same to you."
  - Every voice now has a `withhold_readings_public` key, as the voice suite requires every voice to share one key schema. Thirteen copy their privacy line; Fenwick and Edda have the forms above.
  - Code: `MindMeeting._say_readings_held` is called from `_go_public`. Nothing is said for:
    - a claimant who was already public;
    - a gift without readings;
    - someone with nothing left unshared;
    - last words: the gallows calls `_public_disclosure(..., say_held = false)`, since nobody holds back their readings on the way to the rope. This was caught by `test_meeting_flow`.
- NPC behaviour is unchanged: who claims, and what is shared, are the same. This only adds a line of dialogue.

## Measured

- New suite `tools/test_claim_only_reveal.gd` (7 checks, in the fast list):
  - a claim-only reveal gives the claim, then the speaker's own line;
  - last words don't;
  - a claimant already public doesn't repeat it;
  - sharing everything gives no such line;
  - Fenwick and Edda have their town forms.
- Suites passing: `test_claim_only_reveal`, `test_meeting_flow`, `test_dialogue_voices` (its key count goes 300 to 301), `test_presentation_contracts`, plus the meeting, claim, burden and withheld suites: `test_meeting_m2c`, `test_withheld_asks`, `test_withheld_cost`, `test_own_burden_knowledge` and others, 16 of 17 before the last-words fix.
- Golden: two captures, identical to each other and to `baseline_2e97efe`. No golden seed reaches a claim-only reveal.
