# Beadle: a bluffer's frame memory

- **Base:** main `3d1bbea`. **Status:** ready for review. **Next actor:** Bailiff.
- **The item:** BACKLOG "A bluffer's frame memory" (triage 6; Michael, Nov 17: yes, scaled by
  Insight and/or Confidence; one or two new constants approved).

## What changed
- **The memory** (`npc.bluff_frame`, `Evil._remember_frame`): each made-up reading a bluffer
  tells adds the people it implicated, under the scapegoat of the time. A new scapegoat
  starts it afresh, so the memory drops when the team switches.
- **The choice** (`Evil._keep_frame`, before the fabrication check): a fresh made-up reading
  that would clear anyone in the memory drifts from the story. The bluffer keeps its story
  with chance `FRAME_MEMORY_BASE` + `FRAME_MEMORY_TRAITS` x the mean of its Insight and
  Confidence, telling instead one of the bluff rule's other readings that clears none of them
  (if there is one). Otherwise it tells the fresh one. Both outcomes are logged ("plan").
- **New constants** (approved, draft numbers): `FRAME_MEMORY_BASE = 0.2`,
  `FRAME_MEMORY_TRAITS = 0.7`. A dull, unsure liar keeps its story about 1 time in 5; a sharp,
  sure one about 9 in 10. `tuning_catalogue.md` regenerated.

## What it does in play
- 30 passive 10-NPC games (seeds 3000-3029): a bluffer was about to drift twice, in one game,
  and kept its story both times. It rarely comes up, because a drifting reading needs the
  same bluffer, the same scapegoat and a clear of someone it implicated.
- Not measured: whether kept stories change votes.

## Checks
- `tools/test_frame_memory.gd`, 7 checks: in 60 draws, a sharp, sure liar kept its story 56
  times and a dull, unsure one 15; nothing binds after a scapegoat switch; a non-drifting
  reading is told as it is; the memory holds whom readings implicated, not whom they cleared.
- **Golden:** zero drift. Two captures identical to each other and to `baseline_44073d9`. (A
  first version tagged each reading with the scapegoat, which golden saw on every record;
  the memory is now its own field.)
- **Suites run:** test_frame_memory, test_evil_play, test_fabrication_check,
  test_evil_owned_lie, test_gift_doubt, test_relay_bluff.

## Next
- The second half of bluff consistency: one pass over every bluffer for the "too clean when an
  ally is involved" tell (BACKLOG [decided]).

Claude-Beadle
