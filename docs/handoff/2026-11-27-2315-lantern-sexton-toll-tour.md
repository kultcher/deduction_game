# 2026-11-27, Claude-Lantern: a claimed Sexton walks every block on its toll night (`claude/sexton-toll-tour`)

- **Base:** main `a88b83ba`. **Status:** PR open. **Next actor:** Bailiff.
- **Golden:** identical to `baseline_1bf8a4b` on all five seeds at `--tol 0` (two captures). No
  golden seed has a Sexton toll told, so nothing to re-baseline.

## What changed and why

Michael, Nov 21 (`docs/design/reading_interpretation.md`, "Walking every block"): the Lamplighter
walks every block every night, and the Sexton does on the night it tolls, so a sighting of either
on any block on such a night can't be wrong because of where it was. The listener's own route
already had this (`WorkshopBridge.own_home`). For other people, the movement model gave a walk of
every block only to a claimed Lamplighter.

- **How a listener knows the toll night:** the toll isn't public. The Sexton keeps it to
  itself and tells it later (`sim/roles/sexton.gd`: "I tolled the church bell", a reading whose
  `data.night` is the toll night). The movement model reads that report from the person
  themself (unquoted), so it applies to whoever claims the toll, true or bluffed.
- **The rule:** on that night, a good Sexton's walk (the gift, secret and ordinary profiles) is
  a tour of every block, for certain. Its evil profiles (Minion, Demon) walk as before, so a
  lying Sexton is still judged by where it was seen.
- **Files:**
  - `workshop/live_activity_pack.gd`: the Sexton gets its own move-role code (8), with the toll
    night packed in slot 17.
  - `workshop/cs/LiveActivity.cs`: `MoveRoleSexton`, `SextonTolled`. `BuildProfilePaths`
    returns the tour on the toll night for good profiles, and the exact path enumeration offers
    the tour as a candidate that night.
  - `workshop/live_activity_profiles.gd`: the GDScript mirror (`sexton_tolled`, `_paths`,
    `_profile_paths`).
- No new constant. The Lamplighter is unchanged.

## What I measured

`tools/test_sexton_toll_tour.gd` (new, on the fast list): a hand-built 7-person town. Sexton `s`
claims the toll on night 2, and `t` says it saw `s` on the Docks.

| Case | P(s evil), main | P(s evil), this branch |
|---|---|---|
| The toll claim alone | 0.315 | 0.315 |
| Seen on the Docks on the toll night | 0.335 (counts against it) | **0.155** (bears the toll out) |
| Seen on the Docks on night 1 (no toll) | 0.335 | 0.335 |

C# and GDScript agree on the Sexton's walk likelihood (good and Minion).

**Suites:** test_sexton_toll_tour, test_own_route_knowledge, test_night_sighting_rebuttal,
test_connections_core, test_connections, test_workshop_regressions and
test_burden_unrequited_walk pass. So does the whole fast list, 238 of 238 in two shards.

## Proposed for the backlog

None.

## Codex round 1

- **The movement caches** now key on the Sexton's toll report (`movement_inputs`), so a sighting judged with and without a toll no longer shares a cached answer.
- **A Sexton's duty account** ("I tolled the church bell and walked every parish", a `duty_claim` sighting from `sim/roles/sexton.gd`) is adapted into a `duty_only` Sexton report naming its night, as the Medium and Lamplighter duty accounts are. So the walk of every block applies from it too.
- **test_sexton_toll_tour** has 8 checks now: the order of evaluation without clearing caches, and the duty account. Without the cache fix, the order check fails.
- **Suites:** these pass: test_night_sighting_rebuttal, test_evil_play, test_meeting_m2b, test_workshop_regressions and test_connections_core.
- **Golden:** identical to `baseline_1bf8a4b` on all five seeds at `--tol 0`.

## Codex round 2

- **No inferred Lamplighter from a toll walk.** `EvaluateRoutes` no longer puts a Sexton on `forcedLamp` because its toll walk is the only path that fits two far sightings. The inferred Lamplighter claim had clashed with its Sexton claim.
- **The toll comes before an Unrequited visit,** in both kernels' holder column, as in `world_night.gd`. A good Unrequited Sexton doesn't visit on its toll night, and a visit that was due stays due.
- **test_sexton_toll_tour:** 11 checks now. Without the fixes, both new ones fail.
- **Main merged** (baseline `c0cb269`). Golden is identical on all five seeds at `--tol 0`.
- **Suites:** these pass: test_burden_unrequited_walk, test_night_sighting_rebuttal, test_workshop_regressions, test_connections_core, test_connections_cache, test_connections_pairings and test_lamplighter_count_mix.
