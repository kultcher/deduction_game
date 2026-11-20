# Burdens feasibility: combined summary (Nov 20)

**Status: Seneschal's summary of the five feasibility reports, committed by Claude-Vicar
(Nov 20). The 24 questions at the end are answered: Michael, Nov 20, in [burdens.md](burdens.md)
section 9.** Argon's detail is in
[burdens_perf_feasibility.md](burdens_perf_feasibility.md).

Sources: Lantern (judge and belief model), Quill (evidence and the Workshop), Beadle (NPC
behaviour and evil), Herald (UI and dialogue), Argon (#468, performance). All read-only;
nothing has been measured.

## Bottom line

- **Feasible on existing machinery.** No lead found a blocker.
- **Faster.** The judge considers ~2,900 possible worlds instead of ~15,000 in a 10-NPC town,
  so belief updates and presented cases should be ~20–40% quicker (Argon).
- **Seed 100002 is solved world by world.** One burden per script means a "Delusional" reading
  rules out Sleepwalker worlds, so #459's patch retires.
- **Biggest single risk: Marked.** It becomes known to its holder but still makes others'
  readings call them evil. How the judge handles an unclaimed Marked person is question 1.
- **Rough size:**
  - Lantern: ~1 week for the core world-domain change in C# (the riskiest part), plus medium
    pieces.
  - Quill: 1–1.5 weeks.
  - Beadle: 5–7 PRs.
  - Herald: ~4 days of UI plus ~200 voice lines (Michael's wording).

  Every reference game moves; re-baseline per stage.

## Suggested first prototype (on `mock/burdens-slot`)

**The burden slot plus Marked (known), with the Lovers and Sleepwalker 1.0 retired.**
- Lantern builds the slot world domain (Delusional hidden; Marked known plus its allowance).
- Beadle builds Marked's tiered disclosure, the "carried the mark since birth" defence, evil's
  lazy Marked bluff, and the counter-claim.
- Argon measures speed and caching.

Then paired sweeps against main. Ill-Omened, Unrequited and Sleepwalker 2.0 follow.

## Per-lead headlines

- **Lantern:**
  - A world carries the burden slot: which listed burden is in play, plus a holder only if
    hidden. That's ~10 choices per evil team, against 42 today. Connections needs no
    structural change.
  - Unrequited is a walker reason with its destination at the beloved's block (small).
    Ill-Omened is a world-dependent night factor like the Poisoner's (medium). Sleepwalker 2.0
    fits worlds properly (medium).
- **Quill:**
  - The Rumormonger maps as is. Known burden claims reuse `secret_claim` cards. A new "drink"
    honest cause for Ill-Omened.
  - "Holds a secret" stays a premise only for the hidden burden; known burdens are handled
    through claims.
  - The Test juror gets the general allowance and per-burden slate entries.
- **Beadle:**
  - The errand and confession paths carry Unrequited.
  - Marked gets a second disclosure track and a defence move.
  - Ill-Omened claims at nomination and feeds a general "hanging cost" vote term.
  - Evil gets a separate burden-bluff slot, chosen lazily at the moment of need.
  - Costs: retiring the Lovers and Sleepwalker 1.0 (~140 sim sites, ~45 test files), and
    Unrequited's withholding across ~6 sharing paths.
- **Herald:**
  - Script sheet, cards, Workshop and grimoire changes are small and fit the existing secret
    machinery.
  - ~12–14 new voice keys (~200 lines), drafting one voice per key first.
- **Argon:**
  - World count down 5.25×; 12-NPC towns fit.
  - Three cache-key hazards to wire up front: the dynamic allowance, Marked claims on reading
    units, and the Ill-Omened night.
  - Arguing an unclaimed known burden (burdens.md §4.9) would double the judge's cost for that
    case.

## Questions for Michael

**The judge**
1. **Marked, unclaimed:** enumerate possible holders (exact, ~7 worlds per team), or a
   per-person allowance? Lantern recommends the allowance. Quill warns that with the allowance
   only, an unclaimed Marked named by a reading looks like a lie by the reader.
2. **Does the town reason about which known burden is in play,** so that a true Rumormonger
   "Marked" rules out Unrequited? Lantern says yes.
3. **Is the ~10% allowance per person,** or per oddity explained?
4. **Can a script have no burden in play,** which would need a "none" world?

**Ill-Omened**

5. **Drunk readings:** false, random or merely unreliable? Next night only? Learned only
   through contradictions?
6. **Do drunk readers know?** If unaware, a bluffed Ill-Omened hanged gives no drunk night, and
   nobody can tell. Is that intended?
7. **Timing:** does a claim made earlier under pressure count, or must it be restated at the
   nomination?
8. **Evil's vote:** should evil push to hang a real claimed Ill-Omened (a tell), or play as its
   good self?
9. **The cost of a hanging:** one general vote term fed by the claim? Beadle and the note say
   yes. How heavily against a strong case?
10. **The player:** does Ill-Omened affect the player's night actions? Should the board mark
    the drunk night?

**Unrequited**

11. **Does a reading or card name the beloved?**
12. **Evil's Unrequited bluff** needs a beloved whose home fits the sighting. Beadle says yes.
13. **Withholding:** only evidence implicating the beloved, or also evidence clearing rivals?
    Is it the same lie severity as gift withholding?
14. **The reveal's trust cost:** good listeners only? Its size is a new constant.

**Marked**

15. **The private 40% share:** to the player as readily as to a friend?

**Evil's burden bluffs**

16. **"Bolder with silence":** from day 1 or from the first meeting? A cap? It needs two new
    constants.
17. **May one evil NPC bluff both a gift and a burden?** Beadle assumes yes.

**Sleepwalker 2.0**

18. **Does she see nothing while walking,** and honestly say "I was home"?
19. **Does "I've been known to sleepwalk" survive?** If not, the excuse is evil-only.

**UI**

20. **The hidden tag:** plain "(hidden)", or an explaining line?
21. **Show burden claims on the sheet,** as for gifts? Herald says yes.
22. **The Workshop's "private errand":** becomes "explained by a burden", or retires?

**Wording**

23. **The "Burden" tooltip draft:** "Burden: something that weighs on a townsperson, on top of
    their gift. The script lists the possible burdens and how many are in play. A hidden
    burden's holder doesn't know they carry it."
24. **Later:** the "drink" Mistaken cause, the Rumormonger phrases and the ~200 voice lines.

## Addendum: Lantern (Nov 20, through Seneschal)

1. **Question 2, sharpened: where the known burden sits in a world.**
   - **Argon's "none" placement:** 7 + 1 = 8 choices per team, about 2,880 worlds.
   - **Lantern's per-known-kind placement:** 7 + 3 = 10 per team, about 3,600 worlds.
   - **Why it matters:** with per-kind placement, a true Rumormonger or Chronicler reading of a
     known burden ("one of A, B is Unrequited") can rule out "it's Marked" world by world,
     instead of only through the allowance.
   - **Lantern's view:** both work, and Argon's is about 20% cheaper. Lantern would accept
     "none" unless Michael wants readings of known burdens to be decisive.
2. **An unclaimed Marked, under the allowance:**
   - P(a reading calls X evil | X good) = a × P(it reads Marked as evil) + (1 − a) × the normal
     false-positive rate.
   - A claimed Marked X registers evil only in worlds where X is good.
3. **The allowance formula:**
   - a = P(a known burden is in play) / (goods not ruled out). That's about 0.75 / 7 ≈ 0.11 per
     person in the 10-NPC town, which matches Michael's ~10%.
   - Each other burden claim multiplies it by (1 − 0.3 × trust in the claimant).
   - A Rumormonger or Chronicler reading raises a inside the named pair and lowers it outside,
     never to zero.
   - a is quantized for caching.
4. **Ill-Omened:**
   - It's an independent failure cause: P(sound) = (1 − p_poison)(1 − d)(1 − p_delusional),
     where d applies only in worlds where the hanged claimant was good.
   - A self-doubt on a drunk night carries the Ill-Omened cause, so #455's Poisoner nudge skips
     it.
5. **Argon's three cache hazards, confirmed, with additions:**
   - the allowance also enters CaseEval's key;
   - a Marked claim arriving after a reading queues a refresh;
   - the Ill-Omened night is keyed on (night, claimant).

   Sleepwalker 2.0 adds a new multi-block path kind for its holder.

### Vicar's note: how this meets Michael's answers ([burdens.md](burdens.md) section 9)

The addendum and Michael's answers were written in parallel. Two places need the leads to
reconcile them:
- **Point 1:** Michael answered Q2 "yes, the town reasons about which known burden is in
  play". That reads as wanting readings of known burdens to count world by world, which points
  to Lantern's per-kind placement (about 3,600 worlds) over "none". Worth confirming with him
  in one line.
- **Points 2 and 3:** Michael answered Q1 "enumerate" for an unclaimed Marked. So point 2's
  allowance form no longer applies to Marked: Marked is placed in the worlds like the hidden
  burden. The allowance in point 3 would then cover only the known burdens that aren't
  enumerated. Lantern should confirm how much of point 3 still applies.

## Lantern's revised numbers, after Michael's answers (Nov 20, through Seneschal)

These replace the addendum's points 1 to 3 where they differ, and settle the Vicar's note above.
- **The allowance now covers only the Unrequited's night walks.** It's per person (1/g, about
  1 in 7) inside worlds where Unrequited is in play, and zero elsewhere. So Q3 resolves to
  per person, Unrequited only.
- **Worlds per evil team:** 2g + 2. That's g for Delusional (hidden), g for Marked
  (enumerated), plus 1 each for Unrequited and Ill-Omened. Each known burden has its own
  place, so a reading of a known burden counts world by world, as Michael's Q2 answer wants.
  - 10 NPCs: 16 per team, 5,760 worlds against 15,120 today, about 2.6× fewer.
  - 7 NPCs: 504 against 1,050.
- **Speed:** a smaller gain than Argon's 20–40%, roughly 10–25% by Lantern's guess. Argon
  should re-estimate with Marked enumerated.
- **Ill-Omened** reuses the Poisoner's reading-failure path. **Unrequited's bluff** fits the
  walker-reason path, with the beloved's block, or the graveyard once the beloved is dead.
