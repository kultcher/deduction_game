# Evil's Unrequited bluff: only a beloved the judge would believe

- **Agent:** Claude-Beadle
- **Base:** main at `b3c5cf62` (`baseline_14f5b7d`)
- **Branch:** `claude/beadle-unrequited-fit`
- **Status:** PR open. Golden unmoved (all five seeds identical at `--tol 0`).
- **Next actor:** Bailiff (review and merge).
- **Item:** Michael, Nov 23, via Seneschal: "evil shouldn't try to bluff Unrequited in a way that
  creates that kind of obvious contradiction." Use the judge's own fit check, as a general rule.

## What changed

- **`Burdens.evil_unrequited_bluff`:** the beloved evil names must fit that night by the
  judge's visit rule (`workshop/cs/LiveActivity.cs` `ComputeUnrequitedProfiles`):
  - the walk runs from home to the beloved's block;
  - it runs to Chapel Hill if the beloved was dead by that night, counted as the judge's
    timeline counts it (`workshop/live_history.gd`): a Demon's victim was alive the night
    they died, and a hanged soul was dead by that evening;
  - a beloved who shares the bluffer's home gives no walk at all, so fits no sighting.
- **Every block evil could be seen on that night must lie on that walk.** That means the
  sighting it's shown, plus where it really went (`history`), since another witness may have
  seen that. With no one who fits, evil uses another excuse or none.
- **The confession's wording follows the same night** (Codex on #548): the grave line only
  if the beloved was dead by the night it answers for.
- **The pick is now a pure function,** `Burdens.unrequited_bluff_beloved`, so it can be
  tested and probed without side effects.
- **No new constant.** The draw that decides whether evil bluffs at all is unchanged.

The old check differed from the judge in three ways:
- it looked only at the sighting shown, so a Demon seen leaving home on a kill night could
  name a love anywhere;
- it allowed a beloved who shares the bluffer's home;
- it used "dead now" rather than "dead by that night" for the grave.

## Measured

- **Real sightings of evil, old rule against new.** A local probe checked every night
  sighting of a living evil NPC that some townsperson held, in 42 passive 10-NPC games
  (seeds 9200–9241). There were 74 such sightings.

  | | Old rule | New rule |
  |---|---|---|
  | Sightings evil could answer with an Unrequited bluff | 73 of 74 | 70 of 74 |
  | Of those, the named beloved contradicts the judge | 29 | 0 |

  So evil can still make the bluff about as often. What changes is whom it names: about two
  old bluffs in five named someone the judge would see through, and now none does. The usual
  case was a Demon or Poisoner seen leaving home while it really went elsewhere: it named a
  love on its own block, or on a third block, instead of one on the block it went to.
  The probe measures when the bluff is available. Whether evil takes it is the unchanged
  reactive draw, and it fires only when the player shows evil a sighting in private.
- **Quill's slate:** unchanged, so no slate re-baseline. `unrequited_bluff` is still Damning on all 10 deals (strength 21.46) and `unrequited_walk` still Contradicts (0.53), the same as `docs/case_slate/baseline.md`. The slate builds its cards by hand, so an NPC change can't move it. Michael accepted the Damning grade standing.
- **Tests:** `test_burden_unrequited` gains 7 checks: the true destination, a third block, a
  housemate, the victim's door and grave by night, and (Codex on #548) the door line, not
  the grave, for a night the beloved was still alive. It and `test_burden_unrequited_walk`
  pass.
- **Golden:** identical to `baseline_14f5b7d` on all five seeds at `--tol 0`. The bluff fires only when the player shows evil a sighting in private, which the golden bot never does, so there's no re-baseline. Seneschal expected golden to move; it doesn't.

## Proposed for the backlog

None.
