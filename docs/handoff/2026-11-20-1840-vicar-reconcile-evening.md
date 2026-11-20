# Vicar: evening backlog reconcile, and in-progress marks in the contents list

- **Agent:** Claude-Vicar
- **Base:** main (after #441, #442)
- **Status:** docs only
- **Next actor:** Bailiff

## What changed and why

Michael asked, through Seneschal, for a full reconcile against main (Nov 20).

**Closed** (moved to BACKLOG_COMPLETED.md, "Built or dropped, Nov 20, evening"):
- **NPC defenders weigh secrets the game can't deal:** fixed, Lantern #432 (Lantern
  confirmed). Section 1 now has no open items.
- **The spoken reply to a later-day repeat:** built, Quill #428.
- **A Medium's relayed sighting vs the dead's known vantage (12a):** Michael dropped it, on
  Quill's measurement. No design note held it.

**Updated:**
- **Minion gifts: the Poisoner's visit (12b):**
  - Michael's rule: a candidate is someone spotted whose destination was on the failed
    reader's block, not anyone whose route passed it;
  - Quill is applying it to the filter from #429;
  - the fuller factor waits for after this round;
  - tagged `[decided]`.
- **Argon's audit, file splits:**
  - Tier 1 is done (#404, #417, #426, #433);
  - Tier 2 is under way (#438, #439 done). Beadle's `social.gd` split comes after #431 and
    #437, and Lantern's `live_activity` and `case_eval` after the joint-reasons PR.
- **New UI item, accepted by Michael (Nov 20):** "Movement wording: 'pass by' and 'road'".
  - the Night Watch card's "pass by" is reworded (Herald drafts, Michael approves);
  - no voiced line says "road".

  Owner Herald.

**The contents list now marks in-progress items with `\*`** (Michael's rule: a lead is
building it, or its PR is open). Marked from the open PRs and the leads' answers:

| Item | Why |
|---|---|
| Evil Martyr bluff | Beadle #412 |
| Argon's audit: cleanup | Tier 2 splits under way |
| Accusations from starting suspicion | Beadle, `mock/beadle-silence` A/B (no PR yet) |
| The Gravedigger in a reluctant town | Beadle #413 |
| Rapport and Warden-credit leftovers | Beadle #409 |
| Explicit night-sighting rebuttals | #415 |
| Graded gossip | #431, #437 |
| Minion gifts: the Poisoner's visit | Quill, applying the destination rule |
| A reason citing a pairing the model didn't weigh | Lantern, `claude/joint-reasons-combined` |

Beadle, Lantern and Quill have answered. When Herald answers, the marks are updated in a
follow-up file.

- **Not tied to an open item:** #414 (case slate lie calls) and Limner's #282 (line boil).
  I've asked Quill which item #414 is for.

## Checked

Each closure's merge is on origin/main: #432 (136c197e), #428 (6cdafd17), #429 (389a3a51).
Docs only.
