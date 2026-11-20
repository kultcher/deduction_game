# The town's response to a double claim, and the private "they're lying"

- **Agent:** Claude-Beadle
- **Base:** main at `8c45a7c` (`baseline_9ea3f99`)
- **Branch:** `claude/beadle-double-claims`
- **Status:** PR open. It moves golden on two seeds and re-baselines to `baseline_c7c2199`.
  Golden-moving PRs merge one at a time.
- **Next actor:** Bailiff (review and merge).
- **BACKLOG item:** "More rebuttals after a caught lie": the town's response to a double
  claim (Michael, Nov 19; Vicar's #364).

## What changed

- **The true holder counterclaims at its first chance** (`MindMeeting._public_claim_decision`).
  - **When:** a good NPC whose gift someone else has claimed, publicly or in something it
    heard (`rival_claimants`).
  - **What:** it claims its gift at its next meeting turn, past its usual reticence and any
    promise to the player.
  - **A silenced holder,** or one that heard of the claim outside a meeting, counterclaims at
    the next meeting.
- **A taken bluff switches** (`switch_taken_bluff`).
  - **When:** evil whose planned bluff someone else claims first, before it has claimed
    anything, and before it has told a fake reading of that bluff.
  - **What:** it switches to a spare from the bluff list, one no teammate uses and nobody has
    claimed.
  - **Log:** "bluff taken; switched to <role>".
- **A Minion's deliberate double claim** (`choose_double_claim`).
  - **Who:** an unclaimed Minion, never the Demon or a Scion, and not one committed by a fake
    reading it has told.
  - **What:** when it hears someone claim a gift, it may knowingly take that gift as its
    bluff and claim it at its turn.
  - **How likely:** `Tuning.Evil.MINION_DOUBLE_CLAIM_CHANCE` = 0.05 each time (new; Michael set
    0.05, Nov 19), scaled down by its heat (`Evil.exposure`'s public talk), to nothing at full
    heat.
  - **Log:** the claim is a lie with its reason.
- **The private "<witness> is lying about seeing me"** (`MindDialogue._witness_lying`).
  - **When:** pressed in private with another NPC's sighting, an NPC standing by "home" says
    it if its Confidence is over the meeting defence's gate (0.6).
  - **Who:** evil uses it freely; a good NPC says it only if it really was home.
  - **Weight:** a line only. It adds no doubt of the witness (Michael, Nov 19).
  - **Lines:** `press_witness_lying` in all 15 voices, Herald's lines as Michael approved them.
    The voice key count goes to 257.

## Small calls made on Michael's behalf

- **The double claim's trigger:** any claim the Minion hears at a meeting, of a gift that
  isn't evil's own. It's checked when the claim is made.
- **Spares:** they come from evil's existing bluff list only. With no spare free, evil keeps
  its bluff, as today.
- **The private "lying" line:** sightings only, not readings. Herald's lines are about being
  seen.

## Measured

**Suites:**
- **New:** `tools/test_double_claim_response.gd` (13 checks), on the fast list:
  - the holder counterclaims, whether it saw the claim or heard of it;
  - the switch, its gates and its logged reason;
  - the Minion's rate at about 0.05 when cold;
  - never the Demon, and never at full heat;
  - the private "lying" line and its Confidence gate.
- **Also pass:** test_dialogue_voices (257 keys), test_caught_out_ladder, test_meeting_flow,
  test_evil_play, test_double_claim, test_mechanics_claims, test_meeting_m2a, test_relay_bluff,
  test_too_clean_bluffs, test_npc_interactions, test_evil_owned_lie and test_press_caught_out.

**In play:** 40 passive 10-NPC games, seeds 4000-4039, main (`49b17ec`) against this branch at
0.05, with the Minion's roll on its own draw.

| | Main | Here |
|---|---|---|
| Winners | 20 good, 20 evil | 19 good, 21 evil |
| Hangings | 88 | 95 |
| Evil hanged | 54 | 62 |
| Good hanged | 34 | 33 |
| Deliberate double claims | — | 9 (in 9 games) |

- **A double claim usually costs the Minion.** It was hanged in 8 of the 9 cases, 5 times
  within a day of claiming. The real holder was hanged too in 4 of them. Evil won 6 of those
  9 games, so the confusion sometimes pays off even when the Minion is lost.
- **Holder counterclaims and bluff switches: none fired in these 40 games.** That follows from
  how the deal works. Evil's bluffs are gifts not in play, so a good holder's gift is claimed
  by someone else only through a double claim. By then the holder has already claimed, since
  the double claim answers its claim. Both paths are covered by the suite.
- **How to read it:** more evil hanged and no more good. At 40 games, the winner shift is
  within noise.
- **An earlier run at 0.15,** on the world's draw, gave 12 double claims in 40 games. The
  Minion was hanged in all 12, 11 times within a day. Winners were 22 good, 18 evil.

**The Minion's roll has its own draw,** seeded from the moment, like the tavern gossip. So the
world's random stream, and golden, move only where a double claim is actually made. The suite
checks this.

**Golden:** see `docs/golden_baseline.md`.

## Proposed for the backlog

None.
