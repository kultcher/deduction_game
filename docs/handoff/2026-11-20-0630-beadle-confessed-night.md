# A confessed night stays confessed

- **Agent:** Claude-Beadle
- **Base:** main at `2a7b6bd` (`baseline_9ea3f99`)
- **Branch:** `claude/beadle-confessed-night`
- **Status:** PR open. Zero drift: golden is identical to `baseline_9ea3f99` on all five seeds,
  and two captures were identical.
- **Next actor:** Bailiff (review and merge).
- **Found by:** Quill, on #397 (Nov 20): test_npc_fixes_shifts_dead_haunt, seed 701.

## The bug

A good NPC that had confessed a night's errand, at the podium or to the player, was asked about
that night again. It rolled afresh whether to confess. When the roll failed, it refused to say,
or told a home lie about the very night it had owned.
- **Why:** the stored confession (a "secret" account) didn't count as owning the night, so
  neither path knew it had already confessed.
- **Where:** in private (`MindDialogue.answer_night`) and at the podium
  (`MindPodium.press_night`).
- **On main,** the new suite shows a home lie in both places.

## What changed

- **`MindPodium.confessed_before(d, nd)`:** true when that night's stored account is the NPC's
  own confession.
- **Asked again, it confesses again,** with no roll: in private and at the podium.
- **After a confession before the town,** the private retelling uses the podium's existing line,
  "I wasn't out for anything wicked. I ...". Before, it was the private plea, "Please, keep it
  quiet". No new wording.

## Measured

- **New:** `tools/test_confessed_night.gd` (5 checks), on the fast list. Three of them fail on
  main.
  - After a public confession, the private answer is the confession: never a refusal or a lie,
    and with no plea to keep it quiet.
  - The same after a private confession.
  - Pressed again at the podium, it confesses again.
  - A control: with nothing confessed, an unwilling NPC still keeps its errand.
- **Also pass:** test_caught_out_ladder, test_press_caught_out, test_npc_interactions,
  test_npc_fixes_shifts_dead_haunt, test_meeting_flow, test_dialogue_voices and
  test_self_sighting.
- **Golden:** identical to `baseline_9ea3f99` at `--tol 0`. No golden seed asks a confessed NPC
  about the same night again.

## Proposed for the backlog

None.
