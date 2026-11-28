# 2026-11-28, Claude-Lantern: withheld readings, the cost (`claude/withheld-cost`)

- **Base:** `claude/beadle-withheld-asks` (#588) at 6488a88e. This PR follows #588 and merges after it.
- **Status:** PR open.
- **Next actor:** Bailiff, once #588 has merged.
- **BACKLOG:** "Withheld readings: asking for what someone hasn't said" [decided]. The cost is approved as I re-proposed it (Michael, Nov 28, via Seneschal).

## What changed and why

- **`Connections.withheld`** (`workshop/connections.gd`) adds the cost to each refresh as one log-odds term per claimant, beside the items, the core and the stored cases.
  - The leave-one-out shortcut (`drop_card_posterior`) adds the same term.
  - `summary` lists it as `withheld`.
- **How it's sized:**
  - The factor is `WITHHELD_DEFER_FACTOR` 1.15 for a refusal with a reason, or `WITHHELD_DEFLECT_FACTOR` 1.6 for a bare one.
  - Its log grows by `WITHHELD_DAY_STEP` 1.25 for each day since the first refusal of that reading.
  - It's scaled by 2 × (1 − the listener's trust in the claimant).
  - There's one term per reading (claimant, gift and night), at the strongest kind seen.
  - Once the reading comes out it stops growing. A deferral's term is dropped; a deflection's stays.
  - It's alignment-blind: no measured good or evil rate enters it.
- **Who counts it:** `game/workshop_bridge.gd` `withheld_seen` gives a good listener the refusals in `w.withheld_refusals` it saw. Those are the ones whose `known_to` holds it, or "public".
  - `jury.gd` and `live_assessment.gd` carry the list through to the weigher. Without the second, the prepared listener lost it.
- **Constants:** three new ones in `sim/tuning.gd` (Workshop), approved. `tuning_catalogue.md` is regenerated.
- **Docs:** `docs/design/withheld_readings.md` §4 has an "As built" note.

## Measured

- **New:** `tools/test_withheld_cost.gd`, 17 checks, added to the fast list.
  - **From even odds:** a deferral takes the claimant to 0.535 and a deflection to 0.615, then 0.676 on its third day out and 0.759 on its fifth.
  - **No stacking:** five refusals of one reading count as one.
  - **Trust:** full trust cancels the cost; none doubles it.
  - **After sharing:** a deferral's cost is lifted, and a deflection's is frozen.
  - **Who counts it:** private and public visibility, and never the claimant itself.
  - **In play** (seed 1, day 2): a private deflection raises the asker's suspicion of the claimant from 0.100 to 0.179. An NPC that wasn't asked is unmoved.
- **Suites:** test_withheld_asks, test_connections_core, test_call_on_respond, test_workshop_regressions, test_workshop_action and test_connections_cache pass.
- **Golden:** identical to #588's baseline on all five seeds at `--tol 0`: first `baseline_446c9c2`, then `baseline_2e97efe` after #588's head b5274609 was merged in. Golden's one private ask (seed 42) ends without a refusal, so no golden refresh sees a cost.

## Not measured

How often refusals happen in bot games, and so how far the cost moves outcomes. #588 saw one ask and no press in 9 games. A sweep would show the cost only in games where the player uses "Call on".

## Proposed for the backlog

None.

## Codex round 1

- **Immediate refresh:** `MindWithheld.record_refusal` now refreshes whoever saw the refusal: the private asker, or every living good mind for one at the meeting. The cost lands at once.
- **A public refusal then shared in private:** a public refusal whose reading is later told to one listener in private gets `shared_to: {listener: tick}`. `withheld_seen` reads it as shared for that listener alone.
- **Night sightings and late relays:** #588's `note_shared` hooks in `MindMeeting` already close refusals over a night sighting or a dead reader's reading.
- **Files:** the first two edit Beadle's `sim/mind_withheld.gd`, as agreed with him afterwards.
- **test_withheld_cost:** 19 checks.
- **Suites:** test_withheld_asks, test_call_on_respond, test_call_on and test_silence_pressure pass.
- **Golden:** identical to `baseline_2e97efe` (main).
