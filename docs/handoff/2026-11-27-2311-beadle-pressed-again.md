# Caught out and pressed again (1 of 2): private presses

- **Agent:** Claude-Beadle
- **Base:** main at `a88b83ba` (`baseline_1bf8a4b`)
- **Branch:** `claude/beadle-pressed-again`
- **Status:** PR open. Golden unmoved (all five seeds identical at `--tol 0`).
- **Next actor:** Bailiff (review and merge). Part 2, the same ladder at the podium, follows in
  its own PR.
- **BACKLOG item:** "Caught out and pressed again: what's left" [decided]. Plan by Michael
  (Nov 20); constants approved by Michael (Nov 27, via Seneschal).

## What changed

- **A good NPC that owned a night but kept the reason** (pressed with a case placing it out):
  - each earlier press about that same night adds `Tuning.Dialogue.PRESSED_AGAIN_OPENNESS`
    (0.15, new) to the openness check for giving the reason;
  - once the check passes, the reason comes out: its gift, or a known burden's walk (today,
    the Unrequited's visit, through the existing confession and its card);
  - `MindDialogue._target_tier` takes the bonus as an optional argument, default 0, so every
    other caller is unchanged. The count is logged as `presses` on the answer's `admit_out`
    entry.
- **A truly-home NPC pressed again about that night:** same lines as before ("I stand by that
  account"). From the second press about that night, it trusts the asker less, by the existing
  question-fatigue amount, whatever today's count of questions. No new constant.
- **Evil pressed again about a night it owned, with no walking bluff to tell:**
  - it may back into a spare walking gift from its bluff pool: one no teammate bluffs, no
    claimant it knows of holds, and whose night work explains that night;
  - the chance per re-press is `PRESSED_AGAIN_BACKUP_MINION` (0.6, new) for a Minion, or
    `PRESSED_AGAIN_BACKUP_CAREFUL` (0.3, new) for the Demon or a Scion;
  - it switches its bluff (the existing `_change_bluff`, which backfills a first-night reading),
    logs the lie with its reason, and answers as the gift;
  - never once it has named a gift to anyone, publicly or in private (including to another
    NPC, which only the listener records, or by telling a made-up reading), and never a
    Revenant-turned townsperson, whose real gift is its cover (Codex on #560). With no spare
    walking gift, it stays with "being out isn't wicked": wary of a double claim;
  - the re-press counts as one question, not two (Codex on #560).
- **The press count** is `MindPress.press_count(n, night)`, kept in `dialogue_memory`
  (`caught_presses`), so the podium can share it in part 2.

## Dropped from the Nov 20 plan

- **The Sleepwalker's lines:** Burdens retired Sleepwalker 1.0, so there's nothing to build
  (Seneschal, Nov 23).
- **"Gift or secret errand"** is now "gift or known burden": the secret errand is retired too,
  and `n.secret` is set only by the Unrequited setup. Other burdens don't explain a night out.

## Measured

- **New:** `tools/test_pressed_again.gd`, 15 checks, on the slow CI list (about 50 seconds):
  - 30 deals from seed 3000: 20 closed NPCs kept the reason at the first press, and all 20
    gave it within six more presses;
  - a truly-home NPC loses trust in the asker on the second press, not the first;
  - from seed 3200, on the second press: a Minion backed into a spare walking gift in 9 of 16
    cases, the Demon in 6 of 14. Both counts are small. Never on the first press, never into a
    gift that doesn't explain the night, never once it has named a gift;
  - never a turned townsperson (12 cases), never once it has named its bluff to another NPC,
    and the backup counts one question (5 cases). Each check fails with its guard removed.
- **Also pass:** test_caught_lie_softening, test_caught_lying, test_caught_out_ladder,
  test_press_caught_out, test_press_contradiction, test_press_night_case,
  test_silence_pressure, test_trapped_explanation, test_dialogue_voices,
  test_burden_unrequited and test_double_claim_response.
- **Golden:** identical to `baseline_1bf8a4b` on all five seeds. The golden bot never presses
  the same night twice.
- **Not measured:** how often players press the same night twice.

## Proposed for the backlog

None.
