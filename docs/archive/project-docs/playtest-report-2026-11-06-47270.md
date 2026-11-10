# Playtest 47270 (2026-11-06): evil bluffing, dialogue and social notes

ChatGPT driving through computer use. 10 townsfolk, dynamic script #502083, `main` at
`d51b133` (before premises 0b and the Codex game fixes). The town hanged Odette (the
Demon) on Day 3 off the player's vigil and filed case. Claude-Bailiff's read of the log.

**Grimoire:**
- Evil: Odette is the Demon, bluffing Night Watch. Bartholomew is the Poisoner, bluffing
  Lamplighter. Kiran is the Breathstealer, bluffing Rumormonger. The scapegoat is Edda.
- Good: Greta (Registrar), Edda (Confessor, Delusional), Dorian (Dowser), Merrin (Medium),
  Jory (Clerk), Lian (Sexton), Hollis (Archivist).

## Evil bluffing

1. **Odette's Night Watch story changes between the meeting and the podium (bug).** Her
   prepared reports said she watched the Square on nights 1 and 2. The daily planter
   (`Evil`, the scapegoat frame) rewrote the unshared reports to the murder blocks: Chapel
   Hill, then the Docks, "I saw Edda pass by". It didn't update
   `evil_plan.fake_watch[night]`, which still read "square". At the meeting she said she
   watched the Docks last night. Pressed at the podium on the same night, she said "Keeping
   watch over the Square" (`NightWatch.night_duty_alibi` reads `fake_watch`). Fix: the
   rewrite sets `plan["fake_watch"][str(nd)] = death_block` too.
2. **The rewrite puts the Demon on watch at both murder blocks** (design). The frame
   says the same person passed both killings, and its teller is the one person who was
   "there" both times. It also happens to be where Odette really went, so it explains a
   sighting of her, but it's a strong tell. Consider not rewriting a Demon's watch onto
   the death block, or only for one night.
3. **Before claiming, Odette's private story contradicted the bluff she was about to
   make** (design). On Day 3 she told the player "at home all last night, saw nobody".
   Shown the player's vigil card (seen on the Docks), she doubled down on "home". An hour
   later at the meeting she claimed Night Watch and said she watched the Docks that night,
   without owning the earlier account. An evil member holding a prepared watch report for
   a night should refuse ("my business") rather than claim home, as the honest Sexton
   does. If they claim later, they should own the change, as Edda did ("whatever I said
   earlier").
4. **Working as designed, but the log reads oddly:** Kiran spoke against his teammate
   Bartholomew ("never sat right with me"). The log says "Keeps cover on support: stay
   quiet rather than speak against teammate". "Keeps cover" means he did what his good self
   would do, and the label names the option he passed up. Kiran and Odette then voted yes
   on Bartholomew while Odette was on the block (5 of the 7 needed): an attempt to move the
   block off the Demon.
5. **Fine:**
   - Bartholomew's Lamplighter counts (1, 2, 5 against true 0, 2, 4) are plausible fakes.
   - Kiran's Rumormonger bluff, "one of Merrin and Odette is Marked", pre-emptively covers
     the Demon.

## Good-side behaviour and dialogue

6. **Lian accused Bartholomew, then spoke for him in the same meeting** (Day 2). The
   accusation had a 0.21 chance and was generic ("I back Jory's read"). The supporter line
   had a 0.06 chance, as Bartholomew's friend ("I don't believe it of them"). The
   supporter step (`sim/mind_support.gd`) should skip, for the "for" side, anyone who
   publicly accused the nominee at this meeting, and vice versa.
7. **Wrong stem when shown a sighting of yourself.** Odette's reply to the vigil card
   opened with "My eyesight is regrettably sharp, and wishing I'd seen someone else won't
   make me squint" (`doubted_visual`). That stem defends the NPC's own sighting. The card
   was a sighting of her.
8. **Kiran's case recap repeats one sentence:** "Odette saw them out at night where
   someone was killed; and Odette saw them out at night where someone was killed". These
   are two readings on two nights, so each needs its night.
9. **Merrin's Medium relay is in the third person about herself:** "they sensed 0 evil
   among Merrin and Lian". It should be "among me and Lian".
10. **Greta:** "The night before you arrived, My register lists three roles". The capital
    M comes from `registrar.gd`'s text being spliced after the time stem.
11. **Bartholomew** answered `ask night` with "My whereabouts are my business. Leave it."
    and then "Saw nobody." A refusal shouldn't then report a sighting.
12. **Hollis's hint:** "I hold an additional evidentiary ground implicating Bartholomew".
    He hadn't stated a first ground, so "additional" reads oddly.
13. **Fine:**
    - Edda (Confessor) said "home" and then owned the outing when shown the vigil.
    - Jory's relay of the Archivist reading was legitimate. Hollis told Jory on Day 1, even
      though he later asked the player to keep it quiet.
    - Merrin's "I voted to hang Odette: they claimed to stay home…" is the M2d swing-voter
      line, and accurate.

## Social dynamics and how evidence moved suspicion

**Trust with the player stayed small and sensible.** No one went above 0.56.
- Civil chats and gift shares: +0.03 each.
- Lian: -0.02 for a wrong gift guess, then +0.02 twice for presentations that supported
  their argument.
- Edda: -0.05 for being pressed with evidence, -0.08 when the player voted yes on Odette's
  baseless nomination of her, then +0.03 overnight.
- Odette: -0.15 when the player nominated her.
- NPC grudges after nominations all point the right way: Bartholomew against Greta and
  Hollis, Edda against Odette and Kiran.

**Irregularities in the evidence:**

14. **Bartholomew contradicted his own bluff in one conversation (evil bug).** On Day 2
    evening at the tavern he told Greta his Lamplighter count ("walking the lamps, I
    counted 1 other out"). In the same conversation he said "I stayed home on the Market
    on night 1". A Lamplighter walks every night. Greta caught it: her suspicion of him
    went from 0.15 to 0.61, and she nominated him. She was killed that night. Evil's
    private whereabouts lie needs to respect its own claimed bluff: a walking bluff
    claims the duty, it doesn't say "home". This is the same family as item 3.
15. **The town's top suspect on Day 3 was Lian, the good Sexton.** Lian was top for
    Edda (0.42), Hollis (0.42) and Jory (0.32). The chain:
    - Hollis's Archivist pair says Lian or Bartholomew is the Poisoner.
    - Bartholomew's public Lamplighter claim explains his night outings. Edda saw him out
      on the Market on the night Greta died, and still had him at only 0.13.
    - So the pair resolves toward Lian. She can't answer, because a Sexton keeps the toll
      quiet while the bell holds.
    - Lian also spoke for Bartholomew on Day 2 (item 6).

    The reasoning is coherent, but the walker bluff still carries a lot even after
    PR #74's evidence honesty fixes. Add this game to Tally's walker-bluff checks.
16. **One private card moved Lian a lot, and the `--why` replay says it was sound.** The
    player showed Lian the vigil card that saw Odette and Lian on the Docks the night Greta
    died.
    - The snapshot's suspicion scale moved Odette 0.28 → 0.64 and Bartholomew 0.26 → 0.58,
      and put Kiran, Merrin and Hollis at 0. That scale is relative and floored, so 0 means
      below her average, not cleared.
    - The real posteriors at the Odette vote (Michael's `replay_log --why`): P(evil) for
      Bartholomew 0.95, Odette 0.89, Edda 0.49, Kiran 0.34. P(Demon) for Odette 0.79,
      Edda 0.20, Kiran 0.00.
    - Kiran's P(Demon) near zero follows from the vigil. Only Odette and Lian were seen
      arriving on the Docks, and Lian knows it was her. Edda keeps 0.20 because Odette's
      public Night Watch claim put her on the Docks that night.
    - **Not an irregularity.**

    Other notes from the replay:
    - **The frame on Edda worked.** Hollis had Edda's P(Demon) at 0.70 and Merrin at 0.74,
      both from Odette's Night Watch claims. The player's case still carried the vote.
    - **Greta had Bartholomew at P(evil) 0.92** after his contradictory account (item 14).
    - **Jory's top P(evil) was Lian at 0.70**, the Archivist-pair chain in item 15.
    - **The replay diverges at seq 97.** That was a testimony step, with Hollis's hint
      line. The log is from `d51b133`, and main has changed since (premises 0b and the Codex
      fixes). All five votes still matched.

## Suggested order

- **Small fixes:** items 1, 6, 7, 8 and 10.
- **Evil strategy, so measure with an A/B:**
  - Item 2.
  - Items 3 and 14 together: evil's private whereabouts must fit its own bluff.
- **Wording:** items 9, 11 and 12.
- **For Tally:** the walker-bluff check (15).
