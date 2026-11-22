# Playtest 51795: NPC journeys (Claude-Coroner)

A companion to `51795.md`. It follows four good townsfolk through the game: whom they
suspected and why, how they saw you, and how they voted and judged the one case presented.
I replayed the log at its build (`ac3ec83`).
- **Where the "why" comes from:** at each meeting I took one thing a mind had heard out at
  a time, and measured how far its suspicions moved.
- **Votes:** from the log's own vote breakdowns.
- **Caveat:** Fenwick's blank double claim (bugs since fixed) shapes some of what follows.

| | Gift | Friends | Rivals |
|---|---|---|---|
| **Kiran** | Gravedigger | Isolde, Jory (the Demon) | Merrin |
| **Isolde** | Medium | Odette, Kiran, Jory | Fenwick, Merrin, Dorian |
| **Odette** | Rumormonger | Isolde, Merrin, Edda, Jory | none |
| **Dorian** | Clerk | Nisha | Isolde, Merrin, Edda |

## The findings first

1. **Trying to hang someone who knows he's good doesn't make him suspect you (Lantern,
   design question).**
   - **What happened:** Odette accused Kiran on all three days and nominated him on day 2.
     By day 3, Kiran's suspicion of her was **0.00**.
   - **Where it went instead:** her pushes don't enter what he weighs as evidence at all.
     They show up only as trust: his trust in Odette is **0.0**, the floor.
   - **What cleared her:** Jory's fake Dowser count ("0 evil among Odette, Fenwick, Lian").
     So total distrust sits beside zero suspicion.
   - **Why it matters:** a person who knows he's innocent would find a persistent accuser
     suspicious. Worth deciding whether "they keep trying to hang me, and I know I'm good"
     should count as evidence about the accuser.
2. **A suspected reader's readings still clear people (Lantern).**
   - **Kiran:** he suspected Jory 0.52 on day 3, yet Jory's day-1 Dowser count was still
     what cleared Odette for him (about −0.15).
   - **Odette:** that count kept Fenwick, the Poisoner, at 0.00 for her (−0.25).
   - **Dorian:** it pulled Fenwick down by 0.11–0.17.
   - **Is it reasoning?** Partly. If Jory is honest, they're clear, and Kiran gave Jory about
     even odds. But the Demon's one fake reading did a lot of clearing for his teammate.
3. **Friendship doesn't reach the vote: Isolde came within 0.03 of voting to hang Kiran on
   day 2 (Beadle).**
   - **Her side of it:** she trusts Kiran at 0.95. Moments earlier she'd said "I've known
     Kiran long enough. I don't believe it of them."
   - **Her suspicion of him:** 0.18. That's the baseline for someone she can't clear,
     driven by nothing she'd heard.
   - **What nearly carried it:** town pressure (+0.20) and your yes vote (+0.07) brought her
     to 0.46 against the 0.49 she needed.
   - **The gap:** nothing in the vote looks at friendship or trust. A friend she'd just
     defended was one push from her rope.
4. **Excess equilibrium: Dorian's suspicion of Fenwick held at 0.23–0.29 for all three
   days (Lantern).**
   - **The two sides:** the two Archivist claims held it up (+0.18 to +0.25 each, every
     day), and Jory's clearing count held it down (−0.11 to −0.17).
   - **What didn't move it:** Kiran's reading proving Merrin was the Scion didn't loosen the
     clash for Dorian, though Dorian trusted Kiran fully (suspicion 0.00). By contrast, the
     clash stopped weighing on Fenwick for Kiran and Isolde from day 2.
   - **Why it's still worth a look:** Fenwick really was evil, so Dorian ended up right. But
     a rival proven evil leaves the clash no lighter for one mind and gone for the others.
5. **Odette's grief never softened (Beadle, question).**
   - **What happened:** her trust in you fell from 0.48 to 0.32 when you voted to hang her
     friend Merrin, and stayed exactly 0.32 for the rest of the game.
   - **What didn't touch it:** "the Demonologist was proven right about Merrin" (+0.12 for
     Isolde and Dorian) never reached her, because she disbelieves Kiran's reading. And
     Kiran's "time softens past slights" has no equivalent for grief.
   - **The question:** if grief is meant to fade, it doesn't.

Working as intended, but strong: Odette's loyalty to Merrin.
- **The cost:** it turned Kiran's Gravedigger reading ("Merrin was the Scion") into
  evidence against Kiran (+0.12 to +0.14, every day). With other pieces, her suspicion of
  him reached about 0.55, and she nominated him.
- **What broke it:** Isolde's Medium reading on day 3, Edda's confession that Kiran's heart
  was pure. That took her down 0.34 at once.

A wrong belief held for a human reason, and a big but fitting swing when it broke.

## Kiran (Gravedigger)

**Suspicion:**
- **Day 1:** Merrin 0.53, from the two Archivist claims (+0.20 each) and her own reading
  naming him as a possible Scion (+0.16). Odette 0.17, Fenwick 0.17. He nominated Merrin
  (0.83 at the nomination).
- **Day 2:** Merrin is dead and his reading confirmed her as the Scion. Jory rose to 0.22,
  since Jory's Dowser count didn't fit what Kiran knew (+0.13). Odette eased to 0.10.
- **Day 3:** Jory 0.52. Odette 0.00 and Fenwick 0.10, both cleared by Jory's readings
  (findings 1 and 2).

**How he saw you:**
- **Rapport:** 0.41 to 0.33 when you voted to hang him on day 2. Back to 0.35 ("time
  softens"), then 0.39 when you spared him on day 3.
- **Credibility:** the highest in town, 0.50 to 0.69 to 0.79. Your votes matched what he
  knew, even while you voted against him.
- **Rapport and credibility pulling apart is right here.**

**Votes and the case:**
- **Votes:** yes on Merrin; no on Fenwick, Jory (day 2) and Nisha; yes on Jory (day 3).
- **Gravedigger pull:** his role adds a small "gravedigger wants a hanging" pull (+0.08) to
  every vote, including on people he didn't suspect.
- **Your case on Jory:** he was already there: "I already had my money down on that read of
  Jory". The log calls his stance "reject" for nothing new, but his scoped stance is accept.
  That's working as intended; the label just reads oddly.

## Isolde (Medium)

**Suspicion:**
- **Day 1:** Merrin 0.40 and Fenwick 0.25, both from the clash, and Odette 0.14 from
  Odette's own reading.
- **Day 2:** Kiran 0.21, Nisha 0.18, Jory 0.17. Her friend Kiran sat highest on baseline
  alone (finding 3).
- **Day 3:** Jory 0.44 and Fenwick 0.20. The Jory number isn't explained by any single
  thing she'd heard; it's built from several reports, each redundant on its own. Kiran
  0.00.

**How she saw you:**
- **Rapport:** 0.47 to 0.59 ("proven right about Merrin"), then 0.63 after a civil talk.
- **Credibility:** 0.61, then down to 0.57 on day 3. Your day-2 yes on Kiran clashed with
  what she knew.

**Votes and the case:**
- **Votes:** yes on Merrin and on Jory (day 3). No on the rest, including Kiran, by 0.03 on
  day 2.
- **Your case:** she accepted it ("it changes how I see Jory").
- **Burdens:** Lian, her Unrequited admirer, gave his life over for her as the Martyr. That
  showed up only in her odd "Lian's readings agree" line, since fixed.

## Odette (Rumormonger)

**Suspicion:**
- **Day 1:** Kiran 0.31–0.34, but almost none of it traces to anything she'd heard (+0.04
  from Dorian's reading). Most likely it's Merrin's private word to her ("one of Kiran and
  Nisha is the Scion"), which didn't show up among her tested items. Merrin 0.24 by the
  meeting's end. She accused Kiran.
- **Day 2:** Kiran about 0.55: his Gravedigger reading counted against him, plus Jory's
  count. Nisha 0.26. She nominated Kiran and voted yes on Nisha.
- **Day 3:** Kiran 0.26 after Isolde's Medium reading, Jory 0.22, Fenwick 0.00 throughout.

**How she saw you:**
- **Rapport:** 0.48 to 0.32 (grief over Merrin), then flat (finding 5).
- **Credibility:** 0.51 to 0.55, slow, because your claims kept disagreeing with what she
  believed.

**Votes and the case:**
- **Votes:**
  - no on Merrin, by a narrow margin, even as her best friend;
  - yes on Kiran on day 2, with resentment +0.16 because Kiran nominated Merrin;
  - yes on Nisha;
  - yes on Jory on day 3;
  - yes on Kiran on day 3.
- **Your case:** she accepted it, but it barely moved her: Jory went from 0.22 to 0.23.

## Dorian (Clerk)

**Suspicion:**
- **Day 1:** Merrin 0.45 and Fenwick 0.24 from the clash. His own Clerk reading kept
  Isolde near 0. He voted yes on Merrin by 0.05.
- **Day 2:** Jory 0.28 (Jory's Dowser count, and the clash) and Fenwick 0.11. He spoke
  against Jory.
- **Day 3:** Jory 0.52 and Fenwick 0.29 (finding 4). Kiran 0.00: the clash, Isolde's Medium
  reading and Kiran's own claim all cleared him.

**How he saw you:**
- **Rapport:** 0.40 to 0.44 (civil talk), 0.56 (proven right), then 0.60 when you spared
  him.
- **Credibility:** steady at 0.62–0.63.

**Votes and the case:**
- **Votes:** yes on Merrin and on Jory (day 3); no on the rest.
- **Your case:** "I'd already talked myself into that same worry." That's a partial stance,
  and the case added little, as it should when he was already there.

## What wasn't checked

- **The other good townsfolk:** Nisha, Lian and Edda.
- **The evil minds.**
- **Moments between meetings:** only the meetings were sampled.
- **Pieces that only work together:** taking items out one at a time can't see a suspicion
  built from several pieces that each make the others redundant. That's Isolde's day-3
  Jory, and Odette's day-1 Kiran.
- **The log's phase snapshots:** they sometimes differ from what NPCs used at the next
  meeting (Odette's Kiran was 0.60 in the evening snapshot and 0.25 at her day-3 vote). I
  took the meeting and vote values. Private conversations in between may explain the gap;
  I didn't trace them.

*The probes ran in a scratch worktree and aren't committed.*
