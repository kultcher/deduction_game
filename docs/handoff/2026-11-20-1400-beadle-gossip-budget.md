# Graded gossip: the tavern's tier budget

- **Agent:** Claude-Beadle
- **Base:** Quill's `claude/gossip-tiers` (#431), with main at 9f8a5ab merged in (`baseline_7005cc6`)
- **Status:** PR open, stacked on #431. Merge after #431.
- **Next actor:** Bailiff.

## What changed and why

BACKLOG §3, "Graded gossip" (Michael, Nov 19): each gossip occasion has a budget of mixed-value items, so the player usually gets at least two useful pieces. Quill built the value tiers (#431). This PR adds the budget.

- **The constants (approved Nov 19):** `TAVERN_TIER1_TARGET` = 2 and `TAVERN_TIER2_TARGET` = 1, both in `Tuning.Social`.
- **The tavern draws its budget first.** In `Social.tavern_evening_gossip`, before the ordinary draw:
  - up to 2 unheard tier-1 items, drawn by weight within the tier;
  - then up to 1 unheard tier-2 item.

  The ordinary weighted draw then fills the rest of the evening's 3 to 5 items, as before. What the offer lacks, it fills with whatever there is.
- **The draw is shared.** The draw loop moved, unchanged, into `Social._tavern_draw`, which both the budget and the fill use.
- **The measure tool** reads the two constants instead of hard-coding 2 and 1.

## Small calls made on Michael's behalf

- **Only unheard items count toward the budget.** An item the player already heard isn't news, so the budget never spends a slot on it.
- **One item per conversation still holds.** A shared reading, the gift claim it put in circulation and the hint it gave stay one "group", as before. So a reading and its claim can't fill two budget slots from one exchange.
- **Order:** the budget's picks are shuffled in with the rest, so the useful items don't always come first.

## Measured

`tools/measure_gossip_tiers.gd` (Quill's tool, at the evening before the meeting's testimony), 40 passive games, 10 NPCs, seeds 1–40. Before = #431, after = this branch:

MEASURE_TABLE

- **Golden:** identical to `baseline_7005cc6` at `--tol 0` on all five seeds. The golden games never visit the tavern, so no re-baseline.
- **Suites:** 29 pass:
  - test_gossip_tiers, test_town_vibe, test_buildings_tavern_town_hall, test_meeting_gossip, test_haunt_learning, test_tuning_hoist, test_state_digest;
  - and 22 more that touch the tavern: board, control flow, dialogue, evidence cards, evil play, hint cards, meeting flow, NPC chatter and interactions, social, the town UI and the UI, the workshop regressions and others.
- **Not measured:** an active player, and the 7-NPC town.

## Proposed for the backlog

None.
