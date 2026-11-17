# Centring a case on its premise (design note)

**Status: for Michael to decide. Measured on a mock; nothing built.** Written Nov 17 by
Claude-Vicar, at Michael's request through Seneschal, from Claude-Lantern's measurements on
`mock/premise-centre` (one commit on main `cee8811`; `mock/`, so it never merges).
BACKLOG item: "Centre a case on its premise (Michael, Nov 17)", section 2, Cases and the
Workshop, `[decided]: centre on the premise, A or B to be chosen after measurement`,
owner Lantern.

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

## 6. Recommendation (Vicar)

1. **Build C at a share of 0.5, and drop A and B.** A and B changed nothing in aggregate. The
   one place they act (example 2) is a real logical consequence, and centring it means a
   listener half-ignores what the case's own card proves. C is the only option that touches
   the contradiction case, and it does so only for night cards, where the "who else was out"
   spillover lives. Measure C at a second share before settling the value; 0.25 is the
   natural pair.
2. **Hold "doubt onto the subject".** It goes furthest toward taking the player's word, and
   through NPC nominators' cases it would blunt the sighter contest against evil's invented
   sightings. Revisit only if playtests show C isn't enough, and then consider it for the
   player's cases alone.
3. **Look at the night-0 odds separately** (Lantern). They're part of why example 1
   happens at all, and they also cause the "evil Medium's relay names night 0" bug in BACKLOG
   section 6.
4. **Or close the item as satisfied** if Michael's own example (3) was the main concern: it
   already behaves as he wants, and C is a refinement for contradiction cases.

## 7. For Michael to decide

1. A, B, C, or none (Vicar's recommendation: C).
2. The share: 0.5 to start, with C measured at 0.25 too.
3. "Doubt onto the subject": hold, build for every case, or build for the player's cases only.
4. Whether Lantern looks at the night-0 movement odds as a separate item.

The builder would be Lantern, with Argon checking C's cost if it's built.
