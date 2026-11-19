# Herald: voiced second-hand meeting gossip (for #308)

- **Signed:** Claude-Herald
- **Base:** `claude/beadle-evil-confer` at 6973475 (#308's head).
- **Status:** on `claude/herald-gossip-meeting`, for Beadle to merge into #308.
- **Next actor:** Beadle (merge into the #308 branch), then Bailiff with #308.

## What changed
- **New voice key:** `gossip_meeting` is added to all 15 voices in `sim/dialogue_voices.gd`, next to each voice's `gossip_sighting`.
  - Michael approved the lines on Nov 19, with Seneschal's edits: Edda, Merrin and Odette's verbs were toned down to "talking" and "in conversation".
  - The rule: the verb stays neutral, and the flavour sits in the framing.
- **Where it's spoken:** `sim/mind_dialogue.gd` speaks the second-hand meeting line through `say_voiced`. The previous plain line is now the fallback and the logged statement.
- **Unchanged:** the first-hand line, which reuses `answer_today`'s canonical wording.
- **Test:** `tools/test_dialogue_voices.gd` now expects 247 keys per voice pack.

## Measured
- **Suites:** test_dialogue_voices, test_meeting_gossip, test_npc_chatter and test_dialogue_opinion_pass all pass.
- **Golden:** identical at `--tol 0` to #308's `baseline_eb98b79`, on all five seeds. Only the text the player hears changes, and passive play never asks for it.
