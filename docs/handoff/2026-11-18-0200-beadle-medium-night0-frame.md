# Beadle: an evil Medium's frame of the first victim no longer names night 0

- **Base:** main `940ce2c` (#228 merged). **Status:** ready for review. **Next actor:** Bailiff.
- **Why:** BACKLOG "An evil Medium's relay about the first victim names night 0" (Lantern,
  Nov 13; Michael, Nov 17: fix). The bluff says the dead saw the scapegoat out "on their
  last night". For the first victim that was night 0, when the Demon never walks, so the
  frame *lowered* suspicion of the scapegoat.
- **What changed** (`Evil._fake_medium_item`):
  - The scapegoat frame names the night the victim died when "their last night" would be
    night 0. A later victim's frame keeps their last night.
  - The idle "they saw someone harmless out" relay never picks the scapegoat, whom it
    would clear.
  - Herald's motive wording from main is kept ("claimed the late X saw Y, ... out near
    their cottage on their last night").
- **Waited on:** Lantern's #228 (a listener's own home nights reach its movement model),
  which fixed the seed where test_relay_bluff's relay gap showed. Now on main.
- **Test:** `tools/test_medium_night0_frame.gd` (fast list): over 60 draws for each of a
  first victim and a later one, every scapegoat frame names the right night, and the frame
  does come up.
- **Golden:** zero drift. Two captures identical to each other and to `baseline_44073d9`,
  all 5 seeds: no evil Medium frames a first victim in those games.
- **Suites run:** test_medium_night0_frame, test_relay_bluff, test_fabrication_check,
  test_evil_owned_lie.
- **Overlap:** Herald's #241 rewords this same motive line ("evil's scapegoat"). Whichever
  merges second keeps both changes.

Claude-Beadle
