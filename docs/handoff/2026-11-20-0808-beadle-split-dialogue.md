# Split mind_dialogue.gd (Tier 1)

- **Agent:** Claude-Beadle
- **Base:** main at `3b83b61` (`baseline_7792e9a`, with #399)
- **Branch:** `claude/beadle-split-dialogue`
- **Status:** PR open. Zero drift: golden is identical to `baseline_7792e9a` on all five seeds.
- **Next actor:** Bailiff (review and merge).
- **Item:** Michael's Nov 20 order, item 1, the cleanup: "File splits", Tier 1, the second of
  four (after #404's mind_meeting.gd).

## What changed

No change to play. Code moves only.

| File | Lines | Holds |
|---|---|---|
| `sim/mind_dialogue.gd` | 665 | greetings, disclosure gates and tiers, fear, protection and confidence requests, opinions, the dead, reactions to traces |
| `sim/mind_press.gd` (new) | 513 | hints, being pressed with evidence, the caught-out ladder |
| `sim/mind_answers.gd` (new) | 717 | answers about a gift, a night (alibis, night accounts, night gift results) and the day; sightings |
| `sim/mind_dialogue_base.gd` (new) | 157 | what all three share |

- **The base:** the three modules extend it. It holds:
  - the preloads and the module constants (the greeting expectations, `WORD_DOUBT_BELOW`,
    `OPINION_BONDED`);
  - lazy loaders for one another (`_dialogue()`, `_press()`, `_answers()`);
  - the delegates to `Mind`.
- **Calls across modules are prefixed.**
- **Callers repointed, with no new forwarders:**
  - `sim/mind.gd`'s wrappers now call the new modules, and every `Mind.<fn>` stays.
  - 12 suites and tools now use `MindPress` or `MindAnswers` where they called moved functions.
- **test_tuning_hoist** checks each moved constant in its new file.
- **The split was done by a script,** so it re-runs on a newer main.

## Order with other PRs

- **Quill's #415** (night-sighting rebuttals) edits `MindDialogue.press`, which moves to
  mind_press.gd. Either order works:
  - if #415 lands first, I re-run the split on top;
  - if this lands first, its hunk moves by hand.
- **The README code map** for these files is left for after #404 merges, since both touch the
  same lines.

## Measured

- **Golden:** identical to `baseline_7792e9a` at `--tol 0`.
- **Suites:** 19 of 19 pass. That's every suite the PR touches, plus test_npc_interactions,
  test_dialogue_voices, test_self_sighting, test_own_night_knowledge, test_npc_openness,
  test_social and test_confessed_night.

## Proposed for the backlog

None.
