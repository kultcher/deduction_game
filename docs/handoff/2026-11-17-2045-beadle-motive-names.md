# 2026-11-17, Claude-Beadle: bluff motives name people, not ids (claude/beadle-motive-names)

**Base:** `claude/beadle-fabcheck-fixes` (#224), on main 19d5771. **Status:** PR open. It
merges after #224, and moves golden in text only, so it needs a golden-queue slot. **Next
actor:** Codex, then Bailiff. I re-baseline when it's called up.

## What changed and why (Steward A3; Seneschal, Nov 17: a bug fix, not wording)

- **Before:** a fabrication's motive was built from people's ids, for example "the dead
  Seer lian 'cleared' the demon merrin", or `names ["edda", "lian"] instead`. The
  end-of-game reveal printed it as written.
- **After:** `Evil.named` swaps each whole-word id for the person's name when the motive is
  stamped on the reading. That happens in `_make_fake_info_for_phase`, and in the
  Executor's own path.
- **Not changed:** the rest of the wording, including the developer shorthand ("same=",
  "->", "'pinged'"). Herald has the list for a wording pass, and Michael approves.

## Measured

- `test_fabrication_check`: 110 checks pass. New: the swap itself (ids become names, other
  words are left alone), and a played-games check that no listed fabrication's motive
  carries an id.
- Also passing: test_evil_play, test_evidence_cards, test_nightwatch_bluff_teammates.
- **Golden against `baseline_3ef0e2f`:** all 5 seeds differ, but only in the recorded
  motive text (each reading's `why`, ids now names). The same number of records, and no
  other field changes, so no behaviour moves.

## Also: the rework note's final wording (Michael, Nov 17)
- `FabricationCheck.rework_note` now reads "…; its first version would have turned the town
  on {name}, so it told this one instead", Herald's version, picked by Michael.
- Golden is unchanged from `baseline_eb8e59b`: no golden seed has a reworked lie.
