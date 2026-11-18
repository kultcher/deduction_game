# The "too clean when an ally is involved" pass over every bluffer

- **Agent:** Claude-Beadle
- **Base:** main at 832bd17
- **Branch:** claude/beadle-too-clean
- **Status:** PR open, zero drift (golden identical to baseline_490cdcf at `--tol 0`)
- **Next actor:** Bailiff (review and merge). Michael, through Seneschal, for the three
  questions at the end.
- **BACKLOG item:** "One pass over every bluffer" (section 5), **[decided]**. Built as
  far as the guideline settles it; three tells left need a design call. BACKLOG isn't
  edited while Vicar restructures it.

## What changed

Every bluff rule (`generate_bluff_reading` in `sim/roles/*.gd`) was held to the Dowser's
#160 guideline: stay close to the truth, and let the situation set the room. The tell from
97626 was an ally covered at any cost: a clean result that was itself unlikely.

- **A bluffing Augur no longer gives the Demon a clean day in a crowd.** Before, a lying
  Augur whose street held the Demon (and not the scapegoat) always said "no Demon crossed
  my path". Now, if four or more other people were in public on that street with the
  Demon, it says the true "yes". Among that many, a yes points at nobody in particular,
  and a "no" is something the player can catch from their own sightings. With a smaller
  crowd it still covers the Demon, as the Dowser does for groups of two or three. The four
  is the Dowser guideline's "4+" row, named `DEMON_CROWD` in `sim/roles/augur.gd`.
- **A bluffing Psychologist no longer swears nobody lied on a day a fellow evil lied in its
  hearing**, when it has two good people's words to cast doubt on instead. Before, it
  swore it 40% of the time even then. It still does on days when no teammate lied, and
  when fewer than two good people spoke in its hearing.

## The audit

| Bluffer | Verdict | Why |
|---|---|---|
| Dowser | Fits (#160) | The guideline itself |
| Augur | **Fixed** | Covered the Demon at any cost |
| Psychologist | **Fixed** | "Nobody lied" on a day a teammate lied |
| Seer | Fits | "Neither is the Demon" is what most true pairs say. A cleared teammate is no stranger than a true no |
| Surveyor | Fits | A true "all on one side" is common (about 3 blocks in 10). Clearing a teammate's block is a single flip |
| Monitor | Fits | "Nobody walked" is ordinary, and the teammate it covers needn't have walked there |
| Night Watch | Fits | Leaves a walking teammate out of the names it lists: one name off the truth, within the guideline |
| Lamplighter | Fits | The true count ±1 |
| Magistrate | Fits | Yes/no on one pair: no room to be "close" except by not lying |
| Registrar | Fits | Backs a teammate's claim at 45%, otherwise harmless or framing |
| Archivist, Chronicler, Medium | Fits | Frame the scapegoat. No teammate is in scope |
| Hearthwitch | Not changed | Benched. Its rule already matches the Dowser's two-person row |
| **Clerk, Rumormonger, Martyr** | **Question 1** | Always pair or name a teammate |
| **Gravedigger, Executor** | **Question 2** | Always confirm a dead teammate's false claim |
| **Confessor** | **Question 3** | Vouches for a teammate 60% of the time |

## Questions for Michael (through Seneschal)

1. **The Clerk, Rumormonger and Martyr bluffs always involve a teammate.** A made-up Clerk
   reading always pairs a teammate with its claimed gift. A made-up Rumormonger reading
   always pairs a teammate with a harmless secret. A made-up Martyr always gives its life
   for a teammate. A true Clerk's other name is evil about 3 times in 10. A player who
   suspects one of these readings, and knows the pattern, can halve the field.
   The Executor already does the alternative: it names a teammate 35% of the time and a
   good person otherwise. The open question is what the other 65% should say:
   - (a) a good person's real gift, a harmless truth;
   - (b) a wrong gift for a good person, which can clash with that person's own claim later.
   I'd recommend (a) at the Executor's 35%. Not built: it's a new choice for those
   bluffers, not a tell in an existing one.
2. **A bluffing Gravedigger or Executor always confirms a hanged or dead teammate's false
   claim.** That's consistent, but a liar could sometimes buy trust by naming the dead
   teammate's true evil role: the teammate is already dead, so the cost is small. That
   would be a new kind of evil play, so it's your call. I'd leave it as it is for now.
3. **A bluffing Confessor vouches for a teammate 60% of the time.** That's a rate, not a
   tell in one reading, but it's the highest of any bluffer. Lowering it toward the Seer's
   40% (`SEER.bluff_clear_mate_prob`) would be a value change and mine to make. I've left
   it for you to weigh alongside question 1.

## Small calls made on Michael's behalf

- The Augur's crowd is everyone else in public on the bluffer's street, in a phase when the
  Demon was there. The size four follows the Dowser guideline's "4+" row. With a crowd that
  big it always tells the truth, as the Dowser's 4+ row never reads below the truth.
- The Psychologist counts only a teammate's statement that was false. A good person's
  misread doesn't count, because the liar can't know of it.

## Measured

- `tools/test_too_clean_bluffs.gd` (6 checks, new, on the fast list). Across 12 cases, the
  Demon among four others: the bluffing Augur said yes 12 times; among two others, 0 times.
  Across 40 cases, the Psychologist swore nobody lied 0 times after a teammate lied, and 17
  times when no teammate had. Both behaviours fail on main's code.
- Golden is identical to baseline_490cdcf: none of the five seeds deals an Augur or
  Psychologist bluff that reaches these branches.
- **In play:** 25 passive 10-NPC games, seeds 3000-3024, branch against main. (Main ran 30;
  the branch run stopped at 25 when the container restarted.)
  - **Augur:** no Augur bluffs were dealt in any of the 25 games, nor in main's 30. The fix
    is rare in play.
  - **Psychologist:** 4 of the 25 games changed, and none changed winner (13 evil, 12 good on
    both). In 3017 a bluffer that swore nobody lied, after a teammate had lied, now casts
    doubt on two good people's words. In 3001, 3008 and 3012 the change is a different
    random draw after the skipped roll, not a different rule. Made-up "nobody lied" readings
    numbered 6 on main and 7 on the branch: the rule catches only days a teammate lied in
    the bluffer's hearing, which is rare.

## Proposed for the backlog

None. The three questions belong to the existing item.
