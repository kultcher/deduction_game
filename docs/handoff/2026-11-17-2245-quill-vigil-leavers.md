# 2026-11-17, Claude-Quill: the vigil watches who leaves the block (`claude/vigil-leavers`; moves golden, text only)

- **Base:** main (merged in at `318b29c`). **Status:** PR open. **Next:** Bailiff (review;
  golden-moving, merge on its own). Then a playtest.
- **What (BACKLOG "The vigil watches who leaves", [decided], Michael Nov 17;
  `docs/design/vigil.md` option A):** a player vigil now sees the watched block's residents
  leaving home, plus anyone on the full lamp or Sexton tour. It no longer sees walkers
  arriving from another block.
  - **One rule, both sides:** `C.vigil_sees_path` now checks where a night path starts, not
    where it ends. The C# kernel mirrors it (`PathSpec.FirstBlock`). The judge's empty-vigil
    and complete-vigil cards read the same rule, so they follow automatically.
  - **Small call, builder's (§5):** the lamp-route clause stays. Someone walking every block,
    lighting lamps or ringing the bell, is seen from any block.
  - **Bot:** `tools/autoplay.gd` keeps its vigil on the block whose living residents it
    suspects most between them. The old policy chose a trusted claimant's home, and its three
    constants are gone. Its summary now counts vigils kept, vigils that saw someone and
    vigils that saw the Demon.
- **Wording settled by Michael (Herald's draft, Nov 17):**
  - Empty vigil, narration: "You kept watch over {block} all night. Nobody stirred."
  - Empty vigil, card: "Night {n} vigil on {block}: nobody stirred." (The block is named once;
    the old card named it twice.)
  - People seen, narration: "You kept watch over {block}. In the night, {names} went out."
  - People seen, card: "Night {n} vigil on {block}: you saw {names} go out."
  - Help: "'vigil <block>' (watch who goes out from a block at night)"
- **Bot, before and after:** seeds 1–20, 10 NPCs, the M4 policy. Before is main with only the
  vigil counts added.

  | | Old rule (arrivals) | New rule (leavers) |
  |---|---|---|
  | Good wins | 13 of 20 | 17 of 20 |
  | Vigils kept | 56 | 44 |
  | Vigils that saw someone | 39 | 29 |
  | Vigils that saw the Demon | 11 (1 in 5) | 12 (about 1 in 4) |
  | Good people hanged per game | 0.75 | 0.6 |
  | Average game length | 4.2 days | 3.75 days |

  The note expected the bot to do worse. It did a little better, because it now watches its
  suspects' homes, and the Demon leaves home on every kill night, so a vigil on a suspected
  Demon's block catches it going out. That's the player's deduction doing the work, as the
  note intends: the hit depends on suspecting the right block. Twenty games is a small
  sample; treat the direction, not the size.
- **Golden:** re-baselined to `baseline_318b29c`. It's text only: the night prompt's help
  line, on every seed. With that string put back, all five seeds are identical to
  `baseline_1f2e761`. The rule itself doesn't reach golden, because the passive player never
  keeps a vigil. Two captures were identical.
- **Tests:** 23 suites that touch vigils pass. Six fixtures that pinned the arrival rule are
  restated to test the same idea under the new one:
  - `test_evidence_cards`, `test_workshop_live_activity` and `test_workshop_remaining`: the
    vigil or coverage on the suspect's own block.
  - `test_meeting_reasons` and `test_workshop_regressions` (98933): the vigil on the Night
    Watch's own block.
  - `test_workshop_reading_challenges`: Nisha's block, with Constance made her neighbour.
  - The sigil check in `test_workshop_regressions`: a witness's sighting near the door
    replaces the vigil. A vigil seeing someone leave says nothing of where they went, so the
    sigil can't add to it.
- **Docs:** DESIGN's "Vigils see who leaves" and the Night section's Vigil line are
  rewritten. The design note is marked built, and the BACKLOG item has a built note.
- **Still open (note §4):**
  - Offered and requested vigils keep their wording. They now watch the NPC and their
    neighbours.
  - Random misses: none, as before.
