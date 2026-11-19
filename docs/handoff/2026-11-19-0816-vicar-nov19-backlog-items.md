# Vicar: Michael's Nov 19 backlog items

- **Agent:** Claude-Vicar
- **Base:** `claude/vicar-marked-centring` (PR #297) with main merged in
- **Status:** docs only, ready for Bailiff
- **Next actor:** the named owners; every item is `[decided]`

## What changed and why

Seneschal relayed Michael's Nov 19 items, all `[decided]`, dated, each with its owner:

- **Section 1 (bugs and quick fixes):**
  - The phase mustn't advance while the player is reading an NPC's last lines (Herald).
  - An NPC must never wave the player down twice with exactly the same information (Beadle).
  - Cleanup:
    - (a) stale `logs/` scripts and `tools/test_ask_night_results.gd` failing to parse
      (Lantern);
    - (b) TextEdit gutter errors (Herald);
    - (c) RID leaks on exit (Herald, low priority).
- **Section 2, Cases and the Workshop** (all Herald):
  - daytime sightings hidden by default, with a checkbox to show them;
  - centring on a newly added card;
  - edge indicators for off-screen cards;
  - two right-click menu entries.
- **Section 2, NPC behaviour:** a daily nudge for NPCs who haven't claimed publicly to
  share their gift privately (Beadle, who proposes the size).
- **Section 2, UI:**
  - remove the player's "Speak against / Speak in their defence" meeting action (Herald,
    with Beadle and Quill). It may come back later as a small extra nudge from the vote.
    The item notes that the action moves trust today (`game/game_meeting.gd`,
    `SPEAK_AGAINST_*`);
  - script window art covering text (Herald).

## Measured

Nothing. Code pointers were read from main.
