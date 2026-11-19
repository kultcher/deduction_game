# Private sharing grows each day past day 1

- **Agent:** Claude-Beadle
- **Base:** main with #321 (`baseline_2829999`)
- **Branch:** `claude/beadle-private-share`
- **Status:** PR open. **New constant pending Michael: Bailiff, please hold the merge until he
  approves it.** It moves golden and re-baselines to `baseline_1d9e025` (main with #321). It
  re-baselines again on its turn.
- **Next actor:** Michael (approve or change the size), then Bailiff.
- **BACKLOG item:** "A daily nudge to share a gift privately" (Michael, Nov 19). The built note
  is added.

## What changed

In private talk between NPCs (`Social._pick_item`), an NPC who hasn't claimed a gift publicly
brings up two things more often each day past day 1: its gift, and its own readings.
- **The rule:** their weight in the draw is multiplied by 1 + 0.15 x (day - 1). That is ×1.15
  on day 2, ×1.3 on day 3 and ×1.45 on day 4.
- **The constant:** `Tuning.Social.SHARE_UNCLAIMED_DAY_BOOST` = 0.15. It's new, and its value
  is proposed.
- **Unchanged:** what comes out once the gift comes up (nothing, a hint or the claim) is still
  decided by the existing openness roll, which already rises a little each day.
- **Why a new constant:** that roll's day term (`Dialogue.OPENNESS_DAY_SLOPE`) is shared with
  answers to the Demonologist, so raising it would also change what NPCs tell the player.

## Small calls made on Michael's behalf (by Seneschal, Nov 19)

- **NPC-to-NPC only.** What NPCs tell the Demonologist keeps its own tuning.
- **Evil gets the same.** An unclaimed evil NPC's bluffed gift and fake readings are boosted
  alike, so the difference can't become a tell.
- **Measure first, then build with a proposed value.** The PR is marked pending Michael.

## Measured

**Suites:**
- New: `tools/test_private_share_boost.gd` (7 checks), on the fast list:
  - day 1 has no boost, and day 3 has ×1.3 on both the gift topic and the reading;
  - idle talk is unchanged;
  - an NPC who has claimed publicly gets no boost;
  - evil's fake reading and bluffed gift get the same boost.
- Also pass: test_peer_role_gossip, test_social, test_npc_chatter, test_npc_openness,
  test_social_trust, test_meeting_gossip, test_evil_play and test_relay_bluff.

**In play:** 40 passive 10-NPC games, seeds 4000-4039, main against this branch. Counted: private
shares of an NPC's own readings, gift hints and gift claims, told first-hand to another NPC.
- **Day 1:** identical on both sides, as it should be.
- **Day 2 on:**

  | Private shares | Main | Here |
  |---|---|---|
  | Good: readings | 79 | 100 |
  | Good: gift hints | 36 | 42 |
  | Good: gift claims | 28 | 32 |
  | Evil: fake readings | 47 | 45 |
  | Evil: bluffed hints | 8 | 6 |
  | Evil: bluffed claims | 13 | 13 |
  | All, per game | 5.3 | 6.0 |

  - **Good NPCs** share their gift and readings privately about a fifth more often from day 2.
  - **Evil's** private bluffs don't rise, even though the same boost applies. It may be that
    evil NPCs claim publicly sooner, or have already told their fake readings to the people
    they talk to. I haven't looked further; at these counts the difference is within noise.
- **Effect on evil's cover:** no clear change on 40 games.

  | | Main | Here |
  |---|---|---|
  | Evil hanged | 56 | 52 |
  | Games where evil was hanged | 33 | 34 |
  | Day of evil's first hanging, on average | 2.5 | 2.6 |
  | Good hanged | 36 | 42 |
  | Winners | 22 good, 18 evil | 20 good, 20 evil |

  The differences are within what 40 games vary by. Passive games don't show what the player
  hears from the extra gossip.
- **Golden:** see `docs/golden_baseline.md`. On main with #321, only 98933 diverges, on day 2: it
  hangs Merrin on day 2 instead of Dorian then Isolde, with no winner by day 4 either way.

## Proposed for the backlog

None.
