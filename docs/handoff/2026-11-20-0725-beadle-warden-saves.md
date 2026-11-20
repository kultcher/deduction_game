# Evil Wardens fake saves; a real save is a reason to come out

- **Agent:** Claude-Beadle
- **Base:** main at `ad33789` (`baseline_7792e9a`)
- **Branch:** `claude/beadle-warden-saves`
- **Status:** draft PR. Zero drift: golden is identical to `baseline_7792e9a` on all five seeds.
  It's marked ready once the A/B is in.
- **Next actor:** Beadle (the A/B), then Bailiff.
- **BACKLOG item:** "Rapport and Warden-credit leftovers", parts (b) and (c) (Michael, Nov 20:
  agreed as assessed; close (d); hold (a) until anger reasons). From the overnight queue, the
  decision-free items.

## What changed

- **(b) An evil Warden bluff takes each quiet night as its save** (`Warden.told_saves`).
  - **Where:** at the door it says it guarded that night (`warden_door`, the same story it
    already tells).
  - **How much it believes it:** as a real Warden would believe it. A living Veteran claim
    halves the belief, and it drops below `WARDEN_SAVE_BELIEF_MIN`.
  - **What it says:** it tells of the save with the real Warden's `warden_saves_claim` line, and
    its card carries `save_claim`.
  - **Log:** it's logged as a lie with its reason. No new wording.
- **(c) A good Warden with a save it believes in has more reason to claim at the meeting**
  (`Warden.score_public_claim`: `save_to_tell`).

## Question for Michael

**New constant:** `Tuning.Roles.WARDEN.save_claim_bonus` = **0.3** (proposed).
- **What it does:** it offsets most of the Warden's hiding floor (−0.35) on the meeting claim
  roll. So a Warden that believes it turned the Demon away leans towards telling the town, but
  isn't made to.
- **Alternatives:** 0.15 for a nudge, or 0.5 to usually come out.

## Measured

- **New:** `tools/test_warden_saves.gd` (7 checks), on the fast list.
- **Also pass:** test_warden_challenge, test_warden_quiet_route, test_roles_registry,
  test_social_trust, test_evil_play, test_tuning_hoist, test_relay_bluff,
  test_too_clean_bluffs and test_dialogue_voices.
- **Golden:** identical to `baseline_7792e9a` at `--tol 0`.
- **A/B:** to follow, 40 passive games against main, counting evil Warden fake saves told, how
  the town treats a Warden claimant, and winners and hangings.

## Proposed for the backlog

None.
