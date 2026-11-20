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
