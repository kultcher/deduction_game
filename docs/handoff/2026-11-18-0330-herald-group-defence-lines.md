# 2026-11-18, Claude-Herald: "it's another of us" lines; the register rule corrected; the card-text item (`claude/herald-group-defence-lines`)

- **Base:** main `980766b`. **Status:** PR open, zero drift. **Next actor:** Bailiff, then Beadle to wire the lines.
- **Source:** Michael, Nov 18, through Seneschal:
  - the "another of us" lines are approved as drafted, in all voices;
  - the register rule is corrected;
  - card nights stay numbered;
  - the full card sentences become a [decided] item owned by Herald.

## What changed

- **`sim/dialogue_voices.gd`:** two new keys, in all 15 voices, for Beadle's group-reading defence (89077 finding 1).
  - `defence_group_named` (slots `{source}`, `{others}`) names the other one or two people. Every voice reads with one name or two, e.g. Bart: "{source} read a few of us. Not me. Look at {others}."
  - `defence_group_others` (slot `{source}`) is for three or more others, or when evil won't name a teammate. Bart: "{source} read a crowd of us. Not me. Look at the rest."
  - **Nothing calls the keys yet.** Beadle wires them on `claude/beadle-group-defence` with `voice_line(n.id, "defence_group_named", <fallback>, {"source": .., "others": ..})`. The canonical fallbacks Michael approved are "{source}'s reading points at one of us. It isn't me, so look at {others}." and "{source}'s reading points at one of several of us. It isn't me, so look among the rest."
- **`docs/DIALOGUE_DESIGN.md`, principle 9, corrected:**
  - a scholarly or analytical register is fine, so Hollis and Nisha can sound learned;
  - only modern-sounding words are out (data, variable, model, constraint);
  - nights are ordinals in speech and numbered on cards ("Night 2").
- **`BACKLOG.md` (UI):** new item "Card text: the fewest words on the card, the full sentence on hover" [decided], owner Herald. It follows #250.

## Tests

- `test_dialogue_voices`: 246 keys. Both new keys resolve in every voice with their slot values kept, and each voice's line differs from the others'. `test_dialogue` passes.

## Also in this PR: `test_workshop_ui_1110` no longer depends on the deal (Michael, Nov 18, through Seneschal)

- **The problem:** the suite took its canvas cards from seed 54875's board, and guarded the drag, unlink, delete and undo checks with `if ev_ids.size() >= 2`. A deal with fewer cards would have skipped those checks silently.
- **The fix:** it now adds three sighting cards by hand, and fails outright (`quit(1)`) if fewer than three reach the canvas. The suite isn't renamed: Steward renames the playtest-named suites on Thursday.
- **Result:** 9 checks pass.
