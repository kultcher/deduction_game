# Herald: the silence-breaker opener in all 15 voices

- **Agent:** Claude-Herald
- **Base:** main
- **Status:** PR open
- **Next actor:** Bailiff. Beadle's "pressure of silence" PR follows and calls the key.

## What changed and why

Michael approved Beadle's "pressure of silence" on Nov 20, including an optional opener. When a meeting has gone quiet, the speaking order runs once more, and an NPC who speaks up to fill the silence opens with a short line. He approved these 15 lines as drafted, via Seneschal. They go in first, as Beadle asked, so his PR calls a key that already exists.

- **The key:** `silence_breaker` in `sim/dialogue_voices.gd`, for every voice, with no slots. The canonical line in Beadle's call is Michael's own: "Well, someone ought to say something."
- **Who says it (agreed with Beadle; Michael agreed):**
  - any NPC whose second-pass turn has content, evil included, so the line never hints at alignment;
  - once per NPC per meeting;
  - never on a first-pass turn.
- **Nothing calls the key yet,** so it's zero drift.

| Voice | Line |
|---|---|
| Agnes | Well, someone ought to say something, love, and it may as well be me. |
| Bart | Somebody say something. Fine, I will. |
| Constance | This silence serves no one. Permit me to break it. |
| Dorian | Sorry, the quiet's getting to me. May I say something? |
| Edda | We'll get nowhere standing about like loaves left to cool. Here's what I think. |
| Fenwick | A silent stage makes a dull play! Let me give us a line. |
| Greta | That's a long silence. Someone has to speak first, and I'll wager it's me. |
| Hollis | Silence settles nothing. Allow me to put something forward. |
| Isolde | This quiet frightens me more than talk would. Let me say what's on my mind. |
| Jory | Is nobody going to say anything? All right, me then! |
| Kiran | Nobody's playing a card? Then I'll lead. |
| Lian | Too quiet. I'll start. |
| Merrin | Woe! Must we sit in silence while the night creeps closer? I'll speak. |
| Nisha | We learn nothing by saying nothing. Let me begin. |
| Odette | Such a hush! Someone must take the stage, and I don't mind if it's me. |

## Measured

- **`test_dialogue_voices`:** the key joins its check that every voice resolves it cleanly, with no slots left and all 15 distinct. The count of keys per voice goes from 257 to 258.
- **Suites:** `test_dialogue_voices`, `test_dialogue` and `test_text_terms` pass locally.
- **Golden:** not captured. Nothing reads the key, and CI runs the diff.

## Proposed for the backlog
None.
