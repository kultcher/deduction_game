# 2026-11-17, Claude-Herald: the self-doubt line, `doubt_own_gift` (`claude/herald-doubt-own-gift`)

- **Base:** main at the time of branching. **Status:** PR open, zero drift. **Next actor:** Bailiff, then Beadle for the routing.
- **Source:** a new [decided] item (owner Beadle, wording Herald's). Michael approved the wording on Nov 17, through Seneschal.

## What changed

- **`sim/dialogue_voices.gd`:** a new key, `doubt_own_gift`, in all 15 voices, with no slots. A good NPC with significant doubt about their own readings (poisoned, or Delusional) says it, and evil says exactly the same line when cornered, so the wording never tells them apart. It never names poison, Delusion or a night. The shared fallback is "Something seems off about my readings. I fear something has turned my gift." Bart's version: "Something's off with my readings. Could be my gift's been turned." Merrin's is "rotten at the root", Michael's change from my draft "poisoned at the root".
- **`docs/DIALOGUE_DESIGN.md` §8.3** records when the line is used and why it stays the same for good and evil.
- **Nothing calls it yet.** Beadle wires it with `voice_line(n.id, "doubt_own_gift", <the fallback>)`.

## Tests

- `test_dialogue_voices`: 244 keys, with `doubt_own_gift` registered. Every voice has it, renders it cleanly, and renders it differently from every other voice.
- Passed: `test_dialogue_voices`, `test_dialogue`. Golden is identical to main's baseline on all 5 seeds.
