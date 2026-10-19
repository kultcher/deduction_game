# Demonologist backlog

The single to-do list. It gathers the deferred and open items from DESIGN.md, the
role_exploration On Deck list, the Project notes and playtests 13473/55774. Items are
sorted by effort. DESIGN.md stays the record of how things work and why.
Tags: **[decided]** = direction agreed, ready to build; **[open]** = path not chosen yet;
**[watch]** = no change, keep an eye on it; **[knob]** = not planned, a balancing tool to
reach for only if needed. Source in parentheses where useful. Exploratory mechanics
(new roles, places, ideas still being shaped) live in role_exploration.md.

---

## 1. Bugs and quick fixes (hours, low risk)

All cleared in the Oct 18 pass (see DESIGN, "Quick-fix pass, Oct 18"). New ones go here.

## 2. Small features and tuning (a day or so each)

### Deduction types and templates
- *Built Oct 18:* Martyr facts in templates, the Martyr who doesn't die, pair with both
  proven good, Misread (Marked, red herring), suspicious, hiding a secret, secrets and
  evil roles as conclusions, builder headings.
- **Template generalization** (one translation table per role, so pair elimination
  etc. work for any gift that makes the same kind of statement). (DESIGN, deferred to
  roster expansion) [decided]

### NPC behaviour
- **NPCs push back on nominations their own information contradicts** (a player-led
  nomination of the true Seer passed 7/8). (DESIGN playtests) [open]
- **Lie severity:** a false gift report weighs more than a whereabouts lie, unless the
  lie puts them near the crime. NPCs who accept a lie but won't hang should say so.
  (DESIGN) [open]
- **An open Warden: "I saw X out while I stood guard"** (filed; may be too strong).
  [open]
- **Evil reads as evil:** evil casting aspersions with no information stands out; give
  good NPCs reasons (grudges, secrets) or make evil hold back. (playtest 30294) [open]

### Numbers
- Day limit by town size: settled, kept as is (6 days for 7 townsfolk, 8 for 10).
- **"Maybe" conclusions:** half the persuasion and half the trust consequences, if
  committed conclusions turn out too punishing. If used: "maybe" can't support further
  deductions or be cited in accuse/defend. [knob]
- **Unlimited Vigil strength.** (DESIGN open question) [watch]
- **Situational credence modifiers** still to settle: early disclosure, quiet night
  as a credence boost, admission against interest, consistency over time,
  role-specific confirmations. (DESIGN) [open]
- **Initial general skepticism:** a lever to pull only if the early game gets too
  decisive. [knob]
- **"No gift" denials** (C.ALLOW_NO_GIFT_DENIAL, off since Oct 18): evil almost never
  bluffed it, so a denial was near-proof of good at the cost of the gift. [knob]
- **Vigil deterrent** (-0.25 on targets living on the watched block (C.VIGIL_DETER)) and **offer trust**
  (+0.03 offer, +0.06 kept, -0.15 broken): first guesses, tune from play. [watch]

### UI
- **"Stayed home" vs "none of your business"** on the sightings/claims boards. [watch]
- **From Playtest Notes 12553**, still unclear or unchecked: pin cards to the main
  view; people who aren't talking or working showing on the map; a wrong role guess
  blocking process of elimination. (Done: "I agree with X", "from my window", home on
  "was home" cards, pressure in the debug view, combined and excluding filters
  "greta+night" / "-sighting", clicking a timeline cell again clears it.)
- **Case-board card rows with mixed formatting** (bold kind, each name in its colour):
  the lists are Godot Trees, one colour per row; true rich rows need a custom-drawn or
  RichText list. [decided, later]

## 3. Medium features (several days; touch a few systems)

- **Rebuttals and excuses.** Someone accused explains with their gift ("I was out
  because I'm the Lamplighter"; see also "NPCs know their own lies" above), which buys some grace with listeners; evil without a
  fitting bluff can claim a fake secret. Biggest open hole: hidden night walkers frame
  themselves (Isolde 55774; Lamplighter/Veteran/Sleepwalker hang rates). (DESIGN)
  [decided: next social pass]
- **Nominations make a case.** The nominator cites several cards, even weak ones.
  Mostly flavour; it only moves NPCs if it brings new information. [decided]
- **Meeting and vote talk** (returns with the rebuttal work). Votes are silent for now;
  PR #3's vote explanations were removed. When vote talk comes back: evil voters must
  draw from the same spread of reasons as good ones (in PR #3 they all said "the case is
  strong enough"), and only lines that tell you something should be spoken (a reason
  that differs from the crowd, a vote against a stated stance, a swing vote). [decided]
- **Talking to a group:** 3 questions per phase, split among anyone at the spot.
  [open; discussed 2026-10-18]
- **Revenant seeks execution** (draws suspicion on purpose) and **NPCs search for
  totems.** Today the Revenant is often invisible (55774). [decided]
- **NPCs find evidence and personal items** (dropped items, traces). [decided]
- **Lovers downside:** when one dies, the other becomes withdrawn: Privacy to max,
  Gossip to min, and whichever other shifts hurt the player most (e.g. Composure up so
  they're harder to read). Visible, so the player can notice the change. [decided]
- **Ways to discover and confront secrets:** sightings that don't fit, confidants,
  personal items, a "you have a secret" card used as leverage. (DESIGN) [open]
- **Named corroborators in alibis** ("I was with Jory"), word-against-word cards; evil
  fake secrets that name someone they really met. (DESIGN) [open]
- **Evidence chains:** a trace leads to a second clue at the killer's evening spot.
  (DESIGN, open since playtest 1) [open]
- **Evil coordination you can see:** daytime evil meetups, with friends and Lovers
  meeting too as noise. (DESIGN) [open]
- **Throw a teammate under the bus:** a pressured minion distances themselves from the
  demon; the demon goes along with town conclusions to build trust. (DESIGN) [open]
- **Full-screen case board** with profile, deductions and cards as overlays; ties into
  modular, movable windows (also deferred). [decided]
- **Claims/reveals timeline** next to the location timeline. (DESIGN) [open]
- **Dialogue voices for the rest of the cast.** The composer is merged (Agnes,
  Bartholomew, Constance × five situations; dialogue lab at `ui/dialogue_lab.tscn`).
  Everyone else uses the plain lines until they get a voice. [decided, later]
- **Bot coverage of the new talk options:** the bot doesn't offer wards or vigils or ask
  about others to learn haunts, so bot runs don't measure them. [decided]
- **Evidence-reading bot.** The bot ignores traces and dropped materials entirely (and
  peeks at `w.dropped` when deciding to search), so bot win rates say nothing about
  physical evidence. Teach it to read traces and drops, and stop the peek, to measure
  what evidence is worth. [decided]

## 4. Major structural work (a week or more; design first)

- **Night movement and trace model.** One package of related items:
  - the deferred night-proximity rule for sightings (route from home to the death
    block);
  - the proposed route limit (home → at most one detour → victim);
  - traces based on where the killer *started* rather than their evening block (this
    fixes the evening-shift demon problem);
  Timing within the night: settled, not modelled (a night stays one instant). The
  evidence-chain item, and the watchtower idea in role_exploration.md, depend on this
  package. (DESIGN) [open]
- **Passing through vs. stopping** (potential movement overhaul direction). Sightings say
  whether someone was passing through a block or out on it (their destination). Two
  "out on" sightings on different blocks are a real contradiction; "passing through"
  fits a route. Open: who can tell the difference (street observers and vigils, not
  window glimpses), and the wording ("heading toward the Docks" vs "out on the
  Docks"). Destination sightings on a kill night overlap with the night-proximity rule,
  and it makes vigils stronger. [open]
- **Relationships:** Bonded, Unrequited, Feuding, Hater (role_exploration).
  Relationship mods for the Lovers live here too. [open]
- **Roster expansion:** On Deck gifts (Tracker, Clairvoyant, Beckon, Tallyman…); minions
  (Framer/Forger with evidence planting, Blackmailer, Hexer, Informant); Debtor secret.
  Each needs its hint package and template coverage. [open]
- **Player toolbox:** Autopsy, Séance, Scry, Binding circle; demon types with bestiary
  entries; exorcism / true-name alternate win. (DESIGN) [open]
- **Scoring system:** identification credit, accuracy of guesses with confidence, why
  the player lost (wrong read / missed / never available / failed to persuade). Absorbs
  the removed voting prompt and the Scion credit rule. [open]
- **Storyteller/director and solvability check:** poisoned readings become arbitrary
  (chosen plausibly) rather than inverted; check that a case can be solved. (DESIGN)
  [open]
- **Procedural town:** blocks, buildings and roads generated per case. (DESIGN) [open]
- **Larger towns (12–15):** only after the core loop works at 7/10. [watch]
- **NPC memory and recency bias.** (Random ideas) [open]
- **Dead NPCs:** no ghost votes for now. (DESIGN, deferred) [watch]

---

## Template gaps (NYI)

A running list of patterns that come up in play, or that the mechanics make meaningful,
but that no link template recognises yet. Add to it whenever a playtest log shows
"no template matched" on a combination that should mean something.

- **Succession breaks earlier clears.** A Seer "no" (or any not-the-demon clear) only
  speaks for the demon *as of that night*. If a hanging with 5+ alive (so a Scion could
  rise) falls between two readings, group elimination, overlap and pair elimination
  must keep "X became the demon afterwards" as an explanation instead of "the earlier
  reading clears the rest". In 55774, #150 cleared Edda from Agnes's night-5 "Greta or
  Edda" using the night-4 "Fenwick or Edda: neither", across Hollis's hanging. Greta
  was right, but Edda (evil, an equally possible successor) stayed a live candidate.
  NPC reasoning and the bot should apply the same limit to old clears. (Astra, 55774)
- *Built Oct 18:* Martyr saves as proof of good; the chosen hanged with the Martyr
  standing; a pair reading naming two proven-good people; filed good / Marked / red
  herring deductions as template inputs; a Seer pair with one proven good (pair
  elimination, with "the proven-good one is the red herring" offered).
- **Same person in repeated Seer yeses, later proven good** → that person is the
  red herring; drop them from the Seer's later readings. (55774: Jory)
- **Evil reading on a proven-good person** (Dowser count, Archivist pair) → Marked.
- **Accounting:** a Lamplighter's "N others out" plus home alibis for everyone but one
  → the unaccounted person was out.
- **Role confirmations:** a Clerk or Gravedigger confirming someone's gift → that claim
  is backed (claim_backed covers the Clerk; the Gravedigger on a living rival claim
  does not).
- **Duty claim vs reading:** the off-route check now tests a named destination (a watch
  kept, a door guarded, the hearth of the dead) against sightings. Still missing: the
  hearth in the Medium's *reading* ("at Dorian's hearth") as the destination, so a
  reading and a sighting can conflict, not only the alibi and a sighting.
- **Walker's sightings vs the Lamplighter count:** more people reported out than the
  Lamplighter counted (or a Lamplighter who counted others but is seen nowhere).

