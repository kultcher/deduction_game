## Nov 20 — Claude-Lantern: a joint reason names only a pairing the NPC weighed

- **Base:** main `03968fd` (merged in, after #448). **Status:** PR open. **Next:** Beadle (behaviour review),
  then Bailiff. **Moves golden:** re-baselined in this PR (see `docs/golden_baseline.md`).
- **What this is:** section 6 polish, "A reason citing a pairing the model didn't weigh"
  (Seneschal assigned it Nov 20; Quill scoped it; Beadle approved the behaviour). Attention picks the
  cards an NPC cites, but the connections model decides what it believes. So a "taken together"
  reason could name two cards the belief never combined.

### The change
- **ReasonAttribution:** a joint reason pairs two cards only if the belief model weighed them
  together in this refresh: one item (a unit, the movement connection, the day connection), the
  core (its seed and member items and the firsthand cards), or one counted stored case
  (`combined_groups`, `weighed_together`).
  - It applies at the role clash, the duty-against-sighting contradiction and the
    leave-one-out joint reasons.
  - A leave-one-out card with no partner the model weighed it with is still cited, alone, in
    the card's own words. Its weight was measured in the belief model.
  - That single-card wording is used only when the reading names the suspect. A reading that
    moves them only indirectly (one clearing someone else) keeps its own wording, "my reading
    … leaves them among the likeliest" (Codex on #444). Before that fix, seed 42 had Kiran
    claim "My own reading pointed at them" of Agnes, whom the reading never named.
  - The "reports considered together" elimination reason is not a pairing, so it's untouched.
- **MindNomination._resolve_shared_reason** (Beadle's code; his rule, approved Nov 20): an own
  reading's status is the reading's own, not its partners'.
  - **Public** if they shared it, or it's on the board and the town knows it's theirs: the gift
    is claimed, or a meeting presentation cited it.
  - **Told to the Demonologist** likewise: told directly, or on the board with the gift claimed
    or a presentation to the Demonologist (any venue) citing it.
  - **Otherwise private**, and so still revealable, including a reading on the board only as an
    anonymous relay or rumour.
  - Before, one private partner card kept an already-shared reading "private", so the NPC
    "revealed" it again.

### Measured (40 passive games, seeds 1–40, 10 NPCs, the same main on each side)
| | main | rule only | filter + rule (this PR) |
|---|---|---|---|
| Accusations | 675 | 672 | 669 |
| Nominations (none without a reason, every side) | 395 | 392 | 387 |
| **Reveals of a reading not yet shared** | **3** | **3** | **3** |
| Re-reveals of a reading already shared | 16 | 0 | 0 |
| Accusations hinting at a private reason | 15 | 12 | 12 |
| Relayed readings | 8 | 8 | 8 |
| Accusations with no specific reason, or citing a public one | 359 | 391 | 387 |
| Defence decisions | 391 | 390 | 384 |
| Good wins | 16 | 18 | 18 |

New reveals hold level; only re-reveals of what the town already had go, all of that from the
classification rule (the filter alone adds nothing on reveals). No accusation, nomination or
defence is left without a reason it could give. Two games change winner, both to good:
- **Seed 27:** the same first two hangings (Hollis, a good Dowser, day 3; Kiran, a Demon, day 4).
  Main then hangs Nisha, a good Sexton, on day 5, and evil wins. With this PR the town hangs Lian
  (the Revenant) on day 5 and Agnes (the second Demon) on day 6, and good wins.
- **Seed 33:** Constance (the Revenant) on day 2 either way. Main then hangs Merrin, a good
  Gravedigger, on day 4, and evil wins. With this PR Merrin is spared, and the town hangs Edda
  (the Poisoner) on day 5 and Hollis (the Demon) on day 6, and good wins.

The first build dropped joint reasons the model hadn't weighed and showed reveals down 19 → 5.
Traced on seed 6, those "reveals" were of readings already shared and claimed, kept "private"
by one private partner card. Beadle set the rule above (his code), then refined it with a
presentation counting for its audience. The presentation suites check that.

### Golden
Re-baselined to `baseline_6836d21`, on main after #448 (the Night Watch wording). Two captures
were identical.
- 54875 hangs Edda a day earlier, then Greta (the Poisoner) on day 2 instead of Agnes on day 3.
- 692 no longer hangs Lian on day 3.
- Neither has a winner by day 4.
- 42 and 900 change only in what NPCs say. 98933 is identical.

See `docs/golden_baseline.md`.

### Tests
- **`test_joint_reasons`:**
  - in play, every joint reason (bar elimination) pairs only cards `weighed_together` accepts;
  - unit checks of the helper (a unit, the core and a counted case count; an uncounted case, or
    two items only summed side by side, don't; with no belief result, nothing is filtered).
- **Suites passing:** test_joint_reasons, test_meeting_reasons, test_nomination_case,
  test_meeting_flow, test_workshop_tuning_probe, test_workshop_regressions,
  test_social_credibility, test_defence_grounds, test_day_defence, test_relay_lie_attribution,
  test_dialogue_fixes_gossip_reasons, test_workshop_reasoning, test_workshop_presentation,
  test_presentation_contracts, test_workshop_nested_cases, test_workshop_votes, and the other
  reason-status suites.
