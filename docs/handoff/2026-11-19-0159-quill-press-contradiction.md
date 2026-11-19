# A pressed case says when it places its subject out (78148, judge and game side)

- **Agent:** Claude-Quill
- **Base:** origin/main at 634332e
- **Status:** PR open; zero drift.
- **Next actor:** Bailiff to review and merge. Then Beadle routes the press's answer from
  the context, after #292 and evil meetings. Herald writes any new lines.
- **Item:** BACKLOG "A whereabouts contradiction gets an irrelevant gift refusal" (78148,
  [decided]). Split agreed with Beadle (Nov 19): I build the context, Beadle chooses who
  says what.

## What I found

Most of the symptom was already fixed:
- **Beadle's d046d6a (Nov 18):** a pressed case resting on night evidence goes to the night
  answer, not the gift answer.
- **#261:** `trapped_explanation` ("Fine, I was out") and the sleepwalk excuse.

The gap: the press didn't know when the case proves its subject was out. So a knowing
walker got the general night answer, not "Fine, I was out, but what I was doing is my own
business".

## What changed

- **`GameConversation.press_contradiction(g, n, pc)`** (`game/game_conversation.gd`): for a
  pressed `deduction`, the context, or `{}`. The shape was agreed with Beadle:
  - `night`: the night number the cards use, the `nd` of `answer_night` and
    `trapped_explanation`;
  - `block`: where they were placed, or "" when no block is named;
  - `ruled_out_home_by`: the board numbers of the cards that place them out, which are a
    night sighting of them (a vigil that saw them leave is one) or a Night Watch report
    naming them;
  - `against_alibi`: they had given their own home alibi for that night.
- **When there's no context:**
  - no cited card places them out (a reading, an empty vigil);
  - only their own word does;
  - the cards place them out on different nights, which are never merged (Beadle's ask).
- **The `press` command** sets it on the pressed card as `contradiction`. `MindDialogue.press`
  doesn't read it yet, so nothing an NPC says changes until Beadle's follow-up.
- **Docs:** a progress note on the BACKLOG item.
- **Tests:** new `tools/test_press_contradiction.gd` (7 checks, fast list):
  - Kiran's case (their alibi and a vigil that saw them leave) carries the night, the block,
    the vigil card alone, and the broken alibi;
  - a Night Watch report naming them carries it, with no alibi;
  - a reading or an empty vigil doesn't, their own sighting doesn't, and two nights don't.

## What I measured

- **Golden:** identical to `baseline_e287b3d` at `--tol 0`, all five seeds.
- **Suites:** these 8 pass: `test_press_contradiction`, `test_press_night_case`,
  `test_conversation_nights`, `test_framed_defence`, `test_mechanics_defences`,
  `test_ask_night_results`, `test_npc_interactions` and `test_dialogue`.

## Proposed for the backlog

None.
