# Herald: the night-sighting rebuttals in all 15 voices, in block terms

- **Agent:** Claude-Herald
- **Base:** Quill's #415 (`claude/night-rebuttals`)
- **Status:** on #415
- **Next actor:** Bailiff

## What changed and why

Michael approved my per-voice drafts for #415's four placeholder lines on Nov 20, via Seneschal, with one change: **no "road" wording.** There are no roads; people move directly from block to block. Every line that said "road", "path" or "on the way" is reworded in block terms, and so is Quill's canonical line.

- **Canonical** (`MindDefence.rebuttal_line`):
  - other_block: "Someone died on {block} that night; I was never on {block}." It was "…; I was nowhere near the road there."
  - no_death: unchanged, "I was seen out {when}, but no one died that night."
- **"Never on {block}" stays true as stated under Quill's rule.** The death's block is on the route from the defender's home to the victim's, so a defender who was really there never says the line, good or evil.
- **The 60 voiced lines** (`defence_night_*` and `private_night_*` in all 15 voices) are my approved drafts. The other_block lines that named a road or path are now block terms:
  - Agnes (meeting): "…and I was never on {block}."
  - Agnes (private): "…I wasn't anywhere near {block}, I promise you."
  - Bart (meeting): "…I wasn't there."
  - Constance: meeting "…I was never on {block}."; private "…I was nowhere near it."
  - Dorian (meeting): "…I wasn't anywhere near {block}."
  - Edda: meeting "…I never set foot on {block}. Not a step."; private "…I was nowhere near it."
  - Fenwick: meeting "…I never set foot there!"; private "…I came nowhere near it." It was "my path came nowhere near it".
  - Greta: meeting "…nowhere near {block}…"; private "…nowhere near it, whatever they say."
  - Hollis: meeting "…never on {block}."; private "…nowhere near {block}."
  - Isolde: meeting "…nowhere near {block}."; private "…nowhere near it, I swear it."
  - Jory (meeting): "…wasn't anywhere near it!"
  - Kiran: meeting and private "…nowhere near it…"
  - Lian: meeting "…I wasn't there."; private "…I was elsewhere."
  - Merrin (meeting): "…nowhere near that dreadful place!"
  - Nisha: meeting "…nothing places me on {block} that night."; private "Look at where I was seen: … I was never on {block} that night." This replaces the route wording Michael flagged.
  - Odette: meeting "…nowhere near {block}. Do keep up."; private "…nowhere near it."
- **The no_death lines are as drafted.** None mentioned a road.
- **Tests:**
  - test_night_sighting_rebuttal now looks for the new canonical text ("I was never on").
  - test_dialogue_voices adds the four keys to its check that every voice resolves cleanly and all 15 differ.

## Measured

- test_dialogue_voices, test_night_sighting_rebuttal, test_dialogue and test_text_terms pass.
- **Golden:** identical at `--tol 0` on all five seeds (baseline_58cb94a).

## Proposed for the backlog
None.
