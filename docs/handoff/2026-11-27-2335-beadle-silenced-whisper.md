# A silenced NPC shares nothing, in private too

- **Agent:** Claude-Beadle
- **Base:** main at `a88b83ba` (`baseline_1bf8a4b`)
- **Branch:** `claude/beadle-silenced-whisper`
- **Status:** PR open. Golden unmoved (all five seeds identical at `--tol 0`).
- **Next actor:** Bailiff (review and merge).
- **Item:** playtest 52102, finding 4. Michael (Nov 27, via Seneschal): a silenced NPC can't
  share anything, in private either; check the sim enforces it.

## What I checked

Every path by which an NPC passes something on:

| Path | Blocked when silenced? |
|---|---|
| NPC-to-NPC conversation (`Social.converse`), evil meetings included | yes, already |
| An NPC approaching the player (`social_approaches`) | yes, already |
| The player's `ask`, `press`, `tell`, `accuse` and the rest (`game_conversation`) | yes, already |
| The haunt and trait asides | yes, already |
| "Call on" | yes, already (refused) |
| The meeting: turns, podium, defence, votes | yes, already |
| A presented case | they read it, and speak no reply (already) |
| **Evil's whisper in the crowded tavern** (`Social.tavern_whispers`) | **no: fixed here** |
| The first-night evil conference | can't arise: no one is silenced on night 0 |

What a silenced NPC said earlier stays in the gossip network, as before: in 52102 Isolde told
Dorian her reading the morning before Odette took her voice.

## What changed

- **`Social.tavern_whispers`:** a silenced evil member no longer whispers intel to a teammate
  in the crowded tavern.

## Measured

- **New:** `tools/test_silenced_shares_nothing.gd`, 4 checks, on the slow CI list (about 20
  seconds). On 30 evil pairs in a crowded tavern (from seed 4200), 15 whispered when both could
  speak and none with one silenced; without the fix, 15 did with one silenced too.
- **Also pass:** test_silence_pressure, test_social, test_call_on, test_npc_interactions.
- **Golden:** identical to `baseline_1bf8a4b`: no silenced evil member is in a crowded tavern
  in the five seeds.

## Proposed for the backlog

None.
