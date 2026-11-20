# Graded gossip: value tiers and their measurement

**Claude-Quill, Nov 20.** Base: main at 6cdafd17. Status: ready for review. Next actor: Beadle
(review, then their budget PR on top), then Bailiff. Zero drift. **The tier definition is a
draft awaiting Michael** (sent to Seneschal, Nov 20).

## What changed and why

BACKLOG "Graded gossip" (Michael, Nov 19; owner Beadle, with Quill on the value tiers). Beadle
and I split it on Nov 20: I tag each tavern gossip item with a value tier and measure, and
Beadle wires the budget into the selection (draw `TAVERN_TIER1_TARGET` 2 and `TIER2_TARGET` 1
first, then fill by weight). That PR moves golden and lands after this one.

- **`Social.gossip_tier(cand)`:** one helper with the rule. **Draft:**
  - **Tier 1** is something the player can file or check: an anonymous reading, or a night
    sighting with a block and a night.
  - **Tier 2** is useful but softer: a gift claim in circulation, a gift-family hint about a
    named person, or a secret about a named person.
  - **Tier 3** is colour: daytime sightings, haunts and town relationships.
- **`Social.tavern_evening_gossip`** tags every candidate (`"tier"`) before the selection, and
  logs the tiers told and offered in its `tavern_evening_gossip` dev-log entry. The selection
  doesn't read the tier yet.
- **New `tools/measure_gossip_tiers.gd`.** It reads what each evening's tavern would tell in
  played games, using passive play and the tavern's own seeded draw, so it changes nothing.
  It counts tiers told and offered against the targets.
- **New `tools/test_gossip_tiers.gd`** (fast list): the rule, and that a played evening logs
  a tier per item.

## Measured (40 games, 10 NPCs, seeds 1–40, 168 evenings, passive play)

| | Tier 1 | Tier 2 | Tier 3 |
|---|---|---|---|
| Told per evening | 0.46 | 0.62 | 2.9 |
| Offered per evening | 4.6 | 6.4 | 37.6 |

Sampled the way the player's tavern visit sees it: after the evening's own conversations and
before the meeting's testimony (the tool was corrected for both on Codex's review).

- **The targets are met rarely:** the tier-1 target (2) on 10% of evenings, the tier-2 target
  (1) on 46%, and both on 4%.
- **But the offer usually has enough:** counting one item per group, on about 89% of evenings
  it holds two tier-1 items, and on about 84% enough for both targets.
- **In game terms:** today a tavern evening seldom gives the player two things they can act
  on. It isn't for lack of news; the haunts and town relationships far outnumber it and win
  the weighted draw. Beadle's budget should lift "both targets met" from about 4% of evenings
  toward the roughly 84% where the offer allows it.
- **Not measured:** an active player, who changes what the town talks about, and the 7-person
  town.
- **Golden:** identical to `baseline_9fa5a74`. Suites: test_gossip_tiers and test_town_vibe
  pass.

## Proposed for the backlog

None.
