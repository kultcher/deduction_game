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

## Why the town settled on Jory early (Michael's follow-up)

**Two things did it: a real contradiction in his readings, then elimination when Nisha
died.**

**Jory's three Dowser counts**, all fabricated, though one happened to be true:
- "0 evil among Odette, Fenwick, Lian": **false**, because Fenwick is evil. It clears
  Odette and Lian, who were good.
- "1 evil among Odette, Kiran, Isolde, Dorian": **false**, because all four are good.
- "0 evil among Odette and Lian": **true**.

**Day 2: a contradiction (Dorian and Kiran).**
- **The chain:** the Archivist clash made Fenwick likely evil. Jory's first count put
  Fenwick in a group with no evil in it. So, in their minds, the count was wrong and Jory
  was lying or poisoned.
- **Dorian:** reached 0.27 on Jory. Taking away Jory's readings, or the two Archivist
  claims, each halves it.
- **Kiran:** reached 0.21. Jory's readings add +0.11 and Dorian's Clerk reading +0.08. The
  Clerk reading backs Isolde's Medium claim, which narrows who the day-2 "1 evil among
  four" could be.
- **Isolde and Odette:** stayed low (0.15 and 0.02).

**Night 2: elimination.**
- **The jump:** all four rose at once, with nothing new said: Kiran 0.21 to 0.42, Isolde
  0.15 to 0.39, Dorian 0.27 to 0.41, Odette 0.02 to 0.22.
- **What caused it:** the Demon killed Nisha. She'd been a top suspect for several of them
  (Isolde 0.34, Odette 0.41, Dorian 0.20, Kiran 0.18). With her out of the pool, her share
  went to whoever nothing had cleared.
- **Why that was Jory:** almost everyone else was cleared by someone's reading or a
  confirmed claim:
  - Isolde and Dorian by their matching Medium and Clerk;
  - Kiran by Edda's confession;
  - Lian by the Martyr reading;
  - Odette and Fenwick by Jory's own counts.

  Nobody's reading cleared Jory. His fake clears, by clearing everyone else, left himself
  as what remained.
- **What I ruled out:** the stored lean from the day before barely moved it. Clearing it
  changes these numbers by 0.00–0.07. Removing the death items or Nisha's claim doesn't
  move it either. The death works by taking her out of the pool of candidates, not as
  something heard.

**Day 3:** the meeting added about 0.10 more for Kiran and Dorian (his third count). The
town went in with Jory as everyone's top suspect except Odette's.

This fits the pillars: explainable in hindsight, and reached by reasoning a player could
follow (contradiction, then elimination). Being as sure as Kiran or Dorian (about 0.5) by
day 3, roughly when you were, isn't out-deducing the player. It's worth watching whether
elimination after a demon kill is often this sharp.

## What drove the town toward Nisha (Michael's follow-up)

Nisha (the Chronicler) peaked at the end of day 2:

| | Day 1 | End of day 2 |
|---|---|---|
| Odette | 0.14 | **0.41** |
| Isolde | 0.02 | **0.34** |
| Dorian | 0.04 | 0.20 |
| Kiran | 0.10 | 0.18 |

Three things raised her and two lowered her. Figures come from taking whole groups of what
each mind had heard out, at the start and end of day 2.

**What raised her:**
1. **Elimination, driven by the Demon's counts.** Jory's Dowser counts cleared Odette,
   Fenwick and Lian, and never included Nisha. With those three cleared, more of the
   remaining evil fell on the people left uncleared, and she was one.
   - **The size:** Jory's readings add +0.11 to Isolde's suspicion of her, +0.14 to
     Odette's, and +0.08 to Dorian's.
   - **Isolde's case:** much of hers sits outside what she heard in public. Jory told her his
     first count in private on day 2, which cleared three people for her. With them gone,
     Nisha was her top suspect.
2. **Merrin's pair.** Merrin's fake Archivist reading was "one of Kiran and Nisha is the
   Scion".
   - **For most:** it was discredited by the double claim and then by Kiran's Gravedigger
     reading, so it added little (+0.07 for Isolde at the end of day 2).
   - **For Odette:** she believed Merrin, so Kiran and Nisha were her pair. She ended on
     Kiran 0.47 and Nisha 0.41, everyone else near zero. Merrin also told her privately on
     day 1.
3. **Her late claim.** Nisha claimed Chronicler only when pressed on her nomination, late on
   day 2.
   - **For most:** it nudged her up slightly (+0.02 to +0.03).
   - **For Odette:** it added +0.15. A claim made under pressure fits a Scion bluffing, and
     that's how Odette's pair read it.

**What lowered her:**
- **The double claim and Kiran's Gravedigger reading.** Both discredited Merrin's reading,
  which cleared Nisha by 0.05 to 0.18 depending on the mind.
- **Odette's Rumormonger reading ("one of Nisha and Lian is Unrequited").** It cut her
  suspicion for Isolde, Dorian, Kiran and Edda (−0.06 to −0.12 on day 1).
  - **Why:** being named in a reading about a Burden reads as being an ordinary townsperson
    with a secret, not as evil.
  - **The contrast:** that's the opposite of your thought that the reading might be cover.
    No NPC weighed that possibility.
  - **The exception:** Lian knew he was the Unrequited himself. For him the reading said
    nothing about Nisha.

**The town didn't count Jory nominating her.** Accusations and nominations aren't evidence
in the belief model, but his readings were, and they did the work.

**The outcome:** she died that night, which is what then moved the town onto Jory (above).

**A method note.** The probes take out only what a mind has *heard*. They can't remove:
- **its own readings and anything told to it privately:** those are kept separately, which
  is likely where Merrin's private tip to Odette sits;
- **the lean it carries over from the day before.**

So "nothing heard moves it" can still mean its own knowledge, a private telling, or
elimination is doing the work.

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
