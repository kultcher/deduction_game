# Bluffers blend in or disrupt, by evil type

- **Agent:** Claude-Beadle
- **Base:** main at 9943120. It re-baselines on main once #249 lands.
- **Branch:** claude/beadle-bluff-blend
- **Status:** PR open. It moves golden and re-baselines in the PR, behind #249 in the golden
  queue.
- **Next actor:** Bailiff (review and merge). Michael, through Seneschal, for one question at
  the end.
- **BACKLOG item:** the follow-up to "One pass over every bluffer" (#264), built to Michael's
  Nov 18 answers. BACKLOG isn't edited while Vicar restructures it.

## What changed

Michael's rule: a Demon or Scion wants to pass as one more honest gift, so it leans toward
blending in; a Minion leans toward disruption, unless it is badly exposed. The lean is 65/35,
from the approved `Tuning.Evil.BLUFF_BLEND_PROB = 0.35`.

| Bluffer | Before | Now |
|---|---|---|
| Rumormonger | Always pairs a teammate with a harmless secret | About a third of the time, names two good townsfolk as possibly Delusional; otherwise as before |
| Clerk | Always vouches for a teammate | A Demon or Scion, about a third of the time, turns its first-night reading into a "confirmation" of the earliest good public claimer, if the reading is still untold that morning. Its timing is unchanged: nothing waits for a claim, and a reading already told stays the cover. A Minion always covers |
| Martyr | Always gives its life for a teammate | Gives it for the good soul under the most public heat, the likeliest to hang. If they hang, it says they must have been evil (the reading a true Martyr gets when its chosen hangs and it lives) |
| Gravedigger | A hanged teammate: always confirms its false claim | A Demon or Scion names the teammate's true role about two times in three on its first reading, and about one in three after. A Minion does so about one in three, or two in three when badly exposed. A hanged good soul: blending confirms their claim; disruption keeps the old frame roll |
| Executor | A dead teammate: always confirms its false claim | The same rule; its one result is always its first |
| Confessor | Vouches for a teammate 60% of the time | A Minion vouches for its Demon. A Demon or Scion vouches for the good soul the town trusts most, about two times in three, or else for a teammate. Never the same soul twice |

**Badly exposed** uses the existing test, exposure beyond caution (`Evil.exposure` against
`Evil.caution`), so it adds no new number.

## Small calls made on Michael's behalf

- **One shared rate:** the approved 35/65 split is the lean for every bluffer here, not only
  the Clerk. The Rumormonger's two-good reading and the Gravedigger, Executor and Confessor's
  less-favoured choice all use `BLUFF_BLEND_PROB`. It can be split later if they should differ.
- **When the Clerk blends:** it confirms the earliest good public claimer. It's checked each
  morning (`Evil.blend_clerk_readings`, from `plan_daily_frame`). The reveal lists the
  reworked reading as the one told.
- **Who the Martyr chooses:** the hottest good soul, by public heat, with nobody excluded.
  That is often the scapegoat.
- **The Confessor's "nobody twice"** is new, because it reads every night: vouching for the
  same soul night after night would be a tell.
- **Wording for the reveal (drafts for Michael):**
  - Rumormonger: "implied that A or B, both good, might be Delusional, to cast doubt on their
    gifts"
  - Clerk: "confirmed A's early claim to be the R, to pass as an honest Clerk"
  - Martyr: "chose A, a good soul under suspicion, to cast doubt on them should they hang";
    "said A, hanged and good, must have been evil, since its made-up Martyr gift didn't take
    them"
  - Gravedigger and Executor: "named their hanged fellow evil A as the R, to pass as an honest
    Gravedigger"; "read the hanged A as the R, to pass as an honest Gravedigger"; "named A, a
    dead fellow evil, as the R, to pass as an honest Executor"
  - Confessor: "cleared A, its Demon, as good"; "vouched for A, a good soul the town trusts,
    to pass as an honest Confessor"

## Question for Michael

**The fabrication check holds back most honest-looking Gravedigger readings about a hanged
teammate.** Naming the teammate's true role narrows the field, so a neutral listener's
suspicion of the teller, or of a living teammate, rises by 0.12 to 0.74. A liar who notices
(more likely the sharper it is) holds the reading back a day.

In the probe, all four readings that named a hanged teammate's true role were held back.
The cover is held often too: on main, 3 of the 4 covers were held. Across every made-up
Gravedigger reading, main held 5 of 11 and this branch 6 of 11.

Should a deliberate blend skip the check, since the liar chose that cost? I'd leave it as it
is. A sharp liar not outing a teammate when the field is small is realistic, and a careless
one still slips.

## Measured

- **New suite:** `tools/test_bluff_blend.gd`, 17 checks, on the fast list.
  - Rumormonger: 26 of 80 two-good-Delusional.
  - Clerk: a Demon blended in 19 of 60 deals, a Minion in 0. An untold reading is reworked;
    a told one isn't.
  - Martyr: chooses the hottest good soul, and the "they were evil" reading follows the
    hanging.
  - Gravedigger, a hanged teammate's true role: a Minion 16 of 60, the Demon 37 of 60.
  - Confessor: a Minion vouches for its Demon, not twice running; the Demon vouches for a
    good soul 27 of 40 times.
- **In play:** 25 passive 10-NPC games, seeds 3000-3024, on main 9943120 and on this branch.
  12 games changed.
  - **Winners:** main 13 evil and 12 good; here 11 evil and 14 good.
    - **3011 (evil to good):** a Minion Gravedigger's frame of a hanged good soul as the
      Scion was told on main (it slipped the check) and held back here, after earlier draws
      shifted.
    - **3015 (evil to good):** it starts at a Rumormonger reading that named two good souls
      as Delusional.

| Choice, made-up readings | Main | Here |
|---|---|---|
| Rumormonger covers a teammate | 5 | 4 |
| Rumormonger: two good souls as Delusional | 0 | 1 |
| Clerk covers a teammate | 8 | 8 |
| Clerk confirms an early good claimer | 0 | 0 (two Scion Clerks were dealt, each blends 35%) |
| Martyr chooses a teammate | 1 | 0 |
| Martyr chooses a good soul under heat | 0 | 1 |
| Gravedigger covers a hanged teammate | 4 (3 held back) | 2 |
| Gravedigger names a hanged teammate's true role | 0 | 4 (all held back) |
| Gravedigger frames a hanged good soul | 4 (2 held back) | 3 (1 held back) |
| Gravedigger confirms a hanged good soul's claim | 3 | 2 (1 held back) |
| Confessor, Executor | not dealt | not dealt |

- **Golden:** moves on four of the five seeds, from record 0 (the night-0 rolls shift). Two
  captures were identical. Outcomes and the re-baseline are in the PR.

## Proposed for the backlog

None.
