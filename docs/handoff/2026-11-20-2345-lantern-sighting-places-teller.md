## Nov 20 — Claude-Lantern: a sighting places its teller

- **Base:** main after #454 (merged in). **Status:** PR ready. **Next:** Bailiff. **Moves golden:**
  re-baselined in this PR (`baseline_b810754`, after #454; earlier `baseline_6f80578` after #412 and `baseline_7af7d2a` on #455).
- **Codex follow-up (Nov 21):** a teller converted when they told the sighting is unconstrained
  in its base world too (`FlagTellerToldCursed`, `_teller_place_converted`). Zero drift.
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
- **40 passive games** (seeds 1–40, 10 NPCs, the rule off against on, on the same code). Good
  hangings don't jump:

  | | Rule off | Rule on |
  |---|---|---|
  | Good townsfolk hanged | 43 | 42 |
  | Evil hanged | 59 | 60 |
  | Good night-walkers (by gift) hanged | 11 | 10 |
  | Good wins / evil wins | 18 / 22 | 18 / 22 |

  Six games swap winner, three each way.

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
- **`test_relayed_alibi` is now built on a controlled deal** (Seneschal, Nov 21). With the rule on,
  play changes and the search landed on new deals:
  - seed 100047, where the sighter was already half-suspected and took the blame;
  - seed 100048, a relay about the victim's own kill night, where the relayer fell with the sighter
    contests off too. That fall comes from kill-night reasoning (logged as a model case to look at
    after this PR).
  - With those left out, the search found no deal in 120 seeds.
  - Now an evil Medium relays that a good victim was home on night 0, a night before their kill.
    They were out on the sighter's block, and a good sighter at home saw them from the window.
  - The assertion is unchanged: the relayer's suspicion must rise (deal 692: 0.41 → 0.50).
- **The relay yardstick** (`test_relay_bluff_games`). A relay recast as its relayer's own word
  (`Seeds.relay_effect`) no longer places the relayer, since a relay never says where its relayer
  was. The recast cards carry `places_teller: false`, which the rule respects. No card in play
  carries it.
- **Passed:** `test_self_sighting`, `test_own_night_knowledge`, `test_connections_pairings`,
  `test_points_elsewhere`, `test_vigil_nightwatch`, `test_warden_quiet_route`,
  `test_lamplighter_count_mix`, `test_nightwatch_whole_list`, `test_mechanics_sightings`,
  `test_workshop_regressions` and `test_sighter_contest`.

### Follow-ups
- **Beadle** (evil-team play): an evil street sighting is told only once its teller has claimed a
  night-walking gift that explains it.
- **BACKLOG "Being lied about can pull in evidence that clears the liar"** stays open. Re-run seed
  100002 after this lands.
