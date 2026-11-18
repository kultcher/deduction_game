# 2026-11-18, Claude-Lantern: premise centring, option B (`claude/premise-centre-b`; moves golden)

- **Base:** main `ab783c1`, with main `d2ffb20` merged in. **Status:** PR open, waiting its turn in the
  golden queue. **Next:** Bailiff (review). I re-baseline when its turn comes. That's after the
  joint-reasons fix, #216 and #232.
- **What (Michael, Nov 17-18, `docs/design/premise_centring.md`: option B, bystander share 1/3):**
  - A listener hearing "X is evil" weighs how far the case proves that. It under-registers what
    the case implies about everyone else.
  - Which cards count as "brought" reuses step 1's selection (`SharedLedger.brought_by_premise`).
    A card is brought while every owner of it is a presented case that argues someone's alignment.
  - A brought card's lean, and a stored case's cards taken together, count in full on the case's
    target and at a third on everyone else (`Connections.refresh` items, `Connections.cases`).
  - A card the listener holds any other way is never shaped: their own reading, hearsay, or the
    public record.
  - A brought card stays brought after its case fades (the lens stays).
- **New constant, decided by Michael:** `PREMISE_BYSTANDER_SHARE = 1/3` in `sim/tuning.gd`.
  `tuning_catalogue.md` is regenerated.
- **Measured** (`tools/measure_premise_frames.gd`, a constructed case on seed 692's 7-NPC deal; the
  person the cards point at starts at 41%):
  - **Presented as that person:** barely changes. Two Dowser readings 51% → 50%; sightings against
    an alibi 69% → 65%.
  - **Misframed** (presented as someone named in the cards, or someone unconnected): the right person
    gains much less. 51% → about 45%; 69% → about 50%.
  - The wrongly named person doesn't rise in any frame.
  - The presenter's trust is unchanged by a misframe (Michael: the case not landing is the cost).
- **Golden:** moves on all five seeds. Against `baseline_fdaccb0` (stale), the first changes are on
  day 1 or 2: listeners hearing a presented case shift the bystanders less. Re-measured from the
  current baseline at re-baseline time.
- **Tests:**
  - New `tools/test_premise_centring` (9 checks), added to the fast list. It covers the frames, the
    selection, and the lens after fading.
  - `test_premise_step1`'s two checks still pass with it on.
  - `test_connections_cases` checks case arithmetic on chosen numbers, so it runs with it off
    (`Connections.premise_centring = false`).
  - Fast list: 85 of 85 passed on `ab783c1`. Two captures were identical.
- **Docs:** `docs/belief_model.md`, "Premise centring, option B".
