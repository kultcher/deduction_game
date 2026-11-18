# 2026-11-18, Claude-Lantern: test_relay_bluff's genuine-Medium check is built by hand (`claude/relay-bluff-honest`; tests only, zero drift)

- **Base:** main `c4f5dc6`. **Status:** PR open. **Next:** Bailiff. Merge this ahead of #269.
- **Why:** on main plus #269 the genuine-Medium check failed on seed 100008. Kiran, a good Medium,
  was poisoned that night, and his broken gift invented a relay: a first-night sighting that
  never happened. Listeners held that false relay against him (0.10 → 0.23). That's the town
  reasoning well, not the bug. Beadle traced the same.
- **The search was the weak part (Seneschal: make it robust, not re-seeded):**
  - The check found its three games by searching seeds for any good Medium. Behaviour changes
    move which games it lands on, and it has tripped three times today.
  - Skipping the poisoned Medium left only one game in the first 60 seeds.
  - Widening the search turned up two more fair reasons to suspect an honest Medium. On 100371,
    a frame: Agnes, the Poisoner posing as a Night Watch, "saw" Hollis on the hill the night he
    communed at the market (0.47 → 0.93). On 100079 under #269, Bart communed on the hill the
    night Dorian was killed there (0.28 → 0.46). Neither is a fault in how relays are weighed.
- **What:**
  - The check now builds six towns by hand, on the 7-NPC deals of seeds 692, 900 and 42 with no
    play.
  - In each, the Demon kills a good neighbour on the first night (a Medium communes only with
    the Demon's victims; Codex on #272). On the second night a good Medium relays what the
    neighbour saw the night before the town arrived: a good person out, or an evil one. If the deal already has a Medium, that's
    the one used; otherwise a good person is made one, with the Medium added to the script.
  - A living good listener hears the relay. The check fails if the relay raises the Medium's
    chance of being evil by 10 points or more in any town.
  - The two evil-relayer checks and the invented-relay check still search seeds. They measure
    the relays' own effect (#271), so they're steadier, but they could be built the same way
    later.
- **Measured:**
  - **On main:** with the Demon-victim fixture, the relay costs the Medium 3 to 8 points in the
    six towns (692: 0.46 → 0.54 and 0.53; 900: 0.48 → 0.51 and 0.53; 42: 0.35 → 0.43). The
    earlier hanged-neighbour version, which a Medium couldn't produce, cost 3 to 5.
  - **The larger cost:** the relay puts the Medium at the house where the Demon killed the
    night before. The 8 points on 692 and 42 sit near the check's 10-point line. They don't
    drift with play, but a belief-model change that weighs that placing more would trip it,
    which is the intent.
  - **On main plus #269:** the earlier version gave identical numbers, since the towns don't
    depend on play. The Demon-victim version isn't re-run there.
  - **Pre-#265 `832bd17`:** both evil-relayer checks fail, as before. The genuine check passes
    there too: #265's bug cleared evil relayers and never touched genuine ones.
- **Tests:** `test_relay_bluff` 4 of 4 on main and on main plus #269. Only that file changes, so
  golden is untouched.
