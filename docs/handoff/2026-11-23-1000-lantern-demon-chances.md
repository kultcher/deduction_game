# 2026-11-23, Claude-Lantern: per-person P(Demon) for the Seer (`claude/demon-chances`)

- **Base:** main `78e82991`.
- **Status:** PR open.
- **Next actor:** Beadle merges this into #549 and switches the Seer's ranking to it; Bailiff merges.
- **Golden:** identical to `baseline_14f5b7d` on all five seeds at `--tol 0`. Nothing in play calls it yet.

## What changed and why

Beadle's Seer (#549) ranks its pick by a person's chance of being the Demon. It was multiplying
`given_evil_of_npc` by suspicion, but suspicion is a lean from the NPC's baseline, clamped at 0, not
P(evil). So people at average suspicion dropped out of the ranking.
- **`OwnGiftDoubt.stage`** now also keeps the refresh's connections posterior: the NPC's own evil
  chance for each person, the number its beliefs come from. `WorkshopOwnership._stage_own_gift_doubt`
  passes `proposal.connections.posterior`.
- **`DemonCandidates.demon_chances_of_npc(n)`** returns {person id: P(Demon)}: that posterior times
  P(Demon | evil) from the joint judgement, scaled to sum to 1 over everyone but the NPC (there is one
  Demon).
  - **Why the scale:** the connections posterior is assembled from separate items, so the raw products
    can sum past 1 (1.27 in the suite's Seer case). The scale never changes the order.
  - **Cost:** it's lazy and cached per refresh, like `of_npc`. It returns {} when no refresh is staged
    or no one has a chance.

## What I measured

- **test_demon_candidates:** 11 checks pass. They cover:
  - {} with nothing staged;
  - the scaled product per person;
  - a sum of 1;
  - the order following the raw products.
- **Also pass:** test_shared_delusion, test_workshop_regressions, test_connections_core,
  test_self_doubt_poisoner and test_own_burden_knowledge.

## Proposed for the backlog

None.
