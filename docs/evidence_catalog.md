# Evidence catalog

First pass, Nov 9 2026, Claude-Quill. **Judged from the code** at main `407069d`, not measured; entries C8, D7 and D8 updated for the day-killer branch (`claude/day-killer`, PR #111). The measured pass is in `docs/evidence_catalog_measured.md`. Strengths here are reasoned from the model's rules and constants. The second pass will replace them with measured shifts from a reference town, at two trust levels, and correct whatever this pass gets wrong. Code pointers for every entry are in `docs/evidence_catalog_code.md`.

## How to read this

### The systems that weigh evidence

Every piece of evidence lands in one or more of these:

1. **World solver.** Enumerates every legal hidden setup (a "world"):
   - who is evil;
   - which evil player is the Demon;
   - one secret modifier and its holder(s): Marked, Delusional, Lovers, Sleepwalker or Muddler;
   - the Revenant's conversion, when there is one.

   A live town has around 15,000 worlds (CaseEval's own figure). A card can rule worlds out (a hard constraint) or reweight them.
2. **Reading likelihood (CaseEval).** For each gift reading, each world gets:
   - `q` if the source can't give a healthy reading in it (the source is evil or Delusional);
   - otherwise `(1 − err)·[content holds] + err·q`.

   `q` is the chance a false reading would say this anyway. `err` is the chance an honest, healthy reading is still wrong for this listener. It starts at 1% (0.2% for the listener's own reading) and grows as the listener's reliability for that card falls (hearing weight, trust in the teller, accepted challenges, doubted nights). This is where "I heard it secondhand" and "maybe their gift failed" live.
3. **Role table.** Whether the role claims and role readings in a world can be given to distinct people:
   - a good claimant's claim is binding;
   - an evil claimant is free to claim anything, at a small cost of 0.92× per bluff.

   Also checked here:
   - the Seer's persistent Red Herring;
   - Medium visits;
   - the Martyr, the Sexton's knell, the Veteran, the Revenant's totem and curse;
   - Town Hall records.
4. **Movement model (live activity).** Routes per person per night, under behaviour profiles. How often each profile is out at night:

   | Profile | Out at night |
   |---|---|
   | Demon hunting | every night |
   | Walking gift | every night |
   | Secret holder | 55% |
   | Minion | 25% |
   | Ordinary townsperson | 5% |

   It consumes night sightings, home alibis, evening sightings, traces, drops, vigils, the walking gifts' readings and secret confessions. Being seen out is evidence in proportion to how unusual it is for good people.
5. **Public and speech factors.** Fixed odds multipliers for a few public facts: Demon victims, people silenced at a meeting, gift-family hints.
6. **Circumstantial hub (Stage 2).** Only for cards the player puts in a case's circumstantial section. Each incident is worth at most +0.015 suspicion, with a cap of +0.045 per target. It's gated: it scales with the specific (Stage 1) evidence the case already has against the target, and partly with their existing suspicion, and is zero without either. Padding a case with unrelated cards draws a smear penalty of 0.005–0.015.
7. **Attention.** A bounded mind (Insight below 0.67) only reasons from a budget of cards: 4 at low Insight, 8 at medium. A high-Insight mind attends to everything. Cards a mind doesn't attend to don't move it.
   - **Salience:** base 1, plus up to 0.1 for trust in the source, plus 2 for a gift reading. Then one of three bonuses:
     - +4 for naming the case's target (when judging a premise);
     - +2 for naming someone the presented cards name or come from;
     - +1 for a group-count reading (Dowser, Surveyor, Seer, Clerk, Rumormonger, Archivist, Registrar), which bears on everyone through the fixed evil count.
   - **Recency:** cards fade with age (0.5 a day at Insight 0, 0.1 at Insight 1, at most 3). The topic of the day draws attention.
   - **Always attended:** own readings are pinned, and presented cards are always attended. Presenting a card, or an NPC citing it in a nomination or accusation, resets its age.

### How a listener hears a card

How firmly a listener takes a card it heard, before trust:

| How it was heard | Weight |
|---|---|
| Own reading | near-certain (error 0.2%) |
| Someone else's reading, heard directly | 0.5 |
| A role claim made in public | 0.5 |
| A reading relayed without naming its source | 0.3 |
| A night sighting | scaled by trust in the teller (0.35 + 0.65 × trust), never below 0.1 |

A reading's reliability for a listener is its hearing weight × `(0.5 + 0.5 × trust in the teller)`, so `err ≈ 1 − reliability`. A reading heard directly from someone trusted at 0.7 has reliability 0.5 × 0.85 ≈ 0.43, so `err` ≈ 0.57. That's large: in a world where the reading's source is good and healthy, it still only counts for 0.43 + 0.57·`q` where it holds, against 0.57·`q` where it doesn't. Own readings are the exception. The player is weighed like any teller, by the listener's trust in the player, except that physical evidence the player found is the evidence itself. *(To confirm in the measured pass: how a listener weighs a sighting the player made, as opposed to evidence the player found.)*

### How a card can be wrong

| Code | Failure | Modelled as |
|---|---|---|
| **L** | Lie: the source is evil (or cursed by the Revenant at the time) | in the worlds |
| **R** | Mis-registration: Marked registers as evil or the Demon, or the Seer's Red Herring | in the worlds (Marked) and the role table (Red Herring) |
| **D** | Delusional source: the gift gives arbitrary information | in the worlds |
| **P** | Poisoned that night | **not in the worlds**; only through `err` (reliability), and the player's "failed gift" challenge |
| **H** | Hearsay drift: relayed, muddled (Muddler) or misheard | the route's reliability; the Muddler is a world modifier |
| **O** | Honest outing: the person was out for a gift, a secret or an errand | the movement profiles |

### Strength tiers (judged)

Strengths assume a reference listener: Insight 0.5, trust 0.7 in the source, the card heard directly, nothing else known. The likelihood-ratio bands match CaseEval's own case-strength categories (weak 1.5, moderate 3, strong 10).

| Tier | Meaning |
|---|---|
| **Decisive** | Settles one person's alignment or role when trusted (likelihood ratio well over 10). |
| **Strong** | Likelihood ratio around 3 to 10 on the person it points at. |
| **Moderate** | Around 1.5 to 3, or strong but spread over several people. |
| **Weak** | Below 1.5, or useful only as a tiebreaker. |
| **Context** | Moves nobody on its own; only enables other evidence or circumstantial incidents. |
| **None** | Rejected as evidence (opinions, rumours). |

## Summary

"Alone" says what the card is worth with nothing else. "Key partner" is what most raises its value. "Measured" is separation (evil minus good) or the step on the subject, from `docs/evidence_catalog_measured.md`; where it disagrees with the judged strength, the measured pass is the better guide.

| # | Evidence | System | Strength (judged) | Measured (7 NPCs, heard at 0.8) | Alone? | Key partner |
|---|---|---|---|---|---|---|
| A1 | Seer reading | worlds, role table (Red Herring), likelihood | "no": strong; "yes": moderate | negligible (+0.013); "yes" false 42% of the time | yes | overlapping Seer readings; a known-good in the pair |
| A2 | Dowser count | worlds, likelihood | moderate; strong at 0 or full | strong at 7 (+0.108), weak at 10 | partly | overlapping groups |
| A3 | Surveyor (block parity) | worlds, likelihood | weak to moderate | moderate at 7 (+0.088), negligible at 10 | no | anyone on that block known |
| A4 | Augur (crossed the Demon) | worlds, likelihood, day sightings | moderate | negligible alone | no | that day's public sightings |
| A5 | Confessor visit | worlds, likelihood | "good": strong; "forgot": weak | moderate (+0.054); "good" clears its target by 0.36 | "good" yes | sightings of the Confessor's visit |
| A6 | Chronicler trio | worlds, likelihood | strong | not dealt by day 3 | yes | a second trio member resolved |
| A7 | Magistrate (nominator vs nominee) | worlds, likelihood, nomination record | moderate | moderate at 7 (+0.087), negligible at 10 | partly | either person resolved |
| A8 | Clerk (one of two holds gift G) | role table | moderate | moderate, all on the reader | partly | claims of gift G |
| A9 | Archivist (one of two is Minion M) | role table | strong | +0.15 on both named; separation negligible | yes | either person cleared |
| A10 | Rumormonger (one of two carries secret S) | worlds | moderate | moderate (+0.054) | partly | a secret confession |
| A11 | Gravedigger (executed's role) | role table, chronology | decisive | strong (+0.19) | yes | the execution |
| A12 | Executor (assigned person's role on death) | role table, chronology | decisive (once they die) | moderate, mostly assignments | after a death | that death |
| A13 | Registrar (role list + checks) | role table | moderate | moderate, all on the reader | partly | claims of the listed roles |
| A14 | Monitor (role of a walker on their block) | worlds, movement | moderate | moderate, all on the reader | no | night sightings on that block |
| A15 | Psychologist (one of two statements false) | worlds, factored channels | moderate | negligible alone | no | holding both statements |
| A16 | Night Watch (who passed a block) | movement | moderate | negligible (+0.017) | partly | home alibis of those seen |
| A17 | Lamplighter (how many were out) | movement (routes) | weak | negligible | no | sightings that night |
| A18 | Medium (relays a dead person's item) | relay channels, role table | as the item, discounted | negligible at 7, moderate at 10 | partly | the dead person's own claims |
| A19 | Warden (guarded a door; a "save") | movement, worlds | weak; "save": moderate | not measured | partly | the quiet night |
| A20 | Veteran (survived; attacker's block) | movement, role table | moderate | too few | partly | evening and night sightings |
| A21 | Martyr (chose someone; died in their place) | role table, public event | event: decisive | moderate (report) | event yes | the execution |
| A22 | Sexton (tolled the bell) | role table, chronology | weak | negligible | no | a minion effect that didn't happen |
| A23 | Hearthwitch (benched) | worlds | — | — | — | — |
| B1 | Role claim | role table, bluff weight | weak alone; strong in a clash | none alone; clash +0.15 on both | no | counter-claims, role readings |
| B2 | Gift-family hint | speech factor | weak | none when gossiped | yes | a later full claim |
| B3 | Secret confession | movement, worlds | context (explains outings) | none when gossiped | no | the outings it explains |
| B4 | Refusal to share whereabouts | circumstantial | weak (circumstantial) | not measured | no | Stage 1 evidence on them |
| B5 | Town Hall records (one of two roles in play) | role table | moderate | not measured | no | claims of those roles |
| C1 | Day sighting / conversation | circumstantial, Augur | context | not measured | no | Augur, Breathstealer, suspicion of the partner |
| C2 | Evening sighting | movement, traces | context to weak | not measured | no | quarter traces, soot |
| C3 | Night sighting (someone out) | movement | moderate | Demon +0.26; a Minion −0.11 | yes | home alibi; walking-gift claim |
| C4 | Home alibi | movement, testimony honesty | weak | clears evil by 0.14 | no | a sighting that contradicts it |
| C5 | Dropped belongings (owner known) | movement | strong (certain outing) | +0.20 on an evil owner | yes | the night's murder route |
| C6 | Mud or soot drop (owner's block only) | movement | weak to moderate | not measured | no | residents of that block |
| C7 | Vigil (player watched a block) | movement | strong for exclusion | not measured | yes | murder route through the block |
| C8 | Day log (who was at a watched block's places) | day presence, Whereabouts solver | moderate for the Hexer and Breathstealer | not measured | partly | a Hexer kill or a silencing that day |
| D1 | Demon victim | public factor, chronology | strong toward good | −0.60 on the victim | yes | — |
| D2 | Crime-scene trace (locations / quarter / connection) | movement, trace solver | moderate; strong in chains | 0 alone, +0.03 with profiles | partly | profile context; more traces |
| D3 | Quiet night (no death) | movement, role table | weak to moderate | not measured | no | Warden, Veteran, ward |
| D4 | Scorched sigil (ward held) | movement, chronology | moderate | not measured | partly | the warded person's neighbours' routes |
| D5 | Revenant totem / curse | role table, chronology | moderate | not measured | partly | the hanging that triggered it |
| D6 | Execution | chronology | context | — | no | Gravedigger, Martyr, Scion |
| D7 | Silenced at the meeting | public factor; day presence (Breathstealer) | weak toward good | −0.16 on the silenced | yes | the day log of the victim's block |
| D8 | Hexer kill (day-killer demon) | day presence (HexFactor) | weak to moderate | not measured | partly | the day log of the victim's places |
| E1 | Vote / nomination record | circumstantial, Magistrate | weak (circumstantial) | not measured | no | the nominee's later resolution |
| E2 | Accusation / opinion / gossip | none | none | — | — | — |
| E3 | Tavern rumour | none in the Workshop | none | — | — | — |
| F1 | Home / work / haunt | context | context | not measured | no | traces |
| F2 | Trait (composure, privacy) | circumstantial | weak | not measured | no | Stage 1 evidence |
| F3 | Bond (friend / rival) | circumstantial, traces | weak | not measured | no | suspected friend, murdered rival, connection trace |
| G1 | Evil / Demon / Minion / not-the-Demon premise | the claim tested | as its cards | — | — | — |
| G2 | Suspicious premise | half-weight hearing + pressure | its cards at half | — | — | — |
| G3 | Good premise | the claim tested | as its cards | — | — | — |
| G4 | Secret premise ("X holds S") | the player's word | weak to moderate | — | yes | the player's credibility |
| G5 | Holds their claimed gift | the role table | as "good" | — | — | — |
| G6 | Conflict premise | case consistency | as its cards | — | — | — |
| G7 | Reading challenge (misled / lying / failed gift / Delusional / these don't fit) | leave-one-out, reliability | moderate when grounded | — | no | grounds cards |
| H | Distorters: Marked, Red Herring, Delusional, Poisoner, Muddler, Sleepwalker, Lovers, curse, Scion, Brute, Breathstealer, Sexton's bell | — | — | — | — | — |

## A. Gift readings

**Defaults for every reading unless the entry says otherwise:**
- **System:** the reading likelihood above.
- **Wrong when:** L and D always; P through `err` only; H when heard secondhand.
- **Attention:** +2 as a gift reading (on the live list, which covers every role here); the reader's own copy is pinned.
- **Player use:** citable in a case and challengeable (misled / lying / failed gift / Delusional / "these don't fit").
- **Faking:** evil can bluff any reading. A bluff costs the bluffer nothing if it later fits by chance, so readings whose content holds in few worlds (low `q`) are the ones that build or destroy a source's credibility. Readings that hold almost everywhere (`q` near 1) earn the source nothing.

### A1. Seer reading
- **Source and timing:** Seer, each night, picks two people.
- **Says:** whether either of the pair is the Demon.
- **System:** worlds plus the role table's Red Herring averaging. One good soul reads as the Demon to this Seer for the whole case, so the solver averages over who that might be. The Marked may register as the Demon (half weight per reading).
- **Constrains:** only the Demon's identity. A "no" clears two people of being the Demon, not of being a Minion.
- **Wrong when:** L, D, P, R (the Red Herring, or the Marked in the pair).
- **Strength:** "no" is strong against the Demon for two people. "Yes" is moderate: it's split between two people and the possibility of the Red Herring. Repeated readings that share a person triangulate and become strong.
- **Alone:** "no" yes; "yes" narrows to two.
- **Becomes useful with:** a second reading overlapping one member; a known-good member (then the other is the Demon or the Red Herring).
- **Corroborates:** an Augur "crossed the Demon" on the same person; Chronicler and Archivist evil reads that point elsewhere (a Minion isn't the Demon).
- **Contradicts:** a Gravedigger or Executor reading that the person was some other role; a Demon kill on someone the Seer called the Demon.
- **Unlocks:** a "yes" plus one cleared member points hard at the other.
- **Undermines:** a "yes" on two proven-good people means the Seer is evil or Delusional, or the Red Herring is in the pair. Repeated "yes" on the same proven-good person points at the Red Herring.
- **Faking:** a bluffed Seer reading gets the fixed `q` of 0.5, so a fake fits by chance often and earns little credit per reading.
- **Gaps:** `q` is the fixed 0.5. The CaseEval comment calls a Seer "yes" hard to fake, but the Seer is on the fixed-estimate list and its shape falls through to 0.5. To check in the measured pass.

### A2. Dowser count
- **Source and timing:** Dowser, during the day: the first time each day they're out in public on a block with two or more others.
- **Says:** how many of those others are evil.
- **Constrains:** the number of evil people in a named group of 2+.
- **Wrong when:** defaults, plus R (the Marked may register either way, independently each reading).
- **Strength:** moderate in general; strong at the extremes. A count of 0 clears everyone in the group (short of Marked or the Dowser lying). A count equal to the group's size convicts them all.
- **Alone:** partly: it spreads suspicion evenly across the group.
- **Becomes useful with:** a second group that overlaps the first (set arithmetic); anyone in the group already resolved.
- **Corroborates:** Seer, Archivist or Chronicler evil reads on a group member; another Dowser count over the same people.
- **Contradicts:** a 0 count that includes someone a Gravedigger later reads as a Minion.
- **Unlocks:** two counts that differ by one person, with one count resolved, pin that person.
- **Undermines:** a count that no world can satisfy, given what's known, discredits the Dowser.
- **Faking:** `q` is the share of worlds where the count holds. That's often 0.3–0.5 for a mid count, so fake mid counts are cheap. Fake 0s are riskier.
- **Attention:** the card mentions every group member, so it gets the +2 bonus if any of them was presented, and the +1 group-count bonus otherwise.

### A3. Surveyor (block parity)
- **Source and timing:** Surveyor, first night: a random block that isn't their own.
- **Says:** whether all of that block's residents share an alignment.
- **Constrains:** the alignment parity of one block's residents (two or more people).
- **Wrong when:** defaults, plus R (Marked).
- **Strength:** weak to moderate. "Same" with a block of mostly good people points toward all good. "Different" says one of them is evil without saying who.
- **Alone:** no: it's a statement about a set.
- **Becomes useful with:** knowing anyone on that block. One resolved resident turns "same" into a verdict on the rest.
- **Corroborates:** Dowser counts over the same residents; quarter traces naming that block.
- **Contradicts:** two proven-opposite residents with a "same" reading.
- **Faking:** `q` is the share of worlds where the parity holds, often near half, so it's cheap to fake.
- **Gaps:** an older count mode ("how many blocks have an evil resident") is still in the code alongside parity.

### A4. Augur (crossed the Demon)
- **Source and timing:** Augur, each evening.
- **Says:** whether they crossed paths with the Demon in public, on the same block, earlier that day.
- **System:** worlds, filtered by `augur_day_spec`. Daytime positions come from that day's public sightings and from workplace context (`context` cards with `context_kind == "work"`: work phases and block). With neither, the reading constrains nothing.
- **Constrains:** that the Demon (or the Marked) was among the people on a block when the Augur was there.
- **Wrong when:** defaults, plus R (Marked).
- **Strength:** moderate once sightings exist. "No" clears everyone the Augur shared a block with that day of being the Demon.
- **Alone:** no.
- **Becomes useful with:** day sightings and conversations (C1), or workplace context (F1), placing people on the Augur's blocks that day.
- **Corroborates:** Seer readings on the same people.
- **Unlocks:** an Augur "yes" on a day when only one unresolved person shared their block.
- **Faking:** `q` is the share of worlds where the reading holds.
- **Gaps:** the player can only check it if that day's positions are known, from recorded sightings or from who was at work.

### A5. Confessor visit
- **Source and timing:** Confessor, each night but the first, visits one living person in secret.
- **Says:** "their spirit is good", or nothing: the Confessor forgot the visit, which happens when the person is evil or Marked.
- **Constrains:** "good" settles one person as good; "forgot" says the person visited is evil or Marked, but the Confessor doesn't know who that was.
- **Wrong when:** defaults; R (Marked) for "forgot".
- **Strength:** "good" is strong. "Forgot" is weak alone.
- **Alone:** "good" yes.
- **Becomes useful with:** for "forgot", a night sighting of the Confessor arriving at someone's door, or the Confessor's route.
- **Corroborates:** Seer "no" or a Dowser 0 on the same person.
- **Faking:** `q` is the share of worlds where the reading holds. An evil Confessor can call a teammate "good". Recurring "good" on people who are later executed as evil discredits them.
- **Gaps:** the Confessor walks at night, so their own outings are explained by the gift once claimed (the claim auto-cites).

### A6. Chronicler trio
- **Source and timing:** Chronicler, night 3.
- **Says:** three other people (living or dead): at case start, one was an ordinary townsperson, one carried a secret, one was a Minion.
- **Constrains:** exactly one Minion, one secret holder and one plain townsperson among three named people.
- **Wrong when:** defaults. No Marked registration; Marked counts as "a secret".
- **Strength:** strong. It names a Minion within three people and ties to the secret's holder.
- **Alone:** yes: a one-in-three Minion.
- **Becomes useful with:** any one member resolved (good, a secret confessed, or evil), which leaves two and a role split.
- **Corroborates:** Archivist and Seer reads on members; a member's secret confession (B3), which marks them as the secret holder.
- **Contradicts:** two members proven good and plain.
- **Unlocks:** a secret confession from one member makes the other two a Minion and a plain townsperson.
- **Faking:** uses exact prior hold rates (`_chance_chronicler`), so a fake that fits is reasonably likely.

### A7. Magistrate (nominator vs nominee)
- **Source and timing:** Magistrate, each night.
- **Says:** whether the first townsperson to nominate that day (other than the player and the Magistrate) shared an alignment with their nominee.
- **System:** worlds; checked against the public nomination record.
- **Constrains:** the parity of two named people.
- **Wrong when:** defaults, plus R (Marked).
- **Strength:** moderate. It links two people's fates.
- **Alone:** partly: "different" means one of the two is evil.
- **Becomes useful with:** either person resolved, or the nominee executed and read by a Gravedigger.
- **Corroborates / Contradicts:** E1 vote records; shielding and hostile-vote incidents.
- **Unlocks:** "same" plus an evil nominee means an evil nominator (bussing).
- **Faking:** `q` is the share of worlds where the parity holds.

### A8. Clerk (one of two holds gift G)
- **Source and timing:** Clerk, first night.
- **Says:** one of two people holds a particular good gift.
- **System:** the role table: someone in the pair must be assignable gift G.
- **Constrains:** a role assignment.
- **Wrong when:** defaults. No Marked registration.
- **Strength:** moderate. It confirms a claimant who matches, and it's strong in a counter-claim fight.
- **Alone:** partly: it says one of the two is good (the gift holder).
- **Becomes useful with:** claims of gift G (B1). A matching claimant inside the pair is likely the real one; a claimant outside the pair is likely lying.
- **Contradicts:** two people outside the pair both being proven holders of G (impossible).
- **Unlocks:** an outside claimant of G becomes a likely bluffer.
- **Faking:** `q` is the fixed 0.5.

### A9. Archivist (one of two is Minion M)
- **Source and timing:** Archivist, first night.
- **Says:** one of two people is a particular Minion.
- **System:** the role table: a Minion slot assignable within the pair.
- **Constrains:** one Minion's identity within two people.
- **Wrong when:** defaults.
- **Strength:** strong. It's one of the few direct Minion reads.
- **Alone:** yes.
- **Becomes useful with:** either person cleared (then the other is that Minion); the Minion's own effects (a silencing that fits a Breathstealer, a poisoned night).
- **Corroborates:** a Chronicler trio containing the same person; a Gravedigger read of M on an executed member.
- **Faking:** `q` is the fixed 0.5. Evil can frame two good people.

### A10. Rumormonger (one of two carries secret S)
- **Source and timing:** Rumormonger, first night.
- **Says:** one of two people carries a particular secret (Marked, Delusional, Lovers, Sleepwalker, Muddler).
- **System:** worlds (the modifier and its holders).
- **Constrains:** who holds the case's one secret. That also rules out every other secret elsewhere, since there's one per case.
- **Wrong when:** defaults.
- **Strength:** moderate. It's mostly an enabler: knowing the Marked, Delusional or Sleepwalker explains away other evidence.
- **Alone:** partly.
- **Becomes useful with:** a confession (B3); a reading that fits a known secret (a Delusional reader's odd readings; a Sleepwalker's outings).
- **Unlocks:** identifying the Delusional discredits every reading they gave. Identifying the Marked explains a false evil read on them.
- **Faking:** uses exact secret priors (`_chance_rumormonger`).

### A11. Gravedigger (executed's role)
- **Source and timing:** Gravedigger, the night after an execution.
- **Says:** the true role of the executed.
- **System:** the role table, plus chronology (the execution must have happened).
- **Constrains:** one person's role, so their alignment too.
- **Wrong when:** defaults, plus R (a Marked executed person may read as an evil role).
- **Strength:** decisive.
- **Alone:** yes.
- **Becomes useful with:** nothing more is needed. It resolves the executed and the claims around them.
- **Corroborates / Contradicts:** every claim and reading about the executed. It checks the claimed role directly.
- **Unlocks:** a role read that contradicts the executed person's claim confirms they bluffed. A good read of the claimed role means the town hanged an innocent and their accusers become suspect.
- **Faking:** `q` is the fixed 0.5. An evil Gravedigger can call an executed teammate good, but the claim is checkable against Executor and Martyr evidence and counter-claims. On a hanged good person it calls them a Minion more often the surer the hanging vote was (#136).
- **Gaps:** shares the fixed `q` issue with the Seer.

### A12. Executor (assigned person's role on death)
- **Source and timing:** Executor: learns one person at case start; if they die, learns their role the next morning.
- **Says:** "I'm assigned to X" (no information), then "X was role R".
- **System:** the role table and chronology (X must have died before that morning).
- **Constrains:** one person's role after death.
- **Wrong when:** defaults, plus R.
- **Strength:** decisive once the assigned person dies; nothing before.
- **Alone:** after the death, yes.
- **Faking:** fixed `q`.

### A13. Registrar (role list + checks)
- **Source and timing:** Registrar: starts knowing three roles on the script (at least one in play, at most one a Minion, never the Demon). Each night, checks one person against them.
- **Says:** whether a person holds one of the three roles.
- **System:** the role table and the Town Hall role pool.
- **Constrains:** role membership for each person checked.
- **Wrong when:** defaults, plus R (Marked).
- **Strength:** moderate. A "yes" on a list with a Minion is evil-leaning; a "yes" on a list without one clears.
- **Alone:** partly.
- **Becomes useful with:** claims of the listed roles (B1); Town Hall records (B5).
- **Faking:** fixed `q`.

### A14. Monitor (role of a walker on their block)
- **Source and timing:** Monitor, each night but the first. Never gets window sightings.
- **Says:** the role of one person who walked on their home block, or that no one walked by.
- **System:** worlds and movement. The Monitor doesn't say who walked; matching the role to a person needs sightings.
- **Constrains:** one walker's role (evil roles allow the Marked); "no one walked" excludes everyone from that block that night.
- **Wrong when:** defaults, plus R.
- **Strength:** moderate. "No one walked" is a good exclusion for murder routes.
- **Alone:** no for the role read; yes for "no one walked".
- **Becomes useful with:** night sightings on that block (C3, A16); traces whose route crosses it.
- **Faking:** `q` is the fixed 0.5.

### A15. Psychologist (one of two statements false)
- **Source and timing:** Psychologist, each night but the first.
- **Says:** either two statements they heard directly that day, at least one of them false (a lie or a misreading), or that none of the statements they heard were false.
- **System:** worlds plus factored channels. Holding both statements as true is inconsistent with a valid Psychologist, so one statement or the Psychologist has to give.
- **Constrains:** the truth of two named statements (and so their speakers).
- **Wrong when:** defaults.
- **Strength:** moderate. It turns a pair of claims into an either/or.
- **Alone:** no.
- **Becomes useful with:** knowing one of the two statements is true, which convicts the other.
- **Unlocks:** "misled" answers where the false statement is a home alibi from a possible Sleepwalker.
- **Faking:** its content isn't in the report table, so by the same logic as the Lamplighter `q` comes out at 1: a fake costs and earns nothing. *(To check.)*
- **Gaps:** older "subject" readings (opinion style) are context only, not alignment evidence.

### A16. Night Watch (who passed a block)
- **Source and timing:** Night Watch, each night: watches one block, and is out on it.
- **Says:** who moved through that block.
- **System:** movement. Each person seen is a night sighting (C3) on that block.
- **Wrong when:** defaults. Seen people may be out for O (gifts, secrets).
- **Strength:** moderate. It's like several sightings at once, and an empty list is an exclusion.
- **Alone:** partly.
- **Becomes useful with:** home alibis of the people seen (C4); murder routes through the block.
- **Contradicts:** home alibis; another watcher's list.
- **Faking:** `q` is 0.25.
- **Gaps:** a "watch claim" without a list is a duty claim (it explains the Watch's own outing), not a reading.

### A17. Lamplighter (how many were out)
- **Source and timing:** Lamplighter, each night: walks the lamp route.
- **Says:** how many other people were out.
- **System:** movement routes: the count constrains how many people were out that night.
- **Strength:** weak. It's a count with no names.
- **Alone:** no.
- **Becomes useful with:** sightings that night. Once the count is accounted for by known walkers, everyone else stayed home.
- **Faking:** CaseEval treats it as checked nowhere, so `q` is 1. A fake count costs the source nothing and earns them nothing.
- **Gaps:** the CaseEval comment ("isn't checked anywhere") and the live-activity code (counts constrain routes) disagree. To check in the measured pass.

### A18. Medium (relays a dead person's item)
- **Source and timing:** Medium, each night after the first Demon kill: visits a victim's hearth and learns something the dead knew but never shared.
- **Says:** the dead person's reading, night sighting, "they were home" or "I guarded X".
- **System:** relay channels. The original keeps its own health (the dead person's honesty and gift), and the Medium's visit has its own honesty. The role table checks the Medium's visits (same victim, same night).
- **Constrains:** whatever the relayed item constrains.
- **Wrong when:** L or D for the Medium; L, D or P for the dead source; H.
- **Strength:** the item's strength, discounted by two links of trust.
- **Alone:** partly.
- **Becomes useful with:** the dead person's own public claims, which make their gift credible; the Medium's role claim.
- **Undermines:** a relayed opinion is rejected as evidence ("cite the supporting observations").
- **Faking:** relays are hard to check, so they're free to fake. A fake Medium sometimes gives something empty so it isn't always damning.

### A19. Warden (guarded a door; a "save")
- **Source and timing:** Warden, each night: guards one other person's door.
- **Says:** "I guarded X", and on a quiet night "I think I saved X".
- **System:** movement (the Warden was out to X's door) and worlds. A claimed save holds only where X is good: the Demon goes for the good.
- **Constrains:** the Warden's route; with a save, X is good.
- **Wrong when:** defaults; contradicted outright if X died that night.
- **Strength:** weak, or moderate for a save.
- **Alone:** partly.
- **Becomes useful with:** a quiet night (D3); sightings of the Warden on X's block.
- **Faking:** `q` fixed.

### A20. Veteran (survived; attacker's block)
- **Source and timing:** Veteran: the first time the Demon attacks them, they survive and learn the last block the attacker came through.
- **System:** movement (the Demon's route) and the role table.
- **Constrains:** the Demon's route that night.
- **Strength:** moderate.
- **Alone:** partly.
- **Becomes useful with:** evening and night sightings on that block; home blocks of suspects.
- **Faking:** `q` fixed.

### A21. Martyr (chose someone; died in their place)
- **Source and timing:** Martyr, once per case: secretly chooses someone. If that person is executed while good, the Martyr dies instead.
- **Says:** the report says whom they chose. The public event (the Martyr died in X's place) shows it happened.
- **System:** the role table: the event assigns the Martyr role and makes both people good.
- **Strength:** the event is decisive for two people. The private report is weak until the event.
- **Alone:** the event yes; the report no.
- **Gaps:** a prior Martyr promise followed by a later execution of the chosen person isn't fully adapted yet.

### A22. Sexton (tolled the bell)
- **Source and timing:** Sexton, once per case (not night 0): may toll the bell and walk every parish. All Minion abilities are suppressed until the next night.
- **System:** the role table (`FlagSextonEnvOk`: the reported night is at least 1, and reported toll nights are consistent).
- **Constrains:** only the claim's own consistency. The suppression of Minion effects is a **simulation rule**, not a solver constraint: neither `RoleConstraints` nor `Chronology.fault_for()` consults the knell, so the solver doesn't rule out a poisoned reading, a silencing or a curse on a knell night.
- **Strength:** weak alone.
- **Becomes useful with:** a Minion effect that should have happened that night, but only to a reader who reasons it through; the solver doesn't.
- **Gaps:** enforcing the knell in the solver (no poison window, silencing or curse turn on a knell night) would make "a reading on a knell night can't have been poisoned" true for the town.

### A23. Hearthwitch (benched)
Not on any script. It counts evil among two living lane neighbours.

## B. Statements about roles and gifts

### B1. Role claim
- **Source and timing:** anyone, privately or at a meeting.
- **Says:** "I hold gift G".
- **System:** the role table and bluff weight. A good claimant's claim binds: they must hold G. An evil claimant is free to claim, at a 0.92× world weight per bluff, eased by how the claim was heard.
- **Constrains:** who can hold G. Two good claimants of one gift can't both be good.
- **Wrong when:** L.
- **Strength:** weak alone: about 1.04× toward good when heard at half weight, 1.09× at full. Strong in a clash, where two claimants of one gift means one of them is evil.
- **Becomes useful with:** a counter-claim; Clerk or Town Hall records; the claimant's own readings (once trusted, the readings make the claim credible).
- **Unlocks:** explains a claimant's outings (a walking gift); turns their readings into credible readings.
- **Undermines:** a Gravedigger or Executor read that contradicts it is proof of a bluff.
- **Attention:** role claims are auto-cited when a case relies on an outing the gift explains.
- **Player use:** "holds their claimed gift" premise (G5).

### B2. Gift-family hint
- **Source and timing:** a cautious NPC: "my gift deals in records" (a family of two or more roles).
- **System:** speech factor: a likelihood ratio of 1.5 toward good. An incompatible later claim flips it to 1.5 toward evil.
- **Strength:** weak.
- **Becomes useful with:** a later full claim inside the family.

### B3. Secret confession
- **Source and timing:** an NPC confesses a secret: Lovers, Sleepwalker, or a flavour secret (insomnia, smuggling, debt).
- **System:** movement profiles (it explains outings at the secret holder's 55% rate) and worlds (Lovers and Sleepwalker are world modifiers).
- **Constrains:** for Lovers and Sleepwalker, the case's one modifier, which rules out the others.
- **Strength:** context. It mostly neutralises night sightings of the confessor.
- **Becomes useful with:** the outings it explains; Rumormonger and Chronicler reads.
- **Faking:** evil can claim a secret to cover an outing. The solver checks a Sleepwalker claim against the world's modifier.

### B4. Refusal to share whereabouts
- **Source and timing:** an NPC who won't say where they were.
- **System:** circumstantial only ("demeanor tell"). A fearful refusal is discounted to 0.71×.
- **Strength:** weak, at most +0.015, and only if the case has Stage 1 evidence on them.

### B5. Town Hall records (one of two roles in play)
- **Source and timing:** the player, at the Town Hall (morning or afternoon), a limited number of times per case.
- **Says:** of two good roles, exactly one is in play.
- **System:** the role table (Town Hall pool).
- **Strength:** moderate in claim fights.
- **Becomes useful with:** claims of either role. If one is claimed and the other isn't, the claim is credible; if both are claimed, one is a bluff.

## C. Whereabouts

**Defaults:**
- **Wrong when:** L for the teller (testimony honesty, separate from gift honesty); H; O.
- **Attention:** no gift bonus, so in a bounded mind these lose out to readings unless they name the case's target (+4) or a presented person (+2).

### C1. Day sighting or conversation
- **Source and timing:** anyone, mornings and afternoons, on a block or at a location.
- **System:** circumstantial (association with a suspected person; proximity to someone silenced that day). Also the Augur's check, which needs to know who shared the Augur's block.
- **Strength:** context.
- **Becomes useful with:** Augur readings; a Breathstealer silencing that day; a suspected conversation partner (suspicion ≥ 0.32).

### C2. Evening sighting
- **Source and timing:** anyone, evenings.
- **System:** movement (the habitual evening block a hunter leaves from) and traces (quarter traces name an evening block).
- **Strength:** context to weak.
- **Becomes useful with:** quarter traces; soot traces.

### C3. Night sighting (someone out)
- **Source and timing:** NPCs out at night (Night Watch, walkers), or the player on a vigil.
- **System:** movement. Being out is weighed against how often each profile goes out (Demon and walking gifts always, secret holders 55%, Minions 25%, ordinary townspeople 5%).
- **Strength:** moderate against someone with no gift or secret to explain it; near zero against a claimed walking gift.
- **Alone:** yes.
- **Contradicts:** the person's home alibi (C4). The player can cite the pair as a dispute.
- **Unlocks:** on a murder night, a sighting on the route to the victim's house.
- **Faking:** evil witnesses can invent sightings; they're weighed by trust in the teller.

### C4. Home alibi
- **Source and timing:** "I was home that night" (own, or vouched by a witness).
- **System:** movement and testimony honesty.
- **Strength:** weak alone.
- **Contradicts:** a sighting of them out that night. That conflict is strong against the alibi-giver unless the teller is doubted.

### C5. Dropped belongings (owner known)
- **Source and timing:** the player, searching a location: someone's belongings, dropped on a known night.
- **System:** movement, as a certain night sighting. It's physical evidence, so it has no honesty channel.
- **Strength:** strong: a certain outing.
- **Becomes useful with:** that night's murder route; the owner's alibi (now contradicted).

### C6. Mud or soot drop (owner's block only)
- **Says:** someone who lives on a given block passed this location that night.
- **System:** movement; the drop's owner is matched to residents of that block.
- **Strength:** weak to moderate, depending on how many residents.

### C7. Vigil (player watched a block)
- **Source and timing:** the player, at night.
- **Says:** everyone the player saw pass; anyone not seen didn't pass (with a 5% miss allowance).
- **System:** movement (complete coverage).
- **Strength:** strong for exclusion. An empty vigil on a claimed walker's block is about 10:1 against the claim.
- **Becomes useful with:** a murder route through the block.

### C8. Day log (who was at a watched block's places)
*(day-killer branch, `claude/day-killer`)*
- **Source and timing:** the player, each day phase spent on a block: everyone at every public place on that block, empty places included. One hidden `watch_log` receipt per day.
- **Says:** who was at each place, and that anyone not listed wasn't at that block's places that phase.
- **System:** the day-presence table (each person's odds of being at each place or home, per day and phase). The player's own view carries the full watch record. A listener hears it only when it's cited, as one card in their reading budget. The Whereabouts solver turns it into "fits / unknown / ruled out" for one question (a Demon death, a silencing, a place on a day).
- **Strength:** moderate, for the questions it answers (where the Hexer stood, who was near a silenced person). Context otherwise.
- **Becomes useful with:** a Hexer kill (D8) or a silencing (D7) that day; NPC sighting reports (trusted at the presence model's testimony trust); known haunts.
- **Gaps:** the bot never builds a Whereabouts node, so in autoplay the town doesn't hear the bot's watches.

## D. Crime scenes and night events

### D1. Demon victim
- **System:** public factor. A victim is 95:5 good.
- **Strength:** strong toward good.
- **Corroborates:** the victim's claims become credible.

### D2. Crime-scene trace
- **Source and timing:** the player, searching a murder scene. The killer always leaves one; a passer on the route sometimes leaves a second.
- **Families:**
  - **Locations:** the killer works at or haunts one of 2–3 named places.
  - **Quarter:** lives on block X or spent that evening on block Y.
  - **Connection:** a neighbour of the victim, a public bond with them, or day company.
  - **Legacy:** the killer spent the evening on the block the material comes from.
- **System:** movement plus the trace solver: a pigeonhole chain over murder nights, and the Scion's succession.
- **Strength:** moderate per trace; strong in chains across nights, because the Demon is the same person.
- **Becomes useful with:** profile context (F1, F3); more traces on other nights; the Scion rules after a Demon execution.

### D3. Quiet night (no death)
- **Says:** the Demon attacked and failed, or didn't kill.
- **System:** movement and the role table (Warden save, Veteran, ward, Sexton).
- **Strength:** weak to moderate.
- **Becomes useful with:** a Warden's save claim (A19); the Veteran (A20).

### D4. Scorched sigil (ward held)
- **Says:** the Demon came to this door that night and the player's ward held.
- **System:** movement (the Demon's route went to that house).
- **Strength:** moderate.
- **Becomes useful with:** sightings and alibis that night near that house.

### D5. Revenant totem and curse
- **Says:** a found totem names a block (its material). A hanged Revenant with a hidden totem turns a good "yes" voter evil until the totem is found.
- **System:** the role table (a Revenant among the block's residents) and chronology (a conversion window).
- **Strength:** moderate.
- **Gaps:** the curse's histories are modelled for fixtures. Live curse chronology carries an "adapter needed" issue.

### D6. Execution
- **System:** chronology.
- **Strength:** context.
- **Becomes useful with:** the Gravedigger; the Martyr; the Scion (the Demon executed with five or more alive).

### D7. Silenced at the meeting
- **System:**
  - a public factor on the silenced person (about 0.66× odds of evil: the Breathstealer silences threats);
  - on the day-killer branch, a joint CaseEval factor ("Breathstealer by presence"). Each world's Minions are weighed by the chance they were on the victim's block in the same phase, across every silencing. It replaces the circumstantial hub's one-day proximity incident.
- **Strength:** weak toward good for the silenced person; the presence factor points at the Breathstealer as far as the day's whereabouts are known.
- **Becomes useful with:** the day log of the victim's block (C8); NPC sightings that day (C1).

### D8. Hexer kill (day-killer demon)
*(day-killer branch; only on scripts that list two demon types)*
- **Source and timing:** a Hexer hexes a public place it stands in, during a day phase, with good regulars present. That night a random living good regular of that place dies. It never walks, so it leaves no night sightings or vigil evidence; traces at the house work as usual.
- **System:** day presence. Each world scores `(1 − s)·walk + s·day·HexFactor`, where `s` is the script's Hexer share and, in the day term, the Demon slot moves like a Minion. HexFactor: for each kill, the sum over the victim's known places of P(the Demon was there) × good alive / good regulars, with a floor of 0.15.
- **Strength:** weak to moderate. It depends on how much of the victim's places' daytime is known.
- **Becomes useful with:** the day log (C8) of the victim's places that day; known haunts; a Veteran who survives a Hexer (learns its home block).
- **Undermines:** night-movement evidence for the Demon. With a Hexer possible, being out at night says less about being the Demon.

## E. Public behaviour

### E1. Vote and nomination record
- **System:** circumstantial:
  - **Hostile vote:** voting to hang, or nominating, someone the listener trusts.
  - **Shielding:** voting against hanging someone the listener suspects (suspicion ≥ 0.48), or a proven-evil nominee.
- **Strength:** weak (circumstantial).
- **Becomes useful with:** the nominee's later resolution; the Magistrate.

### E2. Accusation, opinion, gossip
Not evidence. The Workshop rejects them: "cite the supporting observations". NPC nominations move attention (the topic of the day) and recall the cited cards, but add no weight of their own.

### E3. Tavern rumour
Not usable in the Workshop: unattributed.

## F. Profile context

### F1. Home, work, haunt
- **System:** context for traces: locations traces use work and haunts, quarter traces use home, connection traces use home block and bonds.
- **Strength:** context.

### F2. Trait (composure, privacy)
- **System:** circumstantial: a low-composure or high-privacy "demeanor tell".
- **Strength:** weak, at most 0.8 × 0.015.

### F3. Bond (friend, rival)
- **System:** circumstantial:
  - friend of a suspected person;
  - rival of a murder victim.

  Connection traces also use bonds.
- **Strength:** weak.

## G. Player premises and challenges

Premises are the player's theory. They're tested against the worlds, never added as facts, except the secret premise.

### G1. Evil, Demon, Minion, not-the-Demon
- **Tests:** the claim against every world.
- **Weight:** the cards' weight. The premise decides what the jury is asked, not how much the cards count.

### G2. Suspicious
- **Effect:** cards brought only by a suspicious premise are heard at half weight (0.5) by everyone. The other half becomes pressure on the target: the average listener's full-weight rise, times 0.5 in private or 1.0 at a meeting, once per filing.

### G3. Good
- **Effect:** the inverse of G1.

### G4. Secret premise ("X holds S")
- **Effect:** the player's word. It adds a one-person secret reading told by the player, at the listener's reliability for the player (`0.5 + 0.5 × credibility`). It's always attended. It joins the player's track record.
- **Strength:** weak to moderate, scaled by credibility.

### G5. Holds their claimed gift
- **Effect:** reduces to "X is good" plus the role table's fit.

### G6. Conflict
- **Effect:** "the cited reports can't all be true", tested as a case-consistency check.

### G7. Reading challenge
- **Modes:** misled, lying, failed gift (impaired), Delusional, "these readings from one person don't fit together".
- **System:** leave-one-out against the rest of the case, scored against chance.
  - An accepted challenge lowers the reading's reliability.
  - A "failed gift" challenge raises Poisoner candidates by 0.12 × agreement.
  - A challenge backfires (and costs the player trust) when the rest of the evidence moves the reading toward holding by 0.25.
- **Strength:** moderate when grounded in other cards; nothing when ungrounded.

## H. Distorters

These aren't evidence. They're what makes evidence wrong, and each entry above lists which ones apply.

| Distorter | What it does | Modelled |
|---|---|---|
| Marked (secret) | May register as evil, or as the Demon, to reading gifts. Per reading, independently. | worlds |
| Red Herring (Seer) | One good soul reads as the Demon to the Seer, all case. | role table |
| Delusional (secret) | Gift gives arbitrary information; the holder doesn't know. | worlds |
| Poisoner | One person's gift fails or lies until the next night. | **not in worlds**: reading error and challenges only |
| Muddler (secret) | Often muddles one detail when passing on someone else's reading or sighting. | world modifier; route reliability |
| Sleepwalker (secret) | Leaves home each night without knowing it. Honest false alibis. | worlds and movement |
| Lovers (secret) | Two townsfolk meet at night. Honest outings. | worlds and movement |
| Revenant curse | A good voter turns evil for a window. | chronology; live histories only partly adapted |
| Scion | Becomes the Demon if the Demon is executed with five or more alive. | worlds (succession) |
| Brute | Hunts in the Demon's place; the Demon stays home. Registers as a Minion. | movement |
| Breathstealer | Silences someone; the silence is weak evidence they're good. | public factor |
| Sexton's bell | Suppresses Minion effects for a night. | simulation only; the solver checks the claim's consistency, not the suppression |

## Findings from this pass

1. **Poison isn't a world state.** A poisoned reading is covered only by `err`. For heard readings that's already large (about 0.57 at trust 0.7), so other minds discount it heavily anyway. But the reader's own copy has `err` 0.2%, so a poisoned Dowser is near-certain of their own false count. That's arguably right (they don't know), but the only routes to "that was the night I was poisoned" are indirect: source doubt from caught contradictions, and the player's "failed gift" challenge.
2. **Fixed `q` for role-table readings.** Seer, Clerk, Archivist, Gravedigger, Executor, Registrar and Monitor all get `q` = 0.5. That's probably too generous to bluffers for readings that hold in few worlds (a Seer "yes", an Archivist pair). The CaseEval comment and the fixed path disagree for the Seer.
3. **Lamplighter checking.** CaseEval says the Lamplighter's count is checked nowhere (`q` = 1); the movement code uses it to constrain routes. Possibly both are true (it constrains worlds but earns no source credit), but worth confirming.
4. **The Augur needs day positions to do anything.** They come from recorded daytime sightings or workplace context (who was at work, where). With neither on the player's board, an Augur reading is inert in the Workshop.
5. **Circumstantial evidence is player-only and small by design.** It only exists in cases the player files, caps at +0.045, and only opens when there's Stage 1 evidence. NPCs don't run it on their own.
6. **Hearthwitch** is benched, but still has solver support.

## Next: the measured pass

For each entry:
- one reference town (seed 692, 7 players);
- the card added alone, and with its key partner;
- at trust 0.4 and 0.8, heard directly, at Insight 0.5;
- recording the shift in the subject's suspicion and the likelihood ratio on the conclusion it supports.

That replaces the judged tiers, and checks findings 2 and 3 directly.
