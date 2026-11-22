# The Augur rework (design note)

**Status: direction from Michael (Nov 21–22, 2026). Held, not shared yet; nothing is built.**
Written by Claude-Vicar.

## Why

The current Augur (did I cross paths with the Demon on my block this morning, and this
afternoon?) has two problems:
- **It's swingy:** a small crowd almost names the Demon, and a big one is noise.
- **Its fiction clashes:** the player has to reconstruct who the Augur passed, though the Augur
  would know.

## The rework

**Text (Michael, Nov 22):**
> Each night, learns how close they came to evil that day.
> Hot: the Demon was at the same building as them. The Demon also learns this.
> Warm: the Demon was on their block, or a Minion was at the same building.
> Cold: Neither.

- **When it reads:** the Augur's first free part of each day (Michael, Nov 22), so it can read
  at different places rather than always at work. A day with no free hours gives no reading.
- **Marked** applies as a false Hot or Warm, as the Demon would (Michael).
- **What the Demon learns:**
  - **on Hot,** that an Augur got a Hot on it today. It doesn't learn who, or which part of the
    day, so it suspects the people it shared a building with during the morning and afternoon;
  - **on Warm or Cold,** nothing. The Demon alone learns this; Minions don't (Michael).
- **Evil's play:** if the Demon can work out who the Augur is, the Augur becomes its first target
  (Michael). Not knowing which part of the day triggered it makes that harder. If the Augur
  turns out too safe, adjust.

## Measured (Vicar, Nov 22)

The sample: 19 passive 10-NPC games, seeds 1 and 100–117, with every good NPC treated as the
Augur on every day. It's an upper bound on information: perfect knowledge of who was where, no
Marked, and a Demon that doesn't avoid the Augur.

| Reading | Whole morning and afternoon | First free part of the day |
|---|---|---|
| **Hot** | 26%; points at 2.6, clears 4.9 | 22%; points at 2.0, clears 5.6 |
| **Warm** | 39%; clears about 0 | 32%; clears about 0 |
| **Cold** | 35%; clears 2.4 | 46%; clears 1.9 |

The first free part of the day gave no reading 38 times, when the Augur stayed home.

- **Warm works:** because a Minion in the building can cause it, it clears almost nobody.
- **Cold is modest.**
- **Hot is still common and sharp.** With one part of the day, it's a little rarer (22%, about
  one day in five) but sharper: about two people. The Augur saw everyone in its building, so
  its list has no gaps. Its counterweight is the danger: the Demon learns of it, and the Augur
  becomes its first target.
- **Including the evening** made Hot more common (42%), so the evening stays out.

## Open

1. **When the Demon learns of a Hot.** If it learns that same night, it can kill the Augur before
   it speaks, and the best reading is lost unless a Medium recovers it. If it learns in time for
   the following night, the Augur always gets one day to speak. Vicar recommends the latter.
2. **Whether Hot is still too strong** once the Demon reacts. To check in play. The fallbacks:
   Hot needs at least three others in the building, or the reading is single use.
3. **Who builds it:** Lantern (the judge needs where the Demon was in each world, by building, for
   that part of the day), Beadle (the Augur's movement, and the Demon's targeting and avoidance),
   Herald (the text).
