# The Demon never detours, in inference either

- **Agent:** Claude-Beadle
- **Base:** main at `74e6e74` (with #361), `baseline_ee15238`
- **Branch:** `claude/beadle-demon-detour`
- **Status:** PR open. It moves golden and re-baselines to `baseline_0d796b3` (main with #346). It is
  golden-moving, so it queues behind #327; whichever merges second re-baselines.
- **Next actor:** Bailiff (review and merge).
- **BACKLOG item:** "Demon detours exist in inference but not in actual movement" (77388).
  Michael (Nov 17): the Demon never detours, so remove the detour from inference. A built note
  is added.

## What changed

- **The movement model's Demon** (`LiveActivity.demon_routes`, and `BuildProfilePaths` in
  `workshop/cs/LiveActivity.cs`) walks only the direct way from its home to the victim's.
  - **Before:** a 5% allowance went to a detour through each other block.
  - **Now:** the model matches the live Demon (`World._night_movement`), which always walks
    the direct way. A Hexer still doesn't walk.
- **`Tuning.Workshop.DEMON_DETOUR` is removed,** along with the `demonDetour` parameter all
  the way through `LiveActivity.cs` and `SolverBridge.cs`. The catalogue is regenerated.
- **What it means in play:** an honest sighting of someone off the route to that night's
  victim now rules them out as the killer in the judge's view. Before, it argued strongly
  against them.
  - A sighting is still a claim. The sighter can be lying or mistaken, so as evidence it
    still argues strongly rather than settling it.
  - The Veteran's attack report now fits only a Demon whose direct way passes the reported
    block.
- **The "Seen elsewhere" note** (`LiveActivity.relationships`) drops its last clause:
  - **Before:** "…argues strongly against being that night's killer; a Demon detour remains
    possible."
  - **Now:** "…argues strongly against being that night's killer."
  - Herald agreed this is a correction, not new wording. The NPC line
    `present_seen_elsewhere` never mentioned a detour, so it's unchanged.
- **Docs:** DESIGN.md (how night sightings count) and TUNING_NARRATIVE.md.

## Measured

**Suites:**
- Updated:
  - `test_mechanics_sightings`: the Demon has one route, and an honest off-route sighting
    rules out that night's killer.
  - `test_roles_shelter`: the Veteran's approach no longer admits a Demon home through the
    detour.
- Also pass: test_night0_fake_sightings, test_roles_night_sight, test_self_sighting,
  test_sighter_contest, test_sighting_followup, test_trace_solver, test_vigil_nightwatch,
  test_workshop_live_activity, test_workshop_profile_traces, test_workshop_two_traces and
  test_own_night_knowledge.

**Fixed replays:** 40 passive 10-NPC games, seeds 4000-4039, main (`e989a65`) against this
branch (before main's later merges).
- **Where games diverge:** every game. 36 of 40 diverge first at the day-1 evening belief
  refresh, the others on night 1 or the morning of day 2. The early divergence is small changes
  in belief values; who is hanged changes later, if at all.
- **Outcomes:**

  | | Main | Here |
  |---|---|---|
  | Winners | 22 good, 18 evil | 25 good, 15 evil |
  | Evil hanged | 56 | 59 |
  | Good hanged | 34 | 29 |
  | Nominations | 386 | 371 |
  | Good NPCs' yes votes | 674 of 1,566 (43%) | 664 of 1,540 (43%) |

  - **Same hangings:** 27 of the 40 games hang the same people on the same days.
  - **Different winner:** 5 games. Four turn to good (4010, 4011, 4025, 4026), one to evil
    (4018).
  - **How to read it:** an off-route sighting now clears that night's killer slightly more in
    NPC beliefs, so slightly fewer innocents are hanged. At 40 games, the differences are
    within what the seeds vary by.
- **Not measured:** RNG and timing. The run used `--no-trace`, and I didn't time judgements.
  The Demon's kill-night paths per destination drop from three (four when home is the
  destination) to one, so if anything it's faster. Argon would measure.

**Golden:** see `docs/golden_baseline.md`.
- Every seed diverges from the first day's refreshes. Seed 42 differs only at rounding level.
- Two outcomes change:
  - 54875: Greta is hanged on day 2, instead of Edda on day 2 and Hollis on day 3.
  - 900: Isolde is hanged on day 3 instead of Lian.
- No winner by day 4 in either, as before.
- Two captures were identical.

## Proposed for the backlog

None.
