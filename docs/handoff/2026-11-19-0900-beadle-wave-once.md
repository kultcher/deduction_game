# Never waved down twice with the same news

- **Agent:** Claude-Beadle
- **Base:** main at 05d81a3
- **Branch:** `claude/beadle-wave-once`
- **Status:** PR open. It's zero drift: golden is identical to `baseline_d6a93f1` on all five
  seeds.
- **Next actor:** Bailiff (review and merge).
- **Item:** Michael (Nov 19, through Seneschal): "an NPC can currently wave the player down twice
  with the exact same information. Make sure that never happens." Vicar is adding it to BACKLOG.

## The cause

An NPC approaches with news when it holds a reading it hasn't told the player: one past
`told_readings` and not yet public. When the approach's answer held that reading back,
`told_readings` didn't move:
- the disclosure gate withheld it;
- or the answer fell short of telling everything.

So the next phase the same reading still counted as news, and the NPC waved the player down
again with the same claim and readings. Good NPCs ("news") and evil bluffers ("frame") both go
through `Social.approach_open`.

## The fix

`approach_open` marks every reading the approach was about (`told_to["player|approached:<i>"]`).
`approach_candidate` no longer counts a marked reading as news. A new reading still brings them,
whatever was said about the old one.

The other approach routes already track what was told:
- gossip marks each item (`player|hs:<i>`, `player|secret:<owner>`);
- a kept-word disclosure fires once (`divulge_due`);
- protection requests are once a day, and they're requests, not news.

## Measured

- **New suite:** `tools/test_wave_once.gd` (3 checks), on the fast list. It covers: a reading
  brings an approach; after approaching about it, with the answer held back, never again for
  that reading; a new reading brings them back.
  - **Without the fix,** the second check fails.
- **Suites that pass:** test_social, test_npc_openness, test_evil_play and test_meeting_flow.
- **A probe of 20 played games accepting every approach** (39 approaches, seeds 5000-5019, before
  the fix): no exact repeat turned up there. The suite reproduces the case directly.
- **Golden:** identical.

## Proposed for the backlog

None.
