## Nov 20 — Claude-Lantern: a sighting places its teller

- **Base:** main after #444 (merged in). **Status:** PR open as a draft (one check flagged, below).
  **Next:** Seneschal (the flagged check), then Bailiff. **Moves golden:** re-baselined in this PR
  (`baseline_e8ff7e0`).
- **What this is:** BACKLOG section 6, "A sighting places its teller", `[decided]` (Michael, Nov 20,
  from seed 100002 on #454).

### What changed
- In a world where its teller is good, a street sighting puts the teller out on that block that
  night (their destination; anywhere on a Lamplighter's tour). One from their window (their own
  block) puts them at home or out on their own block, as the sim's honest sightings are made.
- A path that doesn't fit has likelihood 1 minus the card's hearing weight.
- In a world where the teller is evil (or converted that night), it says nothing of where they were.
- Left out: relays, quotations, admitted outings, guard and watch claims, vigil lists, testimony
  alone, and the listener's own home-night knowledge.
- Code: `FlagTellerAt` / `FlagTellerAtHome` in `LiveActivity.cs` (`Observed`), set in
  `live_activity_pack.gd` and mirrored in `live_activity_profiles.gd`. `LiveActivity.teller_place`
  is the measurement switch.

### Measured
- **Seed 100002 (on #454's branch, the same deal played with the rule off).** Edda's chance that
  Hollis, the Demon, is evil:
  - with his fake street sighting of her on the Market: 71% → **83%**;
  - without it: 78%, unchanged;
  - with it, but without Jory's watch: 45% → **63%**.
- **40 passive games** (seeds 1–40, 10 NPCs): pending; see the PR.

### Golden
Every seed moves.
- 54875 now hangs two good townsfolk (Odette, a Veteran, and Isolde, a Lamplighter) instead of
  Greta (the Poisoner).
- 692 now also hangs Lian (the Revenant).
- 98933 no longer hangs Lian (a good Psychologist).
- See `docs/golden_baseline.md`.

### Tests
- **`test_sighter_contest`** isolates the contest (rule held off) and checks the rule on its own:
  - a street sighting by a sighter with no reason to walk moves the clash onto the sighter (×14);
  - a window sighting barely moves it (×1.2).
- **`test_warden_quiet_route` and `test_relayed_alibi`** now use window sightings by a witness at
  home, as honest non-walkers make them.
- **Flagged:** `test_relayed_alibi`, "it counts against the relayer instead", fails on the deal the
  search now finds (seed 100048).
  - The relayer falls 0.74 → 0.65 with the rule, and 0.74 → 0.49 without it, so the rule doesn't
    cause it.
  - Two fixture attempts made; stopped and asked Seneschal.
- **Passed:** `test_self_sighting`, `test_own_night_knowledge`, `test_connections_pairings`,
  `test_points_elsewhere`, `test_vigil_nightwatch`, `test_warden_quiet_route`,
  `test_lamplighter_count_mix`, `test_nightwatch_whole_list`, `test_mechanics_sightings`,
  `test_workshop_regressions` and `test_sighter_contest`.

### Follow-ups
- **Beadle** (evil-team play): an evil street sighting is told only once its teller has claimed a
  night-walking gift that explains it.
- **BACKLOG "Being lied about can pull in evidence that clears the liar"** stays open. Re-run seed
  100002 after this lands.
