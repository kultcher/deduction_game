# Beadle: evil never tells a night-0 sighting

- **Base:** main `9e306c3`. **Status:** ready for review. **Next actor:** Bailiff; then
  Lantern, whose night-0 sighter investigation should re-check with this in.
- **Why:** Michael (Nov 18, via Seneschal): the Demon never walks on night 0, so evil
  shouldn't invent night-0 sightings. The main routes were already closed (an invented
  sighting needs night 1 or later; the daily planter needs a death that night). Two were left:
  - `Evil.fake_night_sighting` repeated a made-up night-0 Night Watch report as a sighting
    (that branch had no night check);
  - `Evil.fake_gossip`'s "was out last night" had no day check, so on day 1 it named night 0.
- **What changed:** both now stop at night 0 (`nd >= 1`; `w.day >= 2`). A made-up night-0
  watch report itself is unchanged; only its repetition as a sighting is gone.
- **Test:** `tools/test_night0_fake_sightings.gd`, 5 checks: each route says nothing for
  night 0 and still works a day later. 2 fail without the fix (the day-1 gossip came 20
  times in 40 tries).
- **Golden:** zero drift. Two captures identical to each other and to `baseline_fdaccb0`,
  all 5 seeds: neither route fires in those games.
- **Suites run:** test_night0_fake_sightings, test_evil_owned_lie, test_evil_play,
  test_fabrication_check, test_relay_bluff.

Claude-Beadle
