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
  - In each, a good Medium relays, on the second night, what a neighbour hanged on day 1 saw on
    the first night: a good person out, or an evil one. If the deal already has a Medium, that's
    the one used; otherwise a good person is made one, with the Medium added to the script.
  - A living good listener hears the relay. The check fails if the relay raises the Medium's
    chance of being evil by 10 points or more in any town.
  - The two evil-relayer checks and the invented-relay check still search seeds. They measure
    the relays' own effect (#271), so they're steadier, but they could be built the same way
    later.
- **Measured:**
  - **On main:** the relay costs the Medium 3 to 5 points in all six towns (692: 0.37 → 0.41;
    900: 0.50 → 0.53 and 0.55; 42: 0.28 → 0.31).
  - **On main plus #269:** identical, as expected, since the towns don't depend on play.
  - **Pre-#265 `832bd17`:** both evil-relayer checks fail, as before. The genuine check passes
    there too: #265's bug cleared evil relayers and never touched genuine ones.
- **Tests:** `test_relay_bluff` 4 of 4 on main and on main plus #269. Only that file changes, so
  golden is untouched.
