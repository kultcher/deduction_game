# Centring a case on its premise (design note)

**Status: decided (Michael, Nov 18): build option B at a bystander share of 1/3. Not built.**
Written Nov 17 by Claude-Vicar, at Michael's request through Seneschal, from Claude-Lantern's
measurements on `mock/premise-centre` (one commit on main `cee8811`; `mock/`, so it never
merges). BACKLOG item: "Centre a case on its premise (Michael, Nov 17)", section 2, Cases and
the Workshop, now `[decided]: B at a share of 1/3`, owner Lantern.

## Decision (Michael, Nov 18; relayed by Seneschal)

- **Build B** (section 2): a card a listener holds only because a case brought it counts in
  full on the case's subject and at a third on everyone else. The case's joint value is
  centred the same way, since B includes A. Cards held some other way count as usual.
- **The bystander share is 1/3.**
- **Lantern builds it,** reusing step 1's selection (`SharedLedger.premise_shaping`: a card
  is shaped while only presentations that argued an alignment premise brought it). A card
  under that rule stays shaped until the listener gets it some other way, which answers the
  "does the lens fade?" question as Vicar leaned (section 7). Lantern to confirm in the build.
- **Not taken:** A alone, C, and "doubt onto the subject" (section 4).
- **No extra trust cost for a misframed case** (Michael, Nov 18). The case not landing is
  the cost. A premise still costs trust only when the evidence argues *against* it, as today.
- **The night-0 sighting lift is probably a bug** (Michael, Nov 18). Lantern is investigating
  it as its own item (example 1 and section 7, item 4).

---

## 1. What Michael asked for

From his answer on "Say what a card is offered for" (Nov 17): when a case has a premise,
its effect should centre on the premise's subject. A case "Constance is evil" that cites a
vigil sighting contradicting her alibi should put its full weight on Constance, and scale
down whatever it moves onto the other people in that sighting.

### How a case moves people today (the connections model)

A presented case is weighed in three ways (`docs/belief_model.md`, "Stored cases"):

1. **Each card it brings** becomes held by the listener and counts alone, for everyone it
   names, from then on.
2. **What the cards say together,** beyond what each says alone (the case's joint value),
   scaled by trust in the presenter and fading by the day.
3. **Night cards** it brings (sightings, alibis, Night Watch reports, traces) join the
   listener's **movement connection,** which reads every night together.

After that, one common shift keeps the town's total in line with the number of evil. So when
the subject rises, everyone else falls a little. That's the "others cleared" effect, and it
isn't spillover.

### The goal, restated (Michael, Nov 17, after the first draft)

The night-sighting case already behaves as intended, so set it aside. The idea is **what's
in focus**:

- A listener hearing "Constance is evil" weighs how far the case proves *that*. They pay
  less attention to unnamed people it might also implicate, a less insightful listener
  especially.
- If the case actually points harder at someone else, the listener doesn't register the full
  weight against that person, because they're looking through the "Constance is evil" lens.
- **In gameplay terms:** the player mustn't win just by supplying information to the town.
  They have to make the right connections and present them that way.

### This was decided once before (Nov 5)

Michael's goal matches the Nov 5 premises decision almost word for word (`docs/premises_plan.md`,
"Decisions": "so the player can't present all the evidence under a wrong premise and let a
high-Insight listener solve the case").

- **Built Nov 6 as premises step 1:** a card that only presentations brought was "shaped".
  The premise's target took its full effect; everyone else took 40% (Insight 0) to 80%
  (Insight 1). It was remembered at every refresh.
- **Lost with the connections model:** the shaping never runs with connections on, so since
  Nov 16 nothing in play does it.
- **To be deleted in purge phase 5,** with Michael's approval. It's kept on BACKLOG
  section 6 as "Spillover damping" `[tentative]`, and the code survives on
  `archive/legacy-belief-final`.
- **Option B below is that same rule, rebuilt for the connections model.**

## 2. The options measured

All three use one new constant, the **bystander share**: the fraction of an effect that
reaches anyone other than the premise's subject. The constant was approved with the
decision. There's no centring without a premise, and a "suspicious" premise centres the
same way.

| | What it scales down for bystanders | In game terms |
|---|---|---|
| **A** | The case's joint value (2 above) | What the cards prove only *together* lands mostly on the subject. Each card still counts in full alone. |
| **B** | A, plus the cards the case brought (1 above) | A card the listener only holds because of this case counts mostly on the subject. Cards held some other way count as usual. |
| **C** | What the case's night cards add to the movement connection (3 above) | A sighting, alibi or trace the case brought weighs mostly on the subject when the listener reads the nights together. It applies only when every brought card in that night came from one subject's case. |

## 3. What the measurements show

**On:** 10 bot games (seeds 1–10, 10 NPCs, connections on), 318 presentations. A and B ran
at shares of 0.5 and 0.25. C ran at 0.5 only. The examples below come from seeds 1–6, at
0.5.

**Not measured:** passive games, the 7-NPC town, Hexer towns, and C at any share but 0.5.
Golden wasn't captured either. Lantern expects all three options to move it, since NPC
nominators' cases name a target and go through the same path.

### In aggregate: A and B change nothing

Across 318 presentations neither A nor B changed bystander movement in any measurable way.
Most of what bystanders move is the evil-count shift as the subject rises, and none of the
options touches that.

### The examples

**1. A true sighting reads partly as the sighter's lie** (seed 1)

- **The people:** Fenwick, the evil Poisoner, and Constance, the good Sexton.
- **The case** was against Fenwick and cited four cards:
  - Kiran saw Fenwick at the tavern on the evening of day 1;
  - Isolde was silenced that day;
  - Constance saw Fenwick on the Square from her window on night 0;
  - Fenwick says he was home on the Docks on night 0.
- **Day 1, Kiran:** the case lifted Fenwick from 34% to 89% (88% under C) and lowered
  Constance from 34% to 23%, the same under every option.
- **Day 2, Kiran's last refresh:**
  - Fenwick was already at 99% without the case, so he had no room to move.
  - Constance rose from 2% to 27% under today's rules, A and B, and to 8% under C.
- **Why Constance rises:** the movement model has the Demon never walking on night 0, and a
  Minion only about a quarter of the time. So "evil Fenwick out on night 0" is unlikely,
  and Constance's true sighting reads partly as her lie.

This is the one example where centring bites, and only C does it.

**2. A reading naming two people** (seed 5, Bartholomew, day 1)

- **The case** was against Odette, the Demon, and cited a Gravedigger-type reading: "one of
  Agnes and Odette is the Gravedigger".
- **Result:** Odette rose from 29% to 100%. Agnes, the good Gravedigger, fell from 34% to
  11% under today's rules and C, or about 17% under A and B.
- **Two reasons Agnes is cleared:**
  - The reading itself: with Odette evil, the reading says Agnes holds the gift.
  - The evil-count shift as Odette rises.
- **What the options do:** A and B soften Agnes's clearing by about a quarter. C leaves it,
  since the reading isn't a night card.

**3. A vigil naming others:** no change under any option. This is Michael's own example,
and the bystanders already barely move today.

**4. Two people claiming one gift:** none came up in these games.

### Reading the results

- **Michael's example (3) already behaves the way he wants.** The vigil's other names barely
  move today.
- **Where a case does move a bystander a lot, it's one of two kinds:**
  - **A logical consequence the player may not have argued (2).** Agnes really is cleared
    by that reading. Centring it means a listener half-ignores what the case's own card says.
  - **A contradiction (1),** where "the subject was out" and "the sighter lied" compete.
    Only C reaches it.
- **Part of example 1 isn't about centring at all.** "The Demon never walks on night 0" is
  why a true night-0 sighting looks like a lie. BACKLOG already has a related night-0 quirk
  in section 6 ("An evil Medium's relay about the first victim names night 0"). It may be
  worth a look on its own (Lantern).

## 4. Moving the doubt onto the subject

Lantern's view is that for centring to bite in contradiction cases, it needs more than C.
Inside the case's own judgement, when the subject's alibi and someone's sighting of the
subject clash, the subject's alibi would be the doubted side, not the sighter.

### How it would work

- The sighter contest (`DESIGN.md`, "Sighter contests") would be skipped for sightings of
  the subject inside that case's judgement, so the clash resolves onto the subject.
- It applies only inside the case. The same cards held outside the case are weighed as today.
- **Cost:** no extra judgement, since the case is judged anyway. No new constant if it's
  all-or-nothing; a partial version would reuse the bystander share.

### Against the guardrails

- **"NPCs mustn't out-deduce the player": it fits.** NPCs would draw fewer conclusions the
  player didn't argue. The cost is the other half of the original premise item, "the town
  can notice what the player missed". A listener who thinks "if Constance's sighting is
  wrong, maybe Constance is the liar" is reasoning the way a person would, and this switches
  that off inside the case.
- **"NPCs simulate a human mind" and "no sheep": it strains them.** Listeners would take the
  presenter's framing as the answer to who lied. Lantern's caveat says the same: it's a step
  toward taking the player's word. Trust in the presenter still scales the whole case, but
  inside it the framing decides.
- **"Every lie has a reason": the guardrail itself isn't broken.** It's about NPC lies being
  motivated and logged, and this creates no lie. But **it would make evil's invented
  sightings much stronger.** NPC nominators' cases name a target too. An evil sighter who
  invents a sighting and then nominates its victim would have that sighting go undoubted
  inside its own case. The sighter contest exists precisely to catch invented sightings,
  and this lets evil step around it. Limiting the rule to the player's cases avoids that,
  but it makes the player a special case.
- **Under the new vigil it matters less.** A vigil sighting is the player's own, so it isn't
  in a sighter contest at all. The rule only touches cases that cite NPCs' sightings.

## 5. Costs

| | New constant | Extra work | Golden |
|---|---|---|---|
| A | The bystander share (approved) | None | Expected to move (NPC nominators' cases), not measured |
| B | The same share | None; uses the record of which cards a case brought, which already exists | Expected to move |
| C | The same share | One extra movement judgement per night item per presentation. These are the expensive kind: roughly a few percent more refresh time on presentation days, not measured precisely (Argon to check if it's built) | Expected to move |
| Doubt onto the subject | None if all-or-nothing | None | Expected to move |

## 6. How well the model fits the goal, and what each option does for it

### Where the connections model already fits

- **Connections across kinds of evidence count only if the player makes them.** A reading, a
  sighting and a claim that mean more together get their joint value only when presented
  together as a case. A pile of scattered cards gets no joint value.
- **The town makes some connections itself, by design:** the built-in pairings (a night's
  movement cards, a trace with profiles, two claims of one gift), and each NPC's core (new
  cards weighed with its own firsthand readings). That's "the town can notice what the player
  missed", which is meant to stay.

### Where it doesn't fit

- **Every card the player hands over counts in full for everyone it names, whatever the
  premise.** A brought card becomes held and keeps its full single value after the case
  fades. So supplying information does much of the work without any connection being made.
- **The premise doesn't change how cards are weighed** (`docs/belief_model.md`: "the premise
  type changes what's asked, not how cards are weighed"). "Constance is evil", with cards that
  point at Dorian, moves Dorian as much as "Dorian is evil" would. That's the lens failure.
- **The measurements didn't test this.** The bot presents cases against its own top suspect,
  so its cases are well framed. "A and B changed nothing" holds for correctly framed cases
  only. It says nothing about misframed ones, which are the ones the goal is about.

### The options against the goal

| Option | What it does for the lens |
|---|---|
| C | Night cards only, which are set aside. Little. |
| A | What the cards prove only *together* lands mostly on the subject. It helps a little, but each card alone, which is most of a case's weight, still reaches the other person in full. |
| **B** (includes A) | Cards the listener holds only because this case brought them count mostly on the subject: "they saw it through the Constance lens". Cards already held, or heard another way, count as usual. **The closest fit.** |

## 7. Recommendation (Vicar, revised Nov 17)

1. **B, at a share to be set by the misframed-case test (section 8).** It is the Nov 5 rule
   on the new model, and the only option that makes the player connect evidence to the right
   person.
2. **Drop C,** since night sightings already behave as intended. Drop A on its own, since B
   includes it.
3. **Hold "doubt onto the subject"** (section 4), for the reasons given there.
4. **Look at the night-0 odds separately** (Lantern), as before.
5. **Before purge phase 5 deletes the step 1 shaping,** Lantern checks whether any of it
   (its tests, the brought-card bookkeeping) is worth reusing for B.

### What B raises

1. **Re-presenting.** Re-presented with "Dorian is evil", the same cards give Dorian full
   weight then. That's the desired behaviour: making the right connection. Cycling the
   premise across everyone would game it, but each try costs a presentation, and a clearly
   wrong premise costs a little trust (`PRESENTATION_WRONG_COST`). That cost's code is still
   on main; whether it still fires as intended under connections isn't checked.
2. **Whether the lens fades.** When the case fades, does a brought card stay scaled or return
   to full? Vicar's lean: it stays scaled until the card reaches that listener another way,
   the way the Nov 6 shaping was remembered at every refresh. They remember it in the light
   it was shown.
3. **Insight.** "Less insightful listeners are more lens-bound" is the old Insight-scaled
   share (40% to 80%). Start with one flat share. Scale it by Insight once Insight's role
   settles (Option A, Lantern measuring).
4. **NPC nominators' cases centre the same way.** That seems right: a listener hearing
   "Greta is evil" sees the cards through Greta too.
5. **"Suspicious" premises:** they centre on their subject like the others (as the BACKLOG
   item already says).

## 8. The test requested (Nov 17)

Constructed misframed cases, with fixtures, no bot games:

- Take a strong case against X and present it three ways: as "X is evil"; as "Y is evil",
  where Y is an innocent named in the cards; and as "Z is evil", where Z is unconnected.
- Measure how far X still rises, and how far Y and Z move, under today's rules, A and B, at
  shares of 0.5 and 0.25.
- Cover the kinds of evidence most cases are built from: a reading naming two people, a
  sighting against an alibi, and a mixed case.
- Report in game terms, side by side.
- Requested from Lantern through Seneschal. `mock/premise-centre` already has A and B.

## 9. For Michael to decide

All answered Nov 18 (see "Decision" at the top): B; a share of 1/3; the lens stays (through
step 1's selection rule); "doubt onto the subject" not taken; no extra trust cost for a
misframed case; the night-0 lift goes to Lantern as a probable bug.
