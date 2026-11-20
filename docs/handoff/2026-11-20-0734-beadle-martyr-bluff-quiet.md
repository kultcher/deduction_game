# The evil Martyr bluff stays quiet against its chosen

- **Agent:** Claude-Beadle
- **Base:** main at `ad33789` (`baseline_7792e9a`)
- **Branch:** `claude/beadle-martyr-bluff-quiet`
- **Status:** draft PR. Zero drift: golden is identical to `baseline_7792e9a` on all five seeds.
  It's marked ready once the A/B is in.
- **Next actor:** Beadle (the A/B), then Bailiff.
- **BACKLOG item:** "Evil Martyr bluff can frame a good scapegoat" [decided] (Michael, Nov 20).
  From the overnight queue.

## What was already built

The choice itself was built on Nov 18 (#264, `Martyr.generate_bluff_reading`):
- **Who:** an evil Martyr bluff "gives its life over" for the hottest good NPC (`Evil.hottest_good`).
- **The frame:** when that NPC hangs, the bluff says they must have been evil, since its gift
  didn't take them (`on_bluff_chosen_executed`).
- **The fallback:** a teammate, used only when no good NPC is left to pick. That's an edge case.

## What changed: the "not loud" half

The hottest good NPC is often evil's scapegoat. So the bluff could lead the cry against the very
person it claims to protect, which is a plain tell. It now never does, wherever it would speak:
- **It never accuses its chosen at the meeting.** `MindMeeting._public_accusation`, evil branch,
  logs "leaves the case to others".
- **It never nominates them.** `MindMeeting._evil_nomination` now wraps its choice and drops a
  nomination of the chosen.
- **It never speaks against them** when they're nominated (`MindSupport.choose`).
- **Teammates are unaffected,** so they may still push the scapegoat.
- `Evil.martyr_bluff_chosen(n)` reads the made-up choice from its fake reading.

## Question for Michael

**Its own vote on its chosen:**
- **Today:** it votes as evil does, so yes on the scapegoat.
- **A real Martyr:** reluctant to vote to hang its chosen (`martyr_reluctance`), so an eager yes
  is a softer tell.
- **The question:** should the bluff copy that reluctance? It's not built, and I recommend yes.

## Measured

- **New:** `tools/test_martyr_bluff_quiet.gd` (5 checks), on the fast list.
  - It never accuses, nominates or speaks against its chosen.
  - A control: with no chosen, the same evil NPC accuses the scapegoat 7 times in 8.
- **Also pass:** test_evil_play, test_meeting_flow, test_meeting_m2a, test_meeting_m2c,
  test_too_clean_bluffs, test_relay_bluff, test_roles_registry and test_evil_owned_lie.
- **Golden:** identical to `baseline_7792e9a` at `--tol 0`.
- **A/B:** to follow, 40 passive games against main. It counts Martyr-bluff frames, the chosen
  hanged, and winners and hangings.

## Proposed for the backlog

None.
