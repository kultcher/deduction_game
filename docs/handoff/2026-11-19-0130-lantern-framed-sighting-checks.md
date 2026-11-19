# 2026-11-19, Claude-Lantern: framed-sighting checks read the fake sighting's own effect (`claude/framed-sighting-checks`; tests only)

- **Base:** main `44a9962` (#290). **Status:** PR open. **Next:** Bailiff. Then Beadle merges
  main into #292.
- **Why:** test_connections_pairings' #139 and #135 checks failed on Beadle's #292. They
  measured where a night or a person ends up, not what the planted sighting does, and #292's
  small trust changes moved the fixture to seeds where those differ:
  - **Seed 100037.** The subject's own true sighting of the Demon at the night's kill pulled the
    whole night off the sighter. The bystander already all but cleared the sighter, at 0.008.
  - **Seed 100022.** The subject already held the Demon sighter at 0.97. Near that ceiling, the
    town's fixed evil count lets the card lift the subject's other evil suspect instead.
- **What changed:**
  - **`Seeds.cards_effect(g, listener, ids, drop)`:** a listener's chances with some held cards
    and with them left out, from one refresh's own inputs. It clears every cache first, because
    one cache below the model isn't keyed on `LiveActivity.sighter_contests_enabled`, so
    flipping that switch between calls didn't take otherwise. `relay_effect` is now built on it.
  - **The four checks** each compare the fake sighting's own lift:
    - for the subject, positive;
    - for the subject, larger with the sighter contest than without;
    - for the bystander on the sighter, larger with the contest;
    - for the bystander on the subject, smaller with the contest.
  - **The fixture:** `Seeds.framed_sighting` takes `bystander_doubt` (the bystander holds the
    sighter at least that suspect; the test uses 0.1) and a starting seed. The test walks on
    past seeds whose subject already holds the sighter at 0.9 or more without the card, and
    notes each one it skips.
- **Not a model change.** Golden can't move; this touches only `tools/`.
- **Found, not fixed:** the cache that ignores `sighter_contests_enabled` (a developer switch;
  play never flips it). Noted here only.
- **Measured:**
  - test_connections_pairings is 59/59 on main (seed 100012).
  - On #292 with main merged it's also 59/59. Seed 100022 is skipped as a ceiling case, and the
    checks run on 100038.
  - The other suites that use the fixture helpers are in the PR body.
- **Proposed for the backlog:** none.
