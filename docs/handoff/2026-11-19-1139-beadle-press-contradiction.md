# A pressed case that places its subject out gets "Fine, I was out"

- **Agent:** Claude-Beadle
- **Base:** main at 4e805c7
- **Branch:** `claude/beadle-press-contradiction`
- **Status:** PR open. Zero drift.
- **Next actor:** Bailiff (review and merge).
- **BACKLOG item:** "A whereabouts contradiction gets an irrelevant gift refusal" (78148,
  Kiran, [decided]). This is Beadle's half, after Quill's #303. The progress note says it's
  built and can close once this merges.

## What changed

Quill's #303 gives a pressed case a `contradiction` when its cards place the subject out on a
night. `MindDialogue.press` now reads it (`_pressed_caught_out`):
- **The night:** the case is about the night the contradiction names.
- **A good NPC out on its own business** (a secret errand, not its gift):
  - it says "Fine, I was out. Doesn't mean I was doing anything wrong." This is
    `trapped_night_out`, the line a presented case already gets in `WorkshopPresentation`;
  - at disclosure tier 2 or above, it then says why (`trapped_explanation`: its secret, owned
    for that night);
  - closed, it says only the first line. Either way, it no longer says it was home.
- **Unchanged:**
  - the truly home stand by being home;
  - an unaware Sleepwalker remembers being home and may offer the sleepwalking excuse;
  - a gift walker owns its gift, or tells its duty if it has claimed;
  - evil keeps its cover.
- **Without the context** (no card places them out), the press answers as before.

No new lines and no new constants.

## Measured

- **New suite:** `tools/test_press_caught_out.gd` (8 checks), on the fast list. It covers the
  open and the closed errand-walker, the same press without the context (which still says "I
  was at home", the old answer), the truly home, an unaware Sleepwalker, and evil.
- **Also pass:** test_press_contradiction, test_press_night_case, test_conversation_nights,
  test_framed_defence, test_mechanics_defences, test_ask_night_results, test_npc_interactions,
  test_dialogue, test_dialogue_decisions and test_dialogue_voices.
- **Golden:** identical to `baseline_659996a` at `--tol 0` on all five seeds. Golden play
  doesn't press with such a case.

## Proposed for the backlog

None.
